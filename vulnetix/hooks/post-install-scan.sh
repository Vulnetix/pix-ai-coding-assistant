#!/usr/bin/env bash
set -uo pipefail

# PostToolUse hook — auto-scan after dependency install commands
# Detects npm install, pip install, go get, cargo add, etc. and scans
# the affected manifest for new vulnerabilities.
# Always exits 0 — informational only.

if ! command -v jq &>/dev/null; then
    exit 0
fi

VULNETIX_DIR=".vulnetix"
MEMORY_FILE="${VULNETIX_DIR}/memory.yaml"
SCANS_DIR="${VULNETIX_DIR}/scans"

# Dependency install command patterns (matched against tool_input.command)
INSTALL_PATTERNS=(
    "npm install"
    "npm i "
    "npm add"
    "yarn add"
    "yarn install"
    "pnpm add"
    "pnpm install"
    "pip install"
    "pip3 install"
    "uv pip install"
    "uv add"
    "poetry add"
    "go get"
    "go mod tidy"
    "cargo add"
    "cargo install"
    "bundle install"
    "bundle add"
    "gem install"
    "composer require"
    "composer install"
    "mvn dependency:resolve"
    "gradle dependencies"
)

# Manifest file mapping: command prefix → manifest files to scan
command_to_manifests() {
    local cmd="$1"
    case "$cmd" in
        npm*|yarn*|pnpm*) echo "package.json package-lock.json yarn.lock pnpm-lock.yaml" ;;
        pip*|uv*|poetry*) echo "requirements.txt Pipfile.lock poetry.lock uv.lock pyproject.toml" ;;
        go*)              echo "go.mod go.sum" ;;
        cargo*)           echo "Cargo.toml Cargo.lock" ;;
        bundle*|gem*)     echo "Gemfile Gemfile.lock" ;;
        composer*)        echo "composer.json composer.lock" ;;
        mvn*|gradle*)     echo "pom.xml build.gradle gradle.lockfile" ;;
        *)                echo "" ;;
    esac
}

manifest_to_ecosystem() {
    local filename="$1"
    case "$filename" in
        package.json|package-lock.json|yarn.lock|pnpm-lock.yaml) echo "npm" ;;
        requirements.txt|Pipfile.lock|poetry.lock|uv.lock|pyproject.toml) echo "pypi" ;;
        go.mod|go.sum) echo "go" ;;
        Cargo.toml|Cargo.lock) echo "cargo" ;;
        pom.xml|build.gradle|gradle.lockfile) echo "maven" ;;
        Gemfile|Gemfile.lock) echo "rubygems" ;;
        composer.json|composer.lock) echo "packagist" ;;
        *) echo "unknown" ;;
    esac
}

# Read JSON from stdin
INPUT=$(cat)

# Extract the command that was executed
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
if [[ -z "$COMMAND" ]]; then
    exit 0
fi

# Check if this is a dependency install command
IS_INSTALL=false
MATCHED_PREFIX=""
for pattern in "${INSTALL_PATTERNS[@]}"; do
    if [[ "$COMMAND" == *"$pattern"* ]]; then
        IS_INSTALL=true
        MATCHED_PREFIX="$pattern"
        break
    fi
done

if [[ "$IS_INSTALL" != "true" ]]; then
    exit 0
fi

# Find or auto-install vulnetix CLI
source "$(dirname "$0")/ensure-vulnetix-cli.sh"
ensure_vulnetix_cli || exit 0

# Check API health
STATUS_JSON=$("$VULNETIX_CMD" vdb status -o json 2>/dev/null)
API_STATUS=$(echo "$STATUS_JSON" | jq -r '.api.status // "unhealthy"' 2>/dev/null)
AUTH_STATUS=$(echo "$STATUS_JSON" | jq -r '.auth.status // "unknown"' 2>/dev/null)
if [[ "$API_STATUS" != "healthy" ]] || [[ "$AUTH_STATUS" != "ok" ]]; then
    exit 0
fi

# Find relevant manifest files to scan
MANIFEST_NAMES=$(command_to_manifests "$MATCHED_PREFIX")
MANIFESTS_TO_SCAN=()
for manifest_name in $MANIFEST_NAMES; do
    if [[ -f "$manifest_name" ]]; then
        MANIFESTS_TO_SCAN+=("$manifest_name")
    fi
done

if [[ ${#MANIFESTS_TO_SCAN[@]} -eq 0 ]]; then
    exit 0
fi

# Scan manifests and collect results
mkdir -p "$SCANS_DIR" 2>/dev/null
SCAN_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TIMESTAMP_COMPACT=$(date -u +"%Y%m%dT%H%M%SZ")
TOTAL_VULNS=0
VULN_LINES_ALL=""

for manifest in "${MANIFESTS_TO_SCAN[@]}"; do
    SCAN_OUTPUT=$("$VULNETIX_CMD" scan --file "$manifest" -f cdx17 2>/dev/null)
    if [[ -z "$SCAN_OUTPUT" ]]; then
        continue
    fi

    # Persist SBOM
    SANITIZED_NAME=$(echo "$manifest" | sed 's|/|--|g')
    SBOM_PATH="${SCANS_DIR}/${SANITIZED_NAME}.${TIMESTAMP_COMPACT}.cdx.json"
    echo "$SCAN_OUTPUT" > "$SBOM_PATH"

    # Count vulns
    VULN_COUNT=$(echo "$SCAN_OUTPUT" | jq -r '.vulnerabilities // [] | length' 2>/dev/null)
    if [[ "$VULN_COUNT" -gt 0 ]]; then
        TOTAL_VULNS=$((TOTAL_VULNS + VULN_COUNT))

        # Extract vuln details
        LINES=$(echo "$SCAN_OUTPUT" | jq -r '
            (
                [.components[]? | {(."bom-ref" // .name): {name: .name, version: (.version // "unknown")}}] | add // {}
            ) as $comp_map |
            .vulnerabilities[]? |
            "\(.id)\t\([.ratings[]? | .severity][0] // "unknown" | ascii_downcase)\t\((.affects[0]?.ref // null) as $ref | if $ref then ($comp_map[$ref].name // "unknown") else "unknown" end)\t\((.affects[0]?.ref // null) as $ref | if $ref then ($comp_map[$ref].version // "unknown") else "unknown" end)"
        ' 2>/dev/null)
        if [[ -n "$LINES" ]]; then
            VULN_LINES_ALL="${VULN_LINES_ALL}${LINES}\n"
        fi
    fi
done

if [[ $TOTAL_VULNS -gt 0 ]]; then
    MESSAGE="Vulnetix post-install scan: ${TOTAL_VULNS} vulnerabilities detected after \`${MATCHED_PREFIX}\`:\n\n"

    while IFS=$'\t' read -r vuln_id severity package version; do
        if [[ -n "$vuln_id" ]] && [[ "$vuln_id" != "null" ]]; then
            MESSAGE="${MESSAGE}* ${vuln_id} (${severity}) — ${package}@${version}\n"
        fi
    done < <(printf "%b" "$VULN_LINES_ALL" | sort -u)

    MESSAGE="${MESSAGE}\nRun \`/vulnetix:fix <vuln-id>\` to see remediation options, \`/vulnetix:exploits <vuln-id>\` for exploit analysis, or \`vulnetix vdb traffic-filters <vuln-id>\` for IDS/IPS Snort rules to filter malicious traffic while a fix is pending."

    FORMATTED=$(printf "%b" "$MESSAGE")
    jq -n --arg msg "$FORMATTED" '{"systemMessage": $msg}'
fi

exit 0
