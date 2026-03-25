#!/usr/bin/env bash
set -uo pipefail

# Pre-commit vulnerability scan hook for Vulnetix Claude Code Plugin
# Intercepts git commit commands, extracts packages from staged manifest files,
# and launches background VDB package searches that don't block the commit.
# Always exits 0 (never blocks commits) — informational only.
#
# Tooling philosophy (applies to all hooks, skills, and commands):
#   Output:   Markdown is the primary format — text the AI renders directly
#   Visuals:  Mermaid diagrams (no deps) for charts/graphs/flows;
#             if uv available, matplotlib/plotly to .vulnetix/ with mermaid fallback
#   JSON:     jq (required dependency for this hook)
#   YAML:     grep/sed/awk — no yq dependency assumed
#   Complex:  uv run --with <deps> > python3 stdlib > manual analysis
#   Rule:     Never assume any runtime; always check with command -v first

# Required: jq for JSON processing
if ! command -v jq &>/dev/null; then
    exit 0
fi

# Read JSON from stdin and check for git commit early (fast exit path)
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
if [[ ! "$COMMAND" =~ git[[:space:]]+commit ]]; then
    exit 0
fi

VULNETIX_DIR=".vulnetix"
MEMORY_FILE="${VULNETIX_DIR}/memory.yaml"
SCANS_DIR="${VULNETIX_DIR}/scans"

# Known manifest files
MANIFEST_PATTERNS=(
    "package.json"
    "package-lock.json"
    "yarn.lock"
    "pnpm-lock.yaml"
    "requirements.txt"
    "Pipfile.lock"
    "poetry.lock"
    "uv.lock"
    "go.mod"
    "go.sum"
    "Gemfile.lock"
    "Cargo.lock"
    "pom.xml"
    "gradle.lockfile"
    "composer.lock"
)

# --- Ecosystem detection ---

manifest_to_ecosystem() {
    local filename="$1"
    case "$filename" in
        package.json|package-lock.json|yarn.lock|pnpm-lock.yaml) echo "npm" ;;
        requirements.txt|Pipfile.lock|poetry.lock|uv.lock) echo "pypi" ;;
        go.mod|go.sum) echo "go" ;;
        Cargo.lock) echo "cargo" ;;
        pom.xml|gradle.lockfile) echo "maven" ;;
        Gemfile.lock) echo "rubygems" ;;
        composer.lock) echo "packagist" ;;
        *) echo "unknown" ;;
    esac
}

# --- Package extraction from staged file content ---

