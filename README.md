# 🏠 Homelab

This repo contains all of the configuration and documentation of my homelab.

The purpose of my homelab is to learn and to have fun.

## :computer: Hardware

The cluster is not running high availability as I only have one node for staging and production.

| Device                   | Num | OS Disk | Data Disk         | RAM   | CPU            | Function   |
| ------------------------ | --- | ------- | ----------------- | ----- | -------------- | ---------- |
| Intel NUC NUC8i7BEH      | 1   | 223.6G  | 3x IronWolf 10 TB | 8 GB  | Intel i7-8559U | staging    |
| Dell Precision Tower7810 | 1   | 512G    | -                 | 64 GB | Xeon e5-2620   | production |

Development is on my local Macbook Pro M1.

# Cluster provisioning

| Type       | K8s Distribution | Control Plane | Deployment |
| ---------- | ---------------- | ------------- | ---------- |
| testing    | k3d (wrapper)    | localhost     | Kustomize  |
| staging    | k3sup (wrapper)  | 10.0.0.50/24  | Flux       |
| production | k3s              | N/A           | Flux       |

# Endpoints

Ingress routes are defined in each environment under the following endpoints

| Type       | Endpoints          |
| ---------- | ------------------ |
| testing    | *.traefik.me       |
| staging    | *.staging.fanen.dk |
| production | *.fanen.dk         |

# Storage

Empty

TODO: I will most likely setup ceph rook on the production node.

# Secret management

I use AWS Secret Manager to store my secrets.
They are synced using external secrets.

A fake store is provided for local testing.

# References

- <https://github.com/onedr0p/home-ops>
- <https://github.com/mischavandenburg/homelab>
