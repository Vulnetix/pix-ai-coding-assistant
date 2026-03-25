# Vulnetix Claude Code Plugin

Vulnerability intelligence for Claude Code — scans dependencies on commit, searches packages for risk data, analyzes exploits, and proposes fixes via the Vulnetix VDB API.

## Features

### Pre-Commit Vulnerability Scanning

Automatically scans staged dependency manifest files when you run `git commit` commands. The hook:

- Detects 15+ manifest types (npm, Python, Go, Rust, Maven, etc.)
- Scans for known vulnerabilities using Vulnetix VDB
- Reports vulnerability counts by severity (critical/high/medium/low)
- **Never blocks commits** — informational only

### Six Interactive Skills

#### 1. `/vulnetix:package-search <package-name>`

Search for packages across ecosystems and assess security risk before adding them as dependencies.

**Example:**
```
/vulnetix:package-search express
```

**What it does:**
- Detects your repository's ecosystems (npm, PyPI, Maven, etc.)
- Searches the Vulnetix package database
- Presents vulnerability counts, max severity, and Safe Harbour scores
- Proposes concrete dependency addition with exact manifest edits
- Suggests alternatives if needed

#### 2. `/vulnetix:exploits <vuln-id>`

Analyze exploit intelligence for a vulnerability (CVE, GHSA, etc.) against your repository.

**Example:**
```
/vulnetix:exploits CVE-2021-44228
```

**What it does:**
- Fetches public exploits (PoCs, Metasploit modules, etc.)
- Retrieves CVSS, EPSS, and CISA KEV status
- Checks if your dependencies are affected
- Analyzes exploit reachability (static analysis only — never executes code)
- Provides exploitability rating (CRITICAL/HIGH/MEDIUM/LOW/N/A)
- Recommends `/vulnetix:fix` if actionable

#### 3. `/vulnetix:fix <vuln-id>`

Get fix intelligence and propose concrete remediation steps for your repository.

**Example:**
```
/vulnetix:fix CVE-2021-44228
```

**What it does:**
- Fetches fix data (version bumps, patches, workarounds)
- Identifies affected dependencies in your manifest files
- Proposes exact edits with version bumps
- Assesses breaking change risk
- Suggests test commands and re-scanning to verify the fix

#### 4. `/vulnetix:vuln <vuln-id or package-name>`

Look up a vulnerability by ID, or list all vulnerabilities for a package.

**Examples:**
```
/vulnetix:vuln CVE-2021-44228
/vulnetix:vuln express
```

**What it does:**
- Auto-detects whether the argument is a vuln ID or package name
- **Vuln ID mode**: fetches CVSS v2/v3/v4 scores, EPSS, CISA KEV status, and checks repo impact
- **Package mode**: lists all known vulns with an "Affects You?" column comparing your installed version
- Accepts 78+ identifier formats (CVE, GHSA, PYSEC, RUSTSEC, SNYK, etc.)
- Supports pagination via natural language in package mode
- Cross-references with Dependabot alerts if available

#### 5. `/vulnetix:exploits-search [query]`

Search for exploits across all vulnerabilities with filtering by ecosystem, severity, source, and EPSS.

**Examples:**
```
/vulnetix:exploits-search --ecosystem npm --severity CRITICAL
/vulnetix:exploits-search --in-kev --min-epss 0.7
/vulnetix:exploits-search -q "remote code execution"
```

**What it does:**
- Searches the VDB for vulnerabilities with known exploits
- Filters by ecosystem, severity, exploit source (ExploitDB, Metasploit, Nuclei, etc.), EPSS, and CISA KEV
- Auto-detects your repository's ecosystem as a default filter
- Shows exploitation maturity level (NONE/POC/WEAPONIZED/ACTIVE/WIDESPREAD)
- Flags CrowdSec live sightings and ransomware associations
- Recommends `/vulnetix:exploits` for deep analysis of individual results

#### 6. `/vulnetix:remediation <vuln-id>`

Get a context-aware remediation plan for a vulnerability with fix verification steps.

**Example:**
```
/vulnetix:remediation CVE-2021-44228
```

**What it does:**
- Auto-detects your ecosystem, package manager, installed version, and container image
- Fetches registry fixes, source patches, distribution advisories, and workarounds
- Provides CWE-specific remediation strategies
- Includes CrowdSec live threat intelligence (active exploitation, source countries)
- Shows workaround effectiveness scores when no immediate fix is available
- Generates verification commands per package manager

### Four Slash Commands (Direct CLI Access)

Slash commands are deterministic thin wrappers around VDB CLI subcommands. Unlike skills (which provide rich LLM-guided analysis), these run the CLI command directly and display the output. Use them when you want raw VDB data without additional analysis.

#### `/vulnetix:vdb-vuln <vuln-id>`

Look up a vulnerability by ID.

