# Bug Bounty Report — Anthropic
Date: 2026-05-30
Platform: HackerOne
Target: anthropic.com (and subdomains)

---

## Executive Summary

Reconnaissance and vulnerability scanning of Anthropic's public-facing infrastructure.
285 subdomains discovered. No critical or high-severity vulnerabilities found.
Anthropic has a well-hardened public security posture with Cloudflare protection.

---

## Finding 1: Missing HSTS Header on api.anthropic.com

**Severity:** Low
**CVSS:** 3.1 (Low) — CVSS:3.1/AV:N/AC:L/PR:N/UI:R/S:U/C:L/I:N/A:N
**CWE:** CWE-319 — Cleartext Transmission of Sensitive Information
**Target:** api.anthropic.com (Core asset)

### Description
The API endpoint at api.anthropic.com does not include the Strict-Transport-Security (HSTS) HTTP response header. HSTS forces browsers to use HTTPS, preventing downgrade attacks and cookie hijacking.

### Evidence
```
$ curl -I https://api.anthropic.com
HTTP/2 404
server: cloudflare
(No Strict-Transport-Security header present)
```

### Steps to Reproduce
1. Run: curl -I https://api.anthropic.com
2. Observe: No Strict-Transport-Security header in response

### Impact
Without HSTS, users on networks with active attackers could potentially be downgraded to HTTP (if the site ever serves over HTTP) or have cookies intercepted. The risk is lowered because api.anthropic.com currently only serves over HTTPS.

### Recommendation
Add the Strict-Transport-Security header to all API responses:
```
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
```

### References
- [OWASP: HTTP Strict Transport Security](https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Strict_Transport_Security_Cheat_Sheet.html)
- [CWE-319: Cleartext Transmission of Sensitive Information](https://cwe.mitre.org/data/definitions/319.html)

---

## Finding 2: Missing Security Headers on Multiple Domains

**Severity:** Low
**CWE:** CWE-693 — Protection Mechanism Failure

### Affected Domains
| Domain | Missing Headers |
|--------|----------------|
| www.claude.ai | HSTS, X-Frame-Options, X-Content-Type-Options, CSP, Referrer-Policy, Permissions-Policy |
| console.anthropic.com | HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy |
| support.anthropic.com | HSTS, X-Frame-Options, X-Content-Type-Options, CSP, Referrer-Policy, Permissions-Policy |
| docs.anthropic.com | HSTS, X-Frame-Options, X-Content-Type-Options, CSP, Referrer-Policy, Permissions-Policy |

### Description
Multiple Anthropic domains are missing recommended security headers that help protect against XSS, clickjacking, MIME sniffing, and other common attacks.

### Recommendation
Add the following headers to all production domains:
```
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
Content-Security-Policy: [appropriate policy for each domain]
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=()
```

### References
- [OWASP Secure Headers Project](https://owasp.org/www-project-secure-headers/)
- [securityheaders.com](https://securityheaders.com)

---

## Informational Findings

### Subdomain Takeover Check
- No vulnerable subdomains found pointing to unregistered/decommissioned services

### Exposed Sensitive Files
- /.env, /.git/, /phpinfo.php, /server-status — All properly blocked by Cloudflare (403)
- /debug, /admin, /administrator — All properly protected (403/redirect)
- No actual file exposures found

### robots.txt Analysis (claude.ai)
Interesting paths revealed:
- /api/* — API endpoints (disallowed from crawling)
- /chat/* — Chat functionality
- /share/* — Sharing feature
- /magic-link/* — Auth via magic links
- /onboarding/* — User onboarding flow
- /upgrade/* — Payment/upgrade flow
- /lti/* — LTI (Learning Tools Interoperability) integration

### Staging Environments Discovered
- staging.anthropic.com (301 redirect)
- claude-staging.anthropic.com (timeout — may be internal)
- staging.claude.ai (301 redirect)
- console-staging.anthropic.com (404)
- api-staging.anthropic.com (404, HSTS present)
- sandbox.staging.api.anthropic.com (302 redirect)

Note: Staging environments are typically more vulnerable than production but are non-core per program rules.

---

## Scope Notes

### In Scope (Core)
- claude.ai ✓
- api.anthropic.com ✓
- console.anthropic.com ✓

### Out of Scope (Not Tested)
- github.com/modelcontextprotocol (report to MCP maintainers)
- Third-party Claude extensions
- Archived/forked repos
- Auto-accept-edits behavior
- Claude iOS/Android/Desktop apps (mobile testing not performed)

---

## Conclusion

Anthropic's public infrastructure is well-secured. The main findings are missing security headers (low severity). Real vulnerability hunting requires authenticated testing:
- Chat functionality (XSS, IDOR)
- API endpoints (injection, auth bypass)
- Payment/upgrade flow (logic flaws)
- Console admin panel (privilege escalation)

These require HackerOne account access and manual testing.
