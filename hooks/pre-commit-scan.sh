#!/usr/bin/env bash
set -uo pipefail

# Pre-commit vulnerability scan hook for Vulnetix Claude Code Plugin
# Intercepts git commit commands and scans staged manifest files
# Always exits 0 (never blocks commits) - informational only

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

# Read JSON from stdin
INPUT=$(cat)

# Extract command from tool_input
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Check if this is a git commit command
if [[ ! "$COMMAND" =~ git[[:space:]]+commit ]]; then
    exit 0
fi

# Check if vulnetix CLI is installed
if ! command -v vulnetix &>/dev/null; then
    exit 0
fi

# Check API health and authentication
STATUS_JSON=$(vulnetix vdb status -o json 2>/dev/null)
if [[ -z "$STATUS_JSON" ]]; then
    exit 0
fi

API_STATUS=$(echo "$STATUS_JSON" | jq -r '.api.status // "unhealthy"' 2>/dev/null)
AUTH_STATUS=$(echo "$STATUS_JSON" | jq -r '.auth.status // "unknown"' 2>/dev/null)

if [[ "$API_STATUS" != "healthy" ]] || [[ "$AUTH_STATUS" != "ok" ]]; then
    echo '{"systemMessage": "⚠️ Vulnetix: API unavailable or not authenticated. Run `vulnetix auth login` to enable vulnerability scanning."}'
    exit 0
fi

# Get staged files
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

# If no manifests staged, exit
if [[ ${#MANIFESTS_TO_SCAN[@]} -eq 0 ]]; then
    exit 0
fi

# Scan each manifest and aggregate results
declare -A SEVERITY_COUNTS=(
    ["critical"]=0
    ["high"]=0
    ["medium"]=0
    ["low"]=0
    ["none"]=0
    ["unknown"]=0
)
TOTAL_VULNS=0
SCANNED_FILES=()

for manifest in "${MANIFESTS_TO_SCAN[@]}"; do
    SCAN_OUTPUT=$(vulnetix scan --file "$manifest" -f cdx17 2>/dev/null)
    
    if [[ -z "$SCAN_OUTPUT" ]]; then
        continue
    fi
    
    # Count vulnerabilities by severity
    VULNS=$(echo "$SCAN_OUTPUT" | jq -r '.vulnerabilities // [] | length' 2>/dev/null)
    if [[ "$VULNS" -gt 0 ]]; then
        SCANNED_FILES+=("$manifest")
        TOTAL_VULNS=$((TOTAL_VULNS + VULNS))
        
        # Parse severities
        while IFS= read -r severity; do
            severity_lower=$(echo "$severity" | tr '[:upper:]' '[:lower:]')
            if [[ -n "$severity_lower" ]]; then
                SEVERITY_COUNTS[$severity_lower]=$((SEVERITY_COUNTS[$severity_lower] + 1))
            fi
        done < <(echo "$SCAN_OUTPUT" | jq -r '.vulnerabilities[].ratings[]? | select(.source == "nvd" or .source == "ghsa") | .severity' 2>/dev/null | head -n "$VULNS")
    fi
done

# If vulnerabilities found, output systemMessage
if [[ $TOTAL_VULNS -gt 0 ]]; then
    FILES_LIST=$(printf ", %s" "${SCANNED_FILES[@]}")
    FILES_LIST=${FILES_LIST:2}  # Remove leading ", "
    
    CRITICAL=${SEVERITY_COUNTS[critical]}
    HIGH=${SEVERITY_COUNTS[high]}
    MEDIUM=${SEVERITY_COUNTS[medium]}
    LOW=${SEVERITY_COUNTS[low]}
    
    MESSAGE="🔍 Vulnetix scan found $TOTAL_VULNS vulnerabilities in staged dependencies:"
    if [[ $CRITICAL -gt 0 ]]; then MESSAGE="$MESSAGE $CRITICAL critical,"; fi
    if [[ $HIGH -gt 0 ]]; then MESSAGE="$MESSAGE $HIGH high,"; fi
    if [[ $MEDIUM -gt 0 ]]; then MESSAGE="$MESSAGE $MEDIUM medium,"; fi
    if [[ $LOW -gt 0 ]]; then MESSAGE="$MESSAGE $LOW low"; fi
    MESSAGE="${MESSAGE%,}"  # Remove trailing comma
    MESSAGE="$MESSAGE (in: $FILES_LIST). Consider reviewing with \`/vulnetix:fix <vuln-id>\` before committing."
    
    jq -n --arg msg "$MESSAGE" '{"systemMessage": $msg}'
fi

exit 0
