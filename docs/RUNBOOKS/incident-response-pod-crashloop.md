# Runbook: Pod CrashLoopBackOff Incident Response

**Purpose:** Diagnose and resolve pod crash loop issues
**Audience:** Platform Engineers, SREs
**Severity:** High
**MTTR Goal:** 30 minutes

## Symptoms

- Pod status shows `CrashLoopBackOff`
- Application unavailable or degraded
- ArgoCD application shows "Degraded" health
- Alerts firing (if monitoring configured)

## Initial Response

### 1. Assess Impact (2 minutes)

```bash
# Check affected pods
kubectl get pods -n <namespace> | grep CrashLoopBackOff

# Check if service is available
kubectl get svc -n <namespace>
curl http://<service-url>/health

# Check replica count
kubectl get deployment <deployment> -n <namespace>
```

**Impact Levels:**
- **Critical:** All replicas down, service unavailable
- **High:** Partial replicas down, degraded performance
- **Medium:** Single replica down, no user impact

### 2. Gather Information (3 minutes)

```bash
# Get pod details
kubectl describe pod <pod-name> -n <namespace>

# Check recent events
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | tail -20

# Check resource usage
kubectl top pod <pod-name> -n <namespace>
```

## Diagnostic Steps

### 3. Check Pod Logs (5 minutes)

```bash
# Current logs
kubectl logs <pod-name> -n <namespace>

# Previous logs (if pod restarted)
kubectl logs <pod-name> -n <namespace> --previous

# All containers (if multi-container pod)
kubectl logs <pod-name> -n <namespace> --all-containers=true

# Istio sidecar logs
kubectl logs <pod-name> -n <namespace> -c istio-proxy
```

**Common Error Patterns:**

| Error Pattern | Likely Cause | Solution |
|---------------|--------------|----------|
| `OOMKilled` | Memory limit exceeded | Increase memory limits |
| `connection refused` | Dependency not ready | Check service dependencies |
| `ImagePullBackOff` | Image not found | Check image name/tag |
| `CrashLoopBackOff` | Application crash | Check application logs |
| `permission denied` | Security context issue | Review pod security context |

### 4. Analyze Pod Configuration (5 minutes)

```bash
# Get full pod spec
kubectl get pod <pod-name> -n <namespace> -o yaml > /tmp/pod.yaml

# Check critical sections
cat /tmp/pod.yaml | grep -A 10 "securityContext"
cat /tmp/pod.yaml | grep -A 10 "resources"
cat /tmp/pod.yaml | grep -A 10 "livenessProbe"
cat /tmp/pod.yaml | grep -A 10 "readinessProbe"
```

**Common Configuration Issues:**

1. **Incorrect health probes**
   ```yaml
   livenessProbe:
     httpGet:
       path: /healthz
       port: 8080
     initialDelaySeconds: 30  # Too short?
     periodSeconds: 10
     failureThreshold: 3
   ```

2. **Insufficient resources**
   ```yaml
   resources:
     limits:
       memory: "128Mi"  # Too low?
       cpu: "100m"
     requests:
       memory: "64Mi"
       cpu: "50m"
   ```

3. **Security context conflicts**
   ```yaml
   securityContext:
     runAsNonRoot: true
     runAsUser: 65534
     readOnlyRootFilesystem: true  # App writes to disk?
   ```

### 5. Check Dependencies (5 minutes)

```bash
# Check if dependent services are running
kubectl get pods -n <namespace> -l app=<dependency>

# Check service endpoints
kubectl get endpoints <service-name> -n <namespace>

# Test connectivity from debug pod
kubectl run debug --image=nicolaka/netshoot -it --rm --restart=Never -- /bin/bash
# Then: curl http://<service-name>.<namespace>:8080/health
```

### 6. Check Resource Constraints (3 minutes)

```bash
# Node resource usage
kubectl top nodes

# Namespace resource usage
kubectl top pods -n <namespace>

# Check for resource quotas
kubectl get resourcequota -n <namespace>

# Check for limit ranges
kubectl get limitrange -n <namespace>
```

## Common Root Causes and Solutions

### Cause 1: OOMKilled (Memory Limit)

**Symptoms:**
```
State:          Terminated
Reason:         OOMKilled
Exit Code:      137
```

**Solution:**
```bash
# Increase memory limits in Helm values
vim applications/helm-charts/<app>/values-<env>.yaml
```

```yaml
resources:
  limits:
    memory: "512Mi"  # Increased from 256Mi
  requests:
    memory: "256Mi"  # Increased from 128Mi
```

```bash
# Commit and let ArgoCD sync
git add .
git commit -m "fix: increase memory limits for <app>"
git push

# Or manual apply
helm upgrade <app> applications/helm-charts/<app> -f values-<env>.yaml -n <namespace>
```

### Cause 2: Application Crash (Exit Code 1)

**Symptoms:**
```
State:          Terminated
Reason:         Error
Exit Code:      1
Last State:     Terminated
```

**Solution:**

1. **Review application logs**
   ```bash
   kubectl logs <pod> -n <namespace> --previous | tail -50
   ```

2. **Common issues:**
   - Missing environment variables
   - Configuration file not found
   - Database connection failure
   - Panic/crash in code

3. **Exec into pod (if it stays up briefly)**
   ```bash
   kubectl exec -it <pod> -n <namespace> -- /bin/sh
   ls -la
   env
   ```

### Cause 3: Readiness/Liveness Probe Failure

