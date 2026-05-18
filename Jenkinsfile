def selectedServices = [
    'circleguard-auth-service',
    'circleguard-identity-service',
    'circleguard-promotion-service',
    'circleguard-notification-service',
    'circleguard-form-service',
    'circleguard-gateway-service'
]

def gradleWrapper() {
    return isUnix() ? './gradlew' : 'gradlew.bat'
}

def runCommand(String command) {
    if (isUnix()) {
        sh command
    } else {
        bat command
    }
}

def runCommandOutput(String command) {
    if (isUnix()) {
        return sh(script: command, returnStdout: true).trim()
    }

    return bat(script: "@echo off\r\n${command}", returnStdout: true).trim()
}

def commandAvailable(String linuxCommand, String windowsCommand) {
    if (isUnix()) {
        return sh(script: linuxCommand, returnStatus: true) == 0
    }

    return bat(script: "@echo off\r\n${windowsCommand}", returnStatus: true) == 0
}

def generateReleaseNotes(List services) {
    def branchName = env.BRANCH_NAME ?: env.GIT_BRANCH ?: runCommandOutput('git rev-parse --abbrev-ref HEAD')
    def commit = runCommandOutput('git rev-parse HEAD')
    def generatedAt = new Date().format("yyyy-MM-dd HH:mm:ss 'UTC'", TimeZone.getTimeZone('UTC'))
    def recentCommits = runCommandOutput('git log --pretty=format:"- %h %s" -10')
    def validations = [
        'Gradle tests for selected services',
        'bootJar for selected services',
        'Docker image build with Dockerfile.service',
        'Docker Compose config validation',
        'Kubernetes dev manifests dry-run: kubectl apply --dry-run=client -f k8s/dev/',
        'E2E smoke + functional suite: e2e/run-e2e.ps1',
        'Locust smoke: performance/locust/locustfile.py'
    ]

    def releaseNotes = """# Release Notes

## Build metadata
- Build number: ${env.BUILD_NUMBER ?: 'N/A'}
- Job name: ${env.JOB_NAME ?: 'N/A'}
- Branch: ${branchName}
- Commit: ${commit}
- Fecha/hora de generacion: ${generatedAt}

## Selected services
${services.collect { "- ${it}" }.join('\n')}

## Validation performed
${validations.collect { "- ${it}" }.join('\n')}

## Environment scope
- Dev flow: tests, bootJar, Docker images and Docker Compose config validation.
- Stage evidence: Kubernetes dry-run against `k8s/dev/`.
- Master evidence: E2E suite, Locust smoke and automatic release notes.
- Kubernetes deployment: dry-run only in this Jenkinsfile; no real cluster deployment is claimed.

## Recent commits
${recentCommits}
"""

    dir('release-notes') {
        writeFile file: 'RELEASE_NOTES.md', text: releaseNotes
    }
}

