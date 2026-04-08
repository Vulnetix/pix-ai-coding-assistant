---
title: "Cline"
weight: 8
description: "Install the Vulnetix security plugin for Cline."
---

## Quick Install

```
npx skills add Vulnetix/pix-ai-coding-assistant
```

This installs the Vulnetix security skills into your project's `.cline/skills` directory.

## Prerequisites

Before running the install command:

1. **Node.js** — Required to run `npx`. Install from [nodejs.org](https://nodejs.org/) if not already available.
2. **Vulnetix CLI** — Install and authenticate following the [prerequisites guide](../../getting-started/prerequisites/).
3. **jq** — Required by plugin hooks for JSON processing. See [prerequisites](../../getting-started/prerequisites/#install-jq) for install instructions.

## What Gets Installed

The plugin registers the following into `.cline/skills`:

| Component | Count | Details |
|-----------|-------|---------|
| **Hooks** | 2 | Pre-tool-use dispatcher (commit scan + manifest gate), post-tool-use dispatcher (install scan) |
| **Skills** | 6 | `package-search`, `exploits`, `fix`, `vuln`, `exploits-search`, `remediation` |
| **Commands** | 4 | `vdb-vuln`, `vdb-vulns`, `vdb-exploits-search`, `vdb-remediation` |
| **Agents** | 1 | `bulk-triage` — parallel vulnerability triage and prioritization |

## Native Hooks

Cline supports hooks natively via executable scripts. The plugin ships dispatcher scripts in `hooks/cline/` that route to the shared Vulnetix hook scripts based on tool name.

The following events are wired up:

| Hook | Event | Tools Matched | Action |
|------|-------|---------------|--------|
| Pre-Commit Scan | PreToolUse | execute_command, terminal, bash, shell | Scan before git commit |
| Manifest Edit Gate | PreToolUse | write_to_file, replace_in_file, insert_code_block | Gate manifest edits |
| Post-Install Scan | PostToolUse | execute_command, terminal, bash, shell | SBOM after npm/pip/go install |

After install, copy the dispatcher scripts to your project:

```bash
cp hooks/cline/PreToolUse .clinerules/hooks/PreToolUse
cp hooks/cline/PostToolUse .clinerules/hooks/PostToolUse
chmod +x .clinerules/hooks/PreToolUse .clinerules/hooks/PostToolUse
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
rm -rf .cline/skills
```

To also remove cached vulnerability data and memory:

```bash
rm -rf .vulnetix/
```
