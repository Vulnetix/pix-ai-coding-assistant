#!/usr/bin/env bash
set -uo pipefail

# Stop hook — remind about unresolved P1/P2 vulnerabilities before session ends
# Checks .vulnetix/memory.yaml for affected/investigating vulns.
# Always exits 0 — never blocks stopping.

VULNETIX_DIR=".vulnetix"
MEMORY_FILE="${VULNETIX_DIR}/memory.yaml"

if [[ ! -f "$MEMORY_FILE" ]]; then
    exit 0
fi

# Find unresolved vulnerabilities (affected or under_investigation)
OPEN_VULNS=""
OPEN_COUNT=0

# Extract vuln IDs with status affected or under_investigation
while IFS= read -r line; do
    vuln_id=$(echo "$line" | sed 's/^ *//; s/:$//')
    if [[ -n "$vuln_id" ]]; then
        OPEN_VULNS="${OPEN_VULNS}${vuln_id}\n"
        OPEN_COUNT=$((OPEN_COUNT + 1))
    fi
done < <(
    # Find vuln IDs whose next status line is affected or under_investigation
    awk '
        /^  [A-Z].*:$/ || /^  GHSA-.*:$/ { id=$0 }
        /status: affected/ || /status: under_investigation/ { if(id) print id; id="" }
    ' "$MEMORY_FILE" 2>/dev/null
)

if [[ $OPEN_COUNT -eq 0 ]]; then
    exit 0
fi

# Build reminder (keep it brief — this fires on every stop)
if [[ $OPEN_COUNT -eq 1 ]]; then
    VULN_ID=$(printf "%b" "$OPEN_VULNS" | head -1 | tr -d '[:space:]')
    MESSAGE="Reminder: ${VULN_ID} is still unresolved. Run \`/vulnetix:fix ${VULN_ID}\` to see remediation options."
else
    MESSAGE="Reminder: ${OPEN_COUNT} vulnerabilities still unresolved."
    # Show up to 3
    COUNT=0
    while IFS= read -r vid; do
        if [[ -n "$vid" ]] && [[ $COUNT -lt 3 ]]; then
            vid_clean=$(echo "$vid" | tr -d '[:space:]')
            MESSAGE="${MESSAGE} ${vid_clean},"
            COUNT=$((COUNT + 1))
        fi
    done < <(printf "%b" "$OPEN_VULNS")
    MESSAGE="${MESSAGE%,}."
    if [[ $OPEN_COUNT -gt 3 ]]; then
        MESSAGE="${MESSAGE} Run \`/vulnetix:dashboard\` to see all."
    fi
fi

if command -v jq &>/dev/null; then
    jq -n --arg msg "$MESSAGE" '{"systemMessage": $msg}'
else
    echo "{\"systemMessage\": \"${MESSAGE}\"}"
fi

exit 0
