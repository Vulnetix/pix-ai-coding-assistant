---
title: Fix Intelligence
weight: 3
description: Fetch fix intelligence for a vulnerability and propose concrete remediation including manifest edits, breaking change analysis, and verification.
---

The Fix Intelligence skill fetches fix data for a vulnerability and proposes concrete, actionable remediation steps for the current repository. It identifies affected dependencies, determines installed versions, evaluates fix options (including dependency inlining), applies manifest edits, and verifies the result.

## Invocation

```
/vulnetix:fix <vuln-id>
```

For example:

```
/vulnetix:fix CVE-2021-44228
/vulnetix:fix GHSA-jfh8-c2jp-5v3q
```

## Workflow

### 0. Load Memory and GHAS Context

Before any fix analysis, the skill:

1. Loads `.vulnetix/memory.yaml` and checks for prior entries (status, decisions, CWSS priority from `/vulnetix:exploits`)
2. Checks cached CycloneDX SBOMs in `.vulnetix/scans/`
3. Queries Dependabot alerts and PRs for this vuln ID (if `gh` CLI is available)
4. Queries CodeQL alerts matching the vulnerability's CWE
5. Queries Secret Scanning alerts if the vulnerability relates to credential handling

If a Dependabot PR already proposes the same upgrade, the skill suggests reviewing and merging that PR instead of applying a manual fix.

### 1. Fetch Fix Data

Queries both V1 and V2 endpoints for maximum coverage:

```bash
vulnetix vdb fixes CVE-2021-44228 -o json
vulnetix vdb fixes CVE-2021-44228 -o json -V v2
```

### Fix Types

| Type | Description |
|------|-------------|
| **Registry upgrades** | Version bumps available in the package registry (npm, Maven Central, PyPI, etc.) |
| **Source patches** | Upstream commits or PRs that fix the vulnerability |
| **Distribution patches** | OS-level patches (Ubuntu, Debian, RHEL) for system packages |
| **Workarounds** | Configuration changes, input validation, selective imports |

### 2. Identify Affected Dependencies

Performs a deep filesystem scan including gitignored directories:

- Globs for all manifest and lockfiles across the project tree (including monorepo structures)
- Derives the installed version from lockfiles, manifests, and installed artifacts (e.g., `node_modules/`, `.venv/`, `.m2/`)
- Determines whether the dependency is direct or transitive
- Greps for all import/require statements referencing the vulnerable package

### 3. Evaluate Dependency Inlining

Before proposing a version bump, the skill evaluates whether the dependency can be replaced with first-party code. Inlining is viable when the affected code is open source, the used portion is small (under ~200 lines), and the functionality is self-contained with no deep internal dependency chain.

### 4. Present Fix Options

Fixes are categorized in priority order:

#### A0. Inline as First-Party Code (when viable)

Remove the dependency entirely and inline the specific functions used. Preserves original license attribution.

#### A. Version Bump (preferred)

| Current Version | Version Source | Target Version | Fix Source | Safe Harbour | Breaking Changes? |
|-----------------|---------------|----------------|------------|-------------|-------------------|
| 2.14.1 | Lockfile: pom.xml | 2.17.1 | Registry: Maven Central | 0.82 (Reasonable) | Minor API changes |

#### B. Patch

Source patches (upstream commits) or distribution patches (OS-level packages).

#### C. Workaround

Temporary mitigations: configuration changes, input validation, network isolation, selective imports.

#### D. Advisory Guidance

Vendor advisory links, CISA KEV due dates, community discussion pointers.

### Safe Harbour Confidence Score

Every fix option includes a Safe Harbour confidence score (0.00--1.00):

| Tier | Range | Meaning |
|------|-------|---------|
| **High** | > 0.90 | Patch-level bump, official registry release, well-tested |
| **Reasonable** | 0.35--0.90 | Minor version bump, backward-compatible, distro-repackaged patch |
| **Low** | < 0.35 | Major version bump, unofficial patch, significant API changes |

Adjustment factors include: registry-published changelog (+0.15), distro-maintained patch (+0.10), upstream commit verified in release tag (+0.10), major version jump (-0.25), no test suite (-0.15), transitive dependency (-0.10).

### Mandatory Version Reporting

Every output includes:

```
Package: log4j-core
Current Version: 2.14.1 (source: lockfile: pom.xml)
Fix Target: 2.17.1 (source: registry: Maven Central)
Safe Harbour: 0.82 (Reasonable confidence)
```

### 5. Apply Fixes

After presenting options, the skill applies the preferred fix:

1. **Back up** lockfiles and manifests for rollback
2. **Edit** version constraints in all affected manifest files (handling overrides for npm `overrides`, yarn `resolutions`, pnpm `pnpm.overrides`, Maven `dependencyManagement`, Cargo `[patch]`)
3. **Refactor imports** to minimize attack surface where possible (e.g., `import lodash` to `import get from 'lodash/get'`)
4. **Dry-run** the package manager to verify resolution succeeds
5. **Restore from backup** if any step fails

### 6. Post-Fix Verification

After applying fixes:

1. Runs the project test suite (`npm test`, `pytest`, `go test ./...`, `cargo test`, etc.)
2. Re-scans for the vulnerability and persists the CycloneDX SBOM to `.vulnetix/scans/`
3. Reports the result with full version details and rollback instructions

### 7. Update Vulnerability Memory

Updates `.vulnetix/memory.yaml` with fix results, version changes, GHAS sync data, and manifest scan metadata.

## Decision Recording

The skill records user decisions using these values:

| Decision | Developer Language | When |
|----------|-------------------|------|
| `fix-applied` | Fix applied | Upgrade, patch, or code fix applied |
| `mitigated` | Workaround in place | Config change, input validation, selective import |
| `risk-accepted` | Risk acknowledged, shipping as-is | Consciously accepting with documented reason |
| `deferred` | Fix planned for later | Will address, but not right now |
| `not-affected` | Not affected | Package absent, code unreachable |
| `risk-avoided` | Removed the exposure | Dependency removed, feature disabled |
| `inlined` | Replaced with own code | Dependency replaced with first-party implementation |
| `risk-transferred` | Handled by platform or infrastructure | WAF, CDN, runtime sandbox handles it |

The skill **always asks before applying edits** to your codebase.

## Example

```
/vulnetix:fix CVE-2021-44228
```

The skill loads prior memory, fetches fix data showing `log4j-core@2.17.1` as the registry fix, finds `log4j-core@2.14.1` in `pom.xml`, presents the version bump as Option A with Safe Harbour 0.82, backs up `pom.xml`, applies the version edit, runs `mvn dependency:resolve -DdryRun` to verify, and updates the memory file with `status: fixed`.
