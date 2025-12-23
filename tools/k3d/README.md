# K3d Local Development

K3d configuration for running the platform locally using Docker.

## Prerequisites

```bash
# Install Docker
# macOS: https://docs.docker.com/desktop/mac/install/

# Install K3d
brew install k3d  # macOS
# Or: curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Install kubectl
brew install kubectl
```

## Quick Start

```bash
# Create cluster
k3d cluster create --config tools/k3d/cluster-config.yaml

# Verify cluster
kubectl get nodes
kubectl cluster-info

# Deploy platform (ArgoCD + App-of-Apps)
kubectl apply -f gitops/bootstrap/root-application.yaml

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get ArgoCD password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Cluster Management

### Create Cluster

```bash
k3d cluster create --config tools/k3d/cluster-config.yaml
```

### Delete Cluster

```bash
k3d cluster delete extreme-lab
```

### Stop/Start Cluster

```bash
# Stop (preserves state)
k3d cluster stop extreme-lab

# Start
k3d cluster start extreme-lab
```

### List Clusters

```bash
k3d cluster list
```

## Port Mappings

- `8080` → HTTP traffic (Kong/Istio ingress)
- `8443` → HTTPS traffic
- `6443` → Kubernetes API server

## Local Registry

K3d creates a local Docker registry at `localhost:5000` for faster image pulls.

```bash
# Tag and push images to local registry
docker tag demo-app:latest localhost:5000/demo-app:latest
docker push localhost:5000/demo-app:latest

# Update image in Helm values to use local registry
# image.repository: k3d-registry.localhost:5000/demo-app
```

## Differences from Lab Environment

| Feature | Lab (K3s) | Local (K3d) |
|---------|-----------|-------------|
| Nodes | 1 bare metal | 1 server + 2 agents (Docker) |
| Storage | Local paths | Docker volumes |
| Load Balancer | MetalLB | K3d proxy |
| Network | Host network | Docker network |
| Performance | Native | Containerized overhead |

## Troubleshooting

### Cluster creation fails

```bash
# Check Docker is running
docker ps

# Check available resources
docker info | grep -i "cpus\|memory"

# Delete and recreate
k3d cluster delete extreme-lab
k3d cluster create --config tools/k3d/cluster-config.yaml
```

### Port conflicts

```bash
# Check what's using port 8080
lsof -i :8080

# Modify ports in cluster-config.yaml if needed
```

### Out of disk space

```bash
# Clean up Docker resources
docker system prune -a --volumes

# Check disk usage
docker system df
```
