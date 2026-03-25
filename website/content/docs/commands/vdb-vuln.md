---
title: vdb-vuln
weight: 1
description: Look up a single vulnerability by ID from the Vulnetix VDB, supporting 78+ identifier formats.
---

The `vdb-vuln` command retrieves detailed information about a single vulnerability from the Vulnetix Vulnerability Database.

## Invocation

```
/vulnetix:vdb-vuln <vuln-id>
```

## Underlying Command

```bash
vulnetix vdb vuln $ARGUMENTS -o json
```

## Accepted Identifier Formats

The command accepts 78+ vulnerability identifier formats, including:

- **Primary:** CVE (e.g., `CVE-2021-44228`), GHSA (e.g., `GHSA-jfh8-3a1q-hjz9`)
- **Language-specific:** PYSEC, GO, RUSTSEC
- **Standards:** EUVD, OSV, GSD, VDB, GCVE
- **Vendor:** SNYK, ZDI, MSCVE, MSRC, TALOS, EDB, WORDFENCE, PATCHSTACK, MFSA, JVNDB, CNVD, BDU, HUNTR
- **Distribution:** RHSA, DSA, DLA, USN, ALSA, RLSA, MGASA, OPENSUSE, FreeBSD, BIT

See the [Vulnerability Identifiers](/docs/reference/vuln-identifiers) reference for the full list.

## Flags

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `-o, --output` | string | `pretty` | Output format: `json` or `pretty` |

## Output

The command parses the JSON response and presents a structured summary including:

- Vulnerability ID and aliases
- Description
- CVSS scores (v2, v3, v4 when available)
- EPSS probability
- CISA KEV status
- Affected products and versions
- References

## Examples

Look up a CVE:

```
/vulnetix:vdb-vuln CVE-2021-44228
```

Look up a GitHub Security Advisory:

```
/vulnetix:vdb-vuln GHSA-jfh8-3a1q-hjz9
```

Look up a Red Hat advisory:

```
/vulnetix:vdb-vuln RHSA-2025:1730
```
