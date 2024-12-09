#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BLUE='\033[0;34m'

# Configuration
NAMESPACE="cert-manager"
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

# Function to cleanup test resources
cleanup() {
    kubectl delete certificate -n $NAMESPACE validate-cert --ignore-not-found > /dev/null 2>&1
}
trap cleanup EXIT

# 1. Check cert-manager pods
echo "Checking cert-manager deployment status..."
for component in controller cainjector webhook; do
    READY=$(kubectl get deployment -n $NAMESPACE cert-manager${component:+-$component} -o jsonpath='{.status.readyReplicas}')
    DESIRED=$(kubectl get deployment -n $NAMESPACE cert-manager${component:+-$component} -o jsonpath='{.spec.replicas}')
    
    if [ "$READY" = "$DESIRED" ]; then
        echo -e "${GREEN}✓ cert-manager${component:+-$component} deployment is ready ($READY/$DESIRED)${NC}"
    else
        echo -e "${RED}✗ cert-manager${component:+-$component} deployment not ready ($READY/$DESIRED)${NC}"
        exit 1
    fi
done

# 2. Check AWS Route53 credentials
echo -e "\nChecking Route53 credentials..."
KEYS=$(kubectl get secret -n $NAMESPACE route53-credentials -o jsonpath='{.data.AWS_ACCESS_KEY_ID},{.data.AWS_SECRET_ACCESS_KEY}' 2>/dev/null)
if [ $? -eq 0 ] && [ ! -z "$KEYS" ]; then
    echo -e "${GREEN}✓ Route53 credentials are configured${NC}"
else
    echo -e "${RED}✗ Route53 credentials not found${NC}"
    exit 1
fi

# 3. Check ClusterIssuer
echo -e "\nChecking ClusterIssuer configuration..."
CONDITION=$(kubectl get clusterissuer letsencrypt-staging -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
if [ "$CONDITION" = "True" ]; then
    echo -e "${GREEN}✓ ClusterIssuer is ready${NC}"
else
    echo -e "${RED}✗ ClusterIssuer is not ready${NC}"
    echo "Debug info:"
    kubectl get clusterissuer letsencrypt-staging -o yaml
    exit 1
fi

# 4. Test certificate issuance
echo -e "\nTesting certificate issuance..."
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: validate-cert
  namespace: $NAMESPACE
spec:
  secretName: validate-cert-tls
  dnsNames:
  - $TEST_DOMAIN
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
  duration: 2160h
  renewBefore: 360h
EOF
check_status "Created test certificate"

echo "Waiting for certificate (90s timeout)..."
kubectl wait --for=condition=Ready=true certificate -n $NAMESPACE validate-cert --timeout=90s
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Certificate issued successfully${NC}"
else
    echo -e "${RED}✗ Certificate issuance failed${NC}"
    echo "\nDebug info:"
    echo "\nCertificate:"
    kubectl get certificate -n $NAMESPACE validate-cert -o yaml
    echo "\nCertificateRequest:"
    kubectl get certificaterequest -n $NAMESPACE -l cert-manager.io/certificate-name=validate-cert -o yaml
    echo "\nChallenge:"
    kubectl get challenge -n $NAMESPACE -l cert-manager.io/certificate-name=validate-cert -o yaml
    exit 1
fi

echo -e "\n${GREEN}✓ All cert-manager validations passed!${NC}"
