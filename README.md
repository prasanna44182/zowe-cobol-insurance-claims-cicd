# Insurance Claims Batch System - CI/CD on IBM Z

**Enterprise-grade batch processing architecture demonstrating mainframe DevOps modernization using open-source tooling.**

There's this myth floating around that you can't learn mainframe without access to expensive enterprise systems. That's not true anymore. IBM provides free z/OS access through Z Xplore, and the open-source Zowe project gives you modern CLI tools to work with it. I put this project together so fellow mainframers - whether you're just starting out or have been doing this for years - can see how COBOL, DB2, JCL, and REXX fit into a modern CI/CD workflow using tools that cost nothing.

No enterprise licenses. No expensive emulators. Just Git, Jenkins, Zowe CLI, and a free IBM Z Xplore account.

---

## Who This Is For

- **New mainframe developers** learning COBOL and JCL who want to understand the full picture
- **Experienced z/OS professionals** curious about DevOps, Git-based workflows, and Zowe

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

### Pipeline Stages (13 Total)

#### Source Upload Stages

| # | Stage | Command | Description |
|---|-------|---------|-------------|
| 1 | **Checkout** | `git checkout` | Clones the repository from GitHub. Jenkins pulls the latest code including COBOL source, JCL, REXX, copybooks, and shell scripts. |
| 2 | **Upload COBOL** | `zowe zos-files upload dir-to-pds src/cobol Z77140.CBL` | Uploads all COBOL source members (CLMSVALD, CLMSDB2, CLMSRPT) to the CBL partitioned dataset on z/OS. |
| 3 | **Upload Copybooks** | `zowe zos-files upload dir-to-pds src/copybook Z77140.COPYBOOK` | Uploads shared copybooks - CLAIMREC.cpy (record layout) and DCLCLMS.cpy (DCLGEN for DB2 table). |
| 4 | **Upload JCL** | `zowe zos-files upload dir-to-pds src/jcl Z77140.JCL` | Uploads all JCL members - compile jobs, bind jobs, execution jobs. 9 members total. |
| 5 | **Upload REXX** | `zowe zos-files upload dir-to-pds src/rexx Z77140.REXX` | Uploads CLMSALRT.rexx - the DSNREXX program for high-value claims alerting. |
| 6 | **Upload DB2 DDL** | `zowe zos-files upload dir-to-pds src/db2 Z77140.SQL` | Uploads CLMSDDL.sql containing CREATE TABLE, CREATE INDEX, and GRANT statements. |

#### Build Stages

| # | Stage | Command | Description |
|---|-------|---------|-------------|
| 7 | **Compile** | `zowe jobs submit data-set "Z77140.JCL(CLMSCMP)"` | Submits the compile JCL which runs IGYCRCTL (COBOL compiler) and DB2 precompiler for all three COBOL programs. Creates load modules in Z77140.LOAD and DBRMs in Z77140.DBRMLIB. |
| 8 | **Verify Compile** | `zowe jobs view job-status-by-jobid` | Checks the return code. CC 0000 or CC 0004 (warnings) means success. Any higher fails the pipeline. Displays spool output on failure for debugging. |
| 9 | **Bind DB2** | `zowe jobs submit data-set "Z77140.JCL(CLMSBIND)"` | Submits the bind JCL which runs IKJEFT01 with DSN command to BIND PLAN and BIND PACKAGE for the DB2 programs. Creates plan Z77140 with packages for CLMSDB2 and CLMSRPT. |
| 10 | **Verify Bind** | `zowe jobs view job-status-by-jobid` | Validates bind completed successfully. CC 0004 is normal (rebind warnings). Fails pipeline on CC 0008 or higher. |

#### Execution Stages

| # | Stage | Command | Description |
|---|-------|---------|-------------|
| 11 | **Run Validation** | `zowe jobs submit data-set "Z77140.JCL(CLMSVLD)"` | Executes CLMSVALD COBOL program. Reads 90 records from VSAM KSDS, applies business rules (policy number format, claim amount range, date validation), writes 88 valid records to CLAIMS.VALID and 2 rejected to CLAIMS.REJECT. Displays spool output showing INPUT/VALID/REJECT counts. |
| 12 | **USS DB2 Load** | Shell script + `db2 -f` | Multi-step process: (1) Downloads CLAIMS.VALID from z/OS to Jenkins workspace, (2) Runs load_claims.sh to parse fixed-width records and generate INSERT SQL, (3) Uploads SQL to USS, (4) Executes via `db2 -f` command in USS. Inserts 88 records into CLAIMS_MASTER table. |
| 13 | **USS DB2 Report** | Shell script + `db2 -f` | Multi-step process: (1) Creates SQL query file with GROUP BY CLAIM_TYPE aggregation, (2) Uploads to USS, (3) Executes via `db2 -f` and captures raw output, (4) Runs generate_report.sh locally to parse DB2 output and format the summary report showing counts and totals by claim type. |
| 14 | **Run Post-Load Jobs** | `zowe jobs submit data-set "Z77140.JCL(CLMSPOST)"` | Submits JCL with two steps: STEP010 runs CLMSRPT (COBOL report - reference implementation), STEP020 runs CLMSALRT (REXX alert program via IKJEFT01). CLMSALRT uses DSNREXX to query claims > $50K and produces the high-value claims alert report. Returns CC 0004 when alerts are found. |

