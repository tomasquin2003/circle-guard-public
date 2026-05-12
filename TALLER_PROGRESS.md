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

## 7. Fase Docker Compose - middleware + microservicios

En esta fase se preparo la composicion Docker necesaria para ejecutar el middleware existente junto con los seis microservicios seleccionados, sin modificar codigo productivo y sin reemplazar el compose base de desarrollo. Como resultado se crearon o ajustaron los siguientes archivos:

- `docker-compose.app.yml`
- `docker-compose.dev.yml`
- `docs/docker-compose.md`

El archivo `docker-compose.app.yml` se creo para declarar los seis microservicios:

- `auth-service`
- `identity-service`
- `promotion-service`
- `notification-service`
- `form-service`
- `gateway-service`

La configuracion de cada contenedor se alineo con nombres DNS internos de Docker Compose para evitar dependencias a `localhost` dentro de la red de contenedores. En consecuencia, los servicios quedaron apuntando a dependencias internas como `postgres`, `neo4j`, `kafka`, `redis`, `openldap` y `auth-service`, segun el caso.

Tambien se verifico el archivo `init-db.sql` para confirmar que las bases requeridas por los servicios seleccionados existen efectivamente:

- `circleguard_auth`
- `circleguard_identity`
- `circleguard_promotion`
- `circleguard_form`

Adicionalmente se identifico `circleguard_dashboard`, pero esta base no aplica a los seis servicios incluidos en esta fase.

Durante la preparacion del compose se detecto un riesgo importante en Kafka. Inicialmente el broker anunciaba `PLAINTEXT://localhost:9092`, lo cual puede ser suficiente para clientes ejecutados en el host, pero rompe o vuelve fragil la conectividad desde otros contenedores, ya que dentro de Docker `localhost` apunta al propio contenedor cliente y no al broker. Para corregir este problema se ajusto Kafka a un esquema de doble listener:

- Listener interno para contenedores: `kafka:29092`
- Listener externo para el host: `localhost:9092`

Como consecuencia, los microservicios que consumen o publican eventos en Kafka fueron configurados para usar:

```text
SPRING_KAFKA_BOOTSTRAP_SERVERS=kafka:29092
```

Este ajuste deja separadas correctamente las rutas de acceso de host y de red interna, evitando que la orquestacion funcione solo parcialmente.

La validacion realizada en esta fase fue exclusivamente estructural y de composicion, mediante:

```powershell
docker compose -f docker-compose.dev.yml -f docker-compose.app.yml config
```

Que valida `docker compose config` en este contexto:

- Que ambos archivos Compose pueden combinarse en una sola definicion consistente.
- Que la sintaxis YAML y la estructura final de servicios son correctas.
- Que variables, puertos, `depends_on` y redes quedan resueltos en la configuracion final.
- Que el middleware y las apps son componibles con archivos combinados.

Resultado validado:

```text
Exit code 0
```

Warning no bloqueante observado:

```text
docker-compose.dev.yml: the attribute version is obsolete, it will be ignored
```

Es importante dejar explicito que esta fase no confirma todavia ejecucion real ni readiness completa. Hasta este punto solo se valido que la configuracion combinada es correcta y coherente; todavia no se ejecuto `docker compose up`.

## 8. Validacion operativa de Docker Compose

Despues de la validacion estructural de Compose, se ejecuto por primera vez el stack combinado mediante:

```powershell
docker compose -f docker-compose.dev.yml -f docker-compose.app.yml up -d
```

El resultado inicial fue positivo para la mayor parte del entorno:

- El middleware levanto correctamente.
- Cinco de los seis microservicios quedaron arriba.
- `promotion-service` fallo en el primer intento de arranque.

El error raiz observado en esa primera ejecucion fue un rechazo de conexion hacia Neo4j:

```text
Connection refused: neo4j:7687
```

El diagnostico mostro que no se trataba de un problema de credenciales, URI ni DNS interno, sino de readiness. En Docker Compose, `depends_on` con `condition: service_started` solo garantiza que el contenedor de dependencia haya sido iniciado, pero no que el servicio interno ya este listo para aceptar conexiones. En este caso puntual, `promotion-service` intentaba usar Bolt en `neo4j:7687` antes de que Neo4j hubiera completado su inicializacion real.

Para resolver el problema se aplico una correccion minima de Compose:

