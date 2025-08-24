SHELL := /bin/bash
CLUSTER_NAME := local-platform
NS := platform

.PHONY: up down cluster ingress tls platform gitea registry jenkins status

up: cluster ingress tls platform status ## Create cluster + ingress + TLS + deploy platform

cluster: ## Create kind cluster
	kind create cluster --name $(CLUSTER_NAME) --config infra/cluster/kind-config.yaml
	kubectl get nodes

ingress: ## Install ingress-nginx via Helm
	helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
	helm repo update
	helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
	  --namespace ingress-nginx --create-namespace \
	  -f infra/ingress/values-nginx.yaml
	kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller

# Create wildcard TLS cert for *.local.test using mkcert and store as platform-tls secret
# Requires mkcert installed and root CA trusted locally.
tls:
	mkdir -p infra/ingress/tls
	cd infra/ingress/tls && mkcert -install && mkcert "*.local.test" local.test
	kubectl apply -f infra/platform/namespace.yaml
	kubectl -n $(NS) delete secret platform-tls >/dev/null 2>&1 || true
	kubectl -n $(NS) create secret tls platform-tls \
	  --cert=infra/ingress/tls/_wildcard.local.test+1.pem \
	  --key=infra/ingress/tls/_wildcard.local.test+1-key.pem

platform: gitea registry jenkins ## Deploy platform apps (Gitea, Registry, Jenkins)

gitea:
	kubectl apply -f infra/platform/namespace.yaml
	kubectl apply -f infra/platform/gitea/pvc.yaml
	kubectl apply -f infra/platform/gitea/secret-env.yaml
	kubectl apply -f infra/platform/gitea/cm-appini.yaml
	kubectl apply -f infra/platform/gitea/deployment.yaml
	kubectl apply -f infra/platform/gitea/service.yaml
	kubectl apply -f infra/platform/gitea/ingress.yaml
	kubectl apply -f infra/platform/gitea/init-admin-job.yaml || true
	kubectl -n $(NS) rollout status deploy/gitea

registry:
	kubectl apply -f infra/platform/registry/pvc.yaml
	kubectl apply -f infra/platform/registry/deployment.yaml
	kubectl apply -f infra/platform/registry/service.yaml
	kubectl apply -f infra/platform/registry/ingress.yaml
	kubectl -n $(NS) rollout status deploy/registry

jenkins:
	kubectl apply -f infra/platform/jenkins/pvc.yaml
	kubectl apply -f infra/platform/jenkins/secret-admin.yaml
	kubectl apply -f infra/platform/jenkins/casc-configmap.yaml
	kubectl apply -f infra/platform/jenkins/deployment.yaml
	kubectl apply -f infra/platform/jenkins/service.yaml
	kubectl apply -f infra/platform/jenkins/ingress.yaml
	kubectl -n $(NS) rollout status deploy/jenkins

status:
	@echo "\nEndpoints:" \
	&& echo "  Gitea:    https://gitea.local.test" \
	&& echo "  Registry: https://registry.local.test" \
	&& echo "  Jenkins:  https://jenkins.local.test" \
	&& echo "\nIf hosts don't resolve, add to /etc/hosts: 127.0.0.1 gitea.local.test registry.local.test jenkins.local.test" \
	&& echo "\nJenkins admin: admin / admin123 (change in secret-admin.yaml)"

clean:
	kind delete cluster --name $(CLUSTER_NAME) || true
	@echo "Cluster removed."