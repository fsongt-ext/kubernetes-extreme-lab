# Policy-as-Code

Centralized policy definitions for governance, security, and compliance.

## Directory Structure

```
policies/
├── opa/                           # OPA Rego policies for Gatekeeper
│   ├── require-labels.rego       # Enforce labeling standards
│   └── enforce-security.rego     # Security best practices
│
├── kyverno/                       # Kyverno ClusterPolicies
│   ├── disallow-default-namespace.yaml
│   ├── require-pod-resources.yaml
│   └── enforce-istio-sidecar.yaml
│
└── conftest/                      # Conftest policies for IaC testing
    └── policy/
        ├── deployment.rego       # Kubernetes manifest validation
        └── terraform.rego        # Terraform plan validation
```

## Policy Engines

### OPA Gatekeeper (Platform-level)

**Purpose:** Cluster-wide admission control for platform resources

**Managed by:** Platform team

**Installation:**

```bash
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml
```

**Apply policies:**

```bash
# Create ConstraintTemplate from Rego
kubectl apply -f platform/security/gatekeeper/templates/

# Create Constraint instance
kubectl apply -f platform/security/gatekeeper/constraints/
```

**Test OPA policy locally:**

```bash
# Install conftest
brew install conftest

# Test against Kubernetes manifest
conftest test deployment.yaml -p policies/opa/
```

### Kyverno (Application-level)

**Purpose:** Application namespace policies with mutation/validation/generation

**Managed by:** Application teams (within their project)

**Installation:** Via ArgoCD (already deployed)

**Apply policies:**

```bash
kubectl apply -f policies/kyverno/
```

**Test Kyverno policy:**

```bash
# Install Kyverno CLI
brew install kyverno

# Test policy against resource
kyverno apply policies/kyverno/disallow-default-namespace.yaml --resource test-pod.yaml
```

**View policy reports:**

```bash
# List policy reports
kubectl get policyreport -A

# View specific report
kubectl describe policyreport -n demo
```

### Conftest (CI/CD pipeline)

**Purpose:** Pre-deployment validation of IaC and manifests

**Managed by:** CI/CD pipelines

**Installation:**

```bash
brew install conftest
```

**Usage:**

```bash
# Test Kubernetes manifests
conftest test platform/core/argocd/values.yaml -p policies/conftest/policy/

# Test Terraform plans
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary | conftest test -p policies/conftest/policy/ -

# Test Helm charts
helm template demo-app applications/helm-charts/demo-app | conftest test -p policies/conftest/policy/ -
```

## Policy Categories

### 1. Security Policies

**OPA: `enforce-security.rego`**

Enforces:
- Non-root containers
- Read-only root filesystem
- Drop all capabilities
- No privilege escalation
- No privileged mode
- No host network/PID/IPC

**Kyverno: Multiple policies**

Enforces:
- Pod Security Standards (baseline/restricted)
- Image provenance verification
- NetworkPolicy auto-generation

**Example violation:**

```yaml
# This will be DENIED
apiVersion: v1
kind: Pod
metadata:
  name: bad-pod
spec:
  containers:
    - name: nginx
      image: nginx:latest
      securityContext:
        privileged: true  # ❌ Denied by OPA
```

### 2. Resource Management

**Kyverno: `require-pod-resources.yaml`**

Enforces:
- CPU/memory requests and limits
- QoS class (Guaranteed/Burstable)

**Example:**

```yaml
# This will be DENIED
apiVersion: v1
kind: Pod
metadata:
  name: bad-pod
spec:
  containers:
    - name: nginx
      image: nginx:latest
      # ❌ Missing resources
```

### 3. Multi-Tenancy

**Kyverno: `disallow-default-namespace.yaml`**

Enforces:
- No workloads in default namespace
- Namespace isolation

### 4. Service Mesh

**Kyverno: `enforce-istio-sidecar.yaml`**

Enforces:
- Istio sidecar injection
- mTLS configuration

**Mutations:**
- Auto-add `istio-injection=enabled` label to namespaces

### 5. Labeling Standards

