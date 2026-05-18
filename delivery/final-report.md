# Taller de pruebas y release 261 - Reporte final

## Portada

| Campo | Valor |
| --- | --- |
| Taller | Taller de pruebas y release 261 |
| Proyecto | CircleGuard |
| Repositorio | `circle-guard-public` |
| Ruta local de trabajo | `C:\Users\acer\Documents\8tavo semestre\Ingesoft V\Taller 2\circle-guard-public` |
| Fecha | 2026-05-18 |
| Integrante | `[Tomas Quintero]` |
| Fuente de rubrica | `docs/RUBRICA_TALLER_261.md` |

Microservicios seleccionados:

- `circleguard-auth-service`
- `circleguard-identity-service`
- `circleguard-promotion-service`
- `circleguard-notification-service`
- `circleguard-form-service`
- `circleguard-gateway-service`

## Resumen ejecutivo

El taller dejo una base reproducible para pruebas y release de seis microservicios de CircleGuard. Se implemento una estrategia Docker con `Dockerfile.service` parametrizable, Docker Compose para middleware y aplicaciones, manifests Kubernetes para servicios y dependencias, y pipelines Jenkins diferenciados para DEV, STAGE y MASTER.

Los pipelines DEV, STAGE y MASTER fueron ejecutados exitosamente en Jenkins local. Las ejecuciones cubren pruebas Gradle, construccion de artefactos `bootJar`, build de imagenes Docker, validacion de Compose, validacion Kubernetes, suite E2E, Locust smoke y generacion automatica de release notes.

Kubernetes fue validado localmente en Docker Desktop (`docker-desktop`, Kubernetes v1.34.1) aplicando los manifests de `k8s/dev` al namespace `circleguard-dev`. La validación final mostró `12/12` pods en estado `Running` y `Ready 1/1`, sin `ImagePullBackOff` ni restarts.

En pruebas se consolidaron 5 unitarias nuevas, 5 de integracion nuevas, una suite E2E smoke + functional y una suite Locust con metricas reales. Locust se ejecuto en modo smoke y load con 0 fallos: smoke registro 70 requests y load registro 581 requests.

Las release notes se generan como artefacto por ejecucion dentro del workspace Jenkins y se archivan como parte del build, orientadas a trazabilidad por pipeline.

## Microservicios seleccionados

Los seis microservicios seleccionados cubren autenticacion, identidad, promocion de estados de salud, notificaciones, formularios y gateway. En conjunto representan dependencias relevantes del sistema: Spring Security/JWT, persistencia relacional, Neo4j, Redis, Kafka, OpenLDAP y orquestacion por Docker/Kubernetes. Esta seleccion permite validar pruebas y pipelines sobre una muestra transversal del monorepo.

## Bloque 1 - Jenkins, Docker y Kubernetes (10%)

La configuracion base queda cubierta por:

| Elemento | Implementacion | Evidencia |
| --- | --- | --- |
| Jenkins | Jobs DEV, STAGE y MASTER configurados como Pipeline from SCM. | `Jenkinsfile`, `Jenkinsfile.stage`, `Jenkinsfile.master`, `docs/jenkins.md`, `docs/jenkins-stage-master.md`, `evidence/screenshots/jenkins-*/*.png` |
| Dockerfile parametrizable | Un unico `Dockerfile.service` empaqueta JARs Spring Boot generados por Gradle. | `Dockerfile.service`, `docs/dockerization.md` |
| Docker Compose | Middleware en `docker-compose.dev.yml` y aplicaciones en `docker-compose.app.yml`. | `docs/docker-compose.md`, `docker-compose.dev.yml`, `docker-compose.app.yml` |
| Kubernetes | Manifests para namespace, config, secrets, middleware y seis microservicios. | `k8s/README.md`, `k8s/dev/*.yaml`, evidencias Kubernetes pendientes de adjuntar |

Kubernetes fue validado en un cluster local Docker Desktop (`docker-desktop`, Kubernetes v1.34.1). Los manifests de `k8s/dev` fueron aplicados al namespace `circleguard-dev`, incluyendo middleware y seis microservicios. La validación final mostró `12/12` pods en estado `Running` y `Ready 1/1`, sin `ImagePullBackOff` ni restarts. Los pipelines Jenkins mantienen `DEPLOY_TO_K8S=false` por defecto como control de seguridad; la validación real del cluster local se realizó con `kubectl apply -f k8s/dev/` sobre Docker Desktop.

