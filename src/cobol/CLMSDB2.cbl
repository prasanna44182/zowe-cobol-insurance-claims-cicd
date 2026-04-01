      *===============================================================
      * CLMSDB2 - Load valid claims into DB2 CLAIMS_MASTER
      * Step 020 in CLMSJOB pipeline (DB2 precompile required)
      * Reads Z77140.CLAIMS.VALID, INSERTs into CLAIMS_MASTER
      * Commits every WS-COMMIT-INTERVAL rows for log management
      * Return codes: 0=success  4=warnings  8=error  16=severe
      *===============================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CLMSDB2.
       AUTHOR. PRASANNA KUMAR MADALA.
       DATE-WRITTEN. 2026-03-26.
      *===============================================================
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       REPOSITORY.
           FUNCTION ALL INTRINSIC.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT CLAIM-IN ASSIGN TO CLAIMIN
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-CLAIMIN-STATUS.
      *===============================================================
       DATA DIVISION.
       FILE SECTION.
       FD  CLAIM-IN
           RECORDING MODE F
           BLOCK CONTAINS 0 RECORDS.
           COPY CLAIMREC.

      WORKING-STORAGE SECTION.
          EXEC SQL INCLUDE SQLCA END-EXEC.
          EXEC SQL SET CURRENT SCHEMA = 'Z77140' END-EXEC.
          COPY DCLCLMS.

       01  WS-PROGRAM-ID          PIC X(08) VALUE 'CLMSDB2 '.

       01  WS-FILE-STATUSES.
           05  WS-CLAIMIN-STATUS   PIC X(02) VALUE SPACES.

       01  WS-COUNTERS.
           05  WS-INPUT-COUNT      PIC 9(07) VALUE ZEROS.
           05  WS-INSERT-COUNT     PIC 9(07) VALUE ZEROS.
           05  WS-DUPKEY-COUNT     PIC 9(07) VALUE ZEROS.
           05  WS-ERROR-COUNT      PIC 9(07) VALUE ZEROS.
           05  WS-COMMIT-COUNT     PIC 9(07) VALUE ZEROS.

       01  WS-COMMIT-INTERVAL      PIC 9(04) VALUE 500.

       01  WS-EOF-FLAG             PIC X(01) VALUE 'N'.
           88  END-OF-FILE         VALUE 'Y'.

       01  WS-RETURN-CODE          PIC S9(04) COMP VALUE +0.

       01  WS-CURRENT-TS           PIC X(26).
      *===============================================================
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE.
           PERFORM 2000-PROCESS UNTIL END-OF-FILE.
           PERFORM 3000-FINAL-COMMIT.
           PERFORM 9000-TERMINATE.
           MOVE WS-RETURN-CODE TO RETURN-CODE.
           STOP RUN.
      *---------------------------------------------------------------
       1000-INITIALIZE.
           DISPLAY WS-PROGRAM-ID ': DB2 LOAD STARTING'.
           OPEN INPUT CLAIM-IN.
           IF WS-CLAIMIN-STATUS NOT = '00'
               DISPLAY WS-PROGRAM-ID ': OPEN CLAIMIN FAILED FS='
                   WS-CLAIMIN-STATUS
               MOVE +16 TO WS-RETURN-CODE
               MOVE WS-RETURN-CODE TO RETURN-CODE
               STOP RUN
           END-IF.
           PERFORM 2100-READ-INPUT.
      *---------------------------------------------------------------
       2000-PROCESS.
           ADD 1 TO WS-INPUT-COUNT.
           PERFORM 2200-MOVE-TO-DCLGEN.
           PERFORM 2300-INSERT-CLAIM.
           IF WS-COMMIT-COUNT >= WS-COMMIT-INTERVAL
               PERFORM 2400-INTERIM-COMMIT
           END-IF.
           PERFORM 2100-READ-INPUT.
      *---------------------------------------------------------------
       2100-READ-INPUT.
           READ CLAIM-IN
               AT END SET END-OF-FILE TO TRUE
           END-READ.
           IF WS-CLAIMIN-STATUS NOT = '00'
               AND WS-CLAIMIN-STATUS NOT = '10'
               DISPLAY WS-PROGRAM-ID ': READ FAILED FS='
                   WS-CLAIMIN-STATUS
               MOVE +8 TO WS-RETURN-CODE
               SET END-OF-FILE TO TRUE
           END-IF.
      *---------------------------------------------------------------
       2200-MOVE-TO-DCLGEN.
           MOVE CLM-POLICY-NUMBER  TO DCL-POLICY-NO.
           MOVE CLM-CLAIM-ID       TO DCL-CLAIM-ID.
           MOVE CLM-CLAIMANT-NAME  TO DCL-CLAIMANT-NAME.
           MOVE CLM-CLAIM-DATE     TO DCL-CLAIM-DATE.
           MOVE CLM-CLAIM-TYPE     TO DCL-CLAIM-TYPE.
           MOVE CLM-CLAIM-AMOUNT   TO DCL-CLAIM-AMOUNT.
           MOVE CLM-COVERAGE-CODE  TO DCL-COVERAGE-CODE.
           MOVE CLM-STATUS         TO DCL-STATUS.

           EXEC SQL
               SET :DCL-INSERT-TS = CURRENT TIMESTAMP
           END-EXEC.
      *---------------------------------------------------------------
       2300-INSERT-CLAIM.
           EXEC SQL
               INSERT INTO CLAIMS_MASTER
               (POLICY_NO,     CLAIM_ID,       CLAIMANT_NAME,
                CLAIM_DATE,    CLAIM_TYPE,      CLAIM_AMOUNT,
                COVERAGE_CODE, STATUS,          INSERT_TS)
               VALUES
               (:DCL-POLICY-NO,      :DCL-CLAIM-ID,
                :DCL-CLAIMANT-NAME,   :DCL-CLAIM-DATE,
                :DCL-CLAIM-TYPE,      :DCL-CLAIM-AMOUNT,
                :DCL-COVERAGE-CODE,   :DCL-STATUS,
                :DCL-INSERT-TS)
           END-EXEC.

           EVALUATE SQLCODE
               WHEN 0
                   ADD 1 TO WS-INSERT-COUNT
                   ADD 1 TO WS-COMMIT-COUNT
               WHEN -803
                   ADD 1 TO WS-DUPKEY-COUNT
                   IF WS-RETURN-CODE < +4
                       MOVE +4 TO WS-RETURN-CODE
                   END-IF
                   DISPLAY WS-PROGRAM-ID ': DUP KEY POLICY='
                       DCL-POLICY-NO ' CLAIM=' DCL-CLAIM-ID
               WHEN OTHER
                   ADD 1 TO WS-ERROR-COUNT
                   MOVE +8 TO WS-RETURN-CODE
                   DISPLAY WS-PROGRAM-ID ': SQL ERROR='
                       SQLCODE ' POLICY=' DCL-POLICY-NO
                   EXEC SQL ROLLBACK END-EXEC
           END-EVALUATE.
      *---------------------------------------------------------------
       2400-INTERIM-COMMIT.
           EXEC SQL COMMIT END-EXEC.
           IF SQLCODE NOT = 0
               DISPLAY WS-PROGRAM-ID ': INTERIM COMMIT FAILED='
                   SQLCODE
               MOVE +8 TO WS-RETURN-CODE
           ELSE
               DISPLAY WS-PROGRAM-ID ': COMMITTED '
                   WS-INSERT-COUNT ' ROWS SO FAR'
               MOVE ZEROS TO WS-COMMIT-COUNT
           END-IF.
      *---------------------------------------------------------------
       3000-FINAL-COMMIT.
           IF WS-COMMIT-COUNT > 0
               EXEC SQL COMMIT END-EXEC
               IF SQLCODE NOT = 0
                   DISPLAY WS-PROGRAM-ID
                       ': FINAL COMMIT FAILED=' SQLCODE
                   MOVE +8 TO WS-RETURN-CODE
               END-IF
           END-IF.
      *---------------------------------------------------------------
       9000-TERMINATE.
           CLOSE CLAIM-IN.
           DISPLAY WS-PROGRAM-ID ': PROCESSING COMPLETE'.
           DISPLAY WS-PROGRAM-ID ': INPUT='    WS-INPUT-COUNT
                   ' INSERTED=' WS-INSERT-COUNT
                   ' DUPKEYS='  WS-DUPKEY-COUNT
                   ' ERRORS='   WS-ERROR-COUNT.
           DISPLAY WS-PROGRAM-ID ': RETURN-CODE='
                   WS-RETURN-CODE.
