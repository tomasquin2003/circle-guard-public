# Jenkins pipeline dev/stage/master

## Objetivo

Este documento describe el `Jenkinsfile` principal del repositorio `circle-guard-public`. El pipeline conserva el flujo base de dev ya preparado para los seis microservicios seleccionados y agrega validaciones explicitas para stage y master sin afirmar despliegue real en Kubernetes.

Flujo cubierto:

1. `test`
2. `bootJar`
3. `docker build`
4. `docker compose config`
5. `kubectl apply --dry-run=client -f k8s/dev/`
6. `e2e/run-e2e.ps1`
7. Locust smoke headless
8. Master Release Notes automaticas

## Servicios incluidos

- `circleguard-auth-service`
- `circleguard-identity-service`
- `circleguard-promotion-service`
- `circleguard-notification-service`
- `circleguard-form-service`
- `circleguard-gateway-service`

## Prerequisitos del agente Jenkins

El agente debe tener:

- Java 21 disponible en `PATH`.
- Git y acceso al repositorio.
- Gradle Wrapper ejecutable desde la raiz del repo.
- Docker CLI y acceso al Docker daemon.
- Docker Compose plugin disponible mediante `docker compose`.
- `kubectl` disponible en `PATH` para el dry-run Kubernetes.
- Python disponible como `python`.
- Locust instalado en el entorno Python usado por Jenkins.
- PowerShell Windows para ejecutar `e2e/run-e2e.ps1` en agentes Windows.
- `pwsh` en Linux si se quiere ejecutar el E2E PowerShell desde un agente Linux.
- Stack Docker Compose levantado y alcanzable en `localhost` antes de ejecutar E2E y Locust.

Instalacion Locust de referencia:

```powershell
pip install -r performance/locust/requirements.txt
```

Levantar stack local requerido por E2E/Locust:

```powershell
docker compose -f docker-compose.dev.yml -f docker-compose.app.yml up -d
```

## Stages del pipeline

### 1. `Checkout`

Realiza `checkout scm` desde Jenkins.

### 2. `Environment Info`

Imprime versiones disponibles de Java, Gradle Wrapper, Docker, Docker Compose y, si existen, `kubectl` y Python. Si `kubectl` o Python no estan instalados, se documenta en consola y el stage correspondiente fallara con un mensaje explicito.

### 3. `Run Selected Service Tests`

Ejecuta pruebas Gradle de los seis servicios seleccionados:

```bash
./gradlew \
  :services:circleguard-auth-service:test \
  :services:circleguard-identity-service:test \
  :services:circleguard-promotion-service:test \
  :services:circleguard-notification-service:test \
  :services:circleguard-form-service:test \
  :services:circleguard-gateway-service:test \
  --console=plain --no-daemon
```

### 4. `Build Boot JARs`

Construye los artefactos ejecutables `bootJar` para los mismos seis servicios.

### 5. `Build Docker Images`

Construye imagenes locales `:dev` usando `Dockerfile.service` y el argumento `SERVICE_NAME`.

Este pipeline no publica imagenes a ningun registry. Solo deja imagenes locales para validaciones del agente.

### 6. `Validate Docker Compose Config`

Valida que la composicion entre middleware y apps sea consistente:

```bash
docker compose -f docker-compose.dev.yml -f docker-compose.app.yml config
```

Esta etapa no levanta el stack. Para E2E y Locust, el stack debe estar levantado previamente o por una preparacion externa del job.

### 7. `Stage Kubernetes Dry Run`

Valida los manifests Kubernetes sin desplegar:

```bash
kubectl apply --dry-run=client -f k8s/dev/
```

Esta etapa es evidencia de validacion de manifiestos. No se debe presentar como despliegue real en cluster.

### 8. `Run E2E Suite`

En agente Windows ejecuta:

```powershell
powershell -ExecutionPolicy Bypass -File e2e/run-e2e.ps1
```

En agente Linux intenta usar:

```bash
pwsh -ExecutionPolicy Bypass -File e2e/run-e2e.ps1
```

Si `pwsh` no existe, el stage deja una nota en consola. Para evidencia completa se recomienda usar un agente Windows o instalar PowerShell 7 en Linux.

### 9. `Run Locust Smoke`

Ejecuta un smoke de rendimiento contra el stack expuesto en `localhost`:

```bash
python -m locust -f performance/locust/locustfile.py --host http://localhost --headless -u 5 -r 1 -t 30s --csv performance/locust/results/jenkins-smoke
```

Si Python o Locust no estan disponibles, el pipeline falla con una explicacion explicita.

### 10. `Master Release Notes`

Genera `release-notes/RELEASE_NOTES.md` como artefacto del pipeline Jenkins.

Incluye:

- Numero de build.
- Nombre del job.
- Rama.
- Commit completo.
- Fecha/hora de generacion.
- Servicios seleccionados.
- Pruebas y validaciones ejecutadas: tests Gradle, `bootJar`, Docker build, Docker Compose config, Kubernetes dry-run, E2E y Locust smoke.
- Alcance de ambiente dev/stage/master.
- Ultimos 10 commits.

Estas release notes son tecnicas y automaticas. No crean tags Git, GitHub Releases ni una release formal publicada.

### 11. `Archive Test Reports`

Publica reportes JUnit y archiva artefactos utiles:

- `services/**/build/test-results/test/*.xml`
- `services/**/build/libs/*.jar`
- `docs/*.md`
- `release-notes/*.md`
- `TALLER_PROGRESS.md`
- `e2e/results/*.md`
- `performance/locust/results/*.csv`
- `k8s/**/*.yaml`

## Limitaciones reales

- No se afirma despliegue real en Kubernetes; el `Jenkinsfile` principal ejecuta dry-run.
- No publica imagenes a un Docker registry.
- E2E y Locust requieren que el stack Compose este arriba y accesible en `localhost`.
- E2E depende de PowerShell. En Linux se requiere `pwsh`.
- Locust requiere Python y dependencias de `performance/locust/requirements.txt`.
- No se inventan credenciales, JWTs ni seed data; por eso algunos E2E pueden quedar `BLOCKED_BY_AUTH` o `SKIPPED_NO_SEED`.
- No crea tags Git ni GitHub Releases.

## Evidencia esperada para entrega

- Captura o log de Jenkins con todos los stages visibles.
- Consola del dry-run Kubernetes.
- Reporte `e2e/results/e2e-report.md`.
- CSVs Locust bajo `performance/locust/results/`.
- Artefacto `release-notes/RELEASE_NOTES.md` generado por Jenkins.
- Reportes JUnit publicados por Jenkins.
