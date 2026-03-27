      *===============================================================
      * CLAIMREC - Insurance Claims Record Layout
      * VSAM KSDS input record (LRECL=100, key pos 1-10)
      * Shared across CLMSVALD, CLMSDB2, CLMSRPT
      *===============================================================
       01  CLAIM-RECORD.
           05  CLM-POLICY-NUMBER   PIC X(10).
           05  CLM-CLAIM-ID        PIC X(08).
           05  CLM-CLAIMANT-NAME   PIC X(30).
           05  CLM-CLAIM-DATE      PIC 9(08).
               88  CLM-DATE-VALID  VALUE 19000101
                                   THRU 20991231.
           05  CLM-CLAIM-DATE-X REDEFINES CLM-CLAIM-DATE.
               10  CLM-DATE-YYYY  PIC 9(04).
               10  CLM-DATE-MM    PIC 9(02).
               10  CLM-DATE-DD    PIC 9(02).
           05  CLM-CLAIM-TYPE      PIC X(02).
               88  CLM-TYPE-MEDICAL    VALUE 'MD'.
               88  CLM-TYPE-DENTAL     VALUE 'DN'.
               88  CLM-TYPE-DISABILITY VALUE 'DS'.
               88  CLM-TYPE-LIFE       VALUE 'LF'.
               88  CLM-TYPE-VALID      VALUE 'MD' 'DN'
                                             'DS' 'LF'.
           05  CLM-CLAIM-AMOUNT    PIC 9(07)V99.
           05  CLM-COVERAGE-CODE   PIC X(03).
               88  CLM-COV-HMO    VALUE 'HMO'.
               88  CLM-COV-PPO    VALUE 'PPO'.
               88  CLM-COV-EPO    VALUE 'EPO'.
               88  CLM-COV-POS    VALUE 'POS'.
               88  CLM-COV-HDH    VALUE 'HDH'.
               88  CLM-COV-GRP    VALUE 'GRP'.
               88  CLM-COV-IND    VALUE 'IND'.
               88  CLM-COV-TRM    VALUE 'TRM'.
           05  CLM-STATUS          PIC X(01).
               88  CLM-STATUS-NEW      VALUE 'N'.
               88  CLM-STATUS-VALID    VALUE 'V'.
               88  CLM-STATUS-REJECT   VALUE 'R'.
           05  FILLER              PIC X(29).
