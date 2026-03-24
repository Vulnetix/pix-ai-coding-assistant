---
name: package-search
description: Search for packages and assess security risk before adding as dependencies
argument-hint: <package-name>
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep, Edit
---

# Vulnetix Package Search Skill

This skill searches for packages across ecosystems and provides a comprehensive security risk assessment before adding them as dependencies.

## Workflow

### Step 1: Detect Repository Ecosystems

Use **Glob** to identify manifest files in the repository:

- `package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml` → **npm**
- `go.mod`, `go.sum` → **go**
- `Cargo.toml`, `Cargo.lock` → **cargo**
- `requirements.txt`, `pyproject.toml`, `Pipfile`, `poetry.lock`, `uv.lock` → **pypi**
- `Gemfile`, `Gemfile.lock` → **rubygems**
- `pom.xml`, `build.gradle`, `gradle.lockfile` → **maven**
- `composer.json`, `composer.lock` → **packagist**

Determine which ecosystems this repository uses.

### Step 2: Search Packages

Run the Vulnetix VDB package search command:

```bash
vulnetix vdb packages search "$ARGUMENTS" -o json
```

If you detected a single ecosystem, add the `--ecosystem <ecosystem>` flag to filter results.

For example:
```bash
vulnetix vdb packages search "express" --ecosystem npm -o json
```

The output is JSON with this structure:
```json
{
  "packages": [
    {
      "name": "express",
      "ecosystem": "npm",
      "description": "Fast, unopinionated, minimalist web framework",
      "latestVersion": "4.18.2",
      "vulnerabilityCount": 3,
      "maxSeverity": "high",
      "safeHarbourScore": 85,
      "repository": "https://github.com/expressjs/express"
    }
  ]
}
```

### Step 3: Filter Results

Discard packages from ecosystems not present in the repository. For example, if the repo only has `package.json`, filter out PyPI and Cargo results.

### Step 4: Risk Assessment

Present the matching packages in a comparison table with these columns:

| Package | Ecosystem | Latest Version | Vulnerabilities | Max Severity | Safe Harbour Score | Repository |
|---------|-----------|----------------|-----------------|--------------|-------------------|------------|
| ... | ... | ... | ... | ... | ... | ... |

**Interpretation guide:**
- **Vulnerability Count**: Total known vulnerabilities (all versions)
- **Max Severity**: Highest severity rating (critical/high/medium/low)
- **Safe Harbour Score**: 0-100 risk score (higher is safer)
  - 90-100: Excellent security posture
  - 70-89: Good, minor issues
  - 50-69: Moderate risk
  - <50: High risk, use with caution

### Step 5: Propose Dependency Addition

For the best candidate (lowest vuln count, highest safe harbour score):

1. **Identify the manifest file** to edit based on ecosystem
2. **Show the concrete edit** that would add this dependency:
   - **npm**: Add to `dependencies` in `package.json`
   - **pypi**: Add to `requirements.txt` or `pyproject.toml`
   - **go**: Provide `go get` command
   - **cargo**: Add to `[dependencies]` in `Cargo.toml`
   - **maven**: Provide `<dependency>` XML
   - **rubygems**: Add to `Gemfile`
   - **packagist**: Provide `composer require` command

Use the **Edit** tool to show the proposed change, but **DO NOT apply it yet**.

Example for npm:
```diff
{
  "dependencies": {
+   "express": "^4.18.2",
    "other-package": "1.0.0"
  }
}
```

### Step 6: Planning Interview

Ask the user:

1. **Would you like me to add this package to your project?** (If yes, apply the edit and suggest running `npm install`, `pip install`, etc.)
2. **Search for alternatives?** (Suggest 2-3 alternative package names based on repository context and the search query)
3. **Run deeper vulnerability check?** (Suggest `/vulnetix:exploits <vuln-id>` for any critical/high severity vulnerabilities found)

If the user requests alternatives, repeat steps 2-6 with the suggested names.

## Error Handling

- If `vulnetix vdb packages search` fails, inform the user to check `vulnetix vdb status`
- If no packages match repo ecosystems, suggest broadening the search or checking alternative ecosystems
- If manifest file structure is unfamiliar, ask the user which file to edit

## Security Notes

- Always recommend the **latest stable version** unless there are known vulnerabilities in it
- If the latest version has critical vulnerabilities, warn the user and recommend holding off until a patch is available
- Never silently add dependencies — always get explicit user approval first
