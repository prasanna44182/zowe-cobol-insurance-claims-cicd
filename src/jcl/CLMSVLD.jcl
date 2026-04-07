//CLMSVLD  JOB (Z77140,CLMS),'CLAIMS VALIDATE',CLASS=A,
//             MSGCLASS=H,MSGLEVEL=(1,1),
//             NOTIFY=&SYSUID,REGION=0M,
//             TIME=1440
//*================================================================
//* CLMSVLD - Validate claims from VSAM
//* Reads Z77140.CLAIMS.VSAM, writes valid to CLAIMS.VALID
//* and rejected to CLAIMS.REJECT
//* Run BEFORE USS DB2 Load
//*================================================================
//JOBLIB    DD DSN=Z77140.LOAD,DISP=SHR
//          DD DSN=CEE.SCEERUN,DISP=SHR
//*
//*--- STEP010: COBOL Validation ---
//*
//STEP010  EXEC PGM=CLMSVALD
//CLAIMIN   DD DSN=Z77140.CLAIMS.VSAM,DISP=SHR
//VALIDOUT  DD DSN=Z77140.CLAIMS.VALID,DISP=OLD
//REJCTOUT  DD DSN=Z77140.CLAIMS.REJECT,DISP=OLD
//SYSOUT    DD SYSOUT=*
//SYSUDUMP  DD SYSOUT=*
//
