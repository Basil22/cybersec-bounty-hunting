# Bug Bounty Tools — Installation & Setup Guide
# WSL (Ubuntu) Environment

## Installed Tools

### Go-Based (compiled from source)
| Tool | Version | Location | Purpose |
|------|---------|----------|---------|
| Go | 1.24.3 | ~/go/bin/go | Compiler for Go tools |
| subfinder | v2.14.0 | ~/go/bin/subfinder | Subdomain enumeration |
| httpx | v1.6.10 | ~/go/bin/httpx | HTTP probing |
| nuclei | v3.8.0 | ~/go/bin/nuclei | Vulnerability scanning |
| gau | v2.2.4 | ~/go/bin/gau | URL discovery (wayback) |
| waybackurls | v0.1.0 | ~/go/bin/waybackurls | Historical URLs |
| ffuf | v2.1.0-dev | ~/go/bin/ffuf | Web fuzzing |

### System Tools
| Tool | Version | Location | Purpose |
|------|---------|----------|---------|
| nmap | 7.98 | /usr/bin/nmap | Port scanning |
| whatweb | 0.0.8 | ~/bugbounty/tools/whatweb | Tech detection |
| Python | 3.14.4 | /usr/bin/python3 | Scripting |
| uv | latest | ~/.local/bin/uv | Python package manager |

## PATH Setup
Source this file before running any tools:
```bash
source ~/bugbounty/tools/path.sh
```

Or make it permanent:
```bash
echo 'source ~/bugbounty/tools/path.sh' >> ~/.bashrc
```

## Updating Tools
```bash
# Update Go tools
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/projectdiscovery/httpx/cmd/httpx@v1.6.10
go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install github.com/lc/gau/v2/cmd/gau@latest
go install github.com/tomnomnom/waybackurls@latest
go install github.com/ffuf/ffuf/v2@latest

# Update nuclei templates
nuclei -update-templates

# Update whatweb
cd /tmp && source whatweb-env/bin/activate && uv pip install --upgrade whatweb
```
