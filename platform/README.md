# Platform Components

This directory contains all Kubernetes platform components deployed and managed by Argo CD.

## Directory Structure

```
platform/
├── core/                     # Core platform services
│   ├── argocd/              # GitOps controller
│   ├── cert-manager/        # Certificate management
│   ├── sealed-secrets/      # Sealed secrets operator
│   └── external-secrets/    # External secrets operator
│
├── networking/              # Networking layer
│   ├── istio/              # Service mesh
│   │   ├── base/           # Istio CRDs
│   │   ├── istiod/         # Control plane
│   │   ├── gateway/        # Ingress gateway
│   │   └── ambient/        # Ambient mesh config
│   ├── kong/               # API Gateway
│   └── metallb/            # LoadBalancer provider
│
├── security/               # Security & Policy
│   ├── gatekeeper/        # OPA admission control (Platform team)
│   ├── kyverno/           # Policy engine (App team)
│   ├── falco/             # Runtime security
│   └── vault/             # Secrets management
│
├── observability/         # LGTM Stack
│   ├── grafana/          # Visualization
│   ├── mimir/            # Metrics backend
│   ├── tempo/            # Traces backend
│   ├── loki/             # Logs backend
│   ├── alloy/            # Collector
│   └── opentelemetry/    # OTel collector
│
├── data-services/        # Stateful services
│   ├── postgresql-operator/
│   ├── redis-operator/
│   └── kafka-strimzi/    # Kafka operator
│
└── operations/           # Operations tooling
    ├── argo-rollouts/   # Progressive delivery
    ├── velero/          # Backup & restore
    ├── chaos-mesh/      # Chaos engineering
    └── opencost/        # FinOps
```

## Deployment Strategy

All platform components are deployed via **Argo CD** using the GitOps pattern.

### Deployment Order (Sync Waves)

Components are deployed in the following order using Argo CD sync waves:

```
Wave 0: Core Infrastructure
├── cert-manager (certificates)
└── sealed-secrets (secrets)

Wave 1: Core Platform
└── argocd (GitOps controller itself)

Wave 2: Networking
├── istio-base (CRDs)
├── istiod (control plane)
├── istio-gateway (ingress)
├── kong (API gateway)
└── metallb (LoadBalancer)

Wave 3: Security & Policy
├── gatekeeper (admission control)
├── kyverno (policy engine)
├── falco (runtime security)
└── vault (secrets)

Wave 4: Observability
├── mimir (metrics)
├── tempo (traces)
├── loki (logs)
├── alloy (collector)
├── opentelemetry (OTel)
└── grafana (visualization)

Wave 5: Data Services
├── postgresql-operator
├── redis-operator
└── kafka-strimzi

Wave 6: Operations
├── argo-rollouts
├── velero
├── chaos-mesh
└── opencost
```

## Component Categories

### Core Components
**Purpose:** Essential platform services that other components depend on
**Owner:** Platform Team
**Resource Budget:** ~1.5 CPU, ~2GB RAM

- **Argo CD**: GitOps continuous delivery
- **cert-manager**: TLS certificate management
- **sealed-secrets**: Git-safe secret encryption

### Networking Components
**Purpose:** North-South and East-West traffic management
**Owner:** Platform Team
**Resource Budget:** ~2 CPU, ~2.5GB RAM

- **Istio**: Service mesh (mTLS, observability, traffic management)
- **Kong**: API Gateway (authentication, rate limiting, routing)
- **MetalLB**: LoadBalancer IP allocation for bare metal

### Security Components
**Purpose:** Policy enforcement and runtime protection
**Owner:** Security Team
**Resource Budget:** ~1 CPU, ~1.5GB RAM

- **OPA Gatekeeper**: Platform-level admission control
- **Kyverno**: Application-level policy management
- **Falco**: Runtime threat detection
- **Vault**: Secrets management and injection

### Observability Components
**Purpose:** LGTM stack for metrics, logs, and traces
**Owner:** SRE Team
**Resource Budget:** ~2.5 CPU, ~3GB RAM

- **Grafana**: Unified visualization platform
- **Mimir**: Long-term metrics storage
- **Tempo**: Distributed tracing backend
- **Loki**: Log aggregation
- **Alloy/OpenTelemetry**: Telemetry collection

### Data Services
**Purpose:** Stateful application dependencies
**Owner:** Application Teams
**Resource Budget:** Variable

- **PostgreSQL Operator**: Database management
- **Redis Operator**: Caching layer
- **Strimzi**: Kafka event streaming

### Operations Components
**Purpose:** Day-2 operations tooling
**Owner:** Platform + SRE Teams
**Resource Budget:** ~0.5 CPU, ~512MB RAM

