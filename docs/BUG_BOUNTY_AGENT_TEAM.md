# P5 — Cybersecurity & Bug Bounty Agent Team

**Status:** Planning phase. Architecture design complete. Awaiting Basil's approval to start building.
**Created:** May 29, 2026
**Goal:** Build an automated bug bounty hunting operation where agents handle recon, scanning, monitoring, and report drafting — Basil handles creative exploitation.

## Deployment Strategy: Local Hermes (Not EC2)

**Decision:** Run Hermes on Basil's local machine, NOT on EC2.

**Why:**
- EC2 t2.micro has only 916 MB RAM — too tight for running multiple security tools + agents
- Local machine has full RAM/CPU for running nuclei scans, subdomain enumeration, etc.
- No EC2 costs for compute-heavy scanning work
- EC2 continues running Hermes Gateway for Telegram, newsletter, etc.

**Architecture:**
```
Local Machine (Basil)              EC2
┌─────────────────────┐           ┌──────────────────┐
│ Hermes Agent         │           │ Hermes Gateway    │
│ + bug bounty agents  │ ←Telegram→ │ + Newsletter      │
│ + security tools     │           │ + Cron jobs       │
│ + local scanning     │           │ + Nginx           │
└─────────────────────┘           └──────────────────┘
       │                                   │
       ▼                                   ▼
  ~/bugbounty/                      ~/newsletter/
  (local findings)                    (newsletter code)
```

**What runs locally:**
- All bug bounty agents (Recon, Analyzer, Monitor, Reporter)
- Security tool stack (subfinder, nuclei, httpx, nmap, etc.)
- Findings directory (`~/bugbounty/`)
- Report generation

