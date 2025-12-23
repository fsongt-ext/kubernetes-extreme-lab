# Infrastructure

This directory contains Infrastructure as Code (IaC) for provisioning and configuring the K3s lab cluster.

## Directory Structure

```
infrastructure/
├── terraform/              # Infrastructure provisioning
│   ├── environments/
│   │   └── lab/           # Lab environment configuration
│   └── modules/           # Reusable Terraform modules
│       ├── k3s-cluster/
│       ├── networking/
│       └── storage/
│
├── ansible/               # Configuration management
│   ├── playbooks/        # Ansible playbooks
│   ├── roles/            # Ansible roles
│   ├── inventory/        # Inventory files
│   └── ansible.cfg       # Ansible configuration
│
└── scripts/              # Helper scripts
    ├── bootstrap.sh      # Complete cluster setup
    ├── destroy.sh        # Cluster teardown
    └── health-check.sh   # Cluster health validation
```

## Quick Start

### Prerequisites

- Terraform >= 1.9.0
- Ansible >= 2.15
- kubectl
- helm
- 2 vCPU / 8GB RAM minimum

### Bootstrap Cluster

```bash
# Full bootstrap (Terraform + Ansible)
./scripts/bootstrap.sh

# Terraform only
./scripts/bootstrap.sh --terraform-only

# Ansible only
./scripts/bootstrap.sh --ansible-only
```

### Verify Cluster

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
./scripts/health-check.sh
```

### Destroy Cluster

```bash
./scripts/destroy.sh
```

## Terraform

### Initialize and Apply

```bash
cd terraform/environments/lab
terraform init
terraform plan
terraform apply
```

### Configuration

Edit `terraform.tfvars` to customize:
- K3s version
- Resource limits
- Network CIDRs
- Security settings

## Ansible

### Run Playbooks

```bash
cd ansible

# System hardening
ansible-playbook -i inventory/lab.ini playbooks/hardening.yaml

# Install K3s
ansible-playbook -i inventory/lab.ini playbooks/k3s-install.yaml
```

### Roles

- **common**: System prerequisites and tools
- **security**: OS hardening (CIS benchmarks)
- **k3s**: K3s installation and configuration
- **monitoring**: Monitoring agents

## Next Steps

After infrastructure setup:

1. Deploy platform components:
   ```bash
   cd ../platform
   ```

2. Configure GitOps:
   ```bash
   cd ../gitops
   ```

3. Deploy applications:
   ```bash
   cd ../applications
   ```

## Troubleshooting

### K3s fails to start

```bash
# Check logs
sudo journalctl -u k3s -f

# Verify system requirements
free -h
nproc
```

### Terraform state issues

```bash
# Remove local state (use with caution)
rm -rf .terraform terraform.tfstate*
terraform init
```

### Ansible connection issues

```bash
# Test connectivity
ansible -i inventory/lab.ini k3s_cluster -m ping

# Verbose output
ansible-playbook -i inventory/lab.ini playbooks/k3s-install.yaml -vvv
```
