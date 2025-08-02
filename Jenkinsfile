pipeline {
    agent any

    environment {
        WORKING_DIRECTORY = 'catalog-service'
    }

    stages {
        stage('Checkout and Build') {
            steps {
                checkout scm

                dir("${env.WORKING_DIRECTORY}") {
                    sh './mvnw -ntp verify'
                }
            }
        }
    }

    post {
        success {
            echo "Build successful!"
        }
        failure {
            echo "Build failed!"
        }
    }
}
