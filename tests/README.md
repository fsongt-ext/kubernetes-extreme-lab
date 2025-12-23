# Testing Infrastructure

Comprehensive testing strategy for the Kubernetes platform covering unit, integration, E2E, chaos, and performance tests.

## Directory Structure

```
tests/
├── unit/                      # Unit tests for IaC code
│   ├── terraform_test.go     # Terraform module tests (Terratest)
│   └── ansible_test.py       # Ansible playbook syntax tests
│
├── integration/               # Integration tests for components
│   ├── argocd_integration_test.go    # ArgoCD deployment tests
│   └── istio_integration_test.go     # Istio service mesh tests
│
├── e2e/                       # End-to-end platform tests
│   └── platform_e2e_test.go  # Full platform validation
│
├── chaos/                     # Chaos engineering experiments
│   └── litmus_chaos_experiments.yaml # LitmusChaos scenarios
│
└── performance/               # Load and stress tests
    └── k6_load_test.js       # K6 performance tests
```

## Test Categories

### 1. Unit Tests

Validate infrastructure-as-code (Terraform, Ansible) correctness before deployment.

**Tools:** Terratest, pytest, ansible-lint

**Run unit tests:**

```bash
# Terraform tests
cd tests/unit
go test -v terraform_test.go

# Ansible tests
cd tests/unit
pytest ansible_test.py -v
```

### 2. Integration Tests

Validate component integration and health after deployment.

**Tools:** Go testing framework, Kubernetes client-go

**Run integration tests:**

```bash
# Requires running K3s cluster
export KUBECONFIG=~/.kube/config

cd tests/integration
go test -v -timeout 10m ./...
```

**Test coverage:**
- ArgoCD deployment and Application sync
- Istio service mesh (mTLS, sidecars, routing)
- Platform component health checks

### 3. End-to-End Tests

Validate full platform functionality from user perspective.

**Tools:** Go, Kubernetes client-go

**Run E2E tests:**

```bash
cd tests/e2e
go test -v -timeout 30m ./...
```

**Test scenarios:**
- Full platform deployment validation
- Demo app lifecycle (deploy, health, metrics)
- Observability stack (Grafana, Prometheus, Loki)
- Canary deployments with Argo Rollouts
- Security policy enforcement (Kyverno, OPA)

### 4. Chaos Engineering

Validate platform resilience under failure conditions.

**Tools:** LitmusChaos

**Prerequisites:**

```bash
# Install LitmusChaos operator
kubectl apply -f https://litmuschaos.github.io/litmus/litmus-operator-v3.0.0.yaml

# Create litmus namespace
kubectl create namespace litmus

# Install ChaosCenter (optional UI)
kubectl apply -f https://raw.githubusercontent.com/litmuschaos/litmus/master/mkdocs/docs/3.0.0/litmus-portal-crds.yml
kubectl apply -f https://raw.githubusercontent.com/litmuschaos/litmus/master/mkdocs/docs/3.0.0/litmus-portal-setup.yml
```

**Run chaos experiments:**

```bash
# Apply all chaos experiments
kubectl apply -f tests/chaos/litmus_chaos_experiments.yaml

# Watch chaos engine status
kubectl get chaosengine -n demo -w

# View chaos results
kubectl get chaosresult -n demo

# Check specific experiment result
kubectl describe chaosresult demo-app-pod-delete -n demo
```

**Available experiments:**
1. **pod-delete**: Random pod deletion to test recovery
2. **pod-network-latency**: Network latency injection (2s + 100ms jitter)
3. **container-kill**: Kill Istio sidecar proxy
4. **argocd-server-pod-delete**: ArgoCD server resilience
5. **node-memory-hog**: Node memory exhaustion (80% consumption)

**Scheduled chaos:**
- Runs daily at 2 AM (non-business hours)
- Configurable via ChaosSchedule CRD

### 5. Performance Tests

Validate platform performance under load.

**Tools:** K6

**Prerequisites:**

```bash
# Install K6
brew install k6  # macOS

# Or use Docker
docker pull grafana/k6
```

**Run performance tests:**

```bash
# Port-forward demo-app (if not exposed)
kubectl port-forward svc/demo-app 8080:8080 -n demo &

# Run load test
k6 run tests/performance/k6_load_test.js

# Run with custom base URL
BASE_URL=http://localhost:8080 k6 run tests/performance/k6_load_test.js

# Run with cloud output (K6 Cloud)
k6 run --out cloud tests/performance/k6_load_test.js

# Run with InfluxDB output
k6 run --out influxdb=http://localhost:8086/k6 tests/performance/k6_load_test.js
```

