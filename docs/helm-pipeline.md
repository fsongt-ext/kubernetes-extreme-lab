# Helm Chart Release Pipeline

This document describes the Helm chart packaging and release pipeline for the kubernetes-extreme-lab project.

## Overview

The Helm pipeline automatically packages, validates, and publishes Helm charts to Azure Blob Storage, creating a self-hosted Helm repository accessible via HTTPS.

## Architecture

```
┌─────────────────┐
│   Git Push to   │
│   helm/**       │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│              GitHub Actions Workflow                        │
│  (.github/workflows/helm-release.yaml)                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Detect Changed Charts                                  │
│     - Compares with base branch                            │
│     - Identifies modified helm/** directories              │
│     - Creates matrix for parallel processing               │
│                                                             │
│  2. Lint & Test (parallel per chart)                       │
│     ├─ helm lint                                           │
│     ├─ helm template --validate                            │
│     ├─ chart-testing (ct)                                  │
│     └─ Values schema validation                            │
│                                                             │
│  3. Security Scan (parallel per chart)                     │
│     ├─ Trivy (IaC scanning)                                │
│     └─ Kubesec (manifest security)                         │
│                                                             │
│  4. Package & Release (parallel per chart)                 │
│     ├─ Semantic versioning                                 │
│     ├─ helm package                                        │
│     ├─ Upload to Azure Blob Storage                        │
│     ├─ Update Helm repository index                        │
│     ├─ Create GitHub Release                               │
│     └─ Generate SBOM                                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│           Azure Blob Storage (Helm Repository)              │
│                                                             │
│  Container: helm-charts                                     │
│  ├─ index.yaml                    (Helm repo index)        │
│  └─ charts/                                                │
│      ├─ demo-app-1.0.0.tgz                                 │
│      ├─ demo-app-1.0.1.tgz                                 │
│      ├─ microservices-demo-0.10.4.tgz                      │
│      └─ <chart>-metadata.json                              │
│                                                             │
│  Public URL: https://<storage>.blob.core.windows.net/      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Infrastructure Setup

### Terraform Resources

The pipeline requires the following infrastructure managed by Terraform:

#### 1. Storage Module (`infrastructure/terraform/modules/storage/`)

**Purpose:** Creates Azure Storage Account for hosting Helm charts

**Key Features:**
- Public blob access for Helm repository
- Blob versioning enabled
- Soft delete (7 days retention)
- Lifecycle management (archives old versions after 90 days)
- Static website hosting (for browsing)
- CORS configuration for web access

**Resources Created:**
- `azurerm_storage_account` - Storage account (LRS, Standard tier)
- `azurerm_storage_container` - Blob container named `helm-charts`
- `azurerm_storage_management_policy` - Lifecycle rules

#### 2. Lab Environment (`infrastructure/terraform/environments/lab/`)

**Files Modified:**
- `local.tf` - Added `helm_storage_config`
- `main.tf` - Added `module "helm_storage"`
- `outputs.tf` - Added Helm storage outputs
- `github.tf` - Added GitHub Actions variables/secrets

**Storage Configuration:**
```hcl
helm_storage_config = {
  storage_account_name = "k3slabhelm<random>"
  container_name       = "helm-charts"
}
```

#### 3. GitHub Actions Integration

**Variables (Public):**
- `HELM_STORAGE_ACCOUNT` - Storage account name
- `HELM_STORAGE_CONTAINER` - Container name (`helm-charts`)
- `HELM_REPO_URL` - Public Helm repository URL

**Secrets (Private):**
- `HELM_STORAGE_KEY` - Storage account access key

These are automatically created by Terraform via the GitHub module.

## Pipeline Workflow

### Triggers

The pipeline runs on:

1. **Push to `main` branch** - When changes are detected in:
   - `helm/**`
   - `.github/workflows/helm-release.yaml`

2. **Pull Requests to `main`** - Linting and testing only (no release)

3. **Manual Dispatch** - Workflow can be triggered manually with options:
   - `chart` - Specific chart to release (optional)
   - `force_version` - Override version (optional)

### Pipeline Stages

#### Stage 1: Detect Changed Charts

**Job:** `detect-changes`

**Purpose:** Identifies which Helm charts were modified

**Logic:**
- For PRs: Compares PR head with base branch
- For pushes: Compares HEAD with HEAD^
- For manual: Uses input parameters or processes all charts

**Output:** JSON matrix of chart names for parallel processing

**Example Output:**
```json
{
  "chart": ["demo-app", "microservices-demo"]
}
```

#### Stage 2: Lint & Test

**Job:** `lint-and-test`

**Runs:** In parallel for each changed chart

**Steps:**

1. **Helm Lint**
   ```bash
   helm lint helm/<chart-name>
   ```
   Validates Chart.yaml syntax and structure

2. **Template Validation**
   ```bash
   helm template test-release helm/<chart-name> --validate
   ```
   Renders templates and validates against Kubernetes API

3. **Chart Testing**
   ```bash
   ct lint --charts helm/<chart-name>
   ```
   Advanced linting with Helm chart-testing tool

4. **Required Fields Check**
   Verifies Chart.yaml contains:
   - `name`
   - `version`
   - `description`

5. **Values Schema Validation** (optional)
   If `values.schema.json` exists, validates values against JSON schema

#### Stage 3: Security Scan

**Job:** `security-scan`

**Runs:** In parallel for each changed chart

**Steps:**

1. **Trivy IaC Scan**
   ```bash
   trivy config helm/<chart-name>
   ```
   Scans for:
   - Security misconfigurations
   - Best practice violations
   - Severity: CRITICAL, HIGH

2. **Kubesec Manifest Scan**
   ```bash
   helm template | kubesec scan
   ```
   Analyzes rendered manifests for:
   - Security context issues
   - Privilege escalation risks
   - Network policy gaps

#### Stage 4: Package & Release

**Job:** `package-and-release`

**Runs:** Only on `main` branch (not PRs)

**Runs:** In parallel for each changed chart

**Steps:**

1. **Version Determination**
   - Reads current version from `Chart.yaml`
   - Auto-increments patch version (e.g., 1.0.0 → 1.0.1)
   - Can be overridden with `force_version` input

2. **Update Chart.yaml**
   ```bash
   sed -i "s/^version:.*/version: <new-version>/" Chart.yaml
   ```
   Updates both `version` and `appVersion`

3. **Package Chart**
   ```bash
   helm package helm/<chart-name> --destination .helm-packages
   ```
   Creates `.tgz` archive

4. **Generate Metadata**
   Creates JSON metadata file:
   ```json
   {
     "chart": "demo-app",
     "version": "1.0.1",
     "package": "demo-app-1.0.1.tgz",
     "commit": "abc123",
     "timestamp": "2024-01-06T12:00:00Z",
     "repository": "fsongt-ext/kubernetes-extreme-lab"
   }
   ```

5. **Upload to Azure Blob Storage**
   ```bash
   az storage blob upload \
     --account-name <storage-account> \
     --container-name helm-charts \
     --name charts/<chart>-<version>.tgz \
     --file <package>
   ```

6. **Update Helm Repository Index**
   ```bash
   helm repo index .helm-packages --url <repo-url> --merge index.yaml
   az storage blob upload --name index.yaml
   ```
   Generates/updates `index.yaml` with new chart version

7. **Create GitHub Release**
   - Tag: `<chart-name>-v<version>`
   - Includes installation instructions
   - Attaches `.tgz` package

8. **Generate SBOM**
   ```bash
   syft packages dir:helm/<chart-name> -o spdx-json
   ```
   Creates Software Bill of Materials in SPDX format

## Using the Helm Repository

### Setup

After Terraform deployment, get the Helm repository URL:

```bash
cd infrastructure/terraform/environments/lab
terraform output helm_repo_url
```

### Add Repository

```bash
# Add the repository
helm repo add k3s-lab <helm_repo_url>

