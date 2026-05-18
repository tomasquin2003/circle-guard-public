# Checklist para zip final

Usar este checklist antes de comprimir la entrega. No ejecutar el comando de zip hasta verificar que las evidencias necesarias estan completas.

## Incluir

- `README.md`
- `settings.gradle.kts`
- `build.gradle.kts`
- `gradlew`
- `gradlew.bat`
- `gradle/`
- `services/`
- `Dockerfile.service`
- `.dockerignore`
- `docker-compose.dev.yml`
- `docker-compose.app.yml`
- `init-db.sql`
- `k8s/`
- `Jenkinsfile`
- `Jenkinsfile.stage`
- `Jenkinsfile.master`
- `docs/`
- `e2e/`
- `performance/locust/`
- `evidence/`
- `delivery/`
- `TALLER_PROGRESS.md`
- `AUDIT_DOD_261.md`

## Verificar antes del zip

- `delivery/final-report.md` esta completo y mantiene estilo academico/profesional.
- `delivery/video-script.md` dura maximo 8 minutos.
- `delivery/zip-checklist.md` esta incluido.
- `evidence/README.md` referencia solo archivos existentes o marca claramente ausencias.
- `evidence/docs-index.md` clasifica `TALLER_PROGRESS.md` como bitacora tecnica, no como reporte final.
- Las capturas existentes estan en `evidence/screenshots/`.
- Los logs Jenkins disponibles estan en `evidence/logs/`.
- Los CSVs Locust estan en `performance/locust/results/`.
- El reporte E2E esta en `e2e/results/e2e-report.md`.
- Los manifests Kubernetes estan en `k8s/dev/`.
- No hay secretos reales incluidos en archivos no destinados a dev.
- Si se requiere evidencia STAGE de consola, reemplazar el archivo vacio `evidence/logs/jenkins-stage-console-success.txt` por un log real antes de comprimir.

## Excluir recomendado

- `.git/`
- `.gradle/`
- `build/`
- `services/**/build/` si el docente no requiere artefactos generados.
- `node_modules/`
- `performance/locust/__pycache__/`
- Logs temporales no relevantes.
- Imagenes o videos pesados no requeridos.
- Secrets reales, tokens, credenciales personales o kubeconfigs privados.

## Comando PowerShell sugerido

Ejecutar desde la raiz del repositorio solo cuando la revision este lista:

```powershell
$zipName = "circle-guard-public-taller-261-final.zip"
$exclude = @(
  ".git",
  ".gradle",
  "build",
  "node_modules",
  "__pycache__"
)

$items = Get-ChildItem -Force | Where-Object {
  $name = $_.Name
  -not ($exclude -contains $name)
}

if (Test-Path $zipName) {
  Remove-Item $zipName
}

Compress-Archive -Path $items.FullName -DestinationPath $zipName -CompressionLevel Optimal
```

Nota: si se decide excluir `services/**/build/`, hacerlo manualmente o crear una carpeta temporal de entrega para evitar arrastrar artefactos pesados.
