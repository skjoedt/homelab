# 🏠 Homelab

This repo contains all of the configuration and documentation of my homelab.

The purpose of my homelab is to learn and to have fun.

## :computer: Hardware

The cluster is not running high availability as I only have one node for staging and production.

| Type       | Hardware                 |
|------------|--------------------------|
| staging    | Intel NUC NUC8i7BEH      |
| production | Dell Precision Tower7810 |

Development is on my local Macbook Pro M1.

# Getting started

1. Bootstrap the cluster
2. Load it with AWS access key secret `aws-creds`

```
kubectl create secret generic aws-creds -n external-secrets \
  --from-literal=AWS_ACCESS_KEY_ID=XXX \
  --from-literal=AWS_SECRET_ACCESS_KEY=XXX \
  --from-literal=VAULT_SEAL_TYPE=awskms \
  --from-literal=VAULT_AWSKMS_SEAL_KEY_ID=XXX
```

# Cluster provisioning

| Type       | K8s Distribution | Control Plane | Deployment |
|------------|------------------|---------------|------------|
| testing    | k3d (wrapper)    | localhost     | Kustomize  |
| staging    | k3sup (wrapper)  | 10.0.0.50/24  | TBD        |
| production | k3s              | N/A           | TBD        |

# Endpoints

Ingress routes are defined in each environment under the following endpoints

| Type       | Endpoints          |
|------------|--------------------|
| testing    | *.traefik.me       |
| staging    | *.staging.fanen.dk |
| production | *.fanen.dk         |

# Storage

The goal of using an external ceph storage is to be able to delete the entire kubernetes cluster and recreate it using deterministic volume handles and fetch existing data that has the `Retain` reclaim policy through the ceph storage classes.

# Secret management

I use AWS Secret Manager to store my secrets.
They are synced using external secrets.

A fake store is provided for local testing and may provide a secret inventory.
