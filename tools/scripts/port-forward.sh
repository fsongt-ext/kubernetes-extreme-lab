#!/usr/bin/env bash
# Port-forward common services for local development

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if namespace exists
check_namespace() {
    local ns=$1
    if ! kubectl get namespace "$ns" &>/dev/null; then
        error "Namespace $ns does not exist"
        return 1
    fi
    return 0
}

# Function to check if service exists
check_service() {
    local ns=$1
    local svc=$2
    if ! kubectl get service "$svc" -n "$ns" &>/dev/null; then
        error "Service $svc not found in namespace $ns"
        return 1
    fi
    return 0
}

# Function to start port-forward in background
start_port_forward() {
    local ns=$1
    local svc=$2
    local local_port=$3
    local remote_port=$4
    local name=$5

    check_namespace "$ns" || return 1
    check_service "$ns" "$svc" || return 1

    log "Port-forwarding $name: localhost:$local_port -> $svc.$ns:$remote_port"

    kubectl port-forward "svc/$svc" "$local_port:$remote_port" -n "$ns" &> "/tmp/port-forward-$name.log" &
    local pid=$!

    echo "$pid" > "/tmp/port-forward-$name.pid"

    # Wait a moment to check if it started successfully
    sleep 2
    if ! kill -0 "$pid" 2>/dev/null; then
        error "Failed to start port-forward for $name"
        cat "/tmp/port-forward-$name.log"
        return 1
    fi

    log "Started $name (PID: $pid)"
}

# Function to stop all port-forwards
stop_all() {
    log "Stopping all port-forwards..."

    for pid_file in /tmp/port-forward-*.pid; do
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            local name=$(basename "$pid_file" .pid | sed 's/port-forward-//')

            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid"
                log "Stopped $name (PID: $pid)"
            fi

            rm "$pid_file"
        fi
    done

    # Cleanup log files
    rm -f /tmp/port-forward-*.log

    log "All port-forwards stopped"
}

# Function to show status
show_status() {
    log "Active port-forwards:"
    echo ""

    local found=0
    for pid_file in /tmp/port-forward-*.pid; do
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            local name=$(basename "$pid_file" .pid | sed 's/port-forward-//')

            if kill -0 "$pid" 2>/dev/null; then
                echo "  ✓ $name (PID: $pid)"
                found=1
            else
                warn "  ✗ $name (PID: $pid) - not running"
                rm "$pid_file"
            fi
        fi
    done

    if [ $found -eq 0 ]; then
        echo "  No active port-forwards"
    fi
}

# Main menu
show_menu() {
    echo ""
    echo "=== Port-Forward Manager ==="
    echo ""
    echo "Available services:"
    echo ""
    echo "  1) ArgoCD Server     - localhost:8080"
    echo "  2) Grafana           - localhost:3000"
    echo "  3) Prometheus        - localhost:9090"
    echo "  4) Demo App          - localhost:8081"
    echo "  5) Kyverno Dashboard - localhost:8082"
    echo "  6) ALL - Start all port-forwards"
    echo "  7) Status - Show active port-forwards"
    echo "  8) Stop all"
    echo "  9) Exit"
    echo ""
}

# Start specific service
start_service() {
    case $1 in
        1)
            start_port_forward "argocd" "argocd-server" "8080" "443" "argocd"
            ;;
        2)
            start_port_forward "observability" "grafana" "3000" "80" "grafana"
            ;;
        3)
            start_port_forward "observability" "prometheus" "9090" "9090" "prometheus"
            ;;
        4)
            start_port_forward "demo" "demo-app" "8081" "8080" "demo-app"
            ;;
        5)
            start_port_forward "kyverno" "kyverno-ui" "8082" "80" "kyverno"
            ;;
        6)
            log "Starting all port-forwards..."
            start_port_forward "argocd" "argocd-server" "8080" "443" "argocd"
            start_port_forward "observability" "grafana" "3000" "80" "grafana"
            start_port_forward "observability" "prometheus" "9090" "9090" "prometheus"
            start_port_forward "demo" "demo-app" "8081" "8080" "demo-app"
            ;;
        7)
            show_status
            ;;
        8)
            stop_all
            ;;
        9)
            log "Exiting..."
            exit 0
            ;;
        *)
            error "Invalid option"
            ;;
    esac
}

# Trap to cleanup on exit
trap stop_all EXIT INT TERM

# Main logic
if [ $# -eq 0 ]; then
    # Interactive mode
    while true; do
        show_menu
        read -rp "Select option: " choice
        start_service "$choice"
    done
else
    # CLI mode
    case $1 in
        start)
            shift
            if [ $# -eq 0 ]; then
                start_service 6  # Start all
            else
                start_service "$1"
            fi
            ;;
        stop)
            stop_all
            ;;
        status)
            show_status
            ;;
        *)
            echo "Usage: $0 {start [service]|stop|status}"
            echo ""
            echo "Services: 1-6 (or omit to start all)"
            exit 1
            ;;
    esac
fi
