---
title: "Verification"
weight: 4
description: "Confirm the plugin, hooks, skills, and commands are all working correctly."
---

Run through these checks after installing or updating the plugin to make sure everything is wired up.

## Check Plugin Status

```
/plugins
```

The output should list `vulnetix` with a status of **enabled**. If it shows as disabled, re-enable it:

```
/plugin enable vulnetix
```

## Check Hook Registration

```
/hooks
```

You should see **6 hooks** registered across these events:

| Event | Count | Purpose |
|-------|-------|---------|
| `PreToolUse` | 2 | Pre-commit scan, manifest edit gate |
| `PostToolUse` | 1 | Post-install scan |
| `SessionStart` | 1 | Session dashboard |
| `Stop` | 1 | Stop reminder |
| `UserPromptSubmit` | 1 | Vuln context inject |

If any hooks are missing, remove and re-add the plugin (see [Updating](../updating/)).

## Test a Skill

Run a vulnerability lookup to verify skills can reach the VDB API:

```
/vulnetix:vuln CVE-2021-44228
```

You should see structured vulnerability details for Log4Shell, including severity, affected packages, and available fixes.

## Test a Command

Commands provide raw CLI output without additional formatting. Try:

```
/vulnetix:vdb-vuln CVE-2021-44228
```

This calls `vulnetix vdb vuln CVE-2021-44228` directly and returns the JSON response from the VDB API.

## Troubleshooting

If a skill or command returns **"API unavailable or not authenticated"**, verify your CLI credentials:

```bash
vulnetix vdb status
```

If `auth` shows `unauthorized`, re-authenticate with `vulnetix auth login`.

If hooks are not triggering during normal workflows, confirm `jq` is installed and on your `PATH`:

```bash
jq --version
```

For additional diagnostics see the [Troubleshooting](/docs/troubleshooting/) section.
