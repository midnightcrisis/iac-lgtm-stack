#!/bin/bash

# LGTM Stack Validation Script
# This script validates the health of all LGTM components

set -e

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}==================================="
echo -e "LGTM Stack Health Check"
echo -e "===================================${NC}"

# Check if running in Kubernetes context
if kubectl cluster-info &> /dev/null; then
    echo -e "${GREEN}✓ Kubernetes cluster accessible${NC}"
    
    # Check namespace
    if kubectl get namespace monitoring &> /dev/null; then
        echo -e "${GREEN}✓ Monitoring namespace exists${NC}"
        
        # Check deployments
        echo -e "\n${YELLOW}Checking Deployments:${NC}"
        kubectl -n monitoring get deployments
        
        # Check StatefulSets
        echo -e "\n${YELLOW}Checking StatefulSets:${NC}"
        kubectl -n monitoring get statefulsets
        
        # Check pods
        echo -e "\n${YELLOW}Checking Pods:${NC}"
        kubectl -n monitoring get pods
        
        # Check services
        echo -e "\n${YELLOW}Checking Services:${NC}"
        kubectl -n monitoring get services
        
        # Check PVCs
        echo -e "\n${YELLOW}Checking Persistent Volumes:${NC}"
        kubectl -n monitoring get pvc
        
        # Check Ingress
        echo -e "\n${YELLOW}Checking Ingress:${NC}"
        kubectl -n monitoring get ingress
        
        # Test service endpoints
        echo -e "\n${YELLOW}Testing Service Endpoints:${NC}"
        
        # Port-forward and test each service
        services=("grafana:3000:/api/health" "prometheus:9090/-/healthy" "loki:3100/ready" "tempo:3200/ready")
        
        for service_info in "${services[@]}"; do
            IFS=':' read -r service port path <<< "$service_info"
            
            # Check if service exists
            if kubectl -n monitoring get service $service &> /dev/null; then
                echo -e "${GREEN}✓ $service service exists${NC}"
                
                # You can add port-forward tests here if needed
                # kubectl -n monitoring port-forward svc/$service $port:$port &
                # sleep 2
                # curl -s http://localhost:$port$path && echo -e "${GREEN}✓ $service is healthy${NC}" || echo -e "${RED}✗ $service is not responding${NC}"
                # kill %1
            else
                echo -e "${RED}✗ $service service not found${NC}"
            fi
        done
        
    else
        echo -e "${RED}✗ Monitoring namespace not found${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Cannot connect to Kubernetes cluster${NC}"
    echo -e "${YELLOW}Make sure kubectl is configured correctly${NC}"
    exit 1
fi

echo -e "\n${GREEN}==================================="
echo -e "Validation Complete"
echo -e "===================================${NC}"
