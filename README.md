# Vulnetix Claude Code Plugin

Vulnerability intelligence for Claude Code — automated dependency scanning, exploit analysis, and remediation powered by the Vulnetix VDB API.

## Contents

- [Quick Start](#quick-start)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Upgrading](#upgrading)
- [Troubleshooting](#troubleshooting)
- [Privacy & Security](#privacy--security)
- [Full Documentation](https://claude-docs.vdb.vulnetix.com)
- [CLI Documentation](https://docs.cli.vulnetix.com/)
- [VDB API Reference](https://redocly.github.io/redoc/?url=https://api.vdb.vulnetix.com/v1/spec)
- [GitHub App](https://github.com/marketplace/vulnetix)

## Quick Start

Add the marketplace:

```
/plugin marketplace add Vulnetix/claude-code-plugin
```

Install the plugin:

```
/plugin install vulnetix@vulnetix-plugins
```

Verify with `/plugins` and `/hooks`.

## Features

### Skills

| Skill | Purpose |
|-------|---------|
| `/vulnetix:package-search <name>` | Search packages and assess risk before adding dependencies |
| `/vulnetix:exploits <vuln-id>` | Analyze exploit intelligence (PoCs, EPSS, CISA KEV, threat model) |
| `/vulnetix:fix <vuln-id>` | Get fix intelligence and apply concrete remediation |
| `/vulnetix:vuln <vuln-id or package>` | Look up vulnerability details or list all vulns for a package |
| `/vulnetix:exploits-search [query]` | Search for exploits with ecosystem/severity/EPSS filters |
| `/vulnetix:remediation <vuln-id>` | Context-aware remediation plan with verification steps |

Plus four slash commands for direct VDB CLI access: `vdb-vuln`, `vdb-vulns`, `vdb-exploits-search`, `vdb-remediation`.

### Hooks

| Hook | Trigger | Purpose |
|------|---------|---------|
| Pre-commit scan | `git commit` | Scan staged manifests for vulnerabilities |
| Manifest edit gate | Edit/Write on manifests | Check packages for vulns before adding |
| Post-install scan | `npm install`, `pip install`, etc. | Auto-scan after dependency changes |
| Session dashboard | Session start | Show vulnerability status summary |
| Stop reminder | Session end | Remind about unresolved P1/P2 vulnerabilities |
| Vuln context inject | User message | Auto-detect CVE/GHSA IDs and inject prior context |

### Agents

| Agent | Purpose |
|-------|---------|
| bulk-triage | Triage multiple vulnerabilities in parallel with CWSS priority scoring |

## Prerequisites

Install the [Vulnetix CLI](https://docs.cli.vulnetix.com/) and authenticate:

```bash
brew install vulnetix/tap/vulnetix
```

```bash
vulnetix auth login
```

See [CLI Documentation](https://docs.cli.vulnetix.com/) for all installation methods.

## Upgrading

Marketplace:

```
/plugin update vulnetix
```

Local clone:

```bash
cd ~/claude-code-plugin && git pull
```

```
/plugin remove vulnetix
```

```
/plugin add ~/claude-code-plugin/vulnetix
```

## Troubleshooting

**Hook not triggering?** Run `/plugins` to check the plugin is enabled, then `/hooks` to verify registration.

**"API unavailable or not authenticated"?** Run `vulnetix vdb status` to check connectivity, then `vulnetix auth login` if needed.

**Skill commands not working?** Use the colon syntax: `/vulnetix:fix <vuln-id>` (not `/vulnetix fix`).

**Scans too slow?** The pre-commit hook has a 120s timeout. Stage fewer manifest files or disable temporarily with `/plugin disable vulnetix`.

## Privacy & Security

- **No code is sent to Vulnetix** — only dependency names and versions
- Manifest files are scanned locally using the Vulnetix CLI
- PoC exploits are **never executed** — static analysis only
- All API calls are authenticated and use HTTPS

## License

Apache-2.0 — see [LICENSE](vulnetix/LICENSE) for details.

## Resources

- [Full Plugin Documentation](https://claude-docs.vdb.vulnetix.com)
- [Vulnetix CLI Documentation](https://docs.cli.vulnetix.com/)
- [VDB API Reference](https://redocly.github.io/redoc/?url=https://api.vdb.vulnetix.com/v1/spec)
- [GitHub App](https://github.com/marketplace/vulnetix)
- [Status Page](https://status.vulnetix.com)

Report issues at [github.com/Vulnetix/claude-code-plugin](https://github.com/Vulnetix/claude-code-plugin).
