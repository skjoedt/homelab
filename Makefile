.POSIX:
.PHONY: *
.EXPORT_ALL_VARIABLES:

# Variables
BRANCH_NAME := $(shell git rev-parse --abbrev-ref HEAD)
BRANCH_NAME_SLUG := $(subst /,-,$(BRANCH_NAME))
CLUSTER_NAME := k3d-flux-$(BRANCH_NAME_SLUG)
FLUX_NAMESPACE ?= flux-system
LOCAL_PATH := $(shell pwd)
REGISTRY_PORT := $(shell echo $(BRANCH_NAME) | cksum | cut -d ' ' -f1 | awk '{print 5000 + ($$1 % 1000)}') # Hash the branch name to a number between 5000-5999
PRIVATE_KEY_FILE := ${HOME}/.ssh/id_rsa

.PHONY: all

git-hooks:
	pre-commit install

# Check for required tools
check-deps:
	@which kubectl >/dev/null || (echo "kubectl is required but not installed" && exit 1)
	@which flux >/dev/null || (echo "flux cli is required but not installed" && exit 1)
	@which k3d >/dev/null || (echo "k3d is required but not installed" && exit 1)

# Create k3d cluster with branch-specific name
dev-up: check-deps
	@if ! k3d cluster list | grep -q "$(CLUSTER_NAME)"; then \
		k3d cluster create $(CLUSTER_NAME) \
		    --k3s-arg "--disable=traefik@server:*" \
			--servers 1 \
			--agents 0 \
			-p "80:80@loadbalancer" \
			-p "443:443@loadbalancer" \
			--registry-create $(CLUSTER_NAME)-registry:127.0.0.1:$(REGISTRY_PORT) \
			--wait; \
	fi
	@kubectl config use-context k3d-$(CLUSTER_NAME)

# Delete the k3d cluster
dev-down:
	@echo "Deleting k3d cluster: $(CLUSTER_NAME)..."
	@k3d cluster delete $(CLUSTER_NAME)
	@echo "Cluster deleted"


# Install CRDs
dev-prepare:
	@echo "Installing CRDs to $(CLUSTER_NAME)..."
	#@kubectl apply -f "https://raw.githubusercontent.com/external-secrets/external-secrets/v0.14.1/deploy/crds/bundle.yaml"
	helm repo add external-secrets https://charts.external-secrets.io
	helm repo add traefik https://helm.traefik.io/traefik
	helm repo update
	helm install external-secrets \
		external-secrets/external-secrets \
		--namespace external-secrets \
		--create-namespace \
		--version v0.14.1 \
		-f infrastructure/controllers/base/external-secrets/values.yaml
	helm install traefik \
		traefik/traefik \
		--namespace traefik \
		--create-namespace \
		--version 34.1.0 \
		-f infrastructure/controllers/base/traefik/values.yaml \
		--set="additionalArguments={--api.insecure}"

dev: dev-up dev-prepare

testing:
	@echo "Deploying testing environment"
	@kubectl kustomize clusters/testing | kubectl apply -f -

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

# Install Flux in against branch
flux-up:
	@echo "Installing Flux in current k8s context"
	kubectl config use-context homelab
	flux install \
		--namespace=$(FLUX_NAMESPACE) \

	@echo "Creating secret for github auth"
	flux create secret git homelab-auth \
		--url='ssh://git@github.com/skjoedt/homelab' \
		--private-key-file=$(PRIVATE_KEY_FILE) 2> /dev/null

	@echo "Creating source for homelab..."
	flux create source git flux-system \
		--url='ssh://git@github.com/skjoedt/homelab' \
		--branch=$(BRANCH_NAME) \
		--interval=100m \
		--timeout=5s \
		--namespace=$(FLUX_NAMESPACE) \
		--secret-ref=homelab-auth \
		--silent

	flux create kustomization staging \
		--source=GitRepository/flux-system \
		--path=./clusters/staging \
		--prune \
		--interval=100m \
		--timeout=5s \
		--namespace=$(FLUX_NAMESPACE)
	@echo "Flux bootstrap complete for cluster: $(CLUSTER_NAME)"

sync:
	@echo "Reconciling flux from remote $(BRANCH_NAME)"
	flux reconcile kustomization staging --with-source

flux-error:
	@echo "Displaying flux kustomization errors"
	flux logs --level=error --kind=Kustomization

# Remove Flux from cluster
flux-down:
	@echo "Uninstalling Flux from $(CLUSTER_NAME)..."
	flux uninstall --namespace=$(FLUX_NAMESPACE) --silent

# Show current configuration
show-config:
	@echo "Current configuration:"
	@echo "Branch name: $(BRANCH_NAME)"
	@echo "Cluster name: $(CLUSTER_NAME)"
	@echo "Flux namespace: $(FLUX_NAMESPACE)"
	@echo "Local path: $(LOCAL_PATH)"
	@echo "Private key: $(PRIVATE_KEY_FILE)"
