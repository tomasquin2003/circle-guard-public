# Rúbrica - Taller de pruebas y release 261

> Fuente de verdad transcrita desde el PDF **"Taller de pruebas y release 261"**.
>
> Este archivo debe ser usado por agentes de desarrollo, auditoría y documentación como referencia principal para validar el Definition of Done del taller.

## Contexto general

Para este ejercicio, se deben configurar los pipelines necesarios para **al menos seis microservicios** del código disponible en:

```text
https://github.com/jcmunozf/circle-guard-public
```

Al escoger los microservicios, se debe considerar que los servicios seleccionados **se comuniquen entre sí**, para permitir la posterior implementación de pruebas que los involucren.

---

## Actividades a considerar

### 1. Configuración base - 10%

Configurar **Jenkins, Docker y Kubernetes** para su utilización.

**Evidencia esperada:**

- Jenkins configurado o documentado.
- Docker configurado y usado para construir/ejecutar servicios.
- Kubernetes configurado o manifests preparados/validados.
- Capturas o comandos que demuestren configuración relevante.

---

### 2. Pipelines para ambiente dev - 15%

Para los microservicios escogidos, se deben definir los pipelines que permitan la utilización de la aplicación en **dev environment**, incluyendo:

- Construcción.
- Pruebas a diferentes niveles.
- Deployment.

**Evidencia esperada:**

- Pipeline(s) para los seis microservicios seleccionados.
- Etapas de build/test/package/deploy o equivalentes.
- Evidencia de ejecución exitosa o documentación clara de ejecución.

---

### 3. Pruebas unitarias, integración, E2E y rendimiento - 30%

En algunos de los microservicios, se deben definir pruebas que involucren los microservicios.

#### 3.a. Pruebas unitarias

Debe haber **al menos cinco nuevas pruebas unitarias** que validen componentes individuales.

**Evidencia esperada:**

- Mínimo 5 tests unitarios nuevos.
- Cada test debe validar lógica o componentes individuales.
- Deben estar en rutas de test del proyecto.
- Debe existir comando de ejecución y resultado.

#### 3.b. Pruebas de integración

Debe haber **al menos cinco nuevas pruebas de integración** que validen la comunicación entre servicios.

**Evidencia esperada:**

- Mínimo 5 tests de integración nuevos.
- Deben validar interacciones entre componentes, servicios, infraestructura o dependencias.
- Deben tener sentido frente a los microservicios seleccionados.
- Debe existir comando de ejecución y resultado.

#### 3.c. Pruebas E2E

Debe haber **al menos cinco nuevas pruebas E2E** que validen flujos completos de usuario.

**Evidencia esperada:**

- Mínimo 5 pruebas/checks E2E nuevos.
- Deben validar flujos completos o recorridos funcionales defendibles.
- Si un flujo queda bloqueado por seguridad, falta de seed data o falta de credenciales, debe documentarse como limitación real y no venderse como éxito funcional completo.

#### 3.d. Pruebas de rendimiento y estrés

Debe haber pruebas de rendimiento y estrés utilizando **Locust** que simulen casos de uso reales del sistema.

**Evidencia esperada:**

- `locustfile.py` o suite equivalente.
- Escenarios de uso realistas.
- Ejecuciones headless o por UI.
- Resultados con métricas.
- Análisis de resultados.

#### Requisito transversal de las pruebas

Todas las pruebas deben ser:

- Relevantes sobre funcionalidades existentes, ajustadas o agregadas.
- Acompañadas de análisis.

---

### 4. Pipelines para ambiente stage - 15%

Para los microservicios escogidos, se deben definir los pipelines que permitan la construcción incluyendo las pruebas de la aplicación desplegada en Kubernetes en **stage environment**.

**Evidencia esperada:**

- Pipeline o etapa explícita de stage.
- Construcción de servicios.
- Ejecución de pruebas sobre aplicación desplegada en Kubernetes.
- Evidencia o documentación de validación en Kubernetes.

---

### 5. Pipeline master environment + Release Notes - 15%

Para los microservicios escogidos, se debe ejecutar un pipeline de despliegue en **master environment**, que realice:

- Construcción.
- Pruebas unitarias.
- Validación de pruebas de sistema.
- Despliegue de la aplicación en Kubernetes.
- Fases adecuadas según el diseño del equipo.
- Generación automática de **Release Notes** siguiendo buenas prácticas de **Change Management**.

**Evidencia esperada:**

- Pipeline master o lógica equivalente claramente diferenciada.
- Stages de build, unit tests, system tests y deploy.
- Despliegue en Kubernetes o evidencia de validación.
- Release Notes automáticas.
- Release Notes con metadatos de build, commit, servicios, cambios y validaciones.

---

### 6. Documentación y video - 15%

Debe existir documentación adecuada del proceso realizado y un video corto de máximo **8 minutos** que evidencie todos los puntos anteriores.

**Evidencia esperada en el documento/video:**

Para cada pipeline:

#### Configuración

- Texto de la configuración de los pipelines.
- Pantallazos de configuración relevante.

#### Resultado

- Pantallazos de ejecución exitosa de los pipelines.
- Detalles y resultados relevantes.

#### Análisis

- Interpretación de los resultados de las pruebas.
- Especial énfasis en pruebas de rendimiento.
- Métricas clave como:
  - Tiempo de respuesta.
  - Throughput.
  - Tasa de errores.

---

## Entregables finales

Además del documento y el video corto, se debe entregar un `.zip` con:

- Pipelines.
- Pruebas implementadas.
- Proyecto si fue modificado.

---

## Definition of Done recomendado para este repositorio

Para considerar el taller listo para entrega, el repositorio debería tener evidencia de:

- [ ] Seis microservicios seleccionados y documentados.
- [ ] Jenkins configurado/documentado.
- [ ] Dockerfile(s) o estrategia Docker funcional.
- [ ] Docker Compose o equivalente para ambiente dev.
- [ ] Manifests Kubernetes para servicios y dependencias necesarias.
- [ ] Pipeline dev con build, tests, empaquetado y deployment/validación.
- [ ] Pipeline stage con pruebas sobre Kubernetes.
- [ ] Pipeline master con build, unit tests, system tests, deploy Kubernetes y Release Notes automáticas.
- [ ] Al menos 5 pruebas unitarias nuevas.
- [ ] Al menos 5 pruebas de integración nuevas.
- [ ] Al menos 5 pruebas E2E nuevas.
- [ ] Suite Locust de rendimiento/estrés.
- [ ] Resultados y análisis de Locust con response time, throughput y error rate.
- [ ] Evidencia de ejecución: logs, reportes, CSVs, capturas o artefactos.
- [ ] Documento final.
- [ ] Guion/video de máximo 8 minutos.
- [ ] Zip final con pipelines, pruebas y proyecto modificado.

---

## Reglas para agentes

Cuando un agente use esta rúbrica:

1. No debe inventar evidencia.
2. Debe citar rutas reales del repositorio.
3. Debe diferenciar entre:
   - Completo.
   - Parcial.
   - Pendiente.
4. Debe marcar como riesgo cualquier flujo que sea solo smoke/reachability y no E2E funcional completo.
5. Debe validar que Locust tenga métricas y análisis, no solo archivo de prueba.
6. Debe validar que Release Notes sean automáticas o generadas desde pipeline.
7. Debe mantener actualizado `TALLER_PROGRESS.md` después de cada cambio relevante.
