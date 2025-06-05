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

Empty

TODO: I will most likely setup ceph on the production node.

# Secret management

I use AWS Secret Manager to store my secrets.
They are synced using external secrets.

A fake store is provided for local testing.
