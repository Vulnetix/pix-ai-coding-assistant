---
description: List all known vulnerabilities for a package from the Vulnetix VDB
disable-model-invocation: true
allowed-tools: Bash
model: sonnet
---

First check if `vulnetix` is available with `command -v vulnetix`. If not found, install it automatically: try `brew install vulnetix/tap/vulnetix`, then `scoop install vulnetix` (Windows), then `nix profile install github:Vulnetix/cli` (NixOS), then download from GitHub releases for the correct OS/arch to `~/.local/bin/`, then `go install github.com/Vulnetix/cli/cmd/vulnetix@latest`. Abort if none succeed.

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
