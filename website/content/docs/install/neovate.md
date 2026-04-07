---
title: "Neovate"
weight: 29
description: "Install the Vulnetix security plugin for Neovate."
---

## Quick Install

```
npx skills add Vulnetix/claude-code-plugin
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

## Verify Installation

Run the dashboard skill to confirm everything is working:

```
/vulnetix:dashboard
```

You should see a vulnerability summary table for your project's dependencies. If you get an authentication error, re-run `vulnetix auth login`.

## Updating

To update to the latest version:

```
npx skills add Vulnetix/claude-code-plugin
```

Running the install command again pulls the latest version and overwrites existing files.

## Uninstall

Remove the plugin by deleting the skills directory:

```bash
rm -rf .neovate/skills
```