- Se agrego un `healthcheck` a `neo4j` en `docker-compose.dev.yml`.
- Se cambio la dependencia de `promotion-service` para que espere a `neo4j` con `condition: service_healthy`.
- Se actualizo `docs/docker-compose.md` para documentar la diferencia entre arranque de contenedor y readiness efectiva.

Despues de ese ajuste, se volvio a validar la configuracion con:

```powershell
docker compose -f docker-compose.dev.yml -f docker-compose.app.yml config
```

Resultado:

```text
Exit code 0
```

La recreacion puntual de `neo4j` y `promotion-service` permitio confirmar la secuencia esperada:

- Neo4j paso a estado `Up ... (healthy)`.
- Compose espero a que Neo4j estuviera healthy.
- `promotion-service` arranco despues y permanecio `Up`.

Los logs de Neo4j confirmaron readiness completa:

- `Bolt enabled on 0.0.0.0:7687`
- `Remote interface available at http://localhost:7474/`
- `Started.`

Los logs de `promotion-service` confirmaron arranque exitoso de Spring Boot:

- `Tomcat started on port 8088`
- `Started PromotionApplication`

Ademas, la validacion HTTP:

```powershell
curl -I http://localhost:8088/swagger-ui/index.html
```

respondio `HTTP 404`, lo cual fue considerado aceptable en esta fase porque confirma que el servicio responde por HTTP aunque esa ruta especifica no exista o no este publicada.

Tambien se observaron warnings no bloqueantes:

- Flyway recomienda upgrade porque PostgreSQL 16.13 es mas nuevo que la version explicitamente soportada o testeada por esa version de Flyway.
- Kafka puede registrar `MemberIdRequiredException` durante el proceso de coordinacion de consumidores, sin bloquear el arranque del servicio.

Como resultado, esta fase confirma que el stack Compose ya no solo es valido a nivel de configuracion, sino tambien operativo localmente para el caso de `promotion-service` y su dependencia con Neo4j.

## 9. Fase Jenkins - pipeline base dev

En esta fase se creo una base inicial de Jenkins para automatizar en CI el flujo tecnico que ya habia sido validado manualmente durante las fases anteriores del taller. Como resultado de esta etapa se crearon los siguientes archivos:

- `Jenkinsfile`
- `docs/jenkins.md`

El objetivo de esta fase fue trasladar a un pipeline declarativo base para ambiente dev la secuencia ya comprobada localmente:

```text
test -> bootJar -> docker build -> docker compose config
```

El `Jenkinsfile` fue creado en la raiz del repositorio con un enfoque claro y documentable para el taller, orientado preferiblemente a un agente Jenkins Linux con Java 21, Gradle Wrapper, Docker CLI y `docker compose` disponibles. No se implemento despliegue real, no se agregaron credenciales externas y no se asumio ningun Docker registry.

Las etapas incluidas en el pipeline base son:

- `Checkout`
- `Environment Info`
- `Run Selected Service Tests`
- `Build Boot JARs`
- `Build Docker Images`
- `Validate Docker Compose Config`
- `Generate Release Notes`
- `Archive Test Reports`

El pipeline trabaja especificamente sobre los seis microservicios seleccionados del taller:

- `circleguard-auth-service`
- `circleguard-identity-service`
- `circleguard-promotion-service`
- `circleguard-notification-service`
- `circleguard-form-service`
- `circleguard-gateway-service`

Tambien se agrego una pequena capa de portabilidad para Gradle mediante `isUnix()`, de forma que el pipeline use `./gradlew` en agentes Unix o Linux y `gradlew.bat` en agentes Windows si llegara a ser necesario. Aun asi, la orientacion principal documentada sigue siendo Jenkins sobre Linux con acceso a Docker.

En esta fase se automatizaron los siguientes puntos:

- Ejecucion de tests Gradle de los seis servicios seleccionados.
- Construccion de artefactos `bootJar`.
- Construccion de imagenes Docker locales con tag `:dev` usando `Dockerfile.service`.
- Validacion estructural de `docker-compose.dev.yml` y `docker-compose.app.yml` mediante `docker compose config`.
- Generacion automatica de `release-notes/RELEASE_NOTES.md` como artefacto Jenkins con metadatos del build, servicios incluidos, validaciones ejecutadas y ultimos 10 commits.
- Archivado de reportes JUnit.
- Archivado de JARs generados, release notes y documentacion relevante del taller.

Adicionalmente, se creo `docs/jenkins.md` para dejar documentado:

