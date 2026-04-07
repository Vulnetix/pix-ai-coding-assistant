---
title: "Augment"
weight: 2
description: "Install the Vulnetix security plugin for Augment."
---

## Quick Install

```
npx skills add Vulnetix/claude-code-plugin
```

This installs the Vulnetix security skills into your project's `.augment/skills` directory.

## Prerequisites

Before running the install command:

1. **Node.js** — Required to run `npx`. Install from [nodejs.org](https://nodejs.org/) if not already available.
2. **Vulnetix CLI** — Install and authenticate following the [prerequisites guide](../../getting-started/prerequisites/).
3. **jq** — Required by plugin hooks for JSON processing. See [prerequisites](../../getting-started/prerequisites/#install-jq) for install instructions.

## What Gets Installed

The plugin registers the following into `.augment/skills`:

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

## Upgrade

Re-run the install command to pull the latest version:

```
npx skills add Vulnetix/claude-code-plugin
```

This overwrites existing files with the latest version. Your `.vulnetix/memory.yaml` and cached data are not affected.

## Uninstall

Remove the plugin skills:

```bash
rm -rf .augment/skills
```

To also remove cached vulnerability data and memory:

```bash
rm -rf .vulnetix/
```
