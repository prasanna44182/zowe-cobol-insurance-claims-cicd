# Insurance Claims Batch System - CI/CD on IBM Z

**A hands-on project for mainframe developers who want to learn modern DevOps with free, open-source tools.**

There's this myth floating around that you can't learn mainframe without access to expensive enterprise systems. That's not true anymore. IBM provides free z/OS access through Z Xplore, and the open-source Zowe project gives you modern CLI tools to work with it. I put this project together so fellow mainframers - whether you're just starting out or have been doing this for years - can see how COBOL, DB2, JCL, and REXX fit into a modern CI/CD workflow using tools that cost nothing.

No enterprise licenses. No expensive emulators. Just Git, Jenkins, Zowe CLI, and a free IBM Z Xplore account.

---

## Who This Is For

- **New mainframe developers** learning COBOL and JCL who want to understand the full picture
- **Experienced z/OS professionals** curious about DevOps, Git-based workflows, and Zowe
- **Anyone who's been told** "you can't learn mainframe at home" and wants to prove that wrong

---

## What This Project Does

It's a complete insurance claims batch processing system:

1. **Validate** - Read claims from VSAM, check them, route to valid/rejected files
2. **Load to DB2** - Insert valid claims into a relational table
3. **Report** - Generate a summary grouped by claim type
4. **Alert** - Flag high-value claims (over $50K) for review

Everything runs through a Jenkins pipeline. Push to GitHub, Jenkins handles the rest - uploads source to z/OS, compiles COBOL, binds DB2 plans, executes batch jobs. Real CI/CD on real z/OS.

---

## The Stack

| Layer | Technology | Notes |
|-------|------------|-------|
| Platform | IBM Z Xplore | Free z/OS access from IBM |
| Languages | COBOL, REXX, JCL, Shell | Standard mainframe + USS |
| Database | DB2 for z/OS | Subsystem DBDG on Z Xplore |
| Data | VSAM KSDS | 100-byte keyed records |
| CLI | Zowe CLI | Open-source, npm install |
| CI/CD | Jenkins | Free, runs on your laptop |
| Source Control | Git/GitHub | Industry standard |

**Total cost: $0**

---

## How It Actually Works

Here's what happens when you trigger a Jenkins build:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           JENKINS PIPELINE                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│ Checkout → Upload → Compile → Bind → Validate → DB2 Load → Report → Alerts  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Stage by Stage

| Stage | What Runs | What It Does |
|-------|-----------|--------------|
| Upload | Zowe CLI | Push COBOL, JCL, REXX, copybooks to z/OS PDSes |
| Compile | CLMSCMP.jcl | Compile all COBOL, DB2 precompile for SQL programs |
| Bind | CLMSBIND.jcl | Bind DB2 plans and packages |
| Validate | CLMSVLD.jcl | COBOL program reads VSAM, validates, writes VALID/REJECT |
| DB2 Load | USS script | Shell script parses VALID file, INSERTs via db2 CLI |
| Report | USS script | Queries CLAIMS_MASTER, generates summary by claim type |
| Alerts | CLMSPOST.jcl | REXX program queries for claims > $50K |

### Sample Output

When the pipeline runs, you see real results:

```
CLMSVALD: INPUT=0000090 VALID=0000088 REJECT=0000002

=== CLAIMS SUMMARY REPORT ===
================================================================================
                    INSURANCE CLAIMS SUMMARY REPORT
================================================================================
RUN DATE: 2026-04-08          RUN TIME: 09:53:30

CLAIM TYPE   DESCRIPTION     COUNT        TOTAL AMOUNT
------------------------------------------------------------------------------------------
DN           DENTAL              28          963134.07
DS           DISABILITY          19          239773.98
LF           LIFE                20          210683.06
MD           MEDICAL             20          196251.08
------------------------------------------------------------------------------------------
GRAND TOTAL:                     88         $1,609,842.19
================================================================================

CLMSALRT: ================================================
CLMSALRT: HIGH-VALUE CLAIMS ALERT REPORT
CLMSALRT: THRESHOLD: $50,000.00
CLMSALRT: ================================================
CLMSALRT: ** ACTION REQUIRED ** 8 claim(s) exceed $50,000 threshold
CLMSALRT: TOTAL AMOUNT: $1,012,826.89
```

---

## Why I Chose Dynamic SQL for DB2 Operations

This is worth explaining because it's a deliberate design choice.

The project includes COBOL programs with embedded static SQL (`CLMSDB2.cbl`, `CLMSRPT.cbl`) - that's the traditional mainframe approach. Precompile, bind a plan, execute. It works great when you have full control over your DB2 environment.

But I also built the DB2 load and report using **USS shell scripts** and the **db2 command line processor**. Here's why:

1. **Flexibility** - Dynamic SQL via USS doesn't need plan authorization for each program. You write SQL, you run it. For ETL and reporting, this is often simpler.

2. **USS Integration** - The db2 CLI in Unix System Services handles connections, commits, and errors cleanly. For batch data loading, it's straightforward.

3. **Pipeline-Friendly** - Shell scripts integrate naturally with Jenkins. Capture output, parse results, make decisions - it all flows.

4. **REXX + DSNREXX** - For the alert logic, REXX with DSNREXX lets you write SQL directly in the script. Query, calculate, format output - more readable than COBOL cursor processing for this use case.

