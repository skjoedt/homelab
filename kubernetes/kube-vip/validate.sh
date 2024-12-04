#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BLUE='\033[0;34m'

# Configuration
VIP="10.0.0.10"
API_PORT="6443"
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

# 2. Verify VIP network accessibility
echo -e "\nChecking control plane VIP network accessibility..."
ping -c 1 $VIP > /dev/null 2>&1
check_status "VIP $VIP responds to ping" "critical"

# 3. Test TCP connectivity to API server port
echo -e "\nChecking API server port accessibility..."
if nc -zv $VIP $API_PORT 2>&1 | grep -q "succeeded"; then
    echo -e "${GREEN}✓ API server port $API_PORT is open${NC}"
else
    echo -e "${RED}✗ Cannot connect to API server port $API_PORT${NC}"
    exit 1
fi

# 4. Verify API server functionality
echo -e "\nVerifying API server health..."

# Create a temporary kubeconfig pointing to the VIP
TMP_KUBECONFIG=$(mktemp)
trap "rm -f $TMP_KUBECONFIG" EXIT

# Get the current context's CA certificate and credentials
KUBECONFIG="$HOME/.kube/config" kubectl config view --raw > "$TMP_KUBECONFIG"

# Update the server address in the temporary kubeconfig
sed -i "s|server: https://[^:]*:6443|server: https://${VIP}:${API_PORT}|" "$TMP_KUBECONFIG"

# Test API server connectivity using the VIP
if KUBECONFIG="$TMP_KUBECONFIG" kubectl get --raw '/readyz' &>/dev/null; then
    echo -e "${GREEN}✓ API server is healthy and accessible through VIP${NC}"
else
    echo -e "${RED}✗ API server health check failed through VIP${NC}"
    exit 1
fi

echo -e "\n${GREEN}✓ Control plane high availability validation completed successfully!${NC}"
