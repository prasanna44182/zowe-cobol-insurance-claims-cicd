#!/bin/bash
# ==============================================================
# generate_report.sh - Generate Claims Summary Report via USS DB2
# Queries CLAIMS_MASTER, groups by claim type, produces report
# For Z Xplore DB2 CLP
# Usage: ./generate_report.sh <output_report_file>
# ==============================================================

set -e

OUTPUT_FILE="${1:-claims_report.txt}"
SQL_FILE="report_query.sql"

echo "Generating Claims Summary Report..."
echo "Output file: $OUTPUT_FILE"

# Create SQL query file (Z Xplore CLP format - no semicolons)
cat > "$SQL_FILE" << 'EOF'
connect to 204.90.115.200:5040/ZXPDB2 user z77140 using PIK13IHC
SET CURRENT SCHEMA = 'Z77140'
SELECT CLAIM_TYPE, COUNT(*) AS CNT, SUM(CLAIM_AMOUNT) AS TOTAL_AMT, AVG(CLAIM_AMOUNT) AS AVG_AMT, MAX(CLAIM_AMOUNT) AS MAX_AMT FROM CLAIMS_MASTER GROUP BY CLAIM_TYPE ORDER BY CLAIM_TYPE
DISCONNECT
EOF

# Execute query and capture output
DB2_OUTPUT=$(db2 -f "$SQL_FILE" 2>&1) || true

# Get current date/time
REPORT_DATE=$(date '+%Y-%m-%d')
REPORT_TIME=$(date '+%H:%M:%S')

# Parse the DB2 output and generate formatted report
cat > "$OUTPUT_FILE" << EOF
================================================================================
                    INSURANCE CLAIMS SUMMARY REPORT
================================================================================
RUN DATE: $REPORT_DATE          RUN TIME: $REPORT_TIME
--------------------------------------------------------------------------------

CLAIM TYPE   DESCRIPTION     COUNT        TOTAL AMOUNT       AVG AMOUNT       MAX AMOUNT
------------------------------------------------------------------------------------------
EOF

# Parse DB2 output - extract data rows
# DB2 CLP output format varies, so we look for the data lines
echo "$DB2_OUTPUT" | while IFS= read -r line; do
    # Skip header lines, connection messages, etc.
    # Look for lines that start with claim type codes (MD, DN, DS, LF)
    if echo "$line" | grep -qE '^[[:space:]]*(MD|DN|DS|LF)[[:space:]]'; then
        # Extract fields - DB2 output is space-separated
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
            *)  DESC="UNKNOWN" ;;
        esac
        
        # Format and append to report
        printf "%-12s %-15s %6s %18.2f %16.2f %16.2f\n" \
            "$TYPE" "$DESC" "$COUNT" "$TOTAL" "$AVG" "$MAX" >> "$OUTPUT_FILE"
    fi
done

# Add grand totals by running a separate query
cat > "$SQL_FILE" << 'EOF'
connect to 204.90.115.200:5040/ZXPDB2 user z77140 using PIK13IHC
SET CURRENT SCHEMA = 'Z77140'
SELECT COUNT(*) AS TOTAL_CNT, SUM(CLAIM_AMOUNT) AS GRAND_TOTAL FROM CLAIMS_MASTER
DISCONNECT
EOF

TOTALS_OUTPUT=$(db2 -f "$SQL_FILE" 2>&1) || true

# Extract grand totals
GRAND_COUNT=$(echo "$TOTALS_OUTPUT" | grep -E '^[[:space:]]*[0-9]+' | head -1 | awk '{print $1}')
GRAND_TOTAL=$(echo "$TOTALS_OUTPUT" | grep -E '^[[:space:]]*[0-9]+' | head -1 | awk '{print $2}')

# Append grand total to report
cat >> "$OUTPUT_FILE" << EOF
------------------------------------------------------------------------------------------
GRAND TOTAL:             $GRAND_COUNT              \$$GRAND_TOTAL
================================================================================

REPORT GENERATED SUCCESSFULLY
EOF

# Cleanup
rm -f "$SQL_FILE"

echo "================================================"
echo "Report Generation Complete"
echo "  Output file: $OUTPUT_FILE"
echo "================================================"

# Display the report
cat "$OUTPUT_FILE"
