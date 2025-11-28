# Demo Pyroscope Cloud Summit LATAM

Assets para la charla *Profiling + IA: el nuevo pilar de la observabilidad* (29 de noviembre, 45 minutos). Muestran cómo activar profiling continuo en Kubernetes usando Grafana Alloy + Pyroscope y cómo aprovechar Grafana Assistant para interpretar flame graphs con IA.

## Qué incluye
- **Manifiestos de Kubernetes (kustomize/base):** DaemonSet de Grafana Alloy, ConfigMap con el pipeline River, RBAC y Secret para credenciales de Grafana Cloud.
- **Flujo de datos:** Los pods anotados con `pyroscope.grafana.com/scrape=true` exponen perfiles pprof en el puerto indicado; Alloy los descubre y los envía a Grafana Cloud (Pyroscope y Prometheus remote write).
- **Guía de demo:** Pasos para preparar el laboratorio en Google Cloud y validar que el profiling está llegando a Grafana Cloud.

## Requisitos previos
- Clúster Kubernetes en Google Cloud (GKE o Autopilot) con `kubectl` configurado.
- Organización y stack de Grafana Cloud con endpoints de Prometheus y Pyroscope (URLs y `User/API key`).
- Workloads Java con el agente de Pyroscope habilitado y escuchando en el puerto 4040 (o el que definas en las anotaciones del pod).

## Infra mínima en Google Cloud con Terraform (GKE de 1 nodo)
1. Revisa y ajusta los valores en `terraform/terraform.tfvars.example` (ID de proyecto, región, nombre del clúster, tipo de máquina).
2. Inicializa y despliega el clúster de prueba (crea un pool preemptible de 1 nodo para la demo):
   ```bash
   cd terraform
   terraform init
   terraform apply -var-file=terraform.tfvars.example
   ```
3. Carga las credenciales de kubeconfig que devuelve la salida `get_credentials` y vuelve al raíz del repo para aplicar Kustomize.

> El clúster se crea con Workload Identity habilitado para que el pipeline de GitHub Actions pueda autenticarse sin llaves largas.

## Despliegue rápido (kustomize/base)
1. Clona el repositorio y usa la rama activa como `main` si tu clone lo requiere:
   ```bash
   git clone https://github.com/alvarowops/Demo-pyroscope-cloudsummitlatam.git
   cd Demo-pyroscope-cloudsummitlatam
   git branch -M main
   ```
2. Actualiza el Secret con tus credenciales y endpoints de Grafana Cloud (`kustomize/base/grafana-cloud-secret.yaml`). Sustituye los placeholders `<grafana-cloud-username>` y `<grafana-cloud-api-key>` y ajusta los endpoints si tu stack usa otra región.
3. Aplica los manifiestos base en el clúster (namespace `observability`):
   ```bash
   kubectl apply -k kustomize/base
   ```
   - Si usas el stack **alvaronicolas-profiles** (US-East, `profiles-prod-001.grafana.net`), copia el overlay dedicado y evita cometer secretos:
     ```bash
     cp kustomize/overlays/alvaronicolas-profiles/secret.env.example kustomize/overlays/alvaronicolas-profiles/secret.env
     # Rellena GRAFANA_CLOUD_API_KEY con el token de Grafana.com y opcionalmente ajusta PROM_REMOTE_WRITE
     kubectl apply -k kustomize/overlays/alvaronicolas-profiles
     ```
4. Verifica que Alloy esté corriendo en cada nodo:
   ```bash
   kubectl get pods -n observability -l app.kubernetes.io/name=alloy
   kubectl logs -n observability -l app.kubernetes.io/name=alloy --tail=50
   ```
5. Anota los pods que quieras perfilar. Ejemplo para un Deployment Java con el agente Pyroscope escuchando en 4040:
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: demo-java
   spec:
     template:
       metadata:
         annotations:
           pyroscope.grafana.com/scrape: "true"
           pyroscope.grafana.com/application_name: "demo-java"
           pyroscope.grafana.com/port: "4040"
   ```
6. Revisa en tu stack de Grafana Cloud -> Pyroscope que aparezca la app `demo-java` y valida flame graphs. Grafana Assistant puede sugerir optimizaciones sobre esos perfiles.

## Detalle de los componentes
- **`alloy-configmap.yaml`:** Define el pipeline River para descubrir pods con anotación `pyroscope.grafana.com/scrape=true`, re-etiquetar el puerto de profiling, propagar `namespace` y `pod` como labels y hacer `pyroscope.write` a Grafana Cloud. Además expone métricas del propio Alloy vía `prometheus.remote_write`.
- **`alloy-daemonset.yaml`:** Ejecuta Alloy en modo DaemonSet, monta el ConfigMap y lee las credenciales desde el Secret `grafana-cloud`.
- **`grafana-cloud-secret.yaml`:** Plantilla de Secret con los endpoints de Pyroscope y Prometheus remote write de Grafana Cloud. Cámbialo por valores reales antes de aplicar.
- **`rbac.yaml` y `serviceaccount.yaml`:** Permisos mínimos para descubrir pods, services y namespaces.

## Tips para la demo en vivo
- Usa workloads de carga (p.ej., un generador de CPU) para que los flame graphs muestren hotspots claros.
- Muestra la etiqueta `service_name` en Pyroscope; proviene de la anotación `pyroscope.grafana.com/application_name`.
- Si cambias el puerto del agente Java, ajusta la anotación `pyroscope.grafana.com/port` para que el relabeling reescriba `__address__` correctamente.
- Mantén abierta la vista de Grafana Assistant para pedir resúmenes en español y recomendaciones de optimización sobre el flame graph activo.

## Pipeline CI/CD (GitHub Actions ➜ GKE ➜ Grafana Cloud)
- Workflow: `.github/workflows/deploy.yaml`.
- Autenticación: Workload Identity Federation (`secrets.GCP_WORKLOAD_IDENTITY_PROVIDER` + `secrets.GCP_SERVICE_ACCOUNT`), sin llaves en claro.
- Variables de repositorio requeridas (`Settings > Variables`):
  - `GCP_PROJECT_ID`, `GKE_CLUSTER`, `GKE_LOCATION`
  - `GRAFANA_CLOUD_USER` (por ejemplo `986364` para `alvaronicolas-profiles`)
- Secret requerido (`Settings > Secrets and variables > Actions`):
  - `GRAFANA_CLOUD_API_KEY` (token de Grafana.com con permisos de Pyroscope)
- Flujo de despliegue:
  1. `kubectl`/`kustomize` se instalan en el runner.
  2. `gcloud container clusters get-credentials` usa las variables anteriores.
  3. Se genera `kustomize/overlays/alvaronicolas-profiles/secret.env` con las credenciales del stack.
  4. `kustomize build ... | kubectl apply -f -` aplica el DaemonSet de Alloy y el Secret para Grafana Cloud.

> El workflow corre en pushes a `main` o manualmente (`workflow_dispatch`). Puedes cambiar el overlay o namespace modificando el archivo de workflow.

## Limpieza
```bash
kubectl delete -k kustomize/base
```

## Contribuir
Mejoras y PRs son bienvenidos. Asegura que las ramas se publiquen en `main` para evitar errores de referencia.
