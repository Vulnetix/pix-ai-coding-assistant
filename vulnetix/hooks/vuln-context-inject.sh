#!/usr/bin/env bash
set -uo pipefail

# UserPromptSubmit hook — auto-detect vulnerability IDs in user messages
# When the user mentions a CVE/GHSA ID, checks .vulnetix/memory.yaml for
# prior context and injects it as a systemMessage.
# Always exits 0 — never blocks prompt submission.

VULNETIX_DIR=".vulnetix"
MEMORY_FILE="${VULNETIX_DIR}/memory.yaml"

# Read JSON from stdin
INPUT=$(cat)

# Extract user prompt text
USER_PROMPT=$(echo "$INPUT" | jq -r '.user_prompt // empty' 2>/dev/null)
if [[ -z "$USER_PROMPT" ]]; then
    exit 0
fi

# Find vulnerability IDs in the prompt (CVE-YYYY-NNNNN or GHSA-xxxx-xxxx-xxxx)
VULN_IDS=$(echo "$USER_PROMPT" | grep -oP '(CVE-\d{4}-\d{4,}|GHSA-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4})' 2>/dev/null | sort -u)
if [[ -z "$VULN_IDS" ]]; then
    exit 0
fi

# Skip if the user is already invoking a vulnetix skill
if [[ "$USER_PROMPT" == */vulnetix:* ]]; then
    exit 0
fi

# Check memory file for prior context
if [[ ! -f "$MEMORY_FILE" ]]; then
    # No memory — suggest looking up the vuln
    FIRST_ID=$(echo "$VULN_IDS" | head -1)
    jq -n --arg msg "Vulnetix: ${FIRST_ID} mentioned — no prior data in memory. Run \`/vulnetix:vuln ${FIRST_ID}\` to look it up." '{"systemMessage": $msg}'
    exit 0
fi

# Build context for each mentioned vuln ID
MESSAGE=""
FOUND=0
NOT_FOUND=""

while IFS= read -r vuln_id; do
    if [[ -z "$vuln_id" ]]; then continue; fi

    if grep -q "^  ${vuln_id}:" "$MEMORY_FILE" 2>/dev/null; then
        FOUND=$((FOUND + 1))
        # Extract key fields
        STATUS=$(sed -n "/^  ${vuln_id}:/,/^  [A-Z]/{
            /^\s*status:/{ s/.*status: *//; p; q; }
        }" "$MEMORY_FILE" 2>/dev/null)
        PACKAGE=$(sed -n "/^  ${vuln_id}:/,/^  [A-Z]/{
            /^\s*package:/{ s/.*package: *//; p; q; }
        }" "$MEMORY_FILE" 2>/dev/null)
        CHOICE=$(sed -n "/^  ${vuln_id}:/,/^  [A-Z]/{
            /^\s*choice:/{ s/.*choice: *//; p; q; }
        }" "$MEMORY_FILE" 2>/dev/null)

        # Map to developer-friendly language
        FRIENDLY=""
        case "$STATUS" in
            fixed) FRIENDLY="Fixed" ;;
            not_affected) FRIENDLY="Not affected" ;;
            under_investigation) FRIENDLY="Investigating" ;;
            affected)
                case "$CHOICE" in
                    risk-accepted) FRIENDLY="Risk accepted" ;;
                    deferred) FRIENDLY="Fix planned" ;;
                    *) FRIENDLY="Vulnerable" ;;
                esac
                ;;
            *) FRIENDLY="Unknown" ;;
        esac

        MESSAGE="${MESSAGE}${vuln_id}: ${FRIENDLY}"
        if [[ -n "$PACKAGE" ]]; then MESSAGE="${MESSAGE} (${PACKAGE})"; fi
        MESSAGE="${MESSAGE}. "
    else
        NOT_FOUND="${NOT_FOUND}${vuln_id}, "
    fi
done <<< "$VULN_IDS"

# Build final output
OUTPUT=""
if [[ $FOUND -gt 0 ]]; then
    OUTPUT="Vulnetix context: ${MESSAGE}"
fi
if [[ -n "$NOT_FOUND" ]]; then
    NOT_FOUND=${NOT_FOUND%, }
    OUTPUT="${OUTPUT}Not tracked: ${NOT_FOUND} — run \`/vulnetix:vuln <id>\` to look up."
fi

if [[ -n "$OUTPUT" ]]; then
    if command -v jq &>/dev/null; then
        jq -n --arg msg "$OUTPUT" '{"systemMessage": $msg}'
    else
        echo "{\"systemMessage\": \"${OUTPUT}\"}"
    fi
fi

exit 0
