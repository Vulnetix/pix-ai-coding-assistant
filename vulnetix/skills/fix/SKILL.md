---
name: fix
description: Get fix intelligence for a vulnerability and propose concrete remediation for the current repository
argument-hint: <vuln-id>
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep, Edit, Write, WebFetch
---

# Vulnetix Fix Intelligence Skill

This skill fetches fix intelligence for a vulnerability and proposes concrete, actionable remediation steps for the current repository.

## Workflow

### Step 1: Fetch Fix Data

Run the Vulnetix VDB fixes command for both V1 and V2 endpoints:

```bash
vulnetix vdb fixes "$ARGUMENTS" -o json
vulnetix vdb fixes "$ARGUMENTS" -o json -V v2
```

**V1 response** (basic fixes):
```json
{
  "fixes": [
    {
      "type": "version",
      "package": "log4j-core",
      "ecosystem": "maven",
      "fixedIn": "2.17.1",
      "description": "Upgrade to patched version"
    }
  ]
}
```

**V2 response** (enhanced with registry, distro, source fixes):
```json
{
  "fixes": [
    {
      "type": "registry",
      "package": "log4j-core",
      "ecosystem": "maven",
      "fixedIn": "2.17.1",
      "registryUrl": "https://repo1.maven.org/...",
      "releaseDate": "2021-12-28"
    },
    {
      "type": "distro-patch",
      "distro": "ubuntu",
      "version": "20.04",
      "package": "liblog4j2-java",
      "patchVersion": "2.17.1-0ubuntu1",
      "aptCommand": "sudo apt-get install liblog4j2-java=2.17.1-0ubuntu1"
    },
    {
      "type": "source-fix",
      "commitUrl": "https://github.com/apache/logging-log4j2/commit/abc123",
      "patchUrl": "https://github.com/apache/logging-log4j2/commit/abc123.patch"
    }
  ]
}
```

### Step 2: Fetch Vulnerability Context

Get additional context about the vulnerability:

```bash
vulnetix vdb vuln "$ARGUMENTS" -o json
vulnetix vdb affected "$ARGUMENTS" -o json -V v2
```

Extract:
- **Affected package/product** names
- **Vulnerable version ranges** (e.g., `>=2.0.0, <2.17.1`)
- **CVSS/severity** (to assess urgency)
- **CISA KEV due date** (if applicable)

### Step 3: Analyze Repository Dependencies

Use **Glob** to find manifest files, then **Read** them to identify affected dependencies:

**npm** (`package.json`):
```json
{
  "dependencies": {
    "vulnerable-package": "1.2.3"
  }
}
```

**Python** (`requirements.txt`, `pyproject.toml`, `Pipfile`):
```
vulnerable-package==1.2.3
```

**Go** (`go.mod`):
```
require vulnerable-package v1.2.3
```

**Cargo** (`Cargo.toml`):
```toml
[dependencies]
vulnerable-package = "1.2.3"
```

**Maven** (`pom.xml`):
```xml
<dependency>
    <groupId>org.example</groupId>
    <artifactId>vulnerable-package</artifactId>
    <version>1.2.3</version>
</dependency>
```

Determine:
1. **Is the vulnerable package installed?** (exact name match)
2. **What version is installed?** (compare with vulnerable range)
3. **Is it a direct or transitive dependency?** (look for lock files)

If the package is **not found**, inform the user that the vulnerability may not affect this repository.

### Step 4: Present Fix Options

Categorize fixes into 4 categories (A-D) and present them in priority order:

---

#### **A. Version Bump** (Preferred)

If a patched version is available in the registry:

| Current Version | Target Version | Breaking Changes? | Manifest File |
|-----------------|----------------|-------------------|---------------|
| 2.14.1 | 2.17.1 | Likely (major) | pom.xml |

**Action:** Update dependency version in manifest file.

