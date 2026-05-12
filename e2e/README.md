# CircleGuard - E2E Test Suite

> Taller de Pruebas y Release 261 - rama `master`

## Objetivo

Esta suite es ahora hibrida:

- Smoke / operational E2E: valida que el stack Docker Compose este levantado, que los contenedores criticos corran y que los servicios respondan HTTP.
- Functional E2E: ejecuta flujos REST reales cuando existen endpoints disponibles y cuando la seguridad/seed data lo permiten.

El script genera evidencia reproducible en Markdown y termina con `exit code 1` si falla un smoke critico o si un functional check clasificado como `FAIL` detecta un endpoint que deberia funcionar.

## Prerrequisitos

| Requisito | Version minima |
|-----------|----------------|
| Docker Desktop (Windows) | 24.x o superior |
| PowerShell | 5.1 o superior |
| Stack Compose levantado | `docker-compose.dev.yml` + `docker-compose.app.yml` |

Levantar el stack desde la raiz del proyecto:

```powershell
docker compose -f docker-compose.dev.yml -f docker-compose.app.yml up -d
```

Ejecutar la suite:

```powershell
powershell -ExecutionPolicy Bypass -File e2e/run-e2e.ps1
```

## Smoke / Operational Checks

Los 5 smoke checks actuales se mantienen como criticos:

| # | Check | Endpoint | Criterio |
|---|-------|----------|----------|
| 1 | auth-service | `http://localhost:8180/actuator/health` | Cualquier HTTP aceptable prueba reachability. |
| 2 | identity-service | `http://localhost:8083/actuator/health` | `401/403/404` tambien prueban que Spring Boot responde. |
| 3 | form-service | `http://localhost:8086/actuator/health` | Valida reachability del servicio dependiente de PostgreSQL/Kafka. |
| 4 | gateway-service | `http://localhost:8087/actuator/health` | Valida reachability del gateway y stack Redis asociado. |
| 5 | promotion-service + Neo4j | `http://localhost:8088/actuator/health` | Valida reachability del servicio y health real de `circleguard-neo4j`. |

Codigos HTTP aceptados como evidencia operacional:

`200, 201, 204, 301, 302, 400, 401, 403, 404, 405`

Tambien se captura reachability adicional de `notification-service` en `http://localhost:8082/actuator/health`. No se cuenta como functional E2E porque el servicio no expone controllers REST de negocio; su comportamiento principal esta basado en listeners Kafka.

## Functional E2E Flows

| Flow | Endpoint(s) | Comportamiento esperado |
|------|-------------|-------------------------|
| Identity map/lookup | `POST /api/v1/identities/map`, `GET /api/v1/identities/lookup/{id}` | Crea un `anonymousId`; lookup pasa si hay token valido o queda `BLOCKED_BY_AUTH` si Spring Security bloquea sin JWT. |
| Certificates/Form | `GET /api/v1/certificates/pending` | Pasa con `200`, incluso si devuelve lista vacia por falta de seed surveys. |
| Promotion recovery | `POST /api/v1/health/recovery/{id}` | Se ejecuta solo si existe un id seed valido y credenciales `HEALTH_CENTER`; si no, queda `SKIPPED_NO_SEED`. |
| Gateway route | `POST /api/v1/gate/validate` | Procesa un token QR intencionalmente invalido y debe responder `RED`/invalid sin usar credenciales reales. |
| Notification reachability | `GET /actuator/health` en puerto `8082` | Se registra como evidencia operacional adicional, no como flujo funcional de negocio. |

## Clasificaciones

| Estado | Significado | Afecta exit code |
|--------|-------------|------------------|
| `PASS` | El flujo funcional se ejecuto y valido el resultado esperado. | No |
| `FAIL` | El endpoint existe/deberia funcionar pero respondio de forma inesperada. | Si |
| `BLOCKED_BY_AUTH` | Seguridad real bloqueo el flujo sin JWT/credenciales seed. | No |
| `SKIPPED_NO_SEED` | No existe data semilla confiable para ejecutar el caso sin inventar datos. | No |
| `SKIPPED_NOT_AVAILABLE` | No hay endpoint/ruta real disponible para ese flujo. | No |

`BLOCKED_BY_AUTH` no es fallo de infraestructura. En esta suite es evidencia util de que Spring Security/JWT esta activo cuando no existen credenciales seed para automatizar el flujo completo.

## Reporte generado

El reporte se guarda en:

```text
e2e/results/e2e-report.md
```

Incluye:

- Fecha/hora y resultado global.
- Conteo smoke passed/failed.
- Conteo functional pass/fail/blocked/skipped.
- Tabla de los 5 smoke checks.
- Tabla de functional E2E checks.
- Snapshot de `docker ps`.
- Estado de Neo4j.
- Endpoints invocados y request bodies no sensibles.
- Limitaciones reales por auth, seed data y alcance.

## Limitaciones

- Los smoke checks validan disponibilidad real del stack, no logica profunda de negocio.
- Los functional checks validan endpoints reales solo cuando se puede hacerlo sin credenciales inventadas ni seed data inexistente.
- Flujos autenticados pueden quedar `BLOCKED_BY_AUTH` porque no hay usuarios/JWT seed reproducibles.
- Flujos dependientes de data de negocio pueden quedar `SKIPPED_NO_SEED`.
- Kafka y Redis se siguen validando indirectamente por endpoints dependientes.
- Esto no reemplaza pruebas Java de integracion, seguridad, contratos ni performance.
- Locust sigue pendiente para rendimiento.

## Estructura

```text
e2e/
|-- README.md
|-- run-e2e.ps1
`-- results/
    |-- .gitkeep
    `-- e2e-report.md
```

*CircleGuard E2E Suite v1.1.0 - Taller de Pruebas y Release 261*
