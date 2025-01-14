#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BLUE='\033[0;34m'

# Configuration
NAMESPACE="external-secrets"
TEST_DOMAIN="validate.fanen.dk"

echo -e "${BLUE}Starting cert-manager validation...${NC}\n"

# Function to check command status
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
    else
        echo -e "${RED}✗ $1${NC}"
        exit 1
    fi
}


# Check dummy secret
echo -e "\nChecking Dummy secret..."
KEYS=$(kubectl get secret -n $NAMESPACE dummy-secret -o jsonpath='{.data.dummy_key}' 2>/dev/null)
if [ $? -eq 0 ] && [ ! -z "$KEYS" ]; then
    echo -e "${GREEN}✓ Dummy secret is retrieved from external store ${NC}"
else
    echo -e "${RED}✗ Dummy secret is not found${NC}"
    exit 1
fi