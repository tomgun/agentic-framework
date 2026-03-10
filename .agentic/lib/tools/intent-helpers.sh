#!/usr/bin/env bash
# intent-helpers.sh — Shell wrappers for intents.py (write-ahead intent journal)
#
# Sourced by ag.sh. Provides intent_write, intent_checkpoint, intent_clear,
# intent_cancel for crash-recovery of multi-step operations.
#
# Design:
#   - All functions use _get_main_root() to resolve the main repo root (works from worktrees)
#   - Session ID is generated once per session and cached in .agentic/session/.current-session-id
#   - Errors from intents.py are logged but never block ag.sh operations —
#     the intent journal is advisory, not gate-blocking
#   - state_enforcement setting (off/advisory/blocking) controls state transitions
#
# Dependencies:
#   - paths.sh must be sourced before this file (provides AGENTIC_LIB, MAIN_PROJECT_ROOT)
#   - python3 must be available
#   - .agentic/lib/auto/intents.py must exist

# Guard against double-sourcing
[[ -n "${_INTENT_HELPERS_LOADED:-}" ]] && return 0
_INTENT_HELPERS_LOADED=1

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# _get_main_root — Discover main repo root (not worktree).
# Uses MAIN_PROJECT_ROOT from paths.sh if available, otherwise resolves via git.
_get_main_root() {
    if [[ -n "${MAIN_PROJECT_ROOT:-}" ]]; then
        echo "$MAIN_PROJECT_ROOT"
        return 0
    fi
    # Fallback: resolve via git
    local git_common git_dir
    git_common=$(git rev-parse --git-common-dir 2>/dev/null) || { echo "${ROOT_DIR:-.}"; return 0; }
    git_dir=$(git rev-parse --git-dir 2>/dev/null) || { echo "${ROOT_DIR:-.}"; return 0; }
    if [[ "$git_common" != "$git_dir" ]]; then
        # In a worktree — main repo is parent of .git/worktrees/../..
        (cd "$(dirname "$git_common")" && pwd)
    else
        echo "${ROOT_DIR:-.}"
    fi
}

# _get_session_id — Read or create a stable session UUID.
# Cached in .agentic/session/.current-session-id.
_get_session_id() {
    local main_root
    main_root=$(_get_main_root)
    local sid_file="$main_root/.agentic/session/.current-session-id"

    # Read existing
    if [[ -f "$sid_file" ]]; then
        local existing
        existing=$(cat "$sid_file" 2>/dev/null | tr -d '[:space:]')
        if [[ -n "$existing" ]]; then
            echo "$existing"
            return 0
        fi
    fi

    # Generate new UUID
    local new_id=""
    if command -v uuidgen >/dev/null 2>&1; then
        new_id=$(uuidgen 2>/dev/null | tr '[:upper:]' '[:lower:]')
    elif [[ -r /proc/sys/kernel/random/uuid ]]; then
        new_id=$(cat /proc/sys/kernel/random/uuid 2>/dev/null)
    else
        # Last resort: python
        new_id=$(python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null) || new_id="fallback-$$-$(date +%s)"
    fi

    # Write to file
    mkdir -p "$(dirname "$sid_file")" 2>/dev/null
    echo "$new_id" > "$sid_file" 2>/dev/null
    echo "$new_id"
}

# _intents_py — Call intents.py with project root set to main repo.
# The script is loaded from the CURRENT checkout (may be worktree),
# but --project-root points to the main repo (for shared session storage).
# Returns exit code from python; caller decides whether to block or warn.
_intents_py() {
    local main_root
    main_root=$(_get_main_root)

    # Resolve intents.py from the current checkout (AGENTIC_LIB is set by paths.sh)
    local intents_script="${AGENTIC_LIB:-${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")}/../}/auto/intents.py"

    if [[ ! -f "$intents_script" ]]; then
        echo "intent-helpers: intents.py not found at $intents_script" >&2
        return 1
    fi

    command -v python3 >/dev/null 2>&1 || {
        echo "intent-helpers: python3 not available" >&2
        return 1
    }

    python3 "$intents_script" --project-root "$main_root" "$@"
}

# _get_state_enforcement — Read state_enforcement setting from STACK.md.
# Returns: off (default), advisory, or blocking.
_get_state_enforcement() {
    get_setting "state_enforcement" "off"
}

# ---------------------------------------------------------------------------
# Public API — called by ag.sh cmd_implement, cmd_done, etc.
# ---------------------------------------------------------------------------

# intent_write — Write a new intent before starting a multi-step operation.
#
# Usage: intent_write <feature_id> <target_state> <command> <steps_csv> [worktree_path]
#   feature_id:    e.g., "F-0042"
#   target_state:  e.g., "implementing"
#   command:       e.g., "implement"
#   steps_csv:     comma-separated step names, e.g., "register_wip,create_worktree,transition_state,update_status"
#   worktree_path: optional absolute path to worktree
#
# Returns 0 on success, 1 on failure (but callers should not block on failure).
intent_write() {
    local feature_id="${1:?intent_write: feature_id required}"
    local target_state="${2:?intent_write: target_state required}"
    local command_name="${3:?intent_write: command required}"
    local steps_csv="${4:?intent_write: steps_csv required}"
    local worktree_path="${5:-}"

    local session_id pid
    session_id=$(_get_session_id)
    pid="${PPID:-$$}"

    # Determine previous state from FEATURES.md (best effort)
    local previous_state=""
    local main_root
    main_root=$(_get_main_root)
    if [[ -f "$main_root/.agentic/spec/FEATURES.md" ]]; then
        previous_state=$(grep -A5 "^## ${feature_id}:" "$main_root/.agentic/spec/FEATURES.md" 2>/dev/null \
            | grep -i "state:" 2>/dev/null \
            | head -1 \
            | sed 's/.*[Ss]tate:[[:space:]]*//' \
            | tr -d '[:space:]' || echo "")
    fi

    local args=(
        write-intent "$feature_id"
        --target-state "$target_state"
        --command-name "$command_name"
        --steps "$steps_csv"
        --session-id "$session_id"
        --pid "$pid"
    )
    [[ -n "$worktree_path" ]] && args+=(--worktree "$worktree_path")
    [[ -n "$previous_state" ]] && args+=(--previous-state "$previous_state")

    _intents_py "${args[@]}" >/dev/null 2>&1
}

# intent_checkpoint — Mark a step as completed.
#
# Usage: intent_checkpoint <feature_id> <step_name>
intent_checkpoint() {
    local feature_id="${1:?intent_checkpoint: feature_id required}"
    local step_name="${2:?intent_checkpoint: step_name required}"

    _intents_py checkpoint-step "$feature_id" "$step_name" >/dev/null 2>&1
}

# intent_clear — Remove a completed intent (all steps done).
#
# Usage: intent_clear <feature_id>
intent_clear() {
    local feature_id="${1:?intent_clear: feature_id required}"

    _intents_py clear-intent "$feature_id" >/dev/null 2>&1
}

# intent_cancel — Abort an intent (marks as cancelled for reconciler).
#
# Usage: intent_cancel <feature_id>
intent_cancel() {
    local feature_id="${1:?intent_cancel: feature_id required}"

    _intents_py cancel-intent "$feature_id" >/dev/null 2>&1
}
