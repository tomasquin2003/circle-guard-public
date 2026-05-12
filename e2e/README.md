# CircleGuard – E2E Test Suite

> **Taller de Pruebas y Release 261** · rama `master`

---

## Objetivo

Esta suite valida la **disponibilidad operacional end-to-end** del stack de microservicios de CircleGuard desplegado localmente con Docker Compose.

No es una suite de regresión funcional completa; su propósito es:

1. Confirmar que todos los contenedores críticos están corriendo.
2. Verificar que cada microservicio responde a peticiones HTTP (smoke check).
3. Generar un reporte estructurado en Markdown que sirva de evidencia reproducible.
4. Fallar con `exit code 1` si algún servicio no responde, para integración con pipelines CI/CD.

---

## Prerrequisitos

| Requisito | Versión mínima |
|-----------|---------------|
| Docker Desktop (Windows) | 24.x o superior |
| PowerShell | 5.1 o superior (incluido en Windows 10/11) |
| Stack Compose levantado | ver sección siguiente |

---

## Levantar el stack

Desde la raíz del proyecto:

```powershell
docker compose -f docker-compose.dev.yml -f docker-compose.app.yml up -d
```

Verificar que los contenedores estén `Up`:

```powershell
docker ps --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}"
```

Servicios esperados y puertos:

| Servicio | Puerto host |
|----------|------------|
| `circleguard-auth-service` | 8180 |
| `circleguard-identity-service` | 8083 |
| `circleguard-notification-service` | 8082 |
| `circleguard-form-service` | 8086 |
| `circleguard-gateway-service` | 8087 |
| `circleguard-promotion-service` | 8088 |
| `circleguard-postgres` | 5432 |
| `circleguard-neo4j` | 7474 / 7687 |
| `circleguard-kafka` | 9092 |
| `circleguard-redis` | 6379 |
| `circleguard-ldap` | 389 / 636 |
| `circleguard-zookeeper` | — |

---

## Ejecutar la suite E2E

Desde la raíz del proyecto:

```powershell
powershell -ExecutionPolicy Bypass -File e2e/run-e2e.ps1
```

El script:
1. Verifica el daemon Docker.
2. Muestra el estado actual de contenedores.
3. Ejecuta los 5 checks E2E.
4. Genera `e2e/results/e2e-report.md`.
5. Termina con `exit 0` (todo OK) o `exit 1` (algún fallo).

---

## Los 5 checks E2E

### Check 1 – auth-service HTTP reachability

| Campo | Detalle |
|-------|---------|
| **URL** | `http://localhost:8180/actuator/health` |
| **Contenedor** | `circleguard-auth-service` |
| **Códigos aceptables** | 200, 401, 403, 404 |
| **Qué valida** | El servidor Spring Boot de autenticación (LDAP + PostgreSQL) está arriba y acepta conexiones TCP/HTTP. |
| **Limitación** | No se realiza autenticación real; no se verifica que LDAP esté correctamente seedado. |

---

### Check 2 – identity-service HTTP reachability

| Campo | Detalle |
|-------|---------|
| **URL** | `http://localhost:8083/actuator/health` |
| **Contenedor** | `circleguard-identity-service` |
| **Códigos aceptables** | 200, 401, 403, 404 |
| **Qué valida** | El microservicio de identidad (perfiles de usuario, PostgreSQL) está corriendo. Un 401/403 es PASS porque demuestra que el servidor responde. |
| **Limitación** | No se validan endpoints de negocio ni se prueban tokens JWT. |

---

### Check 3 – form-service HTTP reachability

| Campo | Detalle |
|-------|---------|
| **URL** | `http://localhost:8086/actuator/health` |
| **Contenedor** | `circleguard-form-service` |
| **Códigos aceptables** | 200, 401, 403, 404 |
| **Qué valida** | El microservicio de formularios (PostgreSQL + Kafka) está corriendo. Si pasa, confirma que las dependencias de infraestructura (DB y bus de eventos) también están funcionales. |
| **Limitación** | No se envían formularios ni se verifica Kafka end-to-end. |

