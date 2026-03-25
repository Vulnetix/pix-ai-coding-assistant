#!/usr/bin/env bash
set -uo pipefail

# Pre-commit vulnerability scan hook for Vulnetix Claude Code Plugin
# Intercepts git commit commands, scans staged manifest files, and maintains
# .vulnetix/memory.yaml with vulnerability state and manifest/SBOM tracking.
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

# Required: jq for JSON processing (CycloneDX parsing, systemMessage construction)
if ! command -v jq &>/dev/null; then
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

# --- Memory file helpers ---

memory_file_exists() {
    [[ -f "$MEMORY_FILE" ]]
}

# Check if a vuln ID exists as a top-level key under vulnerabilities:
is_known_vuln() {
    local vuln_id="$1"
    memory_file_exists && grep -q "^  ${vuln_id}:" "$MEMORY_FILE" 2>/dev/null
}

# Extract a field value for a known vuln using sed
# Searches within the block for the given vuln ID
get_vuln_field() {
    local vuln_id="$1"
    local field="$2"
    if ! memory_file_exists; then return 1; fi
    # Extract the value after "field: " within the vuln's block
    sed -n "/^  ${vuln_id}:/,/^  [A-Z]/{
        /^\s*${field}:/{ s/.*${field}: *//; s/^\"//; s/\"$//; p; q; }
    }" "$MEMORY_FILE" 2>/dev/null
}

# Get the Dependabot alert_state for a known vuln (nested under dependabot:)
get_dependabot_field() {
    local vuln_id="$1"
    local field="$2"
    if ! memory_file_exists; then return 1; fi
    sed -n "/^  ${vuln_id}:/,/^  [A-Z]/{
        /dependabot:/,/^    [a-z].*:/{
            /^\s*${field}:/{ s/.*${field}: *//; s/^\"//; s/\"$//; p; q; }
        }
    }" "$MEMORY_FILE" 2>/dev/null
}

# Map VEX status + decision to developer-friendly language
status_to_friendly() {
    local status="$1"
    local decision="$2"
    case "$status" in
        fixed) echo "Fixed" ;;
        not_affected) echo "Not affected" ;;
        under_investigation) echo "Investigating" ;;
        affected)
            case "$decision" in
                risk-accepted) echo "Risk accepted" ;;
                deferred) echo "Fix planned" ;;
                *) echo "Vulnerable" ;;
            esac
            ;;
        *) echo "Unknown" ;;
    esac
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

# Append a new vulnerability entry to the memory file
append_vuln_entry() {
    local vuln_id="$1" package="$2" ecosystem="$3" severity="$4" version="$5" manifest="$6" sbom_path="$7" timestamp="$8"

    # Replace the empty vulnerabilities sentinel if present
    if grep -q "^vulnerabilities: {}$" "$MEMORY_FILE" 2>/dev/null; then
        sed -i 's/^vulnerabilities: {}$/vulnerabilities:/' "$MEMORY_FILE"
    fi

    cat >> "$MEMORY_FILE" << EOF
  ${vuln_id}:
    aliases: []
    package: ${package}
    ecosystem: ${ecosystem}
    discovery:
      date: "${timestamp}"
      source: hook
      file: ${manifest}
      sbom: ${sbom_path}
    versions:
      current: "${version}"
      current_source: "manifest: ${manifest}"
      fixed_in: null
      fix_source: null
    severity: ${severity}
    safe_harbour: null
    status: under_investigation
    justification: null
    action_response: null
    dependabot: null
    decision:
      choice: investigating
      reason: "Discovered by pre-commit hook scan"
      date: "${timestamp}"
    history:
      - date: "${timestamp}"
        event: discovered
        detail: "Found ${package}@${version} in ${manifest} during pre-commit scan"
EOF
}

