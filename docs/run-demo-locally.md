# Cómo probar la demo en tu máquina (GKE + Grafana Cloud)

Esta guía resume el flujo mínimo para validar en local (Cloud Shell o tu laptop) que Grafana Alloy despliega en GKE y envía perfiles a tu stack de Grafana Cloud.

## 1. Prerrequisitos rápidos
- CLI instaladas: `gcloud`, `kubectl`, `kustomize`, `make`. Opcional: `terraform` si quieres crear el clúster desde cero.
- Acceso a un proyecto de Google Cloud con permisos para usar GKE.
- Credenciales de Grafana Cloud (usuario/stack ID y API key) y endpoints de Pyroscope/Prometheus.

## 2. Configura el contexto de kubeconfig
Si ya tienes un clúster GKE listo (propio o creado con `terraform apply` del directorio `terraform/`):
```bash
gcloud auth login
gcloud container clusters get-credentials "$GKE_CLUSTER" \
  --region "$GKE_LOCATION" \
  --project "$GCP_PROJECT_ID"
```

## 3. Despliega Alloy + Pyroscope con el overlay del stack
En el root del repo, exporta tus credenciales y usa el `Makefile`:
```bash
export GRAFANA_CLOUD_USER=986364 # usa tu ID real
export GRAFANA_CLOUD_API_KEY="glc_..." # token de Grafana.com
export PYROSCOPE_REMOTE_WRITE=https://profiles-prod-001.grafana.net
export PROM_REMOTE_WRITE=https://prometheus-prod-24-prod-us-east-0.grafana.net/api/prom/push
make deploy
```
Esto genera `kustomize/overlays/alvaronicolas-profiles/secret.env` y aplica el DaemonSet de Alloy en `observability`.

## 4. Revisa que Alloy esté corriendo y enviando datos
```bash
kubectl get pods -n observability -l app.kubernetes.io/name=alloy
kubectl logs -n observability -l app.kubernetes.io/name=alloy --tail=50
```
Los logs deberían mostrar envíos exitosos a `pyroscope.write` y `prometheus.remote_write`.

## 5. Anota un workload para generar perfiles
Con un Deployment existente que expone pprof (ej. agente Java en 4040):
```bash
kubectl annotate deploy demo-java \
  pyroscope.grafana.com/scrape=true \
  pyroscope.grafana.com/application_name=demo-java \
  pyroscope.grafana.com/port=4040 --overwrite
```
En segundos deberías ver la app `demo-java` en Grafana Cloud > Pyroscope. Usa Grafana Assistant sobre el flame graph para validar que la integración funciona.

## 6. Limpieza rápida
```bash
make destroy
```

## Problemas comunes
- **Auth de GCP/WIF:** si el pipeline falla, confirma que el clúster tiene Workload Identity y que las variables `GCP_PROJECT_ID`, `GKE_CLUSTER`, `GKE_LOCATION` están definidas.
- **Credenciales de Grafana Cloud:** revisa que `GRAFANA_CLOUD_API_KEY` tenga permisos sobre Pyroscope y que los endpoints correspondan a la región de tu stack.
- **Anotaciones ausentes:** sin `pyroscope.grafana.com/scrape=true` no se descubren pods; añade también `pyroscope.grafana.com/port` si el agente no usa 4040.