# Update repository index
helm repo update
```

### Search Charts

```bash
# List all charts
helm search repo k3s-lab

# Search specific chart
helm search repo k3s-lab/demo-app
```

### Install Chart

```bash
# Install latest version
helm install my-release k3s-lab/demo-app

# Install specific version
helm install my-release k3s-lab/demo-app --version 1.0.1

# Install with custom values
helm install my-release k3s-lab/demo-app \
  --values custom-values.yaml \
  --namespace demo \
  --create-namespace
```

### Upgrade Chart

```bash
# Upgrade to latest version
helm upgrade my-release k3s-lab/demo-app

# Upgrade with rollback on failure
helm upgrade my-release k3s-lab/demo-app --atomic --timeout 5m
```

## Versioning Strategy

### Semantic Versioning

Charts follow [SemVer](https://semver.org/):

- **MAJOR** (X.0.0) - Breaking changes
- **MINOR** (0.X.0) - New features (backwards compatible)
- **PATCH** (0.0.X) - Bug fixes (backwards compatible)

### Auto-versioning

**Default Behavior:**
- Pipeline auto-increments **patch** version
- Example: `1.0.0` → `1.0.1`

**Manual Override:**
- Use `force_version` input in workflow dispatch
- Example: Force version `2.0.0` for breaking changes

### Version Management

**Chart.yaml:**
```yaml
version: 1.0.1      # Chart version
appVersion: "1.0.1" # Application version (should match for app charts)
```

**Best Practices:**
1. Keep `version` and `appVersion` in sync for application charts
2. Bump `version` for any chart changes
3. Bump `appVersion` only for application code changes
4. Use wrapper charts for external dependencies (keep appVersion separate)

## Security Features

### 1. Code Scanning

- **Semgrep** - SAST for Chart templates
- **Trivy** - IaC and manifest scanning
- **Kubesec** - Kubernetes security analysis

### 2. Access Control

- **Azure Blob Storage:**
  - Public read access (for Helm repository)
  - Write access via storage key (GitHub Actions only)

- **GitHub Secrets:**
  - `HELM_STORAGE_KEY` stored encrypted
  - Only accessible to workflow runs

### 3. Supply Chain Security

- **SBOM Generation** - Tracks all chart dependencies
- **GitHub Releases** - Signed and tagged
- **Blob Versioning** - Immutable chart versions
- **Soft Delete** - 7-day recovery window

### 4. Best Practices

- HTTPS-only access
- TLS 1.2 minimum
- CORS configuration for web access
- Lifecycle policies for old versions

## Troubleshooting

### Common Issues

#### 1. Pipeline Fails at "Upload to Azure Blob Storage"

**Symptoms:**
```
ERROR: The request may be blocked by network rules
```

**Cause:** Storage account public access disabled

**Solution:**
```bash
cd infrastructure/terraform/environments/lab
terraform apply
# Ensure public_network_access_enabled = true
```

#### 2. Helm Repo Add Fails

**Symptoms:**
```
Error: failed to download index.yaml
```

**Cause:** `index.yaml` doesn't exist yet

**Solution:** Run pipeline at least once to generate index

#### 3. Version Conflict

**Symptoms:**
```
Error: chart version already exists
```

**Cause:** Version not incremented

**Solution:**
- Update `version` in Chart.yaml manually, or
- Use `force_version` in workflow dispatch

#### 4. Schema Validation Fails

**Symptoms:**
```
Error: values.yaml does not match schema
```

**Cause:** Values don't conform to `values.schema.json`

**Solution:** Fix values or update schema

### Debugging

#### Check Pipeline Logs

1. Go to GitHub Actions tab
2. Select "Helm Chart Release Pipeline"
3. Click on specific run
4. Review job logs

#### Verify Storage Contents

```bash
az storage blob list \
  --account-name <storage-account> \
  --container-name helm-charts \
  --output table
