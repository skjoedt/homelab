#!/bin/bash

# Exit on error
set -e

# Check for required arguments
if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <controller_ip> <controller_vip> <worker_ip1> [worker_ip2] [worker_ipN]..."
    exit 1
fi

# Parse arguments
CONTROL_PLANE="$1"
CONTROL_PLANE_VIP="$2"
# Shift away the first two arguments to get worker nodes
shift 2
# Remaining arguments are worker nodes
WORKER_NODES=("$@")

# Configuration
SSH_USER="skjoedt"
SSH_KEY="${HOME}/.ssh/id_rsa"
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
    --ssh-key  "${SSH_KEY}" \
    --k3s-version "${K3S_VERSION}" \
    --k3s-extra-args "--disable traefik --disable servicelb --tls-san ${CONTROL_PLANE_VIP}" \
    --context homelab \
    --merge \
    --local-path "$HOME"/.kube/config

# Join worker nodes
for worker in "${WORKER_NODES[@]}"; do
    echo "Joining worker node ${worker}..."
    k3sup join \
        --ip "${worker}" \
        --user "${SSH_USER}" \
        --ssh-key  "${SSH_KEY}" \
        --server-ip "${CONTROL_PLANE}" \
        --k3s-version "${K3S_VERSION}"
done

# Verify cluster
printf "\nVerifying cluster setup...\n"
sleep 10  # Give some time for nodes to register
kubectl get nodes -o wide

printf "\nK3s cluster bootstrap complete!\n"
