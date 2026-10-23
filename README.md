<p align="center">
  <img src="pix.svg" alt="Pix, the Vulnetix AI coding assistant" width="160">
</p>

# Pix — Vulnetix for coding agents

Three hooks and eighteen skills. The hooks interrupt only when your agent is
about to do something your own policy disagrees with; the skills cover the work
that needs your working tree.

Looking a vulnerability up is not in here. That is the [Vulnetix MCP
server](https://mcp.vulnetix.com/mcp) and the CLI's own subcommands, so a
question has one answer instead of three competing descriptions of the same job.

## Contents

- [Install](#install)
- [What the hooks do](#what-the-hooks-do)
- [What the skills do](#what-the-skills-do)
- [Credentials](#credentials)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Privacy](#privacy)
- [Full documentation](https://ai-docs.vulnetix.com)

## Install

One command, for whichever agents you have:

```bash
vulnetix agent install
```

It detects the coding agents on your machine, writes each one's hook config in
its own dialect, places the skills in each host's real directory, configures the
MCP server where the host speaks MCP, and reports what it found. Re-running is
safe and tells you nothing changed.

No CLI yet:

```bash
brew install Vulnetix/tap/vulnetix        # or scoop, nix, or:
curl -fsSL https://cli.vulnetix.com/install.sh | sh
```

<details>
<summary>Registry installs, if you would rather</summary>

```bash
gh skill install Vulnetix/pix-ai-coding-assistant
npx skills add Vulnetix/pix-ai-coding-assistant
```

Both work because the canonical skills live at `skills/` in the repository root,
which is the convention each of them looks for. They install **skills only** —
hooks and MCP wiring still need `vulnetix agent install`.

Claude Code marketplace:

```
/plugin marketplace add Vulnetix/pix-ai-coding-assistant
/plugin install vulnetix@vulnetix-plugins
```
</details>

## What the hooks do

| Hook | Fires on | The one question |
|---|---|---|
| `dependency-guard` | a shell install, or an edit to a manifest | Is the dependency about to land acceptable under this repository's Safe Harbour policy? |
| `change-guard` | `git commit`, `git push` | Does the change about to be recorded carry a credential? |
| `session-context` | session start, and each prompt | What did this repository's last scan find, and does the CVE you just named reach it? |

All three are one command — `vulnetix agent hook` — reading the host's payload on
stdin and writing the host's response on stdout. That is why they work on Codex
and Claude Code alike, and why they run on native Windows, which the shell hooks
they replaced never did.

**The dependency guard is silent when your policy is satisfied**, which is nearly
always. It computes the Safe Harbour target for the package under your configured
strategy, and if what is about to land is at or better than that target it prints
nothing at all. Measured: 0 of 33 everyday commands produce output, and a lookup
only happens when a dependency is genuinely being added.

It never blocks on an unparseable manifest, an unreachable API, a missing
credential or a timeout. Absence of an answer is not a verdict.

## What the skills do

Every one of these needs your repository, your input, or a sequence a model would
not compose correctly alone. That is the entry requirement.

| Skill | The one question |
|---|---|
| `dependency-choice` | I need capability X — which package, and what am I trading? |
| `repo-impact` | Does this CVE reach anything in *this* repository? |
| `fix` | Apply a fix for this finding, here, safely. |
| `verify-fix` | Did the fix actually land? |
| `dep-resolve` | The bump is blocked by peer deps — find a compatible set. |
| `typosquat-check` | Is this name impersonating something, or known-malicious? |
| `eol-check` | What here is past end of life, or about to be? |
| `license-check` | Does anything here conflict with our licence policy? |
| `sast-scan` `secret-scan` `iac-scan` `container-scan` | Four single-purpose local scanners. |
| `secure-code-write` | I am about to write auth/crypto/SQL — what should I know? |
| `detection-rules` | I cannot patch this — what do I deploy instead? |
| `exploit-test` | Prove this is or is not exploitable against my authorised target. |
| `sbom-generate` `vex-publish` | Produce the attestations a customer or auditor asked for. |
| `dashboard` | What have we already decided here? |

Plus five subagents for multi-step work: `bulk-triage`,
`dep-upgrade-orchestrator`, `pr-security-reviewer`, `compliance-bundler`,
`incident-responder`.

Each skill's `allowed-tools` is scoped to the commands it actually runs. None
gets bare `Bash`; no read-only skill gets `Write`.

## Credentials

Optional. With none at all the CLI runs on built-in Community credentials: reads
work, the rate limit is shared with every other anonymous caller, and scans
produce no stored snapshot. Your agent is told this in those words rather than
being shown an error.

A free Community key with its own quota:
[vulnetix.com/resolve/register](https://www.vulnetix.com/resolve/register), then:

```bash
vulnetix auth login
```

That prints a URL and a code, and blocks until you approve in a browser. Sign-in
supports password, GitHub, Google and passkeys.

The CLI finds an existing credential on its own, in this order:
`VULNETIX_API_TOKEN`; `VULNETIX_API_KEY` + `VULNETIX_ORG_ID`; `VVD_ORG` +
`VVD_SECRET`; `./.vulnetix/credentials.json`; `~/.vulnetix/credentials.json`; the
OS keyring; `.netrc`.

## Configuration

`.vulnetix/agent.yaml`, all optional:

```yaml
agent:
  safeHarbourStrategy: safest      # safest | stable | latest | rolling
  maxMajorBump: 0
  dependencyGuard:
    block: [malware, kev-critical]
    warn:  [severity-high, below-target, eol, cooldown]
  changeGuard:
    block: [secrets]
```

All four strategies pick from versions Safe Harbour clears, meaning no known
vulnerability, exploit or malware report:

| Strategy | Target |
|---|---|
| `safest` | The highest stable release that Safe Harbour clears. A pre-release is never picked. |
| `stable` | The stable release closest to the one you run. It can be lower than the one you run. |
| `latest` | The highest stable release by the ecosystem's own version rules. A pre-release is never picked, and a point release on an old branch is not the latest. |
| `rolling` | Of the cleared versions published on the most recent release day (UTC), pre-releases included, the one closest to the version you run. |

`safest` and `latest` are computed separately and today usually agree.

The defaults block only what is never the right call — a known-malicious package,
or a critical advisory being exploited in the wild — and inform about the rest.
`unpinned` is deliberately not warned on: `npm i axios` is how almost every
install is written, so warning on it fires on nearly everything and teaches people
to stop reading.

Set `enabled: false` under `agent:` to switch the whole surface off without
uninstalling it.

## Troubleshooting

**The guard says nothing.** That is usually correct — it is silent when your
policy is satisfied. To check it is wired at all: `vulnetix agent hosts` shows
what this CLI can configure and what it found.

**Codex specifically.** Codex 0.153 added a trust gate, and an untrusted hook is
skipped with no error and no output. Approve the hook when Codex prompts, or the
guard stays silent.

**Skills not appearing.** Run `vulnetix agent install` again; it reports each
host's real skills directory. Note that Codex reads `~/.agents/skills`, not
`~/.codex/skills`.

**Which surface am I on?** `vulnetix auth status` says whether you are on
Community or your own key.

## Privacy

- No source code is sent to Vulnetix — dependency names and versions only.
- Manifests are parsed locally by the CLI.
- Secret detection runs entirely locally; nothing it finds leaves the machine.
- Proof-of-concept exploits are never executed. `exploit-test` requires you to
  name an authorised target.

## License

Apache-2.0 — see [LICENSE](LICENSE).

## Resources

- [Plugin documentation](https://ai-docs.vulnetix.com)
- [CLI documentation](https://docs.cli.vulnetix.com/)
- [MCP server](https://www.vulnetix.com/features/mcp-server)
- [VDB API reference](https://redocly.github.io/redoc/?url=https://api.vdb.vulnetix.com/v1/spec)
- [Status](https://status.vulnetix.com)

Issues: [github.com/Vulnetix/pix-ai-coding-assistant](https://github.com/Vulnetix/pix-ai-coding-assistant).
