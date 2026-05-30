#!/bin/bash
# Anthropic Bug Bounty — Monitor Watcher Run Script
# Usage: bash run-monitor.sh [target]
# Example: bash run-monitor.sh anthropic.com

set -e

TARGET="${1:-anthropic.com}"
DATE=$(date +%Y-%m-%d-%H%M)
OUTPUT_DIR="/home/basil/bugbounty/targets/anthropic"
MONITOR_DIR="$OUTPUT_DIR/monitor"
STATE_DIR="$OUTPUT_DIR/state"

mkdir -p "$MONITOR_DIR" "$STATE_DIR"

echo "=== MONITOR WATCHER — $TARGET ==="
echo "Time: $DATE"
echo ""

source ~/bugbounty/tools/path.sh

ALERTS=0

# Step 1: Certificate Transparency Monitoring
echo "[1/5] Certificate Transparency check..."
CT_TEMP="$MONITOR_DIR/ct_latest.txt"
curl -s "https://crt.sh/?q=%.$TARGET&output=json" 2>/dev/null | \
  python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    domains = set()
    for entry in data:
        for name in entry.get('name_value', '').split('\n'):
            name = name.strip().lstrip('*.')
            if name and '*' not in name:
                domains.add(name)
    for d in sorted(domains):
        print(d)
except Exception as e:
    print(f'# error: {e}', file=sys.stderr)
" > "$CT_TEMP" 2>/dev/null || touch "$CT_TEMP"

CT_FILE="$STATE_DIR/known_subdomains.txt"
CT_NEW="$MONITOR_DIR/ct_new.txt"

if [ -f "$CT_FILE" ]; then
    comm -13 <(sort "$CT_FILE") <(sort "$CT_TEMP") > "$CT_NEW"
    NEW_CT=$(wc -l < "$CT_NEW")
    if [ "$NEW_CT" -gt 0 ]; then
        echo "  🚨 NEW CT SUBDOMAINS: $NEW_CT"
        cat "$CT_NEW"
        ALERTS=$((ALERTS + NEW_CT))
    else
        echo "  No new CT subdomains"
    fi
else
    echo "  First run — saving CT baseline ($(wc -l < "$CT_TEMP") subdomains)"
    cp "$CT_TEMP" "$CT_FILE"
fi

# Step 2: CVE Monitoring
echo "[2/5] CVE monitoring..."
TECH_FILE="$OUTPUT_DIR/recon/$(ls -d $OUTPUT_DIR/recon/*/ 2>/dev/null | sort | tail -1 | xargs basename)/tech_stack.txt"

if [ -f "$TECH_FILE" ]; then
    # Extract technologies from tech stack
    TECHS=$(grep -oP '\[.*?\]' "$TECH_FILE" 2>/dev/null | sort -u | head -10)
    
    CVE_TEMP="$MONITOR_DIR/cve_latest.json"
    CVE_FOUND=0
    
    # Check NVD for recent CVEs (last 30 days)
    python3 -c "
import urllib.request, json, ssl, datetime

ctx = ssl.create_default_context()
thirty_days_ago = (datetime.datetime.now() - datetime.timedelta(days=30)).strftime('%Y-%m-%dT00:00:00.000')

url = f'https://services.nvd.nist.gov/rest/json/cves/2.0?pubStartDate={thirty_days_ago}&resultsPerPage=20'
req = urllib.request.Request(url, headers={'User-Agent': 'bug-bounty-monitor/1.0'})
try:
    with urllib.request.urlopen(req, context=ctx, timeout=15) as resp:
        data = json.loads(resp.read())
        for item in data.get('vulnerabilities', []):
            cve = item.get('cve', {})
            cve_id = cve.get('id', 'unknown')
            desc = cve.get('descriptions', [{}])[0].get('value', 'No description')[:100]
            metrics = cve.get('metrics', {})
            cvss = metrics.get('cvssMetricV31', [{}])[0].get('cvssData', {})
            score = cvss.get('baseScore', 0)
            severity = cvss.get('baseSeverity', 'Unknown')
            if score >= 7.0:
                print(f'{cve_id} | {severity} | CVSS:{score} | {desc}')
except Exception as e:
    print(f'# NVD API error: {e}')
" > "$CVE_TEMP" 2>/dev/null || touch "$CVE_TEMP"
    
    CVE_COUNT=$(grep -c "CVE-" "$CVE_TEMP" 2>/dev/null || echo 0)
    if [ "$CVE_COUNT" -gt 0 ]; then
        echo "  🚨 HIGH CVEs found: $CVE_COUNT"
        cat "$CVE_TEMP"
        ALERTS=$((ALERTS + CVE_COUNT))
    else
        echo "  No high CVEs found"
    fi
