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

        stage('Archive Test Reports') {
            steps {
                junit allowEmptyResults: true, testResults: 'services/**/build/test-results/test/*.xml'
                archiveArtifacts allowEmptyArchive: true, artifacts: 'services/**/build/libs/*.jar, docs/*.md, TALLER_PROGRESS.md'
            }
        }
    }

    post {
        always {
            junit allowEmptyResults: true, testResults: 'services/**/build/test-results/test/*.xml'
            archiveArtifacts allowEmptyArchive: true, artifacts: 'services/**/build/libs/*.jar, docs/*.md, TALLER_PROGRESS.md'
        }
        success {
            echo 'Pipeline base dev completado: tests, bootJar, imagenes Docker locales y validacion de Docker Compose ejecutados con exito.'
        }
        failure {
            echo 'Pipeline base dev fallido. Revisar la etapa que fallo y confirmar Java 21, Gradle Wrapper y acceso a Docker en el agente Jenkins.'
        }
    }
}
