#!/usr/bin/env bash

##############################################################################
# Health Check Script - K3s Lab Cluster
#
# Performs comprehensive health checks on the cluster
##############################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Export kubeconfig
export KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"

##############################################################################
# Functions
##############################################################################

print_header() {
    echo ""
    echo -e "${BLUE}===================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}===================================================${NC}"
}

check_cluster_connectivity() {
    print_header "Cluster Connectivity"

    if kubectl cluster-info &> /dev/null; then
        echo -e "${GREEN}✓${NC} Cluster is accessible"
        kubectl cluster-info
    else
        echo -e "${RED}✗${NC} Cannot connect to cluster"
        return 1
    fi
}

check_node_status() {
    print_header "Node Status"

    kubectl get nodes -o wide

    local ready_nodes
    ready_nodes=$(kubectl get nodes --no-headers | grep -c " Ready" || true)
    local total_nodes
    total_nodes=$(kubectl get nodes --no-headers | wc -l)

    if [ "$ready_nodes" -eq "$total_nodes" ]; then
        echo -e "${GREEN}✓${NC} All nodes are Ready ($ready_nodes/$total_nodes)"
    else
        echo -e "${RED}✗${NC} Some nodes are not Ready ($ready_nodes/$total_nodes)"
    fi
}

check_system_pods() {
    print_header "System Pods Status"

    kubectl get pods -n kube-system

    local not_running
    not_running=$(kubectl get pods -n kube-system --no-headers | grep -v "Running\|Completed" | wc -l || true)

    if [ "$not_running" -eq 0 ]; then
        echo -e "${GREEN}✓${NC} All system pods are healthy"
    else
        echo -e "${YELLOW}⚠${NC} $not_running system pods are not running"
    fi
}

check_resource_usage() {
    print_header "Resource Usage"

    echo "Node resources:"
    kubectl top nodes 2>/dev/null || echo "Metrics server not available"

    echo ""
    echo "Pod resources (top 10):"
    kubectl top pods -A --sort-by=memory 2>/dev/null | head -11 || echo "Metrics server not available"
}

check_api_resources() {
    print_header "API Resources"

    local resource_count
    resource_count=$(kubectl api-resources --verbs=list --namespaced -o name | wc -l)

    echo -e "${GREEN}✓${NC} $resource_count API resources available"
}

check_critical_services() {
    print_header "Critical Services"

    local services=(
        "kube-system:kube-dns"
    )

    for svc in "${services[@]}"; do
        local namespace="${svc%%:*}"
        local service="${svc##*:}"

        if kubectl get service -n "$namespace" "$service" &> /dev/null; then
            echo -e "${GREEN}✓${NC} Service $namespace/$service exists"
        else
            echo -e "${RED}✗${NC} Service $namespace/$service not found"
        fi
    done
}

check_storage() {
    print_header "Storage Classes"

    kubectl get storageclass

    local default_sc
    default_sc=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')

    if [ -n "$default_sc" ]; then
        echo -e "${GREEN}✓${NC} Default storage class: $default_sc"
    else
        echo -e "${YELLOW}⚠${NC} No default storage class configured"
    fi
}

generate_summary() {
    print_header "Health Check Summary"

    echo "Cluster: $(kubectl config current-context)"
    echo "Kubernetes Version: $(kubectl version --short 2>/dev/null | grep Server | cut -d' ' -f3)"
    echo "Nodes: $(kubectl get nodes --no-headers | wc -l)"
    echo "Namespaces: $(kubectl get namespaces --no-headers | wc -l)"
    echo "Pods (all): $(kubectl get pods -A --no-headers | wc -l)"
    echo "Services (all): $(kubectl get services -A --no-headers | wc -l)"
    echo ""
    echo -e "${GREEN}Health check completed!${NC}"
}

##############################################################################
# Main
##############################################################################

main() {
    echo -e "${BLUE}K3s Lab Cluster Health Check${NC}"
    echo -e "${BLUE}Kubeconfig: $KUBECONFIG${NC}"

    check_cluster_connectivity || exit 1
    check_node_status
    check_system_pods
    check_resource_usage
    check_api_resources
    check_critical_services
    check_storage
    generate_summary
}

main "$@"
