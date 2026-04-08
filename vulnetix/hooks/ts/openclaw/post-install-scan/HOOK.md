---
name: post-install-scan
description: SBOM scan after package install commands
event: command
---

Runs after shell commands matching package install patterns to generate an updated SBOM and scan for new vulnerabilities.
