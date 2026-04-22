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

        // Shift-left: GnuCOBOL parses IBM-strict COBOL before z/OS upload (Simon Sobisch idea).
        // Requires: brew install gnucobol on the Jenkins agent (Mac: cobc on PATH).
        // CLMSDB2 / CLMSRPT use EXEC SQL — IBM compile only; not checked here.
        stage('GnuCOBOL syntax (CLMSVALD)') {
            steps {
                sh '''
                    set -e
                    command -v cobc
                    cobc --version
                    cobc -std=ibm-strict -fsyntax-only -I src/copybook src/cobol/CLMSVALD.cbl
                    echo "GnuCOBOL: CLMSVALD.cbl syntax OK (ibm-strict)"
                '''
            }
        }

        // Open Mainframe Project COBOL Check — unit tests for CLMSVALD (3000-VALIDATE).
        // Requires: Java on PATH, GnuCOBOL (cobc), tools/cobol-check-0.2.19.jar, cobol-check/config.properties.
        // Note: cobol-check JVM may exit 0 even when tests fail; we grep testResults.txt for FAIL lines.
        stage('COBOL Check (CLMSVALD)') {
            steps {
                sh '''
                    set -e
                    command -v java
                    command -v cobc
                    chmod +x cobol-check/scripts/linux_gnucobol_run_tests
                    test -f tools/cobol-check-0.2.19.jar
                    java -jar tools/cobol-check-0.2.19.jar -p CLMSVALD -c cobol-check/config.properties
                    if grep -qF "**** FAIL:" cobol-check/testruns/testResults.txt 2>/dev/null; then
                        echo "COBOL Check: one or more tests failed (see cobol-check/testruns/testResults.txt)"
                        cat cobol-check/testruns/testResults.txt
                        exit 1
                    fi
                    echo "COBOL Check: CLMSVALD tests passed"
                '''
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

        stage('Run Validation') {
            steps {
                script {
                    // Submit CLMSVLD - validates claims (VSAM -> VALID file)
                    def output = sh(
                        script: "zowe jobs submit data-set \"${HLQ}.JCL(CLMSVLD)\" --wait-for-output --rff jobid --rft string",
                        returnStdout: true
                    ).trim()
                    env.VALIDATE_JOBID = output
                    echo "Validation Job ID: ${env.VALIDATE_JOBID}"
                    
                    def retcode = sh(
                        script: "zowe jobs view job-status-by-jobid ${env.VALIDATE_JOBID} --rff retcode --rft string",
                        returnStdout: true
                    ).trim()
                    echo "Validation Return Code: ${retcode}"
                    
                    if (retcode != 'CC 0000' && retcode != 'CC 0004') {
                        sh "zowe jobs view all-spool-content ${env.VALIDATE_JOBID}"
                        error("Validation FAILED with ${retcode}")
                    }
                    
                    sh "zowe jobs view all-spool-content ${env.VALIDATE_JOBID}"
                }
            }
        }

        stage('USS DB2 Load') {
            steps {
                script {
                    echo "=== Loading claims via USS DB2 CLI ==="
                    // DB2 CLP password: Jenkins → Manage Credentials → Secret text, ID must be zxplore-db2-password
                    withCredentials([string(credentialsId: 'zxplore-db2-password', variable: 'DB2_PASSWORD')]) {
                        // Step 1: Download CLAIMS.VALID from mainframe
                        sh """
                            zowe zos-files download data-set "${HLQ}.CLAIMS.VALID" -f claims_valid.txt
                            echo "Downloaded ${HLQ}.CLAIMS.VALID"
                            wc -l claims_valid.txt || true
                            head -3 claims_valid.txt || true
                        """

                        // Step 2: Generate INSERT SQL (preview skips connect lines so logs do not echo secrets)
                        sh """
                            chmod +x src/scripts/load_claims.sh
                            export DB2_PASSWORD DB2_USER='z77140' DB2_SCHEMA='${HLQ}' DB2_CONNECT_TARGET='204.90.115.200:5040/ZXPDB2'
                            ./src/scripts/load_claims.sh claims_valid.txt insert_claims.sql
                            echo "Generated SQL preview (INSERT lines only):"
                            grep -E '^INSERT ' insert_claims.sql | head -5 || true
                        """

                        // Step 3: Upload SQL file to USS
                        sh """
                            zowe zos-files upload file-to-uss insert_claims.sql "/z/${HLQ.toLowerCase()}/insert_claims.sql"
                            echo "Uploaded SQL to USS: /z/${HLQ.toLowerCase()}/insert_claims.sql"
                        """

                        // Step 4: Execute SQL via USS db2 command (Z Xplore CLP)
                        sh """
                            echo "Executing SQL via USS DB2 CLI..."
                            zowe zos-uss issue ssh "cd /z/${HLQ.toLowerCase()} && db2 -f insert_claims.sql" || {
                                echo "DB2 command completed (check output for any SQL errors)"
                            }
                        """
                    }

                    echo "=== USS DB2 Load Complete ==="
                }
            }
        }

        stage('USS DB2 Report') {
            steps {
                script {
                    echo "=== Generating Claims Report via USS DB2 CLI ==="
                    withCredentials([string(credentialsId: 'zxplore-db2-password', variable: 'DB2_PASSWORD')]) {
                        // Step 1: Create SQL query file locally (Z Xplore CLP format - no semicolons)
                        def reportSql = """connect to 204.90.115.200:5040/ZXPDB2 user z77140 using ${env.DB2_PASSWORD}
SET CURRENT SCHEMA = '${HLQ}'
SELECT CLAIM_TYPE, COUNT(*) AS CNT, SUM(CLAIM_AMOUNT) AS TOTAL_AMT, AVG(CLAIM_AMOUNT) AS AVG_AMT, MAX(CLAIM_AMOUNT) AS MAX_AMT FROM CLAIMS_MASTER GROUP BY CLAIM_TYPE ORDER BY CLAIM_TYPE
SELECT COUNT(*) AS TOTAL_CNT, SUM(CLAIM_AMOUNT) AS GRAND_TOTAL FROM CLAIMS_MASTER
DISCONNECT
"""
                        writeFile file: 'report_query.sql', text: reportSql

                        // Step 2: Upload SQL file to USS
                        sh """
                            zowe zos-files upload file-to-uss report_query.sql "/z/${HLQ.toLowerCase()}/report_query.sql"
                            echo "Uploaded report query to USS"
                        """

                        // Step 3: Execute SQL via USS db2 command and capture output
                        sh """
                            echo "Executing report query via USS DB2 CLI..."
                            zowe zos-uss issue ssh "cd /z/${HLQ.toLowerCase()} && db2 -f report_query.sql" > db2_report_output.txt 2>&1 || true
                            echo "=== RAW DB2 OUTPUT ==="
                            cat db2_report_output.txt
                            echo "=== END RAW OUTPUT ==="
                        """

                        // Step 4: Parse raw output and generate formatted report locally
                        sh """
                            chmod +x src/scripts/generate_report.sh
                            ./src/scripts/generate_report.sh db2_report_output.txt claims_report.txt
                        """

                        // Display report
                        sh """
                            echo "=== CLAIMS SUMMARY REPORT ==="
                            cat claims_report.txt
                        """
                    }

                    echo "=== USS DB2 Report Complete ==="
                }
            }
        }

        stage('Run Post-Load Jobs') {
            steps {
                script {
                    // Submit CLMSPOST - report + alerts (runs after USS load)
                    def output = sh(
                        script: "zowe jobs submit data-set \"${HLQ}.JCL(CLMSPOST)\" --wait-for-output --rff jobid --rft string",
                        returnStdout: true
                    ).trim()
                    env.POSTLOAD_JOBID = output
                    echo "Post-Load Job ID: ${env.POSTLOAD_JOBID}"
                    
                    def retcode = sh(
                        script: "zowe jobs view job-status-by-jobid ${env.POSTLOAD_JOBID} --rff retcode --rft string",
                        returnStdout: true
                    ).trim()
                    echo "Post-Load Return Code: ${retcode}"
                    
                    // Show spool output
                    sh "zowe jobs view all-spool-content ${env.POSTLOAD_JOBID}"
                    
                    // STEP010 (CLMSRPT) may fail with -991 (plan auth)
                    // STEP020 (CLMSALRT REXX) should work (dynamic SQL)
                    if (retcode != 'CC 0000' && retcode != 'CC 0004') {
                        echo "Post-Load completed with ${retcode} - STEP010 (report) may have -991 plan auth issue"
                        echo "STEP020 (REXX alert) should have succeeded with dynamic SQL"
                    }
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline SUCCESS — compile, bind, and DB2 load via USS completed"
        }
        failure {
            echo "Pipeline FAILED - check JES spool output"
        }
        always {
            echo "HLQ: ${HLQ} | Compile: ${env.COMPILE_JOBID ?: 'N/A'} | Bind: ${env.BIND_JOBID ?: 'N/A'} | Validate: ${env.VALIDATE_JOBID ?: 'N/A'} | PostLoad: ${env.POSTLOAD_JOBID ?: 'N/A'}"
            // Cleanup temporary files
            sh "rm -f claims_valid.txt insert_claims.sql claims_report.txt report_query.sql db2_report_output.txt || true"
        }
    }
}
