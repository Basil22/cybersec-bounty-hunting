#!/bin/bash
# Anthropic Bug Bounty — Vulnerability Analyzer Run Script
# Usage: bash run-analyzer.sh [target]
# Example: bash run-analyzer.sh anthropic.com

set -e

TARGET="${1:-anthropic.com}"
DATE=$(date +%Y-%m-%d)
OUTPUT_DIR="/home/basil/bugbounty/targets/anthropic"
SCAN_DIR="$OUTPUT_DIR/scan/$DATE"
RECON_DIR="$OUTPUT_DIR/recon/$DATE"

mkdir -p "$SCAN_DIR"

echo "=== VULN ANALYZER — $TARGET ==="
echo "Date: $DATE"
echo ""

source ~/bugbounty/tools/path.sh

# Check if recon data exists
if [ ! -f "$RECON_DIR/live_hosts.txt" ]; then
    echo "WARNING: No live_hosts.txt found for $DATE"
    echo "Looking for most recent recon data..."
    LATEST_RECON=$(ls -d "$OUTPUT_DIR/recon/"*/ 2>/dev/null | sort | tail -1)
    if [ -n "$LATEST_RECON" ]; then
        RECON_DIR="$LATEST_RECON"
        echo "Using: $RECON_DIR"
    else
        echo "ERROR: No recon data found. Run recon first."
        exit 1
    fi
fi

HOSTS_FILE="$RECON_DIR/live_hosts.txt"
TECH_FILE="$RECON_DIR/tech_stack.txt"

# Step 1: Nuclei CVE scanning
echo "[1/5] Running nuclei CVE scans..."
nuclei -l "$HOSTS_FILE" -t cves/ -severity critical,high,medium \
  -silent -o "$SCAN_DIR/nuclei_cves.txt" 2>/dev/null || true
CVE_COUNT=$(wc -l < "$SCAN_DIR/nuclei_cves.txt" 2>/dev/null || echo 0)
echo "  CVE findings: $CVE_COUNT"

# Step 2: Exposures scanning
echo "[2/5] Running nuclei exposure scans..."
nuclei -l "$HOSTS_FILE" -t exposures/ -silent \
  -o "$SCAN_DIR/nuclei_exposures.txt" 2>/dev/null || true
EXP_COUNT=$(wc -l < "$SCAN_DIR/nuclei_exposures.txt" 2>/dev/null || echo 0)
echo "  Exposure findings: $EXP_COUNT"

# Step 3: Misconfiguration scanning
echo "[3/5] Running nuclei misconfiguration scans..."
nuclei -l "$HOSTS_FILE" -t misconfiguration/ -silent \
  -o "$SCAN_DIR/nuclei_misconfig.txt" 2>/dev/null || true
MIS_COUNT=$(wc -l < "$SCAN_DIR/nuclei_misconfig.txt" 2>/dev/null || echo 0)
echo "  Misconfiguration findings: $MIS_COUNT"

# Step 4: Subdomain takeover check
echo "[4/5] Running subdomain takeover checks..."
nuclei -l "$RECON_DIR/all_subdomains.txt" -t takeovers/ -silent \
  -o "$SCAN_DIR/nuclei_takeovers.txt" 2>/dev/null || true
TO_COUNT=$(wc -l < "$SCAN_DIR/nuclei_takeovers.txt" 2>/dev/null || echo 0)
echo "  Takeover findings: $TO_COUNT"

# Step 5: Manual checks with curl
echo "[5/5] Running manual checks..."
> "$SCAN_DIR/manual_checks.txt"

# Check common endpoints on live hosts
COMMON_PATHS="/.env /.git/ /.svn/ /.DS_Store /.htaccess /.htpasswd /wp-config.php.bak /config.xml /debug /phpinfo.php /server-status /server-info /actuator /actuator/env /api/swagger /api/docs /graphql /console /admin /administrator"

while IFS= read -r host; do
    [ -z "$host" ] && continue
    for path in $COMMON_PATHS; do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${host}${path}" 2>/dev/null || echo "000")
        if [ "$STATUS" != "404" ] && [ "$STATUS" != "000" ] && [ "$STATUS" != "403" ]; then
            echo "$host$path -> HTTP $STATUS" >> "$SCAN_DIR/manual_checks.txt"
        fi
    done
done < "$HOSTS_FILE"

MANUAL_COUNT=$(wc -l < "$SCAN_DIR/manual_checks.txt" 2>/dev/null || echo 0)
echo "  Manual check hits: $MANUAL_COUNT"

# Check security headers
echo ""
echo "=== Security Header Check ==="
> "$SCAN_DIR/missing_headers.txt"
while IFS= read -r host; do
    [ -z "$host" ] && continue
    HEADERS=$(curl -sI --max-time 5 "$host" 2>/dev/null || true)
    ISSUES=""
    echo "$HEADERS" | grep -qi "strict-transport-security" || ISSUES="$ISSUES HSTS"
    echo "$HEADERS" | grep -qi "x-frame-options" || ISSUES="$ISSUES X-Frame-Options"
    echo "$HEADERS" | grep -qi "x-content-type-options" || ISSUES="$ISSUES X-Content-Type-Options"
    echo "$HEADERS" | grep -qi "content-security-policy" || ISSUES="$ISSUES CSP"
    if [ -n "$ISSUES" ]; then
        echo "$host missing:$ISSUES" >> "$SCAN_DIR/missing_headers.txt"
    fi
done < "$HOSTS_FILE"
HEADER_ISSUES=$(wc -l < "$SCAN_DIR/missing_headers.txt" 2>/dev/null || echo 0)
echo "  Missing security headers: $HEADER_ISSUES hosts affected"

# Write summary
TOTAL=$((CVE_COUNT + EXP_COUNT + MIS_COUNT + TO_COUNT + MANUAL_COUNT))
cat > "$SCAN_DIR/summary.md" << EOF
# Vuln Scan Summary — $TARGET
Date: $DATE

## Stats
- CVE findings: $CVE_COUNT
- Exposure findings: $EXP_COUNT
- Misconfiguration findings: $MIS_COUNT
- Takeover findings: $TO_COUNT
- Manual check hits: $MANUAL_COUNT
- Missing security headers: $HEADER_ISSUES hosts
- **Total findings: $TOTAL**

## Critical/High Findings
$(grep -i "critical\|high" "$SCAN_DIR/nuclei_cves.txt" "$SCAN_DIR/nuclei_exposures.txt" "$SCAN_DIR/nuclei_misconfig.txt" 2>/dev/null | head -20)

## Manual Check Hits
$(cat "$SCAN_DIR/manual_checks.txt" 2>/dev/null | head -20)

## Missing Security Headers
$(cat "$SCAN_DIR/missing_headers.txt" 2>/dev/null | head -10)
EOF

echo ""
echo "=== SCAN COMPLETE ==="
echo "Total findings: $TOTAL"
echo "Summary: $SCAN_DIR/summary.md"
echo "All files in: $SCAN_DIR"

# Alert if critical/high findings exist
if [ "$TOTAL" -gt 0 ]; then
    echo ""
    echo "⚠️  $TOTAL FINDINGS DETECTED — Review $SCAN_DIR/summary.md"
fi
