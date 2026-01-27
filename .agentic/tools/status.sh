#!/usr/bin/env bash
# status.sh - Update specific sections of STATUS.md (token-efficient)
#
# Usage:
#   bash .agentic/tools/status.sh focus "Working on F-0003"
#   bash .agentic/tools/status.sh progress "60% complete"
#   bash .agentic/tools/status.sh next "Deploy to staging"
#   bash .agentic/tools/status.sh blocker "Waiting for API key"
#   bash .agentic/tools/status.sh blocker "None"  # Clear blocker
#   bash .agentic/tools/status.sh sync            # Regenerate STATUS.md from JSON
#
# Token efficiency: Updates JSON state file (fast), syncs to MD on demand
#
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATUS_FILE="${PROJECT_ROOT}/STATUS.md"
STATE_DIR="${PROJECT_ROOT}/.agentic/state"
STATE_FILE="${STATE_DIR}/status.json"

# Ensure state directory exists
mkdir -p "${STATE_DIR}"

# Initialize JSON state from STATUS.md if it doesn't exist
init_state() {
    if [[ ! -f "${STATE_FILE}" ]]; then
        # Extract current values from STATUS.md if it exists
        local focus="" progress="" next_step="" blocker=""

        if [[ -f "${STATUS_FILE}" ]]; then
            # Try to extract existing values (best effort)
            focus=$(awk '/^## Current session state/,/^## /{if(/^- /) {gsub(/^- /,""); gsub(/ \(Updated:.*\)/,""); print; exit}}' "${STATUS_FILE}" 2>/dev/null || echo "")
            next_step=$(awk '/^## Next immediate step/,/^## /{if(/^- /) {gsub(/^- /,""); print; exit}}' "${STATUS_FILE}" 2>/dev/null || echo "")
            blocker=$(awk '/^## Blockers/,/^## /{if(/^- /) {gsub(/^- /,""); gsub(/ \(Added:.*\)/,""); print; exit}}' "${STATUS_FILE}" 2>/dev/null || echo "None")
        fi

        # Create initial state
        cat > "${STATE_FILE}" <<EOF
{
  "focus": "${focus:-Not set}",
  "progress": "${progress:-}",
  "next": "${next_step:-Not set}",
  "blocker": "${blocker:-None}",
  "updated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
    fi
}

# Read a field from JSON state
read_state() {
    local field="$1"
    if command -v jq &>/dev/null; then
        jq -r ".${field} // \"\"" "${STATE_FILE}" 2>/dev/null || echo ""
    else
        # Fallback without jq - simple grep
        grep "\"${field}\"" "${STATE_FILE}" | sed 's/.*: *"\([^"]*\)".*/\1/' | head -1
    fi
}

# Update a field in JSON state (without jq dependency)
update_state() {
    local field="$1"
    local value="$2"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    if command -v jq &>/dev/null; then
        # Use jq if available (cleaner)
        jq --arg val "$value" --arg ts "$timestamp" \
            ".${field} = \$val | .updated = \$ts" \
            "${STATE_FILE}" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "${STATE_FILE}"
    else
        # Fallback: sed-based update (works without jq)
        local escaped_value
        escaped_value=$(echo "$value" | sed 's/[&/\]/\\&/g; s/"/\\"/g')
        sed -i.bak "s|\"${field}\": \"[^\"]*\"|\"${field}\": \"${escaped_value}\"|" "${STATE_FILE}"
        sed -i.bak "s|\"updated\": \"[^\"]*\"|\"updated\": \"${timestamp}\"|" "${STATE_FILE}"
        rm -f "${STATE_FILE}.bak"
    fi
}

# Regenerate STATUS.md from JSON state
sync_to_md() {
    local focus progress next_step blocker updated

    focus=$(read_state "focus")
    progress=$(read_state "progress")
    next_step=$(read_state "next")
    blocker=$(read_state "blocker")
    updated=$(read_state "updated")

    # Convert ISO timestamp to readable format
    local readable_date
    readable_date=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$updated" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$updated")

    # Update STATUS.md sections using awk (preserves other content)
    awk -v focus="$focus" -v progress="$progress" -v next_step="$next_step" -v blocker="$blocker" -v ts="$readable_date" '
        BEGIN { in_section="" }

        /^## Current session state/ {
            in_section="focus"
            print
            if (progress != "") {
                print "- " focus " (Updated: " ts ")"
                print "- Progress: " progress
            } else {
                print "- " focus " (Updated: " ts ")"
            }
            next
        }

        /^## Next immediate step/ {
            in_section="next"
            print
            print "- " next_step
            next
        }

        /^## Blockers/ {
            in_section="blocker"
            print
            if (blocker == "None" || blocker == "") {
                print "- None"
            } else {
                print "- " blocker " (Added: " ts ")"
            }
            next
        }

        /^## / {
            in_section=""
        }

        in_section != "" && /^- / { next }
        in_section != "" && /^$/ && !seen_blank[in_section] { seen_blank[in_section]=1; print; next }
        in_section != "" && /^$/ { next }

        { print }
    ' "${STATUS_FILE}" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "${STATUS_FILE}"
}

# Check if STATUS.md exists
if [[ ! -f "${STATUS_FILE}" ]]; then
    echo "Error: STATUS.md not found."
    echo "Run: bash .agentic/init/scaffold.sh"
    exit 1
fi

# Initialize state if needed
init_state

# Arguments
FIELD="${1:-}"
VALUE="${2:-}"

# Handle sync command
if [[ "${FIELD}" == "sync" ]]; then
    sync_to_md
    echo "✓ Synchronized STATUS.md from state"
    exit 0
fi

# Handle show command (display current state)
if [[ "${FIELD}" == "show" ]]; then
    echo "Current status state:"
    cat "${STATE_FILE}"
    exit 0
fi

if [[ -z "${FIELD}" ]] || [[ -z "${VALUE}" ]]; then
    cat <<'USAGE'
Usage: bash status.sh <field> <value>

Fields:
  focus     - Current focus/task
  progress  - Progress description
  next      - Next immediate step
  blocker   - Current blocker (use "None" to clear)

Commands:
  sync      - Regenerate STATUS.md from JSON state
  show      - Display current JSON state

Examples:
  bash status.sh focus "Implementing F-0003: User login"
  bash status.sh progress "70% - 3 of 5 criteria complete"
  bash status.sh next "Add email verification"
  bash status.sh blocker "Waiting for design mockups"
  bash status.sh blocker "None"
  bash status.sh sync
USAGE
    exit 1
fi

# Update the appropriate field
case "${FIELD}" in
    focus|progress|next|blocker)
        update_state "${FIELD}" "${VALUE}"
        sync_to_md
        echo "✓ Updated ${FIELD} in STATUS.md"
        ;;
    *)
        echo "Error: Unknown field '${FIELD}'"
        echo "Valid fields: focus, progress, next, blocker"
        exit 1
        ;;
esac
