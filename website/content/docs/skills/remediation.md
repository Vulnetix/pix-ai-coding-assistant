---
title: Remediation Planning
weight: 6
description: Generate a context-aware remediation plan with registry fixes, distribution patches, workarounds, CWE guidance, and verification steps.
---

The Remediation Planning skill generates a comprehensive, context-aware remediation plan for a vulnerability using the VDB V2 remediation API. It auto-detects your repository's ecosystem, package manager, installed versions, container images, and OS to provide targeted fix guidance.

**How this differs from [`/vulnetix:fix`](fix):** The Fix Intelligence skill fetches V1 fix data and proposes manual manifest edits. This skill uses the V2 `remediation plan` endpoint, which provides **context-aware** guidance (ecosystem, version, OS, container), **CWE remediation strategies**, **CrowdSec live threat intelligence**, **workaround effectiveness scoring**, and **verification commands** per package manager. The remediation plan is broader -- it includes distribution patches, container context, and CWE-specific strategies that the fix skill does not cover.

## Invocation

```
/vulnetix:remediation <vuln-id>
```

For example:

```
/vulnetix:remediation CVE-2021-44228
/vulnetix:remediation GHSA-jfh8-c2jp-5v3q
```

## Workflow

### 1. Load Memory and Detect Repository Context

The skill:

1. Loads `.vulnetix/memory.yaml` and displays any prior state
2. Detects the repository ecosystem and package manager from manifest files
3. Identifies the affected package (from memory or via a quick VDB lookup)
4. Detects the installed version using the lockfile/manifest/installed artifacts chain
5. Checks for Containerfiles or Dockerfiles to extract the base image for OS-specific patches

### 2. Auto-Populate Context Flags

The skill automatically builds CLI flags from the repository state:

| Flag | Source |
|------|--------|
| `--ecosystem` | Manifest file detection |
| `--package-name` | VDB response or memory |
| `--current-version` | Lockfile or manifest |
| `--package-manager` | Manifest file type (e.g., `package-lock.json` = npm, `yarn.lock` = yarn) |
| `--purl` | Constructed from ecosystem + name + version (e.g., `pkg:maven/org.apache.logging.log4j/log4j-core@2.14.1`) |
| `--container-image` | Extracted from `Containerfile` or `Dockerfile` `FROM` directive |
| `--os` | From `/etc/os-release` or inferred from container base image |
| `--vendor` | From VDB affected products |
| `--product` | From VDB affected products |

Two flags are always set:

- `--include-guidance` -- includes CWE-specific remediation strategies
- `--include-verification-steps` -- includes per-package-manager verification commands

### 3. Execute Remediation Plan Query

```bash
vulnetix vdb remediation plan CVE-2021-44228 -V v2 \
  --ecosystem maven --package-name log4j-core --current-version 2.14.1 \
  --package-manager maven --include-guidance --include-verification-steps -o json
```

The V2 remediation endpoint is the most comprehensive single endpoint -- it aggregates data from registry fixes, source fixes, distribution patches, workarounds, CWE guidance, and KEV data into one response.

## Response Sections

### Vulnerability Summary

```
CVE-2021-44228 -- Apache Log4j2 JNDI injection
Remote code execution via crafted JNDI lookup patterns
Severity: 10.0 (Critical)  |  EPSS: 0.97
```

### CrowdSec Threat Activity

When CrowdSec data is available in the response, the skill presents live threat intelligence:

```
Live Exploitation: Active
Sightings: 50,000 from 12,000 unique IPs
Last seen: 2024-03-15
Source countries: CN, RU, US
MITRE techniques: Attackable from the internet, Can run arbitrary commands
```

If no CrowdSec data is available, this section is omitted.

### Registry Fixes

Version upgrades per ecosystem:

| Ecosystem | Package | Current | Fix Version | Verified | Confidence | Registry |
|-----------|---------|---------|-------------|----------|------------|----------|
| maven | log4j-core | 2.14.1 | 2.17.1 | Yes | High | Maven Central |

Safe Harbour confidence tiers apply:

| Tier | Range | Typical Fix Type |
|------|-------|------------------|
| **High** | > 0.90 | Patch-level bump, official registry release |
| **Reasonable** | 0.35--0.90 | Minor version bump, backward-compatible |
| **Low** | < 0.35 | Major version bump, significant API changes |

### Source Fixes

Upstream commits and PRs:

```
Upstream fix: https://github.com/apache/logging-log4j2/commit/abc123
  SHA: abc123
  Author: rgoers
  Message: Restrict JNDI lookups to prevent RCE
  Repository health: active (daily commits, 50+ contributors)
```

### Distribution Patches

Available when `--os` or `--container-image` context was provided:

| Distro | Patch ID | Affected Packages | Priority |
|--------|----------|-------------------|----------|
| Ubuntu 22.04 | USN-XXXX-X | liblog4j2-java | High |

### Workarounds

Interim mitigations with effectiveness scoring:

```
Workaround: Set log4j2.formatMsgNoLookups=true
  Effectiveness: 85/100
  Applicable versions: 2.10.0 -- 2.16.0
  Requires restart: Yes
  Verification: Check JVM args include -Dlog4j2.formatMsgNoLookups=true
```

### CWE Guidance

Weakness-specific remediation strategies from the API:

```
CWE-502: Deserialization of Untrusted Data
Remediation strategy:
  Avoid deserializing untrusted data. If deserialization is necessary,
  use allowlists to restrict which classes can be instantiated...

Verification guidance:
  Ensure no untrusted input reaches deserialization entry points...
```

### Verification Steps

Per-package-manager commands to verify the fix:

```
Verify the fix:
  npm: npm audit --json | jq '.vulnerabilities["express"]'
  maven: mvn dependency:tree | grep log4j-core
  pip: pip show <package> | grep Version
```

## Cross-References

After presenting the plan, the skill surfaces:

- Existing Dependabot PRs that propose the same upgrade
- Prior `/vulnetix:exploits` analysis (CWSS priority) from the memory file
- Prior `/vulnetix:fix` proposals

And recommends:

- `/vulnetix:exploits <vuln-id>` -- for exploit intelligence and threat modeling
- `/vulnetix:vuln <vuln-id>` -- for full vulnerability details
- `/vulnetix:exploits-search --ecosystem <eco>` -- to discover related exploited vulnerabilities

## Memory Updates

After generating the plan, the skill updates `.vulnetix/memory.yaml`:

- Sets `versions.fixed_in` and `versions.fix_source` from registry fix data
- Updates `severity` and `safe_harbour` from CVSS data
- Merges any newly discovered aliases
- Appends `event: remediation-plan` to history with a summary of fix options found

If the user applies a fix during the conversation, the skill records `status: fixed` and `decision.choice: fix-applied`.

## Example

```
/vulnetix:remediation CVE-2021-44228
```

The skill detects Maven as the ecosystem from `pom.xml`, finds `log4j-core@2.14.1` installed, constructs the PURL `pkg:maven/org.apache.logging.log4j/log4j-core@2.14.1`, queries the V2 remediation API with full context, and presents: a registry fix to 2.17.1 (High confidence), an upstream commit link, a `formatMsgNoLookups` workaround (85/100 effectiveness), CWE-502 guidance, and Maven verification commands.
