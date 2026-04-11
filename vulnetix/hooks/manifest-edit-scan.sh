#!/usr/bin/env bash
set -uo pipefail

# PreToolUse hook — manifest dependency security gate
# Fires before Edit or Write modifies a package manager manifest file.
# Extracts package names/versions from the diff, runs vdb packages search,
# cross-references .vulnetix/memory.yaml, and outputs risk assessment.
# Never blocks edits (exits 0) — informational, drives user toward /vulnetix:fix.

if ! command -v jq &>/dev/null; then
    exit 0
fi

VULNETIX_DIR=".vulnetix"
MEMORY_FILE="${VULNETIX_DIR}/memory.yaml"

# Known manifest filenames
MANIFEST_FILES=(
    "package.json"
    "requirements.txt"
    "pyproject.toml"
    "Pipfile"
    "go.mod"
    "Cargo.toml"
    "pom.xml"
    "build.gradle"
    "build.gradle.kts"
    "Gemfile"
    "composer.json"
)

filename_to_ecosystem() {
    local filename="$1"
    case "$filename" in
        package.json) echo "npm" ;;
        requirements.txt|pyproject.toml|Pipfile) echo "pypi" ;;
        go.mod) echo "go" ;;
        Cargo.toml) echo "cargo" ;;
        pom.xml|build.gradle|build.gradle.kts) echo "maven" ;;
        Gemfile) echo "rubygems" ;;
        composer.json) echo "packagist" ;;
        *) echo "" ;;
    esac
}

# Extract package names from a diff based on ecosystem
# Returns newline-separated "package\tversion" pairs
extract_packages_from_diff() {
    local ecosystem="$1"
    local new_text="$2"

    case "$ecosystem" in
        npm)
            # Match "package-name": "version" patterns in JSON
            echo "$new_text" | grep -oP '"([^"]+)"\s*:\s*"([^"]*)"' | \
                grep -v '"name"\|"version"\|"description"\|"main"\|"scripts"\|"license"\|"type"\|"author"\|"repository"\|"engines"\|"files"\|"keywords"' | \
                sed 's/"//g; s/\s*:\s*/\t/' | \
                sed 's/[\^~>=<]//g' 2>/dev/null
            ;;
        pypi)
            # Match package==version or package>=version patterns
            echo "$new_text" | grep -oP '^[a-zA-Z0-9_-]+[><=!~]+[0-9][^\s,;]*' | \
                sed 's/[><=!~]*/\t/' 2>/dev/null
            ;;
        go)
            # Match require lines: module/path vX.Y.Z
            echo "$new_text" | grep -oP '\S+\s+v[0-9]+\.[0-9]+\.[0-9]+' | \
                sed 's/\s\+/\t/' 2>/dev/null
            ;;
        cargo)
            # Match name = "version" patterns
            echo "$new_text" | grep -oP '^([a-zA-Z0-9_-]+)\s*=\s*"([^"]+)"' | \
                sed 's/\s*=\s*"/\t/; s/"$//' 2>/dev/null
            ;;
        *)
            echo ""
            ;;
    esac
}

# Read JSON from stdin
INPUT=$(cat)

# Extract file_path from tool_input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Check if file is a manifest
FILENAME=$(basename "$FILE_PATH")
IS_MANIFEST=false
for manifest in "${MANIFEST_FILES[@]}"; do
    if [[ "$FILENAME" == "$manifest" ]]; then
        IS_MANIFEST=true
        break
    fi
done

if [[ "$IS_MANIFEST" != "true" ]]; then
    exit 0
fi

ECOSYSTEM=$(filename_to_ecosystem "$FILENAME")
if [[ -z "$ECOSYSTEM" ]]; then
    exit 0
fi

# Extract new content from the tool input
# For Edit: new_string field. For Write: content field.
NEW_TEXT=$(echo "$INPUT" | jq -r '.tool_input.new_string // .tool_input.content // empty' 2>/dev/null)
if [[ -z "$NEW_TEXT" ]]; then
    exit 0
fi

# Extract package names/versions from the diff
PACKAGES=$(extract_packages_from_diff "$ECOSYSTEM" "$NEW_TEXT")
if [[ -z "$PACKAGES" ]]; then
    exit 0
fi

# Find or auto-install vulnetix CLI
source "$(dirname "$0")/ensure-vulnetix-cli.sh"
ensure_vulnetix_cli || exit 0

