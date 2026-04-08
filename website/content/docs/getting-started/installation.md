---
title: "Installation"
weight: 2
description: "Add the Vulnetix security plugin to your AI coding agent."
---

Install the Vulnetix security plugin with a single command:

```
npx skills add Vulnetix/pix-ai-coding-assistant
```

This works with any supported agent. Skills are installed into the correct directory automatically.

For agent-specific instructions, see the [Install](/docs/install/) section — it covers all 32 supported agents with full setup details.

## What Gets Installed

The plugin registers:

- **6 hooks** — pre-commit scan, manifest edit gate, post-install scan, session dashboard, stop reminder, and vuln context inject.
- **6 skills** — `package-search`, `exploits`, `fix`, `vuln`, `exploits-search`, and `remediation`.
- **4 commands** — `vdb-vuln`, `vdb-vulns`, `vdb-exploits-search`, and `vdb-remediation`.
- **1 agent** — `bulk-triage` for parallel vulnerability triage.

---

Next, learn how to keep the plugin current in [Updating](../updating/), or skip ahead to [Verification](../verification/) to confirm everything works.
