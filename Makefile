# Helper targets to deploy the Alloy + Pyroscope overlay by hand
# Usage:
#   make deploy GRAFANA_CLOUD_USER=986364 GRAFANA_CLOUD_API_KEY=glc_... \
#     PYROSCOPE_REMOTE_WRITE=https://profiles-prod-001.grafana.net \
#     PROM_REMOTE_WRITE=https://prometheus-prod-24-prod-us-east-0.grafana.net/api/prom/push

OVERLAY ?= kustomize/overlays/alvaronicolas-profiles
GRAFANA_CLOUD_USER ?=
GRAFANA_CLOUD_API_KEY ?=
PYROSCOPE_REMOTE_WRITE ?= https://profiles-prod-001.grafana.net
PROM_REMOTE_WRITE ?= https://prometheus-prod-24-prod-us-east-0.grafana.net/api/prom/push

.PHONY: deploy destroy secret-env logs

secret-env:
	@test -n "$(GRAFANA_CLOUD_USER)" || (echo "GRAFANA_CLOUD_USER requerido" && exit 1)
	@test -n "$(GRAFANA_CLOUD_API_KEY)" || (echo "GRAFANA_CLOUD_API_KEY requerido" && exit 1)
	@echo "Escribiendo $(OVERLAY)/secret.env"
	@cat > $(OVERLAY)/secret.env <<EOF_SECRET
GRAFANA_CLOUD_USER=$(GRAFANA_CLOUD_USER)
GRAFANA_CLOUD_API_KEY=$(GRAFANA_CLOUD_API_KEY)
PYROSCOPE_REMOTE_WRITE=$(PYROSCOPE_REMOTE_WRITE)
PROM_REMOTE_WRITE=$(PROM_REMOTE_WRITE)
EOF_SECRET

# Aplica el overlay seleccionado (default: alvaronicolas-profiles)
# Requiere kubeconfig apuntando al clúster GKE
deploy: secret-env
	kustomize build $(OVERLAY) | kubectl apply -f -

# Elimina los recursos del overlay sin fallar si ya fueron borrados
.destroy-raw:
	kustomize build $(OVERLAY) | kubectl delete -f -

destroy:
	$(MAKE) -s .destroy-raw || true

# Muestra logs recientes de Alloy para comprobar que envía perfiles
logs:
	kubectl logs -n observability -l app.kubernetes.io/name=alloy --tail=200
