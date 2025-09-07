# 🏠 Homelab

This repo contains all of the configuration and documentation of my homelab.

The purpose of my homelab is to learn and to have fun.

## :computer: Hardware

The cluster is not running high availability as I only have two nodes.

| Device                   | Num | OS Disk | Data Disk         | RAM   | CPU            |
| ------------------------ | --- | ------- | ----------------- | ----- | -------------- |
| Intel NUC NUC8i7BEH      | 1   | 223.6G  | -                 | 8 GB  | Intel i7-8559U |
| Dell Precision Tower7810 | 1   | 512G    | 3x IronWolf 10 TB | 64 GB | Xeon e5-2620   |

Development is on my local macbook using k3d.

# Getting started

1. Provision metal

    ```bash
    cd metal/lxc/dragon-1 && terraform apply
    ```

2. Bootstrap the cluster

    ```bash
    make bootstrap-production
    ```

3. Install external secrets

    ```bash
    make prepare-production
    ```

4. Load it with AWS access key secret `aws-creds`

    ```bash
    kubectl create secret generic aws-creds -n external-secrets \
    --from-literal=AWS_ACCESS_KEY_ID=XXX \
    --from-literal=AWS_SECRET_ACCESS_KEY=XXX \
    --from-literal=VAULT_SEAL_TYPE=awskms \
    --from-literal=VAULT_AWSKMS_SEAL_KEY_ID=XXX
    ```

5. Provision resources

    ```bash
    make prepare-production
    ```

# Cluster provisioning

| Type       | K8s Distribution | Control Plane | Load Balancer | Deployment |
| ---------- | ---------------- | ------------- | ------------- | ---------- |
| testing    | k3d (wrapper)    | localhost     | localhost     | Manual     |
| production | k3s              | 10.0.0.30     | 10.0.0.50     | ArgoCD     |

# Endpoints

Ingress routes are defined in each environment under the following endpoints

| Type       | Endpoints          |
| ---------- | ------------------ |
| testing    | *.traefik.me       |
| production | *.fanen.dk         |

# Storage

The goal of using an external ceph storage is to be able to delete the entire kubernetes cluster and recreate it using deterministic volume handles and fetch existing data that has the `Retain` reclaim policy through the ceph storage classes.

The caveat is we need to create all rbd images manually with the same size

```
rbd -c ceph.conf --id homelab -p kubernetes create grafana-data --size 10G
```

# Secret management

I use AWS Secret Manager to store my secrets.
They are synced using external secrets.

A fake store is provided for local testing and may provide a secret inventory.

# References

- <https://github.com/pando85/homelab>
- <https://github.com/khuedoan/homelab>
- <https://github.com/mischavandenburg/homelab>
