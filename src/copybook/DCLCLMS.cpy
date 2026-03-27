      *===============================================================
      * DCLCLMS - DB2 DCLGEN for CLAIMS_MASTER table
      * Generated declaration for host variables
      * Table: Z77140.CLAIMS_MASTER
      *===============================================================
       01  DCLCLAIMS-MASTER.
           10  DCL-POLICY-NO       PIC X(10).
           10  DCL-CLAIM-ID        PIC X(08).
           10  DCL-CLAIMANT-NAME   PIC X(30).
           10  DCL-CLAIM-DATE      PIC S9(08) COMP-3.
           10  DCL-CLAIM-TYPE      PIC X(02).
           10  DCL-CLAIM-AMOUNT    PIC S9(07)V99 COMP-3.
           10  DCL-COVERAGE-CODE   PIC X(03).
           10  DCL-STATUS          PIC X(01).
           10  DCL-INSERT-TS       PIC X(26).
