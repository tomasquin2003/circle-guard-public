# Auditoria DoD Taller 261 - CircleGuard

Fecha de auditoria: 2026-05-14  
Rama observada: `master`  
Fuentes obligatorias leidas: `docs/RUBRICA_TALLER_261.md`, `TALLER_PROGRESS.md`  
Alcance: auditoria documental y de archivos reales del repositorio. No se reejecutaron pipelines Jenkins ni despliegues Kubernetes durante esta auditoria.

## 1. Resumen ejecutivo

El repositorio esta en estado **PARCIAL alto** frente a la rubrica. Hay evidencia real de configuracion Docker, Docker Compose, pipelines Jenkins declarativos para dev/stage/master, manifests Kubernetes, 5 pruebas unitarias, 5 pruebas de integracion, suite E2E hibrida y Locust con CSVs de resultados.

El mayor riesgo para entrega no esta en ausencia de archivos, sino en ausencia de evidencia externa de ejecucion real en Jenkins y Kubernetes. `Jenkinsfile.stage` y `Jenkinsfile.master` existen, pero usan `DEPLOY_TO_K8S=false` por defecto y documentan dry-run como fallback. `k8s/README.md` declara explicitamente que no se ha validado en cluster real. La suite E2E existe y tiene reporte exitoso, pero contiene varios checks de reachability y dos flujos funcionales no completos por `BLOCKED_BY_AUTH` y `SKIPPED_NO_SEED`.

Hay evidencia fuerte de pruebas Java: los metodos nuevos existen bajo `services/**/src/test/**` y tambien aparecen en XMLs de Gradle bajo `services/**/build/test-results/test/*.xml`. Locust esta mejor que lo indicado por `e2e/results/e2e-report.md`: el reporte E2E dice "Locust remains pending", pero `performance/locust/README.md` y los CSVs en `performance/locust/results/` muestran ejecuciones smoke y load con 0 fallos.

## 2. Matriz de cumplimiento contra rubrica

