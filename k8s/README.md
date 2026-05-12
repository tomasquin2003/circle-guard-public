# Kubernetes manifests base para Circle Guard

## Objetivo

Estos manifests crean una base inicial, clara y documentable para desplegar en Kubernetes los seis microservicios seleccionados del taller "Taller de pruebas y release 261" junto con su middleware base. El alcance actual es academico y de preparacion: no introduce Helm, no asume registry remoto y usa imagenes locales con tag `:dev`.

## Servicios incluidos

- `circleguard-auth-service` en puerto `8180`
- `circleguard-identity-service` en puerto `8083`
- `circleguard-promotion-service` en puerto `8088`
- `circleguard-notification-service` en puerto `8082`
- `circleguard-form-service` en puerto `8086`
- `circleguard-gateway-service` en puerto `8087`

Todos los recursos se crean dentro del namespace `circleguard-dev` y cada archivo de servicio contiene un `Deployment` y un `Service` `ClusterIP`.

## Middleware incluido

- `postgres` con `StatefulSet`, `Service` y `ConfigMap` de inicializacion para las bases `circleguard_auth`, `circleguard_identity`, `circleguard_promotion`, `circleguard_dashboard` y `circleguard_form`
- `redis` con `Deployment` y `Service`
- `neo4j` con `StatefulSet`, `Service` y volumen persistente para `/data`
- `zookeeper` con `Deployment` y `Service`
- `kafka` con `Deployment` y `Service` expuesto internamente como `kafka:29092`
- `openldap` con `Deployment` y `Service`

## Prerequisitos

- Un cluster Kubernetes local, por ejemplo Docker Desktop Kubernetes o Minikube.
- Las imagenes locales `:dev` deben existir previamente para los seis microservicios.

Nota operativa: si el runtime de tu cluster no comparte el mismo daemon de Docker donde construiste las imagenes, sera necesario cargarlas manualmente en el cluster local antes de desplegar. Aun asi, en esta fase no se asume un registry remoto.

## Archivos incluidos

- `dev/namespace.yaml`
- `dev/configmap.yaml`
- `dev/secrets.yaml`
- `dev/postgres.yaml`
- `dev/redis.yaml`
- `dev/neo4j.yaml`
- `dev/zookeeper.yaml`
- `dev/kafka.yaml`
- `dev/openldap.yaml`
- `dev/auth-service.yaml`
- `dev/identity-service.yaml`
- `dev/promotion-service.yaml`
- `dev/notification-service.yaml`
- `dev/form-service.yaml`
- `dev/gateway-service.yaml`

## Orden sugerido de aplicacion

```powershell
kubectl apply -f k8s/dev/namespace.yaml
kubectl apply -f k8s/dev/secrets.yaml
kubectl apply -f k8s/dev/configmap.yaml
kubectl apply -f k8s/dev/postgres.yaml
kubectl apply -f k8s/dev/redis.yaml
kubectl apply -f k8s/dev/neo4j.yaml
kubectl apply -f k8s/dev/zookeeper.yaml
kubectl apply -f k8s/dev/kafka.yaml
kubectl apply -f k8s/dev/openldap.yaml
kubectl apply -f k8s/dev/auth-service.yaml
kubectl apply -f k8s/dev/identity-service.yaml
kubectl apply -f k8s/dev/promotion-service.yaml
kubectl apply -f k8s/dev/notification-service.yaml
kubectl apply -f k8s/dev/form-service.yaml
kubectl apply -f k8s/dev/gateway-service.yaml
```

## Validacion

```powershell
kubectl apply --dry-run=client -f k8s/dev/
kubectl get pods -n circleguard-dev
kubectl get svc -n circleguard-dev
kubectl logs -n circleguard-dev deploy/promotion-service
```

En esta fase solo se recomienda la validacion con `--dry-run=client`. No se debe considerar que exista un despliegue operativo completo hasta validar middleware, networking y arranque real de pods en cluster.

Si el cluster rechaza recursos porque el namespace todavia no existe, aplica primero `k8s/dev/namespace.yaml` y luego el resto de `k8s/dev/`.

## Limitaciones actuales

- No hay registry remoto todavia.
- No se ha validado en un cluster real todavia.
- Kafka en Kubernetes puede requerir ajustes adicionales para produccion.
- Las credenciales actuales son solo de dev.
- No hay ingress todavia.
- Neo4j usa `NEO4J_AUTH=neo4j/password` fijo para mantener compatibilidad simple con la imagen oficial en esta fase base.
- Las probes se dejaron como `tcpSocket` para no asumir endpoints HTTP de health que no estan documentados para todos los servicios.
