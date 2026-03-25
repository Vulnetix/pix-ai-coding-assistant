---
title: vdb-remediation
weight: 4
description: Get a context-aware remediation plan for a vulnerability from the Vulnetix VDB V2 API.
---

The `vdb-remediation` command retrieves a detailed, context-aware remediation plan for a specific vulnerability. It uses the V2 API to provide registry fixes, source patches, workarounds, CWE guidance, and verification steps.

## Invocation

```
/vulnetix:vdb-remediation <vuln-id> [flags]
```

## Underlying Command

```bash
vulnetix vdb remediation plan $ARGUMENTS -V v2 -o json
```

## Flags

The vulnerability ID is passed as the first argument, followed by any combination of these flags:

| Flag | Type | Description |
|------|------|-------------|
| `--ecosystem` | string | Package ecosystem (`npm`, `pypi`, `maven`, `go`, `cargo`, etc.) |
| `--package-name` | string | Package name |
| `--current-version` | string | Currently installed version (enables version-specific guidance) |
| `--package-manager` | string | Package manager (`npm`, `pip`, `cargo`, `maven`, `gradle`, etc.) |
| `--purl` | string | Package URL (overrides ecosystem + package-name + version) |
| `--container-image` | string | Container image reference (e.g., `node:18-alpine`) |
| `--os` | string | OS identifier (e.g., `ubuntu:22.04`, `debian-11`) |
| `--vendor` | string | Vendor name for CPE matching |
| `--product` | string | Product name for CPE matching |
| `--registry` | string | Registry filter (`npm`, `pypi`, `maven-central`) |
| `--include-guidance` | bool | Include CWE-specific remediation guidance |
| `--include-verification-steps` | bool | Include verification commands per package manager |
| `-o, --output` | string | Output format: `json` or `pretty` |

## Output

The command parses the JSON response and presents a structured remediation plan including:

- Vulnerability summary
- Registry fixes with target versions
- Source fixes with commit details
- Distribution patches
- Workarounds with effectiveness scores
- CWE guidance (when `--include-guidance` is set)
- Verification steps (when `--include-verification-steps` is set)
- CrowdSec threat intelligence (when available)

## Examples

Basic lookup by vulnerability ID:

```
/vulnetix:vdb-remediation CVE-2021-44228
```

With full ecosystem context for targeted guidance:

```
/vulnetix:vdb-remediation CVE-2021-44228 --ecosystem maven --package-name log4j-core --current-version 2.14.1
```

Using a Package URL (combines ecosystem, name, and version):

```
/vulnetix:vdb-remediation CVE-2021-44228 --purl "pkg:maven/org.apache.logging.log4j/log4j-core@2.14.1"
```

With CWE guidance and verification steps:

```
/vulnetix:vdb-remediation CVE-2024-XXXXX --ecosystem npm --include-guidance --include-verification-steps
```

For container and OS-level vulnerabilities:

```
/vulnetix:vdb-remediation CVE-2024-XXXXX --container-image "node:18-alpine" --os ubuntu:22.04
```
