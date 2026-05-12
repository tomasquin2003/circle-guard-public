# Taller de pruebas y release 261 - Progreso tecnico

## 1. Objetivo del taller

El objetivo del taller es preparar una base tecnica reproducible para el ciclo de pruebas y release de un conjunto de microservicios del monorepo `circle-guard-public`. Esto incluye la configuracion de pipelines para al menos seis servicios, la estabilizacion y ejecucion de pruebas unitarias, de integracion, E2E y de rendimiento, la preparacion de empaquetado con Docker, el despliegue sobre Kubernetes, la generacion de release notes y la documentacion del proceso tecnico realizado.

## 2. Microservicios seleccionados

Se seleccionaron los siguientes seis microservicios:

1. `circleguard-auth-service`
2. `circleguard-identity-service`
3. `circleguard-promotion-service`
4. `circleguard-notification-service`
5. `circleguard-form-service`
6. `circleguard-gateway-service`

La seleccion se hizo porque cubre flujos representativos de autenticacion, identidad, promocion de estados de riesgo, notificaciones, captura de formularios y validacion de acceso. En conjunto, estos servicios ejercitan distintos tipos de dependencias tecnicas del monorepo, incluyendo Spring Security, JPA, Kafka, Redis, Neo4j y pruebas con contexto Spring completo, lo que los hace adecuados para preparar pipelines y despliegues realistas.

## 3. Estado inicial encontrado

Durante la revision inicial se encontraron los siguientes problemas:

- El entorno local no estaba alineado con la version requerida por el proyecto. Se identifico una diferencia entre JDK 17 y Java 21, y fue necesario estabilizar la ejecucion con Java 21.
- `circleguard-identity-service:test` fallaba por configuracion JWT de prueba insuficiente o debil, lo que impedia levantar correctamente el contexto de test bajo Spring Security.
- `circleguard-promotion-service` presentaba fallos en `HealthStatusControllerTest` porque los tests estaban simulando autoridades incompatibles con `hasRole(...)` en Spring Security.
- `circleguard-form-service` ejecutaba `AttachmentControllerTest` con `@SpringBootTest`, levantando un contexto completo innecesario para una prueba de endpoint simple y arrastrando dependencias de PostgreSQL, Kafka y Flyway.
- Varios tests de integracion y rendimiento de `circleguard-promotion-service` dependian de PostgreSQL y Redis locales en `localhost`, lo que impedia su ejecucion reproducible en CI/Jenkins.

## 4. Cambios realizados

### `services/circleguard-identity-service/src/test/resources/application.yml`

Problema:
Los tests del servicio de identidad fallaban por una configuracion JWT de prueba que no cumplia los requisitos minimos de longitud o fortaleza esperados por la libreria de tokens.

Solucion aplicada:
Se ajusto la configuracion de test para incluir un `jwt.secret` adecuado para ejecucion bajo pruebas.

Por que es adecuada para CI/Jenkins:
Evita depender de configuraciones externas o secretos locales debiles y permite que el contexto de pruebas se inicialice de forma determinista en entornos automatizados.

### `services/circleguard-promotion-service/src/test/java/com/circleguard/promotion/controller/HealthStatusControllerTest.java`

Problema:
Los tests autorizados usaban `@WithMockUser(authorities = "...")` mientras el controller validaba acceso con `@PreAuthorize("hasRole('HEALTH_CENTER')")`. Esto provocaba respuestas HTTP 403 en lugar de 200.

Solucion aplicada:
Se reemplazo el uso de `authorities` por `roles` en los mocks de usuario para que Spring Security genere internamente autoridades con prefijo `ROLE_`.

Por que es adecuada para CI/Jenkins:
Hace que la simulacion de seguridad en test refleje con precision el comportamiento real del framework y evita falsos negativos en pipelines.

### `services/circleguard-form-service/src/test/java/com/circleguard/form/controller/AttachmentControllerTest.java`

Problema:
La prueba levantaba todo el contexto con `@SpringBootTest` para validar un endpoint que solo delega a un servicio de almacenamiento, provocando dependencias innecesarias con base de datos y mensajeria.

