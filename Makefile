# ==============================================================================
# Makefile - Pyroscope Demo Cloud Summit LATAM 2025
# ==============================================================================
# Usage:
#   make deploy GRAFANA_CLOUD_USER=986364 GRAFANA_CLOUD_API_KEY=glc_...
#   make logs
#   make load-cpu
# ==============================================================================

# Configuration
OVERLAY ?= kustomize/overlays/alvaronicolas-profiles
NAMESPACE_ALLOY ?= observability
NAMESPACE_APP ?= default

# Grafana Cloud credentials (override via command line or environment)
GRAFANA_CLOUD_USER ?=
GRAFANA_CLOUD_API_KEY ?=
PYROSCOPE_REMOTE_WRITE ?= https://profiles-prod-001.grafana.net
PROM_REMOTE_WRITE ?= https://prometheus-prod-24-prod-us-east-0.grafana.net/api/prom/push

.PHONY: help deploy destroy logs status load-cpu load-memory port-forward secret-env

# ==============================================================================
# Help
# ==============================================================================
help:
	@echo "Available targets:"
	@echo "  deploy          - Deploy Alloy + observability stack"
	@echo "  destroy         - Remove all resources"
	@echo "  logs            - Show Alloy logs"
	@echo "  logs-java       - Show logs filtered for Java profiling"
	@echo "  status          - Show pods status"
	@echo "  load-cpu        - Generate CPU load on demo app"
	@echo "  load-memory     - Generate memory allocations on demo app"
	@echo "  port-forward    - Port forward demo app to localhost:8080"
	@echo "  alloy-ui        - Port forward Alloy UI to localhost:12345"

# ==============================================================================
# Secrets
# ==============================================================================
secret-env:
	@test -n "$(GRAFANA_CLOUD_USER)" || (echo "❌ GRAFANA_CLOUD_USER required" && exit 1)
	@test -n "$(GRAFANA_CLOUD_API_KEY)" || (echo "❌ GRAFANA_CLOUD_API_KEY required" && exit 1)
	@echo "📝 Writing $(OVERLAY)/secret.env"
	@echo "GRAFANA_CLOUD_USER=$(GRAFANA_CLOUD_USER)" > $(OVERLAY)/secret.env
	@echo "GRAFANA_CLOUD_API_KEY=$(GRAFANA_CLOUD_API_KEY)" >> $(OVERLAY)/secret.env
	@echo "PYROSCOPE_REMOTE_WRITE=$(PYROSCOPE_REMOTE_WRITE)" >> $(OVERLAY)/secret.env
	@echo "PROM_REMOTE_WRITE=$(PROM_REMOTE_WRITE)" >> $(OVERLAY)/secret.env

# ==============================================================================
# Deploy / Destroy
# ==============================================================================
deploy: secret-env
	@echo "🚀 Deploying Alloy stack..."
	kustomize build $(OVERLAY) | kubectl apply -f -
	@echo "✅ Deploy complete"

deploy-demo-app:
	@echo "☕ Deploying Java demo app..."
	kubectl apply -f demo-app/k8s/deployment.yaml
	kubectl rollout status deployment/java-demo-app -n $(NAMESPACE_APP)
	@echo "✅ Demo app deployed"

.destroy-raw:
	kustomize build $(OVERLAY) | kubectl delete -f -

destroy:
	@echo "🗑️  Destroying resources..."
	$(MAKE) -s .destroy-raw || true
	@echo "✅ Destroy complete"

# ==============================================================================
# Monitoring / Debugging
# ==============================================================================
logs:
	kubectl logs -n $(NAMESPACE_ALLOY) -l app.kubernetes.io/name=alloy -c alloy --tail=100 -f

logs-java:
	kubectl logs -n $(NAMESPACE_ALLOY) -l app.kubernetes.io/name=alloy -c alloy --tail=200 | grep -E "(java|profil|pushed|error)" -i

status:
	@echo "=== Alloy Pods ==="
	kubectl get pods -n $(NAMESPACE_ALLOY) -o wide
	@echo ""
	@echo "=== Demo App Pods ==="
	kubectl get pods -n $(NAMESPACE_APP) -l app=java-demo-app -o wide

alloy-ui:
	@echo "🌐 Opening Alloy UI at http://localhost:12345"
	kubectl port-forward -n $(NAMESPACE_ALLOY) svc/alloy 12345:12345

# ==============================================================================
# Load Generation (for demo)
# ==============================================================================
port-forward:
	@echo "🔌 Port forwarding demo app to localhost:8080..."
	kubectl port-forward svc/java-demo-app 8080:80

load-cpu:
	@echo "🔥 Generating CPU load..."
	@for i in 1 2 3 4 5; do \
		curl -s "http://localhost:8080/cpu-sync?iterations=2000000" & \
	done; wait
	@echo "✅ CPU load complete"

load-memory:
	@echo "💾 Generating memory allocations..."
	@for i in 1 2 3 4 5; do \
		curl -s "http://localhost:8080/memory?size=10000" & \
	done; wait
	@echo "✅ Memory load complete"

# ==============================================================================
# Terraform (Infrastructure)
# ==============================================================================
tf-init:
	cd terraform && terraform init

tf-plan:
	cd terraform && terraform plan

tf-apply:
	cd terraform && terraform apply

tf-destroy:
	cd terraform && terraform destroy
