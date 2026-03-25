---
title: Integrations
weight: 3
description: Third-party data sources and GitHub features integrated by the Vulnetix Claude Code Plugin.
---

The Vulnetix Claude Code Plugin pulls data from multiple sources to enrich vulnerability intelligence. This page documents each integration and how it surfaces in the plugin.

## GitHub Dependabot

**What it provides:** Dependabot alert status, automated fix PRs, and dismiss reasons for vulnerabilities in your repository.

**How it works:** When the `gh` CLI is available and authenticated, hooks and the bulk triage agent query the Dependabot alerts API:

```bash
gh api repos/{owner}/{repo}/dependabot/alerts
```

**Fields in memory.yaml:** `dependabot.alert_number`, `dependabot.alert_state`, `dependabot.pr_number`, `dependabot.pr_state`

**Used by:** Pre-commit hook, bulk triage agent, fix skill

## GitHub CodeQL (Code Scanning)

**What it provides:** CWE-matched alerts from CodeQL analysis, providing reachability signals that indicate whether vulnerable code paths are actually exercised.

**How it works:** The plugin queries code scanning alerts and matches them against the CWE identifiers associated with a vulnerability.

**Fields in memory.yaml:** `code_scanning.cwe_match`, `code_scanning.reachable`

**Used by:** Fix skill, bulk triage agent

## GitHub Secret Scanning

**What it provides:** Detection of credential-handling packages, which is relevant when assessing whether a vulnerable package has access to secrets.

**Fields in memory.yaml:** `secret_scanning.relevant`

**Used by:** Fix skill

## CISA KEV (Known Exploited Vulnerabilities)

**What it provides:** The CISA Known Exploited Vulnerabilities catalog identifies vulnerabilities that are confirmed to be actively exploited in the wild. KEV listing is a strong signal for prioritization.

**How it surfaces:** KEV status is included in VDB query results and is a factor in the bulk triage agent's CWSS priority scoring (+15 to exploitability score).

**Used in commands:** `vdb-vuln` output, `vdb-exploits-search --in-kev` flag

## CrowdSec

**What it provides:** Live sighting data and ransomware campaign associations. CrowdSec intelligence indicates whether a vulnerability is being actively targeted in the wild and whether it has been linked to ransomware operations.

**How it surfaces:** Included in the remediation plan output from the V2 API. The vdb-remediation command shows CrowdSec threat intelligence when available.

**Used in commands:** `vdb-remediation` output

## EPSS (Exploit Prediction Scoring System)

**What it provides:** A probability score (0.0 -- 1.0) predicting the likelihood that a vulnerability will be exploited in the next 30 days. EPSS is maintained by FIRST.org.

**How it surfaces:** EPSS scores appear in vulnerability lookups and are used as a sorting and filtering criterion in exploit searches.

**Used in commands:** `vdb-vuln` output, `vdb-exploits-search --min-epss` and `--sort epss` flags

**Used in scoring:** Bulk triage agent uses EPSS x 100 as the base exploitability score

## CVSS (Common Vulnerability Scoring System)

**What it provides:** Standardized severity scoring across v2, v3, and v4 of the CVSS specification. Scores range from 0.0 to 10.0 with severity levels (CRITICAL, HIGH, MEDIUM, LOW).

**How it surfaces:** CVSS scores and vectors are included in all vulnerability lookup results.

**Fields in memory.yaml:** `severity.cvss_score`, `severity.cvss_vector`, `severity.level`

## MITRE ATT&CK

**What it provides:** Technique mapping that classifies vulnerability exploitation methods according to the MITRE ATT&CK framework (tactics, techniques, and procedures).

**How it surfaces:** Used internally by the bulk triage agent when assessing technical impact categories (RCE, privilege escalation, data exfiltration, etc.).

## CWSS (Common Weakness Scoring System)

**What it provides:** A weighted scoring formula that combines technical impact, exploitability, exposure, complexity, and repository relevance into a single priority score.

**How it surfaces:** The bulk triage agent calculates CWSS scores and maps them to priority levels:

| Priority | Score Range | Action |
|----------|-------------|--------|
| P1 | 80+ | Act now |
| P2 | 60 -- 79 | Plan this sprint |
| P3 | 40 -- 59 | Schedule when convenient |
| P4 | Below 40 | Monitor |

**Fields in memory.yaml:** `cwss.score`, `cwss.priority`
