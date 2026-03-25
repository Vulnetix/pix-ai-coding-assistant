---
title: Package Search
weight: 1
description: Search packages across ecosystems and get a comprehensive security risk assessment before adding dependencies.
---

The Package Search skill searches for packages across ecosystems and provides a comprehensive security risk assessment before adding them as dependencies.

## Invocation

```
/vulnetix:package-search <package-name>
```

For example:

```
/vulnetix:package-search express
/vulnetix:package-search lodash
```

## Workflow

### 1. Ecosystem Detection

The skill detects your repository's ecosystems by scanning for manifest files:

| Manifest Files | Ecosystem |
|----------------|-----------|
| `package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml` | npm |
| `go.mod`, `go.sum` | go |
| `Cargo.toml`, `Cargo.lock` | cargo |
| `requirements.txt`, `pyproject.toml`, `Pipfile`, `poetry.lock`, `uv.lock` | pypi |
| `Gemfile`, `Gemfile.lock` | rubygems |
| `pom.xml`, `build.gradle`, `gradle.lockfile` | maven |
| `composer.json`, `composer.lock` | packagist |

If `.vulnetix/memory.yaml` has a cached `manifests` section from a recent scan (less than 24 hours old), it uses the cached ecosystem list as a starting point.

### 2. Version Detection

The skill determines whether the package is already installed using a **4-tier detection chain** (in priority order):

1. **User-supplied** -- the user explicitly stated the version in their message
2. **Lockfile** -- the most authoritative filesystem source (e.g., `package-lock.json`, `poetry.lock`, `go.sum`, `Cargo.lock`)
3. **Manifest** -- the declared version constraint, which is less precise than a lockfile (e.g., `^4.17.0` from `package.json`)
4. **Installed artifacts** -- queries the actual installed state (e.g., `node_modules/<pkg>/package.json`, `pip show <pkg>`, `go list -m`)

Every output tags the version with its source for full transparency:

```
1.2.3 (from lockfile: package-lock.json)
^1.2.0 (from manifest: package.json -- constraint, not exact)
1.2.3 (from node_modules)
1.2.3 (user-supplied)
Not installed
```

### 3. VDB Search

Runs the Vulnetix VDB package search:

```bash
vulnetix vdb packages search "express" --ecosystem npm -o json
```

If a single ecosystem was detected, the `--ecosystem` flag filters results automatically. Results from ecosystems not present in the repository are discarded.

### 4. Risk Assessment Table

Results are presented in a comparison table:

| Package | Ecosystem | Current Version | Latest Version | Vulnerabilities | Max Severity | Safe Harbour | Confidence | Repository |
|---------|-----------|-----------------|----------------|-----------------|--------------|-------------|------------|------------|
| express | npm | 4.17.1 (lockfile) | 4.18.2 | 3 | high | 0.85 | Reasonable | [link] |

#### Safe Harbour Confidence Tiers

The API returns a 0--100 integer score, converted to a 0--1 decimal. The confidence tier is derived from that value:

| Tier | Range | Meaning |
|------|-------|---------|
| **High** | > 0.90 | Excellent security posture, strong track record |
| **Reasonable** | 0.35--0.90 | Acceptable risk, minor or moderate issues |
| **Low** | < 0.35 | Significant risk, use with extreme caution |

Below the table, a **Version Context** summary is always included:

```
Version Context:
- express: 4.17.1 -> 4.18.2 (patch upgrade available) -- source: package-lock.json
- lodash: Not installed -- no existing version detected
```

### 5. Dependency Addition Proposal

For the best candidate (lowest vulnerability count, highest Safe Harbour score), the skill identifies the manifest file to edit and shows the concrete change as a diff:

```diff
{
  "dependencies": {
+   "express": "^4.18.2",
    "other-package": "1.0.0"
  }
}
```

The edit is proposed but **never applied without user approval**.

### 6. Planning Interview

After presenting the assessment, the skill asks:

1. **Would you like me to add this package?** -- If yes, applies the edit and suggests running the install command
2. **Search for alternatives?** -- Suggests 2--3 alternative package names based on the search query
3. **Run deeper vulnerability check?** -- Suggests `/vulnetix:exploits <vuln-id>` for any critical or high severity vulnerabilities found

## GitHub Advanced Security Integration

When `gh` CLI is authenticated, the skill enriches the risk assessment with data from GitHub:

### Dependabot

- Checks for open Dependabot alerts matching packages in the results
- Notes existing Dependabot PRs that propose the same upgrade
- Surfaces prior Dependabot history from the memory file

### CodeQL

- Checks for CodeQL alerts matching the CWEs associated with package vulnerabilities
- Notes whether CodeQL default setup is configured on the repository
- Surfaces available CodeQL AI-suggested fixes

### Secret Scanning

- For packages handling authentication or credentials (e.g., `jsonwebtoken`, `bcrypt`, `passport`), checks for active secret scanning alerts
- Flags when active secrets exist alongside a credentials-handling package

## Memory Updates

After completing the search, the skill updates `.vulnetix/memory.yaml`:

- New vulnerabilities discovered in the search results are recorded with `status: under_investigation` and `discovery.source: scan`
- Known history for each package is surfaced, including prior vuln IDs, statuses, decision dates, and CWSS priorities
- Packages with unresolved P1 or P2 vulnerabilities are flagged with a warning: "Active exploit intelligence available"

## Example

```
/vulnetix:package-search express
```

The skill detects the npm ecosystem from `package.json`, searches the VDB for "express" packages, detects that version 4.17.1 is installed from the lockfile, presents a risk assessment table comparing current and latest versions, proposes an upgrade to 4.18.2, and asks whether to apply the change.
