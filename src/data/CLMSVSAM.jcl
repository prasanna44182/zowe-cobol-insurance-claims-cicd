//CLMSVSAM JOB (Z77140,CLMS),'VSAM SETUP',CLASS=A,
//             MSGCLASS=H,MSGLEVEL=(1,1),
//             NOTIFY=&SYSUID,REGION=0M,
//             TIME=1440
//*================================================================
//* VSAM & DATASET SETUP - INSURANCE CLAIMS BATCH
//* Defines VSAM KSDS cluster, allocates sequential datasets,
//* allocates PDS libraries, and loads sample claims data
//*================================================================
//*
//*--- Step 1: Delete existing datasets (ignore if not found) ---
//*
//STEP1    EXEC PGM=IDCAMS
//SYSPRINT  DD SYSOUT=*
//SYSIN     DD *
  DELETE Z77140.VSAMDS CLUSTER PURGE
  SET MAXCC = 0
  DELETE Z77140.CLAIMS.VALID
  SET MAXCC = 0
  DELETE Z77140.CLAIMS.REJECT
  SET MAXCC = 0
  DELETE Z77140.CLAIMS.REPORT
  SET MAXCC = 0
  DELETE Z77140.CLAIMS.DATA
  SET MAXCC = 0
/*
//*
//*--- Step 2: Define VSAM KSDS cluster ---
//*
//STEP2    EXEC PGM=IDCAMS
//SYSPRINT  DD SYSOUT=*
//SYSIN     DD *
  DEFINE CLUSTER                          -
    (NAME(Z77140.VSAMDS)                  -
     INDEXED                              -
     KEYS(10 0)                           -
     RECORDSIZE(100 100)                  -
     CYLINDERS(1 1)                       -
     FREESPACE(10 10)                     -
     SHAREOPTIONS(2 3))                   -
  DATA                                    -
    (NAME(Z77140.VSAMDS.DATA)             -
     CONTROLINTERVALSIZE(4096))           -
  INDEX                                   -
    (NAME(Z77140.VSAMDS.INDEX))
/*
//*
//*--- Step 3: Allocate sequential output datasets ---
//*
//STEP3    EXEC PGM=IEFBR14
//VALID     DD DSN=Z77140.CLAIMS.VALID,DISP=(NEW,CATLG,DELETE),
//             UNIT=SYSDA,SPACE=(CYL,(1,1)),
//             DCB=(RECFM=FB,LRECL=100,BLKSIZE=27900)
//REJECT    DD DSN=Z77140.CLAIMS.REJECT,DISP=(NEW,CATLG,DELETE),
//             UNIT=SYSDA,SPACE=(CYL,(1,1)),
//             DCB=(RECFM=FB,LRECL=100,BLKSIZE=27900)
//REPORT    DD DSN=Z77140.CLAIMS.REPORT,DISP=(NEW,CATLG,DELETE),
//             UNIT=SYSDA,SPACE=(CYL,(1,1)),
//             DCB=(RECFM=FBA,LRECL=133,BLKSIZE=27930)
//*
//*--- Step 4: Allocate flat file for sample data upload ---
//*
//STEP4    EXEC PGM=IEFBR14
//DATA      DD DSN=Z77140.CLAIMS.DATA,DISP=(NEW,CATLG,DELETE),
//             UNIT=SYSDA,SPACE=(CYL,(1,1)),
//             DCB=(RECFM=FB,LRECL=100,BLKSIZE=27900)
//*
//*--- Step 5: Allocate COPYBOOK PDS ---
//*
//STEP5    EXEC PGM=IEFBR14
//COPYBOOK  DD DSN=Z77140.COPYBOOK,DISP=(NEW,CATLG,DELETE),
//             UNIT=SYSDA,SPACE=(TRK,(15,15,10)),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=27920,DSORG=PO)
//*
//*--- Step 6: Allocate DBRM PDS ---
//*
//STEP6    EXEC PGM=IEFBR14
//DBRM      DD DSN=Z77140.DBRM,DISP=(NEW,CATLG,DELETE),
//             UNIT=SYSDA,SPACE=(TRK,(15,15,10)),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=27920,DSORG=PO)
//*
//*--- Step 7: Allocate REXX PDS ---
//*
//STEP7    EXEC PGM=IEFBR14
//REXX      DD DSN=Z77140.REXX,DISP=(NEW,CATLG,DELETE),
//             UNIT=SYSDA,SPACE=(TRK,(15,15,10)),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=27920,DSORG=PO)
//*
//*--- Step 8: Load flat file into VSAM KSDS via REPRO ---
//* (Run after uploading CLMSDATA.txt to Z77140.CLAIMS.DATA
//*  using: zowe zos-files upload ftds src/data/CLMSDATA.txt
//*         "Z77140.CLAIMS.DATA")
//*
//STEP8    EXEC PGM=IDCAMS
//SYSPRINT  DD SYSOUT=*
//INPUT     DD DSN=Z77140.CLAIMS.DATA,DISP=SHR
//SYSIN     DD *
  REPRO INFILE(INPUT)                     -
        OUTDATASET(Z77140.VSAMDS)
/*
//
