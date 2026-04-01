//CLMSBIND JOB (Z77140,CLMS),'DB2 BIND',CLASS=A,
//             MSGCLASS=H,MSGLEVEL=(1,1),
//             NOTIFY=&SYSUID,REGION=0M
//*================================================================
//* BIND packages + plan for CLMSDB2 / CLMSRPT (run after CLMSCMP)
//* IBM Z Xplore typically grants BINDADD for your own user-named
//* collection (e.g. Z77140); bind packages there, not a shared CLMPKG.
//* DBRMs: Z77140.DBRMLIB(CLMSDB2) Z77140.DBRMLIB(CLMSRPT)
//* Plan CLMPLAN must exist before CLMSJOB RUN PROGRAM ... PLAN(Z77140)
//*================================================================
//BIND     EXEC PGM=IKJEFT01
//STEPLIB   DD DSN=Z77140.LOAD,DISP=SHR
//         DD DSN=DSND10.SDSNLOAD,DISP=SHR
//SYSTSPRT  DD SYSOUT=*
//SYSPRINT  DD SYSOUT=*
//SYSUDUMP  DD SYSOUT=*
//SYSTSIN   DD *
  DSN SYSTEM(DBDG)
  BIND PACKAGE(Z77140) -
       MEMBER(CLMSDB2) -
       LIBRARY('Z77140.DBRMLIB') -
       ACTION(REPLACE) -
       ISOLATION(CS)
  BIND PACKAGE(Z77140) -
       MEMBER(CLMSRPT) -
       LIBRARY('Z77140.DBRMLIB') -
       ACTION(REPLACE) -
       ISOLATION(CS)
  BIND PLAN(Z77140) -
       PKLIST(Z77140.*) -
       ACTION(REPLACE)
  END
/*
