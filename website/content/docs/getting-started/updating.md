---
title: "Updating"
weight: 3
description: "Keep the Vulnetix plugin up to date with the latest hooks, skills, and vulnerability data."
---

How you update depends on how you installed the plugin.

## npx skills (All Agents)

If you installed with `npx skills add`, run the same command again:

```
npx skills add Vulnetix/claude-code-plugin
```

This pulls the latest version and overwrites existing files in your agent's skills directory.

## Claude Code Marketplace

Run a single command inside Claude Code:

```
/plugin update vulnetix
```

Claude Code pulls the latest version from the marketplace and re-registers all hooks and skills automatically.

## Claude Code Local Clone

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

Run a skill to confirm the update took effect:

```
/vulnetix:dashboard
```

You should see a vulnerability summary table. For Claude Code specifically, you can also run `/plugins` to confirm the plugin is **enabled** and `/hooks` to confirm all six hooks are registered.

---

Continue to [Verification](../verification/) for a full post-install checklist.
