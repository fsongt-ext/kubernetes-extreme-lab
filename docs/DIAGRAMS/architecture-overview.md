# Architecture Overview

Comprehensive architecture diagrams for the Kubernetes platform.

## High-Level Architecture

```mermaid
graph TB
    subgraph "External"
        Users[Users/Clients]
        Internet[Internet]
    end

    subgraph "Ingress Layer"
        Kong[Kong Gateway<br/>North-South Traffic]
    end

    subgraph "Service Mesh"
        Istio[Istio<br/>East-West Traffic]
        Envoy[Envoy Proxies<br/>Sidecar Pattern]
    end

    subgraph "Platform Components"
        ArgoCD[ArgoCD<br/>GitOps]
        CertManager[cert-manager<br/>TLS Certificates]
        Kyverno[Kyverno<br/>Policy Engine]
        ArgoRollouts[Argo Rollouts<br/>Progressive Delivery]
    end

    subgraph "Observability Stack"
        Grafana[Grafana<br/>Visualization]
        Prometheus[Prometheus<br/>Metrics]
        Loki[Loki<br/>Logs]
        Tempo[Tempo<br/>Traces]
    end

    subgraph "Applications"
        DemoApp[Demo App]
        OtherApps[Other Applications]
    end

    subgraph "Data Plane"
        K3s[K3s Cluster<br/>Kubernetes]
    end

    Users --> Internet
    Internet --> Kong
    Kong --> Istio
    Istio --> Envoy
    Envoy --> DemoApp
    Envoy --> OtherApps

    ArgoCD -.->|Manages| Platform Components
    ArgoCD -.->|Manages| Applications
    ArgoCD -.->|Manages| Observability Stack

    DemoApp -.->|Metrics| Prometheus
    DemoApp -.->|Logs| Loki
    DemoApp -.->|Traces| Tempo

    Prometheus --> Grafana
    Loki --> Grafana
    Tempo --> Grafana

    Kyverno -.->|Enforces| DemoApp
    CertManager -.->|TLS Certs| Kong
    ArgoRollouts -.->|Controls| DemoApp

    style Kong fill:#ff9900
    style Istio fill:#466bb0
    style ArgoCD fill:#ff6d00
    style Grafana fill:#f46800
```

## Network Flow Diagram

```mermaid
sequenceDiagram
    participant User
    participant Kong
    participant IstioGateway as Istio Gateway
    participant IstioProxy as Istio Proxy
    participant DemoApp as Demo App
    participant Prometheus
    participant Loki

    User->>Kong: HTTPS Request
    Note over Kong: Rate Limiting<br/>Authentication<br/>CORS

    Kong->>IstioGateway: HTTP Request
    Note over IstioGateway: Gateway Rules<br/>Virtual Service Routing

    IstioGateway->>IstioProxy: mTLS Request
    Note over IstioProxy: Mutual TLS<br/>Retry Logic<br/>Circuit Breaker

    IstioProxy->>DemoApp: HTTP Request
    Note over DemoApp: Business Logic

    DemoApp-->>IstioProxy: Response
    IstioProxy-->>IstioGateway: Response
    IstioGateway-->>Kong: Response
    Kong-->>User: HTTPS Response

    IstioProxy->>Prometheus: Metrics (scrape)
    DemoApp->>Prometheus: App Metrics
    DemoApp->>Loki: Logs
    IstioProxy->>Tempo: Traces
```

## GitOps Flow

```mermaid
graph LR
    subgraph "Source Control"
        Git[Git Repository<br/>Source of Truth]
    end

    subgraph "CI/CD"
        GHA[GitHub Actions]
        Docker[Docker Registry]
    end

    subgraph "GitOps"
        ArgoCD[ArgoCD<br/>Sync Engine]
        AppOfApps[App-of-Apps<br/>Bootstrap]
    end

    subgraph "Kubernetes"
        Platform[Platform<br/>Components]
        Apps[Applications]
    end

    Developer[Developer] -->|Push Code| Git
    Git -->|Trigger| GHA
    GHA -->|Build Image| Docker
    GHA -->|Update GitOps| Git

    Git -->|Watch| ArgoCD
    ArgoCD -->|Deploy| AppOfApps
    AppOfApps -->|Create| Platform
    AppOfApps -->|Create| Apps

    Apps -.->|Health Status| ArgoCD
    Platform -.->|Health Status| ArgoCD

    style Git fill:#f05032
    style ArgoCD fill:#ff6d00
    style Docker fill:#2496ed
```

## Deployment Sync Waves

