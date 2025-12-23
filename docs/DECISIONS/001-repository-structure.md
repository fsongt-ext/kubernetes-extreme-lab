# ADR 001: Repository Structure - Monorepo Approach

**Status:** Accepted
**Date:** 2023-12-23
**Deciders:** Platform Architecture Team
**Technical Story:** Platform repository organization

## Context

We need to decide on the repository structure for the Kubernetes platform lab project, which includes infrastructure provisioning, platform components, applications, and GitOps configurations.

### Options Considered

1. **Multi-repo approach** - Separate repositories for infrastructure, platform, applications
2. **Monorepo approach** - Single repository with clear directory boundaries
3. **Hybrid approach** - Core platform in one repo, applications in separate repos

## Decision

We will use a **monorepo approach** with clear directory boundaries and modular structure.

### Repository Structure

```
kubernetes-extreme-lab/
├── .github/           # CI/CD workflows and automation
├── infrastructure/    # IaC (Terraform, Ansible)
├── platform/          # Platform components (Helm charts)
├── applications/      # Application workloads
├── gitops/            # ArgoCD Application manifests
├── tests/             # All testing code
├── tools/             # Development and operational tools
├── policies/          # Policy-as-code (OPA, Kyverno, Conftest)
├── security/          # Security scanning and compliance
└── docs/              # Documentation
```

## Rationale

### Advantages of Monorepo

1. **Atomic Changes**
   - Single PR can update infrastructure, platform, and applications together
   - Easier to maintain consistency across components
   - Clear dependency tracking

2. **Simplified CI/CD**
   - Single pipeline configuration
   - Unified versioning strategy
   - Easier to implement integration tests

3. **Developer Experience**
   - Clone once, see everything
   - Easier onboarding for new team members
   - Unified tooling and linting

4. **Change Management**
   - Clear audit trail in single Git history
   - Easier to review cross-cutting changes
   - Better code review workflow

### Disadvantages (Mitigated)

1. **Repository Size**
   - Mitigation: Use `.gitignore` for generated artifacts, binaries
   - Git LFS for large files (if needed)

2. **Access Control**
   - Mitigation: Use CODEOWNERS and branch protection
   - Directory-level permissions via CI checks

3. **CI/CD Complexity**
   - Mitigation: Use path-based triggers in GitHub Actions
   - Selective job execution based on changed files

## Consequences

### Positive

- **Cohesive platform view** - All components visible in single repository
- **Simplified dependency management** - Changes propagate clearly
- **Better testing** - Integration tests across components easier
- **Unified documentation** - All docs in one place

### Negative

- **Larger clone size** - Mitigated by shallow clones in CI
- **Potential merge conflicts** - Mitigated by clear directory ownership
- **CI build times** - Mitigated by path-based job triggers

### Neutral

- **Requires discipline** - Teams must follow directory structure conventions
- **CODEOWNERS enforcement** - Platform team owns `/platform`, `/infrastructure`
- **Versioning strategy** - Use tags for releases, directory-specific versioning

## Implementation

### CODEOWNERS

```
# Platform Team owns infrastructure and platform components
/infrastructure/ @platform-team
/platform/ @platform-team
/gitops/bootstrap/ @platform-team
/gitops/projects/ @platform-team

# Application Team owns application code
/applications/ @app-team
/gitops/environments/*/applications/ @app-team
```

### CI/CD Path Triggers

```yaml
on:
  push:
    paths:
      - 'infrastructure/**'
      - 'platform/**'
  pull_request:
    paths:
      - 'applications/**'
```

### Directory Isolation

- Each directory is self-contained with its own README
- No cross-directory relative imports
- Shared utilities in `/tools`

## Alternatives Considered

### Multi-Repo Approach

**Pros:**
- Smaller repository size per team
- Independent CI/CD pipelines
- Clearer ownership boundaries

**Cons:**
- Complex dependency management across repos
- Difficult to maintain consistency
- Cross-cutting changes require multiple PRs
- Integration testing challenges

**Rejected because:** Overhead of managing multiple repositories outweighs benefits for a lab environment.

### Hybrid Approach

**Pros:**
- Platform stability separate from application changes
- Core platform has stricter controls

**Cons:**
- Still requires cross-repo coordination
- Application teams need access to two repos
- Harder to maintain full platform in sync

**Rejected because:** Adds complexity without significant benefits for our team size.

## References

- [Google Monorepo Philosophy](https://cacm.acm.org/magazines/2016/7/204032-why-google-stores-billions-of-lines-of-code-in-a-single-repository/fulltext)
- [Nx Monorepo Best Practices](https://nx.dev/concepts/more-concepts/why-monorepos)
- [ArgoCD App-of-Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)

## Revision History

| Date | Version | Changes |
|------|---------|---------|
| 2023-12-23 | 1.0 | Initial decision |
