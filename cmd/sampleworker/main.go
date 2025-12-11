package main

import (
	"context"
	"fmt"
	"math/rand"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"sample-monorepo/internal/tracing"
	"sample-monorepo/internal/utils"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/trace"
)

var (
	emailsSent = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "worker_emails_sent_total",
			Help: "Total number of emails sent successfully by the worker",
		},
	)

	emailsFailed = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "worker_emails_failed_total",
			Help: "Total number of emails that failed to send",
		},
	)

	emailDuration = promauto.NewHistogram(
		prometheus.HistogramOpts{
			Name:    "worker_email_duration_seconds",
			Help:    "Duration of email sending in seconds",
			Buckets: prometheus.DefBuckets,
		},
	)

	workerInfo = promauto.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "worker_info",
			Help: "Information about the worker",
		},
		[]string{"interval"},
	)
)

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Initialize logger
	logLevel := os.Getenv("LOG_LEVEL")
	if logLevel == "" {
		logLevel = "info"
	}
	utils.InitLogger(logLevel)

	// Initialize tracing
	serviceName := os.Getenv("OTEL_SERVICE_NAME")
	if serviceName == "" {
		serviceName = "sampleworker"
	}

	shutdown, err := tracing.InitTracer(ctx, serviceName)
	if err != nil {
		utils.Logger.Warnf("Failed to initialize tracing: %v", err)
	} else {
		defer func() {
			if err := shutdown(ctx); err != nil {
				utils.Logger.Errorf("Error shutting down tracer: %v", err)
			}
		}()
		utils.Logger.Info("OpenTelemetry tracing initialized")
	}

	// Configuration
	intervalStr := os.Getenv("WORKER_INTERVAL")
	interval, err := time.ParseDuration(intervalStr)
	if err != nil {
		interval = 10 * time.Second
	}

	metricsPort := os.Getenv("METRICS_PORT")
	if metricsPort == "" {
		metricsPort = "9091"
	}

	secret := os.Getenv("SECRET_KEY")
	if secret == "" {
		utils.Logger.Warn("SECRET_KEY not set, using default")
		secret = "default-secret"
	}

	failSimulateEnabled := os.Getenv("FAIL_SIMULATE_ENABLED") == "true"

	utils.Logger.Infof("Fail simulate is %t", failSimulateEnabled)

	// Set worker info metric
	workerInfo.WithLabelValues(interval.String()).Set(1)

	// Start metrics server
	go func() {
		metricsMux := http.NewServeMux()
		metricsMux.Handle("/metrics", promhttp.Handler())
		utils.Logger.Infof("Starting metrics server on :%s", metricsPort)
		if err := http.ListenAndServe(":"+metricsPort, metricsMux); err != nil {
			utils.Logger.Fatal(err)
		}
	}()

	// Handle graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		<-sigChan
		utils.Logger.Info("Received shutdown signal")
		cancel()
	}()

	utils.Logger.Infof("Starting email worker with interval %s", interval)

	// Main worker loop
	emailID := 0
	for {
		select {
		case <-ctx.Done():
			utils.Logger.Info("Email worker shutting down")
			return
		default:
			emailID++
			sendMail(ctx, emailID, failSimulateEnabled)
			time.Sleep(interval)
		}
	}
}

// sendMail sends an email with full tracing
func sendMail(ctx context.Context, emailID int, failSimulateEnabled bool) {
	// Start root span for email sending
	ctx, span := tracing.StartSpan(ctx, "send_mail",
		trace.WithAttributes(
			attribute.Int("email.id", emailID),
			attribute.String("email.type", "transactional"),
		),
	)
	defer func() {
		if span != nil {
			span.End()
		}
	}()

	start := time.Now()

	utils.LogWithTrace(ctx).WithField("email_id", emailID).Info("Starting email send process")

	// Step 1: Validate email request
	if err := validateEmailRequest(ctx, emailID); err != nil {
		if span != nil {
			span.RecordError(err)
			span.SetStatus(codes.Error, err.Error())
		}
		emailsFailed.Inc()
		utils.LogWithTrace(ctx).WithError(err).Error("Email validation failed")
		return
	}
	utils.LogWithTrace(ctx).Debug("Email validation passed")

	// Step 2: Fetch email template and recipient data
	emailData, err := fetchEmailData(ctx, emailID)
	if err != nil {
		if span != nil {
			span.RecordError(err)
			span.SetStatus(codes.Error, err.Error())
		}
		emailsFailed.Inc()
		utils.LogWithTrace(ctx).WithError(err).Error("Email data fetch failed")
		return
	}
	utils.LogWithTrace(ctx).WithField("recipient", emailData.recipient).Debug("Email data fetched")

	// Step 3: Prepare email content
	emailContent, err := prepareEmailContent(ctx, emailData)
	if err != nil {
		if span != nil {
			span.RecordError(err)
			span.SetStatus(codes.Error, err.Error())
		}
		emailsFailed.Inc()
		utils.LogWithTrace(ctx).WithError(err).Error("Email content preparation failed")
		return
	}
	utils.LogWithTrace(ctx).WithField("subject", emailContent.subject).Debug("Email content prepared")

	// Step 4: Send email via SMTP
	if err := sendEmailViaSMTP(ctx, emailContent, failSimulateEnabled); err != nil {
		if span != nil {
			span.RecordError(err)
			span.SetStatus(codes.Error, err.Error())
		}
		emailsFailed.Inc()
		utils.LogWithTrace(ctx).WithError(err).Error("SMTP send failed")
		return
	}

	// Record metrics
	duration := time.Since(start)
	emailDuration.Observe(duration.Seconds())
	emailsSent.Inc()

	if span != nil {
		span.SetAttributes(
			attribute.Float64("email.duration_ms", float64(duration.Milliseconds())),
			attribute.String("email.status", "sent"),
			attribute.String("email.recipient", emailContent.recipient),
			attribute.String("email.subject", emailContent.subject),
		)
		span.SetStatus(codes.Ok, "Email sent successfully")
	}

	utils.LogWithTrace(ctx).WithFields(map[string]interface{}{
		"email_id":    emailID,
		"recipient":   emailContent.recipient,
		"subject":     emailContent.subject,
		"duration_ms": duration.Milliseconds(),
	}).Info("Email sent successfully")
}

