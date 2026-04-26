#!/usr/bin/env bash
# commands/tui.sh — Launch the mission-control TUI (R-008).
# Sourced by ag.sh. Depends on: ROOT_DIR, color codes, get_setting().

cmd_tui() {
    local journal_dir="$ROOT_DIR/.agentic/journal"
    local feature="${1:-—}"
    local profile
    profile=$(get_setting "profile" "discovery")
    local mode="${AG_MODE:-—}"
    local quota_tokens
    quota_tokens=$(get_setting "quota_pro_max_window_tokens" "")
    local from_start="${AG_TUI_FROM_START:-0}"

    local from_start_arg=""
    if [[ "$from_start" == "1" ]]; then
        from_start_arg="--from-start"
    fi

    local quota_arg=""
    if [[ -n "$quota_tokens" ]]; then
        quota_arg="--quota-window $quota_tokens"
    fi

    PYTHONPATH="$ROOT_DIR/.agentic/lib${PYTHONPATH:+:$PYTHONPATH}" \
        python3 -m tui \
        --journal-dir "$journal_dir" \
        --feature "$feature" \
        --profile "$profile" \
        --mode "$mode" \
        $quota_arg $from_start_arg
}
