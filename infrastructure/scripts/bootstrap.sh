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

# Flags
RUN_TERRAFORM=true
RUN_ANSIBLE=true

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

    log_success "Ansible playbooks completed successfully"
}

verify_cluster() {
    log_info "Verifying K3s cluster..."

    # Export kubeconfig
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

    if ! kubectl cluster-info &> /dev/null; then
        log_error "Failed to connect to K3s cluster"
        return 1
    fi

    log_info "Cluster information:"
    kubectl cluster-info

    log_info "Node status:"
    kubectl get nodes

    log_info "System pods:"
    kubectl get pods -A

    log_success "Cluster verification completed"
}

display_summary() {
    echo ""
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}  Bootstrap Completed!${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Export kubeconfig:"
    echo "   export KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
    echo ""
    echo "2. Verify cluster:"
    echo "   kubectl get nodes"
    echo "   kubectl get pods -A"
    echo ""
    echo "3. Deploy platform components:"
    echo "   cd ${PROJECT_ROOT}/platform"
    echo "   ./deploy-platform.sh"
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
                shift
                ;;
            --ansible-only)
                RUN_TERRAFORM=false
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

    # Display summary
    display_summary
}

main "$@"