```mermaid
graph TD
    Wave0[Wave 0: Foundation<br/>cert-manager<br/>CRDs] --> Wave1[Wave 1: Core Platform<br/>ArgoCD]
    Wave1 --> Wave2[Wave 2: Networking Base<br/>istio-base]
    Wave2 --> Wave3[Wave 3: Networking Services<br/>istiod, Kong]
    Wave3 --> Wave4[Wave 4: Security<br/>Kyverno]
    Wave4 --> Wave5[Wave 5: Observability<br/>Grafana, Prometheus]
    Wave5 --> Wave6[Wave 6: Operations<br/>Argo Rollouts]
    Wave6 --> Wave10[Wave 10: Applications<br/>Demo App]

    style Wave0 fill:#4CAF50
    style Wave1 fill:#8BC34A
    style Wave2 fill:#CDDC39
    style Wave3 fill:#FFEB3B
    style Wave4 fill:#FFC107
    style Wave5 fill:#FF9800
    style Wave6 fill:#FF5722
    style Wave10 fill:#F44336
```

## Security Architecture

```mermaid
graph TB
    subgraph "Defense in Depth"
        subgraph "Layer 1: Network"
            NetworkPolicy[Network Policies<br/>Default Deny]
            Firewall[Firewall Rules]
        end

        subgraph "Layer 2: Mesh"
            mTLS[Mutual TLS<br/>Istio]
            AuthZ[Authorization<br/>Policies]
        end

        subgraph "Layer 3: Admission"
            OPA[OPA Gatekeeper<br/>Platform Policies]
            Kyverno[Kyverno<br/>App Policies]
        end

        subgraph "Layer 4: Runtime"
            PodSecurity[Pod Security<br/>Standards]
            Seccomp[Seccomp Profiles]
            AppArmor[AppArmor]
        end

        subgraph "Layer 5: Application"
            AuthN[Authentication]
            InputVal[Input Validation]
            SecCode[Secure Coding]
        end
    end

    NetworkPolicy --> mTLS
    Firewall --> mTLS
    mTLS --> OPA
    AuthZ --> OPA
    OPA --> PodSecurity
    Kyverno --> PodSecurity
    PodSecurity --> AuthN
    Seccomp --> AuthN
    AppArmor --> AuthN
    AuthN --> InputVal
    InputVal --> SecCode

    style NetworkPolicy fill:#f44336
    style mTLS fill:#ff9800
    style OPA fill:#ffc107
    style PodSecurity fill:#8bc34a
    style AuthN fill:#4caf50
```

## Observability Stack

```mermaid
graph TB
    subgraph "Data Sources"
        App[Applications]
        Istio[Istio Proxies]
        K8s[Kubernetes]
    end

    subgraph "Collection"
        OTel[OpenTelemetry<br/>Collector]
        Promtail[Promtail<br/>Log Agent]
    end

    subgraph "Storage"
        Prometheus[Prometheus<br/>Metrics]
        Loki[Loki<br/>Logs]
        Tempo[Tempo<br/>Traces]
    end

    subgraph "Visualization"
        Grafana[Grafana<br/>Dashboards]
    end

    subgraph "Alerting"
        Alertmanager[Alertmanager]
        Slack[Slack]
        PagerDuty[PagerDuty]
    end

    App -->|Metrics| Prometheus
    App -->|Logs| Promtail
    App -->|Traces| OTel

    Istio -->|Metrics| Prometheus
    Istio -->|Logs| Loki
    Istio -->|Traces| OTel

    K8s -->|Metrics| Prometheus

    Promtail -->|Forward| Loki
    OTel -->|Export| Tempo

    Prometheus --> Grafana
    Loki --> Grafana
    Tempo --> Grafana

    Prometheus --> Alertmanager
    Alertmanager --> Slack
    Alertmanager --> PagerDuty

    style Prometheus fill:#e6522c
    style Loki fill:#f5a623
    style Tempo fill:#f46800
    style Grafana fill:#f46800
```

## Canary Deployment Flow

```mermaid
graph LR
    subgraph "Initial State"
        Stable1[Stable v1.0<br/>100% Traffic]
    end

    subgraph "Step 1: Deploy Canary"
        Stable2[Stable v1.0<br/>80% Traffic]
        Canary1[Canary v1.1<br/>20% Traffic]
    end

    subgraph "Step 2: Analysis"
        Analysis[Metrics Analysis<br/>Error Rate<br/>Latency]
    end

    subgraph "Step 3: Increment"
        Stable3[Stable v1.0<br/>60% Traffic]
        Canary2[Canary v1.1<br/>40% Traffic]
    end

    subgraph "Step 4: Full Rollout"
        Canary3[Canary v1.1<br/>100% Traffic]
    end

    Stable1 --> Stable2
    Stable2 --> Analysis
    Canary1 --> Analysis
    Analysis -->|Pass| Stable3
    Analysis -->|Fail| Rollback[Rollback]
    Stable3 --> Canary3
    Canary2 --> Canary3
    Rollback --> Stable1

    style Stable1 fill:#4caf50
    style Canary1 fill:#ff9800
    style Analysis fill:#2196f3
    style Rollback fill:#f44336
```

