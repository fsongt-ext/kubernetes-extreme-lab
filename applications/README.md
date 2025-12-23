# Applications

This directory contains sample microservices demonstrating platform capabilities.

## Directory Structure

```
applications/
├── demo-app/                    # Sample Go microservice
│   ├── src/                    # Application source code
│   │   └── main.go            # Main application
│   ├── tests/                  # Test files
│   ├── Dockerfile              # Multi-stage Docker build
│   ├── Makefile                # Build automation
│   ├── go.mod                  # Go dependencies
│   └── openapi.yaml            # API specification
│
├── helm-charts/                # Helm charts
│   └── demo-app/
│       ├── Chart.yaml
│       ├── values.yaml         # Base configuration
│       ├── values-lab.yaml     # Lab overrides
│       └── templates/          # Kubernetes manifests
│           ├── rollout.yaml    # Argo Rollouts
│           ├── service.yaml
│           ├── servicemonitor.yaml
│           ├── virtualservice.yaml  # Istio
│           ├── networkpolicy.yaml
│           └── ...
│
└── README.md
```

## Demo App Features

The demo-app showcases all platform capabilities:

### 1. **Observability (LGTM)**
- **Metrics**: Prometheus instrumentation (`/metrics`)
- **Traces**: OpenTelemetry with automatic context propagation
- **Logs**: Structured JSON logging

```go
// Prometheus metrics
httpRequestsTotal.WithLabelValues(method, path, status).Inc()
httpRequestDuration.WithLabelValues(method, path).Observe(duration)

// OpenTelemetry tracing
tracer := otel.Tracer("demo-app")
ctx, span := tracer.Start(r.Context(), "operation")
defer span.End()
```

### 2. **Service Mesh (Istio)**
- **mTLS**: Automatic mutual TLS
- **Traffic Management**: Retries, timeouts, circuit breakers
- **Observability**: Envoy metrics and distributed tracing

```yaml
# VirtualService with retries
retries:
  attempts: 3
  perTryTimeout: 2s
  retryOn: 5xx,reset,connect-failure
```

### 3. **Progressive Delivery (Argo Rollouts)**
- **Canary Deployments**: Gradual traffic shifting
- **Analysis**: Success rate validation
- **Automatic Rollback**: On metric threshold breaches

```yaml
# Canary strategy
steps:
  - setWeight: 20
  - pause: {duration: 60s}
  - setWeight: 40
  - pause: {duration: 60s}
  - setWeight: 100
```

### 4. **Security**
- **Non-root user**: Runs as UID 65534
- **Read-only root filesystem**: Immutable container
- **Network policies**: Restricted ingress/egress
- **Security context**: Drop all capabilities

```dockerfile
# Minimal scratch image
FROM scratch
USER 65534:65534
```

### 5. **Autoscaling (HPA)**
- CPU-based scaling
- Memory-based scaling
- Custom metrics (via ServiceMonitor)

### 6. **Health Checks**
- **Liveness probe**: `/health` endpoint
- **Readiness probe**: `/ready` endpoint
- **Startup probe**: For slow-starting apps

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Home page |
| `/health` | GET | Health check (liveness) |
| `/ready` | GET | Readiness check |
| `/api/v1/hello` | GET | Hello endpoint with query param |
| `/api/v1/echo` | POST | Echo JSON payload |
| `/metrics` | GET | Prometheus metrics |

## Building the Application

### Local Development

```bash
cd applications/demo-app

# Install dependencies
make deps

# Build binary
make build

# Run locally
make run

# Test
curl http://localhost:8080/health
```

### Docker Build

```bash
# Build image
make docker-build

# Push to registry
make docker-push

# Or use Docker directly
docker build -t yourusername/demo-app:1.0.0 .
docker push yourusername/demo-app:1.0.0
```

### Multi-platform Build

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t yourusername/demo-app:1.0.0 \
  --push \
  .
```

## Deploying with Helm

### Install to Kubernetes

```bash
cd applications/helm-charts/demo-app

# Lab environment
helm install demo-app . \
  -f values.yaml \
  -f values-lab.yaml \
  --namespace demo \
  --create-namespace

# Production environment
helm install demo-app . \
  -f values.yaml \
  -f values-prod.yaml \
  --namespace demo \
  --create-namespace
```

### Upgrade

```bash
helm upgrade demo-app . \
  -f values.yaml \
  -f values-lab.yaml \
  --namespace demo
```

### Uninstall

```bash
helm uninstall demo-app --namespace demo
```

## Testing the Deployment

### Check Status

```bash
# Pods
kubectl get pods -n demo

# Argo Rollout
kubectl argo rollouts get rollout demo-app -n demo

# Service
kubectl get svc -n demo

# Istio VirtualService
kubectl get virtualservice -n demo
```

### Access the Application

```bash
# Port-forward to service
kubectl port-forward -n demo svc/demo-app 8080:80

# Test endpoints
curl http://localhost:8080/health
curl http://localhost:8080/api/v1/hello?name=Platform
curl -X POST http://localhost:8080/api/v1/echo -d '{"message":"test"}'

