#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BLUE='\033[0;34m'

# Configuration
VIP="10.0.0.10"
LB_TEST_NAME="vip-test"
NAMESPACE="kube-system"

echo -e "${BLUE}🔍 Starting kube-vip validation...${NC}\n"

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

# 1. Check if kube-vip pods are running
echo "Checking kube-vip pod status..."
KUBE_VIP_PODS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=kube-vip -o name)
if [ -z "$KUBE_VIP_PODS" ]; then
    echo -e "${RED}✗ No kube-vip pods found${NC}"
    exit 1
fi

for pod in $KUBE_VIP_PODS; do
    STATUS=$(kubectl get $pod -n $NAMESPACE -o jsonpath='{.status.phase}')
    if [ "$STATUS" = "Running" ]; then
        echo -e "${GREEN}✓ $pod is running${NC}"
    else
        echo -e "${RED}✗ $pod status: $STATUS${NC}"
        exit 1
    fi
done

# 2. Verify VIP is responding
echo -e "\nChecking VIP accessibility..."
ping -c 1 $VIP > /dev/null 2>&1
check_status "VIP $VIP is responding" "critical"

# 3. Test LoadBalancer service creation
echo -e "\nTesting LoadBalancer service creation..."

# Create test deployment and service
kubectl create deployment $LB_TEST_NAME --image=nginx:alpine --port=80 > /dev/null 2>&1
check_status "Created test deployment"

kubectl expose deployment $LB_TEST_NAME --type=LoadBalancer --port=80 > /dev/null 2>&1
check_status "Exposed service as LoadBalancer"

# Wait for LoadBalancer IP
echo "Waiting for LoadBalancer IP (timeout: 30s)..."
for i in {1..6}; do
    LB_IP=$(kubectl get svc $LB_TEST_NAME -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
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

# Verify IP is in the configured range
IFS='.' read -r -a IP_PARTS <<< "$LB_IP"
LAST_OCTET=${IP_PARTS[3]}
if [ $LAST_OCTET -ge 50 ] && [ $LAST_OCTET -le 100 ]; then
    echo -e "${GREEN}✓ LoadBalancer IP ($LB_IP) is within configured range${NC}"
else
    echo -e "${RED}✗ LoadBalancer IP ($LB_IP) is outside configured range${NC}"
fi

# Clean up test resources
echo -e "\nCleaning up test resources..."
kubectl delete service $LB_TEST_NAME > /dev/null 2>&1
kubectl delete deployment $LB_TEST_NAME > /dev/null 2>&1
check_status "Cleaned up test resources"

echo -e "\n${GREEN}✓ Validation completed successfully!${NC}"
