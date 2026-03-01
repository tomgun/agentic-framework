#!/usr/bin/env bash
# periodic-checks.sh — Frequency-gated lifecycle checks
#
# Called by sync.sh Phase 7. Each check has a configurable frequency
# (every_session, every_N_sessions) stored in STACK.md ## Settings.
#
# State: .agentic-state/sync-state.conf (flat key=value)
# Config: STACK.md periodic_* settings, defaults from profiles.conf
#
# Usage:
#   bash .agentic/tools/periodic-checks.sh              # Run all due checks
#   bash .agentic/tools/periodic-checks.sh --quiet       # One-line summary
#   bash .agentic/tools/periodic-checks.sh --check       # Dry run
#   bash .agentic/tools/periodic-checks.sh --increment   # Just bump session counter
#
# Exit code: always 0 (advisory tool)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source shared settings
source "$SCRIPT_DIR/../lib/settings.sh"

# Colors (disabled if not TTY)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' BOLD='' DIM='' NC=''
fi

# --- Parse flags ---
MODE="full"
for arg in "$@"; do
    case "$arg" in
        --quiet) MODE="quiet" ;;
        --check) MODE="check" ;;
        --increment) MODE="increment" ;;
        -h|--help)
            echo "Usage: bash .agentic/tools/periodic-checks.sh [--quiet|--check|--increment]"
            exit 0
            ;;
    esac
done

# --- State file management ---
STATE_DIR="$ROOT_DIR/.agentic-state"
STATE_FILE="$STATE_DIR/sync-state.conf"

# Ensure state dir exists
mkdir -p "$STATE_DIR"

load_state_value() {
    local key="$1"
    local default="${2:-}"
    if [ -f "$STATE_FILE" ]; then
        local val
        val=$(grep "^${key}=" "$STATE_FILE" 2>/dev/null | tail -1 | sed "s/^${key}=//")
        if [ -n "$val" ]; then
            echo "$val"
            return
        fi
    fi
    echo "$default"
}

save_state_value() {
    local key="$1"
    local value="$2"
    if [ ! -f "$STATE_FILE" ]; then
        echo "# Sync state (auto-maintained by periodic-checks.sh)" > "$STATE_FILE"
    fi
    if grep -q "^${key}=" "$STATE_FILE" 2>/dev/null; then
        # Update existing — use grep+write to avoid sed escaping issues with URLs/special chars
        local tmp_file="${STATE_FILE}.tmp"
        grep -v "^${key}=" "$STATE_FILE" > "$tmp_file" || true
        echo "${key}=${value}" >> "$tmp_file"
        mv "$tmp_file" "$STATE_FILE"
    else
        echo "${key}=${value}" >> "$STATE_FILE"
    fi
}

# --- Session counter ---
increment_session_count() {
    local current
    current=$(load_state_value "session_count" "0")
    local next=$((current + 1))
    save_state_value "session_count" "$next"
    save_state_value "last_sync" "$(date +%Y-%m-%d)"
    echo "$next"
}

# --- Frequency evaluation ---
# Parses "every_session", "every_5_sessions", "off"
# Returns 0 (should run) or 1 (skip)
should_run_check() {
    local check_name="$1"
    local frequency="$2"

    # "off" or empty = never run
    if [ -z "$frequency" ] || [ "$frequency" = "off" ]; then
        return 1
    fi

    # "every_session" = always run
    if [ "$frequency" = "every_session" ]; then
        return 0
    fi

    # "every_N_sessions" = check session counter
    local interval
    interval=$(echo "$frequency" | grep -oE '[0-9]+' || echo "")
    if [ -z "$interval" ]; then
        return 1
    fi

    local current_session
    current_session=$(load_state_value "session_count" "0")
    local last_session
    last_session=$(load_state_value "${check_name}.last_session" "0")
    local sessions_since=$((current_session - last_session))

    if [ "$sessions_since" -ge "$interval" ]; then
        return 0
    fi
    return 1
}

# Mark a check as having run this session
mark_check_run() {
    local check_name="$1"
    local current_session
    current_session=$(load_state_value "session_count" "0")
    save_state_value "${check_name}.last_run" "$(date +%Y-%m-%d)"
    save_state_value "${check_name}.last_session" "$current_session"
}

# --- Counters (matching sync.sh pattern) ---
ISSUE_COUNT=0
ISSUE_SUMMARY=()

