---
title: Pre-Commit Scan
weight: 1
description: Scans staged dependency manifests for known vulnerabilities before every git commit, generates CycloneDX SBOMs, and maintains the project vulnerability memory file.
---

The pre-commit scan is the most comprehensive hook in the plugin. It intercepts every `git commit` command, identifies staged dependency manifests, generates a CycloneDX SBOM for each one, and cross-references the results against the project's vulnerability memory.

| Property | Value |
|----------|-------|
| **Event** | `PreToolUse` |
| **Matcher** | `Bash` |
| **Script** | `pre-commit-scan.sh` |
| **Timeout** | 120 seconds |

## Trigger condition

The hook reads the `tool_input.command` field from stdin and checks whether it contains `git commit`. All other Bash commands are ignored -- the hook exits 0 immediately.

## Manifest detection

The hook calls `git diff --cached --name-only` to get the list of staged files, then filters for these 15 manifest filename patterns:

| Manifest file | Ecosystem |
|---------------|-----------|
| `package.json` | npm |
| `package-lock.json` | npm |
| `yarn.lock` | npm |
| `pnpm-lock.yaml` | npm |
| `requirements.txt` | pypi |
| `Pipfile.lock` | pypi |
| `poetry.lock` | pypi |
| `uv.lock` | pypi |
| `go.mod` | go |
| `go.sum` | go |
| `Gemfile.lock` | rubygems |
| `Cargo.lock` | cargo |
| `pom.xml` | maven |
| `gradle.lockfile` | maven |
| `composer.lock` | packagist |

If no staged files match any of these patterns, the hook exits silently.

## SBOM generation

For each staged manifest, the hook runs:

```bash
vulnetix scan --file <manifest> -f cdx17
```

This produces a CycloneDX v1.7 JSON SBOM. The SBOM is saved to:

```
.vulnetix/scans/<sanitized-manifest-name>.<timestamp>.cdx.json
```

The sanitized name replaces path separators with `--` (e.g., `packages/api/package.json` becomes `packages--api--package.json`).

## Vulnerability extraction

The hook parses each SBOM with jq, joining the `vulnerabilities` array with `components` and `affects` references to resolve:

- **Vulnerability ID** (CVE or GHSA)
- **Severity** (preferring NVD/GHSA ratings, falling back to the first available)
- **Package name** and **version** (resolved from the component bom-ref)

## Memory file updates

The hook maintains `.vulnetix/memory.yaml` as the persistent vulnerability state for the project.

### New vulnerabilities

For each vulnerability ID not already in memory, the hook appends a full entry:

```yaml
CVE-2024-XXXXX:
  aliases: []
  package: example-package
  ecosystem: npm
  discovery:
    date: "2024-01-15T10:30:00Z"
    source: hook
    file: package.json
    sbom: .vulnetix/scans/package.json.20240115T103000Z.cdx.json
  versions:
    current: "1.2.3"
    current_source: "manifest: package.json"
    fixed_in: null
    fix_source: null
  severity: high
  status: under_investigation
  decision:
    choice: investigating
    reason: "Discovered by pre-commit hook scan"
    date: "2024-01-15T10:30:00Z"
  history:
    - date: "2024-01-15T10:30:00Z"
      event: discovered
      detail: "Found example-package@1.2.3 in package.json during pre-commit scan"
```

### Known vulnerabilities

For vulnerabilities already tracked in memory, the hook reads the current status and decision to produce a developer-friendly summary. It also checks for Dependabot context (alert state, PR number, PR state) when available.

The VEX status mapping:

| VEX Status | Decision | Display |
|------------|----------|---------|
| `fixed` | any | Fixed |
| `not_affected` | any | Not affected |
| `under_investigation` | any | Investigating |
| `affected` | `risk-accepted` | Risk accepted |
| `affected` | `deferred` | Fix planned |
| `affected` | other | Vulnerable |

### Manifest tracking

The hook replaces the entire `manifests:` section in memory with fresh scan metadata for each scanned file:

```yaml
manifests:
  package.json:
    path: "package.json"
    ecosystem: npm
    last_scanned: "2024-01-15T10:30:00Z"
    sbom_generated: true
    sbom_path: ".vulnetix/scans/package.json.20240115T103000Z.cdx.json"
    vuln_count: 3
    scan_source: hook
```

## Data directory setup

On first run, the hook:

1. Creates `.vulnetix/` and `.vulnetix/scans/` directories
2. Adds `.vulnetix/` to `.gitignore` (creating the file if necessary)
3. Migrates the legacy `.vulnetix-memory.yaml` file to `.vulnetix/memory.yaml` if present

## CLI discovery

The hook probes multiple locations for the `vulnetix` binary:

1. Current `PATH` (`command -v vulnetix`)
2. Homebrew on Linux: `/home/linuxbrew/.linuxbrew/bin/vulnetix`
3. Homebrew on macOS: `/opt/homebrew/bin/vulnetix`
4. System-wide: `/usr/local/bin/vulnetix`
5. User local: `~/.local/bin/vulnetix`
6. Go install: `~/go/bin/vulnetix`
7. Cargo install: `~/.cargo/bin/vulnetix`
8. Shell RC sourcing: sources `~/.bashrc` or `~/.zshrc` in a subshell to pick up PATH modifications

If the CLI cannot be found, the hook outputs a message suggesting installation and how to update the PATH.

## Example output

When vulnerabilities are found in staged manifests:

```
Vulnetix pre-commit scan results:

2 new vulnerabilities:
- CVE-2024-29041 (high) -- express@4.17.1 in package.json
- CVE-2024-28849 (medium) -- follow-redirects@1.15.4 in package-lock.json

1 previously tracked:
- CVE-2023-44270 -- Risk accepted (Dependabot PR #42: open)

Manifests scanned: package.json (npm), package-lock.json (npm)
SBOMs saved to .vulnetix/scans/

Review with `/vulnetix:fix <vuln-id>` or `/vulnetix:exploits <vuln-id>`.
```

When no vulnerabilities are found:

```
Vulnetix: No vulnerabilities found in staged dependencies.
Manifests scanned: package.json (npm). SBOMs saved to .vulnetix/scans/.
```
