---
title: Post-Install Scan
weight: 2
description: Automatically scans dependency manifests after package install commands to detect newly introduced vulnerabilities.
---

The post-install scan fires after any dependency install command completes, scanning the relevant manifest files to catch vulnerabilities introduced by newly added or updated packages.

| Property | Value |
|----------|-------|
| **Event** | `PostToolUse` |
| **Matcher** | `Bash` |
| **Script** | `post-install-scan.sh` |
| **Timeout** | 120 seconds |

## Trigger condition

The hook reads `tool_input.command` from stdin and matches it against 23 install command patterns. If the executed command contains any of these patterns, the scan runs:

| Pattern | Ecosystem |
|---------|-----------|
| `npm install` | npm |
| `npm i ` | npm |
| `npm add` | npm |
| `yarn add` | npm |
| `yarn install` | npm |
| `pnpm add` | npm |
| `pnpm install` | npm |
| `pip install` | pypi |
| `pip3 install` | pypi |
| `uv pip install` | pypi |
| `uv add` | pypi |
| `poetry add` | pypi |
| `go get` | go |
| `go mod tidy` | go |
| `cargo add` | cargo |
| `cargo install` | cargo |
| `bundle install` | rubygems |
| `bundle add` | rubygems |
| `gem install` | rubygems |
| `composer require` | packagist |
| `composer install` | packagist |
| `mvn dependency:resolve` | maven |
| `gradle dependencies` | maven |

## Command-to-manifest mapping

When a command matches, the hook determines which manifest files to scan based on the command prefix:

| Command prefix | Manifest files scanned |
|----------------|----------------------|
| `npm`, `yarn`, `pnpm` | `package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml` |
| `pip`, `uv`, `poetry` | `requirements.txt`, `Pipfile.lock`, `poetry.lock`, `uv.lock`, `pyproject.toml` |
| `go` | `go.mod`, `go.sum` |
| `cargo` | `Cargo.toml`, `Cargo.lock` |
| `bundle`, `gem` | `Gemfile`, `Gemfile.lock` |
| `composer` | `composer.json`, `composer.lock` |
| `mvn`, `gradle` | `pom.xml`, `build.gradle`, `gradle.lockfile` |

Only manifest files that actually exist in the project root are scanned.

## Scan process

For each manifest found, the hook:

1. Runs `vulnetix scan --file <manifest> -f cdx17` to generate a CycloneDX v1.7 SBOM
2. Saves the SBOM to `.vulnetix/scans/<manifest>.<timestamp>.cdx.json`
3. Parses the SBOM with jq to extract vulnerability IDs, severities, package names, and versions
4. Deduplicates results across all scanned manifests

## Example output

After running `npm install`:

```
Vulnetix post-install scan: 3 vulnerabilities detected after `npm install`:

* CVE-2024-29041 (high) -- express@4.17.1
* CVE-2024-28849 (medium) -- follow-redirects@1.15.4
* GHSA-rv95-896h-c2vc (moderate) -- webpack-dev-middleware@5.3.3

Run `/vulnetix:fix <vuln-id>` to see remediation options
or `/vulnetix:exploits <vuln-id>` for exploit analysis.
```

If no vulnerabilities are detected after the install, the hook exits silently without producing output.