The static SQL COBOL programs are included as **reference implementations**. They show the traditional approach. The dynamic SQL scripts show an alternative that's often more practical for learning environments and CI/CD pipelines.

---

## The Programs

| Program | Language | What It Does |
|---------|----------|--------------|
| **CLMSVALD** | COBOL | Validates VSAM input, applies business rules, routes to VALID/REJECT |
| **CLMSDB2** | COBOL | Static SQL INSERT to CLAIMS_MASTER (reference implementation) |
| **CLMSRPT** | COBOL | Static SQL cursor report by claim type (reference implementation) |
| **CLMSALRT** | REXX | DSNREXX dynamic SQL - finds claims over $50K threshold |
| **load_claims.sh** | Shell | Parses VALID file, generates INSERT SQL, executes via db2 CLI |
| **generate_report.sh** | Shell | Queries DB2 via USS, formats claims summary report |

---

## Datasets on z/OS

Everything lives under the `Z77140` high-level qualifier:

| Dataset | Type | Purpose |
|---------|------|---------|
| Z77140.CBL | PDS | COBOL source |
| Z77140.COPYBOOK | PDS | Shared copybooks (CLAIMREC, DCLCLMS) |
| Z77140.JCL | PDS | JCL members |
| Z77140.LOAD | PDS | Compiled load modules |
| Z77140.DBRMLIB | PDS | DB2 DBRM objects |
| Z77140.REXX | PDS | REXX procedures |
| Z77140.SQL | PDS | DB2 DDL |
| Z77140.CLAIMS.VSAM | VSAM KSDS | Input claims (100-byte records) |
| Z77140.CLAIMS.VALID | Sequential | Validated claims |
| Z77140.CLAIMS.REJECT | Sequential | Rejected claims |
| Z77140.CLAIMS.REPORT | Sequential | Report output (FBA, LRECL=133) |

---

## Getting Started

### What You Need

1. **IBM Z Xplore account** - Free: https://ibmzxplore.influitive.com/
2. **Zowe CLI** - `npm install -g @zowe/cli`
3. **Jenkins** - Local install or server
4. **Git** - You probably already have this

### Setup

```bash
# Clone the repo
git clone https://github.com/prasanna44182/zowe-cobol-insurance-claims-cicd.git
cd zowe-cobol-insurance-claims-cicd

# Configure Zowe CLI with your Z Xplore credentials
zowe profiles create zosmf-profile zosmf --host <your-host> --port 443 --user <userid> --password <password> --reject-unauthorized false

# Test connection
zowe zosmf check status
```

### Run via Jenkins (Recommended)

1. Install Jenkins locally (`brew install jenkins-lts` on Mac)
2. Start Jenkins, configure PATH to include Zowe CLI
3. Add z/OS credentials to Jenkins credential store
4. Create a Pipeline job pointing to this repo
5. Build

### Run Manually

```bash
# Upload source
zowe zos-files upload dir-to-pds src/cobol Z77140.CBL
zowe zos-files upload dir-to-pds src/copybook Z77140.COPYBOOK
zowe zos-files upload dir-to-pds src/jcl Z77140.JCL
zowe zos-files upload dir-to-pds src/rexx Z77140.REXX

# Compile
zowe jobs submit data-set "Z77140.JCL(CLMSCMP)" --wait-for-output

# Bind DB2
zowe jobs submit data-set "Z77140.JCL(CLMSBIND)" --wait-for-output

# Run validation
zowe jobs submit data-set "Z77140.JCL(CLMSVLD)" --wait-for-output

# Run alerts
zowe jobs submit data-set "Z77140.JCL(CLMSPOST)" --wait-for-output
```

---

## Project Structure

```
├── src/
│   ├── cobol/           CLMSVALD.cbl, CLMSDB2.cbl, CLMSRPT.cbl
│   ├── copybook/        CLAIMREC.cpy, DCLCLMS.cpy
│   ├── jcl/             CLMSVLD.jcl, CLMSPOST.jcl, CLMSCMP.jcl, CLMSBIND.jcl, ...
│   ├── rexx/            CLMSALRT.rexx
│   ├── db2/             CLMSDDL.sql
│   ├── scripts/         load_claims.sh, generate_report.sh
│   └── data/            Sample claims data, VSAM setup JCL
├── docs/                Architecture notes
├── Jenkinsfile          The CI/CD pipeline
└── README.md
```

---

## What I Learned Building This

A few things that might save you time:

1. **Zowe CLI is the real deal** - File uploads, job submission, USS SSH, spool retrieval - all from the command line. It's what makes mainframe CI/CD practical.

2. **USS is your friend** - The Unix System Services layer on z/OS is powerful. The db2 CLI, shell scripts, SSH access - use them.

3. **Mix and match** - COBOL for business logic, REXX for flexible queries, shell scripts for data transformation. Use what fits.

4. **Z Xplore is perfect for learning** - It's real z/OS, real DB2, real JES2. The skills transfer directly to production systems.

5. **Dynamic SQL has its place** - DSNREXX and USS db2 CLI are great for ETL, reporting, and scripts. Don't assume everything needs static SQL and bound plans.

---

## Contributing

If you're learning mainframe or want to improve the pipeline, contributions are welcome. Open an issue or PR.

---

## License

MIT

---

**Author:** Prasanna Kumar Madala

*Built to show that modern DevOps and mainframe development work together. No expensive tools required - just Zowe, Jenkins, and some COBOL.*
