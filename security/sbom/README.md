# Software Bill of Materials (SBOM)

SBOMs are generated for all container images and dependencies to track components and vulnerabilities.

## Tools

### Syft (Generate SBOMs)

```bash
# Install Syft
brew install syft

# Generate SBOM for Docker image
syft demo-app:1.0.0 -o json > sbom/demo-app-1.0.0.json

# Generate SBOM in SPDX format
syft demo-app:1.0.0 -o spdx-json > sbom/demo-app-1.0.0.spdx.json

# Generate SBOM in CycloneDX format
syft demo-app:1.0.0 -o cyclonedx-json > sbom/demo-app-1.0.0.cyclonedx.json
```

### Grype (Scan SBOMs for vulnerabilities)

```bash
# Install Grype
brew install grype

# Scan image directly
grype demo-app:1.0.0

# Scan using SBOM
grype sbom:demo-app-1.0.0.json

# Output as JSON
grype demo-app:1.0.0 -o json > vulnerabilities/demo-app-1.0.0-vulns.json
```

## CI/CD Integration

SBOMs are automatically generated in CI pipelines:

```yaml
# .github/workflows/app-ci.yaml (excerpt)
- name: Generate SBOM
  run: |
    syft $IMAGE_NAME:$IMAGE_TAG -o spdx-json > sbom-$IMAGE_TAG.json

- name: Upload SBOM
  uses: actions/upload-artifact@v3
  with:
    name: sbom
    path: sbom-*.json
```

## Storage

SBOMs are:
1. Stored as artifacts in CI/CD runs
2. Uploaded to artifact repository (optional)
3. Signed with Cosign for integrity

```bash
# Sign SBOM
cosign sign-blob --key cosign.key sbom-demo-app-1.0.0.json > sbom-demo-app-1.0.0.json.sig
```

## Compliance

SBOMs support compliance requirements:
- **Executive Order 14028** (US Federal)
- **NIST SP 800-218** (Secure Software Development Framework)
- **ISO/IEC 5962** (SPDX standard)

## Example SBOM Content

```json
{
  "artifacts": [
    {
      "name": "golang.org/x/net",
      "version": "v0.17.0",
      "type": "go-module",
      "licenses": ["BSD-3-Clause"]
    },
    {
      "name": "github.com/prometheus/client_golang",
      "version": "v1.17.0",
      "type": "go-module",
      "licenses": ["Apache-2.0"]
    }
  ]
}
```

## References

- [Syft Documentation](https://github.com/anchore/syft)
- [SPDX Specification](https://spdx.dev/specifications/)
- [CycloneDX Standard](https://cyclonedx.org/)
