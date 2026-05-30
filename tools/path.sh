#!/bin/bash
# Bug Bounty Tools PATH Setup
# Source this file: source ~/bugbounty/tools/path.sh
# Or add to ~/.bashrc: echo 'source ~/bugbounty/tools/path.sh' >> ~/.bashrc

export PATH=$HOME/go/bin:$PATH
export PATH=$HOME/bugbounty/tools:$PATH
export GOPATH=$HOME/go
export GOROOT=$HOME/go

echo "Bug bounty tools loaded:"
echo "  subfinder, httpx, nuclei, gau, waybackurls, ffuf, nmap, whatweb"
