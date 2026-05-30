# Anthropic — HackerOne Bug Bounty Target

## Program URL
https://hackerOne.com/anthropic

## Core Assets (Focus Here First)

| Domain | Type | Resolved |
|--------|------|----------|
| claude.ai | Web App | 47 (16%) |
| api.anthropic.com | API | 5 (2%) |
| console.anthropic.com | Web App | 2 (1%) |
| Claude Code (GitHub) | Source Code | 121 (41%) |

## Non-Core Assets (Still Eligible, Lower Priority)

| Asset | Resolved |
|-------|----------|
| Claude iOS/Android/Desktop Apps | 21 (7%) |
| Infrastructure & Internal Apps | 18 (6%) |
| github.com/anthropics (source code) | 7 (2%) |
| API & SDKs | 13 (4%) |
| support.anthropic.com | 0 (0%) |
| docs.anthropic.com | 1 (0%) |
| Claude in Chrome | 1 (0%) |
| Claude Desktop Extensions/MCP | 3 (1%) |
| anthropic.atlassian.com | 1 (0%) |
| Leaked Employee API Keys | 0 (0%) |

## Key Rules

1. MUST use @wearehackerone.com email when creating accounts
2. MUST add header: X-HackerOne-Handle: <your handle>
3. AI-generated or auto-scanner reports are rejected
4. Manual validation + working PoC required for every report
5. First reporter wins for duplicates
6. One vulnerability per report (unless chained)
7. Beta/Research Preview features = non-core for 1 month after release

## Claude Code Specific Rules (High Activity - 121 reports)

In Scope:
- Bypassing permission prompts for unauthorized command execution
- Bypassing permission prompts for file writes outside working directory
- Misrepresenting parameters in permission prompts
- Executing commands invisibly to users

Out of Scope:
- Abusing intended CLI functionality
- Using aliases/symlinks to bypass prompts
- Local storage of credentials/config/logs

## Exclusions (Don't Waste Time)
- MCP OSS code → report to MCP maintainers directly (not Anthropic)
- Archived/forked repos in github.com/anthropics
- Third-party Claude extensions → report to those developers
- Auto-accept-edits file modification behavior (intended)
- Public zero-days with official patch < 7 days old

## Recon Priority

### Tier 1 (Main Targets)
- claude.ai and all subdomains
- api.anthropic.com and all subdomains
- console.anthropic.com and all subdomains

### Tier 2 (Secondary)
- support.anthropic.com
- docs.anthropic.com
- anthropic.atlassian.com
- Any subdomains discovered via recon

### Tier 3 (Source Code - Manual Review)
- github.com/anthropics (active repos only)
- github.com/anthropics/claude-code
- github.com/anthropics/claude-code-action

## API Testing Notes
- Use staging hostname for API testing (see docs)
- API keys must use @wearehackerone.com email
- Add X-HackerOne-Handle header to all API requests

## Bounty Range
- All assets: Critical severity eligible
- No specific min/max listed in public scope
- $100 discretionary for documentation updates
- Third-party coordinated fixes: $100 at discretion
