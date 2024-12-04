#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BLUE='\033[0;34m'

# Configuration
NAMESPACE="metallb-system"
TEST_NAME="lb-test"
MIN_IP="10.0.0.50"
MAX_IP="10.0.0.99"

echo -e "${BLUE}🔍 Starting MetalLB validation...${NC}\n"

# Function to check command status
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
    else
        echo -e "${RED}✗ $1${NC}"
        if [ "$2" = "critical" ]; then
            exit 1
        fi
    fi
}

# Function to validate IP is in range
validate_ip() {
    local IP=$1
    local MIN=$2
    local MAX=$3
    
    IFS='.' read -r -a IP_PARTS <<< "$IP"
    IFS='.' read -r -a MIN_PARTS <<< "$MIN"
    IFS='.' read -r -a MAX_PARTS <<< "$MAX"
    
    local IP_LAST=${IP_PARTS[3]}
    local MIN_LAST=${MIN_PARTS[3]}
    local MAX_LAST=${MAX_PARTS[3]}
    
    if [ $IP_LAST -ge $MIN_LAST ] && [ $IP_LAST -le $MAX_LAST ]; then
        return 0
    else
        return 1
    fi
}

# 1. Check if MetalLB pods are running
echo "Checking MetalLB pod status..."
for component in controller speaker; do
    PODS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=$component -o name)
    if [ -z "$PODS" ]; then
        echo -e "${RED}✗ No MetalLB $component pods found${NC}"
        exit 1
    fi
    
    for pod in $PODS; do
        STATUS=$(kubectl get $pod -n $NAMESPACE -o jsonpath='{.status.phase}')
        if [ "$STATUS" = "Running" ]; then
            echo -e "${GREEN}✓ $pod is running${NC}"
        else
            echo -e "${RED}✗ $pod status: $STATUS${NC}"
            exit 1
        fi
    done
done

# 2. Test LoadBalancer service creation
echo -e "\nTesting LoadBalancer service creation..."

# Create test deployment and service
kubectl create deployment $TEST_NAME --image=nginx:alpine --port=80 > /dev/null 2>&1
check_status "Created test deployment"

kubectl expose deployment $TEST_NAME --type=LoadBalancer --port=80 > /dev/null 2>&1
check_status "Exposed service as LoadBalancer"

# Wait for LoadBalancer IP
echo "Waiting for LoadBalancer IP (timeout: 30s)..."
for i in {1..6}; do
    LB_IP=$(kubectl get svc $TEST_NAME -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ ! -z "$LB_IP" ]; then
        echo -e "${GREEN}✓ LoadBalancer IP assigned: $LB_IP${NC}"
        break
    fi
    if [ $i -eq 6 ]; then
        echo -e "${RED}✗ Timeout waiting for LoadBalancer IP${NC}"
        exit 1
    fi
    sleep 5
done

# Validate IP is in range
validate_ip "$LB_IP" "$MIN_IP" "$MAX_IP"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ LoadBalancer IP ($LB_IP) is within configured range${NC}"
else
    echo -e "${RED}✗ LoadBalancer IP ($LB_IP) is outside configured range${NC}"
    exit 1
fi

# Test connectivity
echo -e "\nTesting connectivity to service..."
for i in {1..5}; do
    if curl -s --connect-timeout 2 http://$LB_IP > /dev/null; then
        echo -e "${GREEN}✓ Service is responding${NC}"
        break
    fi
    if [ $i -eq 5 ]; then
        echo -e "${RED}✗ Service is not responding${NC}"
        exit 1
    fi
    sleep 2
done

# Clean up test resources
echo -e "\nCleaning up test resources..."
kubectl delete service $TEST_NAME > /dev/null 2>&1
kubectl delete deployment $TEST_NAME > /dev/null 2>&1
check_status "Cleaned up test resources"

echo -e "\n${GREEN}✓ MetalLB validation completed successfully!${NC}"
