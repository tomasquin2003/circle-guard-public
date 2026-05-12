# Dockerizacion de microservicios Spring Boot

## Objetivo

En esta fase se usa un unico `Dockerfile.service` parametrizable para empaquetar imagenes reproducibles desde la raiz del monorepo `circle-guard-public`. La estrategia se ajusto para separar responsabilidades:

- Gradle compila y genera los JARs.
- Docker solo empaqueta el artefacto ya construido.

Esto evita depender de descargas de Gradle dentro del build Docker y encaja mejor con Jenkins.

## Servicios cubiertos

El Dockerfile cubre estos seis microservicios:

- `circleguard-auth-service`
- `circleguard-identity-service`
- `circleguard-promotion-service`
- `circleguard-notification-service`
- `circleguard-form-service`
- `circleguard-gateway-service`

## Por que se usa un Dockerfile parametrizable

- Todos los servicios seleccionados comparten la misma base tecnica: monorepo Gradle, Spring Boot y Java 21.
- Todos exponen el mismo patron de empaquetado: un `bootJar` ejecutado con `java -jar`.
- Un unico Dockerfile reduce duplicacion y drift entre servicios.
- Jenkins puede reutilizar la misma receta variando solo `SERVICE_NAME` y el tag.

## Estrategia de build

La imagen ya no compila codigo dentro de Docker. El flujo correcto es:

1. Ejecutar `bootJar` con Gradle para el servicio objetivo.
2. Construir la imagen Docker usando el JAR ya generado.

`Dockerfile.service` usa `eclipse-temurin:21-jre` como runtime base, copia los archivos desde `services/${SERVICE_NAME}/build/libs/`, localiza el JAR ejecutable y lo normaliza a `/app/app.jar`.

Esta estrategia evita el fallo observado cuando Gradle Wrapper intentaba descargar `gradle-8.14-bin.zip` dentro del contenedor y fallaba por resolucion DNS hacia `release-assets.githubusercontent.com`.

## Flujo recomendado para Jenkins

La secuencia recomendada en Jenkins es:

1. `test`
2. `bootJar`
3. `docker build`
4. Publicacion de imagen

Con esto, Jenkins valida primero el codigo y solo empaqueta artefactos ya generados por Gradle.

## Comandos de construccion

Servicio de autenticacion:

```powershell
.\gradlew.bat :services:circleguard-auth-service:bootJar --console=plain
docker build -f Dockerfile.service --build-arg SERVICE_NAME=circleguard-auth-service -t circleguard-auth-service:dev .
```

Servicio de identidad:

```powershell
.\gradlew.bat :services:circleguard-identity-service:bootJar --console=plain
docker build -f Dockerfile.service --build-arg SERVICE_NAME=circleguard-identity-service -t circleguard-identity-service:dev .
```

Servicio de promocion:

```powershell
.\gradlew.bat :services:circleguard-promotion-service:bootJar --console=plain
docker build -f Dockerfile.service --build-arg SERVICE_NAME=circleguard-promotion-service -t circleguard-promotion-service:dev .
```

Servicio de notificaciones:

```powershell
.\gradlew.bat :services:circleguard-notification-service:bootJar --console=plain
docker build -f Dockerfile.service --build-arg SERVICE_NAME=circleguard-notification-service -t circleguard-notification-service:dev .
```

Servicio de formularios:

```powershell
.\gradlew.bat :services:circleguard-form-service:bootJar --console=plain
docker build -f Dockerfile.service --build-arg SERVICE_NAME=circleguard-form-service -t circleguard-form-service:dev .
```

Servicio gateway:

```powershell
.\gradlew.bat :services:circleguard-gateway-service:bootJar --console=plain
docker build -f Dockerfile.service --build-arg SERVICE_NAME=circleguard-gateway-service -t circleguard-gateway-service:dev .
```

## Validacion

Para inspeccionar los JARs disponibles:

```powershell
Get-ChildItem -Recurse -Path .\services -Filter "*.jar" | ForEach-Object { $_.FullName }
```

Validacion inicial:

```powershell
.\gradlew.bat :services:circleguard-auth-service:bootJar --console=plain
docker build -f Dockerfile.service --build-arg SERVICE_NAME=circleguard-auth-service -t circleguard-auth-service:dev .

.\gradlew.bat :services:circleguard-identity-service:bootJar --console=plain
docker build -f Dockerfile.service --build-arg SERVICE_NAME=circleguard-identity-service -t circleguard-identity-service:dev .
```

Si ambos pasan, continuar con:

```powershell
.\gradlew.bat :services:circleguard-promotion-service:bootJar --console=plain
docker build -f Dockerfile.service --build-arg SERVICE_NAME=circleguard-promotion-service -t circleguard-promotion-service:dev .

.\gradlew.bat :services:circleguard-notification-service:bootJar --console=plain
docker build -f Dockerfile.service --build-arg SERVICE_NAME=circleguard-notification-service -t circleguard-notification-service:dev .

.\gradlew.bat :services:circleguard-form-service:bootJar --console=plain
docker build -f Dockerfile.service --build-arg SERVICE_NAME=circleguard-form-service -t circleguard-form-service:dev .

.\gradlew.bat :services:circleguard-gateway-service:bootJar --console=plain
docker build -f Dockerfile.service --build-arg SERVICE_NAME=circleguard-gateway-service -t circleguard-gateway-service:dev .
```

## Pendiente para siguientes fases

### `docker-compose`

- Definir variables de entorno por servicio.
- Modelar dependencias compartidas como PostgreSQL, Redis, Kafka y Neo4j.
- Separar perfiles de desarrollo local y pruebas integradas.

### Kubernetes

- Crear manifests o charts por servicio.
- Declarar `ConfigMap`, `Secret`, `Service`, `Deployment` e `Ingress` segun cada microservicio.
- Anadir probes, requests/limits y estrategia de rollout.
- Integrar publicacion de imagenes desde Jenkins hacia un registry.
