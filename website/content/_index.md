---
title: Vulnetix Claude Code Plugin
layout: hextra-home
---

{{< hextra/hero-badge link="https://github.com/Vulnetix/claude-code-plugin" >}}
  <span>GitHub</span>
  {{< icon name="arrow-circle-right" attributes="height=14" >}}
{{< /hextra/hero-badge >}}

<div class="hx-mt-8 hx-mb-8">
{{< hextra/hero-headline >}}
  Vulnerability Intelligence&nbsp;<br class="sm:hx-block hx-hidden" />for Claude Code
{{< /hextra/hero-headline >}}
</div>

<div class="hx-mb-10">
{{< hextra/hero-subtitle >}}
  Automated dependency scanning, exploit analysis, and fix intelligence&nbsp;<br class="sm:hx-block hx-hidden" />&mdash; built into your development workflow.
{{< /hextra/hero-subtitle >}}
</div>

<div class="vx-cta-row hx-mb-4">
  <a href="docs/getting-started" class="vx-btn-primary">Get Started</a>
  <a href="https://github.com/Vulnetix/claude-code-plugin" class="vx-btn-secondary" target="_blank" rel="noopener">View on GitHub</a>
</div>
<a href="https://www.vulnetix.com" class="vx-subtle-link" target="_blank" rel="noopener">Learn more at vulnetix.com &rarr;</a>

<div class="vx-hero-spacer"></div>

<div class="vx-feature-section vx-feature-scan">

## Automatic Security Scanning

Six event-driven hooks run automatically in your Claude Code workflow. Scan dependencies on every commit, detect vulnerabilities after package installs, gate manifest edits with risk data, and surface prior context when you mention a CVE.

<ul>
  <li>Pre-commit scanning</li>
  <li>Post-install detection</li>
  <li>Manifest edit gating</li>
  <li>Session dashboard</li>
  <li>Stop reminders</li>
  <li>CVE context injection</li>
</ul>

<a href="docs/hooks" class="vx-feature-link">Hook reference &rarr;</a>

</div>

<div class="vx-feature-section vx-feature-vdb">

## Vulnerability Intelligence

Six interactive skills give you deep vulnerability analysis on demand. Search packages for risk before adding them, analyze exploit intelligence, get fix recommendations with concrete manifest diffs, and build context-aware remediation plans.

<ul>
  <li>Package risk search</li>
  <li>Exploit analysis</li>
  <li>Fix intelligence</li>
  <li>Vulnerability lookup</li>
  <li>Exploit landscape search</li>
  <li>Remediation planning</li>
</ul>

<a href="docs/skills" class="vx-feature-link">Skill reference &rarr;</a>

</div>

<div class="vx-feature-section vx-feature-cicd">

## Direct CLI Access

Four deterministic commands give you raw VDB data without LLM analysis. Plus a bulk-triage agent that analyzes multiple vulnerabilities in parallel and produces prioritized triage reports.

<ul>
  <li>vdb-vuln</li>
  <li>vdb-vulns</li>
  <li>vdb-exploits-search</li>
  <li>vdb-remediation</li>
  <li>bulk-triage agent</li>
</ul>

<a href="docs/commands" class="vx-feature-link">Command reference &rarr;</a>

</div>

<div class="vx-feature-section vx-feature-data">

## Persistent Vulnerability Memory

All findings, decisions, and scan history persist in the `.vulnetix/` directory. A structured YAML memory file tracks every vulnerability from discovery through resolution, while CycloneDX SBOMs and cached PoC source code provide audit-ready artifacts.

<ul>
  <li>Structured memory file</li>
  <li>CycloneDX SBOMs</li>
  <li>PoC source caching</li>
  <li>Decision tracking</li>
  <li>Cross-session continuity</li>
</ul>

<a href="docs/data-structures" class="vx-feature-link">Data structure reference &rarr;</a>

</div>

<div class="vx-footer-links">
  <a href="https://docs.cli.vulnetix.com" target="_blank" rel="noopener">CLI Docs</a>
  <a href="https://redocly.github.io/redoc/?url=https://api.vdb.vulnetix.com/v1/spec" target="_blank" rel="noopener">VDB API Docs</a>
  <a href="https://github.com/Vulnetix/claude-code-plugin" target="_blank" rel="noopener">GitHub</a>
  <a href="https://www.vulnetix.com" target="_blank" rel="noopener">vulnetix.com</a>
</div>