**OPA: `require-labels.rego`**

Required labels:
- `app`: Application name
- `version`: Application version
- `team`: Owning team

**Example:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: good-pod
  labels:
    app: demo-app
    version: "1.0.0"
    team: platform
spec:
  containers:
    - name: nginx
      image: nginx:1.21
```

## Policy Workflow

### Development Phase

```bash
# 1. Write policy (Rego or YAML)
vim policies/kyverno/my-policy.yaml

# 2. Test locally
kyverno apply policies/kyverno/my-policy.yaml --resource test-manifest.yaml

# 3. Validate syntax
kubectl apply --dry-run=client -f policies/kyverno/my-policy.yaml
```

### CI/CD Integration

```yaml
# .github/workflows/policy-validation.yaml
- name: Validate policies
  run: |
    # Validate Kubernetes manifests
    conftest test gitops/ -p policies/conftest/policy/ --all-namespaces

    # Validate Terraform plans
    terraform plan -out=tfplan.binary
    terraform show -json tfplan.binary | conftest test -
```

### Deployment

```bash
# Apply to cluster
kubectl apply -f policies/kyverno/my-policy.yaml

# Verify policy is active
kubectl get clusterpolicy
```

### Monitoring

```bash
# View policy violations
kubectl get policyreport -A

# Export violations
kubectl get policyreport -n demo -o yaml

# Integrate with Prometheus
# Kyverno exports metrics at :8000/metrics
```

## Policy Modes

### Enforce Mode

Blocks non-compliant resources from being created.

```yaml
spec:
  validationFailureAction: enforce
```

### Audit Mode

Allows resources but reports violations.

```yaml
spec:
  validationFailureAction: audit
```

**Best practice:** Start with `audit`, observe violations, then switch to `enforce`.

## Exemptions

### Namespace-level exemption

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: privileged-workloads
  labels:
    pod-security.kubernetes.io/enforce: privileged
```

### Resource-level exemption (Kyverno)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: special-pod
  annotations:
    policies.kyverno.io/exclude: "require-pod-resources"
spec:
  # ...
```

## Reporting

### Generate policy report

```bash
# HTML report
kyverno apply policies/kyverno/ --resource gitops/ --policy-report > report.html

# JSON report for automation
kubectl get policyreport -A -o json > policy-report.json
```

### Prometheus metrics

Kyverno exports metrics:

```promql
# Policy violations
kyverno_policy_results_total{policy_validation_mode="enforce",policy_type="cluster",policy_result="fail"}

# Policy execution duration
kyverno_policy_execution_duration_seconds
```

### Grafana dashboard

Import Kyverno dashboard: https://grafana.com/grafana/dashboards/16814

## Troubleshooting

### Policy not being applied

```bash
# Check policy status
kubectl get clusterpolicy my-policy -o yaml

# Check admission webhooks
kubectl get validatingwebhookconfigurations

# View Kyverno logs
kubectl logs -n kyverno -l app.kubernetes.io/name=kyverno -f
```

### False positives

```bash
# Test policy against specific resource
kyverno apply policy.yaml --resource resource.yaml -v 4

# Dry-run to see what would be blocked
kubectl apply --dry-run=server -f resource.yaml
```

### Policy conflicts

```bash
# List all policies affecting a resource
kyverno apply --resource resource.yaml --policy-report

# Check policy precedence
kubectl get clusterpolicy --sort-by=.metadata.name
```

## Best Practices

1. **Start with audit mode** - Observe violations before enforcing
2. **Use exceptions sparingly** - Document why exceptions are needed
3. **Test policies locally** - Use Conftest/Kyverno CLI before deploying
4. **Version control** - All policies in Git, reviewed via PR
5. **Document policies** - Add annotations explaining purpose
6. **Monitor violations** - Set up alerts for policy failures
7. **Regular reviews** - Audit and update policies quarterly

## References

- [OPA Gatekeeper Library](https://open-policy-agent.github.io/gatekeeper-library/)
- [Kyverno Policies](https://kyverno.io/policies/)
- [Conftest Documentation](https://www.conftest.dev/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