record_issue() {
    local desc="$1"
    ((ISSUE_COUNT++))
    ISSUE_SUMMARY+=("$desc")
}

# --- Project fingerprint ---
get_project_fingerprint() {
    local fingerprint
    fingerprint=$(git remote get-url origin 2>/dev/null || echo "")
    if [ -z "$fingerprint" ]; then
        fingerprint=$(basename "$ROOT_DIR")
    fi
    echo "$fingerprint"
}

# --- Check: Orphaned Plans ---
check_orphaned_plans() {
    local claude_plans_dir="$HOME/.claude/plans"

    # Skip if ~/.claude/plans/ doesn't exist
    if [ ! -d "$claude_plans_dir" ]; then
        return 0
    fi

    # Get project fingerprint
    local fingerprint
    fingerprint=$(get_project_fingerprint)
    save_state_value "project_fingerprint" "$fingerprint"

    # Extract feature IDs from FEATURES.md (if it exists)
    local feature_ids=""
    if [ -f "$ROOT_DIR/spec/FEATURES.md" ]; then
        feature_ids=$(grep -oE 'F-[0-9]{4}' "$ROOT_DIR/spec/FEATURES.md" 2>/dev/null | sort -u | tr '\n' '|' | sed 's/|$//')
    fi

    # Get last sync date for recency filter
    local last_sync
    last_sync=$(load_state_value "last_sync" "1970-01-01")

    # Scan plans modified since last sync (or all if first run)
    local orphans=()
    local plan_journal_dir="$ROOT_DIR/.agentic-journal/plans"
    local find_newer_args=()
    if [ "$last_sync" != "1970-01-01" ]; then
        # Create a reference file with the last_sync timestamp for -newer comparison
        local ref_file="${STATE_DIR}/.sync-date-ref"
        touch -t "$(echo "$last_sync" | sed 's/-//g')0000" "$ref_file" 2>/dev/null || true
        if [ -f "$ref_file" ]; then
            find_newer_args=(-newer "$ref_file")
        fi
    fi

    while IFS= read -r plan_file; do
        [ -f "$plan_file" ] || continue
        local plan_basename
        plan_basename=$(basename "$plan_file")

        # Check if plan matches this project
        # Priority: fingerprint match (reliable) > feature ID match (may collide across projects)
        local matches=false

        if grep -qF "$fingerprint" "$plan_file" 2>/dev/null; then
            matches=true
        elif [ -n "$feature_ids" ]; then
            # Feature ID matching: only use if plan has >=2 matching IDs (reduces false positives
            # from common IDs like F-0001 appearing in unrelated projects)
            local match_count
            match_count=$(grep -oE 'F-[0-9]{4}' "$plan_file" 2>/dev/null | grep -cE "^($feature_ids)$" 2>/dev/null || echo "0")
            if [ "$match_count" -ge 2 ]; then
                matches=true
            fi
        fi

        if [ "$matches" = true ]; then
            # Check if already saved in journal/plans
            local already_saved=false
            if [ -d "$plan_journal_dir" ]; then
                local plan_fids
                plan_fids=$(grep -oE 'F-[0-9]{4}' "$plan_file" 2>/dev/null | sort -u || echo "")
                for fid in $plan_fids; do
                    if grep -rl "$fid" "$plan_journal_dir/" 2>/dev/null | head -1 | grep -q .; then
                        already_saved=true
                        break
                    fi
                done
            fi

            if [ "$already_saved" = false ]; then
                orphans+=("$plan_basename")
            fi
        fi
    done < <(if [ ${#find_newer_args[@]} -gt 0 ]; then find "$claude_plans_dir" -name "*.md" -type f "${find_newer_args[@]}" 2>/dev/null; else find "$claude_plans_dir" -name "*.md" -type f 2>/dev/null; fi)

    if [ ${#orphans[@]} -gt 0 ]; then
        record_issue "${#orphans[@]} orphaned plan(s)"
        if [ "$MODE" != "quiet" ]; then
            echo -e "Plans:      ${YELLOW}${#orphans[@]} unsaved plan(s) in ~/.claude/plans/${NC}"
            for orphan in "${orphans[@]}"; do
                echo -e "            $orphan"
            done
            echo -e "            ${DIM}Copy relevant plans to .agentic-journal/plans/${NC}"
        fi
    elif [ "$MODE" != "quiet" ] && [ "$MODE" != "increment" ]; then
        echo -e "Plans:      ${GREEN}OK (no orphaned plans)${NC}"
    fi
}

# --- Check: Retro Due ---
check_retro_due() {
    # Only run if retrospectives are enabled in STACK.md
    if ! grep -qE '^\s*-?\s*retrospective_enabled:\s*yes' "$ROOT_DIR/STACK.md" 2>/dev/null; then
        return 0
    fi

    local retro_exit=0
    bash "$SCRIPT_DIR/retro_check.sh" > /dev/null 2>&1 || retro_exit=$?

    if [ "$retro_exit" -eq 1 ]; then
        record_issue "retrospective due"
        if [ "$MODE" != "quiet" ]; then
            echo -e "Retro:      ${YELLOW}DUE — run a project retrospective${NC}"
            echo -e "            ${DIM}See: .agentic/workflows/retrospective.md${NC}"
        fi
    elif [ "$MODE" != "quiet" ] && [ "$MODE" != "increment" ]; then
        echo -e "Retro:      ${GREEN}OK${NC}"
    fi
}

# --- Check: Agent Freshness (for F-0146 project agents) ---
check_agent_freshness() {
    local project_agents_dir="$ROOT_DIR/.agentic/agents/claude/subagents-project"
    if [ ! -d "$project_agents_dir" ]; then
        if [ "$MODE" != "quiet" ] && [ "$MODE" != "increment" ]; then
            echo -e "Agents:     ${DIM}no project agents (run ag agents generate)${NC}"
        fi
        return 0
    fi

    # Check if STACK.md changed since last agent generation
    local stack_mtime=""
    if [ -f "$ROOT_DIR/STACK.md" ]; then
        stack_mtime=$(git log -1 --format="%H" -- STACK.md 2>/dev/null || echo "")
    fi
    local last_gen_hash
    last_gen_hash=$(load_state_value "agent_gen.stack_hash" "")

    if [ -n "$stack_mtime" ] && [ "$stack_mtime" != "$last_gen_hash" ]; then
        record_issue "project agents may be stale"
        if [ "$MODE" != "quiet" ]; then
            echo -e "Agents:     ${YELLOW}STACK.md changed since last generation${NC}"
            echo -e "            ${DIM}Run: ag agents generate${NC}"
        fi
    elif [ "$MODE" != "quiet" ] && [ "$MODE" != "increment" ]; then
        echo -e "Agents:     ${GREEN}OK${NC}"
    fi
}

# ============================================================================
# Main
# ============================================================================
main() {
    # --increment: just bump counter and exit (sync.sh calls this separately)
    if [ "$MODE" = "increment" ]; then
        local session_num
        session_num=$(increment_session_count)
        echo "$session_num"
        exit 0
    fi

    # All other modes: read current session count (don't increment)
    local session_num
    session_num=$(load_state_value "session_count" "0")

    # Get frequencies from settings
    local freq_orphaned_plans
    freq_orphaned_plans=$(get_setting "periodic_orphaned_plans" "every_session")
    local freq_retro
    freq_retro=$(get_setting "periodic_retro_check" "every_5_sessions")
    local freq_agent_refresh
    freq_agent_refresh=$(get_setting "periodic_agent_refresh" "every_20_sessions")

    # Run checks that are due
    if should_run_check "orphaned_plans" "$freq_orphaned_plans"; then
        check_orphaned_plans
        mark_check_run "orphaned_plans"
    fi

    if should_run_check "retro_check" "$freq_retro"; then
        check_retro_due
        mark_check_run "retro_check"
    fi

    if should_run_check "agent_freshness" "$freq_agent_refresh"; then
        check_agent_freshness
        mark_check_run "agent_freshness"
    fi

    # Output summary
    if [ "$MODE" = "quiet" ] || [ "$MODE" = "check" ]; then
        # In quiet/check modes, only print if there are issues
        if [ "$ISSUE_COUNT" -gt 0 ]; then
            local summary
            summary=$(IFS=', '; echo "${ISSUE_SUMMARY[*]}")
            echo "Periodic: $ISSUE_COUNT issue(s) ($summary)"
        fi
    elif [ "$ISSUE_COUNT" -eq 0 ]; then
        echo -e "Periodic:   ${GREEN}all checks passed (session #$session_num)${NC}"
    fi

    exit 0
}

main