```
/vulnetix:vdb-vuln CVE-2021-44228
/vulnetix:vdb-vuln GHSA-jfh8-3a1q-hjz9
```

#### `/vulnetix:vdb-vulns <package-name> [flags]`

List all known vulnerabilities for a package.

```
/vulnetix:vdb-vulns express
/vulnetix:vdb-vulns lodash --limit 20
```

Flags: `--limit`, `--offset`

#### `/vulnetix:vdb-exploits-search [flags]`

Search for exploits across all vulnerabilities with filtering.

```
/vulnetix:vdb-exploits-search --ecosystem npm --severity CRITICAL
/vulnetix:vdb-exploits-search --in-kev --min-epss 0.7 --sort epss
/vulnetix:vdb-exploits-search --source metasploit -q "remote code execution"
```

Flags: `--ecosystem`, `--source`, `--severity`, `--in-kev`, `--min-epss`, `-q`, `--sort`, `--limit`, `--offset`

#### `/vulnetix:vdb-remediation <vuln-id> [flags]`

Get a context-aware remediation plan (V2 API).

```
/vulnetix:vdb-remediation CVE-2021-44228
/vulnetix:vdb-remediation CVE-2021-44228 --ecosystem maven --package-name log4j-core --current-version 2.14.1
/vulnetix:vdb-remediation CVE-2024-XXXXX --include-guidance --include-verification-steps
```

Flags: `--ecosystem`, `--package-name`, `--current-version`, `--package-manager`, `--purl`, `--container-image`, `--os`, `--vendor`, `--product`, `--include-guidance`, `--include-verification-steps`

---

## Prerequisites

### 1. Install the Vulnetix CLI

**macOS/Linux:**
```bash
curl -fsSL https://cli.vulnetix.com/install.sh | bash
```

**Or via package managers:**
```bash
# Homebrew
brew install vulnetix/tap/vulnetix

# Go
go install github.com/AuditRay/vulnetix/cli@latest
```

**Windows:**
```powershell
irm https://cli.vulnetix.com/install.ps1 | iex
```

Verify installation:
```bash
vulnetix --version
```

### 2. Authenticate with Vulnetix

```bash
vulnetix auth login
```

This will open a browser window for authentication. After logging in, verify your connection:

```bash
vulnetix vdb status
```

You should see JSON output with:
```json
{
  "api": { "status": "healthy" },
  "auth": { "status": "ok", "method": "apikey" }
}
```

---

## Installation

### Option A: Marketplace (Recommended)

Add the marketplace and install the plugin:

```
/plugin marketplace add Vulnetix/claude-code-plugin
/plugin install vulnetix@vulnetix-plugins
```

### Option B: Clone Locally

Clone the repository and add it directly:

```bash
git clone https://github.com/Vulnetix/claude-code-plugin.git ~/claude-code-plugin
```

Then in Claude Code:
```
/plugin add ~/claude-code-plugin/vulnetix
```

### Upgrading

#### Marketplace Install

```
/plugin update vulnetix
```

#### Local Clone

```bash
cd ~/claude-code-plugin && git pull
```

Then in Claude Code:
```
/plugin remove vulnetix
/plugin add ~/claude-code-plugin/vulnetix
```

### Verify Installation

Check that the plugin is loaded:

```bash
/plugins
```

You should see `vulnetix` in the list.

Check that hooks are registered:

```bash
/hooks
```

You should see hooks for:
- `PreToolUse` (Bash) — pre-commit vulnerability scanning
- `PreToolUse` (Edit|Write) — manifest dependency security gate
- `PostToolUse` (Bash) — auto-scan after dependency installs
- `SessionStart` — vulnerability dashboard on session start
- `Stop` — unresolved vulnerability reminder
- `UserPromptSubmit` — auto-detect CVE/GHSA IDs in messages

---

## Usage

### Pre-Commit Scanning (Automatic)

The hook activates automatically when you use `git commit` commands. No configuration needed.

**Example workflow:**

1. Stage files with changes to dependencies:
   ```bash
   git add package.json package-lock.json
   ```

2. Commit:
   ```bash
   git commit -m "Update dependencies"
   ```

3. Claude will show a system message if vulnerabilities are found:
   ```
   🔍 Vulnetix pre-commit scan results:

   3 new vulnerabilities:
   • CVE-2024-1234 (critical) — express@4.17.1 in package.json
   • CVE-2024-5678 (high) — lodash@4.17.20 in package.json
   • GHSA-xxxx-yyyy (medium) — jsonwebtoken@8.5.1 in package-lock.json

   2 previously tracked:
   • CVE-2023-9999 — Fixed (Dependabot PR #187 merged)
   • CVE-2023-8888 — Risk accepted

   Manifests scanned: package.json (npm), package-lock.json (npm)
   SBOMs saved to .vulnetix/scans/

   Review with `/vulnetix:fix <vuln-id>` or `/vulnetix:exploits <vuln-id>`.
   ```