| Rubrica / DoD | Estado | Evidencia real | Riesgo / brecha |
| --- | --- | --- | --- |
| Seis microservicios seleccionados y documentados | COMPLETO | `TALLER_PROGRESS.md`, `docs/dockerization.md`, `docs/jenkins.md`, `k8s/README.md` listan `circleguard-auth-service`, `circleguard-identity-service`, `circleguard-promotion-service`, `circleguard-notification-service`, `circleguard-form-service`, `circleguard-gateway-service`. | Sin riesgo critico. |
| Jenkins configurado/documentado | PARCIAL | `Jenkinsfile`, `Jenkinsfile.stage`, `Jenkinsfile.master`, `docs/jenkins.md`, `docs/jenkins-stage-master.md`. | No hay captura/log/artefacto de ejecucion real en Jenkins dentro del repo. |
| Dockerfile o estrategia Docker funcional | COMPLETO | `Dockerfile.service` parametrizado con `SERVICE_NAME`; `docs/dockerization.md`. | No se encontro artefacto de build Docker versionado, pero la estrategia y comandos estan documentados. |
| Docker Compose para dev | COMPLETO | `docker-compose.dev.yml`, `docker-compose.app.yml`, `docs/docker-compose.md`, `e2e/results/e2e-report.md` con snapshot de contenedores arriba. | Algunos healthchecks/readiness siguen pendientes salvo Neo4j. |
| Kubernetes configurado o manifests preparados | PARCIAL | `k8s/dev/*.yaml`, `k8s/README.md`. | `k8s/README.md` indica que no hay validacion en cluster real; solo dry-run recomendado. |
| Pipeline dev con build, tests, package y validacion/deploy | PARCIAL | `Jenkinsfile` ejecuta tests, `bootJar`, `docker build`, `docker compose config`, release notes. | No despliega realmente; no hay evidencia de job Jenkins ejecutado. |
| Pipeline stage con pruebas sobre Kubernetes | PARCIAL | `Jenkinsfile.stage` incluye tests, build, imagenes, `kubectl apply --dry-run=client`, deploy parametrizado, E2E. | `DEPLOY_TO_K8S=false` por defecto; sin evidencia de app desplegada y probada en Kubernetes real. |
| Pipeline master con build, unit tests, system tests, deploy Kubernetes y release notes | PARCIAL | `Jenkinsfile.master` incluye full test suite, Docker, Compose, K8s dry-run, E2E, Locust smoke, deploy parametrizado y release notes automaticas. | Deploy real deshabilitado por defecto; no existe `release-notes/RELEASE_NOTES.md` versionado ni evidencia de Jenkins real. |
| 5 pruebas unitarias nuevas | COMPLETO | Metodos y XMLs listados en seccion 3. | La auditoria valida archivos y XMLs existentes; no reejecuto Gradle. |
| 5 pruebas de integracion nuevas | COMPLETO | Metodos y XMLs listados en seccion 4. | La auditoria valida archivos y XMLs existentes; no reejecuto Gradle. |
| 5 pruebas E2E nuevas | PARCIAL | `e2e/run-e2e.ps1`, `e2e/results/e2e-report.md`, `e2e/README.md`. | Solo 2 functional PASS; 5 smoke son reachability. Riesgo: no son 5 flujos funcionales completos. |
| Locust rendimiento/estres | COMPLETO | `performance/locust/locustfile.py`, `performance/locust/README.md`, `performance/locust/results/*.csv`. | Buen estado, aunque `e2e/results/e2e-report.md` y `e2e/README.md` aun dicen que Locust esta pendiente. |
| Resultados y analisis Locust | COMPLETO | `performance/locust/README.md`, `performance/locust/results/circleguard-smoke_stats.csv`, `performance/locust/results/circleguard-load_stats.csv`. | Inconsistencia documental menor con E2E. |
| Evidencia de ejecucion: logs/reportes/CSVs/capturas/artefactos | PARCIAL | XMLs de Gradle en `services/**/build/test-results/test/*.xml`, `e2e/results/e2e-report.md`, CSVs Locust. | Faltan capturas o logs de Jenkins y Kubernetes real. |
| Documento final | PENDIENTE | Existen docs parciales en `docs/*.md`, pero no se encontro documento final consolidado del taller. | Debe consolidarse para entrega. |
| Guion/video maximo 8 minutos | PENDIENTE | No se encontro archivo de guion/video en el repo. | Requerido por rubrica. |
| Zip final con pipelines, pruebas y proyecto modificado | PENDIENTE | No se encontro `.zip` final. | Requerido por entregables finales. |

## 3. Lista exacta de las 5 pruebas unitarias nuevas

| # | Estado | Test | Ruta fuente | Evidencia de ejecucion local |
| --- | --- | --- | --- | --- |
| 1 | COMPLETO | `JwtTokenServiceTest.generateToken_includesSubjectPermissionsAndExpiration` | `services/circleguard-auth-service/src/test/java/com/circleguard/auth/service/JwtTokenServiceTest.java` | `services/circleguard-auth-service/build/test-results/test/TEST-com.circleguard.auth.service.JwtTokenServiceTest.xml` |
| 2 | COMPLETO | `IdentityVaultServiceTest.getOrCreateAnonymousId_whenHashExists_returnsExistingIdWithoutDuplicateSave` | `services/circleguard-identity-service/src/test/java/com/circleguard/identity/service/IdentityVaultServiceTest.java` | `services/circleguard-identity-service/build/test-results/test/TEST-com.circleguard.identity.service.IdentityVaultServiceTest.xml` |
| 3 | COMPLETO | `HealthSurveyServiceTest.submitSurvey_withAttachment_setsPendingAndPublishesSurveySubmitted` | `services/circleguard-form-service/src/test/java/com/circleguard/form/service/HealthSurveyServiceTest.java` | `services/circleguard-form-service/build/test-results/test/TEST-com.circleguard.form.service.HealthSurveyServiceTest.xml` |
| 4 | COMPLETO | `QrValidationServiceTest.shouldReturnRedForExpiredOrMalformedToken` | `services/circleguard-gateway-service/src/test/java/com/circleguard/gateway/service/QrValidationServiceTest.java` | `services/circleguard-gateway-service/build/test-results/test/TEST-com.circleguard.gateway.service.QrValidationServiceTest.xml` |
| 5 | COMPLETO | `CircleServiceTest.forceFenceCircle_promotesOnlyActiveMembers` | `services/circleguard-promotion-service/src/test/java/com/circleguard/promotion/service/CircleServiceTest.java` | `services/circleguard-promotion-service/build/test-results/test/TEST-com.circleguard.promotion.service.CircleServiceTest.xml` |

