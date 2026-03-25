---
title: Data Structures
weight: 6
description: The .vulnetix/ directory and its contents -- memory files, SBOMs, and PoC source caches.
---

The Vulnetix Claude Code Plugin stores all local state in a `.vulnetix/` directory at the root of your repository. This directory is auto-created by hooks and skills on first use and is automatically added to `.gitignore` so it is never committed.

## Directory Layout

```
.vulnetix/
  memory.yaml          # Vulnerability state and tracking
  scans/               # CycloneDX SBOM files
    *.cdx.json
  pocs/                # Exploit proof-of-concept source cache
    <VULN_ID>/
      ...
```

## Key Properties

**Auto-created.** The `.vulnetix/` directory and its subdirectories are created automatically the first time a hook or skill runs. You never need to create them manually.

**Auto-ignored.** On creation, the directory is added to your repository's `.gitignore` file (creating the file if it does not exist). The contents are local to your machine and should never be committed.

**Never committed.** All data in `.vulnetix/` is local working state -- SBOMs, vulnerability memory, and cached PoC source files. None of it belongs in version control.

**Legacy migration.** If a `.vulnetix-memory.yaml` file exists at the repository root (the pre-directory layout), the pre-commit hook automatically migrates it to `.vulnetix/memory.yaml` on first run.

## Contents

{{< cards >}}
  {{< card link="memory-yaml" title="memory.yaml" subtitle="Vulnerability tracking state, decisions, and history." >}}
  {{< card link="sboms" title="SBOMs" subtitle="CycloneDX v1.7 scan output files." >}}
  {{< card link="pocs" title="PoC Source Cache" subtitle="Cached exploit proof-of-concept source files." >}}
{{< /cards >}}
