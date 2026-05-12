# Docker Compose para middleware y microservicios

Este repositorio separa el entorno Docker Compose en dos archivos:

- `docker-compose.dev.yml`: middleware compartido para desarrollo local.
- `docker-compose.app.yml`: microservicios Spring Boot empaquetados como imagenes locales `:dev`.

## Paso previo obligatorio

Antes de usar el compose de aplicaciones, primero deben existir los JARs y las imagenes Docker locales.

Referencia del flujo de build:

- `docs/dockerization.md`

Resumen:

```powershell
.\gradlew.bat bootJar
docker build -f Dockerfile.service -t circleguard-auth-service:dev --build-arg JAR_FILE=services/circleguard-auth-service/build/libs/circleguard-auth-service.jar .
docker build -f Dockerfile.service -t circleguard-identity-service:dev --build-arg JAR_FILE=services/circleguard-identity-service/build/libs/circleguard-identity-service.jar .
docker build -f Dockerfile.service -t circleguard-promotion-service:dev --build-arg JAR_FILE=services/circleguard-promotion-service/build/libs/circleguard-promotion-service.jar .
docker build -f Dockerfile.service -t circleguard-notification-service:dev --build-arg JAR_FILE=services/circleguard-notification-service/build/libs/circleguard-notification-service.jar .
docker build -f Dockerfile.service -t circleguard-form-service:dev --build-arg JAR_FILE=services/circleguard-form-service/build/libs/circleguard-form-service.jar .
docker build -f Dockerfile.service -t circleguard-gateway-service:dev --build-arg JAR_FILE=services/circleguard-gateway-service/build/libs/circleguard-gateway-service.jar .
```

## Validar la configuracion

Usar ambos archivos Compose juntos para compartir la misma red y resolver los servicios por DNS interno.

```powershell
docker compose -f docker-compose.dev.yml -f docker-compose.app.yml config
```

## Levantar solo middleware

```powershell
docker compose -f docker-compose.dev.yml up -d
```

Servicios incluidos:

- PostgreSQL
- Neo4j
- Zookeeper
- Kafka
- Redis
- OpenLDAP

Kafka expone dos formas de acceso:

- `localhost:9092`: acceso desde el host.
- `kafka:29092`: acceso interno entre contenedores en la red de Compose.

Los microservicios del archivo `docker-compose.app.yml` usan `kafka:29092`.

## Levantar middleware y aplicaciones

```powershell
docker compose -f docker-compose.dev.yml -f docker-compose.app.yml up -d
```

## Inspeccionar logs

Logs del middleware:

```powershell
docker compose -f docker-compose.dev.yml logs -f
```

Logs de un servicio especifico:

```powershell
docker compose -f docker-compose.dev.yml -f docker-compose.app.yml logs -f auth-service
docker compose -f docker-compose.dev.yml -f docker-compose.app.yml logs -f promotion-service
docker compose -f docker-compose.dev.yml -f docker-compose.app.yml logs -f gateway-service
```

## Limitaciones conocidas

- `depends_on` solo ordena arranque; no garantiza readiness de PostgreSQL, Kafka, Neo4j, Redis u OpenLDAP.
- Los `healthcheck` y estrategias de espera pueden mejorarse mas adelante.
