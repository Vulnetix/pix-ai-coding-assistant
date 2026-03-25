---
title: Vulnerability Context Injection
weight: 6
description: Automatically detects CVE and GHSA identifiers in user messages and injects prior vulnerability context from the project memory.
---

The context injection hook watches every user message for vulnerability identifiers. When it finds a CVE or GHSA ID, it checks the project memory for prior context and injects it into the conversation, giving Claude immediate access to the vulnerability's status, affected package, and decision history.

| Property | Value |
|----------|-------|
| **Event** | `UserPromptSubmit` |
| **Matcher** | -- |
| **Script** | `vuln-context-inject.sh` |
| **Timeout** | 15 seconds |

## Trigger condition

The hook reads `user_prompt` from the JSON input on stdin and applies two regex patterns to find vulnerability identifiers:

| Pattern | Format | Example |
|---------|--------|---------|
| `CVE-\d{4}-\d{4,}` | CVE identifier | CVE-2021-44228 |
| `GHSA-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}` | GitHub Security Advisory | GHSA-rv95-896h-c2vc |

If no IDs are found, the hook exits silently.

### Skill invocation bypass

If the user message contains `/vulnetix:` (indicating they are already invoking a Vulnetix skill), the hook skips processing. This avoids redundant context injection when the user is explicitly running a vulnerability lookup or remediation command.

## Memory lookup

For each detected vulnerability ID, the hook searches `.vulnetix/memory.yaml` for a matching entry and extracts:

- **status** -- the current VEX status
- **package** -- the affected package name
- **choice** -- the current decision (if any)

### Status mapping

The raw VEX status and decision fields are converted to developer-friendly language:

| VEX Status | Decision | Display |
|------------|----------|---------|
| `fixed` | any | Fixed |
| `not_affected` | any | Not affected |
| `under_investigation` | any | Investigating |
| `affected` | `risk-accepted` | Risk accepted |
| `affected` | `deferred` | Fix planned |
| `affected` | other | Vulnerable |

## Output scenarios

### Vulnerability found in memory

When the user mentions a tracked vulnerability:

**User:** "what about CVE-2021-44228"

**Injected context:**
```
Vulnetix context: CVE-2021-44228: Fixed (log4j-core).
```

### Multiple vulnerabilities, mixed status

**User:** "are CVE-2021-44228 and GHSA-rv95-896h-c2vc related?"

**Injected context:**
```
Vulnetix context: CVE-2021-44228: Fixed (log4j-core).
GHSA-rv95-896h-c2vc: Vulnerable (webpack-dev-middleware).
```

### Vulnerability not in memory

When the mentioned ID has no prior record:

**User:** "check CVE-2024-50623"

**Injected context:**
```
Vulnetix: CVE-2024-50623 mentioned -- no prior data in memory.
Run `/vulnetix:vuln CVE-2024-50623` to look it up.
```

### Mix of tracked and untracked

When some IDs are in memory and others are not:

```
Vulnetix context: CVE-2021-44228: Fixed (log4j-core).
Not tracked: CVE-2024-50623 -- run `/vulnetix:vuln <id>` to look up.
```

## How it helps

This hook closes the loop between vulnerability discovery and ongoing development. Instead of requiring developers to remember vulnerability IDs or manually look up prior decisions, the context is surfaced automatically whenever a vulnerability is mentioned in conversation. Claude can then provide informed responses based on the project's actual vulnerability state rather than generic information.
