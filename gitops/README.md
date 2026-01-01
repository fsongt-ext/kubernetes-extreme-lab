# GitOps - Source of Truth

This directory contains all ArgoCD Application manifests following the **App-of-Apps** pattern.

## Directory Structure

```
gitops/
├── bootstrap/                      # Root applications (App-of-Apps)
│   ├── root-application.yaml     # Single entry point
│   ├── platform-apps.yaml         # Platform components app-of-apps
│   └── application-apps.yaml      # Application workloads app-of-apps
│
├── projects/                       # ArgoCD AppProjects (RBAC)
│   ├── platform-project.yaml     # Platform team permissions
│   └── applications-project.yaml  # App team permissions
│
└── environments/                   # Environment-specific configs
    ├── lab/                       # Lab environment
    │   ├── platform/              # Platform Argo Applications
    │   │   ├── cert-manager.yaml
    │   │   ├── argocd.yaml
    │   │   ├── istio-base.yaml
    │   │   ├── istiod.yaml
    │   │   ├── kong.yaml
    │   │   ├── kyverno.yaml
    │   │   ├── grafana.yaml
    │   │   └── argo-rollouts.yaml
    │   └── applications/          # App Argo Applications
    │       └── demo-app.yaml
    │
    ├── dev/                       # Dev environment
    ├── staging/                   # Staging environment
    └── prod/                      # Production environment
```

## App-of-Apps Pattern

This repository uses the **App-of-Apps pattern** for managing applications hierarchically:

```
root-application
├── platform-apps (manages platform components)
│   ├── cert-manager
│   ├── argocd
│   ├── istio-base
│   ├── istiod
│   ├── kong
│   ├── kyverno
│   ├── grafana
│   └── argo-rollouts
│
└── application-apps (manages workloads)
    └── demo-app
```

### Benefits

1. **Single Entry Point**: Deploy entire platform with one command
2. **Hierarchical Management**: Parent apps manage child apps
3. **Selective Sync**: Sync entire categories or individual apps
4. **Dependency Management**: Sync waves ensure proper ordering
5. **Separation of Concerns**: Platform vs Application teams

## Deployment Order (Sync Waves)

Applications deploy in order using sync waves:

```
Wave -1: Root Application (bootstrap)
Wave 0:  Foundation (cert-manager, sealed-secrets)
Wave 1:  Core Platform (argocd)
Wave 2:  Networking (istio-base)
Wave 3:  Networking (istiod, kong)
Wave 4:  Security (kyverno, gatekeeper)
Wave 5:  Observability (grafana, loki, mimir)
Wave 6:  Operations (argo-rollouts, velero)
Wave 10: Applications (demo-app)
```

Sync waves ensure:
- CRDs deploy before CRs
- Dependencies resolve correctly
- Platform ready before apps deploy

## Initial Setup

### Prerequisites

1. **K3s cluster** running (see `infrastructure/` directory)
2. **kubectl** configured
3. **Argo CD CLI** installed (optional)

### Install Argo CD

```bash
# Create namespace
kubectl create namespace argocd

# Install Argo CD (using platform helm chart)
helm install argocd platform/core/argocd \
  -f platform/core/argocd/values.yaml \
  -f platform/core/argocd/values-lab.yaml \
  --namespace argocd

# Wait for Argo CD to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

### Bootstrap Platform

```bash
# Option 1: Deploy root application (recommended)
kubectl apply -f gitops/bootstrap/root-application.yaml

# Option 2: Deploy AppProjects first, then root
kubectl apply -f gitops/projects/
kubectl apply -f gitops/bootstrap/root-application.yaml
```

This single command deploys:
- All platform components (Istio, Kong, Kyverno, Grafana, etc.)
- All application workloads (demo-app, etc.)
- In correct dependency order via sync waves

### Access Argo CD UI

```bash
# Port-forward to Argo CD server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open https://localhost:8080
# Username: admin
# Password: (from secret above)
```

## Managing Applications

### View Application Status

```bash
# Using kubectl
kubectl get applications -n argocd

# Using Argo CD CLI
argocd app list

# Get specific app details
argocd app get demo-app
```

### Manual Sync

```bash
# Sync specific app
argocd app sync demo-app

