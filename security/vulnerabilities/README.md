# Vulnerability Scanning

Continuous vulnerability scanning for container images, dependencies, and infrastructure code.

## Scanning Tools

### Trivy (Container Images & IaC)

```bash
# Install Trivy
brew install trivy

# Scan Docker image
trivy image demo-app:1.0.0

# Scan with severity filtering
trivy image --severity HIGH,CRITICAL demo-app:1.0.0

# Scan filesystem (for IaC)
trivy fs infrastructure/terraform/

# Scan Kubernetes manifests
trivy k8s --report summary

# Output formats
trivy image demo-app:1.0.0 -f json -o vulnerabilities/demo-app-1.0.0.json
trivy image demo-app:1.0.0 -f sarif -o vulnerabilities/demo-app-1.0.0.sarif
```

### Grype (SBOM-based scanning)

```bash
# Install Grype
brew install grype

# Scan image
grype demo-app:1.0.0

# Scan with severity filtering
grype demo-app:1.0.0 --fail-on high

# Scan SBOM
grype sbom:security/sbom/demo-app-1.0.0.json

# Match against specific database
grype demo-app:1.0.0 --db-update
```

### Snyk (Dependency scanning)

```bash
# Install Snyk CLI
npm install -g snyk

# Authenticate
snyk auth

# Scan Go project
cd applications/demo-app
snyk test --severity-threshold=high

# Monitor project
snyk monitor
```

## CI/CD Integration

Scans run automatically in pipelines:

```yaml
# .github/workflows/app-ci.yaml (excerpt)
- name: Run Trivy scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.IMAGE_NAME }}:${{ env.IMAGE_TAG }}
    format: 'sarif'
    output: 'trivy-results.sarif'

- name: Upload to GitHub Security
  uses: github/codeql-action/upload-sarif@v2
  with:
    sarif_file: 'trivy-results.sarif'
```

## Vulnerability Thresholds

**Blocking severity:**
- **Critical**: Block deployment
- **High**: Block deployment
- **Medium**: Warn only
- **Low**: Informational

## Remediation Workflow

1. **Scan identifies vulnerability**
   ```bash
   trivy image demo-app:1.0.0 --severity CRITICAL
   ```

2. **Review CVE details**
   - Check CVE database: https://cve.mitre.org/
   - Review vendor advisory
   - Assess exploitability

3. **Apply fix**
   - Update base image: `FROM golang:1.21-alpine` → `FROM golang:1.21.5-alpine`
   - Update dependencies: `go get -u github.com/vulnerable/package`
   - Apply patch if available

4. **Rescan**
   ```bash
   trivy image demo-app:1.0.1
   ```

5. **Deploy patched version**

## Continuous Monitoring

### Scheduled Scans

```bash
# Scan all running images daily
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | \
  sort -u | \
  xargs -I {} trivy image {}
```

### Integration with Observability

Export scan results to Prometheus:

```promql
# Number of critical vulnerabilities
trivy_vulnerabilities_count{severity="CRITICAL"}

# Last scan time
trivy_last_scan_timestamp
```

## Vulnerability Database

Trivy uses multiple vulnerability databases:
- **NVD** (National Vulnerability Database)
- **GitHub Advisory Database**
- **Red Hat Security Data**
- **Alpine SecDB**
- **Debian Security Tracker**

Update database:

```bash
trivy image --download-db-only
```

## False Positive Handling

Create `.trivyignore` file:

```
# Ignore specific CVE (with justification)
CVE-2023-12345  # Fixed in unreleased upstream version

# Ignore CVE in specific package
CVE-2023-67890 pkg:golang/example.com/package@v1.0.0
```

## Reporting

### Generate HTML report

```bash
trivy image demo-app:1.0.0 --format template --template "@contrib/html.tpl" -o report.html
```

### Generate compliance report

```bash
trivy image demo-app:1.0.0 --compliance docker-cis
```

### Export to SARIF for GitHub Security

```bash
trivy image demo-app:1.0.0 --format sarif --output results.sarif
gh code-scanning upload-sarif --sarif results.sarif
```

## Integration with ArgoCD

Annotate Applications with scan status:

```yaml
metadata:
  annotations:
    trivy.aquasecurity.github.io/last-scan: "2023-12-23T10:00:00Z"
    trivy.aquasecurity.github.io/critical-count: "0"
    trivy.aquasecurity.github.io/high-count: "2"
```

## References

- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Grype Documentation](https://github.com/anchore/grype)
- [NIST NVD](https://nvd.nist.gov/)
- [CVE Details](https://www.cvedetails.com/)
