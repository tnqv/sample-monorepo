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
	tasksProcessed = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "worker_tasks_processed_total",
			Help: "Total number of tasks processed by the worker",
		},
	)

	taskDuration = promauto.NewHistogram(
		prometheus.HistogramOpts{
			Name:    "worker_task_duration_seconds",
			Help:    "Duration of task processing in seconds",
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

	utils.Logger.Infof("Starting worker with interval %s", interval)

	// Main worker loop
	taskID := 0
	for {
		select {
		case <-ctx.Done():
			utils.Logger.Info("Worker shutting down")
			return
		default:
			taskID++
			processTask(ctx, taskID, secret)
			time.Sleep(interval)
		}
	}
}

// processTask processes a single task with full tracing
func processTask(ctx context.Context, taskID int, secret string) {
	// Start root span for the task
	ctx, span := tracing.StartSpan(ctx, "process_task",
		trace.WithAttributes(
			attribute.Int("task.id", taskID),
			attribute.String("task.type", "background"),
		),
	)
	defer func() {
		if span != nil {
			span.End()
		}
	}()

	start := time.Now()

	// Before
	//  utils.Logger.Infof("Processing task #%d", taskID)
	// Add log with trace context - trace_id and span_id will be included
	utils.LogWithTrace(ctx).WithField("task_id", taskID).Info("Processing task started")

	// Step 1: Validate task
	if err := validateTask(ctx, taskID); err != nil {
		if span != nil {
			span.RecordError(err)
			span.SetStatus(codes.Error, err.Error())
		}
		utils.LogWithTrace(ctx).WithError(err).Error("Task validation failed")
		return
	}
	utils.LogWithTrace(ctx).Debug("Task validation passed")

	// Step 2: Fetch data
	data, err := fetchData(ctx, taskID)
	if err != nil {
		if span != nil {
			span.RecordError(err)
			span.SetStatus(codes.Error, err.Error())
		}
		utils.LogWithTrace(ctx).WithError(err).Error("Data fetch failed")
		return
	}
	utils.LogWithTrace(ctx).WithField("data_size", len(data)).Debug("Data fetched")

	// Step 3: Process data
	result, err := processData(ctx, data, secret)
	if err != nil {
		if span != nil {
			span.RecordError(err)
			span.SetStatus(codes.Error, err.Error())
		}
		utils.LogWithTrace(ctx).WithError(err).Error("Data processing failed")
		return
	}
	utils.LogWithTrace(ctx).WithField("result_size", len(result)).Debug("Data processed")

	// Step 4: Save result
	if err := saveResult(ctx, taskID, result); err != nil {
		if span != nil {
			span.RecordError(err)
			span.SetStatus(codes.Error, err.Error())
		}
		utils.LogWithTrace(ctx).WithError(err).Error("Save result failed")
		return
	}

	// Record metrics
	duration := time.Since(start)
	taskDuration.Observe(duration.Seconds())
	tasksProcessed.Inc()

	if span != nil {
		span.SetAttributes(
			attribute.Float64("task.duration_ms", float64(duration.Milliseconds())),
			attribute.String("task.status", "completed"),
		)
		span.SetStatus(codes.Ok, "Task completed successfully")
	}

	utils.LogWithTrace(ctx).WithFields(map[string]interface{}{
		"task_id":     taskID,
		"duration_ms": duration.Milliseconds(),
	}).Info("Task completed successfully")
}

// validateTask validates the task parameters
func validateTask(ctx context.Context, taskID int) error {
	ctx, span := tracing.StartSpan(ctx, "validate_task",
		trace.WithAttributes(attribute.Int("task.id", taskID)),
	)
	defer func() {
		if span != nil {
			span.End()
		}
	}()

	// Simulate validation work
	time.Sleep(time.Duration(10+rand.Intn(20)) * time.Millisecond)

	tracing.AddEvent(ctx, "validation_complete",
		attribute.Bool("valid", true),
	)

	return nil
}

// fetchData simulates fetching data from an external source
func fetchData(ctx context.Context, taskID int) (string, error) {
	ctx, span := tracing.StartSpan(ctx, "fetch_data",
		trace.WithAttributes(
			attribute.Int("task.id", taskID),
			attribute.String("data.source", "external_api"),
		),
	)
	defer func() {
		if span != nil {
			span.End()
		}
	}()

	// Simulate API call latency
	latency := time.Duration(50+rand.Intn(100)) * time.Millisecond
	time.Sleep(latency)

	data := fmt.Sprintf("data_for_task_%d", taskID)

	tracing.AddEvent(ctx, "data_fetched",
		attribute.Int("data.size_bytes", len(data)),
		attribute.Float64("fetch.latency_ms", float64(latency.Milliseconds())),
	)

	return data, nil
}

// processData processes the fetched data
func processData(ctx context.Context, data string, secret string) (string, error) {
	ctx, span := tracing.StartSpan(ctx, "process_data",
		trace.WithAttributes(
			attribute.Int("data.input_size", len(data)),
		),
	)
	defer func() {
		if span != nil {
			span.End()
		}
	}()

	// Simulate CPU-intensive processing
	processingTime := time.Duration(100+rand.Intn(200)) * time.Millisecond
	time.Sleep(processingTime)

	result := fmt.Sprintf("processed_%s_with_secret", data)

	if span != nil {
		span.SetAttributes(
			attribute.Int("data.output_size", len(result)),
			attribute.Float64("processing.duration_ms", float64(processingTime.Milliseconds())),
		)
	}

	tracing.AddEvent(ctx, "processing_complete",
		attribute.String("algorithm", "custom_v1"),
	)

	return result, nil
}

// saveResult saves the processing result
func saveResult(ctx context.Context, taskID int, result string) error {
	_, span := tracing.StartSpan(ctx, "save_result",
		trace.WithAttributes(
			attribute.Int("task.id", taskID),
			attribute.Int("result.size", len(result)),
			attribute.String("storage.type", "memory"),
		),
	)
	defer func() {
		if span != nil {
			span.End()
		}
	}()

	// Simulate storage latency
	time.Sleep(time.Duration(20+rand.Intn(30)) * time.Millisecond)

	return nil
}