4. The commit proceeds regardless (informational only).

### Skills (Manual Invocation)

#### Search for a Package

```
/vulnetix:package-search lodash
```

Claude will:
1. Detect your repository's ecosystems
2. Search for matching packages
3. Show vulnerability counts and risk scores
4. Propose adding the safest version
5. Ask if you want to apply the change

#### Analyze Exploits

```
/vulnetix:exploits CVE-2024-12345
```

Claude will:
1. Fetch exploit intelligence (PoCs, Metasploit, etc.)
2. Check if your dependencies are affected
3. Assess exploitability rating
4. Recommend next steps

#### Get Fix Intelligence

```
/vulnetix:fix GHSA-xxxx-yyyy-zzzz
```

Claude will:
1. Fetch fix data (version bumps, patches)
2. Show exact manifest edits
3. Assess breaking change risk
4. Ask if you want to apply the fix
5. Suggest testing and re-scanning

#### Look Up a Vulnerability or Package

```
/vulnetix:vuln CVE-2021-44228
/vulnetix:vuln express
```

Claude will:
1. Auto-detect whether you provided a vuln ID or package name
2. Fetch vulnerability details or list all known vulns for the package
3. Check repo impact and installed versions
4. Suggest next steps (exploits, fix, remediation)

#### Search for Exploits

```
/vulnetix:exploits-search --ecosystem npm --severity CRITICAL
```

Claude will:
1. Auto-detect your repo's ecosystem if not specified
2. Search for vulnerabilities with known exploits
3. Show exploitation maturity, EPSS, KEV status, and exploit sources
4. Flag live CrowdSec sightings and ransomware associations

#### Get a Remediation Plan

```
/vulnetix:remediation CVE-2021-44228
```

Claude will:
1. Auto-detect your ecosystem, package manager, and installed version
2. Fetch registry fixes, source patches, workarounds, and CWE guidance
3. Present verification commands per package manager
4. Offer to apply manifest edits

---

## Troubleshooting

### Hook Not Triggering

**Check plugin status:**
```bash
/plugins
```

Ensure `vulnetix` is listed and enabled.

**Check hook registration:**
```bash
/hooks
```

You should see a `PreToolUse` hook for Bash commands.

### "API unavailable or not authenticated" Message

Run:
```bash
vulnetix vdb status
```

If authentication failed:
```bash
vulnetix auth login
```

If the API is unhealthy, check your internet connection or visit [status.vulnetix.com](https://status.vulnetix.com).

### Skill Commands Not Working

Ensure the command is invoked correctly:
```
# Skills (rich analysis)
/vulnetix:package-search <package-name>
/vulnetix:exploits <vuln-id>
/vulnetix:fix <vuln-id>
/vulnetix:vuln <vuln-id or package-name>
/vulnetix:exploits-search [query]
/vulnetix:remediation <vuln-id>

# Slash commands (direct CLI access)
/vulnetix:vdb-vuln <vuln-id>
/vulnetix:vdb-vulns <package-name>
/vulnetix:vdb-exploits-search [flags]
/vulnetix:vdb-remediation <vuln-id> [flags]
```

**Not:**
```
/vulnetix package-search <package-name>  <-- missing colon
```

### Hook Scanning Takes Too Long

The hook has a 120-second timeout. If scans exceed this:

1. Reduce the number of staged manifest files
2. Commit manifest files separately
3. Disable the hook temporarily: `/plugin disable vulnetix`

---

## Supported Ecosystems

The plugin supports 15+ dependency ecosystems:

| Ecosystem | Manifest Files |
|-----------|----------------|
| **npm** | `package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml` |
| **Python** | `requirements.txt`, `Pipfile.lock`, `poetry.lock`, `uv.lock` |
| **Go** | `go.mod`, `go.sum` |
| **Rust** | `Cargo.lock` |
| **Ruby** | `Gemfile.lock` |
| **Maven** | `pom.xml` |
| **Gradle** | `gradle.lockfile` |
| **PHP** | `composer.lock` |

---

## Privacy & Security

- **No code is sent to Vulnetix servers** — only dependency names and versions
- Manifest files are scanned locally using the Vulnetix CLI
- PoC exploits are **never executed** — static analysis only
- All API calls are authenticated and use HTTPS

---

## Contributing

Report issues or suggest features at [github.com/Vulnetix/claude-code-plugin](https://github.com/Vulnetix/claude-code-plugin).

---

## License

Apache-2.0 — see [LICENSE](vulnetix/LICENSE) for details.

---

## Resources

- **Vulnetix CLI Documentation:** [cli.vulnetix.com](https://cli.vulnetix.com)
- **VDB API Documentation:** [docs.vulnetix.com/vdb](https://docs.vulnetix.com/vdb)
- **Security Policy:** [vulnetix.com/security](https://vulnetix.com/security)
- **Status Page:** [status.vulnetix.com](https://status.vulnetix.com)
