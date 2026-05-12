# CircleGuard Locust performance suite

## Objetivo

Esta suite ejecuta pruebas de rendimiento y estres con Locust sobre endpoints REST representativos de CircleGuard. Los escenarios simulan flujos realistas sin depender de credenciales reales, usuarios seed, npm, Newman ni jq.

La suite cubre:

- Validacion de QR invalido o expirado en `gateway-service`.
- Creacion/mapeo de identidad sintetica en `identity-service`.
- Consulta protegida de identidad cuando existe `anonymousId`.
- Consulta de certificados pendientes en `form-service`.
- Smoke de negocio/reachability en `promotion-service` usando un endpoint publico real.

## Prerrequisitos

El stack Docker Compose debe estar arriba y exponiendo los servicios en el host:

- `auth-service`: `http://localhost:8180`
- `identity-service`: `http://localhost:8083`
- `notification-service`: `http://localhost:8082`
- `form-service`: `http://localhost:8086`
- `gateway-service`: `http://localhost:8087`
- `promotion-service`: `http://localhost:8088`

Comando de referencia:

```powershell
docker compose -f docker-compose.dev.yml -f docker-compose.app.yml up -d
```

## Instalacion

```powershell
pip install -r performance/locust/requirements.txt
```

## Ejecucion con UI

```powershell
locust -f performance/locust/locustfile.py --host http://localhost
```

Luego abrir la UI de Locust y configurar usuarios, spawn rate y duracion segun el objetivo de la prueba.

## Ejecucion headless sugerida

```powershell
locust -f performance/locust/locustfile.py --host http://localhost --headless -u 10 -r 2 -t 1m --csv performance/locust/results/circleguard
```

Los endpoints usan `localhost` por defecto. Si se ejecuta desde otro entorno, se pueden ajustar con variables:

```powershell
$env:CIRCLEGUARD_GATEWAY_URL="http://localhost:8087"
$env:CIRCLEGUARD_IDENTITY_URL="http://localhost:8083"
$env:CIRCLEGUARD_FORM_URL="http://localhost:8086"
$env:CIRCLEGUARD_PROMOTION_URL="http://localhost:8088"
```

## Escenarios implementados

| Escenario | Endpoint | Expectativa |
| --- | --- | --- |
| `gateway_qr_invalid_token` | `POST http://localhost:8087/api/v1/gate/validate` | `200` con respuesta `RED`/invalid, o `401/403` si seguridad bloquea. |
| `identity_map` | `POST http://localhost:8083/api/v1/identities/map` | `200` con `anonymousId` usando identidad sintetica unica por usuario virtual. |
| `identity_lookup_protected` | `GET http://localhost:8083/api/v1/identities/lookup/{anonymousId}` | `200` con body valido si esta autorizado, o `401/403` clasificado como seguridad activa. |
| `certificates_pending` | `GET http://localhost:8086/api/v1/certificates/pending` | `200` con lista vacia/datos, o `401/403` clasificado como seguridad activa. |
| `promotion_health_smoke` | `GET http://localhost:8088/api/v1/health-status/stats` | `200` con metricas agregadas publicas. Se prefirio este endpoint real sobre `/actuator/health`, que en este repo puede devolver `404`. |

## Clasificacion de resultados

No se consideran fallos de infraestructura:

- `401` o `403` en endpoints protegidos cuando la seguridad bloquea una peticion sin JWT.
- Respuestas funcionales esperadas como QR invalido `RED`.

Si se consideran fallos:

- Timeouts o connection refused.
- Cualquier respuesta `5xx`.
- Body invalido cuando el escenario espera JSON.
- Falta de campos esperados como `anonymousId`, `realIdentity`, `totalUsers` o una lista de certificados.

## Metricas a reportar

- Requests totales.
- Failures.
- Average response time.
- Percentiles p50, p95 y p99.
- RPS.
- Error rate.

## Analisis esperado

Al interpretar resultados se debe revisar:

- Tiempo de respuesta promedio y percentiles, especialmente p95/p99.
- Throughput efectivo en RPS.
- Tasa de errores y si corresponden a infraestructura, seguridad esperada o validacion funcional.
- Endpoints mas lentos.
- Limitaciones por autenticacion, ausencia de seed data y dependencia del estado local de Docker Compose.

## Resultados reales

Ejecucion local validada el 2026-05-11 en Windows sobre el stack Docker Compose expuesto en `localhost`.

Validacion de entorno:

```powershell
python --version
pip --version
py --version
py -m pip --version
locust --version
python -m locust --version
```

Resultado validado:

