# Jenkins stage y master

## Objetivo

Esta documentacion describe los pipelines `Jenkinsfile.stage` y `Jenkinsfile.master` creados para el taller. La intencion es cubrir ambientes stage y master de forma minima, defendible y reproducible, sin romper el `Jenkinsfile` dev existente, sin asumir registry remoto real y sin asumir cluster Kubernetes real cuando el agente no tenga `kubeconfig`.

## Pipeline stage

`Jenkinsfile.stage` valida una promocion intermedia de la aplicacion. Cubre checkout, informacion del agente, pruebas unitarias/integracion de los seis servicios desplegables, construccion de JARs, construccion de imagenes Docker locales, validacion de manifiestos Kubernetes, deploy parametrizado y ejecucion E2E cuando el agente lo permite.

Stages:

1. `Checkout`
2. `Environment Info`
3. `Run Unit/Integration Tests`
4. `Build Boot JARs`
5. `Build Docker Images`
6. `Validate Kubernetes Manifests`
7. `Deploy to Kubernetes Stage`
8. `Run E2E Against Stage`
9. `Archive Artifacts`

## Pipeline master

`Jenkinsfile.master` representa el flujo mas completo antes de una entrega. Cubre full test suite de Gradle, empaquetado, imagenes Docker locales, validacion Compose, validacion Kubernetes, E2E smoke/functional, Locust smoke, deploy parametrizado y generacion automatica de release notes.

Stages:

1. `Checkout`
2. `Environment Info`
3. `Run Full Test Suite`
4. `Build Boot JARs`
5. `Build Docker Images`
6. `Validate Docker Compose Config`
7. `Validate Kubernetes Manifests`
8. `Run E2E Smoke + Functional`
9. `Run Locust Smoke`
10. `Deploy to Kubernetes Master`
11. `Generate Release Notes`
12. `Archive Release Artifacts`

## Prerequisitos del agente Jenkins

El agente Jenkins debe tener:

- Java 21 disponible en `PATH`.
- Git y acceso al repositorio.
- Gradle Wrapper ejecutable desde la raiz del repo.
- Docker CLI y acceso al Docker daemon.
- Docker Compose plugin disponible mediante `docker compose` para el pipeline master.
- `kubectl` disponible en `PATH`.
- Python disponible como `python` para el smoke de Locust en master.
- Locust instalado en el entorno Python usado por Jenkins.
- PowerShell Windows para ejecutar `e2e/run-e2e.ps1` en agentes Windows.
- `pwsh` en Linux si se quiere ejecutar el script E2E PowerShell desde un agente Linux.
- `kubeconfig` valido en el agente si se habilita `DEPLOY_TO_K8S=true`.

Instalacion Locust de referencia:

```powershell
pip install -r performance/locust/requirements.txt
```

## Parametros

Ambos pipelines incluyen:

- `DEPLOY_TO_K8S=false`: ejecuta validacion con `kubectl apply --dry-run=client -f k8s/dev/` y no modifica ningun cluster.
- `DEPLOY_TO_K8S=true`: ejecuta `kubectl apply -f k8s/dev/` usando el contexto Kubernetes configurado en el agente Jenkins.

El valor por defecto es `false` para evitar despliegues reales accidentales.

## Evidencia generada

`Jenkinsfile.stage` archiva:

- `**/build/test-results/test/*.xml`
- `e2e/results/*.md`
- `performance/locust/results/*.csv`
- `k8s/**/*.yaml`

`Jenkinsfile.master` archiva:

- `**/build/test-results/test/*.xml`
- `services/**/build/libs/*.jar`
- `e2e/results/*.md`
- `performance/locust/results/*.csv`
- `release-notes/*.md`
- `docs/*.md`

`Jenkinsfile.master` genera automaticamente `release-notes/RELEASE_NOTES.md` con job name, build number, branch, commit, date, services, tests executed, deployment target y ultimos 10 commits.

## Kubernetes

La validacion base usa:

```bash
kubectl apply --dry-run=client -f k8s/dev/
```

Cuando `DEPLOY_TO_K8S=true`, el deploy real usa:

```bash
kubectl apply -f k8s/dev/
```

Si no existe cluster real, el pipeline queda preparado para ejecutarse en un agente Jenkins con `kubectl` y `kubeconfig`. En ese caso, la evidencia defendible es el dry-run de cliente.

## E2E

En agentes Windows se ejecuta:

```powershell
powershell -ExecutionPolicy Bypass -File e2e/run-e2e.ps1
```

En agentes Linux, el pipeline intenta usar:

```bash
pwsh -ExecutionPolicy Bypass -File e2e/run-e2e.ps1
```

Si `pwsh` no esta instalado, el stage queda documentado y no ejecuta E2E. Para una entrega real, se recomienda usar agente Windows o instalar PowerShell 7 en el agente Linux.

## Locust

El pipeline master ejecuta un smoke de rendimiento si Python y Locust estan disponibles:

```bash
python -m locust -f performance/locust/locustfile.py --host http://localhost --headless -u 5 -r 1 -t 30s --csv performance/locust/results/jenkins-master-smoke
```

Si Python o Locust no estan disponibles, el pipeline master falla con un mensaje explicito para que la limitacion del agente sea visible.

## Pantallazos para la entrega

Evidencia sugerida:

- Vista del job stage en Jenkins con todos los stages visibles.
- Vista del job master en Jenkins con todos los stages visibles.
- Consola del stage `Validate Kubernetes Manifests` mostrando el dry-run.
- Consola del stage `Deploy to Kubernetes Stage` o `Deploy to Kubernetes Master` mostrando si `DEPLOY_TO_K8S` estuvo en `false` o `true`.
- Consola del stage E2E mostrando ejecucion de `e2e/run-e2e.ps1` o la limitacion del agente Linux sin `pwsh`.
- Consola del stage `Run Locust Smoke` mostrando `python -m locust`.
- Artefactos archivados en Jenkins, especialmente JUnit XML, reportes E2E, CSVs de Locust y `release-notes/RELEASE_NOTES.md`.

## Limitaciones

- Requiere Jenkins real para obtener pantallazos y trazabilidad completa de ejecucion.
- Requiere `kubeconfig` valido si se hara `kubectl apply` real.
- Registry remoto queda pendiente porque no hay configuracion de registry ni credenciales en el contexto actual.
- Si no hay cluster real, Kubernetes se valida por `kubectl apply --dry-run=client`.
- Las imagenes Docker se construyen localmente con tags `:stage` y `:master`; no se publican.
- El E2E existente depende del stack expuesto en `localhost` y de Docker accesible desde el agente.
- Locust master depende de Python, Locust y servicios alcanzables desde `localhost`.
