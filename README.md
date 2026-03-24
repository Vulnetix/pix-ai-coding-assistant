# Vulnetix Claude Code Plugin

Vulnerability intelligence for Claude Code — scans dependencies on commit, searches packages for risk data, analyzes exploits, and proposes fixes via the Vulnetix VDB API.

## Features

### 🪝 Pre-Commit Vulnerability Scanning

Automatically scans staged dependency manifest files when you run `git commit` commands. The hook:

- Detects 15+ manifest types (npm, Python, Go, Rust, Maven, etc.)
- Scans for known vulnerabilities using Vulnetix VDB
- Reports vulnerability counts by severity (critical/high/medium/low)
- **Never blocks commits** — informational only

### 🔍 Three Interactive Skills

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

You should see the `PreToolUse` hook for Bash commands.

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
   🔍 Vulnetix scan found 5 vulnerabilities in staged dependencies:
   2 high, 3 medium (in: package.json, package-lock.json).
   Consider reviewing with `/vulnetix:fix <vuln-id>` before committing.
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

Ensure the skill is invoked correctly:
```
/vulnetix:package-search <package-name>
/vulnetix:exploits <vuln-id>
/vulnetix:fix <vuln-id>
```

**Not:**
```
/vulnetix package-search <package-name>  ❌ (missing colon)
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
