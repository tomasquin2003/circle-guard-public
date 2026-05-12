# Kubernetes manifests base para Circle Guard

## Objetivo

Estos manifests crean una base inicial, clara y documentable para desplegar en Kubernetes los seis microservicios seleccionados del taller "Taller de pruebas y release 261". El alcance actual es academico y de preparacion: no introduce Helm, no asume registry remoto y usa imagenes locales con tag `:dev`.

## Servicios incluidos

- `circleguard-auth-service` en puerto `8180`
- `circleguard-identity-service` en puerto `8083`
- `circleguard-promotion-service` en puerto `8088`
- `circleguard-notification-service` en puerto `8082`
- `circleguard-form-service` en puerto `8086`
- `circleguard-gateway-service` en puerto `8087`

Todos los recursos se crean dentro del namespace `circleguard-dev` y cada archivo de servicio contiene un `Deployment` y un `Service` `ClusterIP`.

## Prerequisitos

- Un cluster Kubernetes local, por ejemplo Docker Desktop Kubernetes o Minikube.
- Las imagenes locales `:dev` deben existir previamente para los seis microservicios.
- El middleware todavia debe modelarse o conectarse aparte en Kubernetes. Estos manifests solo cubren los microservicios seleccionados y la configuracion compartida base.

Nota operativa: si el runtime de tu cluster no comparte el mismo daemon de Docker donde construiste las imagenes, sera necesario cargarlas manualmente en el cluster local antes de desplegar. Aun asi, en esta fase no se asume un registry remoto.

## Archivos incluidos

- `dev/namespace.yaml`
- `dev/configmap.yaml`
- `dev/secrets.yaml`
- `dev/auth-service.yaml`
- `dev/identity-service.yaml`
- `dev/promotion-service.yaml`
- `dev/notification-service.yaml`
- `dev/form-service.yaml`
- `dev/gateway-service.yaml`

## Validacion

```powershell
kubectl apply --dry-run=client -f k8s/dev/
kubectl apply -f k8s/dev/
kubectl get pods -n circleguard-dev
kubectl get svc -n circleguard-dev
```

En esta fase solo se recomienda la validacion con `--dry-run=client`. No se debe considerar que exista un despliegue operativo completo hasta validar middleware, networking y arranque real de pods en cluster.

Si el cluster rechaza recursos porque el namespace todavia no existe, aplica primero `k8s/dev/namespace.yaml` y luego el resto de `k8s/dev/`.

## Limitaciones actuales

- No hay registry remoto todavia.
- El middleware en Kubernetes no esta completo todavia.
- No hay ingress todavia.
- No se han validado pods corriendo en un cluster real todavia.
- Las probes se dejaron como `tcpSocket` para no asumir endpoints HTTP de health que no estan documentados para todos los servicios.
