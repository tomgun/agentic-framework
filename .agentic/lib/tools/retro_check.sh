#!/usr/bin/env bash
# retro_check.sh — Check if retrospective is due
#
# Usage:
#   bash retro_check.sh              # Check triggers, exit 1 if due
#   bash retro_check.sh --status     # Show retro tracking status
#
# Uses settings framework (get_setting) instead of raw grep.
# Supports BOTH old STACK.md section format and new settings format.
#
# Exit: 0 = not due, 1 = due

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Source shared libraries (settings framework)
source "$SCRIPT_DIR/../paths.sh" 2>/dev/null || true
source "$SCRIPT_DIR/../settings.sh" 2>/dev/null || true

STATUS_FILE="${STATUS_FILE:-$ROOT_DIR/.agentic/STATUS.md}"
STACK_FILE="${STACK_FILE:-$ROOT_DIR/STACK.md}"
STATE_DIR="$ROOT_DIR/.agentic/session"
STATE_FILE="$STATE_DIR/sync-state.conf"

# --- Settings (prefer settings framework, fall back to raw STACK.md grep) ---

_get_retro_setting() {
    local key="$1"
    local default="$2"

    # Try settings framework first
    if type get_setting &>/dev/null; then
        local val
        val=$(get_setting "$key" "" 2>/dev/null)
        if [ -n "$val" ]; then
            echo "$val"
            return
        fi
    fi

    # Fall back to raw STACK.md grep (backwards compat)
    if [ -f "$STACK_FILE" ]; then
        local val
        val=$(grep -E "^\s*-?\s*${key}:" "$STACK_FILE" 2>/dev/null | head -1 | sed 's/.*: *//' | sed 's/#.*//' | tr -d ' ')
        if [ -n "$val" ]; then
            echo "$val"
            return
        fi
    fi

    echo "$default"
}

# --- State helpers ---

_load_state() {
    local key="$1"
    local default="${2:-}"
    if [ -f "$STATE_FILE" ]; then
        local val
        val=$(grep "^${key}=" "$STATE_FILE" 2>/dev/null | tail -1 | sed "s/^${key}=//")
        if [ -n "$val" ]; then echo "$val"; return; fi
    fi
    echo "$default"
}

_save_state() {
    local key="$1"
    local value="$2"
    mkdir -p "$STATE_DIR"
    if [ ! -f "$STATE_FILE" ]; then
        echo "# Sync state" > "$STATE_FILE"
    fi
    if grep -q "^${key}=" "$STATE_FILE" 2>/dev/null; then
        local tmp="${STATE_FILE}.tmp"
        grep -v "^${key}=" "$STATE_FILE" > "$tmp" || true
        echo "${key}=${value}" >> "$tmp"
        mv "$tmp" "$STATE_FILE"
    else
        echo "${key}=${value}" >> "$STATE_FILE"
    fi
}

# --- Status mode ---

cmd_status() {
    local last_date
    last_date=$(_load_state "retro.last_date" "")
    local last_report
    last_report=$(_load_state "retro.last_report" "")
    local total
    total=$(_load_state "retro.action_items_total" "0")
    local completed
    completed=$(_load_state "retro.action_items_completed" "0")
    local next_due
    next_due=$(_load_state "retro.next_due_date" "")

    if [ -z "$last_date" ]; then
        echo "No retrospective recorded yet."
        # Check if there are retro reports on disk
        local retro_dir="$ROOT_DIR/docs/retrospectives"
        if [ -d "$retro_dir" ]; then
            local latest_retro
            latest_retro=$(find "$retro_dir" -name "RETRO-*.md" -o -name "retro_*.md" 2>/dev/null | sort | tail -1)
            if [ -n "$latest_retro" ]; then
                echo "  Found report: $(basename "$latest_retro")"
                # Try to parse action items
                local total_items completed_items
                total_items=$(grep -cE '^\s*-\s*\[' "$latest_retro" 2>/dev/null || echo "0")
                completed_items=$(grep -cE '^\s*-\s*\[x\]' "$latest_retro" 2>/dev/null || echo "0")
                if [ "$total_items" -gt 0 ]; then
                    echo "  Action items: $completed_items/$total_items completed"
                    _save_state "retro.last_report" "$latest_retro"
                    _save_state "retro.action_items_total" "$total_items"
                    _save_state "retro.action_items_completed" "$completed_items"
                fi
            fi
        fi
        return
    fi

    echo "Last retrospective: $last_date"
    if [ -n "$last_report" ]; then
        echo "  Report: $last_report"
    fi
    local remaining=$((total - completed))
    echo "  Action items: $completed/$total completed ($remaining remaining)"
    if [ -n "$next_due" ]; then
        echo "  Next due: $next_due"
    fi

    # Show QA audit status if tracker exists
    local tracker="$ROOT_DIR/.agentic/session/.qa-tracker.json"
    if [ -f "$tracker" ]; then
        local qa_status
        qa_status=$(bash "$SCRIPT_DIR/qa-tracker.sh" status 2>/dev/null || echo "")
        if [ -n "$qa_status" ]; then
            echo "  $qa_status"
        fi
    fi
}

