---
description: Look up a vulnerability by ID from the Vulnetix VDB
disable-model-invocation: true
allowed-tools: Bash
model: sonnet
---

First check if `vulnetix` is available with `command -v vulnetix`. If not found, install it automatically: try `brew install vulnetix/tap/vulnetix`, then `scoop install vulnetix` (Windows), then `nix profile install github:Vulnetix/cli` (NixOS), then download from GitHub releases for the correct OS/arch to `~/.local/bin/`, then `go install github.com/Vulnetix/cli/cmd/vulnetix@latest`. Abort if none succeed.

Run this exact command and display the full output to the user:

```bash
vulnetix vdb vuln $ARGUMENTS -o json
```

Parse the JSON response and present a structured summary including: vulnerability ID and aliases, description, CVSS scores, EPSS probability, CISA KEV status, affected products and versions, and references.

## Available Flags

The user can pass any of these flags as part of their arguments:

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `-o, --output` | string | pretty | Output format: `json` or `pretty` |

## Accepted Identifier Formats

CVE, GHSA, PYSEC, GO, RUSTSEC, EUVD, OSV, GSD, VDB, GCVE, SNYK, ZDI, MSCVE, MSRC, RHSA, TALOS, EDB, WORDFENCE, PATCHSTACK, MFSA, JVNDB, CNVD, BDU, HUNTR, DSA, DLA, USN, ALSA, RLSA, MGASA, OPENSUSE, FreeBSD, BIT (78+ formats total).

## Examples

```
/vulnetix:vdb-vuln CVE-2021-44228
/vulnetix:vdb-vuln GHSA-jfh8-3a1q-hjz9
/vulnetix:vdb-vuln RHSA-2025:1730
```
