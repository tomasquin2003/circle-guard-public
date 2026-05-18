# Guion de video - maximo 8 minutos

Objetivo: demostrar cobertura de la rubrica sin convertir el video en una bitacora. Mostrar primero evidencias ejecutables y despues documentos de soporte.

| Tiempo | Seccion | Que decir | Que mostrar |
| --- | --- | --- | --- |
| 0:00-0:35 | Introduccion | Presentar el taller, proyecto CircleGuard y que la estructura sigue la rubrica oficial. Mencionar los seis bloques y sus pesos generales. | `docs/RUBRICA_TALLER_261.md` y `delivery/final-report.md` en portada. |
| 0:35-1:05 | Microservicios | Indicar los seis microservicios seleccionados y por que representan autenticacion, identidad, promocion, notificaciones, formularios y gateway. | Seccion "Microservicios seleccionados" de `delivery/final-report.md` o estructura `services/`. |
| 1:05-1:55 | Docker, Compose y Kubernetes | Explicar `Dockerfile.service`, Compose separado entre middleware/apps y manifests Kubernetes para servicios y dependencias. Aclarar que en Jenkins se valida Kubernetes por dry-run/deploy parametrizado. | `Dockerfile.service`, `docker-compose.dev.yml`, `docker-compose.app.yml`, `k8s/dev/`, `k8s/README.md`. |
| 1:55-2:40 | Jenkins DEV | Presentar job `circleguard-dev-pipeline`, repo, branch, `Jenkinsfile` y resultado exitoso. Mencionar tests, build, Docker, Compose, dry-run, E2E, Locust y release notes. | `evidence/screenshots/jenkins-dev/jenkins-dev-config.png`, `evidence/screenshots/jenkins-dev/jenkins-dev-stage-view-success.png`, fragmento de `evidence/logs/jenkins-dev-console-success.txt` con `Finished: SUCCESS`. |
| 2:40-3:25 | Jenkins STAGE | Presentar job `circleguard-stage-pipeline`, `Jenkinsfile.stage`, parametro `DEPLOY_TO_K8S=false` y stages de stage. Aclarar que no se hizo deploy real desde Jenkins con ese parametro. | `evidence/screenshots/jenkins-stage/jenkins-stage-config.png`, `evidence/screenshots/jenkins-stage/jenkins-stage-stage-view-success.png`, `Jenkinsfile.stage`. |
| 3:25-4:15 | Jenkins MASTER | Presentar job `circleguard-master-pipeline`, `Jenkinsfile.master`, full test suite, Docker, Compose, K8s dry-run, E2E, Locust smoke, release notes y artefactos. | `evidence/screenshots/jenkins-master/jenkins-master-config.png`, `evidence/screenshots/jenkins-master/jenkins-master-stage-view-success.png`, `evidence/logs/jenkins-master-console-success.txt`. |
| 4:15-5:05 | Pruebas unitarias e integracion | Resumir las 5 unitarias y 5 integraciones nuevas. Enfatizar que estan en `src/test` y cubren JWT, identidad, formularios, gateway, promocion, Redis, Neo4j, seguridad y eventos. | Tablas del `delivery/final-report.md`, `AUDIT_DOD_261.md`, rutas `services/**/src/test/**`. |
| 5:05-5:45 | E2E | Mostrar suite E2E: 5 smoke pass, 2 functional pass, 1 blocked by auth y 1 skipped no seed. Explicar que no se venden los bloqueos como exitos funcionales completos. | `e2e/README.md`, `e2e/results/e2e-report.md`. |
| 5:45-6:45 | Locust y metricas | Mostrar resultados smoke y load. Resaltar 0 fallos, throughput, tiempos de respuesta, p95/p99 y outlier `promotion_health_smoke` en smoke. | `performance/locust/README.md`, `performance/locust/results/circleguard-smoke_stats.csv`, `performance/locust/results/circleguard-load_stats.csv`. |
| 6:45-7:25 | Release notes y evidencias | Explicar que las release notes son automaticas desde Jenkins y aparecen en los logs/workspace; mostrar matriz de evidencias y documentos finales. | `evidence/README.md`, `evidence/docs-index.md`, fragmento de logs DEV/MASTER con etapa de release notes. |
| 7:25-8:00 | Limitaciones y cierre | Cerrar con limitaciones honestas: sin deploy real cuando `DEPLOY_TO_K8S=false`, sin registry remoto, sin release/tag formal versionado, E2E autenticados limitados por JWT/seed. Concluir que la entrega cubre pipelines, pruebas, Docker/K8s, Locust y evidencias. | Seccion "Limitaciones honestas" y "Conclusion" de `delivery/final-report.md`. |

## Frase de cierre sugerida

"Con esta evidencia, el taller queda organizado por la rubrica: infraestructura base, pipelines DEV/STAGE/MASTER, pruebas unitarias, integracion, E2E, rendimiento con Locust, release notes automaticas y documentacion final para entrega."

