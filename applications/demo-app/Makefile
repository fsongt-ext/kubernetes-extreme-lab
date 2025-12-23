.PHONY: help build test lint docker-build docker-push clean

# Variables
APP_NAME := demo-app
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
REGISTRY := docker.io/yourusername
IMAGE := $(REGISTRY)/$(APP_NAME):$(VERSION)
LATEST_IMAGE := $(REGISTRY)/$(APP_NAME):latest

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@awk 'BEGIN {FS = ":.*##"; printf "\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

build: ## Build the Go binary
	@echo "Building $(APP_NAME)..."
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
		-ldflags='-w -s -X main.Version=$(VERSION)' \
		-o bin/$(APP_NAME) \
		./src/main.go

test: ## Run tests
	@echo "Running tests..."
	go test -v -race -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

lint: ## Run linters
	@echo "Running linters..."
	golangci-lint run ./...

docker-build: ## Build Docker image
	@echo "Building Docker image $(IMAGE)..."
	docker build -t $(IMAGE) -t $(LATEST_IMAGE) .

docker-push: docker-build ## Push Docker image to registry
	@echo "Pushing Docker image..."
	docker push $(IMAGE)
	docker push $(LATEST_IMAGE)

run: ## Run application locally
	@echo "Running $(APP_NAME)..."
	go run ./src/main.go

clean: ## Clean build artifacts
	@echo "Cleaning..."
	rm -rf bin/
	rm -f coverage.out coverage.html

deps: ## Download dependencies
	@echo "Downloading dependencies..."
	go mod download
	go mod tidy

.DEFAULT_GOAL := help
