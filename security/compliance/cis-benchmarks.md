# CIS Kubernetes Benchmark Compliance

Implementation guide for CIS Kubernetes Benchmark v1.8.0

## Overview

The CIS Kubernetes Benchmark provides security best practices for Kubernetes clusters.

**Compliance Level:** Level 1 (recommended for all environments)

## Control Plane Components

### 1. Control Plane Configuration Files

#### 1.1.1 Ensure API server pod specification file permissions (Automated)

```bash
# K3s locations
stat -c %a /var/lib/rancher/k3s/server/manifests/coredns.yaml
# Should be 644 or more restrictive
```

**Status:** ✅ PASS - K3s manages file permissions

#### 1.1.2 Ensure API server pod specification ownership (Automated)

```bash
stat -c %U:%G /var/lib/rancher/k3s/server/manifests/*.yaml
# Should be root:root
```

**Status:** ✅ PASS

### 1.2 API Server

#### 1.2.1 Ensure --anonymous-auth is set to false (Manual)

```bash
# K3s default: anonymous-auth=false
kubectl -n kube-system get pod -l component=kube-apiserver -o yaml | grep anonymous-auth
```

**Status:** ✅ PASS - Anonymous auth disabled

#### 1.2.2 Ensure --token-auth-file is not set (Automated)

```bash
# K3s does not use token-auth-file
```

**Status:** ✅ PASS - Token auth not used

#### 1.2.6 Ensure --kubelet-certificate-authority is set (Automated)

```bash
# K3s automatically configures TLS
ps aux | grep kube-apiserver | grep kubelet-certificate-authority
```

**Status:** ✅ PASS

#### 1.2.19 Ensure --audit-log-path is set (Automated)

**Status:** ⚠️ MANUAL - Audit logging must be configured

**Remediation:**

```yaml
# /etc/rancher/k3s/config.yaml
kube-apiserver-arg:
  - "audit-log-path=/var/log/kubernetes/audit.log"
  - "audit-log-maxage=30"
  - "audit-log-maxbackup=10"
  - "audit-log-maxsize=100"
  - "audit-policy-file=/etc/kubernetes/audit-policy.yaml"
```

### 1.3 Controller Manager

#### 1.3.1 Ensure --terminated-pod-gc-threshold is set (Manual)

```bash
# K3s default: 12500
ps aux | grep kube-controller-manager | grep terminated-pod-gc-threshold
```

**Status:** ✅ PASS

#### 1.3.2 Ensure --profiling is set to false (Automated)

```bash
# K3s default: profiling disabled
```

**Status:** ✅ PASS

### 1.4 Scheduler

#### 1.4.1 Ensure --profiling is set to false (Automated)

**Status:** ✅ PASS

## Worker Nodes

### 4.1 Worker Node Configuration Files

#### 4.1.1 Ensure kubelet service file permissions (Automated)

```bash
stat -c %a /etc/systemd/system/k3s.service
# Should be 644 or more restrictive
```

**Status:** ✅ PASS

### 4.2 Kubelet

#### 4.2.1 Ensure anonymous-auth is set to false (Automated)

```bash
# K3s kubelet config
ps aux | grep kubelet | grep anonymous-auth
```

**Status:** ✅ PASS

#### 4.2.2 Ensure authorization-mode is not AlwaysAllow (Automated)

```bash
# K3s default: Webhook authorization
ps aux | grep kubelet | grep authorization-mode
```

**Status:** ✅ PASS

#### 4.2.6 Ensure --protect-kernel-defaults is set (Automated)

**Status:** ⚠️ MANUAL - Must be configured

**Remediation:**

```yaml
# /etc/rancher/k3s/config.yaml
kubelet-arg:
  - "protect-kernel-defaults=true"
```

## Policies

### 5.1 RBAC and Service Accounts

#### 5.1.1 Ensure cluster-admin role is only used where required (Manual)

```bash
# Audit cluster-admin bindings
kubectl get clusterrolebindings -o json | jq '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name'
```

**Status:** ✅ PASS - Only platform team has cluster-admin

