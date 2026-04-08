---
title: "Tabnine"
weight: 33
description: "Install the Vulnetix security plugin for Tabnine."
---

## Quick Install

```
npx skills add Vulnetix/pix-ai-coding-assistant
```

This installs the Vulnetix security skills into your project's `.tabnine/skills` directory.

## Prerequisites

Before running the install command:

1. **Node.js** — Required to run `npx`. Install from [nodejs.org](https://nodejs.org/) if not already available.
2. **Vulnetix CLI** — Install and authenticate following the [prerequisites guide](../../getting-started/prerequisites/).
3. **jq** — Required by plugin hooks for JSON processing. See [prerequisites](../../getting-started/prerequisites/#install-jq) for install instructions.

## What Gets Installed

The plugin registers the following into `.tabnine/skills`:

| Component | Count | Details |
|-----------|-------|---------|
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
npx skills add Vulnetix/pix-ai-coding-assistant
```

This overwrites existing files with the latest version. Your `.vulnetix/memory.yaml` and cached data are not affected.

## Uninstall

Remove the plugin skills:

```bash
rm -rf .tabnine/skills
```

To also remove cached vulnerability data and memory:

```bash
rm -rf .vulnetix/
```
