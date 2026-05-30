# Vuln Scan Summary — Anthropic
Date: 2026-05-30

## Stats
- CVE findings: 0
- Exposure findings: 0
- Manual check hits: 1 real finding + 15 redirects
- Missing security headers: 6 hosts affected

## Interesting Findings

### 1. Missing Security Headers (Low severity)
All 6 tested hosts missing HSTS. Most also missing X-Frame-Options, CSP, etc.

| Domain | Missing |
|--------|---------|
| claude.ai | HSTS |
| www.claude.ai | HSTS, X-Frame-Options, X-Content-Type, CSP, Referrer, Permissions |
| api.anthropic.com | HSTS, X-Frame-Options, X-Content-Type, Referrer, Permissions |
| console.anthropic.com | HSTS, X-Frame-Options, X-Content-Type, Referrer, Permissions |
| support.anthropic.com | HSTS, X-Frame-Options, X-Content-Type, CSP, Referrer, Permissions |
| docs.anthropic.com | HSTS, X-Frame-Options, X-Content-Type, CSP, Referrer, Permissions |

Note: Missing HSTS on api.anthropic.com could be noteworthy since it's a Core asset.

### 2. claude.ai serves different content on non-standard paths
- `/.git/robots.txt` → Returns 200 with full HTML page (not a real .git leak — it's a catch-all route serving the SPA)
- `/.env` → Returns Cloudflare challenge page (403) — properly protected
- `/debug` → 403 blocked by Cloudflare — properly protected
- Standard `/robots.txt` → Returns proper robots.txt with interesting disallow rules

### 3. Console subdomain behavior
- console.anthropic.com → 302 redirect (likely to login)
- All tested paths on console.anthropic.com return 302 — everything redirects to auth
- api.console.anthropic.com → 525 Cloudflare error (worth monitoring)
- sandbox.console.anthropic.com → timeout (might be internal)

### 4. robots.txt reveals interesting paths
From claude.ai/robots.txt:
```
Disallow: /new?*
Disallow: /chat/*
Disallow: /share/*
Disallow: /join/*
Disallow: /magic-link*
Disallow: /api/*          ← API is excluded from crawling
Disallow: /onboarding*
Disallow: /upgrade*
Disallow: /lti/*
```
This tells us the app has: chat, sharing, onboarding, upgrade/payments, LTI (education), and an API.

## Assessed Severity
- **Overall: Low** — No critical or high findings
- Missing headers are low-severity and common on Cloudflare-protected sites
- All sensitive endpoints properly protected by Cloudflare/redirects
- This is a well-hardened target — good security posture

## What to Look for Next (Manual Testing)
1. Authentication flow on console.anthropic.com — test for auth bypass, OAuth issues
2. API endpoints on api.anthropic.com — test for rate limiting, injection
3. Chat functionality on claude.ai — test for XSS, IDOR (requires login)
4. Payment/upgrade flow — test for logic flaws (requires login)
5. Monitor api.console.anthropic.com 525 error — might be temporary