**Risk assessment:**
- **Patch version** (2.14.1 → 2.14.2): Low risk, backward compatible
- **Minor version** (2.14.x → 2.15.0): Medium risk, check changelog
- **Major version** (2.x → 3.0): High risk, breaking changes expected

---

#### **B. Patch** (Alternative)

If a source patch is available:

| Patch Source | Type | Applicability |
|--------------|------|---------------|
| GitHub commit abc123 | Source fix | Can be applied to local fork |
| Ubuntu 20.04 | Distro patch | Only if running on Ubuntu |

**Action:** Download patch and apply to local dependency copy (advanced users only).

---

#### **C. Workaround** (Temporary Mitigation)

If no fix is available yet, provide temporary mitigations:

- **Configuration changes** (disable vulnerable feature, enable safeguards)
- **Input validation** (sanitize untrusted input)
- **Network isolation** (firewall rules, rate limiting)
- **Vendor-recommended workarounds** (from advisory)

**Action:** Apply configuration changes to relevant files.

---

#### **D. Advisory Guidance** (Informational)

- **Vendor advisory links** (official fix documentation)
- **CISA KEV due date** (if listed, agencies must patch by this date)
- **Community discussion** (GitHub issues, Stack Overflow)

**Action:** No immediate action, but monitor for updates.

---

### Step 5: Propose Concrete Changes

For the **preferred fix option** (usually Version Bump), show the **exact edits** using the **Edit** tool:

**Example for Maven (pom.xml):**

```diff
<dependency>
    <groupId>org.apache.logging.log4j</groupId>
    <artifactId>log4j-core</artifactId>
-   <version>2.14.1</version>
+   <version>2.17.1</version>
</dependency>
```

**Example for npm (package.json):**

```diff
{
  "dependencies": {
-   "express": "4.17.1",
+   "express": "4.18.2",
    "other-package": "1.0.0"
  }
}
```

**DO NOT APPLY THE EDIT YET** — show the diff and wait for user approval.

If a workaround configuration change is needed, show that edit as well.

### Step 6: Planning Interview

Ask the user:

1. **Which fix approach would you like to use?** (Version Bump / Patch / Workaround)
2. **Should I apply the changes now?** (If yes, execute the edits with **Edit** or **Write** tools)
3. **Run tests after applying the fix?** (If yes, identify test command from manifest and run it)
4. **Verify the fix with `vulnetix scan`?** (Recommend re-scanning to confirm vulnerability is resolved)

**Suggested workflow after user approves:**

```bash
# Apply the edit (already done via Edit tool)

# Install updated dependency
npm install          # for npm
pip install -r requirements.txt  # for Python
go mod tidy          # for Go
cargo update         # for Rust
mvn install          # for Maven

# Run tests (if available)
npm test             # or appropriate test command

# Verify fix
vulnetix scan --file <manifest> -f json
```

If the scan still shows the vulnerability, explain that it may be a transitive dependency and suggest:
- Using dependency update tools (`npm audit fix`, `cargo update`, etc.)
- Manually updating the parent dependency that pulls in the vulnerable package
- Checking if a newer version of the parent dependency exists

## Error Handling

- If `vulnetix vdb fixes` returns no results, inform the user that no official fix is available yet and suggest workarounds or monitoring
- If the package is not found in the repository, confirm with the user whether it's a transitive dependency
- If manifest format is complex (Gradle, multi-module Maven), ask the user which file to edit
- If breaking changes are expected, warn the user and recommend testing thoroughly

## Security Notes

- **Always upgrade to the latest patched version** unless there are known regressions
- If a vulnerability has a **CISA KEV due date**, prioritize it as urgent
- For **critical/high severity** vulnerabilities, recommend immediate patching even if it requires major version bumps
- Never downgrade to an older version as a "fix" — this may introduce other vulnerabilities

## Integration with Other Skills

- If exploits are known, suggest running `/vulnetix:exploits $ARGUMENTS` first to understand impact
- After fixing, suggest re-running `/vulnetix:package-search` if adding new dependencies as alternatives
