---
title: Pre-Commit Scan
weight: 1
description: Extracts packages from staged dependency manifests and runs background VDB package searches before every git commit — never blocks the commit operation.
---

The pre-commit scan intercepts every `git commit` command, identifies staged dependency manifests, extracts package names and versions locally, then launches background VDB package searches that run after the hook returns. The commit proceeds immediately without waiting for API results.

| Property | Value |
|----------|-------|
| **Event** | `PreToolUse` |
| **Matcher** | `Bash` |
| **Script** | `pre-commit-scan.sh` |
| **Timeout** | 30 seconds |

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

## Package extraction

For each staged manifest, the hook reads the staged content via `git show :<path>` and extracts package name/version pairs using ecosystem-specific parsers:

| Manifest | Parser | Method |
|----------|--------|--------|
| `package.json` | jq | `dependencies` + `devDependencies` objects |
| `requirements.txt` | grep/awk | `package==version` lines |
| `go.mod` | awk | `require` block entries |
| `Cargo.lock` | awk | `[[package]]` blocks with `name` and `version` |
| `Pipfile.lock` | jq | `.default` + `.develop` objects |
| `composer.lock` | jq | `.packages` + `.packages-dev` arrays |
| `gradle.lockfile` | grep/awk | `group:artifact:version` lines |
| `pom.xml` | awk | `<dependency>` blocks with `groupId`, `artifactId`, `version` |

Lock files with complex formats (`package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `poetry.lock`, `uv.lock`, `go.sum`, `Gemfile.lock`) are detected as changed but packages are not extracted from them. The hook notes these in the output.

Extracted packages are deduplicated by name and ecosystem, then capped at 50 to keep background API usage reasonable.

## Background package search

After extracting packages, the hook spawns a background process and exits immediately. The background process:

1. Queries `vulnetix vdb packages search <package> --ecosystem <ecosystem> -o json` for each extracted package
2. Collects vulnerability counts, max severity, Safe Harbour scores, and latest versions
3. Writes a results JSON file to `.vulnetix/scans/pre-commit.<timestamp>.packages.json`
4. Updates the `manifests:` section in `.vulnetix/memory.yaml`

The commit proceeds without waiting for these results.

### Results file format

```json
{
  "timestamp": "2025-03-15T10:30:00Z",
  "manifests": ["package.json", "go.mod"],
  "packages_scanned": 42,
  "risky_packages": [
    {
      "name": "express",
      "version": "4.17.1",
      "ecosystem": "npm",
      "manifest": "package.json",
      "vulnerability_count": 3,
      "max_severity": "high",
      "safe_harbour_score": "72",
      "latest_version": "4.21.0"
    }
  ],
  "total_vulnerabilities": 5
}
```

## Memory file updates

### Manifest tracking

The background process replaces the entire `manifests:` section in memory with fresh scan metadata for each scanned file:

```yaml
manifests:
  package.json:
    path: "package.json"
    ecosystem: npm
    last_scanned: "2025-03-15T10:30:00Z"
    packages_searched: true
    results_path: ".vulnetix/scans/pre-commit.20250315T103000Z.packages.json"
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

The hook returns immediately with a brief message:

```
Vulnetix: Scanning 28 packages from 2 staged manifests in background.
Manifests: package.json (npm), go.mod (go)
Results will be saved to `.vulnetix/scans/pre-commit.20250315T103000Z.packages.json`.
```

When lock files are staged but cannot be parsed:

```
Vulnetix: Scanning 15 packages from 3 staged manifests in background.
Manifests: package.json (npm), package-lock.json (npm), go.mod (go)
Results will be saved to `.vulnetix/scans/pre-commit.20250315T103000Z.packages.json`.
Note: package-lock.json changed but packages could not be extracted (lock file format).
```