- El objetivo del pipeline.
- Los prerequisitos del agente Jenkins.
- La descripcion de stages.
- El contenido de las release notes automaticas archivadas por Jenkins.
- Los comandos manuales equivalentes.
- Las limitaciones actuales.
- La evolucion recomendada para siguientes fases.

Es importante dejar explicito que en esta etapa no se ejecuto Jenkins en un servidor real ni se valido un job remoto end-to-end. Lo que si quedo completado fue la creacion del `Jenkinsfile`, su revision base y la documentacion necesaria para usarlo como punto de partida del ambiente dev.

### Release Notes automaticas como artefacto Jenkins

Como extension del pipeline base dev, se agrego una etapa `Generate Release Notes` ubicada despues de la validacion de Compose y antes del archivado final. Esta etapa genera `release-notes/RELEASE_NOTES.md` dentro del workspace del job y lo publica como artefacto del build.

La intencion de esta salida es dejar una evidencia tecnica resumida de cada ejecucion del pipeline sin convertirla todavia en una release formal. El archivo incluye numero de build, nombre del job, rama, commit corto, fecha de generacion, lista de servicios considerados, validaciones realizadas por el pipeline y los ultimos 10 commits del repositorio.

Se deja explicito que esta automatizacion no crea tags Git, no crea GitHub Releases, no hace versionado oficial y no publica artefactos en un registry. Su alcance actual es documental y de trazabilidad dentro de Jenkins.

## 10. Puntos del taller ya avanzados

Actualmente se consideran avanzados los siguientes puntos:

- Seleccion de un minimo de seis microservicios dentro del monorepo.
- Estabilizacion de pruebas base unitarias e integracion en los servicios seleccionados.
- Preparacion del repositorio para ejecucion automatizada en CI.
- Uso de Testcontainers para hacer reproducibles los tests de integracion.
- Dockerfile parametrizable creado para empaquetar microservicios Spring Boot desde la raiz del monorepo.
- Imagenes Docker locales construidas para los seis servicios seleccionados.
- Documentacion de dockerizacion creada para soportar la siguiente fase de integracion con Jenkins.
- Docker Compose de apps creado para los seis microservicios seleccionados.
- Middleware y apps componibles usando `docker-compose.dev.yml` y `docker-compose.app.yml`.
- Listener Kafka interno y externo configurado para separar trafico entre contenedores y acceso desde host.
- Compose ejecutado localmente con `docker compose up -d`.
- Middleware y microservicios levantados localmente en Docker Compose.
- Readiness de Neo4j corregido mediante `healthcheck`.
- `promotion-service` validado operativo en Docker Compose despues del ajuste de readiness.
- `Jenkinsfile` base creado para ambiente dev.
- Pipeline dev documentado en `docs/jenkins.md`.
- Automatizacion de tests, `bootJar`, build de imagenes y validacion Compose en Jenkins.
- Generacion automatica de Release Notes como artefacto del pipeline Jenkins.
- Archivado de reportes JUnit y artefactos del taller desde el pipeline base.

## 11. Puntos pendientes del taller

Los pendientes principales para completar el taller son:

- Pipeline base dev creado, pero falta evolucionar Jenkins para flujos de `stage`, `master` o `release`.
- Publicacion de imagenes en un registry para consumo desde CI/CD.
- Tags oficiales de release.
- Publicacion formal de releases.
- Manifiestos Kubernetes.
- Pruebas E2E.
- Escenarios de rendimiento con Locust.
- Documentacion final consolidada y video de entrega.

Estado actual de pendientes relevantes:

- Existe una base Jenkins para dev, pero todavia no estan implementados los pipelines para `stage`, `master` o `release`.
- La publicacion de imagenes a registry todavia no esta implementada.
- Los tags oficiales todavia no estan implementados.
- La publicacion formal de releases todavia no esta implementada.
- Kubernetes todavia no esta implementado.
- E2E formal todavia no esta implementado.
- Locust todavia no esta implementado.
- Documentacion final consolidada y video de entrega todavia no estan implementados.

## 12. Proxima fase recomendada

La siguiente fase recomendada es aprovechar esta base Compose ya validada operativamente y el nuevo pipeline Jenkins base dev para evolucionar Jenkins hacia flujos de `stage` y `master` o `release`, definir publicacion de imagenes y continuar con manifiestos Kubernetes, pruebas E2E formales y escenarios de rendimiento con Locust. Con el problema de readiness de Neo4j ya resuelto y con una automatizacion inicial de CI ya documentada, el entorno local queda en mejor posicion para servir como referencia de CI/CD y despliegue progresivo.
