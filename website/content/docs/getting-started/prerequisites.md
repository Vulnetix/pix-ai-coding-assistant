---
title: "Prerequisites"
weight: 1
description: "Install the Vulnetix CLI, authenticate, and set up jq before adding the plugin."
---

The plugin shells out to the Vulnetix CLI for scanning and API access, and uses `jq` for hook JSON processing. Both must be available on your `PATH` before you install the plugin.

## Install the Vulnetix CLI

Choose whichever method suits your environment. See the [CLI documentation](https://docs.cli.vulnetix.com/) for full details.

### macOS / Linux (curl)

```bash
curl -fsSL https://cli.vulnetix.com/install.sh | bash
```

### Homebrew

```bash
brew install vulnetix/tap/vulnetix
```

### Go install

```bash
go install github.com/Vulnetix/cli/cmd/vulnetix@latest
```

### Windows (PowerShell)

```powershell
irm https://cli.vulnetix.com/install.ps1 | iex
```

## Authenticate

Run the login command to open browser-based OAuth and store your credentials locally:

```bash
vulnetix auth login
```

A browser window will open. Sign in with your Vulnetix account and authorize the CLI. The token is saved to `~/.config/vulnetix/` automatically.

## Verify Connectivity

Confirm the CLI can reach the Vulnetix VDB API and that your credentials are valid:

```bash
vulnetix vdb status
```

You should see output similar to:

```
api:  healthy
auth: ok
```

If `auth` shows `unauthorized`, re-run `vulnetix auth login`. If `api` shows `unreachable`, check your network connection and proxy settings.

## Install jq

Several plugin hooks parse JSON output from the CLI. `jq` must be installed and on your `PATH`.

### macOS

```bash
brew install jq
```

### Debian / Ubuntu

```bash
sudo apt-get install jq
```

### Other platforms

Download binaries or find package instructions at [stedolan.github.io/jq](https://stedolan.github.io/jq/).

---

Once the CLI is authenticated and `jq` is available, proceed to [Installation](../installation/).
