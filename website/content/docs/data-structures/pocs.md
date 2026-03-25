---
title: PoC Source Cache
weight: 3
description: Cached exploit proof-of-concept source files downloaded for static analysis.
---

The PoC (proof-of-concept) source cache stores exploit code downloaded by the `/vulnetix:exploits` skill for static analysis.

## Path

```
.vulnetix/pocs/<VULN_ID>/
```

Each vulnerability gets its own subdirectory named by its primary identifier (e.g., `CVE-2021-44228`).

## Creation

PoC files are created by the `/vulnetix:exploits` skill when it retrieves exploit intelligence for a vulnerability. The skill downloads source files from public exploit databases and caches them locally.

## Sources

PoC files may be sourced from:

- **ExploitDB** -- public exploit database entries
- **Metasploit** -- Metasploit Framework modules
- **GitHub repos** -- public proof-of-concept repositories

## Static Analysis Only

PoC source files are cached strictly for **static analysis**. They are never executed. The `/vulnetix:exploits` skill reads the source code to understand exploit mechanics, attack vectors, and prerequisites -- it does not run the exploits.

## Lifecycle

- Files are downloaded on first use of `/vulnetix:exploits` for a given vulnerability
- Subsequent calls reuse the cached files
- The cache is local-only (`.vulnetix/` is in `.gitignore`) and can be safely deleted at any time
- Paths to cached PoC files are recorded in the `pocs` field of the corresponding vulnerability entry in `.vulnetix/memory.yaml`
