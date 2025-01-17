# Kubernetes

Kubernetes is deployed in the following stages:

- Deploy lxc instances with terraform
- Deploy k3s with k3sup

## Deploy lxc instances with terraform

```
terraform apply
```

Will create 3 kubernetes controller and 2 worker instances.

## Deploy k3s with k3sup
https://www.youtube.com/watch?v=2cbniIZUpXM&t=1176s

We use k3sup (ketchup) to deploy k3s via ssh in minutes.

```
brew install k3sup
```

### First node

Then, initialize the first server (kube-1) with

```
k3sup install \
--ip 192.168.68.21 \
--tls-san 192.168.68.20 \
--tls-san kube.fanen.dk \
--cluster \
--k3s-channel latest \
--k3s-extra-args "--disable servicelb" \
--local-path $HOME/.kube/config \
--user skjoedt \
--merge
```

Note: The `--tls-san` is yet to be routed.

Note: The `--disable servicelb` is necessary when using kube-vip as service load balancer:

> If wanting to use the kube-vip cloud controller, pass the --disable servicelb flag so K3s will not attempt to render Kubernetes Service resources of type LoadBalancer. If building with k3sup, the flag should be given as an argument to the --k3s-extra-args flag itself: --k3s-extra-args "--disable servicelb". To install the kube-vip cloud controller, follow the additional steps in the cloud controller guide.

See https://kube-vip.io/docs/usage/k3s/.

### Kube-Vip

Before continuing to the next node we will install kube-vip according to the docs.

https://kube-vip.io/docs/usage/k3s/

1. Login to the kube-1 instance and issue the following commands according to the docs

```
sudo su -
mkdir -p /var/lib/rancher/k3s/server/manifests/
curl https://kube-vip.io/manifests/rbac.yaml > /var/lib/rancher/k3s/server/manifests/kube-vip-rbac.yaml
kubectl apply -f https://kube-vip.io/manifests/rbac.yaml
export VIP=192.168.68.20
export INTERFACE=enp5s0
KVVERSION=$(curl -sL https://api.github.com/repos/kube-vip/kube-vip/releases | jq -r ".[0].name")
alias kube-vip="ctr image pull ghcr.io/kube-vip/kube-vip:$KVVERSION; ctr run --rm --net-host ghcr.io/kube-vip/kube-vip:$KVVERSION vip /kube-vip"
kube-vip manifest daemonset \
    --interface $INTERFACE \
    --address $VIP \
    --inCluster \
    --taint \
    --controlplane \
    --services \
    --arp \
    --leaderElection > /var/lib/rancher/k3s/server/manifests/kube-vip-manifest.yaml
kubectl apply -f /var/lib/rancher/k3s/server/manifests/kube-vip-manifest.yaml
```

You should see a pod name `kube-vip-ds` running:

```
kubectl get daemonsets --all-namespaces
NAMESPACE     NAME          DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
kube-system   kube-vip-ds   1         1         1       1            1           <none>          18m
```

Finally, install the kube-vip cloud-provider to allow applications to receive a virtual IP as well in the range of 192.168.68.40-99.

```
kubectl apply -f https://raw.githubusercontent.com/kube-vip/kube-vip-cloud-provider/main/manifest/kube-vip-cloud-controller.yaml
kubectl create configmap -n kube-system kubevip --from-literal range-global=192.168.68.40-192.168.68.99/29
```

Note: It could be interesting to test the above method using helmfile instead, with the charts at https://github.com/kube-vip/helm-charts for both kube-vip and kube-vip-cloud-provider.

### Initialize remaining k3s nodes

Here, the command is a bit simpler.

```
k3sup join \
--ip 192.168.68.22 \
--server-ip 192.168.68.21 \
--server \
--k3s-channel latest \
--user skjoedt
```

and

```
k3sup join \
--ip 192.168.68.23 \
--server-ip 192.168.68.21 \
--server \
--k3s-channel latest \
--user skjoedt
```

Note: The command might fail with `k3s.service: Failed with result 'exit-code'.`. Simply start the service again or rerun the join command.

Check that the nodes are ready

```
kubectl get nodes
NAME     STATUS   ROLES                       AGE     VERSION
kube-1   Ready    control-plane,etcd,master   53m     v1.31.2+k3s1
kube-2   Ready    control-plane,etcd,master   5m22s   v1.31.2+k3s1
kube-3   Ready    control-plane,etcd,master   117s    v1.31.2+k3s1
```

```
kubectl get pods --all-namespaces
NAMESPACE     NAME                                      READY   STATUS      RESTARTS        AGE
kube-system   coredns-56f6fc8fd7-f5h9c                  1/1     Running     1 (16m ago)     54m
kube-system   helm-install-traefik-crd-2n7x9            0/1     Completed   0               54m
kube-system   helm-install-traefik-l6c2q                0/1     Completed   1               54m
kube-system   kube-vip-ds-dbzcc                         1/1     Running     2 (7m51s ago)   32m
kube-system   kube-vip-ds-pzfj5                         1/1     Running     0               6m51s
kube-system   kube-vip-ds-vl8dm                         1/1     Running     0               3m28s
kube-system   local-path-provisioner-5cf85fd84d-b5zw7   1/1     Running     1 (16m ago)     54m
kube-system   metrics-server-5985cbc9d7-tkfhm           1/1     Running     1 (16m ago)     54m
kube-system   traefik-57b79cf995-mr5k6                  1/1     Running     1 (16m ago)     54m
```

We may have to delete traefik to deploy it using helm charts with a custom configuration.

```
kubectl delete deployment traefik --namespace kube-system
```

Finally,

## Test

To test use nginx

```
kubectl create namespace nginx
kubectl create deployment nginx --image nginx --namespace nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer --name nginx --namespace nginx
```

The nginx should be getting an external IP, which for us is not the case (pending). Notice the traefik is still here.

```
kubectl get services --all-namespaces
NAMESPACE     NAME             TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
default       kubernetes       ClusterIP      10.43.0.1       <none>        443/TCP                      77m
kube-system   kube-dns         ClusterIP      10.43.0.10      <none>        53/UDP,53/TCP,9153/TCP       77m
kube-system   metrics-server   ClusterIP      10.43.72.5      <none>        443/TCP                      77m
kube-system   traefik          LoadBalancer   10.43.104.71    <pending>     80:31603/TCP,443:30285/TCP   76m
nginx         nginx            LoadBalancer   10.43.129.222   <pending>     80:32023/TCP                 5m3s
```

More digging is needed...
