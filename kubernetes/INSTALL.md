# Homelab Kubernetes Cluster Setup

This guide walks through the process of bootstrapping a K3s cluster with high availability control plane and load balancing capabilities.

## Prerequisites

- Three Ubuntu nodes with SSH access
- DNS records or /etc/hosts entries for the nodes
- Network connectivity between nodes
- `kubectl` installed on your local machine

## 1. Bootstrap K3s Cluster

The bootstrap process sets up a lightweight K3s cluster with high availability:

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

## 2. Configure High Availability

Our cluster uses two complementary solutions for high availability:

### Control Plane HA (kube-vip)
kube-vip provides a virtual IP for the control plane, ensuring continuous API server availability:
- Control Plane VIP: `10.0.0.10`
- Layer 2 mode with ARP for local network compatibility

### Service Load Balancing (MetalLB)
MetalLB handles LoadBalancer service types:
- IP Range: `10.0.0.50-10.0.0.99`
- Layer 2 mode for simple network integration

### Deploy HA Components

```bash
# Install helmfile if not present
curl -fsSL https://raw.githubusercontent.com/helmfile/helmfile/main/scripts/get-helmfile | bash

# Deploy kube-vip and MetalLB
cd kubernetes
helmfile sync
```

## 3. Verify Installation

Test the control plane HA:
```bash
./kube-vip/validate.sh
```

Test service load balancing:
```bash
./metallb/validate.sh
```

## Troubleshooting

### Control Plane VIP Issues
1. Check kube-vip pods:
```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=kube-vip
```

2. Verify VIP accessibility:
```bash
ping 10.0.0.10
```

### LoadBalancer Service Issues
1. Check MetalLB pods:
```bash
kubectl get pods -n metallb-system
```

2. Verify service allocation:
```bash
kubectl describe service <service-name>
```

## Next Steps

- Configure persistent storage
- Set up monitoring and logging
- Deploy your applications
