#!/usr/bin/env bash
# Shared Vulnetix CLI detection and auto-installation.
# Source this file from any hook, then call ensure_vulnetix_cli.
# Sets VULNETIX_CMD on success; exits the caller with 0 on failure (non-blocking).
#
# Install priority: PATH lookup > common locations > shell rc > auto-install
# Auto-install priority: brew > scoop (Windows) > nix (NixOS) > GitHub releases > go install
# Aborts if none result in a callable vulnetix command.

# Probe PATH and common install locations for the vulnetix binary.
# Sets VULNETIX_CMD if found; returns 1 if not found.
_find_vulnetix() {
    if command -v vulnetix &>/dev/null; then
        VULNETIX_CMD="vulnetix"
        return 0
    fi

    for candidate in \
        "/home/linuxbrew/.linuxbrew/bin/vulnetix" \
        "/opt/homebrew/bin/vulnetix" \
        "/usr/local/bin/vulnetix" \
        "${HOME}/.local/bin/vulnetix" \
        "${HOME}/go/bin/vulnetix" \
        "${HOME}/.cargo/bin/vulnetix" \
        "${HOME}/scoop/shims/vulnetix.exe" \
        "${HOME}/scoop/shims/vulnetix"; do
        if [[ -x "$candidate" ]]; then
            VULNETIX_CMD="$candidate"
            return 0
        fi
    done

    # Try sourcing shell rc to pick up PATH modifications
    local shell_rc=""
    case "${SHELL:-}" in
        */zsh)  shell_rc="${HOME}/.zshrc" ;;
        */fish) shell_rc="${HOME}/.config/fish/config.fish" ;;
        *)      shell_rc="${HOME}/.bashrc" ;;
    esac
    if [[ -n "$shell_rc" ]] && [[ -f "$shell_rc" ]]; then
        VULNETIX_CMD=$(bash -c "source '$shell_rc' 2>/dev/null && command -v vulnetix" 2>/dev/null || true)
        if [[ -n "$VULNETIX_CMD" ]]; then
            return 0
        fi
    fi

    return 1
}

# Attempt to install vulnetix CLI using available package managers.
# Tries: brew > scoop (Windows) > nix (NixOS) > GitHub releases > go install
# Returns 0 on success, 1 on failure.
_install_vulnetix() {
    # 1. Homebrew (macOS and Linux)
    if command -v brew &>/dev/null; then
        if brew install vulnetix/tap/vulnetix 2>/dev/null; then
            return 0
        fi
    fi

    # 2. Scoop (Windows)
    if command -v scoop &>/dev/null; then
        if scoop bucket add vulnetix https://github.com/Vulnetix/scoop-bucket 2>/dev/null && \
           scoop install vulnetix 2>/dev/null; then
            return 0
        fi
    fi

    # 3. Nix (NixOS or nix package manager)
    if [[ -f /etc/NIXOS ]] || command -v nix &>/dev/null; then
        if command -v nix &>/dev/null; then
            if nix profile install github:Vulnetix/cli 2>/dev/null; then
                return 0
            fi
        fi
    fi

    # 4. GitHub releases (curl-based install for the right architecture)
    if command -v curl &>/dev/null || command -v wget &>/dev/null; then
        local os arch download_url install_dir
        os=$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')
        arch=$(uname -m 2>/dev/null)

        case "$arch" in
            x86_64|amd64)  arch="amd64" ;;
            aarch64|arm64) arch="arm64" ;;
            armv7*)        arch="armv7" ;;
            i386|i686)     arch="386" ;;
            *)             arch="" ;;
        esac

        case "$os" in
            linux|darwin) ;;
            mingw*|msys*|cygwin*) os="windows" ;;
            *) os="" ;;
        esac

        if [[ -n "$os" ]] && [[ -n "$arch" ]]; then
            local ext="tar.gz"
            [[ "$os" == "windows" ]] && ext="zip"

            # Get latest release tag from GitHub API
            local latest_tag
            if command -v curl &>/dev/null; then
                latest_tag=$(curl -fsSL "https://api.github.com/repos/Vulnetix/cli/releases/latest" 2>/dev/null | grep -o '"tag_name": *"[^"]*"' | head -1 | sed 's/.*"tag_name": *"//;s/"//')
            elif command -v wget &>/dev/null; then
                latest_tag=$(wget -qO- "https://api.github.com/repos/Vulnetix/cli/releases/latest" 2>/dev/null | grep -o '"tag_name": *"[^"]*"' | head -1 | sed 's/.*"tag_name": *"//;s/"//')
            fi

            if [[ -n "$latest_tag" ]]; then
                download_url="https://github.com/Vulnetix/cli/releases/download/${latest_tag}/vulnetix_${latest_tag#v}_${os}_${arch}.${ext}"
                install_dir="${HOME}/.local/bin"
                mkdir -p "$install_dir" 2>/dev/null

                local tmpdir
                tmpdir=$(mktemp -d)

                local success=false
                if command -v curl &>/dev/null; then
                    curl -fsSL "$download_url" -o "${tmpdir}/vulnetix.${ext}" 2>/dev/null && success=true
                elif command -v wget &>/dev/null; then
                    wget -q "$download_url" -O "${tmpdir}/vulnetix.${ext}" 2>/dev/null && success=true
                fi

                if [[ "$success" == "true" ]]; then
                    if [[ "$ext" == "tar.gz" ]]; then
                        tar -xzf "${tmpdir}/vulnetix.${ext}" -C "$tmpdir" 2>/dev/null
                    elif [[ "$ext" == "zip" ]]; then
                        unzip -q "${tmpdir}/vulnetix.${ext}" -d "$tmpdir" 2>/dev/null
                    fi

                    if [[ -f "${tmpdir}/vulnetix" ]]; then
                        mv "${tmpdir}/vulnetix" "${install_dir}/vulnetix"
                        chmod +x "${install_dir}/vulnetix"
                        rm -rf "$tmpdir"
                        return 0
                    fi
                fi
                rm -rf "$tmpdir"
            fi
        fi
    fi

    # 5. Go install (if Go is available)
    if command -v go &>/dev/null; then
        if go install github.com/Vulnetix/cli/cmd/vulnetix@latest 2>/dev/null; then
            return 0
        fi
    fi

    return 1
}

# Main entrypoint: find or install vulnetix CLI.
# Sets VULNETIX_CMD on success.
# On failure: emits a JSON systemMessage and returns 1.
# Usage in hooks:
#   source "$(dirname "$0")/ensure-vulnetix-cli.sh"
#   ensure_vulnetix_cli || exit 0
ensure_vulnetix_cli() {
    VULNETIX_CMD=""

    # Try to find existing installation
    if _find_vulnetix; then
        return 0
    fi

    # Not found — attempt auto-install
    if _install_vulnetix; then
        # Re-probe after install
        if _find_vulnetix; then
            return 0
        fi
    fi

    # All methods exhausted
    echo '{"systemMessage": "Vulnetix CLI not found and auto-install failed. Install manually: `brew install vulnetix/tap/vulnetix` (macOS/Linux), `scoop install vulnetix` (Windows), or download from https://github.com/Vulnetix/cli/releases"}'
    return 1
}