# Extract package name/version pairs from a staged manifest file.
# Returns tab-separated "name\tversion" lines.
# Handles source manifests and select lock files; skips unparseable formats.
extract_packages_from_staged() {
    local file_path="$1"
    local filename
    filename=$(basename "$file_path")

    # Read staged content (falls back to working copy)
    local content
    content=$(git show ":${file_path}" 2>/dev/null || cat "$file_path" 2>/dev/null)
    [[ -z "$content" ]] && return

    case "$filename" in
        package.json)
            echo "$content" | jq -r '
                [(.dependencies // {}), (.devDependencies // {})] | add // {} |
                to_entries[] | "\(.key)\t\(.value | gsub("[\\^~>=<]"; ""))"
            ' 2>/dev/null
            ;;
        requirements.txt)
            echo "$content" | grep -v '^\s*#\|^\s*-\|^\s*$' | \
                sed 's/\s*#.*//' | \
                sed 's/\[.*\]//' | \
                awk -F'[><=!~; ]+' '{
                    pkg=$1; ver="unknown"
                    if (NF > 1 && $2 != "") ver=$2
                    if (pkg != "") print pkg "\t" ver
                }' 2>/dev/null
            ;;
        go.mod)
            echo "$content" | awk '
                /^require \(/ { in_block=1; next }
                in_block && /^\)/ { in_block=0; next }
                in_block && /^\s+\S/ { gsub(/^\s+/, ""); print $1 "\t" $2 }
                /^require [^(]/ { print $2 "\t" $3 }
            ' 2>/dev/null
            ;;
        Cargo.lock)
            echo "$content" | awk '
                /^\[\[package\]\]/ { in_pkg=1; name=""; version="" }
                in_pkg && /^name = / { gsub(/"/, "", $3); name=$3 }
                in_pkg && /^version = / { gsub(/"/, "", $3); version=$3 }
                in_pkg && name != "" && version != "" { print name "\t" version; in_pkg=0 }
            ' 2>/dev/null
            ;;
        Pipfile.lock)
            echo "$content" | jq -r '
                [(.default // {}), (.develop // {})] | add // {} |
                to_entries[] | "\(.key)\t\(.value.version // "unknown" | gsub("=="; ""))"
            ' 2>/dev/null
            ;;
        composer.lock)
            echo "$content" | jq -r '
                [(.packages // []), (."packages-dev" // [])] | add // [] |
                .[] | "\(.name)\t\(.version // "unknown")"
            ' 2>/dev/null
            ;;
        gradle.lockfile)
            echo "$content" | grep -v '^\s*#\|^\s*$\|^empty=' | \
                awk -F'[=:]' '{ if (NF >= 3) print $1 ":" $2 "\t" $3 }' 2>/dev/null
            ;;
        pom.xml)
            echo "$content" | awk '
                /<dependency>/ { in_dep=1; gid=""; aid=""; ver="" }
                in_dep && /<groupId>/ { gsub(/<[^>]*>/, ""); gsub(/^[[:space:]]+|[[:space:]]+$/, ""); gid=$0 }
                in_dep && /<artifactId>/ { gsub(/<[^>]*>/, ""); gsub(/^[[:space:]]+|[[:space:]]+$/, ""); aid=$0 }
                in_dep && /<version>/ { gsub(/<[^>]*>/, ""); gsub(/^[[:space:]]+|[[:space:]]+$/, ""); ver=$0 }
                /<\/dependency>/ { if (gid != "" && aid != "") print gid ":" aid "\t" (ver != "" ? ver : "unknown"); in_dep=0 }
            ' 2>/dev/null
            ;;
        # Skip unparseable lock files: package-lock.json, yarn.lock, pnpm-lock.yaml,
        # poetry.lock, uv.lock, go.sum, Gemfile.lock
    esac
}

# --- Memory file helpers ---

memory_file_exists() {
    [[ -f "$MEMORY_FILE" ]]
}

# Create the memory file with header if it doesn't exist
ensure_memory_file() {
    if [[ ! -f "$MEMORY_FILE" ]]; then
        mkdir -p "$VULNETIX_DIR" 2>/dev/null
        cat > "$MEMORY_FILE" << 'HEADER'
# .vulnetix/memory.yaml
# Auto-maintained by Vulnetix Claude Code Plugin
# Do not remove — tracks vulnerability decisions, manifest scans, and fix history

schema_version: 1
manifests: {}
vulnerabilities: {}
HEADER
    fi
}

# Write/update the manifests section in the memory file
# This replaces the entire manifests block with fresh data
write_manifests_section() {
    local manifests_yaml="$1"

    if grep -q "^manifests:" "$MEMORY_FILE" 2>/dev/null; then
        # Remove existing manifests block (from "manifests:" to next top-level key or EOF)
        local tmpfile
        tmpfile=$(mktemp)
        awk '
            /^manifests:/ { skip=1; next }
            /^[a-z_]+:/ && skip { skip=0 }
            !skip { print }
        ' "$MEMORY_FILE" > "$tmpfile"

        # Insert new manifests section before vulnerabilities:
        awk -v section="$manifests_yaml" '
            /^vulnerabilities:/ { print section; print ""; }
            { print }
        ' "$tmpfile" > "$MEMORY_FILE"
        rm -f "$tmpfile"
    fi
}

# --- Main hook logic ---

# Check staged files early (fast, local) before any CLI/network operations
STAGED_FILES=$(git diff --cached --name-only 2>/dev/null)
if [[ -z "$STAGED_FILES" ]]; then
    exit 0
fi

# Filter for manifest files
MANIFESTS_TO_SCAN=()
while IFS= read -r file; do
    filename=$(basename "$file")
    for pattern in "${MANIFEST_PATTERNS[@]}"; do
        if [[ "$filename" == "$pattern" ]] && [[ -f "$file" ]]; then
            MANIFESTS_TO_SCAN+=("$file")
            break
        fi
    done
done <<< "$STAGED_FILES"

if [[ ${#MANIFESTS_TO_SCAN[@]} -eq 0 ]]; then
    exit 0
fi

# Check if vulnetix CLI is installed — probe PATH, shell rc files, and common locations
VULNETIX_CMD=""
if command -v vulnetix &>/dev/null; then
    VULNETIX_CMD="vulnetix"
else
    # Probe common install locations (Homebrew on Linux/macOS, Go, local bin)
    for candidate in \
        "/home/linuxbrew/.linuxbrew/bin/vulnetix" \
        "/opt/homebrew/bin/vulnetix" \
        "/usr/local/bin/vulnetix" \
        "${HOME}/.local/bin/vulnetix" \
        "${HOME}/go/bin/vulnetix" \
        "${HOME}/.cargo/bin/vulnetix"; do
        if [[ -x "$candidate" ]]; then
            VULNETIX_CMD="$candidate"
            break
        fi
    done

    # If still not found, try sourcing shell rc to pick up PATH modifications
    if [[ -z "$VULNETIX_CMD" ]]; then
        SHELL_RC=""
        case "${SHELL:-}" in
            */zsh)  SHELL_RC="${HOME}/.zshrc" ;;
            */bash) SHELL_RC="${HOME}/.bashrc" ;;
            *)      SHELL_RC="${HOME}/.bashrc" ;;
        esac
        if [[ -f "$SHELL_RC" ]]; then
            # Source in a subshell to avoid polluting current environment
            VULNETIX_CMD=$(bash -c "source '$SHELL_RC' 2>/dev/null && command -v vulnetix" 2>/dev/null || true)
        fi
    fi

    if [[ -z "$VULNETIX_CMD" ]]; then
        echo '{"systemMessage": "Vulnetix CLI not found. Install with: `curl -fsSL https://cli.vulnetix.com/install.sh | bash`. If already installed via Homebrew, run `! source ~/.bashrc` in this session to update your PATH."}'
        exit 0
    fi
fi

# Check API health and authentication
STATUS_JSON=$("$VULNETIX_CMD" vdb status -o json 2>/dev/null)
if [[ -z "$STATUS_JSON" ]]; then
    exit 0
fi

API_STATUS=$(echo "$STATUS_JSON" | jq -r '.api.status // "unhealthy"' 2>/dev/null)
AUTH_STATUS=$(echo "$STATUS_JSON" | jq -r '.auth.status // "unknown"' 2>/dev/null)

if [[ "$API_STATUS" != "healthy" ]] || [[ "$AUTH_STATUS" != "ok" ]]; then
    echo '{"systemMessage": "Vulnetix: API unavailable or not authenticated. Run `vulnetix auth login` to enable vulnerability scanning."}'
    exit 0
fi

# --- Extract packages from staged manifests ---

# Ensure .vulnetix/ data directory exists
mkdir -p "$SCANS_DIR" 2>/dev/null

# Migrate legacy memory file location (.vulnetix-memory.yaml → .vulnetix/memory.yaml)
if [[ -f ".vulnetix-memory.yaml" ]] && [[ ! -f "$MEMORY_FILE" ]]; then
    mv ".vulnetix-memory.yaml" "$MEMORY_FILE" 2>/dev/null
fi

# Ensure .vulnetix/ is in .gitignore
if [[ -f ".gitignore" ]]; then
    if ! grep -q "^\.vulnetix/$" ".gitignore" 2>/dev/null && ! grep -q "^\.vulnetix$" ".gitignore" 2>/dev/null; then
        printf '\n# Vulnetix plugin data (SBOMs, PoCs, memory)\n.vulnetix/\n' >> ".gitignore"
    fi
elif [[ -d ".git" ]]; then
    printf '# Vulnetix plugin data (SBOMs, PoCs, memory)\n.vulnetix/\n' > ".gitignore"
fi

SCAN_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TIMESTAMP_COMPACT=$(date -u +"%Y%m%dT%H%M%SZ")

PACKAGES_FILE=$(mktemp)
UNPARSEABLE_MANIFESTS=()

for manifest in "${MANIFESTS_TO_SCAN[@]}"; do
    filename=$(basename "$manifest")
    ecosystem=$(manifest_to_ecosystem "$filename")
    packages=$(extract_packages_from_staged "$manifest")

    if [[ -n "$packages" ]]; then
        while IFS=$'\t' read -r pkg ver; do
            [[ -z "$pkg" ]] && continue
            printf '%s\t%s\t%s\t%s\n' "$pkg" "$ver" "$ecosystem" "$manifest" >> "$PACKAGES_FILE"
        done <<< "$packages"
    else
        UNPARSEABLE_MANIFESTS+=("$manifest")
    fi
done

# Deduplicate by package name + ecosystem, limit to 50 packages
DEDUP_FILE=$(mktemp)
sort -t$'\t' -k1,1 -k3,3 -u "$PACKAGES_FILE" | head -50 > "$DEDUP_FILE"
mv "$DEDUP_FILE" "$PACKAGES_FILE"

PKG_COUNT=$(wc -l < "$PACKAGES_FILE" 2>/dev/null | tr -d ' ')

# Build manifest summary
MANIFEST_SUMMARY=""
for manifest in "${MANIFESTS_TO_SCAN[@]}"; do
    filename=$(basename "$manifest")
    ecosystem=$(manifest_to_ecosystem "$filename")
    [[ -n "$MANIFEST_SUMMARY" ]] && MANIFEST_SUMMARY="${MANIFEST_SUMMARY}, "
    MANIFEST_SUMMARY="${MANIFEST_SUMMARY}${manifest} (${ecosystem})"
done

if [[ "$PKG_COUNT" -eq 0 ]]; then
    rm -f "$PACKAGES_FILE"
    # Still note that manifests changed even if we couldn't extract packages
    jq -n --arg msg "Vulnetix: Staged manifest changes detected (${MANIFEST_SUMMARY}) but no packages could be extracted for scanning." \
        '{"systemMessage": $msg}'
    exit 0
fi

RESULTS_FILE="${SCANS_DIR}/pre-commit.${TIMESTAMP_COMPACT}.packages.json"

# --- Launch background package search ---
# Runs VDB queries without blocking the commit operation.
# Results are written to .vulnetix/scans/ and memory.yaml manifests section is updated.

(
    RISKY_ENTRIES=()
    TOTAL_VULNS=0
    SCANNED=0

    while IFS=$'\t' read -r pkg_name pkg_version ecosystem manifest; do
        [[ -z "$pkg_name" ]] && continue
        SCANNED=$((SCANNED + 1))

        RESULT=$("$VULNETIX_CMD" vdb packages search "$pkg_name" --ecosystem "$ecosystem" -o json 2>/dev/null)
        [[ -z "$RESULT" ]] && continue

        VULN_COUNT=$(echo "$RESULT" | jq -r '.packages[0].vulnerabilityCount // 0' 2>/dev/null)
        [[ "$VULN_COUNT" -eq 0 ]] 2>/dev/null && continue

        MAX_SEV=$(echo "$RESULT" | jq -r '.packages[0].maxSeverity // "unknown"' 2>/dev/null)
        SH_SCORE=$(echo "$RESULT" | jq -r '.packages[0].safeHarbourScore // 0' 2>/dev/null)
        LATEST=$(echo "$RESULT" | jq -r '.packages[0].latestVersion // "unknown"' 2>/dev/null)
        TOTAL_VULNS=$((TOTAL_VULNS + VULN_COUNT))

        ENTRY=$(jq -n \
            --arg name "$pkg_name" \
            --arg ver "$pkg_version" \
            --arg eco "$ecosystem" \
            --arg man "$manifest" \
            --argjson vc "$VULN_COUNT" \
            --arg ms "$MAX_SEV" \
            --arg sh "$SH_SCORE" \
            --arg lv "$LATEST" \
            '{name:$name,version:$ver,ecosystem:$eco,manifest:$man,vulnerability_count:$vc,max_severity:$ms,safe_harbour_score:$sh,latest_version:$lv}')
        RISKY_ENTRIES+=("$ENTRY")
    done < "$PACKAGES_FILE"

    # Build results JSON
    RISKY_ARRAY="[]"
    if [[ ${#RISKY_ENTRIES[@]} -gt 0 ]]; then
        RISKY_ARRAY=$(printf '%s\n' "${RISKY_ENTRIES[@]}" | jq -s '.')
    fi

    MANIFEST_LIST_JSON=$(printf '%s\n' "${MANIFESTS_TO_SCAN[@]}" | jq -R -s 'split("\n") | map(select(. != ""))')

    jq -n \
        --arg ts "$SCAN_TIMESTAMP" \
        --argjson manifests "$MANIFEST_LIST_JSON" \
        --argjson scanned "$SCANNED" \
        --argjson risky "$RISKY_ARRAY" \
        --argjson total_vulns "$TOTAL_VULNS" \
        '{timestamp:$ts,manifests:$manifests,packages_scanned:$scanned,risky_packages:$risky,total_vulnerabilities:$total_vulns}' \
        > "$RESULTS_FILE"

    # Update manifests section in memory.yaml (best-effort)
    if [[ -d "$VULNETIX_DIR" ]]; then
        ensure_memory_file

        MANIFESTS_YAML="manifests:"
        for manifest in "${MANIFESTS_TO_SCAN[@]}"; do
            filename=$(basename "$manifest")
            ecosystem=$(manifest_to_ecosystem "$filename")
            manifest_key=$(echo "$manifest" | sed 's|/|--|g')
            MANIFESTS_YAML="${MANIFESTS_YAML}
  ${manifest_key}:
    path: \"${manifest}\"
    ecosystem: ${ecosystem}
    last_scanned: \"${SCAN_TIMESTAMP}\"
    packages_searched: true
    results_path: \"${RESULTS_FILE}\"
    scan_source: hook"
        done

        write_manifests_section "$MANIFESTS_YAML"
    fi

    # Cleanup
    rm -f "$PACKAGES_FILE"

) </dev/null >/dev/null 2>&1 &
disown

# --- Immediate systemMessage ---

MESSAGE="Vulnetix: Scanning ${PKG_COUNT} packages from ${#MANIFESTS_TO_SCAN[@]} staged manifests in background.\n"
MESSAGE="${MESSAGE}Manifests: ${MANIFEST_SUMMARY}\n"
MESSAGE="${MESSAGE}Results will be saved to \`${RESULTS_FILE}\`."

if [[ ${#UNPARSEABLE_MANIFESTS[@]} -gt 0 ]]; then
    UNPARSEABLE_LIST=""
    for m in "${UNPARSEABLE_MANIFESTS[@]}"; do
        [[ -n "$UNPARSEABLE_LIST" ]] && UNPARSEABLE_LIST="${UNPARSEABLE_LIST}, "
        UNPARSEABLE_LIST="${UNPARSEABLE_LIST}$(basename "$m")"
    done
    MESSAGE="${MESSAGE}\nNote: ${UNPARSEABLE_LIST} changed but packages could not be extracted (lock file format)."
fi

FORMATTED=$(printf "%b" "$MESSAGE")
jq -n --arg msg "$FORMATTED" '{"systemMessage": $msg}'

exit 0
