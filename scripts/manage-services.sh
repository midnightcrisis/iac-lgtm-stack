#!/bin/bash

# LGTM Native Services Management Script
# Usage: ./manage-services.sh [action] [service]
# Actions: start, stop, restart, status, logs
# Services: all, prometheus, loki, tempo, mimir, grafana, nginx

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Services list
SERVICES=("prometheus" "loki" "tempo" "mimir" "grafana-server" "nginx")
SERVICE_NAMES=("Prometheus" "Loki" "Tempo" "Mimir" "Grafana" "Nginx")

# Arguments
ACTION=${1:-status}
SERVICE=${2:-all}

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to manage a single service
manage_service() {
    local service=$1
    local action=$2
    local display_name=$3
    
    case $action in
        start)
            print_message "$YELLOW" "Starting ${display_name}..."
            sudo systemctl start $service
            print_message "$GREEN" "${display_name} started successfully"
            ;;
        stop)
            print_message "$YELLOW" "Stopping ${display_name}..."
            sudo systemctl stop $service
            print_message "$GREEN" "${display_name} stopped successfully"
            ;;
        restart)
            print_message "$YELLOW" "Restarting ${display_name}..."
            sudo systemctl restart $service
            print_message "$GREEN" "${display_name} restarted successfully"
            ;;
        status)
            print_message "$BLUE" "\n=== ${display_name} Status ==="
            sudo systemctl status $service --no-pager -n 5
            ;;
        logs)
            print_message "$BLUE" "\n=== ${display_name} Logs (last 50 lines) ==="
            sudo journalctl -u $service -n 50 --no-pager
            ;;
        enable)
            print_message "$YELLOW" "Enabling ${display_name} at boot..."
            sudo systemctl enable $service
            print_message "$GREEN" "${display_name} enabled at boot"
            ;;
        disable)
            print_message "$YELLOW" "Disabling ${display_name} at boot..."
            sudo systemctl disable $service
            print_message "$GREEN" "${display_name} disabled at boot"
            ;;
        *)
            print_message "$RED" "Unknown action: $action"
            exit 1
            ;;
    esac
}

# Function to check service health
check_health() {
    print_message "$BLUE" "\n=== LGTM Stack Health Check ==="
    print_message "$YELLOW" "Checking service endpoints..."
    
    # Check Prometheus
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/-/ready | grep -q "200"; then
        print_message "$GREEN" "✓ Prometheus is healthy (port 9090)"
    else
        print_message "$RED" "✗ Prometheus is not responding"
    fi
    
    # Check Loki
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:3100/ready | grep -q "200"; then
        print_message "$GREEN" "✓ Loki is healthy (port 3100)"
    else
        print_message "$RED" "✗ Loki is not responding"
    fi
    
    # Check Tempo
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:3200/ready | grep -q "200"; then
        print_message "$GREEN" "✓ Tempo is healthy (port 3200)"
    else
        print_message "$RED" "✗ Tempo is not responding"
    fi
    
    # Check Mimir
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:9009/ready | grep -q "200"; then
        print_message "$GREEN" "✓ Mimir is healthy (port 9009)"
    else
        print_message "$RED" "✗ Mimir is not responding"
    fi
    
    # Check Grafana
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health | grep -q "200"; then
        print_message "$GREEN" "✓ Grafana is healthy (port 3000)"
    else
        print_message "$RED" "✗ Grafana is not responding"
    fi
    
    # Check Nginx
    if curl -s -o /dev/null -w "%{http_code}" http://localhost/health | grep -q "200"; then
        print_message "$GREEN" "✓ Nginx proxy is healthy (port 80/443)"
    else
        print_message "$RED" "✗ Nginx is not responding"
    fi
}

# Function to show service ports
show_ports() {
    print_message "$BLUE" "\n=== Service Ports ==="
    print_message "$YELLOW" "Prometheus: 9090"
    print_message "$YELLOW" "Loki: 3100"
    print_message "$YELLOW" "Tempo: 3200 (HTTP), 4317 (OTLP gRPC), 4318 (OTLP HTTP), 14268 (Jaeger), 9411 (Zipkin)"
    print_message "$YELLOW" "Mimir: 9009"
    print_message "$YELLOW" "Grafana: 3000"
    print_message "$YELLOW" "Nginx: 80 (HTTP), 443 (HTTPS)"
}

# Main execution
main() {
    print_message "$GREEN" "==================================="
    print_message "$GREEN" "LGTM Native Services Manager"
    print_message "$GREEN" "==================================="
    
    # Handle special actions
    if [ "$ACTION" == "health" ]; then
        check_health
        exit 0
    fi
    
    if [ "$ACTION" == "ports" ]; then
        show_ports
        exit 0
    fi
    
    # Validate action
    case $ACTION in
        start|stop|restart|status|logs|enable|disable)
            ;;
        *)
            print_message "$RED" "Invalid action: $ACTION"
            print_message "$YELLOW" "Valid actions: start, stop, restart, status, logs, enable, disable, health, ports"
            exit 1
            ;;
    esac
    
    # Handle service selection
    if [ "$SERVICE" == "all" ]; then
        for i in "${!SERVICES[@]}"; do
            manage_service "${SERVICES[$i]}" "$ACTION" "${SERVICE_NAMES[$i]}"
        done
    else
        # Map service name to actual systemd service
        case $SERVICE in
            prometheus)
                manage_service "prometheus" "$ACTION" "Prometheus"
                ;;
            loki)
                manage_service "loki" "$ACTION" "Loki"
                ;;
            tempo)
                manage_service "tempo" "$ACTION" "Tempo"
                ;;
            mimir)
                manage_service "mimir" "$ACTION" "Mimir"
                ;;
            grafana)
                manage_service "grafana-server" "$ACTION" "Grafana"
                ;;
            nginx)
                manage_service "nginx" "$ACTION" "Nginx"
                ;;
            *)
                print_message "$RED" "Unknown service: $SERVICE"
                print_message "$YELLOW" "Valid services: all, prometheus, loki, tempo, mimir, grafana, nginx"
                exit 1
                ;;
        esac
    fi
    
    print_message "$GREEN" "\nOperation completed successfully!"
}

# Show usage if no arguments
if [ "$#" -eq 0 ]; then
    print_message "$BLUE" "Usage: $0 [action] [service]"
    print_message "$YELLOW" "Actions: start, stop, restart, status, logs, enable, disable, health, ports"
    print_message "$YELLOW" "Services: all, prometheus, loki, tempo, mimir, grafana, nginx"
    print_message "$YELLOW" "\nExamples:"
    print_message "$YELLOW" "  $0 status all        # Check status of all services"
    print_message "$YELLOW" "  $0 restart grafana   # Restart Grafana service"
    print_message "$YELLOW" "  $0 logs prometheus   # View Prometheus logs"
    print_message "$YELLOW" "  $0 health           # Check health of all services"
    exit 0
fi

# Run main function
main
