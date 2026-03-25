---
title: Manifest Edit Gate
weight: 3
description: Checks packages being added or modified in dependency manifests before the edit is applied, reporting vulnerability counts, severity, and Safe Harbour scores.
---

The manifest edit gate fires before Claude Code writes to a dependency manifest file. It extracts package names and versions from the incoming diff, queries the Vulnetix VDB for each package, and reports risk information. Despite its name, it never blocks edits -- it provides an informed decision point.

| Property | Value |
|----------|-------|
| **Event** | `PreToolUse` |
| **Matcher** | `Edit\|Write` |
| **Script** | `manifest-edit-scan.sh` |
| **Timeout** | 30 seconds |

## Trigger condition

The hook reads `tool_input.file_path` from stdin and checks whether the filename matches one of 11 recognized manifest files:

| Manifest file | Ecosystem |
|---------------|-----------|
| `package.json` | npm |
| `requirements.txt` | pypi |
| `pyproject.toml` | pypi |
| `Pipfile` | pypi |
| `go.mod` | go |
| `Cargo.toml` | cargo |
| `pom.xml` | maven |
| `build.gradle` | maven |
| `build.gradle.kts` | maven |
| `Gemfile` | rubygems |
| `composer.json` | packagist |

If the file being edited is not a manifest, the hook exits silently.

## Package extraction

The hook reads the new content from `tool_input.new_string` (for Edit operations) or `tool_input.content` (for Write operations) and extracts package name/version pairs using ecosystem-specific parsing:

### npm (package.json)
Matches `"package-name": "version"` patterns in JSON, filtering out metadata keys (`name`, `version`, `description`, `scripts`, `license`, etc.) and stripping version range operators (`^`, `~`, `>=`, `<`).

### pypi (requirements.txt, pyproject.toml, Pipfile)
Matches `package==version`, `package>=version`, and similar pinning patterns at the start of lines.

### Go (go.mod)
Matches `module/path vX.Y.Z` patterns from require directives.

### Cargo (Cargo.toml)
Matches `name = "version"` patterns from dependency declarations.

## VDB query

For each extracted package, the hook queries the Vulnetix VDB packages search API:

```bash
vulnetix vdb packages search <package> --ecosystem <ecosystem> -o json
```

The response includes:

- **vulnerabilityCount** -- total known vulnerabilities for the package
- **maxSeverity** -- highest severity rating across all vulnerabilities
- **safeHarbourScore** -- a 0-to-1 composite risk score
- **latestVersion** -- the most recent published version

## Memory cross-reference

If `.vulnetix/memory.yaml` exists, the hook checks whether the package has any prior vulnerability records in memory and reports the count. This helps surface repeat offenders -- packages that have previously caused vulnerability findings in the project.

## Example output

When adding packages with known vulnerabilities to `package.json`:

```
Vulnetix dependency security check for package.json (npm):

5 known vulnerabilities across 2 packages being added/modified:

* express@4.17.1 -- 3 known vulns (max: high), Safe Harbour: 0.72, latest: 4.21.2
  Previously tracked: 2 vulnerability record(s) in memory
* lodash@4.17.20 -- 2 known vulns (max: critical), Safe Harbour: 0.45, latest: 4.17.21

Options:
1. Run `/vulnetix:fix <vuln-id>` to see fix options and remediation steps
2. Run `/vulnetix:package-search <package>` to search for safer alternatives
3. Proceed and accept the risk (the edit will not be blocked)
```

If all packages being added have zero known vulnerabilities, the hook exits silently.