## 4. Lista exacta de las 5 pruebas de integracion nuevas

| # | Estado | Test | Ruta fuente | Evidencia de ejecucion local |
| --- | --- | --- | --- | --- |
| 1 | COMPLETO | `IdentityVaultControllerIntegrationTest.mapThenLookup_PersistsMapping_ResolvesIdentity_AndAuditsAccess` | `services/circleguard-identity-service/src/test/java/com/circleguard/identity/controller/IdentityVaultControllerIntegrationTest.java` | `services/circleguard-identity-service/build/test-results/test/TEST-com.circleguard.identity.controller.IdentityVaultControllerIntegrationTest.xml` |
| 2 | COMPLETO | `HealthSurveyServiceIntegrationTest.submitSurvey_WithAttachment_PersistsPendingLegacyFieldsAndPublishesEvent` | `services/circleguard-form-service/src/test/java/com/circleguard/form/service/HealthSurveyServiceIntegrationTest.java` | `services/circleguard-form-service/build/test-results/test/TEST-com.circleguard.form.service.HealthSurveyServiceIntegrationTest.xml` |
| 3 | COMPLETO | `CertificateValidationControllerIntegrationTest.pendingThenValidate_ListsPendingSurvey_UpdatesStatus_AndPublishesApprovalEvent` | `services/circleguard-form-service/src/test/java/com/circleguard/form/controller/CertificateValidationControllerIntegrationTest.java` | `services/circleguard-form-service/build/test-results/test/TEST-com.circleguard.form.controller.CertificateValidationControllerIntegrationTest.xml` |
| 4 | COMPLETO | `QrValidationServiceRedisIntegrationTest.validateToken_WithRedisBackedStatuses_DistinguishesGreenFromRedAndInvalid` | `services/circleguard-gateway-service/src/test/java/com/circleguard/gateway/service/QrValidationServiceRedisIntegrationTest.java` | `services/circleguard-gateway-service/build/test-results/test/TEST-com.circleguard.gateway.service.QrValidationServiceRedisIntegrationTest.xml` |
| 5 | COMPLETO | `HealthStatusRecoveryIntegrationTest.recoverEndpoint_WithSecurity_TransitionsUserToRecovered_UpdatesRedis_AndPublishesStatusChange` | `services/circleguard-promotion-service/src/test/java/com/circleguard/promotion/controller/HealthStatusRecoveryIntegrationTest.java` | `services/circleguard-promotion-service/build/test-results/test/TEST-com.circleguard.promotion.controller.HealthStatusRecoveryIntegrationTest.xml` |

## 5. Lista exacta de las 5 pruebas E2E o checks E2E

Fuente principal: `e2e/run-e2e.ps1` y reporte `e2e/results/e2e-report.md`.

