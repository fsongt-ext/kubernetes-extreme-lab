#!/usr/bin/env bash

##############################################################################
# Destroy Script - K3s Lab Cluster
#
# Tears down the entire K3s cluster and infrastructure
#
# Usage: ./destroy.sh [--force]
##############################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/infrastructure/terraform/environments/lab"

FORCE=false

##############################################################################
# Functions
##############################################################################

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

uninstall_k3s() {
    log_info "Uninstalling K3s..."

    if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
        sudo /usr/local/bin/k3s-uninstall.sh
        log_info "K3s uninstalled successfully"
    else
        log_warning "K3s uninstall script not found, skipping"
    fi
}

destroy_terraform() {
    log_info "Destroying Terraform resources..."

    cd "$TERRAFORM_DIR"

    terraform destroy -auto-approve

    log_info "Terraform resources destroyed"
}

cleanup_files() {
    log_info "Cleaning up generated files..."

    # Clean Terraform files
    rm -f "$TERRAFORM_DIR/tfplan"
    rm -f "$TERRAFORM_DIR/terraform.tfstate.backup"
    rm -rf "$TERRAFORM_DIR/.terraform"

    # Clean kubeconfig
    if [ -f "$HOME/.kube/config" ]; then
        log_warning "Backing up kubeconfig to ~/.kube/config.backup"
        cp "$HOME/.kube/config" "$HOME/.kube/config.backup"
        rm -f "$HOME/.kube/config"
    fi

    log_info "Cleanup completed"
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
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    log_warning "====================================="
    log_warning "  DESTROY K3S LAB CLUSTER"
    log_warning "====================================="
    log_warning "This will:"
    log_warning "  - Uninstall K3s"
    log_warning "  - Destroy all Terraform resources"
    log_warning "  - Remove generated files"
    log_warning ""

    if [ "$FORCE" = false ]; then
        log_warning "Are you sure? Type 'destroy' to confirm:"
        read -r confirmation
        if [ "$confirmation" != "destroy" ]; then
            log_info "Destroy cancelled"
            exit 0
        fi
    fi

    # Uninstall K3s
    uninstall_k3s

    # Destroy Terraform
    destroy_terraform

    # Cleanup files
    cleanup_files

    log_info "====================================="
    log_info "  Cluster destroyed successfully!"
    log_info "====================================="
}

main "$@"
