# Indice de evidencias - Taller de pruebas y release 261

Fuente principal de evaluacion: `docs/RUBRICA_TALLER_261.md`. No se encontro una copia en la raiz con el nombre `RUBRICA_TALLER_261.md`; la transcripcion disponible en `docs/` se usa como fuente de verdad del repositorio.

## Matriz por rubrica

| Bloque de rubrica | Peso | Evidencia requerida | Evidencia disponible en repo | Archivo/screenshot/log asociado | Estado | Observacion |
| --- | ---: | --- | --- | --- | --- | --- |
| Configuracion base: Jenkins, Docker y Kubernetes | 10% | Jenkins configurado/documentado, Docker usado para servicios, Kubernetes preparado o validado, capturas o comandos. | Documentacion Jenkins, Dockerfile parametrizable, Compose middleware + apps, manifests Kubernetes para apps y middleware. | `docs/jenkins.md`, `docs/dockerization.md`, `docs/docker-compose.md`, `Dockerfile.service`, `docker-compose.dev.yml`, `docker-compose.app.yml`, `k8s/README.md`, `k8s/dev/*.yaml` | Completo | Kubernetes queda defendido por manifests y dry-run; el reporte no debe vender stage/master como deploy real cuando `DEPLOY_TO_K8S=false`. |
| Pipeline ambiente dev | 15% | Pipeline para seis microservicios con build, pruebas, empaquetado y deployment/validacion. | Job Jenkins local `circleguard-dev-pipeline` ejecutado exitosamente, con tests, `bootJar`, Docker build, Compose config, Kubernetes dry-run, E2E, Locust smoke y release notes. | `Jenkinsfile`, `docs/jenkins.md`, `evidence/screenshots/jenkins-dev/jenkins-dev-config.png`, `evidence/screenshots/jenkins-dev/jenkins-dev-stage-view-success.png`, `evidence/logs/jenkins-dev-console-success.txt` | Completo | El log termina en `Finished: SUCCESS`. El deploy Kubernetes en este flujo es dry-run/validacion. |
| Pruebas unitarias | Parte de 30% | Al menos 5 pruebas unitarias nuevas, comando y resultado. | 5 pruebas unitarias nuevas documentadas y con reportes XML generados. | `TALLER_PROGRESS.md`, `AUDIT_DOD_261.md`, `services/**/src/test/**`, `services/**/build/test-results/test/*.xml` | Completo | Lista exacta en `AUDIT_DOD_261.md` y resumen en `delivery/final-report.md`. |
| Pruebas de integracion | Parte de 30% | Al menos 5 pruebas de integracion nuevas sobre componentes, servicios o dependencias. | 5 pruebas de integracion nuevas con H2/Testcontainers, seguridad, Redis, Neo4j y eventos. | `TALLER_PROGRESS.md`, `AUDIT_DOD_261.md`, `services/**/src/test/**`, `services/**/build/test-results/test/*.xml` | Completo | Las pruebas Java cubren interacciones reales de infraestructura o endpoints internos. |
| Pruebas E2E | Parte de 30% | Al menos 5 checks/flujos E2E; si hay bloqueos por auth/seed deben documentarse. | Suite E2E smoke + functional ejecutada con resultado global `PASSED`: 5 smoke, 2 functional pass, 1 blocked by auth, 1 skipped por falta de seed. | `e2e/run-e2e.ps1`, `e2e/README.md`, `e2e/results/e2e-report.md`, logs Jenkins dev/master | Parcial | Los 5 checks principales son reachability operacional; no deben presentarse como 5 flujos funcionales completos. |
| Locust rendimiento/estres | Parte de 30% | Suite Locust, escenarios realistas, ejecuciones y metricas con analisis. | Suite Locust ejecutada en smoke y load con CSVs reales y 0 fallos. | `performance/locust/locustfile.py`, `performance/locust/README.md`, `performance/locust/results/circleguard-smoke_*.csv`, `performance/locust/results/circleguard-load_*.csv` | Completo | Smoke: 70 requests, 0 failures, avg 68.63 ms, p95 160 ms, p99 1600 ms, 2.48 req/s. Load: 581 requests, 0 failures, avg 33.21 ms, p95 56 ms, p99 66 ms, 9.78 req/s. |
| Pipeline stage | 15% | Pipeline stage con build, pruebas y validacion sobre Kubernetes. | Job Jenkins local `circleguard-stage-pipeline` documentado como exitoso, con capturas de configuracion y stage view. | `Jenkinsfile.stage`, `docs/jenkins-stage-master.md`, `evidence/screenshots/jenkins-stage/jenkins-stage-config.png`, `evidence/screenshots/jenkins-stage/jenkins-stage-stage-view-success.png`, `evidence/logs/jenkins-stage-console-success.txt` | Parcial | El archivo de log stage existe pero esta vacio; la evidencia fisica principal son las capturas. Con `DEPLOY_TO_K8S=false` no hubo deploy real a cluster desde Jenkins. |
| Pipeline master + Release Notes | 15% | Pipeline master con build, unit tests, system tests, deploy/validacion Kubernetes y release notes automaticas. | Job Jenkins local `circleguard-master-pipeline` ejecutado exitosamente; genera release notes en workspace Jenkins y archiva artefactos. | `Jenkinsfile.master`, `docs/jenkins-stage-master.md`, `evidence/screenshots/jenkins-master/jenkins-master-config.png`, `evidence/screenshots/jenkins-master/jenkins-master-stage-view-success.png`, `evidence/logs/jenkins-master-console-success.txt` | Completo | El log termina en `Finished: SUCCESS` y muestra `DEPLOY_TO_K8S=false`; no se encontro `release-notes/RELEASE_NOTES.md` versionado en el repo. |
| Documento, video y zip | 15% | Documento final, video maximo 8 minutos y zip con pipelines, pruebas y proyecto modificado. | Estructura final creada con reporte, guion, checklist e indice de evidencias. | `delivery/final-report.md`, `delivery/video-script.md`, `delivery/zip-checklist.md`, `evidence/README.md`, `evidence/docs-index.md` | Completo | El video y el zip quedan preparados como entregables a producir fuera del repositorio usando estos archivos. |
| Pantallazos de configuracion y ejecucion | Documento/video | Capturas de configuracion y ejecucion exitosa de pipelines. | Capturas fisicas disponibles para DEV, STAGE y MASTER. | `evidence/screenshots/jenkins-dev/*.png`, `evidence/screenshots/jenkins-stage/*.png`, `evidence/screenshots/jenkins-master/*.png` | Parcial | No existen capturas fisicas de consola en `evidence/screenshots/`; las consolas estan cubiertas por logs dev/master y un log stage vacio. |
| Logs Jenkins | Documento/video | Logs de ejecucion de pipelines. | Logs disponibles para DEV y MASTER; archivo stage vacio. | `evidence/logs/jenkins-dev-console-success.txt`, `evidence/logs/jenkins-master-console-success.txt`, `evidence/logs/jenkins-stage-console-success.txt` | Parcial | DEV y MASTER contienen `Finished: SUCCESS`; STAGE debe apoyarse en capturas o completarse con un log no vacio antes de zip final. |
| Release notes | Master/release | Release Notes automaticas con metadata de build, commit, servicios, cambios y validaciones. | Generacion evidenciada en logs Jenkins DEV y MASTER. | `Jenkinsfile`, `Jenkinsfile.master`, `evidence/logs/jenkins-dev-console-success.txt`, `evidence/logs/jenkins-master-console-success.txt` | Parcial | No se encontro carpeta `release-notes/` versionada; las release notes se generaron dentro del workspace Jenkins. |
| Manifests Kubernetes | Configuracion/stage/master | Manifests para microservicios y middleware. | Namespace, ConfigMap, Secret, middleware y seis microservicios en `k8s/dev/`. | `k8s/README.md`, `k8s/dev/namespace.yaml`, `k8s/dev/configmap.yaml`, `k8s/dev/secrets.yaml`, `k8s/dev/postgres.yaml`, `k8s/dev/redis.yaml`, `k8s/dev/neo4j.yaml`, `k8s/dev/kafka.yaml`, `k8s/dev/openldap.yaml`, `k8s/dev/*-service.yaml` | Completo | Validacion Jenkins reportada por `kubectl apply --dry-run=client -f k8s/dev/`; no equivale a despliegue real cuando `DEPLOY_TO_K8S=false`. |

