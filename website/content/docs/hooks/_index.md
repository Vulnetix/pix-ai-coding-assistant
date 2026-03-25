---
title: Hooks
weight: 2
description: Six event-driven hooks that scan, track, and surface vulnerability intelligence automatically during your Claude Code workflow.
---

The Vulnetix plugin registers six hooks with Claude Code. Each hook fires on a specific event, performs lightweight analysis, and injects an informational `systemMessage` back into the conversation. Hooks never block operations -- they always exit 0.

## Hook overview

| Hook | Event | Matcher | Timeout | Purpose |
|------|-------|---------|---------|---------|
| [Pre-Commit Scan](pre-commit-scan) | PreToolUse | Bash | 120s | Scans staged manifest files for vulnerabilities |
| [Post-Install Scan](post-install-scan) | PostToolUse | Bash | 120s | Scans after dependency install commands |
| [Manifest Edit Gate](manifest-edit-scan) | PreToolUse | Edit\|Write | 30s | Checks packages being added/modified for risk |
| [Session Summary](session-summary) | SessionStart | -- | 10s | Displays vulnerability dashboard on session start |
| [Stop Reminder](stop-reminder) | Stop | -- | 10s | Reminds about unresolved vulnerabilities |
| [Context Inject](vuln-context-inject) | UserPromptSubmit | -- | 15s | Auto-detects CVE/GHSA IDs in messages |

## Key principles

**Never blocks.** Every hook exits 0 regardless of what it finds. Hooks are informational -- they surface context and suggest actions but never prevent commits, edits, or other operations.

**JSON systemMessage output.** All hooks communicate by writing a JSON object to stdout:

```json
{"systemMessage": "Vulnetix: ..."}
```

Claude Code reads this and injects it into the conversation context, making the information available to the AI without interrupting the developer.

**Minimal dependencies.** Hooks require only two external tools:

- **jq** -- for JSON processing (CycloneDX SBOM parsing, systemMessage construction)
- **vulnetix CLI** -- authenticated with a Vulnetix account for API access

If either dependency is missing, hooks exit silently rather than producing errors.

**Data directory.** Hooks that generate artifacts (SBOMs, memory updates) write to `.vulnetix/` in the project root. This directory is automatically added to `.gitignore` on first use.

## How hooks are registered

Hooks are declared in the plugin's `hooks.json` file and registered with Claude Code when the plugin is installed. Each entry specifies:

- **hook** -- the Claude Code event name (e.g., `PreToolUse`, `PostToolUse`)
- **matcher** -- optional tool name filter (e.g., `Bash`, `Edit|Write`)
- **script** -- path to the shell script
- **timeout** -- maximum execution time in seconds