| # | Estado | Check / flujo | Ruta / endpoint | Resultado encontrado | Riesgo |
| --- | --- | --- | --- | --- | --- |
| 1 | PARCIAL | `auth-service HTTP reachability` | `GET http://localhost:8180/actuator/health` en `e2e/run-e2e.ps1`; reporte en `e2e/results/e2e-report.md` | PASS con HTTP `404` y contenedor `UP`. | Es smoke/reachability, no flujo funcional completo. |
| 2 | PARCIAL | `identity-service HTTP reachability` | `GET http://localhost:8083/actuator/health` | PASS con HTTP `401` y contenedor `UP`. | Es smoke/reachability; 401 prueba seguridad/respuesta, no caso de negocio. |
| 3 | PARCIAL | `form-service HTTP reachability` | `GET http://localhost:8086/actuator/health` | PASS con HTTP `404` y contenedor `UP`. | Es smoke/reachability. |
| 4 | PARCIAL | `gateway-service HTTP reachability` | `GET http://localhost:8087/actuator/health` | PASS con HTTP `404` y contenedor `UP`. | Es smoke/reachability. |
| 5 | PARCIAL | `promotion-service + Neo4j health` | `GET http://localhost:8088/actuator/health` + health Docker de `circleguard-neo4j` | PASS con HTTP `404` y Neo4j `healthy`. | Es smoke/reachability, aunque suma dependencia real Neo4j. |

Checks funcionales adicionales encontrados en `e2e/results/e2e-report.md`:

| Flujo funcional | Estado | Evidencia | Riesgo |
| --- | --- | --- | --- |
| `Identity map/lookup` | PARCIAL | `POST /api/v1/identities/map` retorna `200`; `GET /api/v1/identities/lookup/{id}` retorna `401`. | `BLOCKED_BY_AUTH`; no es flujo completo sin JWT con `identity:lookup`. |
| `Certificates/Form pending list` | COMPLETO | `GET /api/v1/certificates/pending` retorna `200` con lista vacia. | Funcional defendible, pero no valida flujo con seed data de certificados pendientes reales. |
| `Promotion health recovery` | PARCIAL | `POST /api/v1/health/recovery/{id}` aparece como `SKIPPED_NO_SEED`. | No ejecutado por falta de id Neo4j seed y credenciales `HEALTH_CENTER`. |
| `Gateway QR validation route` | COMPLETO | `POST /api/v1/gate/validate` retorna `200` y rechaza token invalido como `RED`. | Valida ruta real, pero solo caso negativo de token invalido. |

Conclusion E2E: hay suite y reporte ejecutado, pero no hay 5 flujos funcionales E2E completos. Debe marcarse como **PARCIAL** por la regla de la rubrica sobre smoke/reachability.

## 6. Estado de Locust y metricas encontradas

Estado: **COMPLETO**.

Archivos reales:

- `performance/locust/locustfile.py`
- `performance/locust/README.md`
- `performance/locust/requirements.txt`
- `performance/locust/results/circleguard-smoke_stats.csv`
- `performance/locust/results/circleguard-smoke_stats_history.csv`
- `performance/locust/results/circleguard-smoke_failures.csv`
- `performance/locust/results/circleguard-smoke_exceptions.csv`
- `performance/locust/results/circleguard-load_stats.csv`
- `performance/locust/results/circleguard-load_stats_history.csv`
- `performance/locust/results/circleguard-load_failures.csv`
- `performance/locust/results/circleguard-load_exceptions.csv`

Escenarios implementados en `performance/locust/locustfile.py`:

- `gateway_qr_invalid_token`
- `identity_map`
- `identity_lookup_protected`
- `certificates_pending`
- `promotion_health_smoke`

Metricas agregadas smoke, fuente `performance/locust/results/circleguard-smoke_stats.csv`:

- Requests totales: `70`
- Failures: `0`
- Error rate: `0.00%`
- Average response time: `68.63 ms`
- p50: `45 ms`
- p95: `160 ms`
- p99: `1600 ms`
- Throughput: `2.48 req/s`
- Riesgo observado: outlier en `promotion_health_smoke`, maximo `1631.39 ms`.

Metricas agregadas load, fuente `performance/locust/results/circleguard-load_stats.csv`:

