package utils

import (
	"context"

	"github.com/sirupsen/logrus"
	"go.opentelemetry.io/otel/trace"
)

var Logger *logrus.Logger

func InitLogger(level string) {
	Logger = logrus.New()
	parsedLevel, err := logrus.ParseLevel(level)
	if err != nil {
		parsedLevel = logrus.InfoLevel
	}
	Logger.SetLevel(parsedLevel)
	Logger.SetFormatter(&logrus.JSONFormatter{})
}

func LogWithTrace(ctx context.Context) *logrus.Entry {
	span := trace.SpanFromContext(ctx)
	if span == nil || !span.SpanContext().IsValid() {
		return Logger.WithFields(logrus.Fields{})
	}

	spanCtx := span.SpanContext()
	return Logger.WithFields(logrus.Fields{
		"trace_id": spanCtx.TraceID().String(),
		"span_id":  spanCtx.SpanID().String(),
	})
}

// LogFields returns common fields for structured logging with trace context
func LogFields(ctx context.Context, fields map[string]interface{}) logrus.Fields {
	result := logrus.Fields{}

	span := trace.SpanFromContext(ctx)
	if span != nil && span.SpanContext().IsValid() {
		spanCtx := span.SpanContext()
		result["trace_id"] = spanCtx.TraceID().String()
		result["span_id"] = spanCtx.SpanID().String()
	}

	// Add custom fields
	for k, v := range fields {
		result[k] = v
	}

	return result
}
