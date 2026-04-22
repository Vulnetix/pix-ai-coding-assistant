---
title: "Claude Code"
weight: 1
description: "Install the Vulnetix security plugin for Claude Code."
---

## Via GitHub CLI (Preview)

GitHub CLI v2.90.0+ supports installing individual skills directly via `gh skill`:

```
gh skill install Vulnetix/pix-ai-coding-assistant dashboard --agent claude-code
gh skill install Vulnetix/pix-ai-coding-assistant exploits --agent claude-code
gh skill install Vulnetix/pix-ai-coding-assistant exploits-search --agent claude-code
gh skill install Vulnetix/pix-ai-coding-assistant fix --agent claude-code
gh skill install Vulnetix/pix-ai-coding-assistant package-search --agent claude-code
gh skill install Vulnetix/pix-ai-coding-assistant remediation --agent claude-code
gh skill install Vulnetix/pix-ai-coding-assistant vuln --agent claude-code
```

For the complete plugin (hooks, commands, and bulk-triage agent), use the Marketplace method below. Keep `gh skill`-installed skills current with `gh skill update`.

> `gh skill` is in preview. See [GitHub CLI documentation](https://cli.github.com/manual/gh_skill) for the full reference.

## Install via Marketplace (Recommended)

Add the Vulnetix marketplace to Claude Code:

```
/plugin marketplace add Vulnetix/pix-ai-coding-assistant
```

Then install the plugin:

```
/plugin install vulnetix@vulnetix-plugins
```

The plugin registers its hooks, skills, commands, and agents automatically.

## Install via Local Clone

Clone the repository to a local directory:

```bash
git clone https://github.com/Vulnetix/pix-ai-coding-assistant.git ~/pix-ai-coding-assistant
```

Point Claude Code at the plugin manifest:

```
/plugin add ~/pix-ai-coding-assistant/vulnetix
```

## Prerequisites

Before installing:

1. **Vulnetix CLI** — Install and authenticate following the [prerequisites guide](../../getting-started/prerequisites/).
2. **jq** — Required by plugin hooks for JSON processing. See [prerequisites](../../getting-started/prerequisites/#install-jq) for install instructions.

## What Gets Installed

| Component | Count | Details |
|-----------|-------|---------|
| **Hooks** | 6 | Pre-commit scan, manifest edit gate, post-install scan, session dashboard, stop reminder, vuln context inject |
| **Skills** | 6 | `package-search`, `exploits`, `fix`, `vuln`, `exploits-search`, `remediation` |
| **Commands** | 4 | `vdb-vuln`, `vdb-vulns`, `vdb-exploits-search`, `vdb-remediation` |
| **Agents** | 1 | `bulk-triage` — parallel vulnerability triage and prioritization |

## Verify Installation

Check the plugin is enabled:

```
/plugins
```

The output should list `vulnetix` with a status of **enabled**. Then run a skill to confirm API access:

```
/vulnetix:dashboard
```

You should see a vulnerability summary table for your project's dependencies. If you get an authentication error, re-run `vulnetix auth login`.

## Upgrade

Re-run the marketplace install to pull the latest version:

```
/plugin install vulnetix@vulnetix-plugins
```

Or if using a local clone:

```bash
cd ~/pix-ai-coding-assistant && git pull
```

Your `.vulnetix/memory.yaml` and cached data are not affected.

## Uninstall

Remove the plugin from Claude Code:

```
/plugin remove vulnetix
```

To also remove cached vulnerability data and memory:

```bash
rm -rf .vulnetix/
```
