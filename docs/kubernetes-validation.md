# Kubernetes Validation - Taller 261

## Contexto
- Cluster: Docker Desktop Kubernetes
- Contexto kubectl: docker-desktop
- Namespace: circleguard-dev

## Cambios de estabilidad aplicados
- `enableServiceLinks: false` en `k8s/dev/neo4j.yaml`
- `enableServiceLinks: false` en `k8s/dev/kafka.yaml`
- `startupProbe` agregado (delay 30s, failureThreshold 15) en `k8s/dev/identity-service.yaml` y `k8s/dev/promotion-service.yaml` para entornos de inicialización lenta.

## Validación de middleware
| Pod | Estado | Ready | Observación |
|---|---|---|---|
| kafka | Running | 1/1 | Funciona tras deshabilitar inyección de ServiceLinks |
| neo4j | Running | 1/1 | Funciona tras deshabilitar inyección de ServiceLinks |
| postgres | Running | 1/1 | Estable |
| redis | Running | 1/1 | Estable |
| zookeeper | Running | 1/1 | Estable |
| openldap | Running | 1/1 | Estable |

## Validación de microservicios
| Pod | Estado | Ready | Observación | Logs/diagnóstico relevante |
|---|---|---|---|---|
| auth-service | Running | 1/1 | Boot ok | N/A |
| identity-service | Running | 1/1 | Boot ok | Reinicios curados gracias a startupProbe |
| promotion-service | Running | 1/1 | Boot ok | Reinicios curados gracias a startupProbe |
| notification-service | Running | 1/1 | Boot ok | N/A |
| form-service | Running | 1/1 | Requiere reinicio | Liveness fallaba pero tras un reinicio logró estar Ready 1/1 |
| gateway-service | Running | 1/1 | Boot ok | Reachability comprobada |

## Services creados
Resumen de `kubectl get svc -n circleguard-dev`:
```
NAME                   TYPE        CLUSTER-IP       PORT(S)
auth-service           ClusterIP   10.102.102.195   8180/TCP
form-service           ClusterIP   10.104.104.90    8086/TCP
gateway-service        ClusterIP   10.102.215.177   8087/TCP
identity-service       ClusterIP   10.103.199.134   8083/TCP
kafka                  ClusterIP   10.99.125.130    29092/TCP
neo4j                  ClusterIP   10.110.178.203   7474/TCP,7687/TCP
notification-service   ClusterIP   10.99.112.1      8082/TCP
openldap               ClusterIP   10.100.75.40     389/TCP,636/TCP
postgres               ClusterIP   10.108.111.144   5432/TCP
promotion-service      ClusterIP   10.103.131.184   8088/TCP
redis                  ClusterIP   10.102.152.94    6379/TCP
zookeeper              ClusterIP   10.111.75.222    2181/TCP
```

## Errores encontrados (Resueltos)
- **`identity-service` & `promotion-service`**: Los pods quedaban atrapados en CrashLoopBackOff/reinicios limitados porque las reglas de liveness y readiness eran muy agresivas frente al entorno local. Solucionado inyectando un `startupProbe` que le otorga hasta 180 segundos a la app para inicializar Tomcat.

## Conclusión
- Kubernetes configurado: COMPLETO
- Manifests validados: COMPLETO
- Middleware desplegado: COMPLETO
- Microservicios desplegados: COMPLETO
- Stage environment: PENDIENTE