## Evidencia fisica encontrada

### Screenshots

- `evidence/screenshots/jenkins-dev/jenkins-dev-config.png`
- `evidence/screenshots/jenkins-dev/jenkins-dev-stage-view-success.png`
- `evidence/screenshots/jenkins-stage/jenkins-stage-config.png`
- `evidence/screenshots/jenkins-stage/jenkins-stage-stage-view-success.png`
- `evidence/screenshots/jenkins-master/jenkins-master-config.png`
- `evidence/screenshots/jenkins-master/jenkins-master-stage-view-success.png`

### Logs

- `evidence/logs/jenkins-dev-console-success.txt` - log no vacio, resultado exitoso.
- `evidence/logs/jenkins-master-console-success.txt` - log no vacio, resultado exitoso.
- `evidence/logs/jenkins-stage-console-success.txt` - archivo existente con 0 bytes al momento de esta consolidacion.

### Resultados Locust

- `performance/locust/results/circleguard-smoke_stats.csv`
- `performance/locust/results/circleguard-smoke_stats_history.csv`
- `performance/locust/results/circleguard-smoke_failures.csv`
- `performance/locust/results/circleguard-smoke_exceptions.csv`
- `performance/locust/results/circleguard-load_stats.csv`
- `performance/locust/results/circleguard-load_stats_history.csv`
- `performance/locust/results/circleguard-load_failures.csv`
- `performance/locust/results/circleguard-load_exceptions.csv`

### Reportes E2E

- `e2e/results/e2e-report.md`

