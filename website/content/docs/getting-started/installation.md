---
title: "Installation"
weight: 2
description: "Add the Vulnetix plugin to Claude Code from the marketplace or a local clone."
---

There are two ways to install the plugin. The marketplace method is recommended for most users; the local clone method is useful for development or air-gapped environments.

## Option A: Marketplace (Recommended)

First, add the Vulnetix marketplace to Claude Code:

```
/plugin marketplace add Vulnetix/claude-code-plugin
```

Then install the plugin from that marketplace:

```
/plugin install vulnetix@vulnetix-plugins
```

That's it. The plugin registers its hooks, skills, commands, and agents automatically.

## Option B: Local Clone

Clone the repository to a local directory:

```bash
git clone https://github.com/Vulnetix/claude-code-plugin.git ~/claude-code-plugin
```

Point Claude Code at the plugin manifest inside the clone:

```
/plugin add ~/claude-code-plugin/vulnetix
```

## What Gets Installed

Regardless of install method the plugin registers:

- **6 hooks** — pre-commit scan, manifest edit gate, post-install scan, session dashboard, stop reminder, and vuln context inject.
- **6 skills** — `package-search`, `exploits`, `fix`, `vuln`, `exploits-search`, and `remediation`.
- **4 commands** — `vdb-vuln`, `vdb-vulns`, `vdb-exploits-search`, and `vdb-remediation`.
- **1 agent** — `bulk-triage` for parallel vulnerability triage.

---

Next, learn how to keep the plugin current in [Updating](../updating/), or skip ahead to [Verification](../verification/) to confirm everything works.
