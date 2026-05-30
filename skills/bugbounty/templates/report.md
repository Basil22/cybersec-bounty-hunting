# Bug Report Template

```markdown
# [VULNERABILITY TITLE]

**Program:** [Program Name on HackerOne/Bugcrowd]
**Target:** [affected domain/URL]
**Severity:** [Critical | High | Medium | Low | Informational]
**CVSS v3.1:** [score] ([vector])
**CWE:** CWE-[number] — [name]
**Discovery Date:** [YYYY-MM-DD]

---

## Summary

[2-3 sentence executive summary of the vulnerability]

## Description

[Detailed technical description of the vulnerability.
What is it? How does it work? Where does it occur?]

## Steps to Reproduce

1. [Step 1 — exact action]
2. [Step 2 — exact action]
3. [Step 3 — exact action]
4. [Expected result vs actual result]

### Example Request
```
GET /path?param=value HTTP/1.1
Host: target.com
C************]

HTTP/1.1 200 OK
Content-Type: text/html
...
[relevant response body]
```

## Impact

[What an attacker can accomplish. Be realistic and specific.]

## Recommendation

[Specific mitigation steps. Reference frameworks/standards if applicable.]

## References

- [CVE-XXXX-XXXXX](https://nvd.nist.gov/vuln/detail/CVE-XXXX-XXXXX)
- [OWASP Reference](https://owasp.org/...)
- [CWE-XX: Name](https://cwe.mitre.org/data/definitions/XX.html)

---

**Reporter:** [Handle]
**Report Date:** [YYYY-MM-DD]
```