```

#### Test Chart Locally

```bash
# Lint
helm lint helm/<chart-name>

# Template
helm template test helm/<chart-name> --debug

# Install to local cluster
helm install test helm/<chart-name> --dry-run --debug
```

## Maintenance

### Storage Lifecycle

**Automatic Actions:**
- After 90 days: Chart archives moved to cool tier
- After 365 days: Old versions deleted
- Soft delete: 7-day retention

**Manual Cleanup:**
```bash
# List all blobs
az storage blob list --account-name <storage> --container-name helm-charts

# Delete specific version
az storage blob delete \
  --account-name <storage> \
  --container-name helm-charts \
  --name charts/<chart>-<version>.tgz
```

### Update Terraform Infrastructure

```bash
cd infrastructure/terraform/environments/lab

# Plan changes
terraform plan

# Apply changes
terraform apply

# Verify outputs
terraform output helm_storage_account_name
terraform output helm_repo_url
```

### Rotate Storage Keys

```bash
# Regenerate key in Azure
az storage account keys renew \
  --account-name <storage> \
  --key primary

# Update GitHub secret
gh secret set HELM_STORAGE_KEY --body "<new-key>"
```

## Best Practices

### Chart Development

1. **Use values-lab.yaml pattern**
   - Keep `values.yaml` as defaults
   - Override with environment-specific files

2. **Include README.md**
   - Installation instructions
   - Configuration options
   - Examples

3. **Add values.schema.json** (optional)
   - Validates user input
   - Provides better error messages

4. **Use templates/** wisely
   - Keep templates simple
   - Use `_helpers.tpl` for common logic
   - Follow Helm best practices

### CI/CD Integration

1. **Trigger on relevant changes**
   - Only `helm/**` changes trigger pipeline
   - Reduces unnecessary runs

2. **Use matrix builds**
   - Parallel processing for multiple charts
   - Faster feedback

3. **Fail fast**
   - Lint and test before package
   - Catch errors early

4. **Generate artifacts**
   - SBOM for compliance
   - Metadata for tracking

## References

- [Helm Documentation](https://helm.sh/docs/)
- [Azure Blob Storage](https://docs.microsoft.com/azure/storage/blobs/)
- [Chart Testing](https://github.com/helm/chart-testing)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [SemVer Specification](https://semver.org/)
