FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/sampleapi ./cmd/sampleapi

# Final stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates wget

WORKDIR /root/

# Copy binary from builder
COPY --from=builder /app/sampleapi .

EXPOSE 8080

CMD ["./sampleapi"]

