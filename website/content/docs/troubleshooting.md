---
title: Troubleshooting
weight: 8
description: Common issues, diagnostics, and fixes for the Vulnetix Claude Code Plugin.
---

## Hook Not Triggering

**Symptoms:** No vulnerability scan output appears after `git commit` or `npm install`. No `.vulnetix/` directory is created.

**Diagnostics:**

1. Verify the plugin is installed:

   ```
   /plugins
   ```

   You should see `vulnetix` in the list.

2. Check that hooks are registered:

   ```
   /hooks
   ```

   You should see hooks like `vulnetix/hooks/pre-commit-scan` listed.

3. Verify the Vulnetix CLI is healthy and authenticated:

   ```bash
   vulnetix vdb status
   ```

**Fixes:**

- If the plugin is not listed, reinstall it following the [installation guide](/docs/getting-started/installation).
- If the CLI is not found, see [CLI Not Found](#cli-not-found) below.
- If the API returns an authentication error, run `vulnetix auth login`.

## API Unavailable or Not Authenticated

**Symptoms:** Hooks exit silently. Commands return authentication errors.

**Fix:**

```bash
vulnetix auth login
```

Then verify:

```bash
vulnetix vdb status -o json
```

The status response should show the API is healthy and your authentication token is valid.

## Skill Commands Not Working

**Symptoms:** Typing `/vulnetix fix CVE-2021-44228` does nothing or returns an error.

**Fix:** Use the colon syntax for all plugin skills and commands:

```
/vulnetix:fix CVE-2021-44228
```

Not:

```
/vulnetix fix CVE-2021-44228
```

The colon separates the plugin name from the skill/command name. A space between them is not recognized.

## Hook Timeout

**Symptoms:** Hook output is delayed or truncated. Claude Code reports a hook timeout.

**Possible causes:**

- Too many manifest files staged in a single commit
- Slow network connection to the Vulnetix API
- Large dependency trees producing slow SBOM generation

**Fixes:**

- Reduce the number of staged manifest files per commit. Stage dependency changes separately from code changes.
- Check your network connectivity: `vulnetix vdb status -o json`
- The pre-commit hook has a 120-second timeout. If you consistently hit this limit, consider committing fewer manifests at once.

## Memory File Issues

**Symptoms:** Skills or hooks report errors reading `.vulnetix/memory.yaml`. Vulnerability state is not persisted between sessions.

**Diagnostics:**

1. Check the file exists:

   ```bash
   ls -la .vulnetix/memory.yaml
   ```

2. Verify file permissions (must be readable and writable):

   ```bash
   stat .vulnetix/memory.yaml
   ```

3. Validate the schema version:

   ```bash
   head -5 .vulnetix/memory.yaml
   ```

   The file should start with `schema_version: 1`.

**Fixes:**

- If the file does not exist, run any hook or skill to create it (e.g., stage a manifest file and run `git commit`).
- If the file has a legacy location (`.vulnetix-memory.yaml` at the repo root), the pre-commit hook will migrate it automatically on the next run.
- If the file is corrupted, back it up and delete it. The next hook run will create a fresh one (previous vulnerability decisions will be lost).

## CLI Not Found

**Symptoms:** Hooks exit silently. Running `vulnetix` in the terminal returns "command not found".

**Diagnostics:**

The plugin hooks probe multiple locations for the `vulnetix` binary:

1. Standard PATH (`command -v vulnetix`)
2. Homebrew on Linux (`/home/linuxbrew/.linuxbrew/bin/vulnetix`)
3. Homebrew on macOS (`/opt/homebrew/bin/vulnetix`)
4. System-wide (`/usr/local/bin/vulnetix`)
5. Local bin (`~/.local/bin/vulnetix`)
6. Go bin (`~/go/bin/vulnetix`)
7. Cargo bin (`~/.cargo/bin/vulnetix`)
8. Shell rc sourcing (sources `~/.bashrc` or `~/.zshrc` in a subshell)

**Fixes:**

- If the CLI is installed but not on your PATH, source your shell config:

  ```bash
  ! source ~/.bashrc
  ```

  or

  ```bash
  ! source ~/.zshrc
  ```

- If the CLI is not installed, follow the [prerequisites guide](/docs/getting-started/prerequisites).

- If the CLI is installed in a non-standard location, add it to your PATH:

  ```bash
  export PATH="$PATH:/path/to/vulnetix/bin"
  ```

  Add this to your shell rc file for persistence.
