---
title: Skills
weight: 3
description: LLM-guided interactive workflows that analyze vulnerabilities, assess risk, and propose remediation using AI.
---

Skills are LLM-guided interactive workflows invoked with `/vulnetix:<skill-name>`. Unlike [commands](/docs/commands) (which are deterministic CLI wrappers that run a subcommand and display output), skills involve **AI analysis** powered by the Claude Sonnet model. They interpret data, assess risk, correlate findings across sources, and produce rich Markdown output with tables and Mermaid diagrams.

Every skill:

- Reads and updates [`.vulnetix/memory.yaml`](/docs/data-structures/memory-yaml) to persist findings across sessions
- Cross-references CycloneDX SBOMs in `.vulnetix/scans/` when available
- Integrates with GitHub Advanced Security (Dependabot, CodeQL, Secret Scanning) when `gh` CLI is authenticated
- Suggests next steps by recommending other skills

## Skill Reference

| Skill | Invocation | Purpose |
|-------|-----------|---------|
| [Package Search](package-search) | `/vulnetix:package-search <name>` | Search packages and assess security risk |
| [Exploit Analysis](exploits) | `/vulnetix:exploits <vuln-id>` | Analyze exploit intelligence and threat model |
| [Fix Intelligence](fix) | `/vulnetix:fix <vuln-id>` | Get fix intelligence and apply remediation |
| [Vulnerability Lookup](vuln) | `/vulnetix:vuln <id-or-package>` | Look up a vulnerability or list package vulns |
| [Exploits Search](exploits-search) | `/vulnetix:exploits-search [flags]` | Search for exploited vulnerabilities |
| [Remediation Planning](remediation) | `/vulnetix:remediation <vuln-id>` | Context-aware remediation plan |

## Skills vs Commands

| | Skills | Commands |
|---|--------|----------|
| **Model** | Claude Sonnet (LLM analysis) | None (deterministic) |
| **Output** | Interpreted assessments, tables, Mermaid diagrams | Raw structured data |
| **Memory** | Reads and updates `.vulnetix/memory.yaml` | No memory interaction |
| **GHAS integration** | Dependabot, CodeQL, Secret Scanning | None |
| **Interactivity** | May ask follow-up questions, propose edits | Display only |
| **Use case** | Risk assessment, remediation planning, threat modeling | Quick data lookups, scripting |

## Invocation

All skills use the colon syntax:

```
/vulnetix:<skill-name> <arguments>
```

For example:

```
/vulnetix:exploits CVE-2021-44228
/vulnetix:package-search express
/vulnetix:vuln lodash
```
