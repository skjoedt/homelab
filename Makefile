.PHONY: *
.EXPORT_ALL_VARIABLES:

BRANCH_NAME := $(shell git rev-parse --abbrev-ref HEAD)
BRANCH_NAME_SLUG := $(subst /,-,$(BRANCH_NAME))
REGISTRY_PORT := $(shell echo $(BRANCH_NAME) | cksum | cut -d ' ' -f1 | awk '{print 5000 + ($$1 % 1000)}')
TARGET_REVISION ?= main
ARGOCD_NAMESPACE ?= argocd
ARGOCD_ROOT ?= ./system/argocd/production

git-hooks:
	pre-commit install

check-deps:
	@which kubectl >/dev/null || (echo "kubectl is required but not installed" && exit 1)
	@which k3d >/dev/null || (echo "k3d is required but not installed" && exit 1)

check-mkcert:
	@which mkcert >/dev/null || (echo "mkcert is required but not installed" && exit 1)

dev: dev-up dev-prepare

dev-up: check-deps
	@if ! k3d cluster list | grep -q "$(BRANCH_NAME_SLUG)"; then \
		k3d cluster create $(BRANCH_NAME_SLUG) \
		    --image rancher/k3s:v1.31.5-k3s1 \
		    --k3s-arg "--disable=traefik@server:*" \
			--servers 1 \
			--agents 0 \
			-p "80:80@loadbalancer" \
			-p "443:443@loadbalancer" \
			-p "853:853/tcp@loadbalancer" \
			--registry-create $(BRANCH_NAME_SLUG)-registry:127.0.0.1:$(REGISTRY_PORT) \
			--wait; \
	fi
	@kubectl config use-context k3d-$(BRANCH_NAME_SLUG)

dev-prepare: check-deps check-mkcert
	@kubectl config use-context k3d-$(BRANCH_NAME_SLUG)
	@echo "Installing CRDs..."
	kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml
	helm upgrade --install --dependency-update external-secrets ./controllers/external-secrets/external-secrets --namespace external-secrets --create-namespace -f ./controllers/external-secrets/external-secrets/values.yaml
	helm upgrade --install --dependency-update traefik ./controllers/traefik/traefik --namespace traefik --create-namespace -f ./controllers/traefik/traefik/values-dev.yaml
	@mkdir -p .local/certs
	mkcert -cert-file .local/certs/localho.st.pem -key-file .local/certs/localho.st-key.pem localho.st "*.localho.st"
	kubectl -n traefik create secret tls localho-st-tls --cert=.local/certs/localho.st.pem --key=.local/certs/localho.st-key.pem --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install --dependency-update kube-prometheus-stack ./controllers/monitoring/kube-prometheus-stack --namespace monitoring --create-namespace -f ./controllers/monitoring/kube-prometheus-stack/values.yaml
	helm upgrade --install --dependency-update grafana ./controllers/monitoring/grafana --namespace monitoring --create-namespace -f ./controllers/monitoring/grafana/values.yaml
	helm upgrade --install --dependency-update loki ./controllers/monitoring/loki --namespace monitoring --create-namespace -f ./controllers/monitoring/loki/values.yaml
	helm upgrade --install --dependency-update alloy ./controllers/monitoring/alloy --namespace monitoring --create-namespace -f ./controllers/monitoring/alloy/values.yaml
	helm upgrade --install --dependency-update cert-manager ./controllers/cert-manager/cert-manager --namespace cert-manager --create-namespace -f ./controllers/cert-manager/cert-manager/values.yaml
	helm upgrade --install --dependency-update cnpg ./controllers/cnpg-system/cnpg --namespace cnpg-system --create-namespace -f ./controllers/cnpg-system/cnpg/values.yaml
	helm upgrade --install --dependency-update cnpg-barman-plugin ./controllers/cnpg-system/cnpg-barman-plugin --namespace cnpg-system --create-namespace -f ./controllers/cnpg-system/cnpg-barman-plugin/values.yaml
	helm upgrade --install --dependency-update reflector ./controllers/reflector/reflector --namespace reflector --create-namespace -f ./controllers/reflector/reflector/values.yaml
	kubectl apply -k ./monitoring/configs/base
	kubectl apply -k ./system/configs/base

dev-down:
	@echo "Deleting k3d cluster: $(BRANCH_NAME_SLUG)..."
	@k3d cluster delete $(BRANCH_NAME_SLUG)
	@echo "Cluster deleted"

bootstrap-production:
	@echo "Bootstrapping k3s on production"
	bash terraform/lxc/bootstrap.sh 10.0.0.21 10.0.0.20 10.0.0.22 10.0.0.23

argocd-bootstrap-production:
	kubectl create namespace external-secrets --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install --dependency-update argocd ./controllers/argocd/argocd --namespace $(ARGOCD_NAMESPACE) --create-namespace -f ./controllers/argocd/argocd/values.yaml --wait --timeout 10m
	kubectl wait --for=condition=established --timeout=120s crd/applications.argoproj.io crd/applicationsets.argoproj.io crd/appprojects.argoproj.io
	@if [ "$(TARGET_REVISION)" = "main" ]; then \
		kubectl apply -k $(ARGOCD_ROOT); \
	else \
		TARGET_REVISION="$(TARGET_REVISION)" kubectl kustomize $(ARGOCD_ROOT) | perl -pe 's/(targetRevision|revision): main/$$1: $$ENV{TARGET_REVISION}/g' | kubectl apply -f -; \
	fi
	@echo "ArgoCD is bootstrapped with target revision $(TARGET_REVISION)"

prepare-production: argocd-bootstrap-production

argocd-render-production:
	@if [ "$(TARGET_REVISION)" = "main" ]; then \
		kubectl kustomize $(ARGOCD_ROOT); \
	else \
		TARGET_REVISION="$(TARGET_REVISION)" kubectl kustomize $(ARGOCD_ROOT) | perl -pe 's/(targetRevision|revision): main/$$1: $$ENV{TARGET_REVISION}/g'; \
	fi

argocd-status-production:
	kubectl -n $(ARGOCD_NAMESPACE) get applications.argoproj.io,applicationsets.argoproj.io

argocd-test-branch: TARGET_REVISION = $(BRANCH_NAME)
argocd-test-branch: dev-up argocd-bootstrap-production argocd-status-production
