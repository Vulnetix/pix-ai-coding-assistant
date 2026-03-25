---
title: Commands
weight: 4
description: Deterministic CLI wrappers that run vulnetix vdb subcommands directly with no LLM analysis.
---

Commands are thin, deterministic wrappers around `vulnetix vdb` subcommands. Unlike [skills](/docs/skills) or [agents](/docs/agents), commands involve **no LLM analysis** -- they execute the CLI, capture the JSON output, and display it in a structured format.

Use commands when you want raw VDB data without interpretation, or when you need to pipe exact output into another workflow.

## Command Reference

| Command | Wraps | Purpose |
|---------|-------|---------|
| [vdb-vuln](vdb-vuln) | `vulnetix vdb vuln` | Look up a vulnerability by ID |
| [vdb-vulns](vdb-vulns) | `vulnetix vdb vulns` | List vulnerabilities for a package |
| [vdb-exploits-search](vdb-exploits-search) | `vulnetix vdb exploits search` | Search for exploited vulnerabilities |
| [vdb-remediation](vdb-remediation) | `vulnetix vdb remediation plan -V v2` | Get a remediation plan |

## Invocation

All commands use the colon syntax:

```
/vulnetix:<command-name> <arguments>
```

For example:

```
/vulnetix:vdb-vuln CVE-2021-44228
```

Commands are marked `disable-model-invocation: true`, meaning Claude Code will never call them autonomously -- they only run when you invoke them explicitly.

## Output

Every command appends `-o json` to the underlying CLI call and parses the JSON response into a human-readable summary. The raw JSON is always available in the command output if you need it for scripting or further processing.
