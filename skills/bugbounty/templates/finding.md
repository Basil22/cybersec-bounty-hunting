# Finding Template (JSON)

```json
{
  "id": "FIND-001",
  "title": "Descriptive vulnerability title",
  "severity": "High",
  "cvss": 7.5,
  "cvss_vector": "CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N",
  "cwe": "CWE-200",
  "cwe_url": "https://cwe.mitre.org/data/definitions/200.html",
  "target": "example.com",
  "url": "https://example.com/vulnerable-endpoint",
  "parameter": "q",
  "method": "GET",
  "type": "information-disclosure",
  "verified": true,
  "evidence": {
    "description": "curl output showing sensitive data exposure",
    "curl_command": "curl -s 'https://example.com/endpoint' | head -20",
    "response_snippet": "[truncated actual response]",
    "tool": "nuclei",
    "tool_output": "[relevant nuclei finding]"
  },
  "description": "The application at https://example.com/endpoint exposes sensitive information including database credentials without authentication.",
  "impact": "An unauthenticated attacker can obtain database credentials, potentially leading to unauthorized database access and data exfiltration.",
  "recommendation": "Remove debug endpoints from production. Implement authentication middleware on all /api/* routes. Use environment variables for secrets with a .env file excluded from web root.",
  "steps_to_reproduce": [
    "Send GET request to https://example.com/endpoint",
    "Observe response containing sensitive data",
    "No authentication required"
  ],
  "references": [
    "https://cwe.mitre.org/data/definitions/200.html",
    "https://owasp.org/www-project-top-ten/2017/A3_2017-Sensitive_Data_Exposure"
  ],
  "discovered_by": "ANALYZER agent",
  "discovery_date": "2026-05-29",
  "report_generated": false,
  "platform_submitted": null,
  "bounty_awarded": null
}
```
