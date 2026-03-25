---
title: Bulk Triage
weight: 1
description: Triage multiple vulnerabilities in parallel, analyze exploit intelligence, prioritize by CWSS score, and produce a consolidated security report.
---

The Bulk Triage agent analyzes multiple vulnerabilities in a single invocation, scoring each by exploitability and repository impact, then producing a prioritized triage report.

## Configuration

| Property | Value |
|----------|-------|
| **Effort** | Medium |
| **Max Turns** | 15 |
| **Model** | Sonnet |
| **Allowed Tools** | Bash, Read, Glob, Grep, Edit, Write, WebFetch |

## Input Sources

The agent accepts vulnerability IDs from three sources:

1. **Pre-commit hook results** -- vulnerabilities surfaced by the [Pre-Commit Scan](/docs/hooks/pre-commit-scan) hook
2. **User-provided vuln IDs** -- a list of CVE, GHSA, or other identifiers passed directly
3. **Memory file entries** -- vulnerabilities in `.vulnetix/memory.yaml` with `status: affected` or `status: under_investigation` that do not yet have a CWSS priority score

If no specific IDs are provided, the agent reads the memory file and collects all qualifying entries automatically.

## Workflow

### Step 1: Gather Vulnerability IDs

The agent collects all vuln IDs to analyze. If more than 20 vulnerabilities are found, the agent focuses on the top 20 by estimated severity and notes the remainder.

### Step 2: Analyze Each Vulnerability

For each ID, the agent runs two VDB queries:

```bash
vulnetix vdb vuln "<VULN_ID>" -o json
vulnetix vdb exploits "<VULN_ID>" -o json
```

From these, it extracts:

- **Severity** -- CVSS score and vector
- **EPSS** -- exploit prediction probability
- **CISA KEV** -- whether the vulnerability is in the Known Exploited Vulnerabilities catalog
- **Exploit count** -- number of public exploits (PoCs, Metasploit modules, etc.)
- **Affected package** -- package name and vulnerable version range

Queries are batched in parallel where possible. If a query fails for one vulnerability, the agent skips it and notes the failure rather than stopping the entire triage.

### Step 3: Check Repository Impact

For each vulnerability, the agent determines whether the affected package exists in the repository:

1. Uses **Glob** to find manifest files (`package.json`, `requirements.txt`, `go.mod`, etc.)
2. Uses **Grep** to search for the affected package name in manifests
3. Classifies as: direct dependency, transitive dependency, or not found

### Step 4: Calculate CWSS Priority

Each vulnerability is scored using a weighted formula:

| Factor | Weight | Scoring |
|--------|--------|---------|
| Technical Impact | 25% | RCE = 100, Privilege Escalation = 90, Data Exfiltration = 85, Tampering = 70, DoS = 40 |
| Exploitability | 25% | EPSS x 100, +20 if Metasploit, +15 if verified PoC, +15 if CISA KEV |
| Exposure | 15% | Network + public = 100, Network + internal = 70, Adjacent = 50, Local = 30 |
| Complexity | 15% | Low + no auth + no interaction = 100, reduced for complexity/auth/interaction requirements |
| Repo Relevance | 20% | Direct dep + reachable = 100, Direct + unknown = 70, Transitive = 40, Not found = 0 |

The weighted sum maps to a priority level:

| Priority | Score Range | Meaning |
|----------|-------------|---------|
| **P1** | 80 and above | Act now |
| **P2** | 60 -- 79 | Plan this sprint |
| **P3** | 40 -- 59 | Schedule when convenient |
| **P4** | Below 40 | Monitor, no action needed |

### Step 5: Check Dependabot Context

If the `gh` CLI is available and authenticated, the agent queries Dependabot for each vulnerability:

```bash
gh api repos/{owner}/{repo}/dependabot/alerts \
  --jq '[.[] | select(.security_advisory.cve_id == "<VULN_ID>" or .security_advisory.ghsa_id == "<VULN_ID>")] | first'
```

This surfaces any open alerts or existing pull requests.

### Step 6: Produce Triage Report

The agent generates a consolidated markdown report sorted by priority (P1 first):

```
## Vulnerability Triage Report

Analyzed: N vulnerabilities | Date: YYYY-MM-DD

### P1 -- Act Now

| Vuln ID | Package | Severity | EPSS | Exploits | In Repo? | Dependabot |
|---------|---------|----------|------|----------|----------|------------|
| CVE-... | express | Critical | 0.97 | 5 (Metasploit) | Yes (direct) | Alert #42 open |

**Recommended action:** `/vulnetix:fix CVE-...`

### P2 -- Plan This Sprint

| ... |

### P3 -- Schedule It

| ... |

### P4 -- Track It

| ... |

### Summary

- P1: N (immediate action required)
- P2: N (plan for this sprint)
- P3: N (schedule when convenient)
- P4: N (monitor, no action needed)
```

### Step 7: Update Memory File

For each analyzed vulnerability, the agent updates `.vulnetix/memory.yaml`:

- Sets or updates the `severity` field
- Adds a `history` entry with `event: bulk-triage` and a summary of findings
- Does **not** change `status` or `decision` -- those require user input
- If an entry does not yet exist, creates one with `status: under_investigation`

## Guidelines

- Vulnerabilities are processed in parallel where possible to minimize latency
- Failed VDB queries are skipped and noted, not fatal to the overall triage
- The report is kept concise -- one line per vulnerability in the tables, with details available via `/vulnetix:exploits`
- The agent uses developer-friendly language throughout (no raw VEX or ATT&CK terminology)
- When there are more than 20 vulnerabilities, the agent triages the top 20 by estimated severity and lists the remainder separately
