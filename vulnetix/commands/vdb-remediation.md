---
description: Get a context-aware remediation plan for a vulnerability from the Vulnetix VDB V2 API
disable-model-invocation: true
allowed-tools: Bash
model: sonnet
---

Run this exact command and display the full output to the user:

```bash
vulnetix vdb remediation plan $ARGUMENTS -V v2 -o json
```

Parse the JSON response and present a structured remediation plan including: vulnerability summary, registry fixes with versions, source fixes with commit details, distribution patches, workarounds with effectiveness scores, CWE guidance, verification steps, and CrowdSec threat intelligence if available.

## Available Flags

The user passes the vuln ID as the first argument, followed by any of these flags:

| Flag | Type | Description |
|------|------|-------------|
| `--ecosystem` | string | Package ecosystem (npm, pypi, maven, go, cargo, etc.) |
| `--package-name` | string | Package name |
| `--current-version` | string | Currently installed version (enables version-specific guidance) |
| `--package-manager` | string | Package manager (npm, pip, cargo, maven, gradle, etc.) |
| `--purl` | string | Package URL (overrides ecosystem + package-name + version) |
| `--container-image` | string | Container image reference (e.g., node:18-alpine) |
| `--os` | string | OS identifier (e.g., ubuntu:22.04, debian-11) |
| `--vendor` | string | Vendor name for CPE matching |
| `--product` | string | Product name for CPE matching |
| `--registry` | string | Registry filter (npm, pypi, maven-central) |
| `--include-guidance` | bool | Include CWE-specific remediation guidance |
| `--include-verification-steps` | bool | Include verification commands per package manager |
| `-o, --output` | string | Output format: `json` or `pretty` |

## Examples

```
/vulnetix:vdb-remediation CVE-2021-44228
/vulnetix:vdb-remediation CVE-2021-44228 --ecosystem maven --package-name log4j-core --current-version 2.14.1
/vulnetix:vdb-remediation CVE-2021-44228 --purl "pkg:maven/org.apache.logging.log4j/log4j-core@2.14.1"
/vulnetix:vdb-remediation CVE-2024-XXXXX --ecosystem npm --include-guidance --include-verification-steps
/vulnetix:vdb-remediation CVE-2024-XXXXX --container-image "node:18-alpine" --os ubuntu:22.04
```