# Check metrics
curl http://localhost:8080/metrics
```

### Via Istio Ingress

```bash
# Get ingress IP
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Add to /etc/hosts
echo "$INGRESS_HOST demo-app.lab.local" | sudo tee -a /etc/hosts

# Access via domain
curl http://demo-app.lab.local/health
```

## Observability

### View Metrics in Grafana

```bash
# Port-forward to Grafana
kubectl port-forward -n observability svc/grafana 3000:80

# Open http://localhost:3000
# Default credentials: admin/admin
```

Dashboards:
- **Application Metrics**: Request rate, latency, error rate
- **Istio Mesh**: Service-to-service metrics
- **Rollout Analysis**: Canary deployment metrics

### View Traces in Tempo

Traces are automatically collected via OpenTelemetry and sent to Tempo.

```bash
# Query traces in Grafana
# Navigate to Explore → Tempo
# Search by trace ID or service name
```

### View Logs in Loki

```bash
# Query logs in Grafana
# Navigate to Explore → Loki
# LogQL query: {namespace="demo", app="demo-app"}
```

## Progressive Delivery

### Trigger Canary Deployment

```bash
# Update image tag
kubectl argo rollouts set image demo-app -n demo \
  demo-app=yourusername/demo-app:2.0.0

# Watch rollout progress
kubectl argo rollouts get rollout demo-app -n demo --watch

# Pause rollout
kubectl argo rollouts pause demo-app -n demo

# Resume rollout
kubectl argo rollouts promote demo-app -n demo

# Abort rollout (rollback)
kubectl argo rollouts abort demo-app -n demo
```

### Rollout Dashboard

```bash
# Install Argo Rollouts kubectl plugin
kubectl argo rollouts dashboard

# Open http://localhost:3100
```

## Security

### Verify Security Context

```bash
# Check pod security context
kubectl get pod -n demo -o jsonpath='{.items[0].spec.securityContext}'

# Check container security context
kubectl get pod -n demo -o jsonpath='{.items[0].spec.containers[0].securityContext}'
```

### Test Network Policy

```bash
# From allowed namespace (should work)
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://demo-app.demo.svc.cluster.local/health

# From blocked namespace (should fail)
kubectl run -it --rm debug --image=curlimages/curl --restart=Never \
  --namespace=other -- \
  curl http://demo-app.demo.svc.cluster.local/health
```

## CI/CD Integration

The demo-app integrates with GitHub Actions:

1. **SAST**: Semgrep scanning
2. **Secret scanning**: Gitleaks
3. **Dependency scanning**: Trivy
4. **Build**: Multi-platform Docker build
5. **Image scanning**: Trivy image scan
6. **SBOM**: Syft SBOM generation
7. **Signing**: Cosign image signing
8. **GitOps update**: Update image tag in gitops repo

See `.github/workflows/app-ci.yaml` for full pipeline.

## Customization

### Add New Endpoints

1. Update `src/main.go` with new handler
2. Update `openapi.yaml` with new endpoint spec
3. Rebuild and deploy

### Add Dependencies

```bash
# Update imports in main.go
go get github.com/some/package

# Update go.mod
go mod tidy
```

### Environment Variables

Add to `values.yaml`:

```yaml
env:
  - name: CUSTOM_VAR
    value: "custom-value"
  - name: SECRET_VAR
    valueFrom:
      secretKeyRef:
        name: demo-secret
        key: password
```

## Troubleshooting

### Pod not starting

```bash
# Check pod events
kubectl describe pod -n demo -l app=demo-app

# Check logs
kubectl logs -n demo -l app=demo-app

# Check Istio sidecar
kubectl logs -n demo -l app=demo-app -c istio-proxy
```

### Rollout stuck

```bash
# Check rollout status
kubectl argo rollouts status demo-app -n demo

# Check analysis
kubectl get analysisrun -n demo

# Abort and retry
kubectl argo rollouts abort demo-app -n demo
kubectl argo rollouts retry demo-app -n demo
```

### Metrics not appearing

```bash
# Check ServiceMonitor
kubectl get servicemonitor -n demo

# Check Prometheus targets
# Port-forward to Prometheus and check /targets

# Check pod annotations
kubectl get pod -n demo -o yaml | grep prometheus
```

## Next Steps

1. **Extend the app**: Add database, caching, message queue
2. **Add tests**: Unit tests, integration tests, load tests
3. **Custom metrics**: Add business metrics for HPA
4. **Chaos testing**: Use Chaos Mesh for fault injection
5. **Multi-region**: Deploy across multiple clusters

## References

- [OpenTelemetry Go](https://opentelemetry.io/docs/instrumentation/go/)
- [Prometheus Client Go](https://github.com/prometheus/client_golang)
- [Argo Rollouts](https://argoproj.github.io/argo-rollouts/)
- [Istio Traffic Management](https://istio.io/latest/docs/tasks/traffic-management/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
