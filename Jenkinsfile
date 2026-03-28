pipeline {
    agent any

    environment {
        HLQ = 'Z77140'
        ZOWE_PROFILE = 'zosmf'
        PATH = "/usr/local/bin:/opt/homebrew/bin:${env.PATH}"
    }

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 20, unit: 'MINUTES')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Upload COBOL') {
            steps {
                sh "zowe zos-files upload dir-to-pds src/cobol ${HLQ}.CBL"
            }
        }

        stage('Upload Copybooks') {
            steps {
                sh "zowe zos-files upload dir-to-pds src/copybook ${HLQ}.COPYBOOK"
            }
        }

        stage('Upload JCL') {
            steps {
                sh "zowe zos-files upload dir-to-pds src/jcl ${HLQ}.JCL"
            }
        }

        stage('Upload REXX') {
            steps {
                sh "zowe zos-files upload dir-to-pds src/rexx ${HLQ}.REXX"
            }
        }

        stage('Upload DB2 DDL') {
            steps {
                sh "zowe zos-files upload dir-to-pds src/db2 ${HLQ}.SQL"
            }
        }

        stage('Compile') {
            steps {
                script {
                    def output = sh(
                        script: "zowe jobs submit data-set \"${HLQ}.JCL(CLMSCMP)\" --wait-for-output --rff jobid --rft string",
                        returnStdout: true
                    ).trim()
                    env.COMPILE_JOBID = output
                    echo "Compile Job ID: ${env.COMPILE_JOBID}"
                }
            }
        }

        stage('Verify Compile') {
            steps {
                script {
                    def retcode = sh(
                        script: "zowe jobs view job-status-by-jobid ${env.COMPILE_JOBID} --rff retcode --rft string",
                        returnStdout: true
                    ).trim()
                    echo "Compile Return Code: ${retcode}"
                    if (retcode != 'CC 0000' && retcode != 'CC 0004') {
                        sh "zowe jobs view all-spool-content ${env.COMPILE_JOBID}"
                        error("Compile FAILED with ${retcode}")
                    }
                }
            }
        }

        stage('Bind DB2') {
            steps {
                script {
                    def output = sh(
                        script: "zowe jobs submit data-set \"${HLQ}.JCL(CLMSBIND)\" --wait-for-output --rff jobid --rft string",
                        returnStdout: true
                    ).trim()
                    env.BIND_JOBID = output
                    echo "Bind Job ID: ${env.BIND_JOBID}"
                }
            }
        }

        stage('Verify Bind') {
            steps {
                script {
                    def retcode = sh(
                        script: "zowe jobs view job-status-by-jobid ${env.BIND_JOBID} --rff retcode --rft string",
                        returnStdout: true
                    ).trim()
                    echo "Bind Return Code: ${retcode}"
                    if (retcode != 'CC 0000' && retcode != 'CC 0004') {
                        sh "zowe jobs view all-spool-content ${env.BIND_JOBID}"
                        error("Bind FAILED with ${retcode}")
                    }
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline SUCCESS — compile + DB2 bind verified on z/OS"
        }
        failure {
            echo "Pipeline FAILED - check JES spool output"
        }
        always {
            echo "HLQ: ${HLQ} | Compile: ${env.COMPILE_JOBID ?: 'N/A'} | Bind: ${env.BIND_JOBID ?: 'N/A'}"
        }
    }
}
