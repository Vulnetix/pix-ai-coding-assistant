---
title: "Updating"
weight: 3
description: "Keep the Vulnetix plugin up to date with the latest hooks, skills, and vulnerability data."
---

How you update depends on how you installed the plugin.

## Marketplace Install

Run a single command inside Claude Code:

```
/plugin update vulnetix
```

Claude Code pulls the latest version from the marketplace and re-registers all hooks and skills automatically.

## Local Clone

Pull the latest changes from the repository:

```bash
cd ~/claude-code-plugin && git pull
```

Then remove and re-add the plugin so Claude Code picks up any new or changed manifests:

```
/plugin remove vulnetix
```

```
/plugin add ~/claude-code-plugin/vulnetix
```

## Verify After Updating

After either method, confirm the update took effect:

```
/plugins
```

The `vulnetix` plugin should appear as **enabled**. Run `/hooks` to confirm all six hooks are still registered.

---

Continue to [Verification](../verification/) for a full post-install checklist.
