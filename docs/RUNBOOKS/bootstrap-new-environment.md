# Runbook: Bootstrap New Environment

**Purpose:** Deploy the full Kubernetes platform from scratch
**Audience:** Platform Engineers
**Estimated Time:** 60-90 minutes
**Risk Level:** Low (new environment)

## Prerequisites

- [ ] Access to target infrastructure (bare metal, VM, cloud)
- [ ] Git repository access
- [ ] kubectl configured
- [ ] Terraform and Ansible installed
- [ ] SSH keys configured

## Step 1: Provision Infrastructure

### 1.1 Configure Environment

```bash
cd infrastructure/terraform/environments/<env>

# Edit variables
vim terraform.tfvars
```

**Variables to configure:**
- `cluster_name`
- `node_count`
- `node_cpu`
- `node_memory`
- `network_cidr`

### 1.2 Run Terraform

```bash
# Initialize
terraform init

# Plan
terraform plan -out=tfplan

# Apply
terraform apply tfplan
```

**Expected Output:**
```
Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

Outputs:
cluster_endpoint = "https://10.0.1.10:6443"
kubeconfig_path = "/home/user/.kube/config"
```

**Validation:**
```bash
kubectl get nodes
# Should show all nodes in Ready state
```

### 1.3 Configure with Ansible

```bash
cd infrastructure/ansible

# Update inventory
vim inventory/<env>/hosts.yaml

# Run playbook
ansible-playbook -i inventory/<env>/hosts.yaml playbooks/k3s-install.yaml
```

**Expected Output:**
```
PLAY RECAP ***************
k3s-node-01    : ok=45   changed=12   unreachable=0    failed=0
```

**Validation:**
```bash
kubectl get pods -n kube-system
# All system pods should be Running
```

## Step 2: Install ArgoCD

### 2.1 Install via Helm

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
helm install argocd platform/core/argocd \
  -f platform/core/argocd/values.yaml \
  -f platform/core/argocd/values-<env>.yaml \
  --namespace argocd
```

**Expected Output:**
```
NAME: argocd
NAMESPACE: argocd
STATUS: deployed
```

### 2.2 Wait for ArgoCD to be Ready

```bash
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-application-controller -n argocd
```

### 2.3 Get Admin Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

**Save this password securely!**

### 2.4 Access ArgoCD UI

```bash
# Port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Open in browser
open https://localhost:8080

# Login: admin / <password-from-above>
```

## Step 3: Bootstrap Platform with GitOps

### 3.1 Apply AppProjects

```bash
kubectl apply -f gitops/projects/platform-project.yaml
kubectl apply -f gitops/projects/applications-project.yaml
```

**Validation:**
```bash
kubectl get appproject -n argocd
# Should show platform and applications projects
```

### 3.2 Deploy Root Application

```bash
kubectl apply -f gitops/bootstrap/root-application.yaml
```

**Expected Output:**
```
application.argoproj.io/root-application created
```

### 3.3 Monitor Deployment

```bash
# Watch applications
watch kubectl get applications -n argocd

# Or use ArgoCD CLI
argocd app list
```

**Expected Progression:**

1. `root-application` (wave -1) - Synced
2. `platform-apps` (wave 0) - Syncing
3. `cert-manager` (wave 0) - Progressing
4. `argocd` (wave 1) - Progressing
5. ... (continues through all sync waves)

### 3.4 Wait for Sync Completion

```bash
# Wait for all apps to be healthy
argocd app wait root-application --health --timeout 1800

# Check status
argocd app get root-application --show-operation
```

**Expected Status:**
```
Name:               root-application
Health Status:      Healthy
Sync Status:        Synced
```

## Step 4: Validate Platform Components

### 4.1 Check All Applications

```bash
argocd app list

# Or with kubectl
kubectl get applications -n argocd -o custom-columns=\
NAME:.metadata.name,\
SYNC:.status.sync.status,\
HEALTH:.status.health.status
```

**Expected Output:**
```
NAME              SYNC    HEALTH
root-application  Synced  Healthy
platform-apps     Synced  Healthy
cert-manager      Synced  Healthy
argocd            Synced  Healthy
istio-base        Synced  Healthy
istiod            Synced  Healthy
kong              Synced  Healthy
kyverno           Synced  Healthy
grafana           Synced  Healthy
argo-rollouts     Synced  Healthy
application-apps  Synced  Healthy
demo-app          Synced  Healthy
```

### 4.2 Verify Namespaces

```bash
kubectl get namespaces

# Expected namespaces:
# - argocd
# - cert-manager
# - istio-system
# - kyverno
# - observability
# - argo-rollouts
# - demo
```

### 4.3 Check Pod Health

```bash
# Check all pods
kubectl get pods -A

# Should see all pods Running or Completed
# No CrashLoopBackOff or Error states
```

### 4.4 Verify Istio Mesh

```bash
# Check istiod
kubectl get pods -n istio-system

# Verify mTLS
kubectl get peerauthentication -n istio-system

# Check sidecars injected
kubectl get pods -n demo -o jsonpath='{.items[*].spec.containers[*].name}' | grep istio-proxy
```

### 4.5 Test Demo Application

```bash
# Port-forward to demo-app
kubectl port-forward svc/demo-app -n demo 8081:8080 &

