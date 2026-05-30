#!/bin/bash
# Anthropic Bug Bounty — Report Writer Run Script
# Usage: bash run-reporter.sh [target]
# Example: bash run-reporter.sh anthropic.com

set -e

TARGET="${1:-anthropic.com}"
DATE=$(date +%Y-%m-%d)
OUTPUT_DIR="/home/basil/bugbounty/targets/anthropic"
REPORT_DIR="$OUTPUT_DIR/reports"
SCAN_DIR="$OUTPUT_DIR/scan/$DATE"

mkdir -p "$REPORT_DIR"

echo "=== REPORT WRITER — $TARGET ==="
echo "Date: $DATE"
echo ""

source ~/bugbounty/tools/path.sh

# Find latest scan data
if [ ! -d "$SCAN_DIR" ]; then
    LATEST_SCAN=$(ls -d "$OUTPUT_DIR/scan/"*/ 2>/dev/null | sort | tail -1)
    if [ -n "$LATEST_SCAN" ]; then
        SCAN_DIR="$LATEST_SCAN"
        echo "Using latest scan: $SCAN_DIR"
    else
        echo "ERROR: No scan data found. Run analyzer first."
        exit 1
    fi
fi

VULNS_FILE="$SCAN_DIR/vulns.json"
if [ ! -f "$VULNS_FILE" ]; then
    echo "No vulns.json found. Creating from scan results..."
    
    # Aggregate all nuclei findings into a structured report
    > "$REPORT_DIR/findings-$DATE.txt"
    
    for f in "$SCAN_DIR"/nuclei_*.txt; do
        [ -f "$f" ] || continue
        TYPE=$(basename "$f" .txt | sed 's/nuclei_//')
        COUNT=$(wc -l < "$f")
        echo "=== $TYPE ($COUNT findings) ===" >> "$REPORT_DIR/findings-$DATE.txt"
        cat "$f" >> "$REPORT_DIR/findings-$DATE.txt"
        echo "" >> "$REPORT_DIR/findings-$DATE.txt"
    done
    
    # Add manual checks
    if [ -f "$SCAN_DIR/manual_checks.txt" ] && [ -s "$SCAN_DIR/manual_checks.txt" ]; then
        echo "=== Manual Checks ===" >> "$REPORT_DIR/findings-$DATE.txt"
        cat "$SCAN_DIR/manual_checks.txt" >> "$REPORT_DIR/findings-$DATE.txt"
    fi
    
    # Add missing headers
    if [ -f "$SCAN_DIR/missing_headers.txt" ] && [ -s "$SCAN_DIR/missing_headers.txt" ]; then
        echo "=== Missing Security Headers ===" >> "$REPORT_DIR/findings-$DATE.txt"
        cat "$SCAN_DIR/missing_headers.txt" >> "$REPORT_DIR/findings-$DATE.txt"
    fi
    
    echo "Findings aggregated: $REPORT_DIR/findings-$DATE.txt"
fi

# Generate human-readable report
echo "Generating report..."

REPORT_FILE="$REPORT_DIR/bug-bounty-report-$DATE.md"

cat > "$REPORT_FILE" << 'HEADER'
# Bug Bounty Report — Anthropic

**Target:** anthropic.com (and subdomains)
**Platform:** HackerOne
**Date:** DATE_PLACEHOLDER
**Reporter:** Basil (Basil22)

---

## Table of Contents
HEADER

# Add findings sections
echo "" >> "$REPORT_FILE"
echo "## Summary" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

TOTAL_FINDINGS=0
for f in "$SCAN_DIR"/nuclei_*.txt; do
    [ -f "$f" ] || continue
    COUNT=$(wc -l < "$f")
    TOTAL_FINDINGS=$((TOTAL_FINDINGS + COUNT))
done
MANUAL=$(wc -l < "$SCAN_DIR/manual_checks.txt" 2>/dev/null || echo 0)
HEADER_ISSUES=$(wc -l < "$SCAN_DIR/missing_headers.txt" 2>/dev/null || echo 0)

