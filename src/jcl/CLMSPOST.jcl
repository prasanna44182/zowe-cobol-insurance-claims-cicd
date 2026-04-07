//CLMSPOST JOB (Z77140,CLMS),'CLAIMS POST-LOAD',CLASS=A,
//             MSGCLASS=H,MSGLEVEL=(1,1),
//             NOTIFY=&SYSUID,REGION=0M,
//             TIME=1440
//*================================================================
//* CLMSPOST - Post-load processing (report + alerts)
//* Run AFTER USS DB2 Load has inserted records
//* STEP010: CLMSRPT  - Generate summary report by claim type
//* STEP020: CLMSALRT - REXX alert for claims > $50K
//*================================================================
//JOBLIB    DD DSN=Z77140.LOAD,DISP=SHR
//          DD DSN=DSND10.SDSNLOAD,DISP=SHR
//          DD DSN=DSND10.DBDG.RUNLIB.LOAD,DISP=SHR
//          DD DSN=CEE.SCEERUN,DISP=SHR
//*
//*--- STEP010: DB2 Report (via DSN command processor) ---
//*
//STEP010  EXEC PGM=IKJEFT01
//STEPLIB   DD DISP=SHR,DSN=Z77140.LOAD
//          DD DISP=SHR,DSN=DSND10.DBDG.SDSNEXIT
//          DD DISP=SHR,DSN=DSND10.SDSNLOAD
//          DD DISP=SHR,DSN=ZXP.PUBLIC.LOAD
//RPTFILE   DD DSN=Z77140.CLAIMS.REPORT,DISP=OLD
//SYSTSPRT  DD SYSOUT=*
//SYSPRINT  DD SYSOUT=*
//SYSOUT    DD SYSOUT=*
//SYSUDUMP  DD SYSOUT=*
//SYSTSIN   DD *
  DSN SYSTEM(DBDG)
  RUN PROGRAM(CLMSRPT) PLAN(Z77140) -
      LIB('Z77140.LOAD')
  END
/*
//*
//*--- STEP020: REXX High-Value Alert (via TSO/IKJEFT01) ---
//*
//* Note: STEP010 (CLMSRPT) may fail with -991 plan auth on Z Xplore
//* Run STEP020 regardless of STEP010 result
//STEP020  EXEC PGM=IKJEFT01,
//             PARM='%CLMSALRT DBDG'
//STEPLIB   DD DISP=SHR,DSN=Z77140.LOAD
//          DD DISP=SHR,DSN=DSND10.SDSNLOAD
//          DD DISP=SHR,DSN=DSND10.DBDG.RUNLIB.LOAD
//          DD DISP=SHR,DSN=ZXP.PUBLIC.LOAD
//SYSPROC   DD DSN=Z77140.REXX,DISP=SHR
//SYSTSPRT  DD SYSOUT=*
//SYSTSIN   DD DUMMY
//SYSOUT    DD SYSOUT=*
//SYSUDUMP  DD SYSOUT=*
//
