#!/bin/bash
# Anthropic Bug Bounty — Recon Scout Run Script
# Usage: bash run-recon.sh [target_domain]
# Example: bash run-recon.sh anthropic.com

set -e

TARGET="${1:-anthropic.com}"
DATE=$(date +%Y-%m-%d)
OUTPUT_DIR="/home/basil/bugbounty/targets/anthropic"
RECON_DIR="$OUTPUT_DIR/recon/$DATE"

mkdir -p "$RECON_DIR"

echo "=== RECON SCOUT — $TARGET ==="
echo "Date: $DATE"
echo "Output: $RECON_DIR"
echo ""

# Source tools PATH
source ~/bugbounty/tools/path.sh

# Step 1: Subdomain Enumeration
echo "[1/6] Running subfinder..."
subfinder -d "$TARGET" -silent -o "$RECON_DIR/subdomains.txt" 2>/dev/null
SUBS=$(wc -l < "$RECON_DIR/subdomains.txt")
echo "  Found: $SUBS subdomains"

# Step 2: Certificate Transparency
echo "[2/6] Checking Certificate Transparency (crt.sh)..."
curl -s "https://crt.sh/?q=%.$TARGET&output=json" 2>/dev/null | \
  python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    domains = set()
    for entry in data:
        name = entry.get('name_value', '')
        for d in name.split('\\n'):
            d = d.strip().lstrip('*.')
            if d and '*' not in d:
                domains.add(d)
    for d in sorted(domains):
        print(d)
except:
    print('# crt.sh parse failed')
" > "$RECON_DIR/ct_subdomains.txt" 2>/dev/null || echo "# crt.sh check failed" > "$RECON_DIR/ct_subdomains.txt"

CT_COUNT=$(wc -l < "$RECON_DIR/ct_subdomains.txt")
echo "  Found: $CT_COUNT domains from CT logs"

# Merge and deduplicate
cat "$RECON_DIR/subdomains.txt" "$RECON_DIR/ct_subdomains.txt" | sort -u > "$RECON_DIR/all_subdomains.txt"
TOTAL=$(wc -l < "$RECON_DIR/all_subdomains.txt")
echo "  Total unique subdomains: $TOTAL"
echo ""

# Step 3: Live Host Probing
echo "[3/6] Probing live hosts with httpx..."
httpx -l "$RECON_DIR/all_subdomains.txt" -silent -status-code -title -tech-detect \
  -o "$RECON_DIR/live_hosts.txt" 2>/dev/null || true

LIVE=$(wc -l < "$RECON_DIR/live_hosts.txt" 2>/dev/null || echo 0)
echo "  Live hosts: $LIVE"
echo ""

# Step 4: Technology Detection
echo "[4/6] Detecting technologies..."
> "$RECON_DIR/tech_stack.txt"
while IFS= read -r host; do
  result=$(whatweb "$host" -v 2>/dev/null | head -5)
  echo "--- $host ---" >> "$RECON_DIR/tech_stack.txt"
  echo "$result" >> "$RECON_DIR/tech_stack.txt"
done < "$RECON_DIR/live_hosts.txt"
echo "  Tech detection complete"
echo ""

# Step 5: URL Discovery
echo "[5/6] Discovering URLs (gau + waybackurls)..."
gau "$TARGET" --threads 8 2>/dev/null | head -50000 > "$RECON_DIR/gau_urls.txt" || true
cat "$RECON_DIR/all_subdomains.txt" | waybackurls 2>/dev/null | head -50000 >> "$RECON_DIR/gau_urls.txt" || true
cat "$RECON_DIR/gau_urls.txt" | sort -u > "$RECON_DIR/endpoints.txt"
ENDPOINTS=$(wc -l < "$RECON_DIR/endpoints.txt")
echo "  Discovered: $ENDPOINTS endpoints"
echo ""

# Step 6: Port Scanning (top 100 on live hosts)
echo "[6/6] Scanning ports (top 100)..."
nmap -Pn --top-ports 100 -T4 --open -iL "$RECON_DIR/live_hosts.txt" \
  -oN "$RECON_DIR/ports.nmap" 2>/dev/null || true
echo "  Port scan complete"
echo ""

# Compare with previous run
echo "=== COMPARISON WITH PREVIOUS RUN ==="
PREV_DIR=$(ls -d "$OUTPUT_DIR/recon/"*/ 2>/dev/null | sort | tail -2 | head -1)
if [ -n "$PREV_DIR" ] && [ "$PREV_DIR" != "$RECON_DIR/" ]; then
  PREV_SUBS=$(wc -l < "$PREV_DIR/all_subdomains.txt" 2>/dev/null || echo 0)
  NEW_SUBS=$((TOTAL - PREV_SUBS))
  echo "  Previous subdomains: $PREV_SUBS"
  echo "  Current subdomains: $TOTAL"
  echo "  New subdomains: $NEW_SUBS"
  
  # Show new subdomains
  if [ "$NEW_SUBS" -gt 0 ]; then
    echo ""
    echo "  NEW SUBDOMAINS:"
    comm -13 <(sort "$PREV_DIR/all_subdomains.txt") <(sort "$RECON_DIR/all_subdomains.txt") | head -20
  fi
else
  echo "  No previous run found (first run)"
fi

# Write summary
cat > "$RECON_DIR/summary.md" << EOF
# Recon Summary — $TARGET
Date: $DATE

## Stats
- Subdomains found: $TOTAL
- Live hosts: $LIVE
- Endpoints discovered: $ENDPOINTS
- New subdomains: ${NEW_SUBS:-N/A (first run)}

## Live Hosts
$(cat "$RECON_DIR/live_hosts.txt" 2>/dev/null | head -20)

## Top Technologies
$(grep -h "plugins" "$RECON_DIR/tech_stack.txt" 2>/dev/null | sort | uniq -c | sort -rn | head -10)

## Open Ports Summary
$(grep "open" "$RECON_DIR/ports.nmap" 2>/dev/null | head -20)
EOF

echo ""
echo "=== RECON COMPLETE ==="
echo "Summary: $RECON_DIR/summary.md"
echo "All files in: $RECON_DIR"
