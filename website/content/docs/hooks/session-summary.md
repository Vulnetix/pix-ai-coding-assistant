---
title: Session Summary
weight: 4
description: Displays a vulnerability status dashboard when a new Claude Code session starts, summarizing open issues and tracked manifests.
---

The session summary hook fires once at the start of every Claude Code session. It reads the project's vulnerability memory and provides a quick status overview so you always know where things stand.

| Property | Value |
|----------|-------|
| **Event** | `SessionStart` |
| **Matcher** | -- |
| **Script** | `session-summary.sh` |
| **Timeout** | 10 seconds |

## Trigger condition

This hook fires automatically on every `SessionStart` event. There is no matcher -- it runs unconditionally. If `.vulnetix/memory.yaml` does not exist, the hook exits silently without producing any output.

## What it reads

The hook parses `.vulnetix/memory.yaml` using grep to count entries by category:

### Vulnerability statuses

| Status | Meaning |
|--------|---------|
| `affected` | Confirmed vulnerable, no resolution yet |
| `under_investigation` | Discovered, analysis in progress |
| `fixed` | Remediated |
| `not_affected` | Determined to not impact this project |

### Decision types

| Decision | Meaning |
|----------|---------|
| `risk-accepted` | Acknowledged and accepted |
| `deferred` | Scheduled for future remediation |

### Manifest metadata

- **Last scan timestamp** -- the most recent `last_scanned` value from the manifests section
- **Manifest count** -- number of manifests with `scan_source` entries

## Output logic

The hook only produces output when there is meaningful data to report (at least one vulnerability or one tracked manifest). It calculates "open" vulnerabilities as the sum of `affected` and `under_investigation` counts.

If open vulnerabilities exist, the message ends with a suggestion to run `/vulnetix:dashboard` for a full breakdown.

## Example output

With active vulnerabilities:

```
Vulnetix security status: 4 open (2 vulnerable, 2 investigating),
1 fixed, 1 risk-accepted. 3 manifests tracked
(last scan: 2024-01-15T10:30:00Z). Run /vulnetix:dashboard for details.
```

With no open vulnerabilities:

```
Vulnetix security status: 3 fixed, 1 risk-accepted.
2 manifests tracked (last scan: 2024-01-15T10:30:00Z).
```

## Dependencies

This hook works with or without jq. When jq is available, it uses `jq -n` to construct the JSON output. Without jq, it falls back to string interpolation. This makes the session summary the most resilient hook -- it will produce output even in minimal environments.
