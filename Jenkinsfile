pipeline {
    agent any

    environment {
        // Paths for the Jenkins agent running on the Mac
        FLUTTER_HOME = '/Users/varunpatil/develop/flutter'
        ANDROID_HOME = '/Users/varunpatil/Library/Android/sdk'
        JAVA_HOME = '/Applications/Android Studio.app/Contents/jbr/Contents/Home'
        PATH = "/Users/varunpatil/develop/flutter/bin:/Users/varunpatil/Library/Android/sdk/cmdline-tools/latest/bin:/Users/varunpatil/Library/Android/sdk/platform-tools:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
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
                // The Firebase config files are gitignored. Store them in Jenkins as
                // "Secret file" credentials to get builds that connect to Firebase:
                //   meal-app-firebase-options  -> lib/firebase_options.dart
                //   meal-app-google-services   -> android/app/google-services.json
                // Without them, placeholders are used so the build still succeeds.
                script {
                    try {
                        withCredentials([file(credentialsId: 'meal-app-firebase-options', variable: 'FIREBASE_OPTIONS')]) {
                            sh 'cp "$FIREBASE_OPTIONS" lib/firebase_options.dart'
                        }
                        echo 'Using Firebase options from Jenkins credentials.'
                    } catch (err) {
                        echo 'No meal-app-firebase-options credential; using placeholder (builds will not connect to Firebase).'
                        sh 'cp ci/firebase_options_placeholder.dart lib/firebase_options.dart'
                    }
                    try {
                        withCredentials([file(credentialsId: 'meal-app-google-services', variable: 'GOOGLE_SERVICES')]) {
                            sh 'cp "$GOOGLE_SERVICES" android/app/google-services.json'
                        }
                        echo 'Using google-services.json from Jenkins credentials.'
                    } catch (err) {
                        echo 'No meal-app-google-services credential; using placeholder google-services.json.'
                        sh 'cp ci/google-services.placeholder.json android/app/google-services.json'
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

        stage('Build AAB and APK') {
            steps {
                echo 'Building release AAB and APK...'
                script {
                    def build = '''
                        flutter build appbundle --release
                        flutter build apk --release
                    '''
                    try {
                        withCredentials([
                            file(credentialsId: 'meal-app-keystore', variable: 'KEYSTORE_FILE'),
                            string(credentialsId: 'meal-app-store-password', variable: 'STORE_PASSWORD'),
                            string(credentialsId: 'meal-app-key-password', variable: 'KEY_PASSWORD')
                        ]) {
                            // Write key.properties for release signing (it is gitignored)
                            sh '''
                                cat > android/key.properties <<EOF
storePassword=$STORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=meal_app_upload
storeFile=$KEYSTORE_FILE
EOF
                            '''
                            echo 'Signing with the release key from Jenkins credentials.'
                            sh build
                        }
                    } catch (err) {
                        if (fileExists('android/key.properties')) {
                            sh 'rm -f android/key.properties'
                            throw err // the signed build itself failed
                        }
                        echo 'No meal-app-keystore credentials; signing with the debug key (fine for installing, not for Google Play).'
                        sh build
                    } finally {
                        sh 'rm -f android/key.properties'
                    }
                }
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
            archiveArtifacts artifacts: 'build/app/outputs/bundle/release/app-release.aab, build/app/outputs/flutter-apk/app-release.apk, build/meal_app_web.zip', allowEmptyArchive: false
        }
        failure {
            echo 'Pipeline failed. Check console output for details.'
        }
    }
}