## CI/CD Pipeline

```mermaid
graph TB
    subgraph "Development"
        Code[Source Code]
        Commit[Git Commit]
    end

    subgraph "Build Stage"
        Lint[Linting<br/>golangci-lint]
        Test[Unit Tests<br/>go test]
        Build[Build Image<br/>Docker]
    end

    subgraph "Security Stage"
        SAST[SAST<br/>Semgrep]
        SecretScan[Secret Scan<br/>Gitleaks]
        VulnScan[Vulnerability Scan<br/>Trivy]
        SBOM[SBOM Generation<br/>Syft]
    end

    subgraph "Artifact Stage"
        Sign[Image Signing<br/>Cosign]
        Push[Push to Registry<br/>GHCR]
    end

    subgraph "Deploy Stage"
        UpdateGitOps[Update GitOps<br/>Image Tag]
        ArgoSync[ArgoCD Sync]
    end

    subgraph "Validation Stage"
        Integration[Integration Tests]
        Smoke[Smoke Tests]
    end

    Code --> Commit
    Commit --> Lint
    Lint --> Test
    Test --> Build

    Build --> SAST
    Build --> SecretScan
    Build --> VulnScan
    Build --> SBOM

    SAST --> Sign
    SecretScan --> Sign
    VulnScan --> Sign
    SBOM --> Sign

    Sign --> Push
    Push --> UpdateGitOps
    UpdateGitOps --> ArgoSync
    ArgoSync --> Integration
    Integration --> Smoke

    style Build fill:#2196f3
    style VulnScan fill:#ff9800
    style Sign fill:#4caf50
    style ArgoSync fill:#ff6d00
```

## Node Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     K3s Node                            │
├─────────────────────────────────────────────────────────┤
│  Control Plane (Server Node)                           │
│  ┌──────────────────────────────────────────────────┐  │
│  │ kube-apiserver                                   │  │
│  │ kube-scheduler                                   │  │
│  │ kube-controller-manager                          │  │
│  │ etcd                                             │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  Data Plane                                            │
│  ┌──────────────────────────────────────────────────┐  │
│  │ kubelet                                          │  │
│  │ kube-proxy                                       │  │
│  │ containerd                                       │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  Pods                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐  │
│  │ Demo App    │  │ Grafana     │  │ ArgoCD       │  │
│  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌──────────┐ │  │
│  │ │App      │ │  │ │Grafana  │ │  │ │ArgoCD    │ │  │
│  │ │Container│ │  │ │Container│ │  │ │Server    │ │  │
│  │ └─────────┘ │  │ └─────────┘ │  │ └──────────┘ │  │
│  │ ┌─────────┐ │  │ ┌─────────┐ │  │              │  │
│  │ │Istio    │ │  │ │Istio    │ │  │              │  │
│  │ │Proxy    │ │  │ │Proxy    │ │  │              │  │
│  │ └─────────┘ │  │ └─────────┘ │  │              │  │
│  └─────────────┘  └─────────────┘  └──────────────┘  │
│                                                         │
│  CNI: Flannel                                          │
│  CSI: Local Path Provisioner                          │
└─────────────────────────────────────────────────────────┘
```

## Resource Hierarchy

```
Cluster (k3s-extreme-lab)
│
├── Namespace: argocd
│   ├── ArgoCD Server
│   ├── ArgoCD Application Controller
│   ├── ArgoCD Repo Server
│   └── Applications (CRDs)
│       ├── root-application
│       ├── platform-apps
│       ├── application-apps
│       └── [individual component apps]
│
├── Namespace: cert-manager
│   ├── cert-manager Controller
│   ├── cert-manager Webhook
│   └── Certificates (CRDs)
│
├── Namespace: istio-system
│   ├── istiod
│   ├── Gateway (CRDs)
│   ├── VirtualService (CRDs)
│   └── PeerAuthentication (CRDs)
│
├── Namespace: kyverno
│   ├── Kyverno Controller
│   ├── ClusterPolicies (CRDs)
│   └── PolicyReports (CRDs)
│
├── Namespace: observability
│   ├── Grafana
│   ├── Prometheus
│   ├── Loki
│   └── Tempo
│
└── Namespace: demo
    ├── Demo App (Deployment/Rollout)
    │   ├── Pod (app container + istio-proxy)
    │   ├── Service
    │   ├── VirtualService
    │   └── ServiceMonitor
    └── NetworkPolicy (auto-generated by Kyverno)
```

## References

- [Kubernetes Architecture](https://kubernetes.io/docs/concepts/architecture/)
- [Istio Architecture](https://istio.io/latest/docs/ops/deployment/architecture/)
- [ArgoCD Architecture](https://argo-cd.readthedocs.io/en/stable/operator-manual/architecture/)
- [Platform Engineering](https://platformengineering.org/)