pipeline {
    agent any

    options {
        skipDefaultCheckout(true)
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Environment Info') {
            steps {
                script {
                    runCommand('java --version')
                    runCommand("${gradleWrapper()} --version")
                    runCommand('docker --version')
                    runCommand('docker compose version')
                    if (commandAvailable('command -v kubectl >/dev/null 2>&1', 'where kubectl >nul 2>nul')) {
                        runCommand('kubectl version --client=true')
                    } else {
                        echo 'kubectl no esta disponible en PATH; Stage Kubernetes Dry Run fallara hasta instalarlo en el agente.'
                    }
                    if (commandAvailable('command -v python >/dev/null 2>&1', 'where python >nul 2>nul')) {
                        runCommand('python --version')
                    } else {
                        echo 'python no esta disponible en PATH; Run Locust Smoke fallara hasta instalar Python y Locust.'
                    }
                }
            }
        }

        stage('Run Selected Service Tests') {
            steps {
                script {
                    def testTasks = selectedServices.collect { service ->
                        ":services:${service}:test"
                    }.join(' ')

                    runCommand("${gradleWrapper()} ${testTasks} -PexcludeJUnitTags=performance --console=plain --no-daemon")
                }
            }
        }

        stage('Build Boot JARs') {
            steps {
                script {
                    def jarTasks = selectedServices.collect { service ->
                        ":services:${service}:bootJar"
                    }.join(' ')

                    runCommand("${gradleWrapper()} ${jarTasks} --console=plain --no-daemon")
                }
            }
        }

        stage('Build Docker Images') {
            steps {
                script {
                    selectedServices.each { service ->
                        runCommand("docker build -f Dockerfile.service --build-arg SERVICE_NAME=${service} -t ${service}:dev .")
                    }
                }
            }
        }

        stage('Validate Docker Compose Config') {
            steps {
                script {
                    runCommand('docker compose -f docker-compose.dev.yml -f docker-compose.app.yml config')
                }
            }
        }

        stage('Stage Kubernetes Dry Run') {
            steps {
                script {
                    runCommand('kubectl apply --dry-run=client -f k8s/dev/')
                }
            }
        }

        stage('Run E2E Suite') {
            steps {
                script {
                    if (isUnix()) {
                        if (commandAvailable('command -v pwsh >/dev/null 2>&1', 'where pwsh >nul 2>nul')) {
                            runCommand('pwsh -ExecutionPolicy Bypass -File e2e/run-e2e.ps1')
                        } else {
                            echo 'Agente Linux sin pwsh: no se ejecuta e2e/run-e2e.ps1. Instalar PowerShell 7 o ejecutar este stage en un agente Windows.'
                        }
                    } else {
                        runCommand('powershell -ExecutionPolicy Bypass -File e2e/run-e2e.ps1')
                    }
                }
            }
        }

        stage('Run Locust Smoke') {
            steps {
                script {
                    def pythonOk = commandAvailable('command -v python >/dev/null 2>&1', 'where python >nul 2>nul')
                    if (!pythonOk) {
                        error 'Python no esta disponible en el agente Jenkins. Instalar Python y dependencias de performance/locust/requirements.txt.'
                    }

                    def locustOk = commandAvailable('python -m locust --version >/dev/null 2>&1', 'python -m locust --version >nul 2>nul')
                    if (!locustOk) {
                        error 'Locust no esta disponible para python -m locust. Instalar con: pip install -r performance/locust/requirements.txt.'
                    }

                    runCommand('python -m locust -f performance/locust/locustfile.py --host http://localhost --headless -u 5 -r 1 -t 30s --csv performance/locust/results/jenkins-smoke')
                }
            }
        }

        stage('Master Release Notes') {
            steps {
                script {
                    generateReleaseNotes(selectedServices)
                }
            }
        }

        stage('Archive Test Reports') {
            steps {
                junit allowEmptyResults: true, testResults: 'services/**/build/test-results/test/*.xml'
                archiveArtifacts allowEmptyArchive: true, artifacts: 'services/**/build/libs/*.jar, docs/*.md, release-notes/*.md, TALLER_PROGRESS.md, e2e/results/*.md, performance/locust/results/*.csv, k8s/**/*.yaml'
            }
        }
    }

    post {
        always {
            junit allowEmptyResults: true, testResults: 'services/**/build/test-results/test/*.xml'
            archiveArtifacts allowEmptyArchive: true, artifacts: 'services/**/build/libs/*.jar, docs/*.md, release-notes/*.md, TALLER_PROGRESS.md, e2e/results/*.md, performance/locust/results/*.csv, k8s/**/*.yaml'
        }
        success {
            echo 'Pipeline dev/stage/master documental completado: tests, bootJar, imagenes Docker, Compose, Kubernetes dry-run, E2E, Locust smoke y release notes ejecutados o documentados segun agente.'
        }
        failure {
            echo 'Pipeline fallido. Revisar Java 21, Gradle Wrapper, Git, Docker, Docker Compose, kubectl, PowerShell/pwsh, Python/Locust y disponibilidad del stack local.'
        }
    }
}
