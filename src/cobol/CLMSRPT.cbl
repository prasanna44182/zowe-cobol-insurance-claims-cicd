      *===============================================================
      * CLMSRPT - DB2 Cursor Report by Claim Type
      * Step 030 in CLMSJOB pipeline (DB2 precompile required)
      * Produces summary report grouped by claim type
      * Return codes: 0=success  4=warning  8=error  16=severe
      *===============================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CLMSRPT.
       AUTHOR. PRASANNA KUMAR MADALA.
       DATE-WRITTEN. 2026-03-26.
      *===============================================================
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       REPOSITORY.
           FUNCTION ALL INTRINSIC.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT RPT-OUT ASSIGN TO RPTFILE
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-RPT-STATUS.
      *===============================================================
       DATA DIVISION.
       FILE SECTION.
       FD  RPT-OUT
           RECORDING MODE F
           BLOCK CONTAINS 0 RECORDS.
       01  RPT-LINE                PIC X(132).

       WORKING-STORAGE SECTION.
           EXEC SQL INCLUDE SQLCA END-EXEC.

       01  WS-PROGRAM-ID          PIC X(08) VALUE 'CLMSRPT '.

       01  WS-FILE-STATUSES.
           05  WS-RPT-STATUS       PIC X(02) VALUE SPACES.

       01  WS-RETURN-CODE          PIC S9(04) COMP VALUE +0.

       01  WS-CURRENT-DATE-DATA.
           05  WS-DATE-YYYY        PIC 9(04).
           05  WS-DATE-MM          PIC 9(02).
           05  WS-DATE-DD          PIC 9(02).
           05  WS-TIME-HH          PIC 9(02).
           05  WS-TIME-MN          PIC 9(02).
           05  WS-TIME-SS          PIC 9(02).
           05  WS-TIME-HS          PIC 9(02).
           05  WS-GMT-DIFF-HH      PIC S9(02).
           05  WS-GMT-DIFF-MN      PIC S9(02).

       01  WS-PAGE-NUMBER          PIC 9(04) VALUE ZEROS.
       01  WS-LINE-COUNT           PIC 9(02) VALUE 99.
       01  WS-LINES-PER-PAGE       PIC 9(02) VALUE 55.

       01  WS-TITLE-LINE-1.
           05  FILLER              PIC X(50)
               VALUE 'INSURANCE CLAIMS SUMMARY REPORT'.
           05  FILLER              PIC X(52) VALUE SPACES.
           05  FILLER              PIC X(06) VALUE 'PAGE: '.
           05  WS-TL1-PAGE         PIC Z,ZZ9.
           05  FILLER              PIC X(18) VALUE SPACES.

       01  WS-TITLE-LINE-2.
           05  FILLER              PIC X(10) VALUE 'RUN DATE: '.
           05  WS-TL2-DATE         PIC X(10).
           05  FILLER              PIC X(05) VALUE SPACES.
           05  FILLER              PIC X(10) VALUE 'RUN TIME: '.
           05  WS-TL2-TIME         PIC X(08).
           05  FILLER              PIC X(89) VALUE SPACES.

       01  WS-COLUMN-HEADER.
           05  FILLER              PIC X(12) VALUE 'CLAIM TYPE'.
           05  FILLER              PIC X(03) VALUE SPACES.
           05  FILLER              PIC X(12) VALUE 'DESCRIPTION'.
           05  FILLER              PIC X(03) VALUE SPACES.
           05  FILLER              PIC X(12) VALUE 'TOTAL COUNT'.
           05  FILLER              PIC X(03) VALUE SPACES.
           05  FILLER              PIC X(15) VALUE 'TOTAL AMOUNT'.
           05  FILLER              PIC X(03) VALUE SPACES.
           05  FILLER              PIC X(15) VALUE 'AVG AMOUNT'.
           05  FILLER              PIC X(03) VALUE SPACES.
           05  FILLER              PIC X(15) VALUE 'MAX AMOUNT'.
           05  FILLER              PIC X(36) VALUE SPACES.

       01  WS-SEPARATOR-LINE.
           05  FILLER              PIC X(90)  VALUE ALL '-'.
           05  FILLER              PIC X(42)  VALUE SPACES.

       01  WS-DETAIL-LINE.
           05  WS-DL-TYPE          PIC X(02).
           05  FILLER              PIC X(13) VALUE SPACES.
           05  WS-DL-DESC          PIC X(12).
           05  FILLER              PIC X(03) VALUE SPACES.
           05  WS-DL-COUNT         PIC ZZ,ZZ9.
           05  FILLER              PIC X(06) VALUE SPACES.
           05  WS-DL-TOTAL         PIC $$$,$$$,$$9.99.
           05  FILLER              PIC X(01) VALUE SPACES.
           05  WS-DL-AVG           PIC $$$,$$$,$$9.99.
           05  FILLER              PIC X(01) VALUE SPACES.
           05  WS-DL-MAX           PIC $$$,$$$,$$9.99.
           05  FILLER              PIC X(38) VALUE SPACES.

       01  WS-GRAND-TOTAL-LINE.
           05  FILLER              PIC X(15) VALUE 'GRAND TOTAL:'.
           05  WS-GT-COUNT         PIC ZZ,ZZ9.
           05  FILLER              PIC X(06) VALUE SPACES.
           05  WS-GT-TOTAL         PIC $$$,$$$,$$9.99.
           05  FILLER              PIC X(76) VALUE SPACES.

       01  WS-DB2-FIELDS.
           05  WS-CLAIM-TYPE       PIC X(02).
           05  WS-CLAIM-COUNT      PIC S9(09) COMP.
           05  WS-TOTAL-AMOUNT     PIC S9(11)V99 COMP-3.
           05  WS-AVG-AMOUNT       PIC S9(11)V99 COMP-3.
           05  WS-MAX-AMOUNT       PIC S9(11)V99 COMP-3.

       01  WS-GRAND-TOTALS.
           05  WS-GRAND-COUNT      PIC 9(09) VALUE ZEROS.
           05  WS-GRAND-AMOUNT     PIC 9(11)V99 VALUE ZEROS.

       01  WS-TYPE-DESC            PIC X(12).

       01  WS-FETCH-DONE           PIC X(01) VALUE 'N'.
           88  FETCH-COMPLETE      VALUE 'Y'.

           EXEC SQL DECLARE CLMRPT_CURSOR CURSOR FOR
               SELECT CLAIM_TYPE,
                      COUNT(*),
                      SUM(CLAIM_AMOUNT),
                      AVG(CLAIM_AMOUNT),
                      MAX(CLAIM_AMOUNT)
               FROM CLAIMS_MASTER
               GROUP BY CLAIM_TYPE
               ORDER BY CLAIM_TYPE
           END-EXEC.
      *===============================================================
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE.
           PERFORM 2000-OPEN-CURSOR.
           PERFORM 3000-PROCESS-CURSOR
               UNTIL FETCH-COMPLETE.
           PERFORM 4000-WRITE-GRAND-TOTAL.
           PERFORM 5000-CLOSE-CURSOR.
           PERFORM 9000-TERMINATE.
           MOVE WS-RETURN-CODE TO RETURN-CODE.
           STOP RUN.
      *---------------------------------------------------------------
       1000-INITIALIZE.
           MOVE FUNCTION CURRENT-DATE
               TO WS-CURRENT-DATE-DATA.
           STRING WS-DATE-YYYY '-' WS-DATE-MM '-' WS-DATE-DD
               DELIMITED BY SIZE INTO WS-TL2-DATE.
           STRING WS-TIME-HH ':' WS-TIME-MN ':' WS-TIME-SS
               DELIMITED BY SIZE INTO WS-TL2-TIME.
           OPEN OUTPUT RPT-OUT.
           IF WS-RPT-STATUS NOT = '00'
               DISPLAY WS-PROGRAM-ID ': OPEN RPTFILE FAILED FS='
                   WS-RPT-STATUS
               MOVE +16 TO WS-RETURN-CODE
               MOVE WS-RETURN-CODE TO RETURN-CODE
               STOP RUN
           END-IF.
           PERFORM 1100-WRITE-PAGE-HEADER.
      *---------------------------------------------------------------
       1100-WRITE-PAGE-HEADER.
           ADD 1 TO WS-PAGE-NUMBER.
           MOVE WS-PAGE-NUMBER TO WS-TL1-PAGE.
           WRITE RPT-LINE FROM WS-TITLE-LINE-1
               AFTER ADVANCING PAGE.
           WRITE RPT-LINE FROM WS-TITLE-LINE-2.
           WRITE RPT-LINE FROM WS-SEPARATOR-LINE.
           WRITE RPT-LINE FROM WS-COLUMN-HEADER.
           WRITE RPT-LINE FROM WS-SEPARATOR-LINE.
           MOVE 5 TO WS-LINE-COUNT.
      *---------------------------------------------------------------
       2000-OPEN-CURSOR.
           EXEC SQL OPEN CLMRPT_CURSOR END-EXEC.
           IF SQLCODE NOT = 0
               DISPLAY WS-PROGRAM-ID
                   ': CURSOR OPEN FAILED SQLCODE=' SQLCODE
               MOVE +8 TO WS-RETURN-CODE
               SET FETCH-COMPLETE TO TRUE
           END-IF.
      *---------------------------------------------------------------
       3000-PROCESS-CURSOR.
           EXEC SQL
               FETCH CLMRPT_CURSOR
               INTO :WS-CLAIM-TYPE,
                    :WS-CLAIM-COUNT,
                    :WS-TOTAL-AMOUNT,
                    :WS-AVG-AMOUNT,
                    :WS-MAX-AMOUNT
           END-EXEC.

           IF SQLCODE = +100
               SET FETCH-COMPLETE TO TRUE
               EXIT PARAGRAPH
           END-IF.

           IF SQLCODE NOT = 0
               DISPLAY WS-PROGRAM-ID
                   ': FETCH FAILED SQLCODE=' SQLCODE
               MOVE +8 TO WS-RETURN-CODE
               SET FETCH-COMPLETE TO TRUE
               EXIT PARAGRAPH
           END-IF.

           PERFORM 3100-RESOLVE-TYPE-DESC.

           IF WS-LINE-COUNT >= WS-LINES-PER-PAGE
               PERFORM 1100-WRITE-PAGE-HEADER
           END-IF.

           MOVE WS-CLAIM-TYPE     TO WS-DL-TYPE.
           MOVE WS-TYPE-DESC      TO WS-DL-DESC.
           MOVE WS-CLAIM-COUNT    TO WS-DL-COUNT.
           MOVE WS-TOTAL-AMOUNT   TO WS-DL-TOTAL.
           MOVE WS-AVG-AMOUNT     TO WS-DL-AVG.
           MOVE WS-MAX-AMOUNT     TO WS-DL-MAX.
           WRITE RPT-LINE FROM WS-DETAIL-LINE.
           ADD 1 TO WS-LINE-COUNT.
           ADD WS-CLAIM-COUNT     TO WS-GRAND-COUNT.
           ADD WS-TOTAL-AMOUNT    TO WS-GRAND-AMOUNT.
      *---------------------------------------------------------------
       3100-RESOLVE-TYPE-DESC.
           EVALUATE WS-CLAIM-TYPE
               WHEN 'MD'  MOVE 'MEDICAL'    TO WS-TYPE-DESC
               WHEN 'DN'  MOVE 'DENTAL'     TO WS-TYPE-DESC
               WHEN 'DS'  MOVE 'DISABILITY' TO WS-TYPE-DESC
               WHEN 'LF'  MOVE 'LIFE'       TO WS-TYPE-DESC
               WHEN OTHER MOVE 'UNKNOWN'    TO WS-TYPE-DESC
           END-EVALUATE.
      *---------------------------------------------------------------
       4000-WRITE-GRAND-TOTAL.
           WRITE RPT-LINE FROM WS-SEPARATOR-LINE.
           MOVE WS-GRAND-COUNT    TO WS-GT-COUNT.
           MOVE WS-GRAND-AMOUNT   TO WS-GT-TOTAL.
           WRITE RPT-LINE FROM WS-GRAND-TOTAL-LINE.
      *---------------------------------------------------------------
       5000-CLOSE-CURSOR.
           EXEC SQL CLOSE CLMRPT_CURSOR END-EXEC.
      *---------------------------------------------------------------
       9000-TERMINATE.
           CLOSE RPT-OUT.
           DISPLAY WS-PROGRAM-ID ': PROCESSING COMPLETE'.
           DISPLAY WS-PROGRAM-ID ': '
               WS-GRAND-COUNT ' CLAIMS PROCESSED'.
           DISPLAY WS-PROGRAM-ID ': RETURN-CODE='
               WS-RETURN-CODE.