// emailData represents email recipient and template data
type emailData struct {
	recipient string
	template  string
}

// emailContent represents prepared email content
type emailContent struct {
	recipient string
	subject   string
	body      string
}

// validateEmailRequest validates the email request parameters
func validateEmailRequest(ctx context.Context, emailID int) error {
	ctx, span := tracing.StartSpan(ctx, "validate_email_request",
		trace.WithAttributes(attribute.Int("email.id", emailID)),
	)
	defer func() {
		if span != nil {
			span.End()
		}
	}()

	// Simulate validation work (check recipient format, etc.)
	time.Sleep(time.Duration(10+rand.Intn(20)) * time.Millisecond)

	tracing.AddEvent(ctx, "validation_complete",
		attribute.Bool("valid", true),
	)

	return nil
}

// fetchEmailData simulates fetching email template and recipient data
func fetchEmailData(ctx context.Context, emailID int) (*emailData, error) {
	ctx, span := tracing.StartSpan(ctx, "fetch_email_data",
		trace.WithAttributes(
			attribute.Int("email.id", emailID),
			attribute.String("data.source", "email_service"),
		),
	)
	defer func() {
		if span != nil {
			span.End()
		}
	}()

	// Simulate API call latency to email service
	latency := time.Duration(50+rand.Intn(100)) * time.Millisecond
	time.Sleep(latency)

	recipient := fmt.Sprintf("user%d@example.com", rand.Intn(1000))
	template := fmt.Sprintf("template_%d", emailID%5) // Cycle through 5 templates

	data := &emailData{
		recipient: recipient,
		template:  template,
	}

	if span != nil {
		span.SetAttributes(
			attribute.String("email.recipient", recipient),
			attribute.String("email.template", template),
			attribute.Float64("fetch.latency_ms", float64(latency.Milliseconds())),
		)
	}

	tracing.AddEvent(ctx, "email_data_fetched",
		attribute.String("email.recipient", recipient),
		attribute.String("email.template", template),
	)

	return data, nil
}

// prepareEmailContent prepares the email content from template and data
func prepareEmailContent(ctx context.Context, data *emailData) (*emailContent, error) {
	ctx, span := tracing.StartSpan(ctx, "prepare_email_content",
		trace.WithAttributes(
			attribute.String("email.template", data.template),
			attribute.String("email.recipient", data.recipient),
		),
	)
	defer func() {
		if span != nil {
			span.End()
		}
	}()

	// Simulate template rendering and content preparation
	processingTime := time.Duration(30+rand.Intn(50)) * time.Millisecond
	time.Sleep(processingTime)

	subject := fmt.Sprintf("Welcome! Email #%d", rand.Intn(1000))
	body := fmt.Sprintf("Hello %s,\n\nThis is a dummy email sent using template: %s\n\nThank you for using our service!", data.recipient, data.template)

	content := &emailContent{
		recipient: data.recipient,
		subject:   subject,
		body:      body,
	}

	if span != nil {
		span.SetAttributes(
			attribute.String("email.subject", subject),
			attribute.Int("email.body_size", len(body)),
			attribute.Float64("preparation.duration_ms", float64(processingTime.Milliseconds())),
		)
	}

	tracing.AddEvent(ctx, "email_content_prepared",
		attribute.String("email.subject", subject),
	)

	return content, nil
}

// sendEmailViaSMTP simulates sending email via SMTP server
func sendEmailViaSMTP(ctx context.Context, content *emailContent, failSimulateEnabled bool) error {
	ctx, span := tracing.StartSpan(ctx, "send_email_smtp",
		trace.WithAttributes(
			attribute.String("email.recipient", content.recipient),
			attribute.String("email.subject", content.subject),
		),
	)
	defer func() {
		if span != nil {
			span.End()
		}
	}()

	if failSimulateEnabled {
		err := fmt.Errorf("SMTP server unavailable")
		if span != nil {
			span.RecordError(err)
			span.SetStatus(codes.Error, err.Error())
		}
		return err
	}

	// Simulate SMTP connection and sending
	smtpTime := time.Duration(100+rand.Intn(200)) * time.Millisecond
	time.Sleep(smtpTime)

	// Simulate occasional SMTP failures (5% failure rate)
	// if rand.Float32() < 0.05 {
	// 	err := fmt.Errorf("SMTP server unavailable")
	// 	if span != nil {
	// 		span.RecordError(err)
	// 		span.SetStatus(codes.Error, err.Error())
	// 	}
	// 	return err
	// }

	if span != nil {
		span.SetAttributes(
			attribute.Float64("smtp.duration_ms", float64(smtpTime.Milliseconds())),
			attribute.String("smtp.status", "success"),
		)
	}

	tracing.AddEvent(ctx, "email_sent_via_smtp",
		attribute.String("email.recipient", content.recipient),
		attribute.String("smtp.server", "smtp.example.com"),
	)

	return nil
}
