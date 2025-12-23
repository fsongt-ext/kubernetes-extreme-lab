#!/usr/bin/env bash
# Aggregate logs from multiple pods for debugging

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Function to stream logs from all pods matching a label
stream_logs() {
    local namespace=$1
    local label=$2
    local follow=${3:-false}

    log "Streaming logs from namespace=$namespace, label=$label"

    # Get all pods matching the label
    local pods=$(kubectl get pods -n "$namespace" -l "$label" -o jsonpath='{.items[*].metadata.name}')

    if [ -z "$pods" ]; then
        warn "No pods found with label $label in namespace $namespace"
        return 1
    fi

    log "Found pods: $pods"

    # Stream logs from each pod
    for pod in $pods; do
        log "--- Logs from $pod ---"

        if [ "$follow" = "true" ]; then
            kubectl logs -f "$pod" -n "$namespace" --all-containers=true &
        else
            kubectl logs "$pod" -n "$namespace" --all-containers=true --tail=100
        fi
    done

    if [ "$follow" = "true" ]; then
        wait
    fi
}

# Function to get logs from specific container
container_logs() {
    local namespace=$1
    local pod=$2
    local container=$3
    local tail=${4:-100}

    kubectl logs "$pod" -n "$namespace" -c "$container" --tail="$tail"
}

# Function to show previous logs (after crash)
previous_logs() {
    local namespace=$1
    local pod=$2
    local container=${3:-""}

    if [ -n "$container" ]; then
        kubectl logs "$pod" -n "$namespace" -c "$container" --previous
    else
        kubectl logs "$pod" -n "$namespace" --previous --all-containers=true
    fi
}

# Function to show logs since timestamp
logs_since() {
    local namespace=$1
    local label=$2
    local since=$3  # e.g., "1h", "30m", "2023-12-23T10:00:00Z"

    local pods=$(kubectl get pods -n "$namespace" -l "$label" -o jsonpath='{.items[*].metadata.name}')

    for pod in $pods; do
        log "--- Logs from $pod (since $since) ---"
        kubectl logs "$pod" -n "$namespace" --since="$since" --all-containers=true
    done
}

# Function to save logs to file
save_logs() {
    local namespace=$1
    local label=$2
    local output_dir=${3:-"./logs"}

    mkdir -p "$output_dir"

    local pods=$(kubectl get pods -n "$namespace" -l "$label" -o jsonpath='{.items[*].metadata.name}')

    for pod in $pods; do
        local log_file="$output_dir/${namespace}-${pod}.log"
        log "Saving logs from $pod to $log_file"
        kubectl logs "$pod" -n "$namespace" --all-containers=true > "$log_file"
    done

    log "Logs saved to $output_dir"
}

# Function to grep logs
grep_logs() {
    local namespace=$1
    local label=$2
    local pattern=$3

    local pods=$(kubectl get pods -n "$namespace" -l "$label" -o jsonpath='{.items[*].metadata.name}')

    for pod in $pods; do
        log "--- Searching $pod for '$pattern' ---"
        kubectl logs "$pod" -n "$namespace" --all-containers=true | grep --color=always "$pattern" || true
    done
}

# Show help
show_help() {
    cat <<EOF
Usage: $0 <command> [options]

Commands:
  stream <namespace> <label> [follow]
      Stream logs from all pods matching label
      Example: $0 stream demo app=demo-app true

  container <namespace> <pod> <container> [tail]
      Get logs from specific container
      Example: $0 container demo demo-app-xxx-yyy istio-proxy 50

  previous <namespace> <pod> [container]
      Show previous logs (after crash)
      Example: $0 previous demo demo-app-xxx-yyy

  since <namespace> <label> <duration>
      Show logs since duration (1h, 30m, etc.)
      Example: $0 since demo app=demo-app 1h

  save <namespace> <label> [output_dir]
      Save logs to files
      Example: $0 save demo app=demo-app ./logs

  grep <namespace> <label> <pattern>
      Search logs for pattern
      Example: $0 grep demo app=demo-app "ERROR"

  quick
      Quick access to common logs (interactive)

EOF
}

# Quick access menu
quick_logs() {
    echo ""
    echo "=== Quick Log Access ==="
    echo ""
    echo "  1) ArgoCD Controller"
    echo "  2) ArgoCD Server"
    echo "  3) Demo App"
    echo "  4) Istio Pilot (istiod)"
    echo "  5) Kyverno"
    echo "  6) Grafana"
    echo ""
    read -rp "Select option: " choice

    case $choice in
        1)
            stream_logs "argocd" "app.kubernetes.io/name=argocd-application-controller" false
            ;;
        2)
            stream_logs "argocd" "app.kubernetes.io/name=argocd-server" false
            ;;
        3)
            stream_logs "demo" "app=demo-app" false
            ;;
        4)
            stream_logs "istio-system" "app=istiod" false
            ;;
        5)
            stream_logs "kyverno" "app.kubernetes.io/name=kyverno" false
            ;;
        6)
            stream_logs "observability" "app.kubernetes.io/name=grafana" false
            ;;
        *)
            warn "Invalid option"
            ;;
    esac
}

# Main
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

command=$1
shift

case $command in
    stream)
        stream_logs "$@"
        ;;
    container)
        container_logs "$@"
        ;;
    previous)
        previous_logs "$@"
        ;;
    since)
        logs_since "$@"
        ;;
    save)
        save_logs "$@"
        ;;
    grep)
        grep_logs "$@"
        ;;
    quick)
        quick_logs
        ;;
    *)
        show_help
        exit 1
        ;;
esac
