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

def generateReleaseNotes() {
    def branchName = env.BRANCH_NAME ?: env.GIT_BRANCH ?: runCommandOutput('git rev-parse --abbrev-ref HEAD')
    def shortCommit = runCommandOutput('git rev-parse --short HEAD')
    def generatedAt = new Date().format("yyyy-MM-dd HH:mm:ss 'UTC'", TimeZone.getTimeZone('UTC'))
    def recentCommits = runCommandOutput('git log --pretty=format:"- %h %s" -10')
    def releaseNotes = """# Release Notes

## Build metadata
- Build number: ${env.BUILD_NUMBER ?: 'N/A'}
- Job name: ${env.JOB_NAME ?: 'N/A'}
- Branch: ${branchName}
- Commit corto: ${shortCommit}
- Fecha/hora de generacion: ${generatedAt}

## Selected services
${selectedServices.collect { "- ${it}" }.join('\n')}

## Validation performed
- Service tests
- bootJar
- Docker image build
- Docker Compose config validation

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
                }
            }
        }

        stage('Run Selected Service Tests') {
            steps {
                script {
                    def testTasks = selectedServices.collect { service ->
                        ":services:${service}:test"
                    }.join(' ')

                    runCommand("${gradleWrapper()} ${testTasks} --console=plain --no-daemon")
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

        stage('Generate Release Notes') {
            steps {
                script {
                    generateReleaseNotes()
                }
            }
        }

        stage('Archive Test Reports') {
            steps {
                junit allowEmptyResults: true, testResults: 'services/**/build/test-results/test/*.xml'
                archiveArtifacts allowEmptyArchive: true, artifacts: 'services/**/build/libs/*.jar, docs/*.md, release-notes/*.md, TALLER_PROGRESS.md'
            }
        }
    }

    post {
        always {
            junit allowEmptyResults: true, testResults: 'services/**/build/test-results/test/*.xml'
            archiveArtifacts allowEmptyArchive: true, artifacts: 'services/**/build/libs/*.jar, docs/*.md, release-notes/*.md, TALLER_PROGRESS.md'
        }
        success {
            echo 'Pipeline base dev completado: tests, bootJar, imagenes Docker locales, validacion de Docker Compose y release notes ejecutados con exito.'
        }
        failure {
            echo 'Pipeline base dev fallido. Revisar la etapa que fallo y confirmar Java 21, Gradle Wrapper, Git y acceso a Docker en el agente Jenkins.'
        }
    }
}
