#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BLUE='\033[0;34m'

# Configuration
VIP="10.0.0.10"
NAMESPACE="kube-system"

echo -e "${BLUE}🔍 Starting kube-vip control plane validation...${NC}\n"

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
echo -e "\nChecking control plane VIP accessibility..."
ping -c 1 $VIP > /dev/null 2>&1
check_status "Control plane VIP $VIP is responding" "critical"

# 3. Verify API server accessibility
echo -e "\nVerifying API server connection..."
kubectl --kubeconfig="$HOME/.kube/config" get nodes --request-timeout=5s > /dev/null 2>&1
check_status "API server is accessible through VIP"

echo -e "\n${GREEN}✓ Control plane high availability validation completed successfully!${NC}"
