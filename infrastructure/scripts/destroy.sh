#!/usr/bin/env bash

##############################################################################
# Destroy Script - K3s Lab Cluster
#
# Tears down the entire K3s cluster and infrastructure
#
# Usage: ./destroy.sh [options]
#
# Options:
#   --force             Skip confirmation
#   --argocd-only       Only uninstall ArgoCD
#   --terraform-only    Only destroy Terraform resources
#   --skip-argocd       Skip ArgoCD uninstall
#   --skip-k3s          Skip K3s uninstall
#   --skip-terraform    Skip Terraform destroy
#   --skip-cleanup      Skip file cleanup
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

# Flags
FORCE=false
ARGOCD_ONLY=false
TERRAFORM_ONLY=false
RUN_ARGOCD=true
RUN_K3S=true
RUN_TERRAFORM=true
RUN_CLEANUP=true

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

uninstall_argocd() {
    log_info "Uninstalling ArgoCD..."

    export KUBECONFIG="${TERRAFORM_DIR}/kubeconfig.yaml"

    # Check if kubeconfig exists
    if [ ! -f "$KUBECONFIG" ]; then
        log_warning "Kubeconfig not found at: $KUBECONFIG"
        log_warning "Skipping ArgoCD uninstall"
        return
    fi

    # Check if kubectl can connect
    if ! kubectl cluster-info &> /dev/null; then
        log_warning "Cannot connect to cluster, skipping ArgoCD uninstall"
        return
    fi

    # Check if ArgoCD namespace exists
    if kubectl get namespace argocd &> /dev/null; then
        # Delete root application first (stops ArgoCD from recreating resources)
        log_info "Deleting root application..."
        kubectl delete application root -n argocd --timeout=60s 2>/dev/null || true

        # Delete all ArgoCD applications
        log_info "Deleting all ArgoCD applications..."
        kubectl delete applications --all -n argocd --timeout=120s 2>/dev/null || true

        # Delete ArgoCD projects
        log_info "Deleting ArgoCD projects..."
        kubectl delete appprojects --all -n argocd --timeout=60s 2>/dev/null || true

        # Uninstall ArgoCD Helm release
        log_info "Uninstalling ArgoCD Helm release..."
        helm uninstall argocd -n argocd --wait --timeout 5m 2>/dev/null || true

        # Delete namespace (this will clean up any remaining resources)
        log_info "Deleting ArgoCD namespace..."
        kubectl delete namespace argocd --timeout=120s 2>/dev/null || true

        log_success "ArgoCD uninstalled successfully"
    else
        log_warning "ArgoCD namespace not found, skipping"
    fi
}

uninstall_k3s() {
    log_info "Uninstalling K3s..."

    export KUBECONFIG="${TERRAFORM_DIR}/kubeconfig.yaml"

    # Get VM info from Terraform
    cd "$TERRAFORM_DIR"
    
    if [ ! -f "terraform.tfstate" ]; then
        log_warning "Terraform state not found, cannot determine VM IP"
        return
    fi

    VM_IP=$(terraform output -raw vm_public_ip 2>/dev/null || echo "")
    VM_USER=$(terraform output -raw ssh_command 2>/dev/null | cut -d'@' -f1 | cut -d' ' -f2 || echo "azureuser")

    if [ -z "$VM_IP" ]; then
        log_warning "Cannot determine VM IP, skipping K3s uninstall"
        return
    fi

    log_info "Connecting to VM: ${VM_USER}@${VM_IP}"

    # Run K3s uninstall script on the VM
    if ssh -o StrictHostKeyChecking=no "${VM_USER}@${VM_IP}" \
        "[ -f /usr/local/bin/k3s-uninstall.sh ] && sudo /usr/local/bin/k3s-uninstall.sh" 2>/dev/null; then
        log_success "K3s uninstalled successfully from VM"
    else
        log_warning "K3s uninstall script not found on VM or SSH failed"
    fi
}

destroy_terraform() {
    log_info "Destroying Terraform resources..."

    cd "$TERRAFORM_DIR"

    if [ ! -f "terraform.tfstate" ]; then
        log_warning "Terraform state not found, nothing to destroy"
        return
    fi

    # Show what will be destroyed
    log_info "Planning Terraform destroy..."
    terraform plan -destroy

    if [ "$FORCE" = false ]; then
        log_warning "Review the destroy plan above. Continue? (yes/no)"
        read -r response
        if [[ "$response" != "yes" ]]; then
            log_info "Terraform destroy cancelled"
            return 1
        fi
    fi

    terraform destroy -auto-approve

    log_success "Terraform resources destroyed"
}

