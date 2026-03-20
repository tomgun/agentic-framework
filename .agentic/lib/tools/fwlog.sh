#!/usr/bin/env bash
# fwlog.sh — Framework execution logger (F-0240)
#
# Append-only, fail-open structured log at $FRAMEWORK_LOG.
# Source this file, then call: flog <script> <verb> <args> <result>
#
# Format: TIMESTAMP|SCRIPT|VERB|ARGS|RESULT  (pipe-delimited, no padding)
# Consumers: F-0242 PhaseChecker, `cat .agentic/session/framework.log`

# Guard against double-sourcing
[[ -n "${_AGENTIC_FWLOG_LOADED:-}" ]] && return 0
_AGENTIC_FWLOG_LOADED=1

# Ensure FRAMEWORK_LOG is set (paths.sh should define it, but be safe)
: "${FRAMEWORK_LOG:=${SESSION_DIR:-/dev/null}/framework.log}"

flog() {
    local script="${1:-}" verb="${2:-}" args="${3:-}" result="${4:-}"
    local ts
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")"
    mkdir -p "$(dirname "$FRAMEWORK_LOG")" 2>/dev/null || true
    printf '%s|%s|%s|%s|%s\n' "$ts" "$script" "$verb" "$args" "$result" \
        >> "$FRAMEWORK_LOG" 2>/dev/null || true
}