# --- Check mode ---

cmd_check() {
    # Check if retrospectives are enabled
    local retro_enabled
    retro_enabled=$(_get_retro_setting "retrospective_enabled" "no")

    if [ "$retro_enabled" != "yes" ]; then
        echo "Retrospectives not enabled."
        echo "To enable: ag set retrospective_enabled yes"
        exit 0
    fi

    echo "=== Retrospective Check ==="
    echo

    local trigger
    trigger=$(_get_retro_setting "retrospective_trigger" "both")
    local interval_days
    interval_days=$(_get_retro_setting "retrospective_interval_days" "14")
    local interval_features
    interval_features=$(_get_retro_setting "retrospective_interval_features" "10")

    echo "Configuration:"
    echo "  Trigger: ${trigger}"
    echo "  Interval (days): ${interval_days}"
    echo "  Interval (features): ${interval_features}"
    echo

    # Get last retrospective date from state or STATUS.md
    local last_retro_date
    last_retro_date=$(_load_state "retro.last_date" "")
    if [ -z "$last_retro_date" ] && [ -f "$STATUS_FILE" ]; then
        last_retro_date=$(grep -E 'Last retrospective:' "$STATUS_FILE" 2>/dev/null \
            | head -1 | sed 's/.*: *//' | awk '{print $1}')
    fi

    if [ -z "$last_retro_date" ]; then
        echo "No retrospective recorded yet. Consider running your first!"
        echo "  See: ag retro"
        exit 0
    fi

    echo "Last retrospective: ${last_retro_date}"

    # Check time-based trigger
    if [[ "${trigger}" == "time" || "${trigger}" == "both" ]]; then
        local days_diff=0
        if command -v python3 &>/dev/null; then
            days_diff=$(python3 -c "
from datetime import datetime
try:
    last = datetime.strptime('$last_retro_date', '%Y-%m-%d')
    diff = (datetime.now() - last).days
    print(diff)
except: print(0)
" 2>/dev/null || echo "0")
        elif command -v gdate &>/dev/null; then
            local last_ts current_ts
            last_ts=$(gdate -d "${last_retro_date}" +%s 2>/dev/null || echo "0")
            current_ts=$(gdate +%s)
            days_diff=$(( (current_ts - last_ts) / 86400 ))
        else
            echo "Warning: Cannot compute days since last retro (need python3 or gdate)"
        fi

        echo "Days since last retrospective: ${days_diff}"

        if [ "${days_diff}" -ge "${interval_days}" ]; then
            echo
            echo "TIME TRIGGER MET: ${days_diff} days >= ${interval_days} days threshold"
            echo "Retrospective is due! Run: ag retro"
            exit 1
        fi
    fi

    # Check feature-based trigger
    if [[ "${trigger}" == "features" || "${trigger}" == "both" ]]; then
        local features_file="$ROOT_DIR/.agentic/spec/FEATURES.md"
        if [ -f "$features_file" ]; then
            local last_retro_features
            last_retro_features=$(_load_state "retro.last_feature_count" "0")
            local current_shipped
            current_shipped=$(grep -c 'Status.*shipped' "$features_file" 2>/dev/null || echo "0")
            local features_since=$((current_shipped - last_retro_features))

            echo "Features shipped since last retrospective: ${features_since}"

            if [ "${features_since}" -ge "${interval_features}" ]; then
                echo
                echo "FEATURE TRIGGER MET: ${features_since} features >= ${interval_features} threshold"
                echo "Retrospective is due! Run: ag retro"
                exit 1
            fi
        fi
    fi

    echo
    echo "No retrospective triggers met."
    exit 0
}

# --- Main ---

case "${1:-}" in
    --status)
        cmd_status
        ;;
    *)
        cmd_check
        ;;
esac
