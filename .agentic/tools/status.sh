#!/usr/bin/env bash
# status.sh - Update specific sections of STATUS.md (token-efficient)
#
# Usage:
#   bash .agentic/tools/status.sh focus "Working on F-0003"
#   bash .agentic/tools/status.sh progress "60% complete"
#   bash .agentic/tools/status.sh next "Deploy to staging"
#   bash .agentic/tools/status.sh blocker "Waiting for API key"
#   bash .agentic/tools/status.sh blocker "None"  # Clear blocker
#   bash .agentic/tools/status.sh infer           # Infer current state from history
#   bash .agentic/tools/status.sh infer --apply   # Infer and auto-update STATUS.md
#
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATUS_FILE="${PROJECT_ROOT}/STATUS.md"

# Read current values from STATUS.md sections
_read_current() {
    local focus="" progress="" next_step="" blocker=""

    if [[ -f "${STATUS_FILE}" ]]; then
        focus=$(awk '/^## Current session state/,/^## /{if(/^- /) {gsub(/^- /,""); gsub(/ \(Updated:.*\)/,""); print; exit}}' "${STATUS_FILE}" 2>/dev/null || echo "")
        progress=$(awk '/^## Current session state/,/^## /{if(/^- Progress: /) {gsub(/^- Progress: /,""); print; exit}}' "${STATUS_FILE}" 2>/dev/null || echo "")
        next_step=$(awk '/^## Next immediate step/,/^## /{if(/^- /) {gsub(/^- /,""); print; exit}}' "${STATUS_FILE}" 2>/dev/null || echo "")
        blocker=$(awk '/^## Blockers/,/^## /{if(/^- /) {gsub(/^- /,""); gsub(/ \(Added:.*\)/,""); print; exit}}' "${STATUS_FILE}" 2>/dev/null || echo "None")
    fi

    # Export to caller via global variables
    _CURRENT_FOCUS="${focus:-Not set}"
    _CURRENT_PROGRESS="${progress:-}"
    _CURRENT_NEXT="${next_step:-Not set}"
    _CURRENT_BLOCKER="${blocker:-None}"
}

# Apply values to STATUS.md using awk section replacement (proven, well-tested)
_apply_to_md() {
    local focus="$1"
    local progress="$2"
    local next_step="$3"
    local blocker="$4"
    local timestamp
    timestamp=$(date +"%Y-%m-%dT%H:%M:%S%z")

    # Convert ISO timestamp to readable format with timezone
    local readable_date
    readable_date=$(date "+%Y-%m-%d %H:%M %Z" 2>/dev/null || echo "$timestamp")

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

# Read current values, override one field, write back to STATUS.md
update_md() {
    local field="$1"
    local value="$2"

    _read_current

    local focus="${_CURRENT_FOCUS}"
    local progress="${_CURRENT_PROGRESS}"
    local next_step="${_CURRENT_NEXT}"
    local blocker="${_CURRENT_BLOCKER}"

    case "${field}" in
        focus) focus="$value" ;;
        progress) progress="$value" ;;
        next) next_step="$value" ;;
        blocker) blocker="$value" ;;
    esac

    _apply_to_md "$focus" "$progress" "$next_step" "$blocker"
}

