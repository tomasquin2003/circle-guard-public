# Jenkins pipeline base para dev

## Objetivo

Este documento describe el `Jenkinsfile` base para ambiente dev del repositorio `circle-guard-public`. El pipeline automatiza el flujo ya validado manualmente para los seis microservicios seleccionados:

1. `test`
2. `bootJar`
3. `docker build`
4. `docker compose config`

La intencion es dejar una base clara y documentable para el taller, sin deploy real, sin registry y sin Kubernetes todavia.

## Servicios incluidos

- `circleguard-auth-service`
- `circleguard-identity-service`
- `circleguard-promotion-service`
- `circleguard-notification-service`
- `circleguard-form-service`
- `circleguard-gateway-service`

## Prerequisitos del agente Jenkins

El `Jenkinsfile` esta orientado preferiblemente a un agente Linux con acceso a Docker. Antes de ejecutarlo, el nodo debe contar con:

- Java 21 disponible en `PATH`
- Gradle Wrapper funcional desde la raiz del repositorio
- Docker CLI disponible
- Docker Compose plugin disponible mediante `docker compose`
- Acceso al Docker daemon para construir imagenes locales

Nota importante:
En Windows local se usa `gradlew.bat`, pero este pipeline esta pensado primero para agentes Linux. El `Jenkinsfile` incluye logica con `isUnix()` para usar `./gradlew` en Unix y `gradlew.bat` en Windows si fuera necesario.

## Stages del pipeline

### 1. `Checkout`

Realiza `checkout scm` desde Jenkins. No agrega logica adicional de ramas ni credenciales especiales.

### 2. `Environment Info`

Imprime versiones de herramientas base para dejar trazabilidad del entorno:

```bash
java --version
./gradlew --version
docker --version
docker compose version
```

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

Construye los artefactos ejecutables `bootJar` para los mismos seis servicios:

```bash
./gradlew \
  :services:circleguard-auth-service:bootJar \
  :services:circleguard-identity-service:bootJar \
  :services:circleguard-promotion-service:bootJar \
  :services:circleguard-notification-service:bootJar \
  :services:circleguard-form-service:bootJar \
  :services:circleguard-gateway-service:bootJar \
  --console=plain --no-daemon
```

### 5. `Build Docker Images`

Construye imagenes locales `:dev` usando `Dockerfile.service` y el argumento `SERVICE_NAME`:

```bash
docker build -f Dockerfile.service --build-arg SERVICE_NAME=circleguard-auth-service -t circleguard-auth-service:dev .
docker build -f Dockerfile.service --build-arg SERVICE_NAME=circleguard-identity-service -t circleguard-identity-service:dev .
docker build -f Dockerfile.service --build-arg SERVICE_NAME=circleguard-promotion-service -t circleguard-promotion-service:dev .
docker build -f Dockerfile.service --build-arg SERVICE_NAME=circleguard-notification-service -t circleguard-notification-service:dev .
docker build -f Dockerfile.service --build-arg SERVICE_NAME=circleguard-form-service -t circleguard-form-service:dev .
docker build -f Dockerfile.service --build-arg SERVICE_NAME=circleguard-gateway-service -t circleguard-gateway-service:dev .
```

Este pipeline no publica imagenes a ningun registry. Solo deja imagenes locales listas para siguientes fases.

### 6. `Validate Docker Compose Config`

Valida que la composicion entre middleware y apps sea consistente:

```bash
docker compose -f docker-compose.dev.yml -f docker-compose.app.yml config
```

En esta fase no se ejecuta `docker compose up`. Solo se valida la configuracion combinada.

### 7. `Archive Test Reports`

Publica reportes JUnit y archiva artefactos utiles del taller:

- `services/**/build/test-results/test/*.xml`
- `services/**/build/libs/*.jar`
- `docs/*.md`
- `TALLER_PROGRESS.md`

Ademas de este stage, el `post { always { ... } }` repite la publicacion para intentar conservar evidencia incluso si una etapa previa falla.

## Comandos manuales equivalentes

### Informacion de entorno

```bash
java --version
./gradlew --version
docker --version
docker compose version
```

### Tests

```bash
./gradlew :services:circleguard-auth-service:test \
  :services:circleguard-identity-service:test \
  :services:circleguard-promotion-service:test \
  :services:circleguard-notification-service:test \
  :services:circleguard-form-service:test \
  :services:circleguard-gateway-service:test \
  --console=plain --no-daemon
```

### Boot JARs

```bash
./gradlew :services:circleguard-auth-service:bootJar \
  :services:circleguard-identity-service:bootJar \
  :services:circleguard-promotion-service:bootJar \
  :services:circleguard-notification-service:bootJar \
  :services:circleguard-form-service:bootJar \
  :services:circleguard-gateway-service:bootJar \
  --console=plain --no-daemon
```

### Imagenes Docker locales

```bash
docker build -f Dockerfile.service --build-arg SERVICE_NAME=circleguard-auth-service -t circleguard-auth-service:dev .
docker build -f Dockerfile.service --build-arg SERVICE_NAME=circleguard-identity-service -t circleguard-identity-service:dev .
docker build -f Dockerfile.service --build-arg SERVICE_NAME=circleguard-promotion-service -t circleguard-promotion-service:dev .
docker build -f Dockerfile.service --build-arg SERVICE_NAME=circleguard-notification-service -t circleguard-notification-service:dev .
docker build -f Dockerfile.service --build-arg SERVICE_NAME=circleguard-form-service -t circleguard-form-service:dev .
docker build -f Dockerfile.service --build-arg SERVICE_NAME=circleguard-gateway-service -t circleguard-gateway-service:dev .
```

### Validacion Compose

```bash
docker compose -f docker-compose.dev.yml -f docker-compose.app.yml config
```

## Limitaciones actuales

- No publica imagenes a un Docker registry.
- No despliega a Kubernetes.
- No genera Release Notes automaticamente todavia.
- No ejecuta pruebas E2E todavia.
- No ejecuta escenarios Locust todavia.
- No hace `docker compose up` ni despliegue real.

## Proxima evolucion recomendada

- Pipeline para rama `stage`
- Pipeline para `master` o `release`
- Publicacion de imagenes a registry
- Generacion automatica de Release Notes
- Despliegue sobre Kubernetes
- Ejecucion de pruebas E2E y rendimiento como etapas separadas
