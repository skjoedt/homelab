# 🏠 Homelab

This repo contains all of the configuration and documentation of my homelab.

The purpose of my homelab is to learn and to have fun.

## :computer: Hardware

The cluster is not running high availability as I only have two nodes.

| Device                   | Num | OS Disk | Data Disk         | RAM   | CPU            |
| ------------------------ | --- | ------- | ----------------- | ----- | -------------- |
| Intel NUC NUC8i7BEH      | 1   | 223.6G  | -                 | 8 GB  | Intel i7-8559U |
| Dell Precision Tower7810 | 1   | 512G    | 3x IronWolf 10 TB | 64 GB | Xeon e5-2620   |

Development is on my local machine using k3d.

# Getting started

1. Provision metal

    ```bash
    cd terraform/lxc/dragon-1 && terraform apply
    ```

2. Bootstrap the cluster

    ```bash
    make bootstrap-production
    ```

3. Bootstrap ArgoCD

    ```bash
    make argocd-bootstrap-production
    ```

4. Load AWS access for External Secrets

    ```bash
    kubectl create secret generic aws-creds -n external-secrets \
    --from-literal=AWS_ACCESS_KEY_ID=XXX \
    --from-literal=AWS_SECRET_ACCESS_KEY=XXX \
    --from-literal=VAULT_SEAL_TYPE=awskms \
    --from-literal=VAULT_AWSKMS_SEAL_KEY_ID=XXX
    ```

5. Check reconciliation

    ```bash
    make argocd-status-production
    ```

# ArgoCD

`make argocd-bootstrap-production` installs ArgoCD and applies `system/argocd/production`. After that, ArgoCD tracks `https://github.com/skjoedt/homelab.git` at `main`.

The root uses two ApplicationSets: one wildcard for Helm controllers under `system/controllers/*` and `monitoring/controllers/*`, and one small list for Kustomize roots.

```bash
make argocd-render-production
make argocd-status-production
make argocd-test-branch
```

`make argocd-test-branch` uses `TARGET_REVISION` to render the current branch, which must be pushed before ArgoCD can sync it from GitHub.

# Folder structure

```text
.
├── apps
│   ├── base
│   └── production
├── monitoring
│   ├── configs
│   │   ├── base
│   │   └── production
│   └── controllers
├── system
    ├── argocd
    ├── configs
    │   ├── base
    │   └── production
    └── controllers
└── terraform
```

# Cluster provisioning

| Type       | K8s Distribution | Control Plane | Load Balancer | Deployment |
| ---------- | ---------------- | ------------- | ------------- | ---------- |
| testing    | k3d (wrapper)    | localhost     | localhost     | Manual and ArgoCD smoke tests |
| production | k3s              | 10.0.0.30     | 10.0.0.50     | ArgoCD |

# Endpoints

Gateway routes are defined in each environment under the following endpoints

| Type       | Endpoints          |
| ---------- | ------------------ |
| testing    | *.localho.st       |
| production | *.fanen.dk         |

# Storage

The cluster is using an external ceph storage cluster that is running on the same hardware as the kubernetes cluster. The PVCs are dynamically provisioned using the ceph csi driver. 

A complete inventory of PV volume handles are available in velero backups for easy cluster reinitialization and recovery.

# Secret management

I use AWS Secret Manager to store my secrets.
They are synced using external secrets.

A fake store is provided for local testing and may provide a secret inventory.

# References

- <https://github.com/pando85/homelab>
- <https://github.com/khuedoan/homelab>
- <https://github.com/mischavandenburg/homelab> (no longer public)