# Sync with prune (remove resources)
argocd app sync demo-app --prune

# Hard refresh (ignore cache)
argocd app sync demo-app --force
```

### Add New Platform Component

1. Create Helm chart/manifests in `platform/`
2. Create Argo Application in `gitops/environments/lab/platform/`
3. Set appropriate sync wave
4. Commit and push - Argo CD auto-syncs

```yaml
# Example: gitops/environments/lab/platform/new-component.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: new-component
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "5"
spec:
  project: platform
  source:
    repoURL: git@github.com:TrungHQ-02/kubernetes-extreme-lab
    targetRevision: main
    path: platform/new-component
  destination:
    server: https://kubernetes.default.svc
    namespace: new-component
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Add New Application

```bash
# Create Helm chart in applications/helm-charts/
# Create Argo Application manifest
cat > gitops/environments/lab/applications/new-app.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: new-app
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "10"
spec:
  project: applications
  source:
    repoURL: https://github.com/yourusername/kubernetes-extreme-lab
    targetRevision: main
    path: applications/helm-charts/new-app
    helm:
      valueFiles:
        - values.yaml
        - values-lab.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: new-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

# Commit and push - auto-syncs via application-apps parent
git add gitops/environments/lab/applications/new-app.yaml
git commit -m "Add new-app to lab environment"
git push
```

## Environment Promotion

### Lab → Dev → Staging → Prod

Each environment has identical structure but different configurations:

```
environments/
├── lab/                    # Resource-constrained, single replica
├── dev/                    # Similar to lab, dev features
├── staging/                # Production-like, HA enabled
└── prod/                   # Full HA, strict policies
```

### Promotion Workflow

```bash
# 1. Deploy to lab (auto-synced)
git commit -m "feat: new feature"
git push origin main

# 2. Validate in lab
kubectl get pods -n demo
argocd app get demo-app

# 3. Promote to dev (GitOps approach)
# Update image tag in gitops/environments/dev/applications/demo-app.yaml
sed -i 's/image.tag=1.0.0/image.tag=1.0.1/' \
  gitops/environments/dev/applications/demo-app.yaml

git commit -m "promote: demo-app 1.0.1 to dev"
git push

# 4. After validation, promote to staging
# 5. After approval, promote to prod
```

### Image Tag Management

**Option 1: Manual (GitOps Pull)**
- CI builds image with SHA tag
- Operator updates gitops repo with new tag
- Argo CD syncs automatically

**Option 2: Automated (GitOps Push)**
- CI builds and pushes image
- CI updates gitops repo via PR
- PR approved and merged
- Argo CD syncs

**Option 3: Argo CD Image Updater**
- Monitors image registry
- Auto-updates gitops repo
- Creates PR or commits directly

## AppProjects (RBAC)

### Platform Project

**Who:** Platform Team
**Permissions:** Full cluster access
**Resources:** All Kubernetes resources
**Namespaces:** argocd, istio-system, observability, etc.

```bash
kubectl get appproject platform -n argocd -o yaml
```

### Applications Project

**Who:** Application Teams
**Permissions:** Namespace-scoped only
**Resources:** Deployments, Services, ConfigMaps, etc.
**Restricted:** No ClusterRoles, no cluster resources

```bash
kubectl get appproject applications -n argocd -o yaml
```

### Create Custom Project

```bash
cat > gitops/projects/team-alpha-project.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-alpha
  namespace: argocd
spec:
  description: Team Alpha applications
  sourceRepos:
    - 'https://github.com/team-alpha/*'
  destinations:
    - namespace: 'team-alpha-*'
      server: https://kubernetes.default.svc
  namespaceResourceWhitelist:
    - group: 'apps'
      kind: Deployment
    - group: ''
      kind: Service
EOF

kubectl apply -f gitops/projects/team-alpha-project.yaml
```

## Sync Policies

### Automated Sync

```yaml
syncPolicy:
  automated:
    prune: true        # Delete resources not in Git
    selfHeal: true     # Auto-sync on drift detection
    allowEmpty: false  # Prevent empty sync
```

### Manual Sync

```yaml
syncPolicy:
  automated: null  # Require manual sync approval
```

