---
title: memory.yaml
weight: 1
description: Full schema documentation for the .vulnetix/memory.yaml vulnerability tracking file.
---

The `memory.yaml` file is the central state file for vulnerability tracking. It records every vulnerability discovered by hooks, enriched by skills, and decided upon by you.

**Path:** `.vulnetix/memory.yaml`

## Schema Version

```yaml
schema_version: 1
```

All memory files carry a `schema_version` field. The current version is `1`.

## Manifests Section

The `manifests` section tracks every dependency manifest that has been scanned.

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

| Field | Type | Description |
|-------|------|-------------|
| `path` | string | Relative path to the manifest file |
| `ecosystem` | string | Package ecosystem (`npm`, `pypi`, `go`, `cargo`, `maven`, `rubygems`, `packagist`) |
| `last_scanned` | string | ISO 8601 timestamp of the last scan |
| `packages_searched` | bool | Whether VDB package searches were run |
| `results_path` | string | Path to the package search results JSON file |
| `scan_source` | string | What triggered the scan (`hook`, `skill`, `manual`) |

The post-install scan hook writes additional fields (`sbom_generated`, `sbom_path`, `vuln_count`) when it generates CycloneDX SBOMs.

## Vulnerabilities Section

Each vulnerability is tracked as an entry under `vulnerabilities`:

```yaml
vulnerabilities:
  - id: CVE-2024-29041
    aliases:
      - GHSA-rv95-896h-c2vc
    package: express
    ecosystem: npm
    discovery:
      date: "2025-03-15T10:30:00Z"
      source: hook
      file: package.json
      sbom: .vulnetix/scans/package.json.1710495000.cdx.json
    versions:
      current: "4.17.1"
      current_source: package-lock.json
      fixed_in: "4.19.2"
      fix_source: vdb
    severity:
      cvss_score: 6.1
      cvss_vector: "CVSS:3.1/AV:N/AC:L/PR:N/UI:R/S:C/C:L/I:L/A:N"
      epss: 0.00045
      level: MEDIUM
    safe_harbour: true
    status: under_investigation
    justification: null
    action_response: null
    threat_model: null
    pocs: []
    cwss:
      score: 62
      priority: P2
    dependabot:
      alert_number: 42
      alert_state: open
      pr_number: null
      pr_state: null
    code_scanning:
      cwe_match: false
      reachable: null
    secret_scanning:
      relevant: false
    decision:
      choice: investigating
      reason: null
      date: "2025-03-15T10:30:00Z"
    history:
      - date: "2025-03-15T10:30:00Z"
        event: discovered
        detail: "Found in package.json by pre-commit hook"
```

### Core Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Primary vulnerability identifier (CVE, GHSA, etc.) |
| `aliases` | list | Other identifiers for the same vulnerability |
| `package` | string | Affected package name |
| `ecosystem` | string | Package ecosystem |

### Discovery Block

Records how and when the vulnerability was first found.

| Field | Type | Description |
|-------|------|-------------|
| `date` | string | ISO 8601 discovery timestamp |
| `source` | string | Discovery method (`hook`, `skill`, `manual`) |
| `file` | string | Manifest file where the vulnerability was found |
| `sbom` | string | Path to the SBOM that contained the finding |

### Versions Block

Tracks the affected and fixed versions.

| Field | Type | Description |
|-------|------|-------------|
| `current` | string | Currently installed version |
| `current_source` | string | File the current version was read from |
| `fixed_in` | string | Version that fixes the vulnerability |
| `fix_source` | string | Where the fix version was determined (`vdb`, `dependabot`, `manual`) |

### Severity Block

| Field | Type | Description |
|-------|------|-------------|
| `cvss_score` | float | CVSS numeric score |
| `cvss_vector` | string | Full CVSS vector string |
| `epss` | float | EPSS probability (0.0 -- 1.0) |
| `level` | string | Severity level (`CRITICAL`, `HIGH`, `MEDIUM`, `LOW`) |

### Integration Fields

| Field | Type | Description |
|-------|------|-------------|
| `dependabot` | object | Dependabot alert number, state, PR number, PR state |
| `code_scanning` | object | CodeQL CWE match status and reachability signal |
| `secret_scanning` | object | Whether the package handles credentials |
| `cwss` | object | CWSS score and priority level (P1--P4) |
| `pocs` | list | Cached proof-of-concept file paths |
| `safe_harbour` | bool | Whether the vulnerability was found via safe harbour scan |
| `threat_model` | string | Free-text threat model notes |

### Status and Decision

**Status** follows the VEX status model:

| Status | Meaning |
|--------|---------|
| `not_affected` | The vulnerability does not affect this project |
| `affected` | The vulnerability affects this project |
| `fixed` | The vulnerability has been fixed |
| `under_investigation` | The vulnerability is being investigated |

**Decision** records the user's triage choice:

| Decision | Meaning |
|----------|---------|
| `investigating` | Currently being investigated (default for new findings) |
| `fix-applied` | A fix has been applied |
| `mitigated` | Mitigating controls are in place |
| `risk-accepted` | The risk has been consciously accepted |
| `deferred` | Fix planned but not yet applied |
| `not-affected` | Determined to not affect this project |
| `removed` | The affected dependency has been removed |
| `inlined` | The affected code has been vendored/inlined with patches |
| `risk-transferred` | Risk transferred to another party |

### History

The `history` list records all events related to the vulnerability:

```yaml
history:
  - date: "2025-03-15T10:30:00Z"
    event: discovered
    detail: "Found in package.json by pre-commit hook"
  - date: "2025-03-16T09:00:00Z"
    event: bulk-triage
    detail: "P2 -- EPSS 0.00045, no public exploits, direct dependency"
  - date: "2025-03-17T14:00:00Z"
    event: decision
    detail: "User set decision to fix-applied"
```

## What Writes What

Different tools write different fields, with clear boundaries:

| Tool | Fields Written |
|------|---------------|
| **Hooks** (pre-commit) | Update `manifests` section with package search metadata and results paths |
| **Hooks** (post-install) | Create new vulnerability entries with `discovery`, `versions.current`, `status: under_investigation`, update `manifests` section with SBOM paths |
| **Skills** (fix, exploits, etc.) | Update `severity`, `cwss`, `pocs`, `dependabot`, `code_scanning`, `secret_scanning`, `threat_model` |
| **Bulk Triage agent** | Update `severity`, `cwss`, add `history` entries |
| **User decisions only** | `status`, `decision.choice`, `decision.reason`, `justification`, `action_response` |

The critical boundary: **only user decisions change `status` and `decision`**. Hooks and skills enrich data but never make triage decisions on your behalf.
