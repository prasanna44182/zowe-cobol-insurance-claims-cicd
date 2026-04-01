# Architecture — Insurance Claims Batch System

## Pipeline Flow

```
Z77140.VSAMDS (VSAM KSDS input, LRECL=100, KEY=1-10)
       |
  [STEP010] CLMSVALD — validates claims, routes valid/rejected
       |         Valid   → Z77140.CLAIMS.VALID  (FB LRECL=100)
       |         Reject  → Z77140.CLAIMS.REJECT (FB LRECL=100)
       |
  [STEP020] CLMSDB2  — EXEC SQL INSERT into DB2 CLAIMS_MASTER
       |                (via IKJEFT01 / DSN RUN PROGRAM)
       |                (commits every 500 rows)
       |
  [STEP030] CLMSRPT  — DB2 cursor report grouped by claim type
       |                (via IKJEFT01 / DSN RUN PROGRAM)
       |                (output to Z77140.CLAIMS.REPORT, FBA LRECL=133)
       |
  [STEP040] CLMSALRT — REXX alert for claims > $50K via DSNREXX
                        (via IKJEFT01 / TSO EXEC)
```

## VSAM Record Layout (LRECL=100)

Defined in copybook `CLAIMREC.cpy`, shared across all COBOL programs.

| Field               | PIC        | Bytes  | 88-Levels                        |
|---------------------|------------|--------|----------------------------------|
| CLM-POLICY-NUMBER   | X(10)      | 1-10   | (VSAM key)                       |
| CLM-CLAIM-ID        | X(08)      | 11-18  |                                  |
| CLM-CLAIMANT-NAME   | X(30)      | 19-48  |                                  |
| CLM-CLAIM-DATE      | 9(08)      | 49-56  | CLM-DATE-VALID (19000101-20991231) |
| CLM-CLAIM-TYPE      | X(02)      | 57-58  | CLM-TYPE-VALID (MD/DN/DS/LF)     |
| CLM-CLAIM-AMOUNT    | 9(07)V99   | 59-67  |                                  |
| CLM-COVERAGE-CODE   | X(03)      | 68-70  | HMO/PPO/EPO/POS/HDH/GRP/IND/TRM |
| CLM-STATUS          | X(01)      | 71     | N=New V=Valid R=Reject           |
| FILLER              | X(29)      | 72-100 |                                  |

## Claim Types

- **MD** — Medical
- **DN** — Dental
- **DS** — Disability
- **LF** — Life

## DB2 Configuration

- **Schema:** Z77140
- **Database:** CLMSDB
- **Tablespace:** CLMSTS (SEGSIZE 64, COMPRESS YES, LOCKSIZE ROW)
- **Subsystem:** DBDG (IBM Z Xplore; adjust if your LPAR differs)
- **Plan:** Z77140
- **Package collection:** Z77140 (IBM Z Xplore user-named collection; adjust if your HLQ differs)
- **Table:** Z77140.CLAIMS_MASTER
  - PK: `(POLICY_NO, CLAIM_ID)`
  - CHECK constraints on CLAIM_TYPE, STATUS, CLAIM_AMOUNT
  - Indexes: IDX_CLM_TYPE, IDX_CLM_DATE (DESC), IDX_CLM_AMT (DESC)

## Copybooks (Z77140.COPYBOOK)

| Member    | Purpose                                    |
|-----------|--------------------------------------------|
| CLAIMREC  | 100-byte claim record layout with 88-levels |
| DCLCLMS   | DCLGEN host variables for CLAIMS_MASTER     |

## Datasets (Z77140 HLQ)

| Dataset                  | Type       | LRECL | Purpose                    |
|--------------------------|------------|-------|----------------------------|
| Z77140.CBL               | PDS        | 80    | COBOL source               |
| Z77140.COPYBOOK          | PDS        | 80    | COBOL copybooks            |
| Z77140.JCL               | PDS        | 80    | JCL members                |
| Z77140.LOAD              | PDS        | —     | Load modules               |
| Z77140.DBRMLIB           | PDS        | 80    | DB2 DBRM library           |
| Z77140.REXX              | PDS        | 80    | REXX execs                 |
| Z77140.VSAMDS            | VSAM KSDS  | 100   | Claims input               |
| Z77140.CLAIMS.VALID      | Sequential | 100   | Valid claims output        |
| Z77140.CLAIMS.REJECT     | Sequential | 100   | Rejected claims output     |
| Z77140.CLAIMS.REPORT     | Sequential | 133   | Report output (FBA)        |
| Z77140.CLAIMS.DATA       | Sequential | 100   | Sample data for VSAM load  |

## Return Code Standards

All programs follow z/OS return code conventions:
- **RC 0** — Success, no issues
- **RC 4** — Warning (e.g. duplicate keys in CLMSDB2, alerts found in CLMSALRT)
- **RC 8** — Error (SQL failures, I/O errors)
- **RC 12** — REXX runtime errors
- **RC 16** — Severe (file open failures, cannot proceed)

## Job Dependencies

- **Master job:** `Z77140.JCL(CLMSJOB)` with JOBLIB
- **Step chaining:** `COND=(4,LT,prev-step)` — bypass if prior RC > 4
- **Compile job:** `Z77140.JCL(CLMSCMP)` — compile/link + DB2 precompile (integrated SQL path)
- **Bind job:** `Z77140.JCL(CLMSBIND)` — packages in collection **Z77140**, plan **Z77140** (submitted by CI after compile)

## CI/CD

### Jenkins (Primary)

- **Jenkinsfile** — Declarative pipeline using Zowe CLI
- **Stages:**
  1. Checkout — pulls source from GitHub
  2. Upload Source — COBOL, Copybooks, JCL, REXX, DB2 DDL to z/OS PDSes
  3. Compile — submits `Z77140.JCL(CLMSCMP)`
  4. Verify Compile — CC 0000 or CC 0004
  5. Bind DB2 — submits `Z77140.JCL(CLMSBIND)`
  6. Verify Bind — CC 0000 or CC 0004
- **Jenkins URL:** `http://localhost:8080`
- **Job:** `insurance-claims-pipeline`
- **Credentials:** z/OS username/password stored in Jenkins credential store (ID: `zos-credentials`)