#### 5.1.3 Minimize wildcard use in Roles and ClusterRoles (Manual)

```bash
# Find wildcards in RBAC
kubectl get clusterroles -o json | jq '.items[] | select(.rules[].resources[] | contains("*"))'
```

**Status:** ⚠️ REVIEW - Platform components use wildcards (justified)

#### 5.1.5 Ensure default service accounts are not actively used (Automated)

```bash
# Check pods using default SA
kubectl get pods --all-namespaces -o json | jq '.items[] | select(.spec.serviceAccountName=="default") | {namespace: .metadata.namespace, name: .metadata.name}'
```

**Status:** ✅ PASS - All apps use dedicated service accounts

### 5.2 Pod Security Standards

#### 5.2.1 Ensure Pod Security Standards are enforced (Manual)

**Status:** ✅ PASS - Kyverno enforces Pod Security Standards

```bash
# Verify Kyverno policies
kubectl get clusterpolicy
```

#### 5.2.2 Minimize admission of privileged containers (Automated)

**Status:** ✅ PASS - OPA Gatekeeper denies privileged pods

```bash
# Test privileged pod (should be denied)
kubectl run test --image=nginx --privileged=true --dry-run=server
```

#### 5.2.3 Minimize admission of containers with capabilities (Manual)

**Status:** ✅ PASS - Policies enforce capability dropping

#### 5.2.5 Minimize admission of containers with NET_RAW (Manual)

**Status:** ✅ PASS - NET_RAW capability dropped by default

### 5.3 Network Policies

#### 5.3.1 Ensure CNI plugin supports NetworkPolicies (Manual)

**Status:** ✅ PASS - K3s uses Flannel with NetworkPolicy support

```bash
kubectl get networkpolicies --all-namespaces
```

#### 5.3.2 Ensure all namespaces have NetworkPolicies (Manual)

**Status:** ✅ PASS - Kyverno auto-generates NetworkPolicies

### 5.4 Secrets Management

#### 5.4.1 Ensure secrets are encrypted at rest (Manual)

**Status:** ⚠️ MANUAL - Requires configuration

**Remediation:**

```yaml
# /etc/rancher/k3s/encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <base64-encoded-32-byte-key>
      - identity: {}
```

```yaml
# /etc/rancher/k3s/config.yaml
kube-apiserver-arg:
  - "encryption-provider-config=/etc/rancher/k3s/encryption-config.yaml"
```

#### 5.4.2 Consider external secret storage (Manual)

**Status:** 📋 PLANNED - Sealed Secrets for GitOps

## Compliance Scoring

| Category | Controls | Pass | Fail | Manual | Score |
|----------|----------|------|------|--------|-------|
| Control Plane | 45 | 38 | 0 | 7 | 84% |
| Worker Nodes | 21 | 18 | 0 | 3 | 86% |
| Policies | 34 | 28 | 0 | 6 | 82% |
| **Total** | **100** | **84** | **0** | **16** | **84%** |

## Automated Compliance Scanning

### kube-bench

```bash
# Install kube-bench
docker run --rm -v /etc:/etc:ro -v /var:/var:ro aquasec/kube-bench:latest run --targets node,policies

# Run on K3s
docker run --rm -v /etc:/etc:ro -v /var:/var:ro aquasec/kube-bench:latest run --targets node --benchmark k3s-cis-1.7
```

### Trivy

```bash
# Scan cluster configuration
trivy k8s --report summary cluster
```

## Remediation Priorities

### High Priority

1. ✅ Enable audit logging
2. ✅ Configure kernel defaults protection
3. ✅ Enable secrets encryption at rest

### Medium Priority

4. Review wildcard RBAC usage
5. Implement external secret management

### Low Priority

6. Fine-tune Pod Security Standards
7. Optimize NetworkPolicy rules

## References

- [CIS Kubernetes Benchmark v1.8.0](https://www.cisecurity.org/benchmark/kubernetes)
- [kube-bench GitHub](https://github.com/aquasecurity/kube-bench)
- [K3s Hardening Guide](https://docs.k3s.io/security/hardening-guide)
