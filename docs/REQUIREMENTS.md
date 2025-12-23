# 🏗️ Enterprise Kubernetes & DevSecOps Platform Lab

## TL;DR – Complete Technology Stack

---

### Kubernetes & Infrastructure

- **Engine**: K3s/K3d (2 vCPU, 8 GB RAM)
- **Authentication**: Okta (OIDC/SAML)
- **Authorization**: Kubernetes RBAC
- **IaC**: Terraform + Ansible

---

### DevSecOps & CI/CD (GitHub Actions)

- **SAST**: Semgrep
- **Secrets**: Gitleaks
- **Dependencies**: Trivy
- **Build**: Docker buildx (multi-platform)
- **Image Scan**: Trivy
- **DAST**: OWASP ZAP (pre-prod)
- **Signing**: Cosign
- **SBOM**: Syft

---

### Artifacts & Registries

- **Container Registry**: Docker Hub
- **SBOM Storage**: CI artifacts

---

### GitOps & Deployment

- **Controller**: Argo CD
- **Package Manager**: Helm
- **Progressive Delivery**: Argo Rollouts (canary/blue-green)

---

### Networking & Traffic

- **North-South**: Kong API Gateway + Controller
- **East-West**: Istio (sidecar/ambient with mTLS)
- **Certificates**: cert-manager

---

### Policy & Governance

- **Admission Control**: OPA Gatekeeper (platform team)
- **Policy as Code**: Kyverno (application team)

---

### Observability (LGTM)

- **Metrics**: OpenTelemetry → Mimir → Grafana
- **Traces**: OpenTelemetry → Tempo → Object Storage → Grafana
- **Logs**: Alloy → Loki → Grafana
- **Visualization**: Grafana

---

### Security & Runtime

- **Runtime Detection**: Falco
- **Alerts**: Grafana
- **Secrets**: Vault + Vault Operator

---

### Resilience & Operations

- **Scaling**: HPA
- **Chaos Engineering**: Istio built-ins + Chaos Mesh
- **Backup/Restore**: Velero
- **FinOps**: OpenCost

---

### Platform Utilities

- **Message Queue**: Kafka (Strimzi)
- **Cache**: Redis (Operator)
- **Database**: PostgreSQL (Operator)

---

## 1. Overview

This lab builds a **realistic, enterprise-ready Kubernetes platform** on constrained infrastructure, demonstrating **how modern enterprises design, secure, deploy, operate, and govern microservices**.

The lab follows **real production patterns**, not tutorials:

- GitOps-first
- Security by default
- Clear ownership boundaries
- Observability-driven operations
- Failure-aware design

> Audience: Platform Engineers, DevSecOps Engineers, Senior Backend Engineers

> **Scope**: Single-node (lab-scale), enterprise-architecture (production-grade concepts)

---

## 2. High-Level Goals

- Build a **secure software supply chain**
- Enforce **policy & governance** centrally
- Separate **North–South vs East–West traffic**
- Apply **Zero Trust** principles
- Use **Git as the control plane**
- Operate with **observability, resilience, and cost awareness**

---

## 3. Infrastructure Constraints (Intentional)

| Resource | Value |
| --- | --- |
| Environment | Single VM |
| CPU | 2 vCPU |
| RAM | 8 GB |
| Kubernetes | K3s / K3d |
| Repos | Public GitHub |
| CI | GitHub Actions (free tier) |

> The lab intentionally mirrors real enterprise design under limited resources, forcing correct architectural choices.

---

## 4. Core Technology Stack

### 4.1 Platform & Infrastructure

| Category | Tool |
| --- | --- |
| Kubernetes Engine | K3s / K3d |
| Provisioning | Terraform |
| Configuration | Ansible |
| Authentication | Okta (OIDC) |
| Authorization | Kubernetes RBAC |

### 4.2 CI / DevSecOps (GitHub Actions)

| Stage | Tool |
| --- | --- |
| SAST | Semgrep |
| Secrets Scan | Gitleaks |
| Dependency Scan | Trivy |
| Build | Docker buildx (multi-arch) |
| Image Scan | Trivy |
| DAST (pre-prod) | OWASP ZAP |
| Image Signing | Cosign |
| SBOM | Syft |

### 4.3 Artifact & Registry

| Purpose | Tool |
| --- | --- |
| Container Registry | DockerHub |
| SBOM Storage | CI artifacts |

---

---

---

### 4.4 GitOps & Deployment

| Capability | Tool |
| --- | --- |
| GitOps Controller | Argo CD |
| Packaging | Helm |
| Progressive Delivery | Argo Rollouts |

### 4.5 Networking & Traffic Management

| Direction | Tool |
| --- | --- |
| North–South | Kong API Gateway + Controller |
| East–West | Istio (sidecar → optional ambient) |
| Certificates | cert-manager |
| CNI | Cilium (implicit via K3s or optional) |

### 4.6 Policy, Security & Governance

| Layer | Tool |
| --- | --- |
| Admission Control | OPA Gatekeeper |
| Policy as YAML | Kyverno |
| CI Policy Checks | Conftest / policy jobs |