else
    echo "  No tech stack data — skipping CVE check"
fi

# Step 3: DNS Monitoring
echo "[3/5] DNS monitoring..."
DNS_STATE="$STATE_DIR/dns_state.json"
DNS_TEMP="$MONITOR_DIR/dns_latest.json"

if [ -f "$DNS_STATE" ]; then
    # Check A records for known subdomains (sample top 20)
    SUBS=$(head -20 "$CT_FILE" 2>/dev/null || echo "$TARGET")
    > "$DNS_TEMP"
    while IFS= read -r sub; do
        [ -z "$sub" ] && continue
        IP=$(dig +short A "$sub" 2>/dev/null | head -1)
        if [ -n "$IP" ]; then
            echo "{\"subdomain\": \"$sub\", \"ip\": \"$ip\"}" >> "$DNS_TEMP"
        fi
    done <<< "$SUBS"
    
    # Compare with previous state
    DNS_CHANGES=$(python3 -c "
import json, sys
try:
    with open('$DNS_STATE') as f:
        old = {d['subdomain']: d['ip'] for d in json.load(f)}
    with open('$DNS_TEMP') as f:
        new = {json.loads(l)['subdomain']: json.loads(l)['ip'] for l in f if l.strip()}
    changes = []
    for sub, ip in new.items():
        if sub in old and old[sub] != ip:
            changes.append(f'{sub}: {old[sub]} -> {ip}')
    for sub in new:
        if sub not in old:
            changes.append(f'{sub}: NEW -> {ip}')
    print(len(changes))
    for c in changes:
        print(c)
except Exception as e:
    print(f'0\n# comparison error: {e}')
" 2>/dev/null)
    
    DNS_CHANGE_COUNT=$(echo "$DNS_CHANGES" | head -1)
    if [ "$DNS_CHANGE_COUNT" -gt 0 ]; then
        echo "  🚨 DNS CHANGES: $DNS_CHANGE_COUNT"
        echo "$DNS_CHANGES" | tail -n +2
        ALERTS=$((ALERTS + DNS_CHANGE_COUNT))
    else
        echo "  No DNS changes"
    fi
    
    # Update state
    cp "$DNS_TEMP" "$DNS_STATE"
else
    echo "  First run — saving DNS baseline"
    > "$DNS_TEMP"
    echo "$TARGET" | while IFS= read -r sub; do
        IP=$(dig +short A "$sub" 2>/dev/null | head -1)
        [ -n "$IP" ] && echo "{\"subdomain\": \"$sub\", \"ip\": \"$IP\"}"
    done > "$DNS_STATE"
fi

# Step 4: Alert deduplication
echo "[4/5] Deduplicating alerts..."
ALERT_LOG="$MONITOR_DIR/alert_history.txt"
touch "$ALERT_LOG"

# Clean old alerts (>24 hours)
if [ -f "$ALERT_LOG" ]; then
    CUTOFF=$(date -d '24 hours ago' +%Y-%m-%d-%H%M 2>/dev/null || echo "")
    if [ -n "$CUTOFF" ]; then
        grep -v "^#.*$(date -d '24 hours ago' +%Y-%m-%d)" "$ALERT_LOG" > "${ALERT_LOG}.tmp" 2>/dev/null || true
        mv "${ALERT_LOG}.tmp" "$ALERT_LOG" 2>/dev/null || true
    fi
fi

# Log current alerts
echo "# $DATE — $ALERTS new alerts" >> "$ALERT_LOG"
if [ -f "$CT_NEW" ] && [ -s "$CT_NEW" ]; then
    while IFS= read -r line; do
        echo "CT:$line" >> "$ALERT_LOG"
    done < "$CT_NEW"
fi

# Step 5: Summary
echo "[5/5] Monitor summary..."
cat > "$MONITOR_DIR/summary-$DATE.md" << EOF
# Monitor Report — $TARGET
Time: $DATE

## Alerts This Run: $ALERTS
- New CT subdomains: ${NEW_CT:-0}
- High CVEs: ${CVE_COUNT:-0}
- DNS changes: ${DNS_CHANGE_COUNT:-0}

## New Subdomains
$(cat "$CT_NEW" 2>/dev/null || echo "None")

## Recent High CVEs
$(cat "$CVE_TEMP" 2>/dev/null || echo "None")

## DNS Changes
$(echo "$DNS_CHANGES" | tail -n +2 || echo "None")
EOF

echo ""
echo "=== MONITOR COMPLETE ==="
echo "New alerts: $ALERTS"
echo "Summary: $MONITOR_DIR/summary-$DATE.md"

if [ "$ALERTS" -gt 0 ]; then
    echo ""
    echo "⚠️  ALERTS DETECTED — Review summary for details"
fi
