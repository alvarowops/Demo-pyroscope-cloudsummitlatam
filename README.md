# 🔥 Continuous Profiling con Grafana Pyroscope + Alloy

Demo oficial para **Cloud Summit LATAM 2025** (charla: *Profiling + IA: el nuevo pilar de la observabilidad*). Muestra cómo habilitar **Continuous Profiling** en aplicaciones Java dentro de Kubernetes usando **Grafana Alloy** con **async-profiler**, enviando datos a **Grafana Cloud Pyroscope** y apoyándose en **Grafana Assistant** para interpretar flame graphs.

![Flame graph en Pyroscope](https://grafana.com/media/docs/pyroscope/pyroscope-ui-single-background.png)

---

## 🧭 Qué levanta el lab
- **Cluster GKE** con pods Java anotados para profiling (`pyroscope.grafana.com/scrape=true`).
- **Grafana Alloy** como **DaemonSet**, descubre procesos Java con `discovery.kubernetes` + `discovery.process` y ejecuta `async-profiler`.
- **Pyroscope** recibe perfiles pprof cada 15s; **Prometheus remote write** expone métricas del agente.
- **Grafana Assistant** resume y propone optimizaciones directo sobre el flame graph.

![Flujo de datos hacia Grafana Cloud](https://grafana.com/media/docs/pyroscope/pyroscope-flamegraph-ui.png)

## 🗂️ Estructura del repositorio
```
.
├── demo-app/                    # Spring Boot demo con endpoints de carga
├── kustomize/
│   ├── base/                    # Alloy DaemonSet, ConfigMap River, RBAC, secret de Grafana Cloud
│   └── overlays/alvaronicolas-profiles/  # Overlay listo para la demo (US-East)
├── terraform/                   # Infra mínima (GKE 1 nodo) con tfvars de ejemplo
├── docs/                        # Extras de la charla
└── .github/workflows/           # Pipelines CI/CD (deploy, terraform, build app)
```

## ✅ Requisitos previos
- Proyecto en **Google Cloud Platform** con permisos para crear GKE.
- **gcloud CLI** instalado y autenticado.
- **kubectl** configurado (o toma el contexto desde los outputs de Terraform).
- Cuenta de **Grafana Cloud** (free tier funciona) con endpoints de Pyroscope y Prometheus.
- Secrets de **GitHub Actions** listos si despliegas desde CI/CD.

## ⚡ Guía rápida de laboratorio (15 minutos)
Sigue estos pasos en orden para que los asistentes puedan replicar el lab durante la charla.

1) **Clona el repo**
   ```bash
   git clone https://github.com/alvarowops/Demo-pyroscope-cloudsummitlatam.git
   cd Demo-pyroscope-cloudsummitlatam
   ```

2) **Crea la infraestructura mínima en GCP**
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   # Edita project_id, región, nombre de clúster y tipo de máquina (un nodo preemptible basta)
   terraform init
   terraform apply
   # Copia el output get_credentials para configurar kubectl
   cd ..
   ```

3) **Configura kubectl con las credenciales de GKE**
   Usa el comando `get_credentials` que devolvió Terraform o ejecuta manualmente:
   ```bash
   gcloud container clusters get-credentials <cluster> --region <region> --project <project>
   ```

4) **Carga credenciales de Grafana Cloud**
   Completa tus datos en `kustomize/base/grafana-cloud-secret.yaml` (user/token y endpoints si cambias región) o usa el overlay listo de la demo.

5) **Despliega la base de observabilidad**
   ```bash
   kubectl apply -k kustomize/base
   ```

6) **Overlay listo para la demo (alvaronicolas-profiles)**
   ```bash
   cp kustomize/overlays/alvaronicolas-profiles/secret.env.example \
      kustomize/overlays/alvaronicolas-profiles/secret.env
   # Rellena GRAFANA_CLOUD_USER y GRAFANA_CLOUD_API_KEY (stack US-East)
   kubectl apply -k kustomize/overlays/alvaronicolas-profiles
   ```

7) **Anota tus pods Java** (ejemplo)
   ```yaml
   metadata:
     annotations:
       pyroscope.grafana.com/scrape: "true"
       pyroscope.grafana.com/application_name: "demo-java"
       pyroscope.grafana.com/port: "4040"  # Ajusta al puerto del agente
   ```

8) **Verifica Alloy y los targets**
   ```bash
   kubectl get pods -n observability -l app.kubernetes.io/name=alloy
   kubectl logs -n observability -l app.kubernetes.io/name=alloy --tail=50
   ```

9) **Explora perfiles en Grafana Cloud**
   - Ve a **Explore → Profiles** y selecciona el servicio `default/java-demo-app` (o el `application_name` que definiste).
   - Explora `process_cpu/cpu`, `memory/alloc`, `mutex/lock` y usa **Grafana Assistant** para obtener resúmenes en español.

10) **Limpia el lab cuando termines**
    ```bash
    cd terraform
    terraform destroy
    ```

## 🧱 Infraestructura con Terraform (detalle)
1. Ajusta `terraform/terraform.tfvars.example` y renómbralo a `terraform.tfvars`.
2. Crea el clúster y obtén credenciales:
   ```bash
   terraform init
   terraform apply
   # Copia el comando get_credentials del output
   ```
3. Una vez con `kubectl` apuntando al clúster, vuelve al raíz del repo para aplicar Kustomize.

## 🔧 Componentes y manifiestos clave
- `kustomize/base/alloy-configmap.yaml`: pipeline River que descubre pods anotados, reetiqueta el puerto de profiling y envía datos a Pyroscope/Prometheus.
- `kustomize/base/alloy-daemonset.yaml`: despliega Alloy como DaemonSet con `async-profiler`.
- `kustomize/base/grafana-cloud-secret.yaml`: credenciales y endpoints de Grafana Cloud.
- `kustomize/base/rbac.yaml` y `kustomize/base/serviceaccount.yaml`: permisos de descubrimiento.
- `demo-app/`: Spring Boot con endpoints para carga controlada.

## 🔐 Secrets
### GitHub Actions
| Secret | Descripción |
| --- | --- |
| `GCP_CREDENTIALS` | Service Account JSON con permisos de administrador de GKE |
| `GRAFANA_CLOUD_API_KEY` | Token de Grafana.com con permisos de Pyroscope |

Variables de repositorio (`Settings > Variables`): `GCP_PROJECT_ID`, `GKE_CLUSTER`, `GKE_LOCATION`, `GRAFANA_CLOUD_USER` (ej. `986364`).

### Formato local (plantilla)
```bash
GRAFANA_CLOUD_USER=<instance-id>
GRAFANA_CLOUD_API_KEY=<api-token>
PYROSCOPE_REMOTE_WRITE=https://profiles-prod-xxx.grafana.net
PROM_REMOTE_WRITE=https://prometheus-prod-xxx.grafana.net/api/prom/push
```

## 🔄 Pipelines CI/CD
Además del flujo manual, el repo trae **workflows listos para desplegar**. Úsalos cuando quieras automatizar la demo o dejarla corriendo antes de la charla.

- **`deploy.yaml`**: despliega Alloy + observability stack en GKE (trigger: push a `main`). Usa `GCP_CREDENTIALS`, `GRAFANA_CLOUD_USER` y `GRAFANA_CLOUD_API_KEY` para autenticar y aplicar `kustomize/overlays/alvaronicolas-profiles`.
- **`deploy-demo-app.yaml`**: ciclo de vida de la demo app Java. Se dispara manualmente (`workflow_dispatch`) o al cambiar `demo-app/` y depende de `cicd.yaml` para obtener la imagen.
- **`cicd.yaml`**: build y push de la imagen Java (trigger: cambios en `demo-app/`). Sube la imagen a Artifact Registry usando `GCP_PROJECT_ID` y `GCP_CREDENTIALS`.
- **`terraform.yaml`**: plan/apply/destroy de infraestructura (trigger manual `workflow_dispatch`). Requiere `TF_VAR_project_id`, `TF_VAR_region` y `TF_VAR_cluster_name` mapeados desde secretos/variables.

**Consejo rápido:** antes de la sesión, lanza `terraform.yaml` para crear el clúster y luego `deploy.yaml` para tener Alloy y las anotaciones listas; durante la charla puedes mostrar el workflow `deploy-demo-app.yaml` para redeploy de la app con un solo click.

## ☕ Demo app y generación de carga
Endpoints principales:
| Endpoint | Descripción |
| --- | --- |
| `GET /` | Health check |
| `GET /cpu-sync?iterations=N` | Genera carga de CPU (Fibonacci) |
| `GET /memory?size=N` | Aloca objetos en memoria |

Targets rápidos desde el Makefile:
```bash
make load-cpu
make load-memory
```

## 🧰 Comandos útiles
```bash
make status        # Estado de pods
make logs          # Logs de Alloy
make logs-java     # Logs filtrados por Java
make port-forward  # Port-forward de la demo app
make alloy-ui      # Abre la UI del agente Alloy
```

## 📊 Visualización en Grafana
1. Abre **Explore → Profiles** en tu stack de Grafana Cloud.
2. Selecciona `default/java-demo-app` o el `service_name` definido en la anotación `application_name`.
3. Revisa los perfiles disponibles y corre **Grafana Assistant** para obtener recomendaciones sobre el flame graph activo.

## 🐛 Troubleshooting
| Problema | Acción recomendada |
| --- | --- |
| `could not find PID label` | Verifica `hostPID: true` en el DaemonSet y permisos de Alloy |
| `permission denied /proc/*/exe` | Añade capabilities `SYS_PTRACE` y `SYS_ADMIN` en el DaemonSet |
| `no targets found` | Revisa el namespace en `discovery.kubernetes` y la anotación `pyroscope.grafana.com/scrape` |

### Probar el despliegue manualmente
1. Autentica `kubectl` contra el clúster (usa outputs de Terraform o tus parámetros reales):
   ```bash
   gcloud auth login
   gcloud container clusters get-credentials $GKE_CLUSTER --region $GKE_LOCATION --project $GCP_PROJECT_ID
   ```
2. Exporta las credenciales de Grafana Cloud y ejecuta el target `deploy` del `Makefile` para aplicar el overlay `alvaronicolas-profiles`:
   ```bash
   export GRAFANA_CLOUD_USER=<id>
   export GRAFANA_CLOUD_API_KEY=<token>
   make deploy
   ```
3. Verifica en Grafana Cloud → Pyroscope que aparezcan perfiles de `demo-java` y revisa flame graphs con Grafana Assistant.
