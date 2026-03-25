---
title: Agents
weight: 5
description: Autonomous multi-step workflows that analyze, prioritize, and report on vulnerabilities with minimal user intervention.
---

Agents are autonomous, multi-step workflows that go beyond single-command lookups. They combine multiple VDB queries, repository analysis, and threat intelligence to produce consolidated reports.

Unlike [commands](/docs/commands) (which are single CLI calls) or [skills](/docs/skills) (which perform focused analysis), agents orchestrate many steps across multiple turns to complete a complex task.

## Available Agents

| Agent | Effort | Max Turns | Purpose |
|-------|--------|-----------|---------|
| [Bulk Triage](bulk-triage) | Medium | 15 | Triage multiple vulnerabilities in parallel, prioritize by CWSS score, and produce a consolidated security report |

## How Agents Work

Agents are defined as Claude Code agent prompts with access to a curated set of tools (Bash, Read, Glob, Grep, Edit, Write, WebFetch). When invoked, the agent:

1. Gathers input from the user, hook results, or the memory file
2. Executes multiple VDB queries and repository scans autonomously
3. Synthesizes the results into a structured report
4. Updates `.vulnetix/memory.yaml` with findings

Agents are allowed to run for multiple turns (up to `maxTurns`) and use medium computational effort to balance thoroughness with speed.