### Sync Windows

Prevent deployments during business hours:

```yaml
syncWindows:
  - kind: deny
    schedule: '0 8-18 * * 1-5'  # Mon-Fri 8am-6pm
    duration: 10h
    applications:
      - '*-prod'
```

## Health Assessment

Argo CD monitors resource health:

```yaml
health:
  status: Healthy|Progressing|Degraded|Suspended|Missing|Unknown
```

Custom health checks for CRDs:

```yaml
# In argocd-cm ConfigMap
resource.customizations: |
  argoproj.io/Rollout:
    health.lua: |
      -- Custom health check logic
      if obj.status.phase == "Healthy" then
        return {status = "Healthy"}
      end
```

## Troubleshooting

### Application Not Syncing

```bash
# Check application status
argocd app get demo-app

# Check sync status
kubectl get application demo-app -n argocd -o yaml

# Manual sync
argocd app sync demo-app --force

# Check for errors
argocd app logs demo-app
```

### Sync Wave Issues

```bash
# Verify sync waves
kubectl get applications -n argocd \
  -o custom-columns=NAME:.metadata.name,WAVE:.metadata.annotations."argocd\.argoproj\.io/sync-wave"

# Force sync in order
for app in cert-manager argocd istio-base istiod kong; do
  argocd app sync $app --force
  argocd app wait $app --health
done
```

### Out-of-Sync Resources

```bash
# View diff
argocd app diff demo-app

# Ignore specific differences
# Add to Application manifest:
ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
      - /spec/replicas  # Managed by HPA
```

### Webhook Certificate Issues

```bash
# Refresh webhook CA bundles
kubectl delete mutatingwebhookconfiguration <name>
kubectl delete validatingwebhookconfiguration <name>

# Argo CD will recreate with correct certs
```

## Best Practices

### 1. Sync Waves

- **Use ascending order**: 0, 1, 2, 3...
- **CRDs first**: Sync wave 0
- **Dependencies respect**: istio-base before istiod
- **Applications last**: Wave 10+

### 2. Automated Sync

- **Enable for dev/staging**: Fast feedback
- **Manual for production**: Approval gates
- **prune: true**: Keep Git as source of truth
- **selfHeal: true**: Auto-correct drift

### 3. Project Boundaries

- **Platform team**: Full cluster access
- **App teams**: Namespace-scoped only
- **Least privilege**: Grant minimum required permissions

### 4. Git Workflow

- **Feature branches**: For changes
- **Pull requests**: For reviews
- **Protected main**: Require approvals
- **Signed commits**: Security

### 5. Image Tags

- **Never use `:latest`**: Not GitOps-friendly
- **Use immutable tags**: SHA or version
- **Semantic versioning**: v1.2.3
- **Tag in Git**: Track what's deployed

## CI/CD Integration

### GitHub Actions Example

```yaml
# .github/workflows/deploy.yaml
- name: Update GitOps repository
  run: |
    IMAGE_TAG=${{ github.sha }}

    # Clone gitops repo
    git clone git@github.com:TrungHQ-02/kubernetes-extreme-lab
    cd kubernetes-extreme-lab

    # Update image tag
    sed -i "s/image.tag=.*/image.tag=${IMAGE_TAG}/" \
      gitops/environments/dev/applications/demo-app.yaml

    # Commit and push
    git add .
    git commit -m "deploy: update demo-app to ${IMAGE_TAG}"
    git push
```

## Monitoring & Alerts

### Prometheus Metrics

Argo CD exports metrics:
- `argocd_app_health_status`
- `argocd_app_sync_total`
- `argocd_app_sync_status`

### Grafana Dashboard

Import Argo CD dashboard: https://grafana.com/grafana/dashboards/14584

### Notifications

Configure Slack/email notifications:

```yaml
# In Application annotations
notifications.argoproj.io/subscribe.on-deployed.slack: "platform-deployments"
notifications.argoproj.io/subscribe.on-health-degraded.slack: "platform-alerts"
```

## References

- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [App-of-Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [Sync Waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/)
- [AppProjects](https://argo-cd.readthedocs.io/en/stable/user-guide/projects/)
- [GitOps Principles](https://opengitops.dev/)
