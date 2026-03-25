---
title: Stop Reminder
weight: 5
description: Reminds about unresolved vulnerabilities when a Claude Code session ends, showing up to three open vuln IDs with suggested next actions.
---

The stop reminder hook fires when Claude Code is about to end a session. It checks for unresolved vulnerabilities and provides a brief nudge so open issues are not forgotten between sessions.

| Property | Value |
|----------|-------|
| **Event** | `Stop` |
| **Matcher** | -- |
| **Script** | `stop-reminder.sh` |
| **Timeout** | 10 seconds |

## Trigger condition

This hook fires on every `Stop` event with no matcher filter. If `.vulnetix/memory.yaml` does not exist, or if there are no unresolved vulnerabilities, the hook exits silently.

## What it checks

The hook uses awk to scan `.vulnetix/memory.yaml` for vulnerability entries whose status is `affected` or `under_investigation`. These are the two VEX statuses that represent unresolved issues:

- **affected** -- confirmed vulnerable, not yet remediated
- **under_investigation** -- discovered but analysis is incomplete

Vulnerabilities with status `fixed` or `not_affected`, or decisions of `risk-accepted` or `deferred`, are considered resolved and do not trigger the reminder.

## Output format

### Single vulnerability

When exactly one vulnerability is unresolved:

```
Reminder: CVE-2024-29041 is still unresolved.
Run `/vulnetix:fix CVE-2024-29041` to see remediation options.
```

### Multiple vulnerabilities

When more than one vulnerability is unresolved, the hook shows up to 3 IDs:

```
Reminder: 4 vulnerabilities still unresolved.
CVE-2024-29041, GHSA-rv95-896h-c2vc, CVE-2024-28849.
Run `/vulnetix:dashboard` to see all.
```

The trailing message suggesting `/vulnetix:dashboard` only appears when there are more than 3 open vulnerabilities.

## Dependencies

Like the session summary hook, the stop reminder works with or without jq, falling back to string interpolation when jq is unavailable.
