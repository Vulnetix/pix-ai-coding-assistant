---
description: List all known vulnerabilities for a package from the Vulnetix VDB
disable-model-invocation: true
allowed-tools: Bash
model: sonnet
---

Run this exact command and display the full output to the user:

```bash
vulnetix vdb vulns $ARGUMENTS -o json
```

Parse the JSON response and present a table of vulnerabilities including: vulnerability ID, severity, CVSS score, affected version range, fixed version, and description. Show the total count and pagination info.

## Available Flags

The user can pass any of these flags after the package name:

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--limit` | int | 100 | Maximum number of results to return |
| `--offset` | int | 0 | Number of results to skip (for pagination) |
| `-o, --output` | string | pretty | Output format: `json` or `pretty` |

## Examples

```
/vulnetix:vdb-vulns express
/vulnetix:vdb-vulns lodash --limit 20
/vulnetix:vdb-vulns moment --offset 100
```
