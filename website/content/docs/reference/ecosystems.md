---
title: Supported Ecosystems
weight: 1
description: Package ecosystems, registries, and manifest files supported by the Vulnetix Claude Code Plugin.
---

The Vulnetix Claude Code Plugin supports seven package ecosystems. Hooks automatically detect manifest files for each ecosystem, and commands accept ecosystem identifiers for filtering and context.

## Ecosystem Table

| Ecosystem | Registry | Manifest Files |
|-----------|----------|----------------|
| **npm** | npmjs.com | `package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml` |
| **Python** | PyPI | `requirements.txt`, `Pipfile.lock`, `poetry.lock`, `uv.lock` |
| **Go** | proxy.golang.org | `go.mod`, `go.sum` |
| **Rust** | crates.io | `Cargo.lock` |
| **Ruby** | RubyGems | `Gemfile.lock` |
| **Maven** | Maven Central | `pom.xml`, `gradle.lockfile` |
| **PHP** | Packagist | `composer.lock` |

## Ecosystem Identifiers

When passing `--ecosystem` flags to commands, use these lowercase identifiers:

| Identifier | Ecosystem |
|------------|-----------|
| `npm` | npm / Node.js |
| `pypi` | Python / PyPI |
| `go` | Go modules |
| `cargo` | Rust / Cargo |
| `rubygems` | Ruby / RubyGems |
| `maven` | Java / Maven Central |
| `packagist` | PHP / Packagist |
| `nuget` | .NET / NuGet |

## Manifest Detection

Hooks scan for manifest files using exact filename matching against the patterns listed above. Both top-level and nested manifests are detected (e.g., `packages/api/package.json` in a monorepo).

The [Pre-Commit Scan](/docs/hooks/pre-commit-scan) hook only processes manifests that are staged in the current commit. The [Post-Install Scan](/docs/hooks/post-install-scan) hook scans manifests affected by install commands.
