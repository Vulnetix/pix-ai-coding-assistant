---
title: Vulnerability Identifiers
weight: 2
description: All 78+ vulnerability identifier formats accepted by the Vulnetix VDB, grouped by category.
---

The Vulnetix VDB accepts 78+ vulnerability identifier formats. Any of these can be passed to the [vdb-vuln](/docs/commands/vdb-vuln) command, and cross-references between formats are resolved automatically.

## Primary Identifiers

These are the most widely used vulnerability identifiers.

| Prefix | Name | Example |
|--------|------|---------|
| **CVE** | Common Vulnerabilities and Exposures | `CVE-2021-44228` |
| **GHSA** | GitHub Security Advisory | `GHSA-jfh8-c2jp-5v3q` |

## Language-Specific Identifiers

Assigned by language-specific security databases.

| Prefix | Language/Ecosystem | Example |
|--------|-------------------|---------|
| **PYSEC** | Python | `PYSEC-2024-1234` |
| **GO** | Go | `GO-2024-1234` |
| **RUSTSEC** | Rust | `RUSTSEC-2024-0001` |

## Standards and Aggregators

Identifiers from vulnerability standards bodies and aggregation databases.

| Prefix | Name | Example |
|--------|------|---------|
| **EUVD** | EU Vulnerability Database | `EUVD-2024-1234` |
| **OSV** | Open Source Vulnerability | `OSV-2024-1234` |
| **GSD** | Global Security Database | `GSD-2024-1234` |
| **VDB** | VulDB | `VDB-123456` |
| **GCVE** | Global CVE | `GCVE-2024-1234` |

## Vendor Identifiers

Assigned by security vendors and research organizations.

| Prefix | Vendor / Source | Example |
|--------|----------------|---------|
| **SNYK** | Snyk | `SNYK-JS-EXPRESS-1234567` |
| **ZDI** | Zero Day Initiative | `ZDI-24-001` |
| **MSCVE** | Microsoft CVE | `MSCVE-2024-1234` |
| **MSRC** | Microsoft Security Response Center | `MSRC-CVE-2024-1234` |
| **TALOS** | Cisco Talos | `TALOS-2024-1234` |
| **EDB** | ExploitDB | `EDB-12345` |
| **WORDFENCE** | Wordfence (WordPress) | `WORDFENCE-2024-1234` |
| **PATCHSTACK** | Patchstack (WordPress) | `PATCHSTACK-2024-1234` |
| **MFSA** | Mozilla Foundation Security Advisory | `MFSA-2024-01` |
| **JVNDB** | Japan Vulnerability Notes | `JVNDB-2024-001234` |
| **CNVD** | China National Vulnerability Database | `CNVD-2024-12345` |
| **BDU** | Russian FSTEC Vulnerability Database | `BDU-2024-01234` |
| **HUNTR** | Huntr bug bounty | `HUNTR-1234-abcd` |

## Distribution Identifiers

Issued by Linux distributions and OS vendors for their patched packages.

| Prefix | Distribution | Example |
|--------|-------------|---------|
| **RHSA** | Red Hat Security Advisory | `RHSA-2025:1730` |
| **DSA** | Debian Security Advisory | `DSA-5678-1` |
| **DLA** | Debian LTS Advisory | `DLA-5678-1` |
| **USN** | Ubuntu Security Notice | `USN-6789-1` |
| **ALSA** | AlmaLinux Security Advisory | `ALSA-2025:1234` |
| **RLSA** | Rocky Linux Security Advisory | `RLSA-2025:1234` |
| **MGASA** | Mageia Security Advisory | `MGASA-2025-0001` |
| **OPENSUSE** | openSUSE Security Advisory | `OPENSUSE-SU-2025:0001-1` |
| **FreeBSD** | FreeBSD Security Advisory | `FreeBSD-SA-25:01` |
| **BIT** | Bitnami | `BIT-nginx-2024-1234` |

## Cross-Referencing

When you look up a vulnerability by any identifier, the VDB resolves all known aliases. For example, looking up `GHSA-jfh8-c2jp-5v3q` will also return its corresponding CVE ID, and vice versa. Aliases are stored in the `aliases` field of each vulnerability entry in [memory.yaml](/docs/data-structures/memory-yaml).