# Write/update the manifests section in the memory file
# This replaces the entire manifests block with fresh data
write_manifests_section() {
    local manifests_yaml="$1"

    if grep -q "^manifests:" "$MEMORY_FILE" 2>/dev/null; then
        # Remove existing manifests block (from "manifests:" to next top-level key or EOF)
        # Use a temp file to avoid sed -i issues with multi-line blocks
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

# Read JSON from stdin
INPUT=$(cat)

# Extract command from tool_input
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Check if this is a git commit command
if [[ ! "$COMMAND" =~ git[[:space:]]+commit ]]; then
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

# Arrays for tracking results
NEW_VULNS=()          # Lines: "vulnId\tseverity\tpackage\tversion\tmanifest\tsbom_path\tecosystem"
KNOWN_VULNS=()        # Lines: "vulnId\tstatus_friendly\tdependabot_context"
MANIFEST_RECORDS=()   # Lines: "manifest\tecosystem\tvuln_count\tsbom_path"
TOTAL_NEW=0
TOTAL_KNOWN=0

for manifest in "${MANIFESTS_TO_SCAN[@]}"; do
    SCAN_OUTPUT=$("$VULNETIX_CMD" scan --file "$manifest" -f cdx17 2>/dev/null)

    if [[ -z "$SCAN_OUTPUT" ]]; then
        continue
    fi

    # Persist CycloneDX SBOM
    SANITIZED_NAME=$(echo "$manifest" | sed 's|/|--|g')
    SBOM_PATH="${SCANS_DIR}/${SANITIZED_NAME}.${TIMESTAMP_COMPACT}.cdx.json"
    echo "$SCAN_OUTPUT" > "$SBOM_PATH"

    filename=$(basename "$manifest")
    ecosystem=$(manifest_to_ecosystem "$filename")

    # Extract individual vulnerability details via jq
    # Joins vulnerabilities → affects → components to resolve package names
    VULN_LINES=$(echo "$SCAN_OUTPUT" | jq -r '
        (
            [.components[]? | {(."bom-ref" // .name): {name: .name, version: (.version // "unknown")}}] | add // {}
        ) as $comp_map |
        .vulnerabilities[]? |
        {
            id: .id,
            severity: (
                [.ratings[]? | select(
                    (.source.name? // .source? // "" | ascii_downcase) as $src |
                    $src == "nvd" or $src == "ghsa" or $src == "github"
                ) | .severity][0]
                // [.ratings[]? | .severity][0]
                // "unknown"
            ),
            package: (
                (.affects[0]?.ref // null) as $ref |
                if $ref then ($comp_map[$ref].name // "unknown") else "unknown" end
            ),
            version: (
                (.affects[0]?.ref // null) as $ref |
                if $ref then ($comp_map[$ref].version // "unknown") else "unknown" end
            )
        } |
        "\(.id)\t\(.severity | ascii_downcase)\t\(.package)\t\(.version)"
    ' 2>/dev/null)

    MANIFEST_VULN_COUNT=0

    if [[ -n "$VULN_LINES" ]]; then
        while IFS=$'\t' read -r vuln_id severity package version; do
            if [[ -z "$vuln_id" ]] || [[ "$vuln_id" == "null" ]]; then
                continue
            fi

            MANIFEST_VULN_COUNT=$((MANIFEST_VULN_COUNT + 1))

            if is_known_vuln "$vuln_id"; then
                # Known vuln — get its current status
                status=$(get_vuln_field "$vuln_id" "status")
                decision=$(get_vuln_field "$vuln_id" "choice")
                friendly=$(status_to_friendly "$status" "$decision")

                # Check for Dependabot context
                dep_context=""
                dep_alert=$(get_dependabot_field "$vuln_id" "alert_state")
                dep_pr=$(get_dependabot_field "$vuln_id" "pr_state")
                dep_pr_num=$(get_dependabot_field "$vuln_id" "pr_number")
                if [[ -n "$dep_pr" ]] && [[ "$dep_pr" != "null" ]]; then
                    dep_context=" (Dependabot PR #${dep_pr_num}: ${dep_pr})"
                elif [[ -n "$dep_alert" ]] && [[ "$dep_alert" != "null" ]]; then
                    dep_context=" (Dependabot: ${dep_alert})"
                fi

                KNOWN_VULNS+=("${vuln_id}\t${friendly}${dep_context}")
                TOTAL_KNOWN=$((TOTAL_KNOWN + 1))
            else
                # New vuln — will be recorded in memory
                NEW_VULNS+=("${vuln_id}\t${severity}\t${package}\t${version}\t${manifest}\t${SBOM_PATH}\t${ecosystem}")
                TOTAL_NEW=$((TOTAL_NEW + 1))
            fi
        done <<< "$VULN_LINES"
    fi

    # Record manifest scan metadata
    MANIFEST_RECORDS+=("${manifest}\t${ecosystem}\t${MANIFEST_VULN_COUNT}\t${SBOM_PATH}")
done

# --- Update .vulnetix/memory.yaml ---

if [[ $TOTAL_NEW -gt 0 ]] || [[ ${#MANIFEST_RECORDS[@]} -gt 0 ]]; then
    ensure_memory_file

    # Write new vulnerability entries
    for entry in "${NEW_VULNS[@]}"; do
        IFS=$'\t' read -r vuln_id severity package version manifest sbom_path ecosystem <<< "$entry"
        append_vuln_entry "$vuln_id" "$package" "$ecosystem" "$severity" "$version" "$manifest" "$sbom_path" "$SCAN_TIMESTAMP"
    done

    # Build and write manifests section
    MANIFESTS_YAML="manifests:"
    if [[ ${#MANIFEST_RECORDS[@]} -gt 0 ]]; then
        for record in "${MANIFEST_RECORDS[@]}"; do
            IFS=$'\t' read -r manifest ecosystem vuln_count sbom_path <<< "$record"
            # Use the manifest path as a sanitized key (replace / with --)
            manifest_key=$(echo "$manifest" | sed 's|/|--|g')
            MANIFESTS_YAML="${MANIFESTS_YAML}
  ${manifest_key}:
    path: \"${manifest}\"
    ecosystem: ${ecosystem}
    last_scanned: \"${SCAN_TIMESTAMP}\"
    sbom_generated: true
    sbom_path: \"${sbom_path}\"
    vuln_count: ${vuln_count}
    scan_source: hook"
        done
    else
        MANIFESTS_YAML="manifests: {}"
    fi

    write_manifests_section "$MANIFESTS_YAML"
fi

# --- Build systemMessage ---

if [[ $TOTAL_NEW -gt 0 ]] || [[ $TOTAL_KNOWN -gt 0 ]]; then
    MESSAGE="Vulnetix pre-commit scan results:\n"

    # New vulnerabilities
    if [[ $TOTAL_NEW -gt 0 ]]; then
        MESSAGE="${MESSAGE}\n${TOTAL_NEW} new vulnerabilities:\n"
        for entry in "${NEW_VULNS[@]}"; do
            IFS=$'\t' read -r vuln_id severity package version manifest _ _ <<< "$entry"
            MESSAGE="${MESSAGE}• ${vuln_id} (${severity}) — ${package}@${version} in ${manifest}\n"
        done
    fi

    # Previously tracked vulnerabilities
    if [[ $TOTAL_KNOWN -gt 0 ]]; then
        MESSAGE="${MESSAGE}\n${TOTAL_KNOWN} previously tracked:\n"
        for entry in "${KNOWN_VULNS[@]}"; do
            IFS=$'\t' read -r vuln_id friendly_status <<< "$entry"
            MESSAGE="${MESSAGE}• ${vuln_id} — ${friendly_status}\n"
        done
    fi

    # Scanned manifests summary
    MANIFEST_SUMMARY=""
    for record in "${MANIFEST_RECORDS[@]}"; do
        IFS=$'\t' read -r manifest ecosystem _ _ <<< "$record"
        if [[ -n "$MANIFEST_SUMMARY" ]]; then
            MANIFEST_SUMMARY="${MANIFEST_SUMMARY}, "
        fi
        MANIFEST_SUMMARY="${MANIFEST_SUMMARY}${manifest} (${ecosystem})"
    done
    MESSAGE="${MESSAGE}\nManifests scanned: ${MANIFEST_SUMMARY}\nSBOMs saved to ${SCANS_DIR}/\n"

    if [[ $TOTAL_NEW -gt 0 ]]; then
        MESSAGE="${MESSAGE}\nReview with \`/vulnetix:fix <vuln-id>\` or \`/vulnetix:exploits <vuln-id>\`."
    fi

    # Use printf to interpret \n, then pass to jq for proper JSON escaping
    FORMATTED=$(printf "%b" "$MESSAGE")
    jq -n --arg msg "$FORMATTED" '{"systemMessage": $msg}'

elif [[ ${#MANIFEST_RECORDS[@]} -gt 0 ]]; then
    # No vulns at all — brief confirmation with manifest tracking
    MANIFEST_SUMMARY=""
    for record in "${MANIFEST_RECORDS[@]}"; do
        IFS=$'\t' read -r manifest ecosystem _ _ <<< "$record"
        if [[ -n "$MANIFEST_SUMMARY" ]]; then
            MANIFEST_SUMMARY="${MANIFEST_SUMMARY}, "
        fi
        MANIFEST_SUMMARY="${MANIFEST_SUMMARY}${manifest} (${ecosystem})"
    done
    jq -n --arg msg "Vulnetix: No vulnerabilities found in staged dependencies. Manifests scanned: ${MANIFEST_SUMMARY}. SBOMs saved to ${SCANS_DIR}/." '{"systemMessage": $msg}'
fi

exit 0
