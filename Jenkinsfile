pipeline {
    agent any

    environment {
        // Paths for the Jenkins agent running on the Mac
        FLUTTER_HOME = '/Users/varunpatil/develop/flutter'
        PATH = "/Users/varunpatil/develop/flutter/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        CI = 'true'
        BOT = 'true'
        PUB_ENVIRONMENT = 'bot.jenkins'
        FLUTTER_SUPPRESS_ANALYTICS = 'true'
    }

    stages {
        stage('Checkout Repository') {
            steps {
                cleanWs()
                git branch: 'main',
                    url: 'https://github.com/varunbpatil1121-max/meal_app.git'
            }
        }

        stage('Firebase Config') {
            steps {
                // lib/firebase_options.dart is gitignored. Store it in Jenkins as a
                // "Secret file" credential with ID meal-app-firebase-options to get
                // a build that connects to Firebase; otherwise use a placeholder.
                script {
                    try {
                        withCredentials([file(credentialsId: 'meal-app-firebase-options', variable: 'FIREBASE_OPTIONS')]) {
                            sh 'cp "$FIREBASE_OPTIONS" lib/firebase_options.dart'
                        }
                        echo 'Using Firebase config from Jenkins credentials.'
                    } catch (err) {
                        echo 'No meal-app-firebase-options credential found; using placeholder config (the web build will not connect to Firebase).'
                        sh 'cp ci/firebase_options_placeholder.dart lib/firebase_options.dart'
                    }
                }
            }
        }

        stage('Get Dependencies') {
            steps {
                echo 'Fetching pub packages...'
                sh 'flutter pub get'
            }
        }

        stage('Analyze') {
            steps {
                sh 'flutter analyze'
            }
        }

        stage('Test') {
            steps {
                sh 'flutter test'
            }
        }

        stage('Build Web') {
            steps {
                echo 'Building release web app...'
                sh 'flutter build web --release'
                sh 'cd build && zip -qr meal_app_web.zip web'
            }
        }
    }

    post {
        success {
            archiveArtifacts artifacts: 'build/meal_app_web.zip', allowEmptyArchive: false
        }
        failure {
            echo 'Pipeline failed. Check console output for details.'
        }
    }
}