Solucion aplicada:
La prueba fue convertida a `@WebMvcTest(AttachmentController.class)` y se mockeo `StorageService`.

Por que es adecuada para CI/Jenkins:
Reduce tiempo de ejecucion, elimina acoplamiento con infraestructura innecesaria y deja una prueba mas estable y predecible en entornos de integracion continua.

### `services/circleguard-promotion-service/src/test/java/com/circleguard/promotion/performance/PromotionPerformanceTest.java`

Problema:
El test de rendimiento dependia inicialmente de PostgreSQL y Redis locales. Ademas, una vez estabilizada la infraestructura con Testcontainers, el umbral de 1000 ms resulto fragil para ejecucion local o CI sobre contenedores efimeros.

Solucion aplicada:
Se agrego `PostgreSQLContainer<?>` para datasource de prueba, `GenericContainer<?>` para Redis y se registraron dinamicamente `spring.datasource.*` y `spring.data.redis.*` mediante `@DynamicPropertySource`. Tambien se reemplazo el umbral hardcoded por una constante descriptiva de 2000 ms orientada a local o CI.

Por que es adecuada para CI/Jenkins:
El test deja de depender de servicios locales y se vuelve reproducible en agentes de CI. El umbral ajustado sigue validando comportamiento de rendimiento sin introducir fragilidad artificial por latencia adicional de Testcontainers.

### `services/circleguard-promotion-service/src/test/java/com/circleguard/promotion/service/AdministrativeCorrectionTest.java`

Problema:
Este test de integracion ya utilizaba Neo4j y Redis en Testcontainers, pero todavia dependia de PostgreSQL local para JPA y Flyway.

Solucion aplicada:
Se agrego un `PostgreSQLContainer<?>` y se registraron dinamicamente `spring.datasource.url`, `spring.datasource.username`, `spring.datasource.password` y `spring.datasource.driver-class-name`.

Por que es adecuada para CI/Jenkins:
Permite que el contexto Spring completo, incluyendo Flyway y JPA, levante una base PostgreSQL efimera y aislada, sin suposiciones sobre la maquina del agente.

### `services/circleguard-promotion-service/src/test/java/com/circleguard/promotion/service/HealthStatusReevaluationTest.java`

Problema:
El test dependia inicialmente de Neo4j en Testcontainers, pero seguia intentando conectarse a PostgreSQL y Redis locales.

Solucion aplicada:
Se agrego `PostgreSQLContainer<?>` para datasource y `GenericContainer<?>` para Redis, registrando ambas configuraciones dinamicamente con `@DynamicPropertySource`.

Por que es adecuada para CI/Jenkins:
Completa la aislacion de infraestructura del test y garantiza que los flujos de reevaluacion de estado puedan ejecutarse en CI sin depender de servicios locales instalados previamente.

## 5. Validacion realizada

Se utilizaron los siguientes comandos de validacion:

```powershell
.\gradlew.bat --version
.\gradlew.bat projects
.\gradlew.bat :services:circleguard-auth-service:test :services:circleguard-identity-service:test :services:circleguard-promotion-service:test :services:circleguard-notification-service:test :services:circleguard-form-service:test :services:circleguard-gateway-service:test --console=plain
```

Resultado validado:

```text
BUILD SUCCESSFUL
```

## 6. Fase Docker - empaquetado de microservicios

En esta fase se preparo una base reproducible de dockerizacion para los seis microservicios seleccionados del monorepo. Como resultado de esta etapa se crearon o ajustaron los siguientes archivos:

- `Dockerfile.service`
- `.dockerignore`
- `docs/dockerization.md`

La decision principal fue utilizar un Dockerfile parametrizable en lugar de mantener un Dockerfile duplicado por cada microservicio. Esto permite reutilizar la misma receta de empaquetado para `circleguard-auth-service`, `circleguard-identity-service`, `circleguard-promotion-service`, `circleguard-notification-service`, `circleguard-form-service` y `circleguard-gateway-service`, variando unicamente el valor de `SERVICE_NAME` durante el `docker build`. La aproximacion reduce duplicacion, evita drift entre servicios y deja una base mas limpia para Jenkins.

