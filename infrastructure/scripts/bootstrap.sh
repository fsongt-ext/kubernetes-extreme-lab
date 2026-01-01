#!/usr/bin/env bash

##############################################################################
# Bootstrap Script - K3s Lab Cluster
#
# Provisions infrastructure and installs K3s cluster
#
# Usage: ./bootstrap.sh [options]
#
# Options:
#   --terraform-only    Run only Terraform
#   --ansible-only      Run only Ansible
#   --skip-terraform    Skip Terraform step
#   --skip-ansible      Skip Ansible step
#   --skip-argocd       Skip ArgoCD installation
##############################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/infrastructure/terraform/environments/lab"
ANSIBLE_DIR="${PROJECT_ROOT}/infrastructure/ansible"

# SSH Key for ArgoCD repository access
ARGOCD_SSH_KEY="${ARGOCD_SSH_KEY:-$HOME/.ssh/id_ed25519_personal}"

# Flags
RUN_TERRAFORM=true
RUN_ANSIBLE=true
RUN_ARGOCD=true

##############################################################################
# Functions
##############################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    local missing_tools=()

    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi

    if ! command -v ansible &> /dev/null; then
        missing_tools+=("ansible")
    fi

    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi

    if ! command -v helm &> /dev/null; then
        missing_tools+=("helm")
    fi

    if ! command -v yq &> /dev/null; then
        missing_tools+=("yq")
    fi

    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install missing tools and try again"
        exit 1
    fi

    log_success "All prerequisites satisfied"
}

run_terraform() {
    log_info "Running Terraform..."

    cd "$TERRAFORM_DIR"

    log_info "Initializing Terraform..."
    terraform init

    log_info "Validating Terraform configuration..."
    terraform validate

    log_info "Planning Terraform changes..."
    terraform plan -out=tfplan

    log_warning "Review the plan above. Continue? (yes/no)"
    read -r response
    if [[ "$response" != "yes" ]]; then
        log_info "Terraform apply cancelled"
        return 1
    fi

    log_info "Applying Terraform configuration..."
    terraform apply tfplan

    rm -f tfplan

    log_success "Terraform completed successfully"
}

run_ansible() {
    log_info "Running Ansible playbooks..."

    cd "$ANSIBLE_DIR"

    log_info "Running system hardening playbook..."
    ansible-playbook -i inventory/lab.ini playbooks/hardening.yaml

    log_info "Running K3s installation playbook..."
    ansible-playbook -i inventory/lab.ini playbooks/k3s-install.yaml

    log_info "Running Caddy installation playbook..."
    ansible-playbook -i inventory/lab.ini playbooks/caddy-install.yaml

    log_info "Running Keycloak installation playbook..."
    ansible-playbook -i inventory/lab.ini playbooks/keycloak-install.yaml

    log_success "Ansible playbooks completed successfully"
}

verify_cluster() {
    log_info "Verifying K3s cluster..."
    export KUBECONFIG="${TERRAFORM_DIR}/kubeconfig.yaml"

    if ! kubectl cluster-info &> /dev/null; then
        log_error "Failed to connect to K3s cluster"
        return 1
    fi

    log_success "Cluster verification completed"
}

