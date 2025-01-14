# Homelab kubernetes

Kubernetes is running using k3s. 

# Installation

See `INSTALL.md`

# Features

## High availability

Our cluster uses two complementary tools for high availability:

### Control Plane HA (kube-vip)
kube-vip provides API server high availability:
- Control Plane VIP: `10.0.0.10`
- Access the cluster via `kubectl --server=https://10.0.0.10:6443`

### Service Load Balancing (MetalLB)
MetalLB manages external access to services:
- IP Range: `10.0.0.50-10.0.0.99`