**Symptoms:**
```
Readiness probe failed: Get "http://10.42.0.10:8080/health": dial tcp 10.42.0.10:8080: connect: connection refused
```

**Solution:**

1. **Check if app is listening on correct port**
   ```bash
   kubectl exec <pod> -n <namespace> -- netstat -tlnp
   ```

2. **Adjust probe settings**
   ```yaml
   livenessProbe:
     httpGet:
       path: /health
       port: 8080
     initialDelaySeconds: 60  # Give app more time to start
     periodSeconds: 10
     timeoutSeconds: 5
     failureThreshold: 3
   ```

3. **Or temporarily disable probes for debugging**
   ```yaml
   # Comment out probes
   # livenessProbe: ...
   # readinessProbe: ...
   ```

### Cause 4: Image Pull Error

**Symptoms:**
```
Failed to pull image "demo-app:1.0.0": rpc error: code = Unknown desc = Error response from daemon: pull access denied
```

**Solution:**

1. **Verify image exists**
   ```bash
   docker pull demo-app:1.0.0
   ```

2. **Check imagePullSecrets**
   ```bash
   kubectl get secret -n <namespace>
   kubectl describe pod <pod> -n <namespace> | grep -A 5 "Image"
   ```

3. **Create imagePullSecret if missing**
   ```bash
   kubectl create secret docker-registry regcred \
     --docker-server=<registry> \
     --docker-username=<username> \
     --docker-password=<password> \
     -n <namespace>
   ```

### Cause 5: Volume Mount Issues

**Symptoms:**
```
Error: failed to create containerd task: failed to create shim: OCI runtime create failed
```

**Solution:**

1. **Check PVC status**
   ```bash
   kubectl get pvc -n <namespace>
   kubectl describe pvc <pvc-name> -n <namespace>
   ```

2. **Check volume mounts**
   ```bash
   kubectl get pod <pod> -n <namespace> -o jsonpath='{.spec.volumes}'
   kubectl get pod <pod> -n <namespace> -o jsonpath='{.spec.containers[*].volumeMounts}'
   ```

3. **Fix volume configuration**
   - Ensure PVC is bound
   - Check access modes match
   - Verify storageClassName exists

## Escalation Criteria

Escalate to senior SRE if:

- [ ] Issue persists after 30 minutes
- [ ] Multiple services affected
- [ ] Data loss suspected
- [ ] Security incident suspected
- [ ] Cluster-wide issue (all nodes affected)

## Temporary Workarounds

### Workaround 1: Scale Down and Up

```bash
# Scale to 0
kubectl scale deployment <deployment> -n <namespace> --replicas=0

# Wait for pods to terminate
kubectl get pods -n <namespace> -w

# Scale back up
kubectl scale deployment <deployment> -n <namespace> --replicas=3
```

### Workaround 2: Delete and Recreate Pod

```bash
# Delete pod (deployment will recreate)
kubectl delete pod <pod-name> -n <namespace>

# Watch new pod
kubectl get pods -n <namespace> -w
```

### Workaround 3: Rollback Deployment

```bash
# Check rollout history
kubectl rollout history deployment/<deployment> -n <namespace>

# Rollback to previous version
kubectl rollout undo deployment/<deployment> -n <namespace>

# Or rollback to specific revision
kubectl rollout undo deployment/<deployment> -n <namespace> --to-revision=2
```

## Communication Template

### Initial Update (within 5 minutes)

```
📢 INCIDENT ALERT

Service: <service-name>
Environment: <env>
Status: Investigating
Impact: <describe user impact>
Started: <timestamp>

Current situation:
- <brief description>

Actions taken:
- Checking logs
- Analyzing pod status

ETA for next update: 15 minutes
```

### Resolution Update

```
✅ INCIDENT RESOLVED

Service: <service-name>
Environment: <env>
Status: Resolved
Duration: <time>

Root cause:
- <brief description>

Resolution:
- <what was done>

Follow-up actions:
- [ ] Post-mortem scheduled
- [ ] Monitoring improved
- [ ] Documentation updated
```

## Post-Incident Actions

### 1. Document Incident

Create `docs/incidents/YYYY-MM-DD-<title>.md`:

```markdown
# Incident: <Title>

**Date:** YYYY-MM-DD
**Duration:** XX minutes
**Severity:** High/Medium/Low
**Services Affected:** <list>

## Timeline

- HH:MM - Incident detected
- HH:MM - Investigation started
- HH:MM - Root cause identified
- HH:MM - Fix applied
- HH:MM - Service restored

## Root Cause

<detailed explanation>

## Resolution

<what was done>

## Lessons Learned

- <lesson 1>
- <lesson 2>

## Action Items

- [ ] Improve monitoring
- [ ] Update runbook
- [ ] Add automated remediation
```

### 2. Update Monitoring

```bash
# Add/improve alerts
vim platform/observability/prometheus/alerts/demo-app.yaml
```

```yaml
- alert: PodCrashLooping
  expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
  annotations:
    summary: "Pod {{ $labels.pod }} is crash looping"
    runbook: "https://github.com/user/repo/docs/RUNBOOKS/incident-response-pod-crashloop.md"
```

### 3. Prevent Recurrence

- Update resource limits based on actual usage
- Improve health probe configuration
- Add pre-deployment validation
- Enhance CI/CD testing

## References

- [Debug Pod Tool](../../tools/scripts/debug-pod.sh)
- [Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug/)
- [Pod Lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/)