#### Post-Build Actions

| Action | Description |
|--------|-------------|
| **Success** | Logs "Pipeline SUCCESS" with summary of all job IDs |
| **Failure** | Logs "Pipeline FAILED" for troubleshooting |
| **Cleanup** | Removes temporary files: claims_valid.txt, insert_claims.sql, claims_report.txt, report_query.sql, db2_report_output.txt |

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
3. Add z/OS credentials to Jenkins credential store (for Zowe CLI / z/OSMF)
4. Add a **Secret text** credential for the **DB2 CLP password** (IBM Z Xplore):
   - Jenkins → **Manage Jenkins** → **Credentials** → add **Secret text**
   - **ID** must be exactly: **`zxplore-db2-password`** (the `Jenkinsfile` looks up this ID)
   - **Secret**: your current Z Xplore DB2 password (the one used in `connect ... using ...` for JDBC-style CLP)
5. Create a Pipeline job pointing to this repo
6. Build

**Security:** Do not put the DB2 password in the repo. If you run `load_claims.sh` on your Mac, use `export DB2_PASSWORD=...` or copy `.env.example` to `.env`, fill it in, and `source .env` (keep `.env` out of Git).

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

## The Journey - Problems Solved Along the Way

Building this wasn't a straight path. Here's what I ran into and how I fixed it - might save you some time.

### Dataset Allocation Issues

**Problem:** Tried using `zowe files create` to allocate datasets from Jenkins. Kept failing with various errors.

**Solution:** Dataset allocation on z/OS needs JCL, not CLI commands. Created dedicated allocation JCL (`CLMSALOC.jcl`) to pre-allocate all required datasets with proper attributes (LRECL, RECFM, BLKSIZE, SPACE). Run it once manually, then the pipeline just uses existing datasets.

**Lesson:** Some things are better done the mainframe way. JCL for allocation, Zowe for file transfer and job submission.

---

### File Attribute Mismatch (IGZ0201W)

**Problem:** COBOL report program failed with `IGZ0201W` - file attribute mismatch. The program expected LRECL=133 but the dataset had LRECL=132.

**Solution:** Reallocated `Z77140.CLAIMS.REPORT` with correct attributes: `LRECL=133, RECFM=FBA` (fixed block with ASA carriage control). The extra byte is for the printer control character.

**Lesson:** When COBOL file I/O fails, check your DCB attributes. LRECL must match exactly what the FD clause expects.

---

### DB2 Connection String for Z Xplore

**Problem:** USS db2 CLI kept failing with `DSNC103I` and `DSNC108I` - connection errors. The standard `connect to DBDG` syntax didn't work.

**Solution:** Z Xplore requires the full JDBC-style connection string:
```
connect to 204.90.115.200:5040/ZXPDB2 user z77140 using <password>
```
Also discovered that Z Xplore's db2 CLI doesn't want semicolons at the end of SQL statements - just newlines.

**Lesson:** Every DB2 environment has its quirks. The USS db2 CLI on Z Xplore is JDBC-based, not native CAF. Read the error messages carefully.

---

### db2 Command Not Found in USS Scripts

**Problem:** Shell script uploaded to USS and executed via `zowe zos-uss issue ssh` failed with `db2: command not found`.

**Solution:** The PATH isn't set up when running scripts via SSH. Instead of running `db2` inside a shell script on USS, restructured the approach:
1. Generate SQL file locally in Jenkins
2. Upload to USS
3. Run `db2 -f filename.sql` directly via Zowe SSH command (not inside a script)
4. Capture output back to Jenkins for parsing

**Lesson:** When SSH'ing to USS, the environment is minimal. Run commands directly via Zowe rather than depending on USS shell scripts to find executables.

---

### Parsing DB2 CLI Output

**Problem:** The USS db2 CLI returns data in a tabular format, but parsing it in a shell script was tricky. First attempts produced empty reports.