Referencias tecnicas: `docs/dockerization.md`, `docs/docker-compose.md`, `k8s/README.md`.

## Bloque 2 - Pipeline DEV (15%)

El pipeline DEV corresponde al job Jenkins `circleguard-dev-pipeline`.

| Campo | Valor |
| --- | --- |
| Job | `circleguard-dev-pipeline` |
| Repositorio configurado | `https://github.com/tomasquin2003/circle-guard-public.git` |
| Branch | `*/master` |
| Script path | `Jenkinsfile` |
| Resultado documentado | `Finished: SUCCESS` en `evidence/logs/jenkins-dev-console-success.txt` |

Stages ejecutados: checkout, environment info, pruebas de servicios seleccionados, `bootJar`, build de imagenes Docker, validacion Docker Compose, Kubernetes dry-run, E2E, Locust smoke, release notes y archivado de reportes.

Ajustes de estabilizacion aplicados:

- El benchmark `PromotionPerformanceTest.benchmarkPromotionPerformance()` fue separado con `@Tag("performance")` para evitar fragilidad temporal en CI local. La cobertura de rendimiento formal queda en Locust.
- La generacion de release notes se ajusto para compatibilidad con Groovy/CPS, pasando la lista de servicios a `generateReleaseNotes(List services)`.

Evidencia: `evidence/screenshots/jenkins-dev/jenkins-dev-config.png`, `evidence/screenshots/jenkins-dev/jenkins-dev-stage-view-success.png`, `evidence/logs/jenkins-dev-console-success.txt`.

## Bloque 3 - Pruebas unitarias, integracion, E2E y rendimiento (30%)

### Unitarias nuevas

Se documentan 5 pruebas unitarias nuevas:

| # | Test | Ruta |
| ---: | --- | --- |
| 1 | `JwtTokenServiceTest.generateToken_includesSubjectPermissionsAndExpiration` | `services/circleguard-auth-service/src/test/java/com/circleguard/auth/service/JwtTokenServiceTest.java` |
| 2 | `IdentityVaultServiceTest.getOrCreateAnonymousId_whenHashExists_returnsExistingIdWithoutDuplicateSave` | `services/circleguard-identity-service/src/test/java/com/circleguard/identity/service/IdentityVaultServiceTest.java` |
| 3 | `HealthSurveyServiceTest.submitSurvey_withAttachment_setsPendingAndPublishesSurveySubmitted` | `services/circleguard-form-service/src/test/java/com/circleguard/form/service/HealthSurveyServiceTest.java` |
| 4 | `QrValidationServiceTest.shouldReturnRedForExpiredOrMalformedToken` | `services/circleguard-gateway-service/src/test/java/com/circleguard/gateway/service/QrValidationServiceTest.java` |
| 5 | `CircleServiceTest.forceFenceCircle_promotesOnlyActiveMembers` | `services/circleguard-promotion-service/src/test/java/com/circleguard/promotion/service/CircleServiceTest.java` |

### Integracion nuevas

Se documentan 5 pruebas de integracion nuevas:

| # | Test | Alcance |
| ---: | --- | --- |
| 1 | `IdentityVaultControllerIntegrationTest.mapThenLookup_PersistsMapping_ResolvesIdentity_AndAuditsAccess` | Mapping, lookup, persistencia y auditoria Kafka. |
| 2 | `HealthSurveyServiceIntegrationTest.submitSurvey_WithAttachment_PersistsPendingLegacyFieldsAndPublishesEvent` | Formulario con attachment, estado pendiente y evento. |
| 3 | `CertificateValidationControllerIntegrationTest.pendingThenValidate_ListsPendingSurvey_UpdatesStatus_AndPublishesApprovalEvent` | Lista de certificados, validacion y evento de aprobacion. |
| 4 | `QrValidationServiceRedisIntegrationTest.validateToken_WithRedisBackedStatuses_DistinguishesGreenFromRedAndInvalid` | Redis con Testcontainers y estados GREEN/RED/invalid. |
| 5 | `HealthStatusRecoveryIntegrationTest.recoverEndpoint_WithSecurity_TransitionsUserToRecovered_UpdatesRedis_AndPublishesStatusChange` | Recovery, seguridad, Neo4j, Redis con TTL y evento. |