cat >> "$REPORT_FILE" << EOF
- **Total Findings:** $TOTAL_FINDINGS
- **Nuclei Findings:** $TOTAL_FINDINGS
- **Manual Check Hits:** $MANUAL
- **Missing Security Headers:** $HEADER_ISSUES hosts
- **Scan Date:** $(basename "$SCAN_DIR")

---

EOF

# Function to generate a report section for a finding
generate_finding() {
    local severity="$1"
    local title="$2"
    local url="$3"
    local description="$4"
    local evidence="$5"
    local recommendation="$6"
    local finding_num="$7"
    
    cat >> "$REPORT_FILE" << FINDING

## Finding $finding_num: $title

**Severity:** $severity
**URL:** $url

### Description
$description

### Evidence
\`\`\`
$evidence
\`\`\`

### Recommendation
$recommendation

---
FINDING
}

# Process nuclei findings into report sections
FINDING_NUM=1

for f in "$SCAN_DIR"/nuclei_cves.txt "$SCAN_DIR"/nuclei_exposures.txt "$SCAN_DIR"/nuclei_misconfig.txt; do
    [ -f "$f" ] || continue
    [ -s "$f" ] || continue
    
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        
        # Parse nuclei output: [template-id] [severity] url
        SEVERITY=$(echo "$line" | grep -oP '\[\K[^]]+(?=\])' | head -1 || echo "Medium")
        URL=$(echo "$line" | grep -oP 'https?://[^\s]+' | head -1 || echo "N/A")
        TEMPLATE=$(echo "$line" | grep -oP '\[.*?\]' | head -1 || echo "unknown")
        
        generate_finding \
            "$SEVERITY" \
            "$TEMPLATE finding on $URL" \
            "$URL" \
            "Automated scan detected a potential vulnerability. Manual verification required." \
            "$line" \
            "Investigate and remediate the identified issue." \
            "$FINDING_NUM"
        
        FINDING_NUM=$((FINDING_NUM + 1))
    done < "$f"
done

# Add manual findings
if [ -f "$SCAN_DIR/manual_checks.txt" ] && [ -s "$SCAN_DIR/manual_checks.txt" ]; then
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        URL=$(echo "$line" | grep -oP 'https?://[^\s]+' | head -1 || echo "N/A")
        STATUS=$(echo "$line" | grep -oP 'HTTP \K[0-9]+' || echo "unknown")
        
        generate_finding \
            "Medium" \
            "Interesting endpoint found: $URL" \
            "$URL" \
            "Endpoint returned HTTP $STATUS — may warrant further investigation." \
            "$line" \
            "Review endpoint for sensitive data exposure or unintended access." \
            "$FINDING_NUM"
        
        FINDING_NUM=$((FINDING_NUM + 1))
    done < "$SCAN_DIR/manual_checks.txt"
fi

# Add security header findings
if [ -f "$SCAN_DIR/missing_headers.txt" ] && [ -s "$SCAN_DIR/missing_headers.txt" ]; then
    generate_finding \
        "Low" \
        "Missing Security Headers on Multiple Hosts" \
        "Multiple hosts" \
        "Several hosts are missing recommended security headers (HSTS, X-Frame-Options, CSP, X-Content-Type-Options)." \
        "$(cat "$SCAN_DIR/missing_headers.txt" | head -10)" \
        "Add recommended security headers to all production hosts." \
        "$FINDING_NUM"
    FINDING_NUM=$((FINDING_NUM + 1))
fi

# Replace date placeholder
sed -i "s/DATE_PLACEHOLDER/$DATE/" "$REPORT_FILE"

echo ""
echo "=== REPORT COMPLETE ==="
echo "Report: $REPORT_FILE"
echo "Total findings documented: $((FINDING_NUM - 1))"
echo ""
echo "Next steps:"
echo "  1. Review the report manually"
echo "  2. Verify each finding with curl/browser"
echo "  3. Write PoC for confirmed vulnerabilities"
echo "  4. Submit to HackerOne via their web form"
