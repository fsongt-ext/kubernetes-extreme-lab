#!/bin/bash
##############################################################################
# Fetch K3s Kubeconfig
#
# Usage:
#   ./fetch-kubeconfig.sh              # Merge with ~/.kube/config
#   ./fetch-kubeconfig.sh --standalone # Save as standalone file only
##############################################################################

set -e

# Get project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Paths
INVENTORY="${PROJECT_ROOT}/infrastructure/ansible/inventory/lab.ini"
KUBECONFIG_FILE="${PROJECT_ROOT}/infrastructure/terraform/environments/lab/kubeconfig.yaml"

# Parse VM info from inventory
VM_IP=$(grep "ansible_host=" "$INVENTORY" | head -1 | sed 's/.*ansible_host=\([^ ]*\).*/\1/')
VM_USER=$(grep "ansible_user=" "$INVENTORY" | head -1 | sed 's/.*ansible_user=\([^ ]*\).*/\1/')

echo "Fetching kubeconfig from ${VM_USER}@${VM_IP}..."

# Fetch kubeconfig
mkdir -p "$(dirname "$KUBECONFIG_FILE")"
ssh -o StrictHostKeyChecking=no "${VM_USER}@${VM_IP}" 'sudo cat /etc/rancher/k3s/k3s.yaml' > "$KUBECONFIG_FILE"

# Replace localhost with VM IP
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS requires empty string for in-place edit
    sed -i '' "s/127.0.0.1/${VM_IP}/g" "$KUBECONFIG_FILE"
else
    # Linux
    sed -i "s/127.0.0.1/${VM_IP}/g" "$KUBECONFIG_FILE"
fi
chmod 600 "$KUBECONFIG_FILE"

echo "✓ Kubeconfig saved to: $KUBECONFIG_FILE"

# Merge or standalone
if [[ "$1" == "--standalone" ]]; then
    echo ""
    echo "To use it:"
    echo "  export KUBECONFIG=$KUBECONFIG_FILE"
    echo "  kubectl get nodes"
else
    # Merge with ~/.kube/config
    mkdir -p ~/.kube
    
    if [ -f ~/.kube/config ]; then
        cp ~/.kube/config ~/.kube/config.backup-$(date +%Y%m%d-%H%M%S)
        echo "✓ Backed up existing ~/.kube/config"
    fi
    
    KUBECONFIG=~/.kube/config:$KUBECONFIG_FILE kubectl config view --flatten > ~/.kube/config.tmp
    mv ~/.kube/config.tmp ~/.kube/config
    chmod 600 ~/.kube/config
    
    CONTEXT=$(kubectl --kubeconfig="$KUBECONFIG_FILE" config current-context)
    echo "✓ Merged with ~/.kube/config"
    echo ""
    echo "To use it:"
    echo "  kubectl config use-context $CONTEXT"
    echo "  kubectl get nodes"
fi
