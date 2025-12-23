# ADR 003: Service Mesh - Istio vs Linkerd

**Status:** Accepted
**Date:** 2023-12-23
**Deciders:** Platform Architecture Team
**Technical Story:** Service mesh selection for East-West traffic

## Context

We need a service mesh to provide:
- **mTLS** - Automatic mutual TLS between services
- **Observability** - Distributed tracing, metrics, access logs
- **Traffic Management** - Retries, timeouts, circuit breakers
- **Security** - Authorization policies, zero-trust networking

### Options Considered

1. **Istio** - Full-featured service mesh from Google/IBM
2. **Linkerd** - Lightweight service mesh from Buoyant
3. **Consul Connect** - HashiCorp's service mesh
4. **No service mesh** - Application-level implementation

## Decision

We will use **Istio** as our service mesh.

## Rationale

### Comparison Matrix

| Feature | Istio | Linkerd | Consul | None |
|---------|-------|---------|--------|------|
| **mTLS** | ✅ Automatic | ✅ Automatic | ✅ Manual | ❌ App-level |
| **Observability** | ✅ Full | ✅ Good | ⚠️ Basic | ❌ Custom |
| **Traffic Management** | ✅ Rich | ⚠️ Basic | ⚠️ Basic | ❌ Custom |
| **Resource Usage** | ⚠️ High | ✅ Low | ⚠️ Medium | ✅ None |
| **Complexity** | ⚠️ High | ✅ Low | ⚠️ Medium | ✅ None |
| **Maturity** | ✅ Very Mature | ✅ Mature | ✅ Mature | N/A |
| **Community** | ✅ Large | ⚠️ Small | ⚠️ Medium | N/A |
| **Enterprise Support** | ✅ Available | ✅ Available | ✅ Available | N/A |

### Why Istio?

1. **Feature Completeness**
   - Advanced traffic routing (weighted, header-based, mirror)
   - Circuit breakers, retries, timeouts
   - Fault injection for chaos testing
   - Rate limiting and quotas

2. **Observability Integration**
   - OpenTelemetry native support
   - Prometheus metrics out-of-the-box
   - Jaeger/Zipkin for distributed tracing
   - Access logs with rich metadata

3. **Security Features**
   - Automatic mTLS with STRICT mode
   - Authorization policies (L3-L7)
   - JWT validation
   - RBAC for service-to-service communication

4. **Ecosystem Integration**
   - Works seamlessly with Kong (North-South traffic)
   - Argo Rollouts integration for progressive delivery
   - Kiali for visualization
   - Grafana dashboards available

5. **Production Readiness**
   - Used by major enterprises (Google, Airbnb, eBay)
   - Extensive documentation and examples
   - Large community support
   - Regular security updates

### Trade-offs Accepted

1. **Resource Overhead**
   - Istio proxies consume ~50-100MB per pod
   - Control plane (istiod) needs ~500MB
   - **Mitigation:** Lab environment uses minimal Istio profile

2. **Complexity**
   - Steeper learning curve
   - More configuration options
   - **Mitigation:** Start with defaults, add features incrementally

3. **Debugging**
   - Additional layer to troubleshoot
   - **Mitigation:** Comprehensive logging, Kiali dashboard, documentation

## Implementation

### Minimal Istio Profile for Lab

```yaml
# platform/networking/istio/istio-operator.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: istio-minimal
spec:
  profile: minimal  # Lightweight for lab
  components:
    pilot:
      k8s:
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
  meshConfig:
    enableAutoMtls: true
    accessLogFile: /dev/stdout
    defaultConfig:
      tracing:
        opentelemetry:
          collector_address: otel-collector.observability:4317
```

### mTLS Configuration

```yaml
# Enforce STRICT mTLS cluster-wide
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
```

### Traffic Management Example

```yaml
# VirtualService for demo-app with retries
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: demo-app
  namespace: demo
spec:
  hosts:
    - demo-app
  http:
    - route:
        - destination:
            host: demo-app
            port:
              number: 8080
      retries:
        attempts: 3
        perTryTimeout: 2s
        retryOn: 5xx,reset,connect-failure
      timeout: 10s
```

### Integration with Kong

```
Internet → Kong (North-South) → Istio Gateway → Istio Mesh (East-West)
```

- **Kong** handles external traffic (rate limiting, auth, API gateway)
- **Istio** handles internal traffic (mTLS, observability, retries)

## Consequences

### Positive

- **Zero-trust networking** - mTLS by default
- **Rich observability** - Distributed tracing across all services
- **Progressive delivery** - Canary deployments with Argo Rollouts
- **Resilience** - Built-in retries, circuit breakers, timeouts
- **Security** - Authorization policies at service level

### Negative

- **Resource consumption** - ~150MB overhead per node
- **Learning curve** - Team needs training on Istio concepts
- **Debugging complexity** - Additional layer to troubleshoot

### Neutral

- **Sidecar injection** - Automatic via namespace label
- **CRDs** - Many new custom resources to manage
- **Upgrades** - Careful planning required (canary upgrades supported)

## Alternatives Considered

### Linkerd

**Pros:**
- Lightweight (10-20MB per proxy)
- Simple to operate
- Fast

**Cons:**
- Limited traffic management features
- Smaller community
- Fewer integrations

**Rejected because:** We need advanced traffic routing for progressive delivery.

### Consul Connect

**Pros:**
- HashiCorp ecosystem integration
- Good for multi-cloud

**Cons:**
- Less Kubernetes-native
- Requires Consul servers
- Weaker observability

**Rejected because:** Less mature Kubernetes integration.

### No Service Mesh

**Pros:**
- No resource overhead
- Simpler architecture

**Cons:**
- Manual TLS configuration
- No built-in retries/timeouts
- Custom observability implementation
- No progressive delivery support

**Rejected because:** Benefits of service mesh outweigh costs for production-like lab.

## Migration Path

If Istio proves too resource-intensive for lab:

1. Switch to Linkerd (similar API, easier migration)
2. Or use Istio ambient mode (sidecar-less, when stable)
3. Document comparison in runbook

## References

- [Istio Documentation](https://istio.io/latest/docs/)
- [Istio vs Linkerd Comparison](https://istio.io/latest/about/comparison/)
- [Service Mesh Patterns](https://www.nginx.com/blog/what-is-a-service-mesh/)
- [Kong + Istio Integration](https://konghq.com/blog/kong-istio-integration)

## Revision History

| Date | Version | Changes |
|------|---------|---------|
| 2023-12-23 | 1.0 | Initial decision |
