#!/bin/bash
# ==============================================================
# generate_report.sh - Generate Claims Summary Report from DB2 output
# Parses raw DB2 output and formats it into a report
# For Z Xplore DB2 CLP
# Usage: ./generate_report.sh <db2_raw_output> <output_report_file>
# ==============================================================

RAW_OUTPUT="${1:-db2_report_output.txt}"
OUTPUT_FILE="${2:-claims_report.txt}"

echo "Generating Claims Summary Report..."
echo "Input (raw DB2 output): $RAW_OUTPUT"
echo "Output file: $OUTPUT_FILE"

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
grep -E '^[A-Z]{2}[[:space:]]+[0-9]' "$RAW_OUTPUT" 2>/dev/null | while read -r line; do
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
GRAND_LINE=$(grep -E '^[[:space:]]*[0-9]+[[:space:]]+[0-9]' "$RAW_OUTPUT" 2>/dev/null | tail -1)
GRAND_COUNT=$(echo "$GRAND_LINE" | awk '{print $1}')
GRAND_TOTAL=$(echo "$GRAND_LINE" | awk '{print $2}')

# Append grand total to report
cat >> "$OUTPUT_FILE" << EOF
------------------------------------------------------------------------------------------
GRAND TOTAL:                  ${GRAND_COUNT:-0}              \$${GRAND_TOTAL:-0.00}
================================================================================

REPORT GENERATED SUCCESSFULLY
EOF

echo "================================================"
echo "Report Generation Complete"
echo "  Output file: $OUTPUT_FILE"
echo "================================================"

# Display the report
cat "$OUTPUT_FILE"
