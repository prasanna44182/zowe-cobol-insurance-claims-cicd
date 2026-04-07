#!/bin/bash
# ==============================================================
# load_claims.sh - Generate SQL INSERT statements from CLAIMS.VALID
# Reads fixed-length records (LRECL=100) and outputs INSERT SQL
# For Z Xplore DB2 CLP (no semicolons, one statement per line)
# Usage: ./load_claims.sh <input_file> <output_sql_file>
# ==============================================================

set -e

INPUT_FILE="${1:-claims_valid.txt}"
OUTPUT_FILE="${2:-insert_claims.sql}"

if [ ! -f "$INPUT_FILE" ]; then
    echo "ERROR: Input file not found: $INPUT_FILE"
    exit 1
fi

echo "Generating SQL from: $INPUT_FILE"
echo "Output SQL file: $OUTPUT_FILE"

# Record layout (100 bytes total):
# 1-10   POLICY_NO      X(10)
# 11-18  CLAIM_ID       X(08)
# 19-48  CLAIMANT_NAME  X(30)
# 49-56  CLAIM_DATE     9(08)  YYYYMMDD
# 57-58  CLAIM_TYPE     X(02)
# 59-67  CLAIM_AMOUNT   9(07)V99  (implied decimal, 9 chars total)
# 68-70  COVERAGE_CODE  X(03)
# 71     STATUS         X(01)
# 72-100 FILLER         X(29)

# Start SQL file with connection (Z Xplore CLP format - no semicolons)
cat > "$OUTPUT_FILE" << 'EOF'
connect to 204.90.115.200:5040/ZXPDB2 user z77140 using PIK13IHC
SET CURRENT SCHEMA = 'Z77140'
EOF

COUNT=0
GENERATED=0

while IFS= read -r line || [ -n "$line" ]; do
    COUNT=$((COUNT + 1))
    
    # Skip empty lines
    if [ -z "$line" ]; then
        continue
    fi
    
    # Pad line to 100 chars if needed (in case of trailing space trimming)
    line=$(printf "%-100s" "$line")
    
    # Extract fields using substring (bash uses 0-based indexing)
    POLICY_NO="${line:0:10}"
    CLAIM_ID="${line:10:8}"
    CLAIMANT_NAME="${line:18:30}"
    CLAIM_DATE="${line:48:8}"
    CLAIM_TYPE="${line:56:2}"
    CLAIM_AMT_RAW="${line:58:9}"
    COVERAGE_CODE="${line:67:3}"
    STATUS="${line:70:1}"
    
    # Trim whitespace
    POLICY_NO=$(echo "$POLICY_NO" | xargs)
    CLAIM_ID=$(echo "$CLAIM_ID" | xargs)
    CLAIMANT_NAME=$(echo "$CLAIMANT_NAME" | xargs)
    CLAIM_DATE=$(echo "$CLAIM_DATE" | xargs)
    CLAIM_TYPE=$(echo "$CLAIM_TYPE" | xargs)
    COVERAGE_CODE=$(echo "$COVERAGE_CODE" | xargs)
    STATUS=$(echo "$STATUS" | xargs)
    
    # Convert amount: 9(07)V99 means 7 digits + 2 implied decimals
    # e.g., "001234567" = 12345.67
    CLAIM_AMT_RAW=$(echo "$CLAIM_AMT_RAW" | xargs)
    if [ -n "$CLAIM_AMT_RAW" ] && [ "$CLAIM_AMT_RAW" != "000000000" ]; then
        # Remove leading zeros and insert decimal point
        AMT_INT=${CLAIM_AMT_RAW:0:7}
        AMT_DEC=${CLAIM_AMT_RAW:7:2}
        # Remove leading zeros from integer part
        AMT_INT=$(echo "$AMT_INT" | sed 's/^0*//')
        [ -z "$AMT_INT" ] && AMT_INT="0"
        CLAIM_AMOUNT="${AMT_INT}.${AMT_DEC}"
    else
        CLAIM_AMOUNT="0.00"
    fi
    
    # Escape single quotes in claimant name
    CLAIMANT_NAME_ESC=$(echo "$CLAIMANT_NAME" | sed "s/'/''/g")
    
    # Skip if essential fields are empty
    if [ -z "$POLICY_NO" ] || [ -z "$CLAIM_ID" ]; then
        echo "WARNING: Skipping record $COUNT - missing key fields"
        continue
    fi
    
    # Generate INSERT statement (no semicolon for Z Xplore CLP)
    cat >> "$OUTPUT_FILE" << EOF
INSERT INTO CLAIMS_MASTER (POLICY_NO, CLAIM_ID, CLAIMANT_NAME, CLAIM_DATE, CLAIM_TYPE, CLAIM_AMOUNT, COVERAGE_CODE, STATUS, INSERT_TS) VALUES ('${POLICY_NO}', '${CLAIM_ID}', '${CLAIMANT_NAME_ESC}', ${CLAIM_DATE}, '${CLAIM_TYPE}', ${CLAIM_AMOUNT}, '${COVERAGE_CODE}', '${STATUS}', CURRENT TIMESTAMP)
EOF
    
    GENERATED=$((GENERATED + 1))

done < "$INPUT_FILE"

# Add COMMIT and DISCONNECT at the end (no semicolons for Z Xplore CLP)
echo "COMMIT" >> "$OUTPUT_FILE"
echo "DISCONNECT" >> "$OUTPUT_FILE"

echo "================================================"
echo "SQL Generation Complete"
echo "  Records read: $COUNT"
echo "  INSERTs generated: $GENERATED"
echo "  Output file: $OUTPUT_FILE"
echo "================================================"
