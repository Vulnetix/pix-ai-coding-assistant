---
title: vdb-vulns
weight: 2
description: List all known vulnerabilities for a specific package from the Vulnetix VDB with pagination support.
---

The `vdb-vulns` command lists all known vulnerabilities for a given package from the Vulnetix Vulnerability Database.

## Invocation

```
/vulnetix:vdb-vulns <package-name> [flags]
```

## Underlying Command

```bash
vulnetix vdb vulns $ARGUMENTS -o json
```

## Flags

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--limit` | int | `100` | Maximum number of results to return |
| `--offset` | int | `0` | Number of results to skip (for pagination) |
| `-o, --output` | string | `pretty` | Output format: `json` or `pretty` |

## Output

The command parses the JSON response and presents a table of vulnerabilities including:

- Vulnerability ID
- Severity
- CVSS score
- Affected version range
- Fixed version
- Description

Total count and pagination info are displayed alongside the results.

## Examples

List all vulnerabilities for a package:

```
/vulnetix:vdb-vulns express
```

Limit results to 20:

```
/vulnetix:vdb-vulns lodash --limit 20
```

Paginate through results:

```
/vulnetix:vdb-vulns moment --offset 100
```
