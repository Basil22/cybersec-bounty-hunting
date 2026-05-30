# Cybersec Bug Bounty Hunting

P5 — Automated bug bounty hunting with Hermes agents.

## Structure
- `skills/bugbounty/` — Agent skill files (souls)
- `skills/bugbounty/templates/` — Report and finding templates
- `docs/` — Project documentation
- `bugbounty/` — Runtime directory for targets, findings, reports
- `bugbounty/targets.txt` — Target domains list

## Agent Roles
1. **Recon Scout** (SCANNER.md) — Subdomain enum, tech detection, port scanning
2. **Vuln Analyzer** (ANALYZER.md) — Vulnerability scanning, CVE matching
3. **Monitor** (MONITOR.md) — CT log watching, CVE monitoring, DNS monitoring
4. **Reporter** (REPORTER.md) — Professional bug report generation

## License
Private.