**What stays on EC2:**
- Hermes Gateway (Telegram connectivity)
- Newsletter pipeline
- Cron jobs for newsletter
- Nginx + SSL

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Agent Roles & Soul Templates](#2-agent-roles--soul-templates)
3. [Setup Guide](#3-setup-guide)
4. [Bug Bounty Platforms](#4-bug-bounty-platforms)
5. [Tool Stack](#5-tool-stack)
6. [Workflow: From Recon to Report](#6-workflow-from-recon-to-report)
7. [Income Expectations](#7-income-expectations)
8. [Security & Legal Notes](#8-security--legal-notes)

---

## 1. Architecture Overview

### Single EC2, Multiple Agent Roles

You do NOT need separate Hermes installations. One EC2 instance runs all agents through:

- **Cron jobs** — scheduled scanning, monitoring, reporting
- **delegate_task** — spawn parallel subagents for heavy work
- **Skills directory** — each role has its own skill file with persona + instructions
- **Shared filesystem** — agents pass findings through files in `/home/ec2-user/bugbounty/`

```
┌─────────────────────────────────────────────────────────────┐
│                     EC2 t2.micro                             │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  Recon Agent  │  │ Scanner Agent│  │ Monitor Agent    │  │
│  │  (cron 6 AM)  │  │ (cron 8 AM)  │  │ (cron hourly)    │  │
│  │              │  │              │  │                  │  │
│  │ Subdomain    │  │ Vuln scan    │  │ CVE monitoring   │  │
│  │ enumeration  │  │ endpoints    │  │ New targets      │  │
│  │ Tech detect  │  │ Auth testing │  │ CT log watching  │  │
│  │ Port scan    │  │ XSS/SQLi     │  │ JS analysis      │  │
│  └──────┬───────┘  └──────┬───────┘  └────────┬─────────┘  │
│         │                 │                    │             │
│         ▼                 ▼                    ▼             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Shared Findings Directory                 │  │
│  │  ~/bugbounty/{target}/                                │  │
│  │    ├── recon/subdomains.txt                           │  │
│  │    ├── recon/tech_stack.json                          │  │
│  │    ├── scan/vulns.json                                │  │
│  │    ├── monitor/alerts.md                              │  │
│  │    └── reports/YYYY-MM-DD-{target}.md                 │  │
│  └──────────────────────────────────────────────────────┘  │
│         │                                                   │
│         ▼                                                   │
│  ┌──────────────────┐  ┌──────────────────────────────┐   │
│  │ Report Agent      │  │ Telegram Alert Agent         │   │
│  │ (on-demand)       │  │ (triggered by findings)      │   │
│  │                  │  │                              │   │
│  │ Format findings  │  │ "New critical vuln found"    │   │
│  │ Generate PDF     │  │ "New subdomain discovered"   │   │
│  │ Draft report     │  │ "CVE match for target"       │   │
│  └──────────────────┘  └──────────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Basil (Human) — Creative exploitation, final review  │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### How Multiple "Souls" Work

Each agent role gets its own **skill file** that acts as its soul/persona:

```
~/.hermes/skills/bugbounty/
├── SCANNER.md        # Recon & enumeration agent
├── ANALYZER.md       # Vulnerability analysis agent
├── MONITOR.md        # Continuous monitoring agent
├── REPORTER.md       # Report writing agent
└── templates/
    ├── report.md     # Bug report template
    └── finding.md    # Individual finding template
```

When a cron job or delegate_task runs, it loads the appropriate skill file as its instruction set. Same Hermes installation, different personalities.

---

## 2. Agent Roles & Soul Templates

### Agent 1: Recon Scout

**Role:** Subdomain enumeration, technology detection, endpoint discovery
**Schedule:** Daily at 6:00 AM IST
**Soul/Persona:** Methodical, thorough, curious

```markdown
# SCANNER.md — Recon Scout Agent

You are the Recon Scout — the first agent in the bug bounty pipeline.
Your job is to map the attack surface of target domains.

## Personality
- Methodical and thorough — leave no stone unturned
- Curious — always looking for hidden endpoints
- Document everything — your findings feed the entire pipeline

## Your Tools
- `subfinder` — passive subdomain enumeration
- `amass` — active subdomain enumeration
- `httpx` — HTTP probing of discovered hosts
- `nmap` — port scanning (top 1000 ports)
- `whatweb` / `wappalyzer` — technology fingerprinting
- `waybackurls` / `gau` — historical URL discovery
- `nuclei` — template-based scanning (safe templates only)

## Workflow
1. Read target list from `~/bugbounty/targets.txt`
2. For each target:
   a. Run subfinder → save to `~/bugbounty/{target}/recon/subdomains.txt`
   b. Run httpx to probe live hosts → save to `live_hosts.txt`
   c. Run whatweb for tech detection → save to `tech_stack.json`
   d. Run waybackurls for historical endpoints → save to `endpoints.txt`
   e. Run nmap top-1000 ports on live hosts → save to `ports.txt`
3. Compare with previous run → note new subdomains/endpoints
4. Write summary to `~/bugbounty/{target}/recon/summary.md`
5. If new findings → send Telegram alert

## Output Format
All findings go in `~/bugbounty/{target}/recon/` directory.
Use JSON for structured data, Markdown for summaries.

## Rules
- Only scan domains you have permission to test
- Rate-limit requests to avoid overwhelming targets
- Never run destructive scans
- Document every command you run
```

### Agent 2: Vulnerability Analyzer

**Role:** Take recon findings, identify vulnerabilities
**Schedule:** Daily at 8:00 AM IST (after recon completes)
**Soul/Persona:** Analytical, security-focused, detail-oriented

```markdown
# ANALYZER.md — Vulnerability Analyzer Agent

You are the Vulnerability Analyzer — you take the Recon Scout's findings
and identify potential security issues.

## Personality
- Analytical and precise — every finding must be verified
- Security-minded — think like an attacker, act like a defender
- Evidence-based — never report without proof

## Your Tools
- `nuclei` — vulnerability scanning with safe templates
- `nuclei -t cves/` — CVE-based detection
- `nuclei -t exposures/` — exposed configs/secrets
- `nuclei -t misconfiguration/` — common misconfigs
- `curl` — manual endpoint testing
- `execute_code` — custom Python analysis scripts

## Workflow
1. Read recon findings from `~/bugbounty/{target}/recon/`
2. Run nuclei with safe templates against live hosts
3. Analyze technology stack for known CVEs
4. Check for common misconfigurations:
   - Exposed .git, .env, backup files
   - Missing security headers
   - Default credentials
   - Open redirects
5. Verify each finding manually (don't trust automated tools blindly)
6. Rate findings: Critical / High / Medium / Low / Info
7. Save verified findings to `~/bugbounty/{target}/scan/vulns.json`
8. Write human-readable summary to `scan/findings.md`
9. Alert on Critical/High findings via Telegram

## Output Format
```json
{
  "target": "example.com",
  "date": "2026-05-29",
  "findings": [
    {
      "title": "Exposed .env file",
      "severity": "High",
      "url": "https://example.com/.env",
      "evidence": "curl output showing DB credentials",
      "recommendation": "Block access to .env files in web server config",
      "cvss": 7.5
    }
  ]
}
```

## Rules
- Verify every automated finding manually
- Never exploit vulnerabilities — only identify them
- Respect rate limits
- Document evidence for every finding
```

### Agent 3: Monitor Watcher

**Role:** Continuous monitoring for new attack surface and CVEs
**Schedule:** Every 2 hours
**Soul/Persona:** Vigilant, always watching, alert

```markdown
# MONITOR.md — Monitor Watcher Agent

You are the Monitor Watcher — you keep watch over targets and alert
when something changes or new threats emerge.

## Personality
- Vigilant — always watching, never sleeping
- Alert — immediate notification on important changes
- Concise — short, actionable alerts

## Your Tasks
1. **Certificate Transparency Monitoring**
   - Check crt.sh for new subdomains of target domains
   - Alert on any new certificates issued

2. **CVE Monitoring**
   - Check NVD for new CVEs matching target tech stack
   - Cross-reference with `~/bugbounty/{target}/recon/tech_stack.json`
   - Alert on any matching CVEs with CVSS >= 7.0

3. **JavaScript File Monitoring**
   - Fetch and analyze JS files from target websites
   - Look for:
     - API endpoints
     - Secrets/tokens
     - Internal URLs
     - Comments with sensitive info

4. **DNS Monitoring**
   - Check for DNS changes (new records, IP changes)
   - Alert on any changes

## Workflow
1. Read target list and tech stacks
2. Run each monitoring task
3. Compare with previous state
4. If changes detected → write to `~/bugbounty/{target}/monitor/alerts.md`
5. Send Telegram alert for important changes
6. Update state files

## Alert Format
```
🚨 BUG BOUNTY ALERT
Target: example.com
Type: New subdomain discovered
Detail: api-v2.example.com (new cert on crt.sh)
Time: 2026-05-29 10:30 IST
Action: Added to recon queue
```
```

### Agent 4: Report Writer

**Role:** Compile findings into professional bug bounty reports
**Schedule:** On-demand (triggered by Basil or when Critical/High findings exist)
**Soul/Persona:** Professional, clear, persuasive

```markdown
# REPORTER.md — Report Writer Agent

You are the Report Writer — you compile agent findings into
professional bug bounty reports ready for submission.

## Personality
- Professional — reports should look like they came from a senior pentester
- Clear — anyone should understand the impact
- Persuasive — make the case for why this bug matters

## Report Structure
For each finding, generate:

### Title
Short, descriptive: "Reflected XSS in search parameter on example.com"

### Severity
Critical / High / Medium / Low / Info
Include CVSS score if applicable

### Target
URL, parameter, affected component

### Description
What is the vulnerability? How does it work?

### Steps to Reproduce
Numbered steps with exact commands/requests:
1. Navigate to `https://example.com/search?q=test`
2. Insert payload: `<script>alert(1)</script>`
3. Observe: JavaScript executes in browser

### Impact
What can an attacker do? What's at risk?

### Evidence
Screenshots, curl output, HTTP requests/responses

### Recommendation
How to fix it. Be specific.

### References
CVE links, OWASP references, similar bugs

## Output
Save reports to `~/bugbounty/{target}/reports/`
Format: Markdown + PDF (using fpdf2)
```

---

## 3. Setup Guide

### Step 1: Create Directory Structure

```bash
mkdir -p ~/bugbounty/{targets,recon,scan,monitor,reports,tools}
echo "example.com" > ~/bugbounty/targets.txt
```

### Step 2: Install Security Tools

```bash
# Subdomain enumeration
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest

# HTTP probing
go install github.com/projectdiscovery/httpx/cmd/httpx@latest

# Vulnerability scanning
go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
nuclei -update-templates

# URL discovery
go install github.com/lc/gau/v2/cmd/gau@latest
go install github.com/tomnomnom/waybackurls@latest

# Technology detection
pip3 install whatweb

# Port scanning (usually pre-installed)
sudo yum install nmap -y
```

### Step 3: Create Skill Files

Create the skill files from the templates above in `~/.hermes/skills/bugbounty/`.

### Step 4: Set Up Cron Jobs

```
# Recon — daily at 6 AM IST
0 6 * * * /usr/local/bin/hermes cron run --skill bugbounty/SCANNER --prompt "Run daily recon on all targets"

# Scan — daily at 8 AM IST
0 8 * * * /usr/local/bin/hermes cron run --skill bugbounty/ANALYZER --prompt "Run vulnerability scan on latest recon findings"

# Monitor — every 2 hours
0 */2 * * * /usr/local/bin/hermes cron run --skill bugbounty/MONITOR --prompt "Run monitoring checks"

# Report — daily at 10 AM IST (only if findings exist)
0 10 * * * /usr/local/bin/hermes cron run --skill bugbounty/REPORTER --prompt "Check for unreported findings and generate reports"
```

### Step 5: Configure Telegram Alerts

Each agent sends alerts via `send_message` tool to your Telegram chat (859896199).

---

## 4. Bug Bounty Platforms

### HackerOne (Recommended for Beginners)
- **URL:** https://hackerone.com
- **How to join:** Sign up → Complete profile → Apply to programs
- **Payouts:** $50 - $50,000+ per bug
- **Best for:** Wide variety of targets, good documentation
- **Tips:**
  - Start with "Open" programs (no invite needed)
  - Read program scope carefully
  - Quality over quantity

### Bugcrowd
- **URL:** https://bugcrowd.com
- **How to join:** Sign up → Pass entrance exam → Join programs
- **Payouts:** $50 - $25,000+ per bug
- **Best for:** Structured programs, good learning resources
- **Tips:**
  - Bugcrowd University has free training
  - Start with VDP (Vulnerability Disclosure Programs) for practice

### Intigriti
- **URL:** https://intigriti.com
- **How to join:** Sign up → Apply to programs
- **Payouts:** €50 - €10,000+ per bug
- **Best for:** European companies, responsive triagers
- **Tips:**
  - European focus means less competition
  - Good for beginners

### OpenBugBounty
- **URL:** https://openbugbounty.org
- **How to join:** Sign up → Start hunting (no permission needed for web)
- **Payouts:** $0 (coordinated disclosure, reputation-based)
- **Best for:** Practice, building reputation
- **Tips:**
  - Great for learning
  - No guaranteed payout but builds profile

### YesWeHack
- **URL:** https://yeswehack.com
- **How to join:** Sign up → Join programs
- **Payouts:** €50 - €50,000+ per bug
- **Best for:** European programs, bug bounty + pentest hybrid

---

## 5. Tool Stack

### Reconnaissance
| Tool | Purpose | Install |
|------|---------|---------|
| subfinder | Passive subdomain enum | `go install` |
| amass | Active subdomain enum | `go install` |
| httpx | HTTP probing | `go install` |
| nmap | Port scanning | `yum install nmap` |
| whatweb | Tech fingerprinting | `pip3 install whatweb` |
| waybackurls | Historical URLs | `go install` |
| gau | URL aggregation | `go install` |
| crt.sh | Certificate transparency | Web API |
| Shodan | Internet-wide scanning | API key |

### Vulnerability Scanning
| Tool | Purpose | Install |
|------|---------|---------|
| nuclei | Template-based scanning | `go install` |
| nikto | Web server scanner | `yum install nikto` |
| SQLmap | SQL injection testing | `pip3 install sqlmap` |
| XSStrike | XSS detection | Git clone |
| ffuf | Fuzzing | `go install` |

### Monitoring
| Tool | Purpose | Install |
|------|---------|---------|
| certstream | Real-time cert monitoring | Python library |
| NVD API | CVE database | Web API |
| GitHub Dorking | Secret exposure | Web search |

### Reporting
| Tool | Purpose | Install |
|------|---------|---------|
| fpdf2 | PDF report generation | `pip3 install fpdf2` |
| Markdown | Report format | Built-in |

---

## 6. Workflow: From Recon to Report

```
Day 1: Recon Scout runs → Discovers 50 subdomains, identifies tech stack
         ↓
Day 1: Analyzer runs → Scans all 50 hosts, finds 3 potential vulns
         ↓
Day 1: Basil reviews → Confirms 1 is exploitable, writes PoC
         ↓
Day 1: Reporter generates → Professional report ready for submission
         ↓
Day 2: Basil submits → To HackerOne/Bugcrowd
         ↓
Day 3-7: Triage → Platform triages, asks for clarification
         ↓
Day 7-30: Bounty → If accepted, receive payment
```

### What Agents Do vs What You Do

| Task | Agent | You |
|------|-------|-----|
| Subdomain enumeration | ✅ | |
| Port scanning | ✅ | |
| Tech detection | ✅ | |
| Vuln scanning | ✅ | |
| CVE matching | ✅ | |
| Report drafting | ✅ | |
| Creative exploitation | | ✅ |
| Business logic testing | | ✅ |
| Auth bypass testing | | ✅ |
| Final report review | | ✅ |
| Platform submission | | ✅ |
| Communication with triage | | ✅ |

---

## 7. Income Expectations

### Realistic Timeline

| Period | Expected Income | Notes |
|--------|----------------|-------|
| Month 1-3 | $0 - $500 | Learning, first submissions rejected |
| Month 3-6 | $500 - $2,000/month | First accepted reports |
| Month 6-12 | $2,000 - $5,000/month | Consistent hunting, known targets |
| Year 1-2 | $5,000 - $15,000/month | Reputation, private programs |
| Top hunters | $50,000 - $500,000+/year | Full-time, specialized |

### Factors That Affect Income
- **Quality of targets** — Big tech pays more than small startups
- **Bug severity** — Critical RCE > Reflected XSS
- **Report quality** — Clear, professional reports get accepted faster
- **Speed** — First valid report gets the bounty
- **Specialization** — Pick 1-2 vuln types and master them

### Best Vulnerability Types for Beginners
1. **XSS (Cross-Site Scripting)** — Common, well-documented, good for learning
2. **IDOR (Insecure Direct Object Reference)** — Easy to find, high impact
3. **Information Disclosure** — Exposed files, debug info
4. **Missing Security Headers** — Easy wins, low hanging fruit
5. **Open Redirects** — Simple but valid

---

## 8. Security & Legal Rules

### Golden Rules
1. **Only test what's in scope** — Read program rules carefully
2. **Never go beyond proof of concept** — Don't exfiltrate data, don't DoS
3. **Use a VPN** — Protect your identity
4. **Document everything** — Screenshots, timestamps, commands
5. **Respect rate limits** — Don't overwhelm targets
6. **No automated exploitation** — Only identify, don't exploit
7. **Report responsibly** — Give time to fix before disclosing

### Legal Considerations
- **Written permission** — Only test programs you've joined
- **Safe harbor** — Most platforms offer legal protection for good-faith research
- **Never test without permission** — Unauthorized access is illegal (CFAA, IT Act)
- **Keep records** — Save all communications with platforms

### OPSEC (Operational Security)
- Use a dedicated email for bug bounty
- Use a VPN when scanning
- Don't share findings publicly before disclosure
- Use separate browser profiles for hunting
- Don't use your real name on platforms (use handle)

---

## Local Hermes Setup Guide

### Step 1: Install Hermes Locally

Follow the official Hermes Agent docs: https://hermes-agent.nousresearch.com/docs

```bash
# Clone the repo
git clone https://github.com/nousresearch/hermes-agent.git
cd hermes-agent

# Install dependencies
pip3 install -r requirements.txt

# Or use the CLI installer
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
```

### Step 2: Configure Hermes for Local Use

```bash
# Run setup wizard
hermes setup

# Configure your LLM provider (use free options)
# Recommended: OpenRouter with free models
hermes config set provider openrouter
hermes config set model "nvidia/nemotron-3-super-120b-a12b:free"

# Or use Google Gemini (free tier)
hermes config set provider google
hermes config set model "gemini-2.5-flash"
```

### Step 3: Set Up Telegram (Optional but Recommended)

For Telegram connectivity from local machine:
```bash
# Create a Telegram bot via @BotFather
# Get bot token, then:
hermes config set telegram.token "YOUR_BOT_TOKEN"
hermes config set telegram.chat_id "YOUR_CHAT_ID"
```

**Alternative:** Keep using EC2's Hermes Gateway for Telegram. Your local agents can send alerts via webhooks or save findings to GitHub which EC2 monitors.

### Step 4: Install Security Tools

```bash
# Go-based tools (need Go installed)
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install github.com/lc/gau/v2/cmd/gau@latest
go install github.com/tomnomnom/waybackurls@latest
go install github.com/ffuf/ffuf@latest

# Update nuclei templates
nuclei -update-templates

# System tools
# macOS
brew install nmap

# Ubuntu/Debian
sudo apt install nmap nikto -y

# Python tools
pip3 install whatweb
```

### Step 5: Create Project Structure

```bash
mkdir -p ~/bugbounty/{targets,recon,scan,monitor,reports,tools,skills}
echo "# Bug bounty targets (one domain per line)" > ~/bugbounty/targets.txt
echo "hackerone.com" >> ~/bugbounty/targets.txt  # Example
```

### Step 6: Copy Skill Files

Copy the skill templates from this doc into your local Hermes skills directory:

```bash
# Find your Hermes skills directory
hermes skills list

# Copy skill files
cp SCANNER.md ~/.hermes/skills/bugbounty/
cp ANALYZER.md ~/.hermes/skills/bugbounty/
cp MONITOR.md ~/.hermes/skills/bugbounty/
cp REPORTER.md ~/.hermes/skills/bugbounty/
```

### Step 7: Run Your First Scan

```bash
# Start Hermes
hermes

# Or run a specific agent task
hermes run --skill bugbounty/SCANNER --prompt "Run recon on targets in ~/bugbounty/targets.txt"
```

### Step 8: Set Up Cron Jobs (Local)

```bash
# Edit crontab
crontab -e

# Add these entries (adjust paths):
# Recon — daily at 6 AM
0 6 * * * cd ~/bugbounty && hermes run --skill bugbounty/SCANNER --prompt "Run daily recon"

# Scan — daily at 8 AM
0 8 * * * cd ~/bugbounty && hermes run --skill bugbounty/ANALYZER --prompt "Run vulnerability scan"

# Monitor — every 2 hours
0 */2 * * * cd ~/bugbounty && hermes run --skill bugbounty/MONITOR --prompt "Run monitoring checks"

# Report check — daily at 10 AM
0 10 * * * cd ~/bugbounty && hermes run --skill bugbounty/REPORTER --prompt "Check for unreported findings"
```

### Communication Between Local and EC2

Since your local machine and EC2 both run Hermes:

```
Option A: Shared GitHub Repo
- Local agents push findings to GitHub
- EC2 pulls findings, sends Telegram alerts
- Simple, reliable, no network config needed

Option B: Direct Telegram
- Local Hermes has its own bot token
- Alerts go directly to your Telegram
- Faster, but needs separate bot setup

Option C: Webhook
- Local agents call EC2 webhook
- EC2 processes and alerts
- More complex, real-time
```

**Recommended:** Start with Option A (GitHub sync). It's simplest and you already have the backup cron working.

---

## Next Steps for Basil

1. **Install Hermes locally** (follow Step 1-2 above)
2. **Install security tools** (Step 4)
3. **Create accounts** on HackerOne and Bugcrowd
4. **Set up project structure** (Step 5)
5. **Copy skill files** (Step 6)
6. **Add first targets** to `targets.txt` (start with Open programs)
7. **Run first recon scan** (Step 7)
8. **Set up cron jobs** (Step 8)
9. **Start hunting!**

---

## References

- HackerOne Hacktivity: https://hackerone.com/hacktivity
- Bugcrowd University: https://bugcrowd.com/university
- PortSwigger Web Security Academy: https://portswigger.net/web-security
- OWASP Testing Guide: https://owasp.org/www-project-web-security-testing-guide/
- Nuclei Templates: https://github.com/projectdiscovery/nuclei-templates
- Bug Bounty Playbook: https://github.com/devanshbatham/Awesome-Bugbounty-Resources
