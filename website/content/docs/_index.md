---
title: Documentation
description: Pix — Vulnetix for coding agents. Three hooks, eighteen skills, five subagents, and where each of them fits.
---

Pix connects your coding agent to Vulnetix VDB: 160 upstream sources — CVE, GHSA,
OSV, vendor advisories and more — aggregated, normalised, and enriched with
exploit intelligence, malware associations and safe upgrade paths.

Three hooks watch the moments that matter, and eighteen skills cover the work that
needs your working tree. **Looking a vulnerability up is not in here** — that is
the [MCP server](https://mcp.vulnetix.com/mcp) and the CLI's own subcommands, so a
question has one answer rather than three competing descriptions of the same job.

Free to start on the [Community tier](https://www.vulnetix.com/features/community). No credential at all still works: reads
succeed, the rate limit is shared, and your agent is told so in plain words rather
than shown an error.

{{< cards >}}
  {{< card link="install" title="Install" icon="download" subtitle="One command wires up every agent on your machine. Support matrix generated from the installer." >}}
  {{< card link="getting-started" title="Getting started" icon="play" subtitle="Prerequisites, credentials, and how to check it is working." >}}
  {{< card link="hooks" title="Hooks" icon="lightning-bolt" subtitle="Three guardrails, one command. Silent when your policy is already satisfied." >}}
  {{< card link="skills" title="Skills" icon="academic-cap" subtitle="Eighteen local procedures — choosing a dependency, tracing a CVE into this repo, applying a fix." >}}
  {{< card link="agents" title="Subagents" icon="chip" subtitle="Five multi-step workflows that run with their own context." >}}
  {{< card link="data-structures" title="Data structures" icon="database" subtitle="What lives in .vulnetix/ — the scan record, capabilities, SBOMs." >}}
  {{< card link="reference" title="Reference" icon="book-open" subtitle="Supported ecosystems, vulnerability identifiers, and integrations." >}}
  {{< card link="troubleshooting" title="Troubleshooting" icon="exclamation-circle" subtitle="Common issues, diagnostics, and fixes." >}}
{{< /cards >}}

## The shape of it

There are two surfaces and they do different jobs.

**MCP is the data surface** — 31 tools, already shaped, no install, reachable from
any client that speaks the protocol.

**The CLI is the local surface**, and the only one that can read a working tree,
edit a manifest, or run with no credentials. A hook is a process rather than an
agent turn, so hooks are always CLI.

Skills sit on top of both and follow one rule: use the MCP tools if the agent has
them, the CLI otherwise. That is written down once, in
[the skill contract](https://github.com/Vulnetix/pix-ai-coding-assistant/blob/main/skills/_lib/contract.md),
and never restated.
