#!/bin/bash

# Semaphore Deployment Script
# Usage: ./deploy-semaphore.sh [environment]
# Environments: dev, staging, production

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
ENVIRONMENT=${1:-staging}
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANSIBLE_DIR="${PROJECT_ROOT}/ansible"

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    print_message "$YELLOW" "Checking prerequisites..."
    
    # Check for Ansible
    if ! command -v ansible &> /dev/null; then
        print_message "$RED" "Error: Ansible is not installed"
        exit 1
    fi
    
    # Check for inventory file
    if [ ! -f "${ANSIBLE_DIR}/inventory/semaphore-${ENVIRONMENT}.yml" ]; then
        print_message "$RED" "Error: Inventory file not found for environment: ${ENVIRONMENT}"
        print_message "$YELLOW" "Available environments: dev, staging, production"
        exit 1
    fi
    
    print_message "$GREEN" "Prerequisites check passed!"
}

# Function to create vault file if needed
setup_vault() {
    print_message "$YELLOW" "Setting up Ansible vault..."
    
    VAULT_FILE="${ANSIBLE_DIR}/group_vars/all/vault-semaphore.yml"
    
    if [ ! -f "$VAULT_FILE" ]; then
        print_message "$YELLOW" "Creating vault file template..."
        cat > "${VAULT_FILE}.template" <<EOF
---
# Semaphore Vault Variables
# Encrypt this file with: ansible-vault encrypt vault-semaphore.yml

# Database passwords
vault_semaphore_db_password: "changeme_db_password"
vault_postgres_admin_password: "changeme_postgres_password"

# Semaphore admin password
vault_semaphore_admin_password: "changeme_admin_password"

# Email configuration (optional)
vault_email_username: ""
vault_email_password: ""

# Slack webhook (optional)
vault_slack_webhook_url: ""

# Telegram bot (optional)
vault_telegram_chat_id: ""
vault_telegram_bot_token: ""

# LDAP bind password (optional)
vault_ldap_bind_password: ""

# Runner registration token (optional)
vault_runner_registration_token: ""
EOF
        print_message "$GREEN" "Vault template created at: ${VAULT_FILE}.template"
        print_message "$YELLOW" "Please edit the template and encrypt it with:"
        print_message "$BLUE" "  ansible-vault encrypt ${VAULT_FILE}.template --output ${VAULT_FILE}"
    else
        print_message "$GREEN" "Vault file already exists"
    fi
}

# Function to deploy Semaphore
deploy_semaphore() {
    print_message "$BLUE" "===================================="
    print_message "$BLUE" "Deploying Semaphore - ${ENVIRONMENT}"
    print_message "$BLUE" "===================================="
    
    cd "${ANSIBLE_DIR}"
    
    # Check if vault password file exists
    VAULT_PASS_FILE=".vault_pass_semaphore"
    if [ -f "$VAULT_PASS_FILE" ]; then
        VAULT_OPT="--vault-password-file=$VAULT_PASS_FILE"
    else
        VAULT_OPT="--ask-vault-pass"
        print_message "$YELLOW" "Tip: Create ${VAULT_PASS_FILE} with your vault password to avoid prompts"
    fi
    
    # Run the playbook
    print_message "$YELLOW" "Running Ansible playbook..."
    ansible-playbook \
        -i "inventory/semaphore-${ENVIRONMENT}.yml" \
        playbooks/install-semaphore.yml \
        --extra-vars "environment=${ENVIRONMENT}" \
        $VAULT_OPT \
        "$@"  # Pass any additional arguments
    
    if [ $? -eq 0 ]; then
        print_message "$GREEN" "===================================="
        print_message "$GREEN" "Semaphore deployed successfully!"
        print_message "$GREEN" "===================================="
        
        # Get connection info from inventory
        case $ENVIRONMENT in
            dev)
                URL="http://dev-semaphore.example.com:3001"
                ;;
            staging)
                URL="https://stg-semaphore.checkinplus.com"
                ;;
            production)
                URL="https://semaphore.example.com"
                ;;
            *)
                URL="http://localhost:3001"
                ;;
        esac
        
        print_message "$YELLOW" "Access Semaphore at: ${URL}"
        print_message "$YELLOW" "Default username: admin"
        print_message "$YELLOW" "Password: Check your vault file"
    else
        print_message "$RED" "Deployment failed! Check the errors above."
        exit 1
    fi
}

# Function to check Semaphore status
check_status() {
    print_message "$BLUE" "Checking Semaphore status..."
    
    cd "${ANSIBLE_DIR}"
    
    ansible all \
        -i "inventory/semaphore-${ENVIRONMENT}.yml" \
        -m systemd \
        -a "name=semaphore" \
        --become
    
    ansible all \
        -i "inventory/semaphore-${ENVIRONMENT}.yml" \
        -m uri \
        -a "url=http://localhost:3001/api/ping" \
        --become
}

# Function to show logs
show_logs() {
    print_message "$BLUE" "Showing Semaphore logs..."
    
    cd "${ANSIBLE_DIR}"
    
    ansible all \
        -i "inventory/semaphore-${ENVIRONMENT}.yml" \
        -m shell \
        -a "journalctl -u semaphore -n 50 --no-pager" \
        --become
}

# Main execution
main() {
    case "${2:-deploy}" in
        deploy)
            check_prerequisites
            setup_vault
            deploy_semaphore "${@:3}"
            ;;
        status)
            check_status
            ;;
        logs)
            show_logs
            ;;
        vault)
            setup_vault
            ;;
        *)
            print_message "$RED" "Unknown action: ${2}"
            print_message "$YELLOW" "Usage: $0 [environment] [action]"
            print_message "$YELLOW" "Environments: dev, staging, production"
            print_message "$YELLOW" "Actions: deploy, status, logs, vault"
            exit 1
            ;;
    esac
}

# Show help if no arguments
if [ "$#" -eq 0 ]; then
    print_message "$BLUE" "Semaphore Deployment Script"
    print_message "$YELLOW" "Usage: $0 [environment] [action] [ansible-options]"
    print_message "$YELLOW" ""
    print_message "$YELLOW" "Environments:"
    print_message "$YELLOW" "  dev         - Development environment"
    print_message "$YELLOW" "  staging     - Staging environment"
    print_message "$YELLOW" "  production  - Production environment"
    print_message "$YELLOW" ""
    print_message "$YELLOW" "Actions:"
    print_message "$YELLOW" "  deploy      - Deploy Semaphore (default)"
    print_message "$YELLOW" "  status      - Check Semaphore service status"
    print_message "$YELLOW" "  logs        - Show Semaphore logs"
    print_message "$YELLOW" "  vault       - Setup vault file"
    print_message "$YELLOW" ""
    print_message "$YELLOW" "Examples:"
    print_message "$BLUE" "  $0 staging deploy              # Deploy to staging"
    print_message "$BLUE" "  $0 production status           # Check production status"
    print_message "$BLUE" "  $0 dev deploy --check          # Dry run for dev"
    print_message "$BLUE" "  $0 staging deploy --tags nginx # Only run nginx tasks"
    exit 0
fi

# Run main function
main "$@"
