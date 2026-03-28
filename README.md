# Insurance Claims Batch System

**Repository:** `zowe-cobol-insurance-claims-cicd`  
**Production-grade insurance claims processing on IBM z/OS** (Zowe + COBOL + DB2 + CI/CD)

- **Developer:** Prasanna Kumar Madala  
- **Platform:** IBM Z Xplore (IBM official learning environment)  
- **Domain:** Insurance claims 

## Overview

Batch system that validates insurance claims from VSAM, loads to DB2, generates reports, and alerts on high-value claims. CI/CD powered by Jenkins + Zowe CLI.

## Pipeline

```
Z77140.VSAMDS (VSAM KSDS, 100-byte records)
       ↓
[STEP010] CLMSVALD — validates, routes valid/reject
       ↓
[STEP020] CLMSDB2  — INSERT into DB2 CLAIMS_MASTER
       ↓
[STEP030] CLMSRPT  — DB2 cursor report by claim type
       ↓
[STEP040] CLMSALRT — REXX alert for claims > $50K
```

## Programs

| Program    | Language | Description                                     |
|------------|----------|-------------------------------------------------|
| CLMSVALD   | COBOL    | Validates VSAM input, routes valid/reject        |
| CLMSDB2    | COBOL    | Loads valid claims into DB2 CLAIMS_MASTER        |
| CLMSRPT    | COBOL    | DB2 cursor report grouped by claim type          |
| CLMSALRT   | REXX     | Queries DB2 via DSNREXX, alerts on claims >$50K  |

## Datasets (Z77140 HLQ)

| Dataset                  | Type       | Purpose                    |
|--------------------------|------------|----------------------------|
| Z77140.CBL               | PDS        | COBOL source               |
| Z77140.COPYBOOK          | PDS        | COBOL copybooks (shared)   |
| Z77140.JCL               | PDS        | JCL members                |
| Z77140.LOAD              | PDS        | Load modules               |
| Z77140.DBRM              | PDS        | DB2 DBRMs                  |
| Z77140.REXX              | PDS        | REXX execs                 |
| Z77140.VSAMDS            | VSAM KSDS  | Claims input (100-byte)    |
| Z77140.CLAIMS.VALID      | Sequential | Valid claims output        |
| Z77140.CLAIMS.REJECT     | Sequential | Rejected claims output     |
| Z77140.CLAIMS.REPORT     | Sequential | Report output (FBA 133)    |

## Technology Stack

- **COBOL** — Enterprise COBOL for z/OS (validation, DB2 programs)
- **DB2** — CLAIMS_MASTER table with precompile/bind
- **REXX** — DSNREXX for DB2 queries in alert step
- **JCL** — Master job (CLMSJOB), compile job (CLMSCMP), DB2 compile PROC
- **VSAM** — KSDS input with 100-byte records
- **Zowe CLI** — Mainframe integration for CI/CD
- **Jenkins** — CI/CD pipeline (Jenkinsfile + Zowe CLI)

## CI/CD

- **Jenkins** — Zowe CLI pipeline at `http://localhost:8080`
  - One run: Checkout → Upload (COBOL, Copybooks, JCL, REXX, DB2) → **Compile** (`CLMSCMP`) → **Bind** (`CLMSBIND`, collection **Z77140**) → verify both RC 0000/0004
- z/OS credentials stored in Jenkins credentials store

## Quick Start

```bash
# Clone
git clone https://github.com/prasanna44182/zowe-cobol-insurance-claims-cicd.git
cd zowe-cobol-insurance-claims-cicd

# Deploy via Jenkins (primary) — trigger build at localhost:8080
# Or deploy manually via Zowe CLI
zowe zos-files upload dir-to-pds src/cobol Z77140.CBL
zowe zos-files upload dir-to-pds src/jcl Z77140.JCL
zowe zos-files upload dir-to-pds src/rexx Z77140.REXX
zowe jobs submit data-set "Z77140.JCL(CLMSCMP)" --wait-for-output
zowe jobs submit data-set "Z77140.JCL(CLMSBIND)" --wait-for-output
```

## Project Structure

```
├── src/
│   ├── cobol/          CLMSVALD.cbl, CLMSDB2.cbl, CLMSRPT.cbl
│   ├── copybook/       CLAIMREC.cpy (shared record layout), DCLCLMS.cpy (DCLGEN)
│   ├── jcl/            CLMSJOB.jcl, CLMSCMP.jcl, CLMSBIND.jcl, CLMSPROC.jcl
│   ├── rexx/           CLMSALRT.rexx
│   ├── db2/            CLMSDDL.sql (schema + tablespace + GRANTs)
│   └── data/           Sample 100-record claims data + VSAM setup JCL
├── application-conf/   IBM DBB zAppBuild configuration
├── docs/               Architecture documentation
├── Jenkinsfile         Jenkins CI/CD pipeline (Zowe CLI)
└── README.md
```

## License

MIT