cleanup_files() {
    log_info "Cleaning up generated files..."

    # Clean Terraform files
    rm -f "$TERRAFORM_DIR/tfplan"
    rm -f "$TERRAFORM_DIR/kubeconfig.yaml"
    
    # Clean Ansible generated files
    rm -f "${PROJECT_ROOT}/infrastructure/ansible/inventory/lab.ini"
    rm -f "${PROJECT_ROOT}/infrastructure/ansible/roles/k3s/templates/k3s-config.yaml"
    rm -f "${PROJECT_ROOT}/infrastructure/ansible/roles/caddy/templates/Caddyfile"
    rm -f "${PROJECT_ROOT}/infrastructure/ansible/roles/keycloak/templates/keycloak.service"

    log_success "Cleanup completed"
}

##############################################################################
# Main
##############################################################################

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE=true
                shift
                ;;
            --argocd-only)
                ARGOCD_ONLY=true
                RUN_K3S=false
                RUN_TERRAFORM=false
                RUN_CLEANUP=false
                shift
                ;;
            --terraform-only)
                TERRAFORM_ONLY=true
                RUN_ARGOCD=false
                RUN_K3S=false
                RUN_CLEANUP=false
                shift
                ;;
            --skip-argocd)
                RUN_ARGOCD=false
                shift
                ;;
            --skip-k3s)
                RUN_K3S=false
                shift
                ;;
            --skip-terraform)
                RUN_TERRAFORM=false
                shift
                ;;
            --skip-cleanup)
                RUN_CLEANUP=false
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo ""
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  --force             Skip confirmation"
                echo "  --argocd-only       Only uninstall ArgoCD"
                echo "  --terraform-only    Only destroy Terraform resources"
                echo "  --skip-argocd       Skip ArgoCD uninstall"
                echo "  --skip-k3s          Skip K3s uninstall"
                echo "  --skip-terraform    Skip Terraform destroy"
                echo "  --skip-cleanup      Skip file cleanup"
                exit 1
                ;;
        esac
    done

    # Display what will be destroyed
    log_warning "====================================="
    log_warning "  DESTROY K3S LAB CLUSTER"
    log_warning "====================================="
    
    if [ "$ARGOCD_ONLY" = true ]; then
        log_warning "Mode: ArgoCD Only"
        log_warning "This will:"
        log_warning "  - Uninstall ArgoCD and all applications"
    elif [ "$TERRAFORM_ONLY" = true ]; then
        log_warning "Mode: Terraform Only"
        log_warning "This will:"
        log_warning "  - Destroy all Azure resources"
    else
        log_warning "Mode: Full Destroy"
        log_warning "This will:"
        [ "$RUN_ARGOCD" = true ] && log_warning "  - Uninstall ArgoCD"
        [ "$RUN_K3S" = true ] && log_warning "  - Uninstall K3s from VM"
        [ "$RUN_TERRAFORM" = true ] && log_warning "  - Destroy all Terraform resources"
        [ "$RUN_CLEANUP" = true ] && log_warning "  - Remove generated files"
    fi
    log_warning ""

    # Confirmation
    if [ "$FORCE" = false ]; then
        if [ "$ARGOCD_ONLY" = true ]; then
            log_warning "Type 'yes' to uninstall ArgoCD:"
        else
            log_warning "Type 'destroy' to confirm:"
        fi
        read -r confirmation
        
        if [ "$ARGOCD_ONLY" = true ]; then
            if [ "$confirmation" != "yes" ]; then
                log_info "Operation cancelled"
                exit 0
            fi
        else
            if [ "$confirmation" != "destroy" ]; then
                log_info "Destroy cancelled"
                exit 0
            fi
        fi
    fi

    # Execute destruction steps
    if [ "$RUN_ARGOCD" = true ]; then
        uninstall_argocd || log_warning "ArgoCD uninstall had errors"
    fi

    if [ "$RUN_K3S" = true ]; then
        uninstall_k3s || log_warning "K3s uninstall had errors"
    fi

    if [ "$RUN_TERRAFORM" = true ]; then
        destroy_terraform || exit 1
    fi

    if [ "$RUN_CLEANUP" = true ]; then
        cleanup_files || log_warning "Cleanup had errors"
    fi

    # Summary
    echo ""
    log_success "====================================="
    if [ "$ARGOCD_ONLY" = true ]; then
        log_success "  ArgoCD uninstalled successfully!"
    elif [ "$TERRAFORM_ONLY" = true ]; then
        log_success "  Terraform resources destroyed!"
    else
        log_success "  Cluster destroyed successfully!"
    fi
    log_success "====================================="
}

main "$@"