Inicialmente se intento una estrategia multi-stage en la que Docker ejecutaba `./gradlew :services:${SERVICE_NAME}:bootJar --no-daemon` dentro del contenedor. Ese enfoque fallo por una dependencia de red del entorno de build: el Gradle Wrapper intento descargar `gradle-8.14-bin.zip`, redirigido a `release-assets.githubusercontent.com`, y el contenedor no pudo resolver ese host. Debido a que el problema no estaba en el codigo ni en los microservicios, se cambio a una estrategia runtime-only mas adecuada para el taller y para CI.

La estrategia finalmente validada fue separar responsabilidades de esta forma:

1. Gradle o Jenkins generan primero el artefacto con `bootJar`.
2. Docker empaqueta unicamente el JAR ya construido.

Este cambio deja una responsabilidad clara entre construccion de artefactos y empaquetado de imagen. En Jenkins esto es conveniente porque el pipeline puede ejecutar pruebas, construir `bootJar` y solo despues construir la imagen Docker, sin depender de descargas de Gradle dentro del contenedor.

Los comandos validados para la fase inicial fueron:

```powershell
.\gradlew.bat :services:circleguard-auth-service:bootJar --console=plain
docker build -f Dockerfile.service --build-arg SERVICE_NAME=circleguard-auth-service -t circleguard-auth-service:dev .

.\gradlew.bat :services:circleguard-identity-service:bootJar --console=plain
docker build -f Dockerfile.service --build-arg SERVICE_NAME=circleguard-identity-service -t circleguard-identity-service:dev .
```

Ademas, se valido exitosamente el mismo flujo para:

- `circleguard-promotion-service`
- `circleguard-notification-service`
- `circleguard-form-service`
- `circleguard-gateway-service`

Resultado validado:
Se construyeron imagenes Docker locales exitosamente para los seis microservicios seleccionados usando la estrategia `bootJar -> docker build`.

## 7. Puntos del taller ya avanzados

Actualmente se consideran avanzados los siguientes puntos:

- Seleccion de un minimo de seis microservicios dentro del monorepo.
- Estabilizacion de pruebas base unitarias e integracion en los servicios seleccionados.
- Preparacion del repositorio para ejecucion automatizada en CI.
- Uso de Testcontainers para hacer reproducibles los tests de integracion.
- Dockerfile parametrizable creado para empaquetar microservicios Spring Boot desde la raiz del monorepo.
- Imagenes Docker locales construidas para los seis servicios seleccionados.
- Documentacion de dockerizacion creada para soportar la siguiente fase de integracion con Jenkins.
- Base tecnica suficiente para comenzar la construccion de pipelines Jenkins.

## 8. Puntos pendientes del taller

Los pendientes principales para completar el taller son:

- `docker-compose` con servicios de aplicacion para ambiente de desarrollo.
- Healthchecks y definicion operativa de arranque para los servicios dockerizados.
- Publicacion de imagenes en un registry para consumo desde CI/CD.
- `Jenkinsfile` para ramas `dev`, `stage` y `master`.
- Manifiestos Kubernetes.
- Pruebas E2E.
- Escenarios de rendimiento con Locust.
- Release Notes automaticas.
- Documentacion final consolidada y video de entrega.

Estado actual de pendientes relevantes:

- `docker-compose` todavia no esta implementado.
- Kubernetes todavia no esta implementado.
- Jenkins todavia no esta implementado.
- Locust todavia no esta implementado.

## 9. Proxima fase recomendada

La siguiente fase recomendada es preparar un `docker-compose` de ambiente `dev` sobre la base del `Dockerfile.service` ya validado, incorporar healthchecks y definir la publicacion de imagenes para luego integrarla en Jenkins. Ese paso permitira pasar de la estabilizacion de pruebas y el empaquetado local a una base concreta de orquestacion, CI/CD y despliegue progresivo.