# Check API health (quick check)
STATUS_JSON=$("$VULNETIX_CMD" vdb status -o json 2>/dev/null)
API_STATUS=$(echo "$STATUS_JSON" | jq -r '.api.status // "unhealthy"' 2>/dev/null)
AUTH_STATUS=$(echo "$STATUS_JSON" | jq -r '.auth.status // "unknown"' 2>/dev/null)
if [[ "$API_STATUS" != "healthy" ]] || [[ "$AUTH_STATUS" != "ok" ]]; then
    exit 0
fi

# Search each package for vulnerability context
RISKY_PACKAGES=""
TOTAL_VULNS=0
TOTAL_PACKAGES=0

while IFS=$'\t' read -r pkg_name pkg_version; do
    if [[ -z "$pkg_name" ]]; then continue; fi
    TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))

    # Query VDB for package risk data
    SEARCH_RESULT=$("$VULNETIX_CMD" vdb packages search "$pkg_name" --ecosystem "$ECOSYSTEM" -o json 2>/dev/null)
    if [[ -z "$SEARCH_RESULT" ]]; then continue; fi

    # Extract vulnerability count and severity
    VULN_COUNT=$(echo "$SEARCH_RESULT" | jq -r '.packages[0].vulnerabilityCount // 0' 2>/dev/null)
    MAX_SEVERITY=$(echo "$SEARCH_RESULT" | jq -r '.packages[0].maxSeverity // "none"' 2>/dev/null)
    SAFE_HARBOUR=$(echo "$SEARCH_RESULT" | jq -r '.packages[0].safeHarbourScore // 0' 2>/dev/null)
    LATEST_VERSION=$(echo "$SEARCH_RESULT" | jq -r '.packages[0].latestVersion // "unknown"' 2>/dev/null)

    if [[ "$VULN_COUNT" -gt 0 ]]; then
        TOTAL_VULNS=$((TOTAL_VULNS + VULN_COUNT))
        # Convert Safe Harbour to decimal
        SH_DECIMAL=$(echo "scale=2; $SAFE_HARBOUR / 100" | bc 2>/dev/null || echo "N/A")
        RISKY_PACKAGES="${RISKY_PACKAGES}* **${pkg_name}@${pkg_version:-latest}** — ${VULN_COUNT} known vulns (max: ${MAX_SEVERITY}), Safe Harbour: ${SH_DECIMAL}, latest: ${LATEST_VERSION}\n"
    fi

    # Check memory file for prior history on this package
    if [[ -f "$MEMORY_FILE" ]]; then
        MEMORY_HITS=$(grep -c "package: ${pkg_name}$" "$MEMORY_FILE" 2>/dev/null || echo "0")
        if [[ "$MEMORY_HITS" -gt 0 ]]; then
            RISKY_PACKAGES="${RISKY_PACKAGES}  Previously tracked: ${MEMORY_HITS} vulnerability record(s) in memory\n"
        fi
    fi
done <<< "$PACKAGES"

# Output risk assessment if vulnerabilities found
if [[ $TOTAL_VULNS -gt 0 ]]; then
    MESSAGE="Vulnetix dependency security check for **${FILENAME}** (${ECOSYSTEM}):\n\n"
    MESSAGE="${MESSAGE}${TOTAL_VULNS} known vulnerabilities across ${TOTAL_PACKAGES} packages being added/modified:\n\n"
    MESSAGE="${MESSAGE}${RISKY_PACKAGES}\n"
    MESSAGE="${MESSAGE}**Options:**\n"
    MESSAGE="${MESSAGE}1. Run \`/vulnetix:fix <vuln-id>\` to see fix options and remediation steps\n"
    MESSAGE="${MESSAGE}2. Run \`/vulnetix:package-search <package>\` to search for safer alternatives\n"
    MESSAGE="${MESSAGE}3. Run \`vulnetix vdb traffic-filters <vuln-id>\` for Snort rules to block exploit traffic while a fix is pending\n"
    MESSAGE="${MESSAGE}4. Proceed and accept the risk (the edit will not be blocked)\n"

    FORMATTED=$(printf "%b" "$MESSAGE")
    jq -n --arg msg "$FORMATTED" '{"systemMessage": $msg}'
fi

exit 0
