#!/usr/bin/env bash
# Debug pod issues with detailed diagnostics

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
section() { echo -e "\n${BLUE}=== $1 ===${NC}\n"; }

# Check if pod exists
check_pod() {
    local namespace=$1
    local pod=$2

    if ! kubectl get pod "$pod" -n "$namespace" &>/dev/null; then
        error "Pod $pod not found in namespace $namespace"
        exit 1
    fi
}

# Show pod details
show_pod_details() {
    local namespace=$1
    local pod=$2

    section "Pod Details"
    kubectl get pod "$pod" -n "$namespace" -o wide

    section "Pod Status"
    kubectl describe pod "$pod" -n "$namespace" | grep -A 10 "^Status:\|^Conditions:"

    section "Pod Events"
    kubectl get events -n "$namespace" --field-selector involvedObject.name="$pod" --sort-by='.lastTimestamp'
}

# Show container statuses
show_container_status() {
    local namespace=$1
    local pod=$2

    section "Container Statuses"

    # Get container names
    local containers=$(kubectl get pod "$pod" -n "$namespace" -o jsonpath='{.spec.containers[*].name}')

    for container in $containers; do
        echo ""
        echo "Container: $container"
        echo "---"

        # Container state
        kubectl get pod "$pod" -n "$namespace" -o jsonpath="{.status.containerStatuses[?(@.name=='$container')].state}" | jq '.'

        # Restart count
        local restarts=$(kubectl get pod "$pod" -n "$namespace" -o jsonpath="{.status.containerStatuses[?(@.name=='$container')].restartCount}")
        echo "Restart count: $restarts"

        # Last termination reason (if any)
        local termination=$(kubectl get pod "$pod" -n "$namespace" -o jsonpath="{.status.containerStatuses[?(@.name=='$container')].lastState.terminated.reason}" 2>/dev/null || echo "N/A")
        if [ "$termination" != "N/A" ]; then
            echo "Last termination reason: $termination"
        fi
    done
}

# Show resource usage
show_resource_usage() {
    local namespace=$1
    local pod=$2

    section "Resource Usage"

    # Resource requests and limits
    echo "Resource Requests/Limits:"
    kubectl get pod "$pod" -n "$namespace" -o json | jq '.spec.containers[] | {name: .name, resources: .resources}'

    # Actual usage (requires metrics-server)
    echo ""
    echo "Actual Resource Usage:"
    if kubectl top pod "$pod" -n "$namespace" --containers 2>/dev/null; then
        :
    else
        warn "Metrics not available (metrics-server may not be installed)"
    fi
}

# Show network info
show_network_info() {
    local namespace=$1
    local pod=$2

    section "Network Information"

    # Pod IP
    local pod_ip=$(kubectl get pod "$pod" -n "$namespace" -o jsonpath='{.status.podIP}')
    echo "Pod IP: $pod_ip"

    # Service endpoints
    echo ""
    echo "Services exposing this pod:"
    kubectl get svc -n "$namespace" -o json | jq -r --arg ip "$pod_ip" '.items[] | select(.spec.clusterIP != "None") | select(.spec.selector != null) | "\(.metadata.name) (\(.spec.clusterIP):\(.spec.ports[0].port))"'

    # Network policies
    echo ""
    echo "Network Policies in namespace:"
    kubectl get networkpolicy -n "$namespace" -o wide
}

# Show logs
show_logs() {
    local namespace=$1
    local pod=$2
    local lines=${3:-50}

    section "Recent Logs (last $lines lines)"

    local containers=$(kubectl get pod "$pod" -n "$namespace" -o jsonpath='{.spec.containers[*].name}')

    for container in $containers; do
        echo ""
        echo "--- Logs from container: $container ---"
        kubectl logs "$pod" -n "$namespace" -c "$container" --tail="$lines" 2>&1 || warn "Could not retrieve logs for $container"
    done

    # Previous logs if pod restarted
    echo ""
    section "Previous Logs (if available)"

    for container in $containers; do
        if kubectl logs "$pod" -n "$namespace" -c "$container" --previous &>/dev/null; then
            echo ""
            echo "--- Previous logs from container: $container ---"
            kubectl logs "$pod" -n "$namespace" -c "$container" --previous --tail="$lines"
        fi
    done
}