---

### Check 4 – gateway-service HTTP reachability

| Campo | Detalle |
|-------|---------|
| **URL** | `http://localhost:8087/actuator/health` |
| **Contenedor** | `circleguard-gateway-service` |
| **Códigos aceptables** | 200, 401, 403, 404 |
| **Qué valida** | El API Gateway (Spring Cloud Gateway + Redis) está operativo. Este es el punto de entrada único para tráfico externo; su disponibilidad implica que Redis y el enrutamiento funcionan. |
| **Limitación** | No se prueban rutas específicas del gateway ni se valida rate-limiting. |

---

### Check 5 – promotion-service + Neo4j health

| Campo | Detalle |
|-------|---------|
| **URL** | `http://localhost:8088/actuator/health` |
| **Contenedor** | `circleguard-promotion-service` (+ sub-check `circleguard-neo4j`) |
| **Códigos aceptables** | 200, 401, 403, 404 |
| **Qué valida** | El microservicio de promociones (PostgreSQL + Neo4j + Kafka + Redis) responde HTTP. Al tener la cadena de dependencias más larga, un PASS aquí confirma que el stack completo de infraestructura está operativo. Se realiza también un sub-check del estado del contenedor `circleguard-neo4j`. |
| **Limitación** | No se ejecutan queries Cypher; la salud de Neo4j se infiere del estado del contenedor y del health check interno de Docker. |

---

## Reporte generado

El reporte se guarda en:

```
e2e/results/e2e-report.md
```

Contiene:
- Fecha/hora de ejecución.
- Tabla resumen con todos los checks (URL, contenedor, HTTP status, PASS/FAIL).
- Descripción detallada de cada check.
- Snapshot de `docker ps` en el momento de ejecución.
- Lista de códigos HTTP aceptables.
- Sección de limitaciones.

---

## Códigos HTTP aceptables

Los siguientes códigos son considerados **PASS** (el servicio está vivo):

`200, 201, 204, 301, 302, 400, 401, 403, 404, 405`

Un timeout, `connection refused`, error DNS, o contenedor en estado no-`running` = **FAIL**.

---

## Limitaciones

| Limitación | Razón |
|-----------|-------|
| No cubre flujos autenticados completos | No existe seed data de usuarios por defecto; los tokens JWT/LDAP no pueden generarse automáticamente sin credenciales reales. |
| Es una suite E2E smoke/operacional | El objetivo es evidencia de disponibilidad, no cobertura de regresión funcional. |
| Kafka y Redis no se verifican directamente | Se infieren como saludables si los servicios dependientes (form-service, gateway-service, promotion-service) responden HTTP. |
| Neo4j verificado por estado de contenedor | No se ejecutan queries Cypher; el health check de Docker es suficiente para evidencia smoke. |
| notification-service no tiene check dedicado | Su puerto (8082) no está expuesto al host en la configuración actual de Docker Compose; se verifica indirectamente a través del stack. |

---

## Estructura del directorio `e2e/`

```
e2e/
├── README.md          ← Este archivo
├── run-e2e.ps1        ← Script principal E2E (PowerShell)
└── results/
    ├── .gitkeep       ← Mantiene la carpeta en git
    └── e2e-report.md  ← Generado al ejecutar la suite
```

---

## Funciones del script

| Función | Propósito |
|---------|-----------|
| `Assert-DockerContainerRunning` | Verifica vía `docker inspect` que el contenedor está en estado `running`. |
| `Test-HttpEndpoint` | Hace `Invoke-WebRequest` al endpoint, maneja excepciones HTTP y de red, devuelve hashtable con resultado. |
| `Write-Result` | Imprime el resultado en consola (coloreado) y lo registra en la lista global. |
| `Write-MarkdownReport` | Genera el reporte Markdown final en `e2e/results/e2e-report.md`. |
| `Get-DockerSummary` | Captura el output de `docker ps` para incluirlo en el reporte. |

---

*CircleGuard E2E Suite v1.0.0 · Taller de Pruebas y Release 261*