# Infer current project state from history data
infer_status() {
    local apply="${1:-}"
    local version="" focus="" next_step="" blocker="None"

    echo "═══════════════════════════════════════════════════════"
    echo "STATUS INFERENCE (from git log, JOURNAL, FEATURES)"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    # --- Source 1: VERSION ---
    if [[ -f "${PROJECT_ROOT}/VERSION" ]]; then
        version=$(head -1 "${PROJECT_ROOT}/VERSION" | tr -d '[:space:]')
        echo "📌 Version: ${version}"
    fi

    # --- Source 2: Git log since STATUS.md was last modified ---
    echo ""
    echo "📋 Recent git activity (since STATUS.md last updated):"
    if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
        local status_mtime=""
        if [[ "$(uname)" == "Darwin" ]]; then
            status_mtime=$(stat -f %m "${STATUS_FILE}" 2>/dev/null || echo "0")
        else
            status_mtime=$(stat -c %Y "${STATUS_FILE}" 2>/dev/null || echo "0")
        fi

        local since_date
        if [[ "$status_mtime" != "0" ]]; then
            if [[ "$(uname)" == "Darwin" ]]; then
                since_date=$(date -r "$status_mtime" "+%Y-%m-%d" 2>/dev/null || echo "")
            else
                since_date=$(date -d "@$status_mtime" "+%Y-%m-%d" 2>/dev/null || echo "")
            fi
        fi

        local git_log=""
        if [[ -n "${since_date:-}" ]]; then
            git_log=$(git log --oneline --since="${since_date}" -20 2>/dev/null || echo "")
        fi
        if [[ -z "$git_log" ]]; then
            git_log=$(git log --oneline -10 2>/dev/null || echo "(no git history)")
        fi
        echo "$git_log" | sed 's/^/   /'

        # Try to infer focus from most recent commit
        local latest_commit
        latest_commit=$(echo "$git_log" | head -1 | sed 's/^[a-f0-9]* //' || echo "")
        if [[ -n "$latest_commit" ]]; then
            focus="$latest_commit"
        fi
    else
        echo "   (git not available)"
    fi

    # --- Source 3: Last JOURNAL.md entry ---
    echo ""
    echo "📓 Last JOURNAL.md entry:"
    local journal_file=""
    if [[ -f "${PROJECT_ROOT}/.agentic-journal/JOURNAL.md" ]]; then
        journal_file="${PROJECT_ROOT}/.agentic-journal/JOURNAL.md"
    elif [[ -f "${PROJECT_ROOT}/JOURNAL.md" ]]; then
        journal_file="${PROJECT_ROOT}/JOURNAL.md"
    fi

    if [[ -n "$journal_file" ]]; then
        # Extract the last session entry (everything after the last "### Session:")
        local last_entry
        last_entry=$(awk '/^### Session:/{buf=""; capturing=1} capturing{buf=buf"\n"$0} END{print buf}' "$journal_file" 2>/dev/null || echo "")

        if [[ -n "$last_entry" ]]; then
            echo "$last_entry" | head -20 | sed 's/^/   /'

            # Parse structured fields
            local journal_next
            journal_next=$(echo "$last_entry" | awk '/^\*\*Next steps\*\*:/{found=1; next} found && /^\*\*/{exit} found{print}' | sed 's/^- //' | head -3 | tr '\n' '; ' | sed 's/;[; ]*$//')
            if [[ -n "$journal_next" ]]; then
                next_step="$journal_next"
            fi

            local journal_blockers
            journal_blockers=$(echo "$last_entry" | grep '^\*\*Blockers\*\*:' | sed 's/\*\*Blockers\*\*: *//')
            if [[ -n "$journal_blockers" ]] && [[ "$journal_blockers" != "None" ]]; then
                blocker="$journal_blockers"
            fi
        else
            echo "   (no entries found)"
        fi
    else
        echo "   (JOURNAL.md not found)"
    fi

    # --- Source 4: In-progress features ---
    echo ""
    echo "🔧 In-progress features:"
    if [[ -f "${PROJECT_ROOT}/spec/FEATURES.md" ]]; then
        local in_progress
        in_progress=$(grep -B1 "Status: in_progress" "${PROJECT_ROOT}/spec/FEATURES.md" | grep "^## F-" | sed 's/^## //' || echo "")
        if [[ -n "$in_progress" ]]; then
            echo "$in_progress" | sed 's/^/   - /'
            # Use first in-progress feature as focus if no git-based focus
            if [[ -z "$focus" ]]; then
                focus=$(echo "$in_progress" | head -1)
            fi
        else
            echo "   (none)"
        fi
    else
        echo "   (no spec/FEATURES.md)"
    fi

    # --- Source 5: CHANGELOG.md latest entry ---
    echo ""
    echo "📝 Latest CHANGELOG entry:"
    if [[ -f "${PROJECT_ROOT}/CHANGELOG.md" ]]; then
        # Get the first version section (latest)
        awk '/^## \[/{count++} count==1{print} count>1{exit}' "${PROJECT_ROOT}/CHANGELOG.md" | head -10 | sed 's/^/   /'
    else
        echo "   (no CHANGELOG.md)"
    fi

    # --- Summary ---
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "INFERRED STATUS:"
    echo "═══════════════════════════════════════════════════════"
    echo "  Focus:   ${focus:-Unknown}"
    echo "  Next:    ${next_step:-Unknown}"
    echo "  Blocker: ${blocker}"
    echo "  Version: ${version:-Unknown}"
    echo ""

    if [[ "$apply" == "--apply" ]]; then
        # Read current values as baseline, then override with inferred
        _read_current
        local progress="${_CURRENT_PROGRESS}"
        [[ -n "$focus" ]] && true || focus="${_CURRENT_FOCUS}"
        [[ -n "$next_step" ]] && true || next_step="${_CURRENT_NEXT}"

        _apply_to_md "${focus:-${_CURRENT_FOCUS}}" "$progress" "${next_step:-${_CURRENT_NEXT}}" "$blocker"
        echo "✓ Applied inferred state to STATUS.md"
    else
        echo "To apply: bash .agentic/tools/status.sh infer --apply"
        echo "Or update manually with better context."
    fi
}

# Check if STATUS.md exists
if [[ ! -f "${STATUS_FILE}" ]]; then
    echo "Error: STATUS.md not found."
    echo "Run: bash .agentic/init/scaffold.sh"
    exit 1
fi

# Arguments
FIELD="${1:-}"
VALUE="${2:-}"

# Handle infer command
if [[ "${FIELD}" == "infer" ]]; then
    infer_status "${VALUE}"
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
  infer     - Infer current state from git/journal/features
              Add --apply to auto-update STATUS.md

Examples:
  bash status.sh focus "Implementing F-0003: User login"
  bash status.sh progress "70% - 3 of 5 criteria complete"
  bash status.sh next "Add email verification"
  bash status.sh blocker "Waiting for design mockups"
  bash status.sh blocker "None"
  bash status.sh infer
  bash status.sh infer --apply
USAGE
    exit 1
fi

# Update the appropriate field
case "${FIELD}" in
    focus|progress|next|blocker)
        update_md "${FIELD}" "${VALUE}"
        echo "✓ Updated ${FIELD} in STATUS.md"
        ;;
    *)
        echo "Error: Unknown field '${FIELD}'"
        echo "Valid fields: focus, progress, next, blocker"
        exit 1
        ;;
esac