- **Argo Rollouts**: Canary/blue-green deployments
- **Velero**: Backup and disaster recovery
- **Chaos Mesh**: Chaos engineering experiments
- **OpenCost**: Cost visibility and FinOps

## Resource Allocation

Total estimated resource usage:
- **CPU:** ~7.5 cores (with bursting)
- **Memory:** ~9.5 GB
- **Target Hardware:** 8 vCPU / 16GB RAM minimum

**Lab Constraints (2 vCPU / 8GB RAM):**
- Deploy **only critical components** initially
- Use minimal replica counts (replicas: 1)
- Disable HA features
- Enable resource limits strictly
- Consider component prioritization

### Minimal Lab Profile

For 2 vCPU / 8GB RAM, deploy:

```
Core:
✓ argocd
✓ cert-manager

Networking:
✓ istio (minimal profile)
✓ kong (DB-less mode)

Security:
✓ kyverno (lighter than Gatekeeper)

Observability:
✓ grafana
✓ loki (single instance)
✓ alloy (lightweight)

Operations:
✓ argo-rollouts
```

**Skip for lab:** Mimir, Tempo, Vault, Falco, data-services, chaos-mesh

## Configuration Management

### Values Files Structure

Each component follows this pattern:
```
component/
├── Chart.yaml              # Helm chart definition
├── values.yaml             # Base configuration
├── values-lab.yaml         # Lab overrides
├── values-dev.yaml         # Dev overrides
├── values-prod.yaml        # Production overrides
└── templates/              # Additional manifests
```

### Environment-Specific Overrides

```bash
# Lab environment (minimal resources)
helm install component ./component -f values.yaml -f values-lab.yaml

# Production environment (HA, full resources)
helm install component ./component -f values.yaml -f values-prod.yaml
```

## Argo CD Application Pattern

Each component has a corresponding Argo CD Application manifest in `gitops/environments/`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cert-manager
  namespace: argocd
spec:
  project: platform
  source:
    repoURL: git@github.com:TrungHQ-02/kubernetes-extreme-lab
    targetRevision: main
    path: platform/core/cert-manager
    helm:
      valueFiles:
        - values.yaml
        - values-lab.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: cert-manager
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## Dependencies

### Istio + Kong Integration

```
Internet → Kong API Gateway → Istio Ingress Gateway → Service Mesh (Envoy Sidecars) → Application
```

- **Kong**: External API management (authentication, rate limiting, caching)
- **Istio**: Internal service-to-service communication (mTLS, observability, retries)

### OPA Gatekeeper + Kyverno

- **Gatekeeper**: Platform team enforces cluster-wide policies (e.g., no privileged containers)
- **Kyverno**: App teams define namespace-specific policies (e.g., auto-add network policies)

## Verification

After deploying components:

```bash
# Check all platform components
kubectl get pods -A

# Verify Argo CD applications
kubectl get applications -n argocd

# Check sync status
argocd app list

# Validate Istio
istioctl analyze

# Test Kong
kubectl get svc -n kong

# Verify Grafana datasources
kubectl port-forward -n observability svc/grafana 3000:80
# Open http://localhost:3000
```

## Troubleshooting

### Resource Constraints

```bash
# Check resource usage
kubectl top nodes
kubectl top pods -A --sort-by=memory

# Identify resource hogs
kubectl get pods -A -o json | jq '.items[] | {name: .metadata.name, namespace: .metadata.namespace, cpu: .spec.containers[].resources.requests.cpu, memory: .spec.containers[].resources.requests.memory}'
```

### Argo CD Sync Issues

```bash
# Check application health
argocd app get <app-name>

# Manual sync
argocd app sync <app-name>

# Hard refresh
argocd app sync <app-name> --force

# View logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Istio Issues

```bash
# Check control plane status
istioctl proxy-status

# Validate configuration
istioctl analyze

# Debug proxy
istioctl proxy-config cluster <pod-name> -n <namespace>
```

## Next Steps

1. **Deploy minimal platform** for lab:
   ```bash
   cd ../gitops/bootstrap
   kubectl apply -f minimal-lab-apps.yaml
   ```

2. **Verify deployment**:
   ```bash
   argocd app list
   kubectl get pods -A
   ```

3. **Deploy applications**:
   ```bash
   cd ../applications
   ```

## References

- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [Kong Documentation](https://docs.konghq.com/)
- [Grafana LGTM Stack](https://grafana.com/oss/)
- [OPA Gatekeeper](https://open-policy-agent.github.io/gatekeeper/)
- [Kyverno](https://kyverno.io/)
