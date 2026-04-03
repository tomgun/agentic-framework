#!/usr/bin/env bash
# btrace.sh — Behavioral trace emitter (debug mode)
#
# Append-only JSONL at $BTRACE_LOG. Zero-cost when disabled.
# Source this file, then call: btrace <hook> <phase> <json_data>
#
# Toggle: AGENTIC_BTRACE env var (priority) or STACK.md btrace setting
# Values: off (default) | on (behavioral events) | verbose (+ sub-check detail)
# Output: .agentic/debug/btrace-<session-id>.jsonl (persistent per-session)
#
# Consumers: ag debug show, ag debug decisions, ag debug bundle

# Guard against double-sourcing
[[ -n "${_AGENTIC_BTRACE_LOADED:-}" ]] && return 0
_AGENTIC_BTRACE_LOADED=1

_BTRACE_LEVEL="${AGENTIC_BTRACE:-__unresolved__}"
_BTRACE_SEQ=0
BTRACE_LOG=""

# Resolve level once (lazy — only when first btrace call happens)
_btrace_resolve() {
    if [[ "$_BTRACE_LEVEL" == "__unresolved__" ]]; then
        # Try settings.sh if available
        if type get_setting &>/dev/null; then
            _BTRACE_LEVEL=$(get_setting "btrace" "off" 2>/dev/null || echo "off")
        else
            local _settings_sh="${AGENTIC_LIB:-${PROJECT_ROOT:-.}/.agentic/lib}/settings.sh"
            if [[ -f "$_settings_sh" ]]; then
                source "$_settings_sh" 2>/dev/null || true
                _BTRACE_LEVEL=$(get_setting "btrace" "off" 2>/dev/null || echo "off")
            else
                _BTRACE_LEVEL="off"
            fi
        fi
    fi

    # Resolve log path if not set
    if [[ -z "$BTRACE_LOG" && "$_BTRACE_LEVEL" != "off" ]]; then
        local debug_dir="${PROJECT_ROOT:-.}/.agentic/debug"
        local sid_file="${PROJECT_ROOT:-.}/.agentic/session/.current-session-id"
        local sid="unknown"
        [[ -f "$sid_file" ]] && sid=$(cat "$sid_file" 2>/dev/null | tr -d '[:space:]') || true
        [[ -z "$sid" ]] && sid="unknown"
        mkdir -p "$debug_dir" 2>/dev/null || true
        BTRACE_LOG="$debug_dir/btrace-${sid}.jsonl"
        # Update latest symlink
        ln -sf "btrace-${sid}.jsonl" "$debug_dir/btrace-latest.jsonl" 2>/dev/null || true
    fi
}

btrace_enabled() {
    _btrace_resolve
    [[ "$_BTRACE_LEVEL" == "on" || "$_BTRACE_LEVEL" == "verbose" ]]
}

btrace_verbose() {
    _btrace_resolve
    [[ "$_BTRACE_LEVEL" == "verbose" ]]
}

# Emit a trace event: btrace <hook> <phase> <json_data>
# json_data must be valid JSON object (default: {})
btrace() {
    btrace_enabled || return 0
    local hook="${1:-}" phase="${2:-}" data="$3"
    [[ -z "$data" ]] && data='{}'
    local ts
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")"
    _BTRACE_SEQ=$(( _BTRACE_SEQ + 1 ))
    printf '{"ts":"%s","seq":%d,"hook":"%s","phase":"%s","data":%s}\n' \
        "$ts" "$_BTRACE_SEQ" "$hook" "$phase" "$data" \
        >> "$BTRACE_LOG" 2>/dev/null || true
}