- Requests totales: `581`
- Failures: `0`
- Error rate: `0.00%`
- Average response time: `33.21 ms`
- p50: `47 ms`
- p95: `56 ms`
- p99: `66 ms`
- Throughput: `9.78 req/s`

Riesgo documental: `e2e/results/e2e-report.md` y `e2e/README.md` todavia dicen que Locust esta pendiente, lo cual contradice `performance/locust/README.md` y los CSVs existentes.

## 7. Estado de Jenkins dev/stage/master

### Dev

Estado: **PARCIAL**.

Evidencia:

- `Jenkinsfile`
- `docs/jenkins.md`

Stages reales encontrados:

- `Checkout`
- `Environment Info`
- `Run Selected Service Tests`
- `Build Boot JARs`
- `Build Docker Images`
- `Validate Docker Compose Config`
- `Generate Release Notes`
- `Archive Test Reports`

Riesgos:

- No hay evidencia versionada de ejecucion real en Jenkins.
- No hay deploy real en dev; solo validacion `docker compose config`.
- No existe `release-notes/RELEASE_NOTES.md` en el workspace auditado; se genera dinamicamente dentro del job.

### Stage

Estado: **PARCIAL**.

Evidencia:

- `Jenkinsfile.stage`
- `docs/jenkins-stage-master.md`

Stages reales encontrados:

- `Run Unit/Integration Tests`
- `Build Boot JARs`
- `Build Docker Images`
- `Validate Kubernetes Manifests`
- `Deploy to Kubernetes Stage`
- `Run E2E Against Stage`
- `Archive Artifacts`

Riesgos:

- `DEPLOY_TO_K8S=false` por defecto.
- Si no se cambia el parametro, ejecuta `kubectl apply --dry-run=client -f k8s/dev/`, no deploy real.
- Sin evidencia de pruebas ejecutadas contra aplicacion desplegada en Kubernetes stage.
- En agente Linux sin `pwsh`, el stage E2E puede no ejecutarse y solo quedar documentado.

### Master

Estado: **PARCIAL**.

Evidencia:

- `Jenkinsfile.master`
- `docs/jenkins-stage-master.md`

Stages reales encontrados:

- `Run Full Test Suite`
- `Build Boot JARs`
- `Build Docker Images`
- `Validate Docker Compose Config`
- `Validate Kubernetes Manifests`
- `Run E2E Smoke + Functional`
- `Run Locust Smoke`
- `Deploy to Kubernetes Master`
- `Generate Release Notes`
- `Archive Release Artifacts`

Riesgos:

- `DEPLOY_TO_K8S=false` por defecto; deploy real queda condicionado.
- No hay evidencia de Jenkins master ejecutado con exito.
- Release notes automaticas estan implementadas en pipeline, pero no hay artefacto real versionado de una ejecucion Jenkins.
- No hay registry remoto ni publicacion de imagenes.

## 8. Estado de Kubernetes

Estado: **PARCIAL**.

Manifests reales encontrados:

- `k8s/dev/namespace.yaml`
- `k8s/dev/configmap.yaml`
- `k8s/dev/secrets.yaml`
- `k8s/dev/auth-service.yaml`
- `k8s/dev/identity-service.yaml`
- `k8s/dev/promotion-service.yaml`
- `k8s/dev/notification-service.yaml`
- `k8s/dev/form-service.yaml`
- `k8s/dev/gateway-service.yaml`
- `k8s/dev/postgres.yaml`
- `k8s/dev/redis.yaml`
- `k8s/dev/neo4j.yaml`
- `k8s/dev/zookeeper.yaml`
- `k8s/dev/kafka.yaml`
- `k8s/dev/openldap.yaml`
- `k8s/README.md`

Cobertura real:

- Namespace: `circleguard-dev`.
- Apps: 6 microservicios con `Deployment` y `Service`.
- Middleware: PostgreSQL, Redis, Neo4j, Zookeeper, Kafka, OpenLDAP.
- Imagenes de apps referenciadas como `circleguard-*-service:dev`.
- Probes TCP en servicios de aplicacion.

