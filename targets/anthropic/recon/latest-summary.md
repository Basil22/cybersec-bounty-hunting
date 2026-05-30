# Recon Summary — Anthropic
Date: 2026-05-30

## Stats
- Subdomains found: 285
- Live hosts probed: 15 (top 50)
- Key targets scanned: 10

## Key Targets Status

| Domain | HTTP | Notes |
|--------|------|-------|
| claude.ai | 403 | Blocked (Cloudflare) |
| www.claude.ai | 301 | Redirects |
| api.anthropic.com | 404 | API root — needs auth |
| console.anthropic.com | 302 | Redirects (login page) |
| api.console.anthropic.com | 525 | Cloudflare error — interesting |
| sandbox.console.anthropic.com | timeout | Timed out — interesting |
| staging.claude.ai | 301 | Redirects |
| claude-staging.anthropic.com | timeout | Timed out — interesting |
| support.anthropic.com | 302 | Redirects |
| docs.anthropic.com | 301 | Redirects |

## Interesting Findings

1. **api.console.anthropic.com → 525** — Cloudflare error, might be misconfigured
2. **sandbox.console.anthropic.com → timeout** — Could be internal-only, worth monitoring
3. **claude-staging.anthropic.com → timeout** — Staging environment, might appear later
4. **claude.ai → 403** — Behind Cloudflare, normal for production
5. **285 subdomains discovered** — Many are CDN/internal (a-cdn, assets, etc.)

## Subdomain Categories

### API/Backend
- api.anthropic.com, api-staging.anthropic.com
- api.console.anthropic.com, api-release-candidate.anthropic.com
- a-api.anthropic.com, internal.api.anthropic.com
- live.api.anthropic.com, public.api.anthropic.com
- private.api.anthropic.com, sandbox.api.anthropic.com

### Console/Admin
- console.anthropic.com, console-staging.anthropic.com
- auth.console.anthropic.com, auth.console-staging.anthropic.com
- sandbox.console.anthropic.com, alpha.console.anthropic.com
- vpn.console.anthropic.com

### Staging/Dev
- staging.anthropic.com, claude-staging.anthropic.com
- staging.claude.ai, staging.a-cdn.claude.ai
- staging.tunnel.anthropic.com
- api-staging.anthropic.com, api-staging.product-internal.anthropic.com

### CDN/Assets
- a-cdn.anthropic.com, a-cdn.claude.ai
- assets.anthropic.com, assets.claude.ai
- assets-proxy.anthropic.com
- cdn.a-cdn.claude.ai, s-cdn.anthropic.com

### Internal (likely)
- *.mimir.anthropic.com (monitoring)
- *.bo.anthropic.com (back office)
- titanium-*.anthropic.com (infrastructure)
- homespace-*.anthropic.com

### Support/Docs
- support.anthropic.com, docs.anthropic.com
- learn.anthropic.com, feedback.anthropic.com

## Next Steps for Manual Exploration
1. Check api.console.anthropic.com 525 error — might expose debug info
2. Monitor sandbox.console.anthropic.com — might come online
3. Explore console.anthropic.com login flow
4. Check docs.anthropic.com for API documentation leaks
5. Review staging subdomains when they come online
