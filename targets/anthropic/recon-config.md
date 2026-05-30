# Anthropic Recon Configuration

## Target Summary
- Program: Anthropic Bug Bounty (HackerOne)
- Handle: anthropic
- Coverage: Critical severity eligible across all assets

## In-Scope Targets (Priority Order)

### Tier 1 — Core Web Targets
- claude.ai (and all subdomains)
- api.anthropic.com (and all subdomains)
- console.anthropic.com (and all subdomains)

### Tier 2 — Non-Core Web Targets
- support.anthropic.com
- docs.anthropic.com
- anthropic.atlassian.com

### Tier 3 — Source Code
- github.com/anthropics (active repos only, not archived/forks)
- github.com/anthropics/claude-code
- github.com/anthropics/claude-code-action

## Out of Scope (Don't Test)
- github.com/modelcontextprotocol (report to MCP maintainers)
- Third-party Claude extensions
- Archived/forked repos in anthropics
- Auto-accept-edits mode file modifications (intended behavior)

## Testing Requirements
1. Use @wearehackerone.com email for all account creation
2. Add header to ALL requests: X-HackerOne-Handle: <your_handle>
3. API testing: use staging hostname (see docs.anthropic.com)
4. Manual validation required — no automated scanner reports
5. Working PoC required for every submission

## Recon Commands

### Subdomain Enumeration
subfinder -d anthropic.com -silent -o subdomains.txt
subfinder -d claude.ai -silent -append subdomains.txt

### Live Host Probing
httpx -l subdomains.txt -silent -status-code -title -tech-detect -o live_hosts.txt

### Endpoint Discovery
gau anthropic.com --threads 8 --o endpoints.txt
waybackurls anthropic.com | anew endpoints.txt

### Technology Detection
whatweb claude.ai -v
whatweb api.anthropic.com -v
whatweb console.anthropic.com -v

### Port Scanning (Top 1000)
nmap -Pn --top-ports 1000 -T4 --open -iL live_hosts.txt -oN ports.nmap

### Certificate Transparency
curl -s "https://crt.sh/?q=%.anthropic.com&output=json" | jq -r '.[].name_value | select(. != "*.")' | sort -u | anew ct_subdomains.txt

### API Endpoint Discovery
# Check for common API paths
httpx -l live_hosts.txt -path "/api/v1,/api/v2,/api/v3,/graphql,/swagger,/docs,/openapi.json" -silent -status-code

## High-Value Targets for Vuln Analyzer
1. claude.ai — XSS in chat, auth bypass, IDOR, file upload vulns
2. api.anthropic.com — API auth bypass, rate limit bypass, injection
3. console.anthropic.com — admin panel access, privilege escalation

## Claude Code Specific Checks
- Permission prompt bypasses
- File write outside working directory
- Tool parameter misrepresentation
- Invisible command execution