Riesgos:

- `k8s/README.md` declara que no se ha validado en cluster real.
- No hay evidencia de `kubectl get pods`, logs de pods, rollout exitoso ni pruebas contra servicios en Kubernetes.
- No hay Ingress.
- No hay registry remoto; las imagenes locales `:dev` pueden no existir dentro del runtime del cluster.
- Kafka y middleware son base dev, no produccion.

## 9. Gaps criticos ordenados por impacto

1. **Falta evidencia real de Jenkins ejecutando dev/stage/master.** Existen Jenkinsfiles, pero no hay capturas, logs, artefactos generados por job ni release notes archivadas desde Jenkins.
2. **Falta validacion real en Kubernetes.** Hay manifests completos, pero no hay evidencia de cluster, pods corriendo, services, logs ni pruebas E2E contra Kubernetes.
3. **E2E no alcanza 5 flujos funcionales completos.** Los 5 checks principales son smoke/reachability; los funcionales tienen 2 PASS, 1 `BLOCKED_BY_AUTH` y 1 `SKIPPED_NO_SEED`.
4. **Stage/master no despliegan por defecto.** `DEPLOY_TO_K8S=false` evita despliegues accidentales, pero para la rubrica se necesita evidencia de deploy real o justificar claramente el alcance.
5. **No hay registry ni estrategia de publicacion de imagenes.** Docker build local existe, pero Kubernetes y Jenkins stage/master quedan limitados si el cluster no comparte daemon.
6. **Documentacion final/video/zip no estan cerrados.** La rubrica exige documento/video y zip final; no se encontraron como entregables finales.
7. **Inconsistencia documental sobre Locust.** `performance/locust/` esta completo, pero `e2e/README.md` y `e2e/results/e2e-report.md` dicen que Locust sigue pendiente.
8. **Docs Docker Compose tienen un ejemplo desactualizado.** `docs/docker-compose.md` muestra comandos con `--build-arg JAR_FILE`, mientras `Dockerfile.service` usa `ARG SERVICE_NAME`.

## 10. Plan de cierre para llegar al DoD

1. Ejecutar `Jenkinsfile` dev en Jenkins real y guardar evidencia: consola, stages, JUnit publicados, artefactos y release notes generadas.
2. Ejecutar `Jenkinsfile.stage` con un agente que tenga Docker, `kubectl`, PowerShell/pwsh y kubeconfig valido. Para cumplir la rubrica, correr al menos una vez con `DEPLOY_TO_K8S=true`.
3. Ejecutar `Jenkinsfile.master` con `DEPLOY_TO_K8S=true` o documentar una limitacion formal si no hay cluster disponible. Guardar `release-notes/RELEASE_NOTES.md` como artefacto de evidencia.
4. Validar Kubernetes real: `kubectl apply -f k8s/dev/`, `kubectl get pods -n circleguard-dev`, `kubectl get svc -n circleguard-dev`, logs de pods clave y prueba HTTP contra servicios expuestos por port-forward o ingress.
5. Cerrar E2E funcional: agregar seed data y credenciales/JWT de test para convertir `Identity map/lookup` y `Promotion health recovery` en PASS reales, y sumar al menos un flujo funcional adicional defendible.
6. Mantener los 5 smoke checks como evidencia operacional, pero no contarlos como 5 E2E funcionales completos en la entrega.
7. Corregir documentacion: actualizar `e2e/README.md` y `e2e/results/e2e-report.md` para no decir que Locust esta pendiente; corregir `docs/docker-compose.md` para usar `SERVICE_NAME`.
8. Consolidar documento final del taller con configuracion, resultados, analisis, metricas Locust, capturas Jenkins/Kubernetes y limitaciones reales.
9. Preparar guion/video de maximo 8 minutos mostrando Jenkins, Docker Compose, pruebas, Locust y Kubernetes.
10. Generar zip final con pipelines, pruebas, proyecto modificado, documentacion y evidencias.
