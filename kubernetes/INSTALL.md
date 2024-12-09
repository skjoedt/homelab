# Homelab Kubernetes Cluster Setup

This guide walks through the process of bootstrapping a K3s cluster with high availability control plane and load balancing capabilities.

## Prerequisites

- Three Ubuntu nodes with SSH access
- `kubectl` and `helm` installed on your local machine

## 1. Bootstrap K3s Cluster

The bootstrap process sets up a lightweight K3s cluster with high availability:

```bash
# Run the bootstrap script
./kubernetes/bootstrap.sh
```

The script will:
1. Install k3sup if not present
2. Bootstrap the control plane node with VIP support (10.0.0.10)
3. Join worker nodes to the cluster
4. Configure your local kubeconfig

> **Important**: The script wipes your local `.kube/config`. 
> **Important**: The bootstrap process automatically configures the API server certificate to include the VIP address (10.0.0.10) in its SANs list.

Verify the cluster is ready:
```bash
kubectl get nodes -o wide
```

# Load AWS credentials

Create a local secret for the AWS credentials in order to configure external-secrets.

```bash
kubectl create secret generic aws-creds -n external-secrets \
  --from-literal=AWS_ACCESS_KEY_ID=<#access key> \
  --from-literal=AWS_SECRET_ACCESS_KEY=<#secret key>
```

# Deploy helmfile

```bash
# Install helmfile if not present
curl -fsSL https://raw.githubusercontent.com/helmfile/helmfile/main/scripts/get-helmfile | bash

helmfile sync
```

## 3. Verify Installation

```bash
./<service>/validate.sh   # Tests API server availability via VIP
```

# Dependencies

## Secrets Manager

The cluster uses AWS Secrets Manager for secure secret management via External Secrets Operator (ESO). Here's how to configure it:

1. Create the required IAM policies found in `kubernetes/external-secrets/aws/secretsmanager-policy.json`.
2. Attach the policy to the IAM user `homelab`
3. Create access keys for AWS API access
4. Set up secrets in AWS secret manager e.g. for Traefik dashboard auth.

## Route53 and LetsEncrypt

The cluster uses letsencrypt with dns challenge using AWS Route53. 

1. Create the required IAM policies found in `kubernetes/cert-manager/aws/route53-policy.json`
2. Attach the policy to the IAM user `homelab-route53`
3. Create access keys and store them in AWS secrets manager under `homelab/traefik/route53-credentials`