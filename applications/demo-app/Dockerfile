# Multi-stage Dockerfile for Go application
# Optimized for security and size

##############################################################################
# Stage 1: Build
##############################################################################
FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Set working directory
WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY src/ ./src/

# Build application
# CGO_ENABLED=0 for static binary
# -ldflags to reduce binary size
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a -installsuffix cgo \
    -o app \
    ./src/main.go

##############################################################################
# Stage 2: Runtime
##############################################################################
FROM scratch

# Copy timezone data
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Copy CA certificates
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy application binary
COPY --from=builder /build/app /app

# Create non-root user (using numeric UID for scratch)
USER 65534:65534

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/app", "health"]

# Set environment variables
ENV APP_VERSION=1.0.0 \
    ENVIRONMENT=production

# Run application
ENTRYPOINT ["/app"]
