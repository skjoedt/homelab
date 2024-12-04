# Homelab Kubernetes Cluster

This repository contains the Infrastructure as Code (IaC) for a k3s cluster deployment.

## Prerequisites

- 3 Ubuntu LXC containers (already configured via Terraform)
- Ansible installed on the control machine
- kubectl installed on the control machine

## Initial Setup

1. Clone this repository
2. Configure hosts in `cluster/ansible/inventory/hosts.yml`
3. Run the k3s installation:

```bash
cd cluster/ansible
ansible-playbook -i inventory/hosts.yml playbooks/k3s-install.yml
```

4. Install kube-vip:

```bash
helmfile -f cluster/helmfile/helmfile.yaml apply
```

## Testing the Setup

1. Check cluster nodes:
```bash
kubectl get nodes -o wide
```

2. Verify kube-vip installation:
```bash
kubectl get pods -n kube-system | grep kube-vip
```

3. Test the control plane VIP:
```bash
ping 10.0.0.10
```