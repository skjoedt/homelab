#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"

# Utility functions
log_header() {
    echo -e "\n${YELLOW}$1${NC}"
}

log_success() {
    echo -e "${CHECK} $1"
}

log_error() {
    echo -e "${CROSS} $1"
    return 1
}

wait_for_condition() {
    local timeout=$1
    local condition=$2
    local message=$3
    local error_message=$4

    echo -n "$message"
    
    for i in $(seq 1 $timeout); do
        if eval $condition; then
            echo -e "\r${CHECK} $message"
            return 0
        fi
        echo -n "."
        sleep 1
    done
    echo -e "\r${CROSS} $message"
    echo -e "${RED}$error_message${NC}"
    return 1
}

# Start validation
echo -e "${YELLOW}Starting Traefik validation...${NC}\n"

# Check Traefik deployment
log_header "Checking Traefik deployment status..."

# Wait for deployment
wait_for_condition 60 \
    "kubectl -n traefik get deployment traefik -o jsonpath='{.status.availableReplicas}' 2>/dev/null | grep -q '^1$'" \
    "Waiting for Traefik deployment" \
    "Traefik deployment not ready after 60 seconds" || exit 1

# Verify pod status and health
POD_NAME=$(kubectl -n traefik get pod -l app.kubernetes.io/name=traefik -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [[ -n "$POD_NAME" ]]; then
    READY=$(kubectl -n traefik get pod $POD_NAME -o jsonpath='{.status.containerStatuses[0].ready}')
    if [[ "$READY" == "true" ]]; then
        log_success "Traefik pod is ready and healthy"
    else
        log_error "Traefik pod is not ready" || exit 1
    fi
else
    log_error "Could not find Traefik pod" || exit 1
fi

# Check LoadBalancer service
log_header "Checking LoadBalancer service..."

# Wait for LoadBalancer IP
wait_for_condition 30 \
    "kubectl -n traefik get service traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null | grep -q '^10.0.0.50$'" \
    "Checking LoadBalancer IP" \
    "LoadBalancer IP not assigned or incorrect" || exit 1

# Verify ports
PORTS=$(kubectl -n traefik get service traefik -o jsonpath='{.spec.ports[*].port}')
if echo $PORTS | grep -q "80" && echo $PORTS | grep -q "443"; then
    log_success "LoadBalancer ports 80 and 443 are configured"
else
    log_error "Required ports not configured correctly" || exit 1
fi

# Check ExternalSecret and auth secret
log_header "Checking authentication configuration..."

# Wait for ExternalSecret
wait_for_condition 30 \
    'kubectl -n traefik get externalsecret traefik-dashboard-auth -o jsonpath="{.status.conditions[?(@.type==\"Ready\")].status}" 2>/dev/null | grep -q True' \
    "Waiting for ExternalSecret" \
    "ExternalSecret not ready after 30 seconds" || exit 1

# Check if secret was created
if kubectl -n traefik get secret traefik-dashboard-auth >/dev/null 2>&1; then
    log_success "Dashboard authentication secret created"
else
    log_error "Dashboard authentication secret not found" || exit 1
fi

# Check SSL certificate
log_header "Checking SSL certificate..."

# Wait for Certificate
wait_for_condition 180 \
    'kubectl -n traefik get certificate traefik-dashboard -o jsonpath="{.status.conditions[?(@.type==\"Ready\")].status}" 2>/dev/null | grep -q True' \
    "Waiting for SSL certificate" \
    "Certificate not ready after 180 seconds" || exit 1

# Verify certificate issuer
ISSUER=$(kubectl -n traefik get certificate traefik-dashboard -o jsonpath='{.spec.issuerRef.name}' 2>/dev/null)
if [[ "$ISSUER" == "letsencrypt" ]]; then
    log_success "Certificate using correct issuer"
else
    log_error "Certificate not using Let's Encrypt production issuer" || exit 1
fi

# Check IngressRoute
log_header "Checking Ingress configuration..."

if kubectl -n traefik get ingressroute traefik-dashboard >/dev/null 2>&1; then
    MIDDLEWARE=$(kubectl -n traefik get ingressroute traefik-dashboard -o jsonpath='{.spec.routes[0].middlewares[0].name}' 2>/dev/null)
    if [[ "$MIDDLEWARE" == "traefik-basic-auth" ]]; then
        log_success "IngressRoute properly configured with authentication"
    else
        log_error "IngressRoute missing authentication middleware" || exit 1
    fi
else
    log_error "Dashboard IngressRoute not found" || exit 1
fi

# Test connectivity
log_header "Testing connectivity..."

# Test HTTPS connection
HTTPS_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k -H "Host: traefik.fanen.dk" https://10.0.0.50)
if [[ "$HTTPS_CODE" == "401" ]]; then
    log_success "HTTPS endpoint responding with authentication request"
else
    log_error "HTTPS endpoint not responding correctly (got: $HTTPS_CODE)" || exit 1
fi

# Test HTTP redirect with domain
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: traefik.fanen.dk" http://10.0.0.50)
if [[ "$HTTP_CODE" == "308" ]]; then
    log_success "HTTP to HTTPS redirect working with domain"
else
    log_error "HTTP to HTTPS redirect not working with domain (got: $HTTP_CODE)" || exit 1
fi


# Test TLS certificate
if echo | openssl s_client -connect 10.0.0.50:443 -servername traefik.fanen.dk 2>/dev/null | grep -q "BEGIN CERTIFICATE"; then
    log_success "TLS certificate is being served"
else
    log_error "TLS certificate not being served properly" || exit 1
fi

echo -e "\n${GREEN}All Traefik validations passed!${NC}\n"
exit 0
