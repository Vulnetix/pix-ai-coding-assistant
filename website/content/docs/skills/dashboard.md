---
title: Dashboard
weight: 1
description: Displays a comprehensive vulnerability status report from .vulnetix/memory.yaml, showing all tracked vulnerabilities grouped by status with suggested next actions.
---

The dashboard skill reads [`.vulnetix/memory.yaml`](/docs/data-structures/memory-yaml) and presents a full vulnerability status report. It is read-only and does not modify any files.

This is the skill suggested by the [session summary](/docs/hooks/session-summary) and [stop reminder](/docs/hooks/stop-reminder) hooks when open vulnerabilities exist.

## Invocation

```
/vulnetix:dashboard
```

No arguments required. The skill reads all state from the memory file.

## What it displays

### Summary header

A count of vulnerabilities by status:

```
Vulnetix Security Dashboard
============================
Open: 4 (2 vulnerable, 2 investigating)
Resolved: 3 (2 fixed, 1 risk-accepted)
Manifests tracked: 2 (last scan: 2024-01-15T10:30:00Z)
```

### Open vulnerabilities table

All vulnerabilities with status `affected` or `under_investigation`, sorted by CWSS priority (P1 first), then severity:

| ID | Package | Severity | Status | Priority | Decision |
|----|---------|----------|--------|----------|----------|
| CVE-2021-44228 | log4j-core | critical | Vulnerable | P1 (87.5) | investigating |
| GHSA-xxxx-yyyy | express | high | Investigating | P2 (62.0) | investigating |

### Resolved vulnerabilities table

All vulnerabilities with status `fixed` or `not_affected`, or decisions of `risk-accepted` or `deferred`:

| ID | Package | Severity | Resolution | Decision | Date |
|----|---------|----------|------------|----------|------|
| CVE-2023-1234 | lodash | high | Fixed | fix-applied | 2024-01-15 |

### Manifest tracking

| Manifest | Ecosystem | Last Scanned | Vulns Found |
|----------|-----------|--------------|-------------|
| package.json | npm | 2024-01-15T10:30:00Z | 3 |
| go.mod | go | 2024-01-15T10:31:00Z | 0 |

### Suggested actions

For each open vulnerability (up to 5), the dashboard suggests the most relevant next step:

- No exploit analysis yet: `/vulnetix:exploits <id>`
- Has CWSS score but no fix: `/vulnetix:fix <id>`
- General: `/vulnetix:remediation <id>`

## Relationship to hooks

The [session summary hook](/docs/hooks/session-summary) displays a one-line status on session start. When open vulnerabilities exist, it suggests running `/vulnetix:dashboard` for the full breakdown.

The [stop reminder hook](/docs/hooks/stop-reminder) nudges about unresolved vulnerabilities when a session ends. When more than 3 are open, it suggests `/vulnetix:dashboard` to see all.

## Example

With 4 open and 2 resolved vulnerabilities tracked, running `/vulnetix:dashboard` produces a full report with tables, priority sorting, and next-step suggestions for each open issue.