install_argocd() {
    log_info "Installing ArgoCD..."

    export KUBECONFIG="${TERRAFORM_DIR}/kubeconfig.yaml"

    # Validate SSH key exists
    if [ ! -f "$ARGOCD_SSH_KEY" ]; then
        log_error "SSH key not found at: $ARGOCD_SSH_KEY"
        log_info "Set ARGOCD_SSH_KEY environment variable or update the script"
        log_info "Example: export ARGOCD_SSH_KEY=~/.ssh/id_ed25519"
        return 1
    fi
    
    log_info "Using SSH key: $ARGOCD_SSH_KEY"

    # Create namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -


    # Add GitHub SSH known hosts
    log_info "Configuring SSH known hosts for GitHub..."
    kubectl create secret generic argocd-ssh-known-hosts \
        --from-literal=ssh_known_hosts="$(ssh-keyscan github.com 2>/dev/null)" \
        -n argocd \
        --dry-run=client -o yaml | kubectl apply -f -


    # Create GitHub repository SSH secret directly (imperative approach)
    log_info "Creating GitHub repository SSH secret..."
    kubectl create secret generic github-repo-ssh \
        --from-file=sshPrivateKey="$ARGOCD_SSH_KEY" \
        --from-literal=url=git@github.com:TrungHQ-02/kubernetes-extreme-lab.git \
        --from-literal=type=git \
        -n argocd \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Label the secret so ArgoCD recognizes it
    kubectl label secret github-repo-ssh -n argocd \
        argocd.argoproj.io/secret-type=repository --overwrite
    local repo_template="${PROJECT_ROOT}/gitops/bootstrap/repository.yaml"
    local repo_temp="/tmp/argocd-repository-temp.yaml"
    
    cp "$repo_template" "$repo_temp"
    yq eval ".stringData.sshPrivateKey = \"$(cat "$ARGOCD_SSH_KEY")\"" -i "$repo_temp"
    kubectl apply -f "$repo_temp"
    rm -f "$repo_temp"
    
    log_success "SSH credentials configured"

    # Navigate to ArgoCD chart and update dependencies
    cd "${PROJECT_ROOT}/platform/core/argocd"
    helm dependency update

    # Install ArgoCD using custom chart with lab-specific values
    helm upgrade --install argocd . \
        --namespace argocd \
        --create-namespace \
        --values values-lab.yaml \
        --wait \
        --timeout 10m

    # Wait for ArgoCD server
    kubectl wait --for=condition=available --timeout=300s \
        deployment/argocd-server -n argocd

    log_success "ArgoCD installed"
    log_info "Password configured in values.yaml (default: admin)"
}

bootstrap_gitops() {
    log_info "Bootstrapping GitOps..."

    export KUBECONFIG="${TERRAFORM_DIR}/kubeconfig.yaml"

    # Apply projects and root application
    kubectl apply -f "${PROJECT_ROOT}/gitops/projects/"
    sleep 2
    kubectl apply -f "${PROJECT_ROOT}/gitops/bootstrap/root-application.yaml"

    log_success "GitOps bootstrap completed"
}

display_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           Bootstrap Completed Successfully!           ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    export KUBECONFIG="${TERRAFORM_DIR}/kubeconfig.yaml"
    
    # Get VM IP
    VM_IP=$(cd "$TERRAFORM_DIR" && terraform output -raw vm_public_ip 2>/dev/null || echo "N/A")
    
    echo -e "${BLUE}Cluster Access:${NC}"
    echo "  Kubeconfig: ${TERRAFORM_DIR}/kubeconfig.yaml"
    echo "  Export:     export KUBECONFIG=${TERRAFORM_DIR}/kubeconfig.yaml"
    echo ""
    
    echo -e "${BLUE}ArgoCD Access:${NC}"
    echo "  URL:        https://argocd.lab.local (or http://${VM_IP}:30080)"
    echo "  Username:   admin"
    echo "  Password:   admin (configured in platform/core/argocd/values.yaml)"
    echo ""
    
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "  Check cluster:      kubectl get nodes"
    echo "  Check applications: kubectl get applications -n argocd"
    echo "  Watch sync:         kubectl get applications -n argocd -w"
    echo "  Port forward:       kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo ""
    
    echo -e "${GREEN}GitOps is active! ArgoCD will deploy all components automatically.${NC}"
    echo ""
}

##############################################################################
# Main
##############################################################################

main() {
    log_info "Starting K3s Lab Cluster Bootstrap"
    log_info "Project Root: $PROJECT_ROOT"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --terraform-only)
                RUN_ANSIBLE=false
                RUN_ARGOCD=false
                shift
                ;;
            --ansible-only)
                RUN_TERRAFORM=false
                RUN_ARGOCD=false
                shift
                ;;
            --skip-terraform)
                RUN_TERRAFORM=false
                shift
                ;;
            --skip-ansible)
                RUN_ANSIBLE=false
                shift
                ;;
            --skip-argocd)
                RUN_ARGOCD=false
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Check prerequisites
    check_prerequisites

    # Run Terraform
    if [ "$RUN_TERRAFORM" = true ]; then
        run_terraform || exit 1
    else
        log_warning "Skipping Terraform"
    fi

    # Run Ansible
    if [ "$RUN_ANSIBLE" = true ]; then
        run_ansible || exit 1
    else
        log_warning "Skipping Ansible"
    fi

    # Verify cluster
    verify_cluster || exit 1

    # Install ArgoCD
    if [ "$RUN_ARGOCD" = true ]; then
        install_argocd || exit 1
        bootstrap_gitops || exit 1
    else
        log_warning "Skipping ArgoCD installation"
    fi

    # Display summary
    display_summary
}

main "$@"
