# ADR 002: GitOps with App-of-Apps Pattern

**Status:** Accepted
**Date:** 2023-12-23
**Deciders:** Platform Architecture Team
**Technical Story:** ArgoCD deployment strategy

## Context

We need a scalable GitOps deployment strategy that:
- Bootstraps the entire platform from a single entry point
- Manages dependencies between components (e.g., cert-manager before Istio)
- Separates platform and application concerns
- Supports multiple environments (lab, dev, staging, prod)

## Decision

We will implement ArgoCD with the **App-of-Apps pattern** and sync waves for dependency management.

### Architecture

```
root-application (sync wave -1)
├── platform-apps (manages platform components)
│   ├── cert-manager (wave 0)
│   ├── argocd (wave 1)
│   ├── istio-base (wave 2)
│   ├── istiod (wave 3)
│   ├── kong (wave 3)
│   ├── kyverno (wave 4)
│   ├── grafana (wave 5)
│   └── argo-rollouts (wave 6)
│
└── application-apps (manages workloads)
    └── demo-app (wave 10)
```

### Sync Waves

Sync waves ensure proper deployment order:

```
Wave -1: Bootstrap (root application)
Wave 0:  Foundation (cert-manager, CRDs)
Wave 1:  Core Platform (ArgoCD)
Wave 2:  Networking Base (istio-base CRDs)
Wave 3:  Networking Services (istiod, Kong)
Wave 4:  Security (Kyverno, OPA Gatekeeper)
Wave 5:  Observability (Grafana, Prometheus, Loki)
Wave 6:  Operations (Argo Rollouts, Velero)
Wave 10: Applications (demo-app, other workloads)
```

### AppProjects (RBAC)

**Platform Project:**
- Full cluster access
- Platform team permissions
- Can create ClusterRoles, CRDs, webhooks

**Applications Project:**
- Namespace-scoped only
- Application team permissions
- No cluster-wide resources

## Rationale

### Advantages

1. **Single Entry Point**
   ```bash
   kubectl apply -f gitops/bootstrap/root-application.yaml
   # Deploys entire platform
   ```

2. **Dependency Management**
   - Sync waves ensure CRDs before CRs
   - Platform components ready before applications
   - Automatic retry on transient failures

3. **Hierarchical Management**
   - Platform team controls platform-apps
   - App teams control application-apps within their project
   - Clear ownership boundaries

4. **Selective Sync**
   - Sync entire platform: `argocd app sync root-application`
   - Sync platform only: `argocd app sync platform-apps`
   - Sync single app: `argocd app sync demo-app`

5. **Environment Promotion**
   ```
   gitops/environments/
   ├── lab/         # Single replica, minimal resources
   ├── dev/         # Development features
   ├── staging/     # Production-like
   └── prod/        # HA, strict policies
   ```

### Disadvantages (Mitigated)

1. **Complexity**
   - Mitigation: Clear documentation, templates, examples
   - Benefit outweighs learning curve

2. **Cascading Failures**
   - Mitigation: Sync waves prevent dependency failures
   - Health checks and automated rollbacks

3. **Long Initial Sync**
   - Mitigation: Parallel sync where possible
   - Status monitoring in ArgoCD UI

## Implementation Details

### Root Application

```yaml
# gitops/bootstrap/root-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-application
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
spec:
  project: platform
  source:
    repoURL: https://github.com/user/kubernetes-extreme-lab
    targetRevision: main
    path: gitops/bootstrap
    directory:
      include: '{platform-apps.yaml,application-apps.yaml}'
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Platform Apps

```yaml
# gitops/bootstrap/platform-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-apps
  namespace: argocd
spec:
  project: platform
  source:
    repoURL: https://github.com/user/kubernetes-extreme-lab
    targetRevision: main
    path: gitops/environments/lab/platform
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Component Application

```yaml
# gitops/environments/lab/platform/cert-manager.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cert-manager
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "0"  # Deploy first
spec:
  project: platform
  source:
    repoURL: https://github.com/user/kubernetes-extreme-lab
    targetRevision: main
    path: platform/core/cert-manager
    helm:
      valueFiles:
        - values.yaml
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

## Consequences

### Positive

- **Declarative platform state** - Git is source of truth
- **Automated deployments** - Push to Git triggers sync
- **Drift detection** - ArgoCD auto-corrects manual changes
- **Audit trail** - All changes tracked in Git history
- **Disaster recovery** - Rebuild entire platform from Git

### Negative

- **Initial complexity** - Requires understanding of ArgoCD concepts
- **Debug complexity** - Multiple layers of applications
- **Sync timing** - May need manual intervention for timing issues

### Neutral

- **Git workflow** - Requires PR-based workflow for changes
- **Permissions** - AppProjects enforce RBAC strictly
- **Testing** - Changes must be tested before merge

## Alternatives Considered

### Helm Umbrella Chart

**Pros:**
- Single Helm release
- Familiar Helm workflow

**Cons:**
- No dependency management
- All-or-nothing upgrades
- No per-component RBAC

**Rejected because:** Lacks dependency management and fine-grained control.

### Flux CD

**Pros:**
- Similar GitOps capabilities
- Lightweight

**Cons:**
- Less mature App-of-Apps pattern
- Smaller community
- Fewer integrations

**Rejected because:** ArgoCD has better App-of-Apps support and UI.

### Manual kubectl apply

**Pros:**
- Simple, direct

**Cons:**
- No drift detection
- No rollback
- No audit trail
- Manual dependency management

**Rejected because:** Not scalable for production platform.

## References

- [ArgoCD App-of-Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [Sync Waves Documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/)
- [ArgoCD Projects](https://argo-cd.readthedocs.io/en/stable/user-guide/projects/)
- [GitOps Principles](https://opengitops.dev/)

## Revision History

| Date | Version | Changes |
|------|---------|---------|
| 2023-12-23 | 1.0 | Initial decision |