### E2E smoke + functional

La suite E2E esta en `e2e/run-e2e.ps1` y genera `e2e/results/e2e-report.md`. El reporte disponible indica:

- Resultado global: `PASSED`.
- Smoke checks: 5 passed / 0 failed.
- Functional checks: 2 passed / 0 failed / 1 blocked / 1 skipped.

Alcance documentado: los 5 checks principales validan disponibilidad operacional del stack. Los flujos funcionales autenticados dependen de JWT y seed data; la suite los clasifica explicitamente como `BLOCKED_BY_AUTH` o `SKIPPED_NO_SEED` cuando aplica.

### Locust performance/load

La suite Locust esta en `performance/locust/locustfile.py` y sus resultados en `performance/locust/results/*.csv`.

| Corrida | Requests | Failures | Avg | p95 | p99 | Throughput |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Smoke | 70 | 0 | 68.63 ms | 160 ms | 1600 ms | 2.48 req/s |
| Load | 581 | 0 | 33.21 ms | 56 ms | 66 ms | 9.78 req/s |

Analisis:

- Throughput: la corrida load alcanzo 9.78 req/s, superior al smoke de 2.48 req/s, sin incremento de errores.
- Tiempo de respuesta: load fue mas estable, con promedio 33.21 ms y p99 de 66 ms.
- Tasa de errores: ambas corridas registraron 0 failures y 0.00% de error rate.
- Outlier: en smoke, `promotion_health_smoke` tuvo un maximo de 1631.39 ms y elevo el p99 agregado a 1600 ms.
- Estabilidad: el outlier no se repitio en load; el maximo agregado bajo a 88.81 ms segun `performance/locust/README.md`.
- Alcance: algunos endpoints se clasifican aceptando 401/403 cuando la seguridad bloquea peticiones sin JWT; los flujos dependientes de seed data se reportan con su clasificacion explicita.

## Bloque 4 - Pipeline STAGE (15%)

El pipeline STAGE corresponde al job Jenkins `circleguard-stage-pipeline`.

| Campo | Valor |
| --- | --- |
| Job | `circleguard-stage-pipeline` |
| Script path | `Jenkinsfile.stage` |
| Parametro/default | `DEPLOY_TO_K8S=false` |
| Evidencia disponible | Capturas de configuracion y stage view |

Stages documentados: checkout, environment info, unit/integration tests, `bootJar`, Docker build, validacion Kubernetes, deploy parametrizado, E2E contra stage, archivado y post actions.

El pipeline STAGE usa `DEPLOY_TO_K8S=false` como valor por defecto para controlar cuándo aplicar manifiestos desde Jenkins. En esta entrega, el flujo STAGE quedó validado con pruebas, build, Docker, validación Kubernetes, E2E y archivado de artefactos. La validación Kubernetes real se complementó directamente sobre Docker Desktop mediante `kubectl apply -f k8s/dev/`, dejando el namespace `circleguard-dev` operativo.

Evidencia: `Jenkinsfile.stage`, `docs/jenkins-stage-master.md`, `evidence/screenshots/jenkins-stage/jenkins-stage-config.png`, `evidence/screenshots/jenkins-stage/jenkins-stage-stage-view-success.png`.

## Bloque 5 - Pipeline MASTER / Release (15%)

El pipeline MASTER corresponde al job Jenkins `circleguard-master-pipeline`.

| Campo | Valor |
| --- | --- |
| Job | `circleguard-master-pipeline` |
| Script path | `Jenkinsfile.master` |
| Parametro/default | `DEPLOY_TO_K8S=false` |
| Resultado documentado | `Finished: SUCCESS` en `evidence/logs/jenkins-master-console-success.txt` |

Stages ejecutados: checkout, environment info, full test suite, `bootJar`, Docker build, Docker Compose config, Kubernetes manifests, E2E smoke + functional, Locust smoke, deploy Kubernetes parametrizado, release notes automaticas, archivado de artefactos y post actions.

El pipeline MASTER valida el camino master/release con full test suite, Docker, Compose, Kubernetes, E2E, Locust smoke, deploy parametrizado, release notes automaticas y artefactos archivados. Las release notes se generan como artefacto por ejecucion dentro del workspace Jenkins, orientadas a trazabilidad por build.