**Load test stages:**
1. Ramp-up: 10 → 50 → 100 users (17 minutes)
2. Sustained: 100 users for 10 minutes
3. Spike: 200 users for 4 minutes
4. Ramp-down: 50 → 0 users (4 minutes)

**Performance SLOs:**
- P95 latency: < 500ms
- P99 latency: < 1000ms
- Error rate: < 1%
- Health endpoint P95: < 100ms
- Metrics endpoint P95: < 200ms

**Scenarios:**
- Health check (40% of requests)
- Metrics scraping (20% of requests)
- API load test (30% of requests)
- Stress test - batch requests (10% of requests)

## CI/CD Integration

### GitHub Actions

Tests run automatically on pull requests and commits.

```yaml
# .github/workflows/test.yaml
name: Test Suite

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Terraform tests
        run: |
          cd tests/unit
          go test -v terraform_test.go

  integration-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup K3s
        run: |
          curl -sfL https://get.k3s.io | sh -
      - name: Run integration tests
        run: |
          cd tests/integration
          go test -v -timeout 10m ./...

  e2e-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy platform
        run: |
          ./infrastructure/scripts/bootstrap.sh
      - name: Run E2E tests
        run: |
          cd tests/e2e
          go test -v -timeout 30m ./...

  performance-tests:
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      - name: Run K6 tests
        run: |
          k6 run tests/performance/k6_load_test.js
```

## Test Reports

### Code Coverage

```bash
# Go test coverage
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out -o coverage.html
```

### JUnit XML Reports

```bash
# Install go-junit-report
go install github.com/jstemmer/go-junit-report/v2@latest

# Generate JUnit report
go test -v ./... 2>&1 | go-junit-report -set-exit-code > report.xml
```

### K6 HTML Reports

```bash
# Generate K6 HTML report
k6 run --out json=test-results.json tests/performance/k6_load_test.js
k6 report test-results.json --out html=report.html
```

## Best Practices

### 1. Test Isolation

- Each test should be independent
- Clean up resources after test completion
- Use unique namespaces for parallel tests

### 2. Test Timeouts

- Set appropriate timeouts for long-running tests
- Integration tests: 10 minutes
- E2E tests: 30 minutes
- Chaos tests: Duration of experiment + buffer

### 3. Retry Logic

- Implement retry logic for flaky tests
- Wait for resources to become ready
- Use Kubernetes watch API for state changes

### 4. Test Data

- Use test-specific namespaces (e.g., `test-12345`)
- Generate unique resource names
- Clean up test data to avoid conflicts

### 5. Environment Variables

```bash
# Required environment variables
export KUBECONFIG=~/.kube/config
export BASE_URL=http://demo-app.demo.svc.cluster.local:8080
```

## Troubleshooting

### Tests Fail with "connection refused"

**Issue:** Cannot connect to Kubernetes API

**Solution:**
```bash
# Verify kubectl works
kubectl get nodes

# Check KUBECONFIG
echo $KUBECONFIG

# Port-forward if testing remotely
kubectl port-forward svc/kubernetes 6443:443 -n default
```

### Chaos experiments don't start

**Issue:** LitmusChaos operator not running

**Solution:**
```bash
# Check operator status
kubectl get pods -n litmus

# Reinstall operator
kubectl delete namespace litmus
kubectl apply -f https://litmuschaos.github.io/litmus/litmus-operator-v3.0.0.yaml
```

### K6 tests fail with high error rate

**Issue:** Platform under-resourced or pods not ready

**Solution:**
```bash
# Check pod status
kubectl get pods -n demo

# Check resource usage
kubectl top nodes
kubectl top pods -n demo

# Scale demo-app if needed
kubectl scale deployment demo-app --replicas=3 -n demo
```

## References

- [Terratest Documentation](https://terratest.gruntwork.io/)
- [LitmusChaos Documentation](https://litmuschaos.github.io/litmus/)
- [K6 Documentation](https://k6.io/docs/)
- [Kubernetes E2E Testing](https://kubernetes.io/blog/2019/03/22/kubernetes-end-to-end-testing-for-everyone/)
