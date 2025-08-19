#!/bin/bash

# LGTM Stack Deployment Script
# Usage: ./deploy.sh [environment] [action]
# Environments: dev, staging, uat, production
# Actions: install-vm, install-gke, upgrade, uninstall

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT=${1:-staging}
ACTION=${2:-install-gke}
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANSIBLE_DIR="${PROJECT_ROOT}/ansible"
KUSTOMIZE_DIR="${PROJECT_ROOT}/kustomize-manifests"

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    print_message "$YELLOW" "Checking prerequisites..."
    
    # Check required tools
    local required_tools=("kubectl" "gcloud" "ansible" "kustomize")
    for tool in "${required_tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            print_message "$RED" "Error: $tool is not installed"
            exit 1
        fi
    done
    
    print_message "$GREEN" "All prerequisites met!"
}

# Function to install LGTM stack on VM using Ansible (Native Installation)
install_vm() {
    print_message "$YELLOW" "Installing LGTM stack (Native) on VM for ${ENVIRONMENT}..."
    
    cd "${ANSIBLE_DIR}"
    
    # Check if ansible vault password file exists
    VAULT_PASS_FILE=".vault_pass"
    if [ -f "$VAULT_PASS_FILE" ]; then
        VAULT_OPT="--vault-password-file=$VAULT_PASS_FILE"
    else
        VAULT_OPT="--ask-vault-pass"
    fi
    
    # Run Ansible playbook for native installation
    ansible-playbook \
        -i inventory/${ENVIRONMENT}.yml \
        playbooks/install-lgtm.yml \
        --extra-vars "environment=${ENVIRONMENT}" \
        $VAULT_OPT
    
    if [ $? -eq 0 ]; then
        print_message "$GREEN" "LGTM stack (Native) installed successfully on VM!"
        print_message "$GREEN" "========================================"
        print_message "$YELLOW" "Access Information:"
        print_message "$YELLOW" "  Grafana URL: https://stg-checkinplust-monitor.checkinplus.com"
        print_message "$YELLOW" "  "
        print_message "$YELLOW" "Service Status:"
        print_message "$YELLOW" "  - Prometheus: http://localhost:9090"
        print_message "$YELLOW" "  - Loki: http://localhost:3100"
        print_message "$YELLOW" "  - Tempo: http://localhost:3200"
        print_message "$YELLOW" "  - Mimir: http://localhost:9009"
        print_message "$YELLOW" "  - Grafana: http://localhost:3000 (proxied via Nginx)"
        print_message "$GREEN" "========================================"
    else
        print_message "$RED" "Installation failed! Check the logs above for errors."
        exit 1
    fi
}

# Function to install LGTM stack on GKE
install_gke() {
    print_message "$YELLOW" "Installing LGTM stack on GKE for ${ENVIRONMENT}..."
    
    # Get GKE credentials based on environment
    case $ENVIRONMENT in
        dev)
            CLUSTER_NAME="checkinplus-dev"
            REGION="asia-southeast1"
            PROJECT="checkinplus-dev"
            ;;
        staging)
            CLUSTER_NAME="checkinplus-staging"
            REGION="asia-southeast1"
            PROJECT="checkinplus-staging"
            ;;
        uat)
            CLUSTER_NAME="checkinplus-uat"
            REGION="asia-southeast1"
            PROJECT="checkinplus-uat"
            ;;
        production)
            CLUSTER_NAME="checkinplus-prod"
            REGION="asia-southeast1"
            PROJECT="checkinplus-prod"
            ;;
        *)
            print_message "$RED" "Unknown environment: ${ENVIRONMENT}"
            exit 1
            ;;
    esac
    
    # Get GKE credentials
    print_message "$YELLOW" "Getting GKE cluster credentials..."
    gcloud container clusters get-credentials ${CLUSTER_NAME} \
        --region ${REGION} \
        --project ${PROJECT}
    
    # Create namespace if it doesn't exist
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply Kustomize manifests
    print_message "$YELLOW" "Applying Kustomize manifests..."
    cd "${KUSTOMIZE_DIR}"
    
    # Build and apply the manifests
    kustomize build overlays/${ENVIRONMENT} | kubectl apply -f -
    
    # Wait for deployments to be ready
    print_message "$YELLOW" "Waiting for deployments to be ready..."
    kubectl -n monitoring wait --for=condition=available --timeout=600s \
        deployment/grafana \
        deployment/prometheus
    
    kubectl -n monitoring wait --for=condition=ready --timeout=600s \
        statefulset/loki \
        statefulset/tempo \
        statefulset/mimir
    
    print_message "$GREEN" "LGTM stack installed successfully on GKE!"
    
    # Get Grafana URL
    GRAFANA_URL=$(kubectl -n monitoring get ingress grafana-ingress -o jsonpath='{.spec.rules[0].host}')
    print_message "$YELLOW" "Access Grafana at: https://${GRAFANA_URL}"
    
    # Get admin password
    ADMIN_PASSWORD=$(kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.password}' | base64 -d)
    print_message "$YELLOW" "Admin username: admin"
    print_message "$YELLOW" "Admin password: ${ADMIN_PASSWORD}"
}

# Function to upgrade LGTM stack
upgrade() {
    print_message "$YELLOW" "Upgrading LGTM stack for ${ENVIRONMENT}..."
    
    cd "${KUSTOMIZE_DIR}"
    kustomize build overlays/${ENVIRONMENT} | kubectl apply -f -
    
    # Restart deployments to pick up new configs
    kubectl -n monitoring rollout restart deployment/grafana
    kubectl -n monitoring rollout restart deployment/prometheus
    kubectl -n monitoring rollout restart statefulset/loki
    kubectl -n monitoring rollout restart statefulset/tempo
    kubectl -n monitoring rollout restart statefulset/mimir
    
    print_message "$GREEN" "LGTM stack upgraded successfully!"
}

# Function to uninstall LGTM stack
uninstall() {
    print_message "$YELLOW" "Uninstalling LGTM stack for ${ENVIRONMENT}..."
    
    read -p "Are you sure you want to uninstall? This will delete all data! (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_message "$YELLOW" "Uninstall cancelled"
        exit 0
    fi
    
    cd "${KUSTOMIZE_DIR}"
    kustomize build overlays/${ENVIRONMENT} | kubectl delete -f -
    
    print_message "$GREEN" "LGTM stack uninstalled successfully!"
}

# Main execution
main() {
    print_message "$GREEN" "==================================="
    print_message "$GREEN" "LGTM Stack Deployment Tool"
    print_message "$GREEN" "Environment: ${ENVIRONMENT}"
    print_message "$GREEN" "Action: ${ACTION}"
    print_message "$GREEN" "==================================="
    
    check_prerequisites
    
    case $ACTION in
        install-vm)
            install_vm
            ;;
        install-gke)
            install_gke
            ;;
        upgrade)
            upgrade
            ;;
        uninstall)
            uninstall
            ;;
        *)
            print_message "$RED" "Unknown action: ${ACTION}"
            print_message "$YELLOW" "Valid actions: install-vm, install-gke, upgrade, uninstall"
            exit 1
            ;;
    esac
}

# Run main function
main