- `python --version` -> `Python 3.12.0`
- `pip --version` -> `pip 23.2.1`
- `py --version` -> `Python 3.12.0`
- `py -m pip --version` -> `pip 23.2.1`
- `locust --version` -> `locust 2.32.6`
- `python -m locust --version` -> `locust 2.32.6`

Ejecuciones headless realizadas:

```powershell
locust -f performance/locust/locustfile.py --host http://localhost --headless -u 5 -r 1 -t 30s --csv performance/locust/results/circleguard-smoke
locust -f performance/locust/locustfile.py --host http://localhost --headless -u 20 -r 5 -t 1m --csv performance/locust/results/circleguard-load
```

Archivos generados:

- `performance/locust/results/circleguard-smoke_stats.csv`
- `performance/locust/results/circleguard-smoke_stats_history.csv`
- `performance/locust/results/circleguard-smoke_failures.csv`
- `performance/locust/results/circleguard-smoke_exceptions.csv`
- `performance/locust/results/circleguard-load_stats.csv`
- `performance/locust/results/circleguard-load_stats_history.csv`
- `performance/locust/results/circleguard-load_failures.csv`
- `performance/locust/results/circleguard-load_exceptions.csv`

### Smoke headless

Fuente: `performance/locust/results/circleguard-smoke_stats.csv`

- Requests totales: `70`
- Failures: `0`
- Error rate: `0.00%`
- Average response time agregada: `68.63 ms`
- p50 agregada: `45 ms`
- p95 agregada: `160 ms`
- p99 agregada: `1600 ms`
- Throughput agregado: `2.48 req/s`

Detalle por endpoint:

| Escenario | Requests | Failures | Avg | p50 | p95 | p99 | Max | RPS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `certificates_pending` | 16 | 0 | 25.67 ms | 11 ms | 160 ms | 160 ms | 158.70 ms | 0.57 |
| `gateway_qr_invalid_token` | 14 | 0 | 66.37 ms | 51 ms | 280 ms | 280 ms | 275.88 ms | 0.50 |
| `identity_lookup_protected` | 9 | 0 | 11.70 ms | 8 ms | 30 ms | 30 ms | 29.92 ms | 0.32 |
| `identity_map` | 25 | 0 | 52.98 ms | 53 ms | 88 ms | 120 ms | 116.82 ms | 0.89 |
| `identity_map_setup` | 1 | 0 | 259.35 ms | 260 ms | 260 ms | 260 ms | 259.35 ms | 0.04 |
| `promotion_health_smoke` | 5 | 0 | 354.96 ms | 45 ms | 1600 ms | 1600 ms | 1631.39 ms | 0.18 |

Observacion:

- El outlier del smoke estuvo en `promotion_health_smoke`, con un maximo de `1631.39 ms`, que elevo el promedio agregado y el p99.

### Load headless

Fuente: `performance/locust/results/circleguard-load_stats.csv`

- Requests totales: `581`
- Failures: `0`
- Error rate: `0.00%`
- Average response time agregada: `33.21 ms`
- p50 agregada: `47 ms`
- p95 agregada: `56 ms`
- p99 agregada: `66 ms`
- Throughput agregado: `9.78 req/s`

Detalle por endpoint:

| Escenario | Requests | Failures | Avg | p50 | p95 | p99 | Max | RPS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `certificates_pending` | 124 | 0 | 11.34 ms | 9 ms | 29 ms | 43 ms | 58.89 ms | 2.09 |
| `gateway_qr_invalid_token` | 156 | 0 | 47.23 ms | 50 ms | 58 ms | 66 ms | 67.13 ms | 2.63 |
| `identity_lookup_protected` | 79 | 0 | 5.28 ms | 5 ms | 10 ms | 11 ms | 11.22 ms | 1.33 |
| `identity_map` | 180 | 0 | 50.11 ms | 51 ms | 60 ms | 70 ms | 88.81 ms | 3.03 |
| `identity_map_setup` | 6 | 0 | 29.70 ms | 24 ms | 56 ms | 56 ms | 55.82 ms | 0.10 |
| `promotion_health_smoke` | 36 | 0 | 25.20 ms | 24 ms | 43 ms | 58 ms | 57.86 ms | 0.61 |

Conclusiones de esta corrida:

- La suite Locust quedo ejecutada exitosamente en smoke y load con `exit code 0`.
- No hubo `5xx`, timeouts ni `connection refused`.
- La corrida de carga fue mas estable que el smoke porque no repitio el outlier inicial observado en `promotion_health_smoke`.
- `identity_map` y `gateway_qr_invalid_token` concentraron la mayor parte del throughput funcional de la suite.