# Check security context
show_security_context() {
    local namespace=$1
    local pod=$2

    section "Security Context"

    kubectl get pod "$pod" -n "$namespace" -o json | jq '.spec.securityContext, .spec.containers[] | {name: .name, securityContext: .securityContext}'
}

# Check volume mounts
show_volumes() {
    local namespace=$1
    local pod=$2

    section "Volumes and Mounts"

    echo "Volumes:"
    kubectl get pod "$pod" -n "$namespace" -o json | jq '.spec.volumes'

    echo ""
    echo "Volume Mounts:"
    kubectl get pod "$pod" -n "$namespace" -o json | jq '.spec.containers[] | {name: .name, volumeMounts: .volumeMounts}'
}

# Check probes
show_probes() {
    local namespace=$1
    local pod=$2

    section "Liveness/Readiness Probes"

    kubectl get pod "$pod" -n "$namespace" -o json | jq '.spec.containers[] | {name: .name, livenessProbe: .livenessProbe, readinessProbe: .readinessProbe, startupProbe: .startupProbe}'
}

# Execute commands in pod
exec_into_pod() {
    local namespace=$1
    local pod=$2
    local container=${3:-""}

    section "Exec into Pod"

    if [ -n "$container" ]; then
        log "Opening shell in container: $container"
        kubectl exec -it "$pod" -n "$namespace" -c "$container" -- /bin/sh
    else
        log "Opening shell in default container"
        kubectl exec -it "$pod" -n "$namespace" -- /bin/sh
    fi
}

# Full diagnostic report
full_diagnostic() {
    local namespace=$1
    local pod=$2

    log "Running full diagnostic for pod $pod in namespace $namespace"

    check_pod "$namespace" "$pod"

    show_pod_details "$namespace" "$pod"
    show_container_status "$namespace" "$pod"
    show_resource_usage "$namespace" "$pod"
    show_network_info "$namespace" "$pod"
    show_security_context "$namespace" "$pod"
    show_volumes "$namespace" "$pod"
    show_probes "$namespace" "$pod"
    show_logs "$namespace" "$pod" 100

    section "Diagnostic Complete"
    log "Review output above for issues"
}

# Show help
show_help() {
    cat <<EOF
Usage: $0 <command> <namespace> <pod> [options]

Commands:
  full <namespace> <pod>
      Run full diagnostic report

  details <namespace> <pod>
      Show pod details and events

  containers <namespace> <pod>
      Show container statuses

  resources <namespace> <pod>
      Show resource usage

  network <namespace> <pod>
      Show network information

  logs <namespace> <pod> [lines]
      Show recent logs (default: 50 lines)

  security <namespace> <pod>
      Show security context

  volumes <namespace> <pod>
      Show volumes and mounts

  probes <namespace> <pod>
      Show liveness/readiness probes

  exec <namespace> <pod> [container]
      Open shell in pod

Examples:
  $0 full demo demo-app-xxx-yyy
  $0 logs demo demo-app-xxx-yyy 100
  $0 exec demo demo-app-xxx-yyy istio-proxy

EOF
}

# Main
if [ $# -lt 1 ]; then
    show_help
    exit 0
fi

command=$1
shift

case $command in
    full)
        full_diagnostic "$@"
        ;;
    details)
        check_pod "$@"
        show_pod_details "$@"
        ;;
    containers)
        check_pod "$@"
        show_container_status "$@"
        ;;
    resources)
        check_pod "$@"
        show_resource_usage "$@"
        ;;
    network)
        check_pod "$@"
        show_network_info "$@"
        ;;
    logs)
        check_pod "$1" "$2"
        show_logs "$@"
        ;;
    security)
        check_pod "$@"
        show_security_context "$@"
        ;;
    volumes)
        check_pod "$@"
        show_volumes "$@"
        ;;
    probes)
        check_pod "$@"
        show_probes "$@"
        ;;
    exec)
        check_pod "$1" "$2"
        exec_into_pod "$@"
        ;;
    *)
        show_help
        exit 1
        ;;
esac
