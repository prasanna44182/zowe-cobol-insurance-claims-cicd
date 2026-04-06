//CLMSBIND JOB (Z77140,CLMS),'DB2 BIND',CLASS=A,
//             MSGCLASS=H,MSGLEVEL=(1,1),
//             NOTIFY=&SYSUID,REGION=0M
//*================================================================
//* BIND plan Z77140 from DBRMs (run after CLMSCMP)
//* IBM Z Xplore: BINDADD removed platform-wide BIND PACKAGE is not
//* allowed. Bind only into your own Z##### plan using BIND PLAN with
//* MEMBER (DBRM registration + plan in one step per program).
//* DBRMs: Z77140.DBRMLIB(CLMSDB2) Z77140.DBRMLIB(CLMSRPT)
//* CLMSJOB: RUN PROGRAM ... PLAN(Z77140)
//*================================================================
//BIND     EXEC PGM=IKJEFT01
//STEPLIB   DD DSN=Z77140.LOAD,DISP=SHR
//          DD DSN=DSND10.SDSNLOAD,DISP=SHR
//          DD DSN=DSND10.DBDG.SDSNEXIT,DISP=SHR
//SYSTSPRT  DD SYSOUT=*
//SYSPRINT  DD SYSOUT=*
//SYSUDUMP  DD SYSOUT=*
//SYSTSIN   DD *
  DSN SYSTEM(DBDG)
  BIND PLAN(Z77140) -
       MEMBER(CLMSDB2) -
       LIBRARY('Z77140.DBRMLIB') -
       ACTION(REPLACE) -
       ISOLATION(CS)
  BIND PLAN(Z77140) -
       MEMBER(CLMSRPT) -
       LIBRARY('Z77140.DBRMLIB') -
       ACTION(REPLACE) -
       ISOLATION(CS)
  END
/*