# Health check
curl http://localhost:8081/health
# Expected: {"status":"ok"}

# Metrics
curl http://localhost:8081/metrics | grep http_requests_total
```

## Step 5: Configure Observability

### 5.1 Access Grafana

```bash
# Port-forward
kubectl port-forward svc/grafana -n observability 3000:80 &

# Default credentials: admin / admin (change on first login)
open http://localhost:3000
```

### 5.2 Import Dashboards

1. Navigate to Dashboards → Import
2. Import ArgoCD dashboard: `14584`
3. Import Istio dashboard: `7645`
4. Import Kyverno dashboard: `16814`

### 5.3 Verify Prometheus Targets

```bash
# Port-forward Prometheus
kubectl port-forward svc/prometheus -n observability 9090:9090 &

# Check targets
open http://localhost:9090/targets

# Should see:
# - kubernetes-apiservers (up)
# - kubernetes-nodes (up)
# - kubernetes-pods (up)
# - demo-app (up)
```

## Step 6: Security Validation

### 6.1 Check Kyverno Policies

```bash
kubectl get clusterpolicy

# Verify policies are active
kubectl describe clusterpolicy disallow-default-namespace
```

### 6.2 Test Policy Enforcement

```bash
# Try to create pod in default namespace (should fail)
kubectl run test --image=nginx -n default

# Expected: Error from server (Forbidden)
```

### 6.3 Check NetworkPolicies

```bash
kubectl get networkpolicy -A

# Each namespace should have a NetworkPolicy
```

### 6.4 Verify Certificate Manager

```bash
kubectl get certificates -A
kubectl get certificaterequests -A

# Check webhook
kubectl get validatingwebhookconfiguration cert-manager-webhook
```

## Step 7: Documentation and Handoff

### 7.1 Document Cluster Info

Create `docs/<env>-cluster-info.md`:

```markdown
# <ENV> Cluster Information

**Cluster Name:** <name>
**Kubernetes Version:** <version>
**Node Count:** <count>
**Bootstrap Date:** <date>
**ArgoCD URL:** https://<url>
**Grafana URL:** https://<url>

## Credentials

- ArgoCD admin password: [stored in 1Password]
- Grafana admin password: [stored in 1Password]
```

### 7.2 Save Kubeconfig

```bash
# Backup kubeconfig
cp ~/.kube/config ~/backups/kubeconfig-<env>-$(date +%Y%m%d).yaml

# Store securely (1Password, AWS Secrets Manager, etc.)
```

### 7.3 Update Inventory

Add to `docs/cluster-inventory.md`:

```markdown
| Environment | Endpoint | Nodes | Created | Status |
|-------------|----------|-------|---------|--------|
| <env> | https://<ip>:6443 | 3 | 2023-12-23 | Active |
```

## Troubleshooting

### Issue: Terraform fails with "resource already exists"

**Solution:**
```bash
# Import existing resource
terraform import <resource_type>.<name> <id>

# Or remove from state
terraform state rm <resource_type>.<name>
```

### Issue: ArgoCD apps stuck in "Progressing"

**Solution:**
```bash
# Check sync status
argocd app get <app-name>

# Check logs
kubectl logs -n argocd deployment/argocd-application-controller

# Force sync
argocd app sync <app-name> --force
```

### Issue: Istio sidecars not injecting

**Solution:**
```bash
# Check namespace label
kubectl get namespace demo -o yaml | grep istio-injection

# Add label if missing
kubectl label namespace demo istio-injection=enabled

# Restart pods
kubectl rollout restart deployment -n demo
```

### Issue: Pods CrashLoopBackOff

**Solution:**
```bash
# Check pod logs
kubectl logs <pod-name> -n <namespace>

# Check events
kubectl describe pod <pod-name> -n <namespace>

# Check resource constraints
kubectl top pods -n <namespace>
```

## Rollback Procedure

If bootstrap fails critically:

```bash
# 1. Delete root application
kubectl delete application root-application -n argocd

# 2. Manually clean up stuck resources
kubectl delete namespace <namespace> --grace-period=0 --force

# 3. Restart from Step 3
```

## Post-Bootstrap Checklist

- [ ] All ArgoCD applications healthy
- [ ] All pods running
- [ ] Istio mesh operational
- [ ] Demo app accessible
- [ ] Grafana dashboards loaded
- [ ] Kyverno policies active
- [ ] Credentials stored securely
- [ ] Documentation updated
- [ ] Team notified

## Success Criteria

✅ **Platform is ready when:**
1. All ArgoCD apps show "Healthy" and "Synced"
2. Demo app responds to health checks
3. Grafana dashboards show metrics
4. Kyverno blocks policy violations
5. Istio mesh is enforcing mTLS

## Next Steps

1. Onboard application teams
2. Set up CI/CD pipelines
3. Configure backup strategy
4. Schedule compliance audits
5. Plan for production promotion

## References

- [Terraform K3s Module](../infrastructure/terraform/modules/k3s/README.md)
- [ArgoCD App-of-Apps](../gitops/README.md)
- [Security Checklist](../security/README.md)
