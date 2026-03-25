#!/usr/bin/env bash
set -uo pipefail

# SessionStart hook — display vulnerability dashboard on session start
# Reads .vulnetix/memory.yaml and outputs a brief status summary.
# Always exits 0 — informational only.

VULNETIX_DIR=".vulnetix"
MEMORY_FILE="${VULNETIX_DIR}/memory.yaml"

# Only show dashboard if memory file exists
if [[ ! -f "$MEMORY_FILE" ]]; then
    exit 0
fi

# Count vulnerabilities by status using grep
TOTAL=$(grep -c "^  [A-Z].*:" "$MEMORY_FILE" 2>/dev/null || echo "0")
FIXED=$(grep -c "status: fixed" "$MEMORY_FILE" 2>/dev/null || echo "0")
AFFECTED=$(grep -c "status: affected" "$MEMORY_FILE" 2>/dev/null || echo "0")
NOT_AFFECTED=$(grep -c "status: not_affected" "$MEMORY_FILE" 2>/dev/null || echo "0")
INVESTIGATING=$(grep -c "status: under_investigation" "$MEMORY_FILE" 2>/dev/null || echo "0")

# Count decisions
RISK_ACCEPTED=$(grep -c "choice: risk-accepted" "$MEMORY_FILE" 2>/dev/null || echo "0")
DEFERRED=$(grep -c "choice: deferred" "$MEMORY_FILE" 2>/dev/null || echo "0")

# Get last scan timestamp from manifests section
LAST_SCAN=$(grep "last_scanned:" "$MEMORY_FILE" 2>/dev/null | tail -1 | sed 's/.*last_scanned: *"//; s/"//' || echo "unknown")

# Count tracked manifests
MANIFEST_COUNT=$(grep "scan_source:" "$MEMORY_FILE" 2>/dev/null | wc -l || echo "0")

# Only output if there's meaningful data
OPEN=$((AFFECTED + INVESTIGATING))
if [[ $TOTAL -le 0 ]] && [[ $MANIFEST_COUNT -le 0 ]]; then
    exit 0
fi

# Build summary message
MESSAGE="Vulnetix security status:"

if [[ $OPEN -gt 0 ]]; then
    MESSAGE="${MESSAGE} ${OPEN} open"
    DETAILS=""
    if [[ $AFFECTED -gt 0 ]]; then DETAILS="${DETAILS}, ${AFFECTED} vulnerable"; fi
    if [[ $INVESTIGATING -gt 0 ]]; then DETAILS="${DETAILS}, ${INVESTIGATING} investigating"; fi
    MESSAGE="${MESSAGE} (${DETAILS:2})"
fi
if [[ $FIXED -gt 0 ]]; then MESSAGE="${MESSAGE}, ${FIXED} fixed"; fi
if [[ $RISK_ACCEPTED -gt 0 ]]; then MESSAGE="${MESSAGE}, ${RISK_ACCEPTED} risk-accepted"; fi
if [[ $DEFERRED -gt 0 ]]; then MESSAGE="${MESSAGE}, ${DEFERRED} deferred"; fi

MESSAGE="${MESSAGE}."

if [[ "$MANIFEST_COUNT" -gt 0 ]]; then
    MESSAGE="${MESSAGE} ${MANIFEST_COUNT} manifests tracked (last scan: ${LAST_SCAN})."
fi

# If there are open vulnerabilities, suggest action
if [[ $OPEN -gt 0 ]]; then
    MESSAGE="${MESSAGE} Run /vulnetix:dashboard for details."
fi

if command -v jq &>/dev/null; then
    jq -n --arg msg "$MESSAGE" '{"systemMessage": $msg}'
else
    echo "{\"systemMessage\": \"${MESSAGE}\"}"
fi

exit 0
