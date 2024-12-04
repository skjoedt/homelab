# Homelab Kubernetes Cluster Setup

This guide walks through the process of bootstrapping a K3s cluster and configuring essential components using helmfile.

## Prerequisites

- Three Ubuntu nodes with SSH access
- DNS records or /etc/hosts entries for the nodes
- Network connectivity between nodes
- `kubectl` installed on your local machine

## 1. Bootstrap K3s Cluster

The bootstrap process automatically installs a lightweight K3s cluster with a designated control plane and worker nodes.

```bash
# Make the bootstrap script executable
chmod +x kubernetes/bootstrap.sh

# Run the bootstrap script
./kubernetes/bootstrap.sh
```

The script will:
1. Install k3sup if not present
2. Bootstrap the control plane node
3. Join worker nodes to the cluster
4. Configure your local kubeconfig

Verify the cluster is ready:
```bash
kubectl get nodes -o wide
```

## 2. Configure Load Balancing

We use kube-vip for both control plane high availability and service load balancing.

### Install Helmfile

```bash
# Install helmfile
curl -fsSL https://raw.githubusercontent.com/helmfile/helmfile/main/scripts/get-helmfile | bash

# Verify installation
helmfile --version
```

### Deploy kube-vip

```bash
cd kubernetes
helmfile sync
```

Verify the kube-vip deployment:
```bash
# Make the validation script executable
chmod +x kube-vip/validate.sh

# Run validation
./kube-vip/validate.sh
```

## Configuration Details

### Virtual IP Addresses
- Control Plane VIP: `10.0.0.10`
- LoadBalancer Range: `10.0.0.50-10.0.0.100`

### Network Interface
- All nodes use `enp5s0` for VIP management

## Testing LoadBalancer Services

Create a test service:
```bash
# Deploy a test nginx instance
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --type=LoadBalancer --port=80

# Check the assigned IP
kubectl get svc nginx
```

## Troubleshooting

### Common Issues

1. **VIP Not Responding**
   ```bash
   # Check kube-vip pods
   kubectl get pods -n kube-system -l app.kubernetes.io/name=kube-vip
   
   # Check logs
   kubectl logs -n kube-system -l app.kubernetes.io/name=kube-vip
   ```

2. **LoadBalancer IP Not Assigned**
   ```bash
   # Check service events
   kubectl describe svc <service-name>
   ```

### Validation

Run the validation script anytime to verify the setup:
```bash
./kube-vip/validate.sh
```

## Next Steps

- Configure persistent storage
- Set up monitoring and logging
- Deploy your applications
