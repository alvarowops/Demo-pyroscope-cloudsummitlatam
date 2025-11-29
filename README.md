# 🔥 Continuous Profiling con Grafana Pyroscope + Alloy# Demo Pyroscope Cloud Summit LATAM



> Demo para **Cloud Summit LATAM 2025** - Charla: "Profiling + IA"Assets para la charla *Profiling + IA: el nuevo pilar de la observabilidad* (29 de noviembre, 45 minutos). Muestran cómo activar profiling continuo en Kubernetes usando Grafana Alloy + Pyroscope y cómo aprovechar Grafana Assistant para interpretar flame graphs con IA.



Este repositorio contiene una implementación completa de **Continuous Profiling** para aplicaciones Java usando **Grafana Alloy** con **async-profiler** (auto-instrumentación) enviando datos a **Grafana Cloud Pyroscope**.## Qué incluye

- **Manifiestos de Kubernetes (kustomize/base):** DaemonSet de Grafana Alloy, ConfigMap con el pipeline River, RBAC y Secret para credenciales de Grafana Cloud.

![Pyroscope Flame Graph](https://grafana.com/media/docs/pyroscope/pyroscope-ui-single-background.png)- **Flujo de datos:** Los pods anotados con `pyroscope.grafana.com/scrape=true` exponen perfiles pprof en el puerto indicado; Alloy los descubre y los envía a Grafana Cloud (Pyroscope y Prometheus remote write).

- **Guía de demo:** Pasos para preparar el laboratorio en Google Cloud y validar que el profiling está llegando a Grafana Cloud.

## 📋 Tabla de Contenidos

## Requisitos previos

- [Arquitectura](#-arquitectura)- Clúster Kubernetes en Google Cloud (GKE o Autopilot) con `kubectl` configurado.

- [Componentes](#-componentes)- Organización y stack de Grafana Cloud con endpoints de Prometheus y Pyroscope (URLs y `User/API key`).

- [Requisitos Previos](#-requisitos-previos)- Workloads Java con el agente de Pyroscope habilitado y escuchando en el puerto 4040 (o el que definas en las anotaciones del pod).

- [Despliegue Rápido](#-despliegue-rápido)

- [Estructura del Proyecto](#-estructura-del-proyecto)## Infra mínima en Google Cloud con Terraform (GKE de 1 nodo)

- [Configuración de Secrets](#-configuración-de-secrets)1. Revisa y ajusta los valores en `terraform/terraform.tfvars.example` (ID de proyecto, región, nombre del clúster, tipo de máquina).

- [Pipelines CI/CD](#-pipelines-cicd)2. Inicializa y despliega el clúster de prueba (crea un pool preemptible de 1 nodo para la demo):

- [Demo App](#-demo-app)   ```bash

- [Visualización en Grafana](#-visualización-en-grafana)   cd terraform

- [Troubleshooting](#-troubleshooting)   terraform init

   terraform apply -var-file=terraform.tfvars.example

## 🏗 Arquitectura   ```

3. Carga las credenciales de kubeconfig que devuelve la salida `get_credentials` y vuelve al raíz del repo para aplicar Kustomize.

```

┌─────────────────────────────────────────────────────────────────┐> El clúster se crea con Workload Identity habilitado para que el pipeline de GitHub Actions pueda autenticarse sin llaves largas.

│                         GKE Cluster                              │

│  ┌─────────────────┐    ┌─────────────────┐                     │## Despliegue rápido (kustomize/base)

│  │   Java App      │    │   Java App      │                     │1. Clona el repositorio y usa la rama activa como `main` si tu clone lo requiere:

│  │   (Pod)         │    │   (Pod)         │                     │   ```bash

│  │                 │    │                 │                     │   git clone https://github.com/alvarowops/Demo-pyroscope-cloudsummitlatam.git

│  └────────┬────────┘    └────────┬────────┘                     │   cd Demo-pyroscope-cloudsummitlatam

│           │                      │                               │   git branch -M main

│           │   async-profiler     │                               │   ```

│           │   (attach)           │                               │2. Actualiza el Secret con tus credenciales y endpoints de Grafana Cloud (`kustomize/base/grafana-cloud-secret.yaml`). Sustituye los placeholders `<grafana-cloud-username>` y `<grafana-cloud-api-key>` y ajusta los endpoints si tu stack usa otra región.

│           ▼                      ▼                               │3. Aplica los manifiestos base en el clúster (namespace `observability`):

│  ┌──────────────────────────────────────────┐                   │   ```bash

│  │         Grafana Alloy (DaemonSet)         │                   │   kubectl apply -k kustomize/base

│  │  ┌─────────────────────────────────────┐  │                   │   ```

│  │  │  discovery.kubernetes               │  │                   │   - Si usas el stack **alvaronicolas-profiles** (US-East, `profiles-prod-001.grafana.net`), copia el overlay dedicado y evita cometer secretos:

│  │  │  discovery.process                  │  │                   │     ```bash

│  │  │  pyroscope.java (async-profiler)    │  │                   │     cp kustomize/overlays/alvaronicolas-profiles/secret.env.example kustomize/overlays/alvaronicolas-profiles/secret.env

│  │  │  pyroscope.write                    │  │                   │     # Rellena GRAFANA_CLOUD_API_KEY con el token de Grafana.com y opcionalmente ajusta PROM_REMOTE_WRITE

│  │  └─────────────────────────────────────┘  │                   │     kubectl apply -k kustomize/overlays/alvaronicolas-profiles

│  └──────────────────────┬───────────────────┘                   │     ```

│                         │                                        │4. Verifica que Alloy esté corriendo en cada nodo:

└─────────────────────────┼────────────────────────────────────────┘   ```bash

                          │ HTTPS   kubectl get pods -n observability -l app.kubernetes.io/name=alloy

                          ▼   kubectl logs -n observability -l app.kubernetes.io/name=alloy --tail=50

              ┌───────────────────────┐   ```

              │   Grafana Cloud       │5. Anota los pods que quieras perfilar. Ejemplo para un Deployment Java con el agente Pyroscope escuchando en 4040:

              │  ┌─────────────────┐  │   ```yaml

              │  │    Pyroscope    │  │   apiVersion: apps/v1

              │  │  (Profiles DB)  │  │   kind: Deployment

              │  └─────────────────┘  │   metadata:

              │  ┌─────────────────┐  │     name: demo-java

              │  │    Grafana UI   │  │   spec:

              │  │  (Flame Graphs) │  │     template:

              │  └─────────────────┘  │       metadata:

              └───────────────────────┘         annotations:

```           pyroscope.grafana.com/scrape: "true"

           pyroscope.grafana.com/application_name: "demo-java"

## 🧩 Componentes           pyroscope.grafana.com/port: "4040"

   ```

| Componente | Descripción |6. Revisa en tu stack de Grafana Cloud -> Pyroscope que aparezca la app `demo-java` y valida flame graphs. Grafana Assistant puede sugerir optimizaciones sobre esos perfiles.

|------------|-------------|

| **Grafana Alloy** | Agente de observabilidad que recolecta profiles usando async-profiler |## Detalle de los componentes

| **async-profiler** | Profiler de bajo overhead para JVM (CPU, memoria, locks) |- **`alloy-configmap.yaml`:** Define el pipeline River para descubrir pods con anotación `pyroscope.grafana.com/scrape=true`, re-etiquetar el puerto de profiling, propagar `namespace` y `pod` como labels y hacer `pyroscope.write` a Grafana Cloud. Además expone métricas del propio Alloy vía `prometheus.remote_write`.

| **Pyroscope** | Backend de almacenamiento y visualización de profiles |- **`alloy-daemonset.yaml`:** Ejecuta Alloy en modo DaemonSet, monta el ConfigMap y lee las credenciales desde el Secret `grafana-cloud`.

| **Java Demo App** | Aplicación Spring Boot para generar carga y demostrar profiling |- **`grafana-cloud-secret.yaml`:** Plantilla de Secret con los endpoints de Pyroscope y Prometheus remote write de Grafana Cloud. Cámbialo por valores reales antes de aplicar.

- **`rbac.yaml` y `serviceaccount.yaml`:** Permisos mínimos para descubrir pods, services y namespaces.

## ✅ Requisitos Previos

## Tips para la demo en vivo

- **Google Cloud Platform** con proyecto habilitado- Usa workloads de carga (p.ej., un generador de CPU) para que los flame graphs muestren hotspots claros.

- **gcloud CLI** instalado y autenticado- Muestra la etiqueta `service_name` en Pyroscope; proviene de la anotación `pyroscope.grafana.com/application_name`.

- **kubectl** configurado- Si cambias el puerto del agente Java, ajusta la anotación `pyroscope.grafana.com/port` para que el relabeling reescriba `__address__` correctamente.

- **Cuenta de Grafana Cloud** (free tier funciona)- Mantén abierta la vista de Grafana Assistant para pedir resúmenes en español y recomendaciones de optimización sobre el flame graph activo.

- **GitHub Secrets** configurados (ver abajo)

## Pipeline CI/CD (GitHub Actions ➜ GKE ➜ Grafana Cloud)

## 🚀 Despliegue Rápido- Workflow: `.github/workflows/deploy.yaml`.

- Autenticación: Workload Identity Federation (`secrets.GCP_WORKLOAD_IDENTITY_PROVIDER` + `secrets.GCP_SERVICE_ACCOUNT`), sin llaves en claro.

### 1. Clonar el repositorio- Variables de repositorio requeridas (`Settings > Variables`):

```bash  - `GCP_PROJECT_ID`, `GKE_CLUSTER`, `GKE_LOCATION`

git clone https://github.com/alvarowops/Demo-pyroscope-cloudsummitlatam.git  - `GRAFANA_CLOUD_USER` (por ejemplo `986364` para `alvaronicolas-profiles`)

cd Demo-pyroscope-cloudsummitlatam- Secret requerido (`Settings > Secrets and variables > Actions`):

```  - `GRAFANA_CLOUD_API_KEY` (token de Grafana.com con permisos de Pyroscope)

- Flujo de despliegue:

### 2. Crear infraestructura con Terraform  1. `kubectl`/`kustomize` se instalan en el runner.

```bash  2. `gcloud container clusters get-credentials` usa las variables anteriores.

cd terraform  3. Se genera `kustomize/overlays/alvaronicolas-profiles/secret.env` con las credenciales del stack.

cp terraform.tfvars.example terraform.tfvars  4. `kustomize build ... | kubectl apply -f -` aplica el DaemonSet de Alloy y el Secret para Grafana Cloud.

# Editar terraform.tfvars con tus valores

terraform init> El workflow corre en pushes a `main` o manualmente (`workflow_dispatch`). Puedes cambiar el overlay o namespace modificando el archivo de workflow.

terraform apply

```## Cómo probar el despliegue a mano (sin esperar al pipeline)

1. Autentícate en Google Cloud y apunta `kubectl` al clúster (usa las salidas de Terraform o tus parámetros reales):

### 3. Configurar kubectl   ```bash

```bash   gcloud auth login

gcloud container clusters get-credentials pyroscope-demo --region us-east1   gcloud container clusters get-credentials $GKE_CLUSTER --region $GKE_LOCATION --project $GCP_PROJECT_ID

```   ```

2. Exporta tus credenciales de Grafana Cloud y ejecuta el target `deploy` del `Makefile`, que genera `secret.env` y aplica el overlay `alvaronicolas-profiles`:

### 4. Desplegar Alloy (via GitHub Actions)   ```bash

El pipeline `deploy.yaml` se ejecuta automáticamente en push a `main`, o manualmente desde GitHub Actions.   export GRAFANA_CLOUD_USER=986364 \

          GRAFANA_CLOUD_API_KEY="glc_..." \

### 5. Desplegar Demo App          PYROSCOPE_REMOTE_WRITE=https://profiles-prod-001.grafana.net \

```bash          PROM_REMOTE_WRITE=https://prometheus-prod-24-prod-us-east-0.grafana.net/api/prom/push

# Desde GitHub Actions: workflow_dispatch en deploy-demo-app.yaml   make deploy

# O manualmente:   ```

make deploy-demo-app3. Verifica que Alloy esté corriendo y empujando perfiles:

```   ```bash

   kubectl get pods -n observability -l app.kubernetes.io/name=alloy

## 📁 Estructura del Proyecto   make logs

   ```

```4. Anota tu pod Java (o workload instrumentado) con `pyroscope.grafana.com/scrape=true` y revisa en Grafana Cloud > Pyroscope que aparezcan nuevas series.

.

├── .github/workflows/> Para limpiar el entorno rápidamente: `make destroy`.

│   ├── deploy.yaml           # Deploy Alloy + observability stack

│   ├── deploy-demo-app.yaml  # Deploy/manage Java demo app## Limpieza

│   ├── cicd.yaml             # CI/CD para Java app (build & push)```bash

│   └── terraform.yaml        # Infrastructure provisioningkubectl delete -k kustomize/base

├── demo-app/```

│   ├── Dockerfile

│   ├── pom.xml## Contribuir

│   ├── src/                  # Spring Boot Java applicationMejoras y PRs son bienvenidos. Asegura que las ramas se publiquen en `main` para evitar errores de referencia.

│   └── k8s/
│       └── deployment.yaml   # Kubernetes manifests
├── kustomize/
│   ├── base/
│   │   ├── alloy-configmap.yaml   # Alloy configuration (HCL)
│   │   ├── alloy-daemonset.yaml   # DaemonSet with hostPID
│   │   ├── namespace.yaml
│   │   ├── rbac.yaml
│   │   └── serviceaccount.yaml
│   └── overlays/
│       └── alvaronicolas-profiles/
│           └── kustomization.yaml
├── terraform/
│   ├── main.tf               # GKE cluster definition
│   ├── variables.tf
│   └── outputs.tf
├── docs/
│   └── run-demo-locally.md
├── Makefile
└── README.md
```

## 🔐 Configuración de Secrets

### GitHub Secrets requeridos:

| Secret | Descripción |
|--------|-------------|
| `GCP_CREDENTIALS` | Service Account JSON con permisos de GKE Admin |
| `GRAFANA_CLOUD_API_KEY` | API Key de Grafana Cloud |

### Contenido del secret `GRAFANA_CLOUD_API_KEY`:
```
GRAFANA_CLOUD_USER=<instance-id>
GRAFANA_CLOUD_API_KEY=<api-token>
PYROSCOPE_REMOTE_WRITE=https://profiles-prod-xxx.grafana.net
PROM_REMOTE_WRITE=https://prometheus-prod-xxx.grafana.net/api/prom/push
```

## 🔄 Pipelines CI/CD

### `deploy.yaml` - Deploy Observability Stack
- **Trigger**: Push a `main` o manual
- **Acciones**: 
  - Valida config de Alloy con `alloy fmt`
  - Aplica Kustomize (namespace, RBAC, Alloy DaemonSet)
  - Crea secrets de Grafana Cloud

### `deploy-demo-app.yaml` - Manage Demo App
- **Trigger**: Manual (workflow_dispatch)
- **Acciones**: `deploy`, `delete`, `restart`

### `cicd.yaml` - Build Java App
- **Trigger**: Push a `main` con cambios en `demo-app/`
- **Acciones**: Build Maven, push a Artifact Registry

### `terraform.yaml` - Infrastructure
- **Trigger**: Manual o push a `terraform/`
- **Acciones**: `plan`, `apply`, `destroy`

## ☕ Demo App

Aplicación Spring Boot con endpoints para generar carga:

| Endpoint | Descripción |
|----------|-------------|
| `GET /` | Health check |
| `GET /cpu-sync?iterations=N` | Genera carga CPU síncrona |
| `GET /memory?size=N` | Aloca memoria (genera profiles de alloc) |

### Generar carga para demo:
```bash
# Port forward
kubectl port-forward svc/java-demo-app 8080:80

# Generar carga CPU
curl "http://localhost:8080/cpu-sync?iterations=5000000"

# Generar allocations
curl "http://localhost:8080/memory?size=10000"
```

## 📊 Visualización en Grafana

1. Ir a **Grafana Cloud** → **Explore** → **Profiles**
2. Seleccionar **Data source**: `grafanacloud-<tu-instancia>-profiles`
3. Seleccionar **Service**: `default/java-demo-app`
4. Elegir **Profile type**:
   - `process_cpu/cpu` - CPU time
   - `memory/alloc` - Memory allocations  
   - `mutex/lock` - Lock contention

### Flame Graph
- **Eje X**: Tiempo acumulado en la función
- **Eje Y**: Stack trace (profundidad de llamadas)
- **Color**: Diferencia entre versiones (diff view)

## 🔧 Configuración de Alloy

El archivo `kustomize/base/alloy-configmap.yaml` contiene la configuración de Alloy en formato HCL:

```hcl
// Descubrir pods Java
discovery.kubernetes "pods" {
  role = "pod"
  namespaces {
    names = ["default"]
  }
}

// Descubrir procesos y unir con pods
discovery.process "all" {
  join = discovery.kubernetes.pods.targets
}

// Filtrar solo Java y añadir labels
discovery.relabel "java" {
  targets = discovery.process.all.targets
  rule {
    source_labels = ["__meta_process_exe"]
    action        = "keep"
    regex         = ".*/java$"
  }
  // ... más reglas de relabeling
}

// Auto-instrumentación con async-profiler
pyroscope.java "java" {
  profiling_config {
    interval    = "15s"
    cpu         = true
    sample_rate = 100
    alloc       = "512k"
    lock        = "10ms"
  }
  forward_to = [pyroscope.write.grafana_cloud.receiver]
  targets    = discovery.relabel.java.output
}
```

### Flags JVM recomendados (opcional)
Para profiles más precisos:
```bash
-XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints
```

## 🐛 Troubleshooting

### Ver logs de Alloy
```bash
kubectl logs -n observability -l app.kubernetes.io/name=alloy -c alloy -f
```

### Verificar targets descubiertos
```bash
kubectl port-forward -n observability svc/alloy 12345:12345
curl http://localhost:12345/api/v0/web/components
```

### Errores comunes

| Error | Solución |
|-------|----------|
| `could not find PID label` | Verificar `hostPID: true` en DaemonSet |
| `permission denied /proc/*/exe` | Añadir capabilities `SYS_PTRACE`, `SYS_ADMIN` |
| `no targets found` | Verificar namespaces en `discovery.kubernetes` |

## 📚 Referencias

- [Grafana Alloy Documentation](https://grafana.com/docs/alloy/latest/)
- [Pyroscope Java Profiling](https://grafana.com/docs/pyroscope/latest/configure-client/grafana-alloy/java/)
- [async-profiler](https://github.com/async-profiler/async-profiler)

## 👤 Autor

**Alvaro Nicolas** - Cloud Summit LATAM 2025

---

<p align="center">
  <img src="https://grafana.com/static/assets/img/grafana_labs_logo_light.svg" width="200">
</p>
