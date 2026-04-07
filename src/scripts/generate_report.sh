#!/bin/bash
# ==============================================================
# generate_report.sh - Generate Claims Summary Report via USS DB2
# Queries CLAIMS_MASTER, groups by claim type, produces report
# For Z Xplore DB2 CLP
# Usage: ./generate_report.sh <output_report_file>
# ==============================================================

OUTPUT_FILE="${1:-claims_report.txt}"
SQL_FILE="report_query.sql"
RAW_OUTPUT="db2_raw_output.txt"

echo "Generating Claims Summary Report..."
echo "Output file: $OUTPUT_FILE"

# Create SQL query file (Z Xplore CLP format - no semicolons)
cat > "$SQL_FILE" << 'EOF'
connect to 204.90.115.200:5040/ZXPDB2 user z77140 using PIK13IHC
SET CURRENT SCHEMA = 'Z77140'
SELECT CLAIM_TYPE, COUNT(*) AS CNT, SUM(CLAIM_AMOUNT) AS TOTAL_AMT, AVG(CLAIM_AMOUNT) AS AVG_AMT, MAX(CLAIM_AMOUNT) AS MAX_AMT FROM CLAIMS_MASTER GROUP BY CLAIM_TYPE ORDER BY CLAIM_TYPE
SELECT COUNT(*) AS TOTAL_CNT, SUM(CLAIM_AMOUNT) AS GRAND_TOTAL FROM CLAIMS_MASTER
DISCONNECT
EOF

# Execute query and capture output
db2 -f "$SQL_FILE" > "$RAW_OUTPUT" 2>&1 || true

# Debug: show raw output
echo "=== RAW DB2 OUTPUT ==="
cat "$RAW_OUTPUT"
echo "=== END RAW OUTPUT ==="

# Get current date/time
REPORT_DATE=$(date '+%Y-%m-%d')
REPORT_TIME=$(date '+%H:%M:%S')

# Initialize report file
cat > "$OUTPUT_FILE" << EOF
================================================================================
                    INSURANCE CLAIMS SUMMARY REPORT
================================================================================
RUN DATE: $REPORT_DATE          RUN TIME: $REPORT_TIME
--------------------------------------------------------------------------------

CLAIM TYPE   DESCRIPTION     COUNT        TOTAL AMOUNT       AVG AMOUNT       MAX AMOUNT
------------------------------------------------------------------------------------------
EOF

# Parse DB2 output - look for lines with claim type data
# Z Xplore DB2 CLP returns data in tabular format after column headers
# We need to find lines that have: TYPE COUNT TOTAL AVG MAX pattern

# Extract claim type summary lines (2 letter code followed by numbers)
grep -E '^[A-Z]{2}[[:space:]]+[0-9]' "$RAW_OUTPUT" | while read -r line; do
    TYPE=$(echo "$line" | awk '{print $1}')
    COUNT=$(echo "$line" | awk '{print $2}')
    TOTAL=$(echo "$line" | awk '{print $3}')
    AVG=$(echo "$line" | awk '{print $4}')
    MAX=$(echo "$line" | awk '{print $5}')
    
    # Resolve description
    case "$TYPE" in
        MD) DESC="MEDICAL" ;;
        DN) DESC="DENTAL" ;;
        DS) DESC="DISABILITY" ;;
        LF) DESC="LIFE" ;;
        *)  DESC="OTHER" ;;
    esac
    
    # Format and append to report
    printf "%-12s %-15s %6s    %15s    %15s    %15s\n" \
        "$TYPE" "$DESC" "$COUNT" "$TOTAL" "$AVG" "$MAX" >> "$OUTPUT_FILE"
done

# Extract grand totals - look for a line with just two numbers (count and sum)
# This will be from the second SELECT
GRAND_LINE=$(grep -E '^[[:space:]]*[0-9]+[[:space:]]+[0-9]' "$RAW_OUTPUT" | tail -1)
GRAND_COUNT=$(echo "$GRAND_LINE" | awk '{print $1}')
GRAND_TOTAL=$(echo "$GRAND_LINE" | awk '{print $2}')

# Append grand total to report
cat >> "$OUTPUT_FILE" << EOF
------------------------------------------------------------------------------------------
GRAND TOTAL:                  ${GRAND_COUNT:-0}              \$${GRAND_TOTAL:-0.00}
================================================================================

REPORT GENERATED SUCCESSFULLY
EOF

# Cleanup
rm -f "$SQL_FILE" "$RAW_OUTPUT"

echo "================================================"
echo "Report Generation Complete"
echo "  Output file: $OUTPUT_FILE"
echo "================================================"

# Display the report
cat "$OUTPUT_FILE"
