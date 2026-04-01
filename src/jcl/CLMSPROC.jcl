//CLMSPROC  PROC MEMBER=,SUBSYS=DBDG,PKG=Z77140
//*================================================================
//* DB2 COMPILE PROC - INSURANCE CLAIMS BATCH
//* Precompile, compile, link-edit, and bind a DB2 COBOL program.
//* Use for DB2 programs (CLMSDB2, CLMSRPT) only.
//* Non-DB2 programs (CLMSVALD) use IGYWCL cataloged proc.
//*
//* Parameters:
//*   MEMBER - Program name (e.g. CLMSDB2, CLMSRPT)
//*   SUBSYS - DB2 subsystem name (default: DBDG)
//*   PKG    - DB2 package collection (default: Z77140)
//*            Xplore: usually same as your HLQ
//*================================================================
//*
//*--- DB2 Precompile ---
//*
//PRECOMP  EXEC PGM=DSNHPC,
//             PARM='HOST(COBOL),APOST,SOURCE',
//             COND=(4,LT)
//DBRMLIB   DD DSN=Z77140.DBRMLIB(&MEMBER),DISP=SHR
//SYSCIN    DD DSN=&&DSNHOUT,DISP=(NEW,PASS),
//             UNIT=SYSDA,SPACE=(TRK,(15,15))
//SYSIN     DD DSN=Z77140.CBL(&MEMBER),DISP=SHR
//SYSLIB    DD DSN=Z77140.COPYBOOK,DISP=SHR
//             DD DSN=Z77140.CBL,DISP=SHR
//SYSPRINT  DD SYSOUT=*
//SYSTERM   DD SYSOUT=*
//SYSUT1    DD SPACE=(TRK,(15,15)),UNIT=SYSDA
//SYSUT2    DD SPACE=(TRK,(15,15)),UNIT=SYSDA
//*
//*--- COBOL Compile + Link-Edit ---
//*
//COMPILE  EXEC IGYWCL,COND=(4,LT),
//             PARM.COBOL='LIB,CICS(NONE),SQL(NONE)'
//COBOL.SYSIN  DD DSN=&&DSNHOUT,DISP=(OLD,DELETE)
//COBOL.SYSLIB DD DSN=Z77140.COPYBOOK,DISP=SHR
//             DD DSN=CEE.SCEESAMP,DISP=SHR
//LKED.SYSLMOD DD DSN=Z77140.LOAD(&MEMBER),DISP=SHR
//LKED.SYSLIB  DD DSN=CEE.SCEELKED,DISP=SHR
//             DD DSN=DSND10.SDSNLOAD,DISP=SHR
//SYSUDUMP  DD SYSOUT=*
//*
//*--- DB2 Bind Package + Plan ---
//*
//BIND     EXEC PGM=IKJEFT01,COND=(4,LT)
//SYSTSPRT  DD SYSOUT=*
//SYSPRINT  DD SYSOUT=*
//SYSUDUMP  DD SYSOUT=*
//SYSTSIN   DD *,SYMBOLS=JCLONLY
  DSN SYSTEM(&SUBSYS)
  BIND PACKAGE(&PKG) -
       MEMBER(&MEMBER) -
       LIBRARY('Z77140.DBRMLIB') -
       ACTION(REPLACE) -
       ISOLATION(CS)
  BIND PLAN(Z77140) -
       PKLIST(&PKG.*) -
       ACTION(REPLACE)
  END
/*
//         PEND
