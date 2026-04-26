#!/usr/bin/env bash
# commands/push.sh — Sanctioned `git push` wrapper (R-002).
# Sourced by ag.sh — do NOT execute directly.
# Depends on: ROOT_DIR, RED/YELLOW/NC color codes.

# Mirrors `ag commit --skip-gate` (R-001): when --skip-gate is the first arg,
# set AGENT_SKIP_GATE so prepush_gate.py records a `gate_skipped` event and
# returns 0; then forward remaining args to `git push`. The breadcrumb file
# at .agentic/session/.push-invoked-via-ag tells the gate this was sanctioned
# (used in AC6 of the gate to distinguish from raw `git push`).

cmd_push() {
    local skip_reason=""
    if [[ "${1:-}" == "--skip-gate" ]]; then
        skip_reason="${2:-}"
        if [[ -z "$skip_reason" ]]; then
            echo -e "${RED}ag push --skip-gate requires a reason.${NC}"
            echo "  Usage: ag push --skip-gate \"<reason>\" [git-push-args...]"
            return 1
        fi
        shift 2
        export AGENT_SKIP_GATE=1
        export AGENT_SKIP_GATE_REASON="$skip_reason"
    fi

    # Drop the breadcrumb so prepush_gate.py knows this was via `ag push`.
    mkdir -p "$ROOT_DIR/.agentic/session"
    if [[ -n "$skip_reason" ]]; then
        printf '%s\n' "$skip_reason" > "$ROOT_DIR/.agentic/session/.push-invoked-via-ag"
    else
        printf 'invoked-via-ag\n' > "$ROOT_DIR/.agentic/session/.push-invoked-via-ag"
    fi

    exec git push "$@"
}
