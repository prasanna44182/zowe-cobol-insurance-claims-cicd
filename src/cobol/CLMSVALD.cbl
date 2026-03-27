      *===============================================================
      * CLMSVALD - Insurance Claims Validator
      * Validates VSAM KSDS input, routes to valid/reject datasets
      * Step 010 in CLMSJOB pipeline
      * Return codes: 0=success  4=warning  8=error  16=severe
      *===============================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CLMSVALD.
       AUTHOR. PRASANNA KUMAR MADALA.
       DATE-WRITTEN. 2026-03-26.
      *===============================================================
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       REPOSITORY.
           FUNCTION ALL INTRINSIC.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT CLAIM-IN    ASSIGN TO CLAIMIN
               ORGANIZATION IS INDEXED
               ACCESS MODE IS SEQUENTIAL
               RECORD KEY IS CLM-POLICY-NUMBER
               FILE STATUS IS WS-CLAIMIN-STATUS.
           SELECT VALID-OUT   ASSIGN TO VALIDOUT
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-VALID-STATUS.
           SELECT REJECT-OUT  ASSIGN TO REJCTOUT
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-REJECT-STATUS.
      *===============================================================
       DATA DIVISION.
       FILE SECTION.
       FD  CLAIM-IN.
           COPY CLAIMREC.

       FD  VALID-OUT
           RECORDING MODE F
           BLOCK CONTAINS 0 RECORDS.
       01  VALID-RECORD            PIC X(100).

       FD  REJECT-OUT
           RECORDING MODE F
           BLOCK CONTAINS 0 RECORDS.
       01  REJECT-RECORD           PIC X(100).
      *===============================================================
       WORKING-STORAGE SECTION.
       01  WS-PROGRAM-ID          PIC X(08) VALUE 'CLMSVALD'.

       01  WS-FILE-STATUSES.
           05  WS-CLAIMIN-STATUS   PIC X(02) VALUE SPACES.
           05  WS-VALID-STATUS     PIC X(02) VALUE SPACES.
           05  WS-REJECT-STATUS    PIC X(02) VALUE SPACES.

       01  WS-COUNTERS.
           05  WS-INPUT-COUNT      PIC 9(07) VALUE ZEROS.
           05  WS-VALID-COUNT      PIC 9(07) VALUE ZEROS.
           05  WS-REJECT-COUNT     PIC 9(07) VALUE ZEROS.

       01  WS-EOF-FLAG             PIC X(01) VALUE 'N'.
           88  END-OF-FILE         VALUE 'Y'.

       01  WS-VALID-FLAG           PIC X(01) VALUE 'N'.
           88  VALID-CLAIM         VALUE 'Y'.
           88  INVALID-CLAIM       VALUE 'N'.

       01  WS-RETURN-CODE          PIC S9(04) COMP VALUE +0.
      *===============================================================
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE.
           PERFORM 2000-PROCESS UNTIL END-OF-FILE.
           PERFORM 9000-TERMINATE.
           MOVE WS-RETURN-CODE TO RETURN-CODE.
           STOP RUN.
      *---------------------------------------------------------------
       1000-INITIALIZE.
           OPEN INPUT  CLAIM-IN
                OUTPUT VALID-OUT REJECT-OUT.
           IF WS-CLAIMIN-STATUS NOT = '00'
               DISPLAY WS-PROGRAM-ID ': OPEN CLAIMIN FAILED FS='
                   WS-CLAIMIN-STATUS
               MOVE +16 TO WS-RETURN-CODE
               PERFORM 9000-TERMINATE
               MOVE WS-RETURN-CODE TO RETURN-CODE
               STOP RUN
           END-IF.
           IF WS-VALID-STATUS NOT = '00'
               DISPLAY WS-PROGRAM-ID ': OPEN VALIDOUT FAILED FS='
                   WS-VALID-STATUS
               MOVE +16 TO WS-RETURN-CODE
               PERFORM 9000-TERMINATE
               MOVE WS-RETURN-CODE TO RETURN-CODE
               STOP RUN
           END-IF.
           IF WS-REJECT-STATUS NOT = '00'
               DISPLAY WS-PROGRAM-ID ': OPEN REJCTOUT FAILED FS='
                   WS-REJECT-STATUS
               MOVE +16 TO WS-RETURN-CODE
               PERFORM 9000-TERMINATE
               MOVE WS-RETURN-CODE TO RETURN-CODE
               STOP RUN
           END-IF.
           PERFORM 2100-READ-INPUT.
      *---------------------------------------------------------------
       2000-PROCESS.
           ADD 1 TO WS-INPUT-COUNT.
           SET INVALID-CLAIM TO TRUE.
           PERFORM 3000-VALIDATE.
           IF VALID-CLAIM
               WRITE VALID-RECORD FROM CLAIM-RECORD
               IF WS-VALID-STATUS NOT = '00'
                   DISPLAY WS-PROGRAM-ID
                       ': WRITE VALID FAILED FS='
                       WS-VALID-STATUS
                   MOVE +8 TO WS-RETURN-CODE
               ELSE
                   ADD 1 TO WS-VALID-COUNT
               END-IF
           ELSE
               WRITE REJECT-RECORD FROM CLAIM-RECORD
               IF WS-REJECT-STATUS NOT = '00'
                   DISPLAY WS-PROGRAM-ID
                       ': WRITE REJECT FAILED FS='
                       WS-REJECT-STATUS
                   MOVE +8 TO WS-RETURN-CODE
               ELSE
                   ADD 1 TO WS-REJECT-COUNT
               END-IF
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
       3000-VALIDATE.
           IF CLM-POLICY-NUMBER = SPACES
               OR CLM-POLICY-NUMBER = LOW-VALUES
               EXIT PARAGRAPH
           END-IF.
           IF CLM-CLAIM-ID = SPACES
               OR CLM-CLAIM-ID = LOW-VALUES
               EXIT PARAGRAPH
           END-IF.
           PERFORM 3100-VALIDATE-DATE.
           IF INVALID-CLAIM
               EXIT PARAGRAPH
           END-IF.
           IF NOT CLM-TYPE-VALID
               EXIT PARAGRAPH
           END-IF.
           IF CLM-CLAIM-AMOUNT NOT > ZEROS
               EXIT PARAGRAPH
           END-IF.
           IF CLM-CLAIM-AMOUNT >= 9999999.99
               EXIT PARAGRAPH
           END-IF.
           SET VALID-CLAIM TO TRUE.
      *---------------------------------------------------------------
       3100-VALIDATE-DATE.
           IF CLM-CLAIM-DATE = ZEROS
               EXIT PARAGRAPH
           END-IF.
           IF CLM-DATE-YYYY < 1900 OR CLM-DATE-YYYY > 2099
               EXIT PARAGRAPH
           END-IF.
           IF CLM-DATE-MM < 01 OR CLM-DATE-MM > 12
               EXIT PARAGRAPH
           END-IF.
           IF CLM-DATE-DD < 01 OR CLM-DATE-DD > 31
               EXIT PARAGRAPH
           END-IF.
           SET VALID-CLAIM TO TRUE.
      *---------------------------------------------------------------
       9000-TERMINATE.
           CLOSE CLAIM-IN VALID-OUT REJECT-OUT.
           DISPLAY WS-PROGRAM-ID ': PROCESSING COMPLETE'.
           DISPLAY WS-PROGRAM-ID ': INPUT='  WS-INPUT-COUNT
                   ' VALID='  WS-VALID-COUNT
                   ' REJECT=' WS-REJECT-COUNT.
           DISPLAY WS-PROGRAM-ID ': RETURN-CODE='
                   WS-RETURN-CODE.
