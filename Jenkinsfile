pipeline {
    agent any

    environment {
        JAVA_HOME = '/opt/java/openjdk'
        MAVEN_HOME = '/usr/share/maven'
        PATH = "${JAVA_HOME}/bin:${MAVEN_HOME}/bin:${PATH}"
        DOCKER_IMAGE = 'catalog-service'
        DOCKER_TAG = "${BUILD_NUMBER}"
        DATABASE_URL = 'jdbc:postgresql://catalog-db:5432/postgres'
        DB_USERNAME = 'postgres'
        DB_PASSWORD = 'postgres'
    }

    tools {
        maven 'Maven-3.9.9'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()
                }
            }
        }

        stage('Build Parent Project') {
            steps {
                sh '''
                    echo "Building parent project..."
                    ./mvnw clean compile -DskipTests
                '''
            }
        }

        stage('Build and Test Catalog Service') {
            parallel {
                stage('Maven Build') {
                    steps {
                        dir('catalog-service') {
                            sh '''
                                echo "Building catalog-service..."
                                ./mvnw clean compile -DskipTests
                            '''
                        }
                    }
                }

                stage('Unit Tests') {
                    steps {
                        dir('catalog-service') {
                            sh '''
                                echo "Running unit tests..."
                                ./mvnw test
                            '''
                        }

                        // Publish test results
                        publishTestResults testResultsPattern: 'catalog-service/target/surefire-reports/*.xml'

                        // Publish JaCoCo code coverage
                        publishCoverage adapters: [
                            jacocoAdapter('catalog-service/target/site/jacoco/jacoco.xml')
                        ]
                    }
                }
            }
        }

        stage('Package') {
            steps {
                dir('catalog-service') {
                    sh '''
                        echo "Packaging application..."
                        ./mvnw package -DskipTests
                    '''
                }

                // Archive artifacts
                archiveArtifacts artifacts: 'catalog-service/target/*.jar', fingerprint: true
            }
        }

        stage('Docker Build') {
            steps {
                script {
                    dir('catalog-service') {
                        def image = docker.build("${DOCKER_IMAGE}:${DOCKER_TAG}")

                        // Also tag as latest
                        sh "docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest"

                        echo "Built Docker image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                    }
                }
            }
        }

        stage('Integration Tests') {
            steps {
                script {
                    try {
                        // Start infrastructure
                        sh '''
                            cd deployment/docker-compose
                            docker-compose -f infra.yml up -d
                            sleep 30
                        '''

                        // Start the service for integration testing
                        sh '''
                            # Stop any existing containers
                            docker stop catalog-service-test || true
                            docker rm catalog-service-test || true

                            # Start the service with test profile
                            docker run -d \
                                --name catalog-service-test \
                                --network deployment_docker-compose_default \
                                -p 8082:8081 \
                                -e SPRING_PROFILES_ACTIVE=test \
                                -e DB_URL=jdbc:postgresql://catalog-db:5432/postgres \
                                -e DB_USERNAME=postgres \
                                -e DB_PASSWORD=postgres \
                                catalog-service:latest

                            # Wait for service to be ready
                            sleep 30

                            # Run health check
                            curl -f http://localhost:8082/actuator/health || exit 1
                        '''
                    } finally {
                        // Cleanup
                        sh '''
                            docker stop catalog-service-test || true
                            docker rm catalog-service-test || true
                            cd deployment/docker-compose
                            docker-compose -f infra.yml down || true
                        '''
                    }
                }
            }
        }

        stage('Deploy to Staging') {
            when {
                branch 'develop'
            }
            steps {
                script {
                    sh '''
                        echo "Deploying to staging environment..."

                        # Start infrastructure
                        cd deployment/docker-compose
                        docker-compose -f infra.yml up -d

                        # Stop existing staging container
                        docker stop catalog-service-staging || true
                        docker rm catalog-service-staging || true

                        # Deploy to staging
                        docker run -d \
                            --name catalog-service-staging \
                            --network deployment_docker-compose_default \
                            -p 8083:8081 \
                            -e SPRING_PROFILES_ACTIVE=staging \
                            -e DB_URL=jdbc:postgresql://catalog-db:5432/postgres \
                            -e DB_USERNAME=postgres \
                            -e DB_PASSWORD=postgres \
                            catalog-service:latest

                        echo "Staging deployment completed. Service available at: http://localhost:8083"
                    '''
                }
            }
        }

        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                script {
                    input message: 'Deploy to production?', ok: 'Deploy',
                          submitterParameter: 'DEPLOYER'

                    sh '''
                        echo "Deploying to production environment..."
                        echo "Deployed by: ${DEPLOYER}"

                        # Start infrastructure
                        cd deployment/docker-compose
                        docker-compose -f infra.yml up -d

                        # Stop existing production container
                        docker stop catalog-service-prod || true
                        docker rm catalog-service-prod || true

                        # Deploy to production
                        docker run -d \
                            --name catalog-service-prod \
                            --network deployment_docker-compose_default \
                            -p 8081:8081 \
                            -e SPRING_PROFILES_ACTIVE=production \
                            -e DB_URL=jdbc:postgresql://catalog-db:5432/postgres \
                            -e DB_USERNAME=postgres \
                            -e DB_PASSWORD=postgres \
                            catalog-service:latest

                        echo "Production deployment completed"
                    '''
                }
            }
        }
    }

    post {
        always {
            cleanWs()
            sh 'docker image prune -f'
        }

        success {
            echo 'Pipeline succeeded! 🎉'
        }

        failure {
            echo 'Pipeline failed! ❌'
        }
    }
}