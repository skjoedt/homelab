#!/bin/bash

# Exit on error
set -e

# Configuration
CONTROL_PLANE="10.0.0.11"
WORKER_NODES=("10.0.0.12" "10.0.0.13")
CONTROL_PLANE_VIP="10.0.0.10"
SSH_USER="skjoedt"
K3S_VERSION="v1.31.2+k3s1"

# Install k3sup if not present
if ! command -v k3sup &> /dev/null; then
    echo "Installing k3sup..."
    curl -sLS https://get.k3sup.dev | sh
    sudo install k3sup /usr/local/bin/
fi

# Wipe local kube config
echo "" > ~/.kube/config

# Install control plane
echo "Installing K3s control plane on ${CONTROL_PLANE}..."
k3sup install \
    --ip "${CONTROL_PLANE}" \
    --user "${SSH_USER}" \
    --k3s-version "${K3S_VERSION}" \
    --k3s-extra-args "--disable traefik --disable servicelb --tls-san ${CONTROL_PLANE_VIP}" \
    --context homelab \
    --merge \
    --local-path $HOME/.kube/config

# Join worker nodes
for worker in "${WORKER_NODES[@]}"; do
    echo "Joining worker node ${worker}..."
    k3sup join \
        --ip "${worker}" \
        --user "${SSH_USER}" \
        --server-ip "${CONTROL_PLANE}" \
        --k3s-version "${K3S_VERSION}"
done

# Verify cluster
echo "\nVerifying cluster setup..."
sleep 10  # Give some time for nodes to register
kubectl get nodes -o wide

echo "\nK3s cluster bootstrap complete!"
