.POSIX:
.PHONY: *
.EXPORT_ALL_VARIABLES:

# Variables
BRANCH_NAME := $(shell git rev-parse --abbrev-ref HEAD)
BRANCH_NAME_SLUG := $(subst /,-,$(BRANCH_NAME))
REGISTRY_PORT := $(shell echo $(BRANCH_NAME) | cksum | cut -d ' ' -f1 | awk '{print 5000 + ($$1 % 1000)}') # Hash the branch name to a number between 5000-5999

.PHONY: all

git-hooks:
	pre-commit install

# Check for required tools
check-deps:
	@which kubectl >/dev/null || (echo "kubectl is required but not installed" && exit 1)
	@which k3d >/dev/null || (echo "k3d is required but not installed" && exit 1)

# Create k3d cluster with branch-specific name
dev-up: check-deps
	@if ! k3d cluster list | grep -q "$(BRANCH_NAME_SLUG)"; then \
		k3d cluster create $(BRANCH_NAME_SLUG) \
		    --k3s-arg "--disable=traefik@server:*" \
			--servers 1 \
			--agents 0 \
			-p "80:80@loadbalancer" \
			-p "443:443@loadbalancer" \
			--registry-create $(BRANCH_NAME_SLUG)-registry:127.0.0.1:$(REGISTRY_PORT) \
			--wait; \
	fi
	@kubectl config use-context k3d-$(BRANCH_NAME_SLUG)

# Install CRDs
dev-prepare:
	@echo "Installing CRDs to $(CLUSTER_NAME)..."
	helm upgrade --install external-secrets ./system/controllers/external-secrets --namespace external-secrets --create-namespace -f ./system/controllers/external-secrets/values.yaml
	helm upgrade --install traefik ./system/controllers/traefik --namespace traefik --create-namespace -f ./system/controllers/traefik/values-dev.yaml
	helm upgrade --install kube-prometheus-stack ./monitoring/controllers/kube-prometheus-stack --namespace monitoring --create-namespace -f ./monitoring/controllers/kube-prometheus-stack/values.yaml
	helm upgrade --install grafana ./monitoring/controllers/grafana --namespace monitoring --create-namespace -f ./monitoring/controllers/grafana/values.yaml
	helm upgrade --install loki ./monitoring/controllers/loki --namespace monitoring --create-namespace -f ./monitoring/controllers/loki/values.yaml
	helm upgrade --install alloy ./monitoring/controllers/alloy --namespace monitoring --create-namespace -f ./monitoring/controllers/alloy/values.yaml
	kubectl apply -k ./system/configs/base
	kubectl apply -k ./monitoring/configs/base
dev: dev-up dev-prepare

# Delete the k3d cluster
dev-down:
	@echo "Deleting k3d cluster: $(BRANCH_NAME_SLUG)..."
	@k3d cluster delete $(BRANCH_NAME_SLUG)
	@echo "Cluster deleted"

staging-prepare: # to be replaced by argocd
	@read -p "aws-creds loaded? (y/n): " ans; [ "$$ans" = "y" ]
	@echo "Installing CRDs to $(CLUSTER_NAME)..."
	helm upgrade --install kube-vip ./system/controllers/kube-vip --namespace kube-vip --create-namespace -f ./system/controllers/kube-vip/values.yaml
	helm upgrade --install metallb ./system/controllers/metallb --namespace metallb --create-namespace -f ./system/controllers/metallb/values.yaml
	helm upgrade --install cert-manager ./system/controllers/cert-manager --namespace cert-manager --create-namespace -f ./system/controllers/cert-manager/values.yaml
	helm upgrade --install external-secrets ./system/controllers/external-secrets --namespace external-secrets --create-namespace -f ./system/controllers/external-secrets/values.yaml
	helm upgrade --install ceph-csi ./system/controllers/ceph-csi --namespace ceph --create-namespace -f ./system/controllers/ceph-csi/values.yaml
	helm upgrade --install reflector ./system/controllers/reflector --namespace reflector --create-namespace -f ./system/controllers/reflector/values.yaml
	helm upgrade --install external-dns ./system/controllers/external-dns --namespace external-dns --create-namespace -f ./system/controllers/external-dns/values.yaml
	helm upgrade --install traefik ./system/controllers/traefik --namespace traefik --create-namespace -f ./system/controllers/traefik/values.yaml
	helm upgrade --install kube-prometheus-stack ./monitoring/controllers/kube-prometheus-stack --namespace monitoring --create-namespace -f ./monitoring/controllers/kube-prometheus-stack/values.yaml
	helm upgrade --install grafana ./monitoring/controllers/grafana --namespace monitoring --create-namespace -f ./monitoring/controllers/grafana/values.yaml
	helm upgrade --install loki ./monitoring/controllers/loki --namespace monitoring --create-namespace -f ./monitoring/controllers/loki/values.yaml
	helm upgrade --install alloy ./monitoring/controllers/alloy --namespace monitoring --create-namespace -f ./monitoring/controllers/alloy/values.yaml
	kubectl apply -k ./system/configs/staging
	kubectl apply -k ./monitoring/configs/staging
	kubectl apply -k ./apps/staging

cluster-up:
	@echo "Deploying k3s cluster nodes with lxc (terraform)"
	cd metal/lxc && terraform apply
	sleep 15

cluster-down:
	@echo "Destroying k3s cluster nodes"
	lxc remote switch beholder-1
	lxc image list -f csv -c f | xargs -I {} lxc image delete {}
	cd metal/lxc/beholder-1 && terraform destroy

bootstrap-production:
	@echo "Bootstrapping k3s on production"
	bash metal/bootstrap.sh 10.0.0.21 10.0.0.20 10.0.0.22 10.0.0.23

bootstrap-staging:
	@echo "Bootstrapping k3s on production"
	bash metal/bootstrap.sh 10.0.0.31 10.0.0.30 10.0.0.32 10.0.0.33

SYSTEM_APPS = cert-manager kube-vip metallb

helm:
	helm upgrade --install $(app) ./$(type)/$(app) --namespace $(app) --create-namespace -f ./$(type)/$(app)/values.yaml
