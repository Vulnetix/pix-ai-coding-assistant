---
title: Vulnerability Lookup
weight: 4
description: Look up a vulnerability by ID for detailed intelligence, or query a package name to list all its known vulnerabilities.
---

The Vulnerability Lookup skill operates in two modes depending on the argument:

- **Vuln ID mode** -- retrieves detailed vulnerability intelligence and assesses repository impact
- **Package mode** -- lists all known vulnerabilities for a package and identifies which ones affect your installed version

This skill **does not modify application code** -- it only updates `.vulnetix/memory.yaml` to track findings. Use [`/vulnetix:fix`](fix) for remediation, [`/vulnetix:exploits`](exploits) for exploit analysis, or [`/vulnetix:remediation`](remediation) for a context-aware remediation plan.

## Invocation

```
/vulnetix:vuln <vuln-id or package-name>
```

For example:

```
/vulnetix:vuln CVE-2021-44228
/vulnetix:vuln express
```

## Argument Detection

The skill auto-detects the mode from the argument:

- **Vuln ID patterns** -- `CVE-*`, `GHSA-*`, `PYSEC-*`, `GO-*`, `RUSTSEC-*`, `EUVD-*`, `OSV-*`, `GSD-*`, `VDB-*`, `GCVE-*`, `SNYK-*`, `ZDI-*`, `MSCVE-*`, `MSRC-*`, `RHSA-*`, `TALOS-*`, `EDB-*`, `WORDFENCE-*`, `PATCHSTACK-*`, `MFSA*`, `JVNDB-*`, `CNVD-*`, `BDU:*`, `HUNTR-*`, `DSA-*`, `DLA-*`, `USN-*`, `ALSA-*`, `RLSA-*`, `MGASA-*`, `OPENSUSE-*`, `FreeBSD-*`, `BIT-*`, and more
- **Package name** -- anything that does not match a vuln ID pattern

The VDB accepts **78+ identifier formats** in total. If ambiguous, vuln ID mode is preferred. If the vuln lookup returns empty, the skill falls back to package mode automatically.

## Vuln ID Mode

### Workflow

1. **Load memory** -- reads `.vulnetix/memory.yaml` and displays any prior state for the vuln ID or its aliases
2. **Fetch vulnerability data** -- `vulnetix vdb vuln <id> -o json`
3. **Enrich with metrics** -- `vulnetix vdb metrics <id> -o json` for detailed CVSS v2/v3/v4, EPSS, and other scoring data
4. **Analyze repository impact** -- scans manifest and lockfiles, searches for affected packages, determines installed version and dependency relationship, cross-references SBOMs
5. **Present structured summary**
6. **Update memory** -- creates or merges the entry (does not change status or decision)

### Output

**Identity:**

```
CVE-2021-44228 (GHSA-jfh8-c2jp-5v3q)
Apache Log4j2 JNDI injection allows remote code execution
Published: 2021-12-09  |  Modified: 2024-01-15
```

**Severity Table:**

| Metric | Score | Vector |
|--------|-------|--------|
| CVSS v3.1 | 10.0 (Critical) | AV:N/AC:L/PR:N/UI:N/S:C/C:H/I:H/A:H |
| CVSS v4.0 | 10.0 (Critical) | ... |
| EPSS | 0.97 (97% chance of exploitation within 30 days) | -- |
| CISA KEV | Listed (deadline: 2021-12-24) | -- |

**Affected Packages:**

| Package | Ecosystem | Vulnerable Range | Fixed In |
|---------|-----------|-----------------|----------|
| log4j-core | maven | < 2.17.1 | 2.17.1 |

**Repository Impact:**

| Package | Installed Version | Source | Affected? | Relationship |
|---------|------------------|--------|-----------|-------------|
| log4j-core | 2.14.1 | lockfile: pom.xml | Yes (in range) | Direct |

### Next Steps

After presenting the summary, the skill suggests:

- `/vulnetix:exploits <vuln-id>` -- for exploit intelligence and threat modeling
- `/vulnetix:fix <vuln-id>` -- for fix intelligence and manifest edits
- `/vulnetix:remediation <vuln-id>` -- for a context-aware remediation plan
- `/vulnetix:exploits-search --ecosystem <eco>` -- to discover related exploited vulnerabilities

## Package Mode

### Workflow

1. **Load memory** -- reads `.vulnetix/memory.yaml` and displays known history for the queried package
2. **Detect ecosystems** -- scans for manifest files to determine repository ecosystems
3. **Detect installed version** -- resolves the current version using the 4-tier chain (user-supplied, lockfile, manifest, installed artifacts)
4. **Fetch vulnerabilities** -- `vulnetix vdb vulns <package> -o json`
5. **Filter and enrich** -- discards vulns from ecosystems not in the repo, cross-references with memory for prior statuses, determines "Affects You?" by comparing installed version against each vulnerable range
6. **Present vulnerability list**
7. **Update memory** -- creates stub entries only for vulns that affect the installed version

### Output

```
Vulnerabilities for express@4.17.1 (from lockfile: package-lock.json)
Total: 12 known vulnerabilities (3 affect your version)
```

| # | ID | Severity | Affects You? | Fixed In | Status | EPSS |
|---|-----|----------|-------------|----------|--------|------|
| 1 | CVE-2024-XXXXX | critical | Yes | 4.18.3 | -- | 0.45 |
| 2 | CVE-2023-YYYYY | high | Yes | 4.17.3 | Fixed | 0.12 |
| 3 | CVE-2022-ZZZZZ | medium | No (>=4.17) | 4.17.0 | -- | 0.03 |

**Summary:** `3 of 12 affect your version -- 1 critical, 1 high, 1 medium`

### Pagination

Results support pagination through natural language:

- "first 20" or "top 20" -- limits to 20 results
- "next page" or "page 3" -- advances the offset
- "all" -- fetches up to 500 results

## Memory Updates

- **Vuln ID mode** -- creates or merges the entry with `status: under_investigation` if new. Updates `severity` and `safe_harbour` if newer data is available. Does not change `status` or `decision`.
- **Package mode** -- creates minimal stub entries for newly discovered vulns that affect the installed version. Existing entries are not modified beyond severity updates.

## Example: Vuln ID Mode

```
/vulnetix:vuln CVE-2021-44228
```

Fetches detailed intelligence for Log4Shell, enriches with CVSS 10.0 and EPSS 0.97, finds `log4j-core@2.14.1` in the repository, and suggests running `/vulnetix:exploits` or `/vulnetix:fix` as next steps.

## Example: Package Mode

```
/vulnetix:vuln express
```

Detects npm as the repository ecosystem, finds `express@4.17.1` from the lockfile, lists 12 known vulnerabilities with 3 affecting the installed version, and recommends `/vulnetix:fix` for the critical one.
