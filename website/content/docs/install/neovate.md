---
title: "Neovate"
weight: 29
description: "Install the Vulnetix security plugin for Neovate."
---

## Quick Install

```
npx skills add Vulnetix/pix-ai-coding-assistant
```

This installs the Vulnetix security skills into your project's `.neovate/skills` directory.

## Prerequisites

Before running the install command:

1. **Node.js** — Required to run `npx`. Install from [nodejs.org](https://nodejs.org/) if not already available.
2. **Vulnetix CLI** — Install and authenticate following the [prerequisites guide](../../getting-started/prerequisites/).
3. **jq** — Required by plugin hooks for JSON processing. See [prerequisites](../../getting-started/prerequisites/#install-jq) for install instructions.

## What Gets Installed

The plugin registers the following into `.neovate/skills`:

| Component | Count | Details |
|-----------|-------|---------|
| **Hooks** | 6 | Pre-commit scan, manifest edit gate, post-install scan, session dashboard, stop reminder, vuln context inject |
| **Skills** | 6 | `package-search`, `exploits`, `fix`, `vuln`, `exploits-search`, `remediation` |
| **Commands** | 4 | `vdb-vuln`, `vdb-vulns`, `vdb-exploits-search`, `vdb-remediation` |
| **Agents** | 1 | `bulk-triage` — parallel vulnerability triage and prioritization |

## Native Hooks

Neovate uses a TypeScript plugin system. The plugin ships `neovate-plugin.ts` which registers hooks via Neovate's extension API, wrapping the shared Vulnetix bash scripts.

The following lifecycle events are wired up:

| Hook | Extension Point | Action |
|------|----------------|--------|
| Pre-Commit Scan | onBeforeToolCall | Block git commit if vulns found |
| Manifest Edit Gate | onBeforeToolCall | Gate manifest edits |
| Post-Install Scan | onAfterToolCall | SBOM after package install |
| Session Summary | onSessionStart | Vulnerability dashboard |
| Context Inject | onBeforePrompt | Inject vuln context |
| Stop Reminder | onSessionEnd | Remind about unresolved vulns |

After install, register the plugin in `.neovate/plugins/`:

```bash
cp hooks/ts/neovate-plugin.ts .neovate/plugins/vulnetix.ts
```

See [Hooks documentation](../../hooks/) for details on each hook.

## Verify Installation

Run the dashboard skill to confirm everything is working:

```
/vulnetix:dashboard
```

You should see a vulnerability summary table for your project's dependencies. If you get an authentication error, re-run `vulnetix auth login`.

## Upgrade

Re-run the install command to pull the latest version:

```
npx skills add Vulnetix/pix-ai-coding-assistant
```

This overwrites existing files with the latest version. Your `.vulnetix/memory.yaml` and cached data are not affected.

## Uninstall

Remove the plugin skills:

```bash
rm -rf .neovate/skills
```

To also remove cached vulnerability data and memory:

```bash
rm -rf .vulnetix/
```
