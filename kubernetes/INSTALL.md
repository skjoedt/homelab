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
2. Bootstrap the control plane node with VIP support (10.0.0.10)
3. Join worker nodes to the cluster
4. Configure your local kubeconfig

> **Important**: The bootstrap process automatically configures the API server certificate to include the VIP address (10.0.0.10) in its SANs list.

Verify the cluster is ready:
```bash
kubectl get nodes -o wide
```

## 2. Configure High Availability

Our cluster uses two complementary tools for high availability:

### Control Plane HA (kube-vip)
kube-vip provides API server high availability:
- Control Plane VIP: `10.0.0.10`
- Access the cluster via `kubectl --server=https://10.0.0.10:6443`
- Layer 2 mode with ARP for local network compatibility

### Service Load Balancing (MetalLB)
MetalLB manages external access to services:
- IP Range: `10.0.0.50-10.0.0.99`
- Layer 2 mode for simple network integration
- Automatic IP assignment for LoadBalancer services

### Deploy HA Components

```bash
# Install helmfile if not present
curl -fsSL https://raw.githubusercontent.com/helmfile/helmfile/main/scripts/get-helmfile | bash

# Deploy kube-vip and MetalLB
cd kubernetes
helmfile sync
```

## 3. Verify Installation

Validate the control plane HA:
```bash
./kube-vip/validate.sh   # Tests API server availability via VIP
```

Test load balancing:
```bash
./metallb/validate.sh    # Creates test service and validates IP assignment
```

## 4. Secret Manager

The cluster uses AWS Secrets Manager for secure secret management via External Secrets Operator (ESO). Here's how to configure it:

### AWS IAM Setup
1. Create the required IAM policies:

```json
# homelab-secrets-manager-read policy
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret"
            ],
            "Resource": "arn:aws:secretsmanager:eu-west-1:*:secret:homelab/*"
        },
        {
            "Effect": "Allow",
            "Action": "secretsmanager:ListSecrets",
            "Resource": "*"
        }
    ]
}
```

2. Attach the policy to your IAM user
3. Create access keys for AWS API access

### Kubernetes Integration
1. Store AWS credentials in the external-secrets namespace:
```bash
kubectl create secret generic aws-creds -n external-secrets \
  --from-literal=AWS_ACCESS_KEY_ID=<access-key> \
  --from-literal=AWS_SECRET_ACCESS_KEY=<secret-key>
```

2. Deploy External Secrets Operator:
```bash
helmfile --selector name=external-secrets sync
```

3. Verify the setup:
```bash
# Check ESO is running
kubectl get pods -n external-secrets

# Verify the ClusterSecretStore is ready
kubectl get clustersecretstore aws-secrets-manager
```

After setup, you can create ExternalSecret resources that automatically sync AWS Secrets Manager secrets into Kubernetes secrets.

## Troubleshooting

### Control Plane VIP Issues
1. Certificate errors when accessing VIP:
```bash
# Check the API server certificate SANs
echo | openssl s_client -connect 10.0.0.10:6443 2>/dev/null | openssl x509 -noout -text | grep DNS
# If VIP is missing, rerun bootstrap with correct tls-san parameter
```

2. Connection issues:
```bash
# Verify kube-vip pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=kube-vip

# Check VIP status
ping 10.0.0.10
telnet 10.0.0.10 6443
```

### LoadBalancer Service Issues
1. Check MetalLB status:
```bash
kubectl -n metallb-system get all
```

2. Verify IP assignment:
```bash
kubectl get svc -o wide     # Look for EXTERNAL-IP
kubectl -n metallb-system logs -l app.kubernetes.io/component=controller
```

## Next Steps

- Configure persistent storage
- Set up monitoring and logging
- Deploy your applications