**Solution:** Captured raw db2 output to a file, then used `grep` and `awk` to extract data rows. The key was understanding the output format:
- Header row with column names
- Data rows starting with the actual values
- Footer with "X record(s) selected"

Used pattern matching: `grep -E '^[A-Z]{2}[[:space:]]+[0-9]'` to find claim type rows.

**Lesson:** When parsing CLI output, always dump the raw output first to understand the exact format before writing parsers.

---

### VSAM Setup and Data Loading

**Problem:** Needed to set up VSAM KSDS with test data. Can't just upload a file - VSAM requires DEFINE CLUSTER and REPRO.

**Solution:** Created two JCL members:
- `CLMSVSAM.jcl` - IDCAMS DEFINE CLUSTER for the KSDS
- `CLMSREPRO.jcl` - IDCAMS REPRO to load data from sequential file

Generated 90 test records with realistic insurance claim data using a Python script locally, uploaded as sequential, then REPRO'd into VSAM.

**Lesson:** VSAM setup is a multi-step process. Define the cluster first, then load data. REPRO is your friend.

---

### Jenkins PATH Configuration

**Problem:** Jenkins couldn't find `zowe` command even though it was installed.

**Solution:** Added explicit PATH in Jenkinsfile environment block:
```groovy
environment {
    PATH = "/usr/local/bin:/opt/homebrew/bin:${env.PATH}"
}
```

**Lesson:** Jenkins runs with a minimal environment. Always set PATH explicitly for any CLI tools you need.

---

### COBOL Copybook Parsing in Shell

**Problem:** Needed to parse the fixed-width CLAIMS.VALID file in a shell script using the same layout as the COBOL copybook.

**Solution:** Manually translated the COBOL PIC clauses to shell `cut` commands:
```bash
POLICY_NO=$(echo "$line" | cut -c1-10)      # PIC X(10)
CLAIM_ID=$(echo "$line" | cut -c11-18)      # PIC X(8)
CLAIMANT_NAME=$(echo "$line" | cut -c19-48) # PIC X(30)
```

The tricky part was the CLAIM_AMOUNT - stored as PIC 9(7)V99 (implied decimal), so needed to insert the decimal point: `${amt:0:7}.${amt:7:2}`

**Lesson:** Keep your copybook handy when writing parsers. Every position matters in fixed-width files.

---

### JCL Step Dependencies

**Problem:** Wanted CLMSALRT (REXX alerts) to run even if CLMSRPT (COBOL report) failed. But JCL default behavior flushes subsequent steps on failure.

**Solution:** Removed the COND parameter from STEP020. Without COND, the step runs regardless of previous step return codes.

**Lesson:** JCL step conditioning is powerful but subtle. No COND = always run. COND=(4,LT,STEP010) = skip if STEP010 RC < 4.

---

### DSNREXX Setup for Dynamic SQL

**Problem:** Wanted to query DB2 from REXX without precompile/bind overhead.

**Solution:** Used DSNREXX - the REXX interface to DB2:
```rexx
ADDRESS DSNREXX
"CONNECT" SUBSYS
"EXECSQL DECLARE C1 CURSOR FOR S1"
"EXECSQL PREPARE S1 FROM :SQLSTMT"
"EXECSQL OPEN C1"
```

Key insight: DSNREXX uses dynamic SQL under the covers, so no plan authorization needed for the REXX program itself.

**Lesson:** DSNREXX is powerful for ad-hoc queries and scripts. It's dynamic SQL, so more flexible than embedded static SQL.

---

### What Actually Worked Well

1. **Zowe CLI** - Rock solid. File uploads, job submission, USS SSH, spool retrieval - it all just works.

2. **Hybrid Architecture** - COBOL for validation (complex business logic), shell scripts for ETL (data transformation), REXX for queries (flexible SQL). Use each tool where it fits.

3. **Z Xplore** - Real z/OS, real DB2, real JES2. Everything I learned applies directly to production systems.

4. **Git + Jenkins** - Standard DevOps tooling works fine with mainframe. Nothing special needed.

5. **USS as a Bridge** - Unix System Services is the glue between modern tools and traditional z/OS. SSH access, db2 CLI, shell scripts - it opens up a lot of possibilities.

---

## Contributing

If you're learning mainframe or want to improve the pipeline, contributions are welcome. Open an issue or PR.

---

## License

MIT

---

**Author:** Prasanna Kumar Madala

*Built to show that modern DevOps and mainframe development work together. No expensive tools required - just Zowe, Jenkins, and some COBOL.*