---

---

---

### 4.7 Runtime & Operations

| Capability | Tool |
| --- | --- |
| Autoscaling | HPA |
| Runtime Security | Falco |
| Alerts | Grafana |
| Secrets | Vault + Vault Operator |
| Chaos Engineering | Chaos Mesh + Istio faults |
| Backup & Restore | Velero |
| FinOps | OpenCost |

### 4.8 Observability (LGTM)

| Signal | Flow |
| --- | --- |
| Metrics | Otel → Mimir → Grafana |
| Traces | Otel → Tempo → Object Storage → Grafana |
| Logs | Alloy → Loki → Grafana |
| Visualization | Grafana |

### 4.9 Platform Utilities

- Kafka (Strimzi)
- Redis (Operator-based)

---

## 5. Responsibility & Ownership Model

| Domain | Owner |
| --- | --- |
| Infrastructure | Platform Team |
| Kubernetes & Mesh | Platform Team |
| CI Pipelines | Platform + Security |
| Policies | Security Team |
| Microservices | Application Teams |
| Observability | SRE |
| Secrets | Platform + Security |

> Tool overlap is intentional and controlled via ownership.

---

## 6. Repository Structure

### 6.1 Application Repository

```text
app-service/
├── src/
├── Dockerfile
├── openapi.yaml
├── helm/
├── security/
└── .github/workflows/ci.yaml
```

### 6.2 Platform Repository

```text
platform/
├── terraform/
├── ansible/
├──cluster/
│   ├── istio/
│   ├── kong/
│   ├── opa/
│   ├── observability/
│   └──security/
```

### 6.3 GitOps Repository

```text
gitops/
├── dev/
├── staging/
└── prod/
    ├── apps/
    ├── gateways/
    ├── policies/
    └── rollouts/
```

---

## 7. End-to-End Flows

### 7.1 CI / Supply Chain Flow

```text
gitpush
 →GitHubActions
   →SAST/Secrets/DependencyScan
   →BuildImage
   →ImageScan
   →GenerateSBOM
   →SignImage
 →PushtoDockerHub
 →GitOpsP
```

### 7.2 Deployment (Control Plane)

```text
GitOps repo change
 → Argo CDsync
   → OPA Gatekeeper (admission)
   → Helm deploy
   → Argo Rollouts (canary/blue-green)

```

---

### 7.3 Runtime Request Flow

```text
Client
 → Kong API Gateway
 → Istio Ingress
 → ServiceA (sidecar)
 → ServiceB (sidecar)
 → Kafka / Redis / DB

```

### 7.4 Observability Flow

```text
App / Envoy
 → OpenTelemetry
 → Mimir / Tempo / Loki
 → Grafana Dashboards & Alerts
```

### 7.5 Security Flow

```text
Policy violation → OPA (block)
Runtime anomaly → Falco → Grafana alert
```

---

## 8. Scaling & Resilience

### Scaling

- HPA (CPU, memory, custom metrics)
- Service-aware scaling
- Sidecar resource tuning

### Resilience

- Istio retries, timeouts, circuit breakers
- Graceful shutdown
- Canary auto-rollback

---

## 9. Deployment Strategies

- Rolling updates (baseline)
- Canary deployments (default)
- Blue-green deployments (riskier changes)
- Feature flags (deploy ≠ release)

## 10. Chaos & Failure Testing

- Pod failures
- Network latency
- Error injection
- Validate recovery (MTTR)

---

## 11. Backup, DR & Recovery

- Namespace-level backup with Velero
- Restore drills
- GitOps-based recovery

---

## 12. FinOps & Cost Awareness

- Resource request vs usage analysis
- Sidecar cost visibility
- Namespace cost allocation

---

## **13. Lab Phases & Timeline**

### Phase 1 – Foundations (Week 1)

- Terraform VM
- Ansible hardening
- K3s install
- RBAC + OIDC

### Phase 2 – CI & Supply Chain (Week 2)

- GitHub Actions
- Security scans
- Image signing
- SBOMs

### Phase 3 – GitOps (Week 3)

- Argo CD
- Environment promotion
- Sync windows

### Phase 4 – Networking (Week 4)

- Kong Gateway
- Istio (minimal profile)
- TLS automation

### Phase 5 – Security & Policy (Week 5)

- OPA Gatekeeper
- Kyverno
- Runtime security

### Phase 6 – Observability (Week 6)

- LGTM stack
- Golden signals
- Alerting

### Phase 7 – Scaling & Resilience (Week 7)

- HPA
- Canary deployments
- Chaos experiments

### Phase 8 – Enterprise Ops (Week 8)

- Backup & restore
- FinOps
- Incident simulation
- Postmortem

---

## 14. What This Lab Teaches (Key Outcome)

> How real enterprises design platforms — not just how tools work.

This lab covers:

- Architecture
- Security
- Operations
- Governance
- Human & org constraints

---

## 15. Final Statement

This lab is **enterprise-ready by design**, limited only by **hardware scale, not architectural quality**.

If deployed on larger infrastructure, **no design changes are required** — only scaling parameters.
