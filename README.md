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

# ArgoCD MVC

ArgoCD is the production control plane for this repository.

The bootstrap boundary is small. `make argocd-bootstrap-production` installs the ArgoCD Helm chart from `system/controllers/argocd`, waits for ArgoCD CRDs, and applies the root manifests in `system/argocd/production`.

After bootstrap, ArgoCD monitors `https://github.com/skjoedt/homelab.git` at `main` and reconciles the desired state from this repository.

ArgoCD owns these production entrypoints:

| Layer | Source | Render type |
| ----- | ------ | ----------- |
| System controllers | `system/controllers/*` | Helm and Kustomize |
| System configuration | `system/configs/production` | Kustomize |
| Monitoring controllers | `monitoring/controllers/*` | Helm |
| Monitoring configuration | `monitoring/configs/production` | Kustomize |
| Applications | `apps/production` | Kustomize |

The production root uses ApplicationSets to keep the repo layout explicit while avoiding one manifest per controller. Sync waves install ArgoCD, CRDs, controllers, configuration, monitoring, and applications in that order. Applications use automated sync, pruning, self-healing, and retry backoff.

Production should normally be changed through Git. Merge to `main`, then ArgoCD reconciles the cluster to the merged state.

Useful commands:

```bash
make argocd-status-production
make argocd-admin-password
make argocd-port-forward
```

The UI is available through port-forwarding at <http://localhost:8080> or through the production route at <https://argocd.fanen.dk> after Traefik and Gateway resources are healthy.

# Testing ArgoCD changes

Render the production root locally before pushing:

```bash
make argocd-render-production
```

Render the production root as a feature branch:

```bash
make argocd-render-production TARGET_REVISION=$(git rev-parse --abbrev-ref HEAD)
```

After pushing the feature branch, smoke-test ArgoCD itself in k3d before merging:

```bash
make argocd-test-branch
```

That target creates or reuses the branch-specific k3d cluster, installs ArgoCD, applies the root manifests with `TARGET_REVISION` set to the current branch, and lists generated Applications. It validates ArgoCD bootstrap, ApplicationSet generation, repo access, and manifest rendering. Full production health still requires production-only dependencies such as AWS secrets, Ceph, and production network addresses.

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