Evidencia: `Jenkinsfile.master`, `evidence/screenshots/jenkins-master/jenkins-master-config.png`, `evidence/screenshots/jenkins-master/jenkins-master-stage-view-success.png`, `evidence/logs/jenkins-master-console-success.txt`.

## Evidencias principales

| Evidencia | Que demuestra | Ruta | Bloque |
| --- | --- | --- | --- |
| Configuracion DEV | Job Jenkins DEV configurado desde SCM. | `evidence/screenshots/jenkins-dev/jenkins-dev-config.png` | 2, 6 |
| Stage view DEV | Pipeline DEV exitoso visualmente. | `evidence/screenshots/jenkins-dev/jenkins-dev-stage-view-success.png` | 2, 6 |
| Log DEV | Stages DEV, E2E, Locust, release notes y `Finished: SUCCESS`. | `evidence/logs/jenkins-dev-console-success.txt` | 2, 3, 5 |
| Configuracion STAGE | Job STAGE configurado desde SCM. | `evidence/screenshots/jenkins-stage/jenkins-stage-config.png` | 4, 6 |
| Stage view STAGE | Pipeline STAGE exitoso visualmente. | `evidence/screenshots/jenkins-stage/jenkins-stage-stage-view-success.png` | 4, 6 |
| Configuracion MASTER | Job MASTER configurado desde SCM. | `evidence/screenshots/jenkins-master/jenkins-master-config.png` | 5, 6 |
| Stage view MASTER | Pipeline MASTER exitoso visualmente. | `evidence/screenshots/jenkins-master/jenkins-master-stage-view-success.png` | 5, 6 |
| Log MASTER | Full suite, Docker, Compose, K8s dry-run, E2E, Locust, release notes y `Finished: SUCCESS`. | `evidence/logs/jenkins-master-console-success.txt` | 5, 6 |
| E2E report | Resultado E2E smoke + functional. | `e2e/results/e2e-report.md` | 3 |
| Locust CSVs | Metricas reales smoke/load. | `performance/locust/results/*.csv` | 3 |
| Kubernetes manifests | Recursos para apps y middleware. | `k8s/dev/*.yaml` | 1, 4, 5 |
| Kubernetes Docker Desktop activo | Cluster local `docker-desktop` disponible para validacion. | `evidence/screenshots/k8s-docker-desktop-running.png` pendiente de adjuntar | 1 |
| Kubernetes apply real | Aplicacion de manifests `kubectl apply -f k8s/dev/`. | `evidence/logs/k8s-docker-desktop-apply.txt` pendiente de adjuntar | 1 |
| Kubernetes recursos | Recursos creados en namespace `circleguard-dev`. | `evidence/screenshots/k8s-get-all-circleguard-dev.png` pendiente de adjuntar | 1 |
| Kubernetes pods | Pods `12/12` en estado `Running/Ready`. | `evidence/screenshots/k8s-get-pods-circleguard-dev.png` pendiente de adjuntar | 1 |
| Kubernetes services | Services `ClusterIP` de middleware y microservicios. | `evidence/screenshots/k8s-get-svc-circleguard-dev.png` pendiente de adjuntar | 1 |

## Alcance, supuestos y consideraciones de ejecución

- Kubernetes fue validado en Docker Desktop local con `12/12` pods `Running/Ready`.
- Jenkins conserva deploy parametrizado mediante `DEPLOY_TO_K8S` para controlar cuando aplicar manifiestos desde pipeline.
- Registry remoto no fue necesario para la validacion local porque Docker Desktop Kubernetes uso imagenes locales.
- Los E2E autenticados dependen de JWT/seed data y se clasifican explicitamente como `BLOCKED_BY_AUTH` o `SKIPPED_NO_SEED` cuando aplica.
- Warnings de startup/readiness inicial en Kubernetes y shutdown de Testcontainers no afectaron los resultados finales exitosos.
- Release notes se generan como artefacto Jenkins por build.

## Conclusion

El taller queda cubierto con pipelines DEV, STAGE y MASTER ejecutados en Jenkins, Docker/Compose operativo, Kubernetes validado localmente en Docker Desktop con `12/12` pods `Running/Ready`, pruebas unitarias, integracion, E2E, rendimiento con Locust, release notes y evidencias organizadas para entrega.
