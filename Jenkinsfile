// =================================================================
// IBM DBB + Jenkins Enterprise Pipeline Reference
// Pattern used at JPMorgan, Mastercard, US Bank
// =================================================================
// This Jenkinsfile documents the enterprise zAppBuild pipeline.
// GitHub Actions (mainframe-cicd.yml) is the active CI for this repo.
// =================================================================

pipeline {
    agent any
    environment {
        DBB_HLQ = 'Z77140'
        ZOSMF_PROFILE = 'zosmf'
    }
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('DBB Build') {
            steps {
                sh '''
                    groovyz ${DBB_HOME}/build.groovy \
                        --workspace ${WORKSPACE} \
                        --hlq ${DBB_HLQ} \
                        --application zowe-cobol-insurance-claims-cicd
                '''
            }
        }
        stage('Compile COBOL') {
            steps {
                sh 'dbb build --files "src/cobol/**/*.cbl"'
            }
        }
        stage('Deploy to z/OS') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'zosmf',
                    usernameVariable: 'ZOSMF_USER',
                    passwordVariable: 'ZOSMF_PASS'
                )]) {
                    sh '''
                        zowe zos-files upload dir-to-pds src/cobol ${DBB_HLQ}.CBL
                        zowe zos-files upload dir-to-pds src/jcl ${DBB_HLQ}.JCL
                    '''
                }
            }
        }
        stage('Submit Build Job') {
            steps {
                sh 'zowe jobs submit jcl "Z77140.JCL(CLMSCMP)" --wait'
            }
        }
        stage('Verify') {
            steps {
                sh 'zowe jobs list spool-files-by-jobid $(zowe jobs list jobs --prefix Z77140 -o json | jq -r ".[0].jobid")'
            }
        }
    }
    post {
        success { echo 'Pipeline SUCCESS — CC 0000' }
        failure { echo 'Pipeline FAILED — check JES spool' }
    }
}
