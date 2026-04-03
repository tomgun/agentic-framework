#!/usr/bin/env bash
# PreToolUse.sh: Enforcement hook — blocks dangerous ops and enforces spec-first
#
# This is an ENFORCEMENT hook. It calls `ag gate pretool` and returns:
#   exit 0 = allow (tool use permitted)
#   exit 2 = deny (tool use blocked via permissionDecision)
#
# Checks:
#   - Block destructive git operations (reset --hard, stash, checkout --, etc.)
#   - Block git commit/push without spec+AC (formal/autonomous_formal profiles)
#   - Block code edits without spec+AC (formal/autonomous_formal profiles)
#
# Triggered by: Claude Code PreToolUse hook
# Timeout: 3 seconds (increased from 2s to handle cold Python startup)

# Bootstrap: ensure lib/ is extracted (inline check avoids fork when lib exists)
[[ -d "${CLAUDE_PROJECT_DIR:-.}/.agentic/lib/tools" ]] || bash "${CLAUDE_PROJECT_DIR:-.}/.agentic/bootstrap.sh" 2>/dev/null || true

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_ROOT"
source "$PROJECT_ROOT/.agentic/lib/tools/fwlog.sh" 2>/dev/null || true
source "$PROJECT_ROOT/.agentic/lib/tools/btrace.sh" 2>/dev/null || true
flog "hook:pre-tool-use" "fire" "" "start" 2>/dev/null || true

# Skip if not an agentic project
if [[ ! -d ".agentic" ]]; then
  exit 0
fi

# Read tool input from stdin
INPUT=$(cat)

# Extract tool name from hook input
TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_name', ''))
except: print('')
" 2>/dev/null || true)

# Extract tool_input as JSON string for the gate
TOOL_INPUT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(json.dumps(d.get('tool_input', {})))
except: print('{}')
" 2>/dev/null || true)

# btrace: log tool input (truncated, no file contents)
_BT_INPUT_SUMMARY="${TOOL_INPUT:0:120}"
btrace "PreToolUse" "enter" "{\"tool\":\"${TOOL_NAME}\",\"input_summary\":$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$_BT_INPUT_SUMMARY" 2>/dev/null || echo '""')}" 2>/dev/null || true

# Call ag gate pretool
GATE_OUTPUT=""
GATE_RC=0
_BT_GATE_NS=$(date +%s%N 2>/dev/null || echo 0)
GATE_OUTPUT=$(PYTHONPATH="$PROJECT_ROOT/.agentic/lib" python3 -m gate pretool \
  --tool "${TOOL_NAME}" \
  --input "${TOOL_INPUT}" \
  --project-root "$PROJECT_ROOT" 2>&1) || GATE_RC=$?
_BT_GATE_END=$(date +%s%N 2>/dev/null || echo 0)
_BT_GATE_MS=$(( (_BT_GATE_END - _BT_GATE_NS) / 1000000 ))

# Helper: emit Claude deny JSON and exit
_deny() {
  local reason="$1"
  python3 -c "
import json, sys
reason = sys.argv[1]
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': reason,
    }
}))
" "$reason"
  exit 0  # Claude hooks: exit 0 with deny in JSON (exit 2 for Stop hook only)
}

# If gate says deny (exit 2), block
if [[ "$GATE_RC" -eq 2 ]]; then
  REASON="Blocked by ag gate pretool"
  if command -v jq >/dev/null 2>&1 && echo "$GATE_OUTPUT" | jq -e . >/dev/null 2>&1; then
    REASON=$(echo "$GATE_OUTPUT" | jq -r '.reasons // [] | join(". ")' 2>/dev/null || echo "$REASON")
  fi
  btrace "PreToolUse" "gate_result" "{\"decision\":\"deny\",\"exit_code\":$GATE_RC,\"duration_ms\":$_BT_GATE_MS,\"reason\":$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$REASON" 2>/dev/null || echo '""')}" 2>/dev/null || true
  _deny "$REASON"
fi

# Gate error (exit 1 / crash / import error) — fail-closed when blocking
# Without this, a Python crash silently ALLOWS the action (fail-open).
# See: NHL hockey game incident — gate.py error + fail-open = full bypass.
if [[ "$GATE_RC" -ne 0 ]]; then
  if grep -q 'state_enforcement:.*blocking' "$PROJECT_ROOT/.agentic/STACK.md" 2>/dev/null; then
    _deny "Gate error (exit $GATE_RC). state_enforcement=blocking requires fail-closed. Run: PYTHONPATH=.agentic/lib python3 -m gate pretool --tool ${TOOL_NAME} --input '{}' --project-root . to debug."
  fi
  # Non-blocking: warn but allow
  if [[ -n "$GATE_OUTPUT" ]]; then
    echo "$GATE_OUTPUT" >&2
  fi
fi

# --- Intelligence: Pattern check for Write/Edit ---
# Advisory only — warns on matching patterns, never blocks.
# Pure bash, no Python, targets <50ms.
if [[ "$TOOL_NAME" == "Write" || "$TOOL_NAME" == "Edit" || "$TOOL_NAME" == "MultiEdit" ]]; then
  _PTN_FILE="$PROJECT_ROOT/.agentic/intel/patterns.yaml"
  if [[ -f "$_PTN_FILE" ]]; then
    # Extract file_path from tool_input JSON using pure bash for speed.
    # Assumption: TOOL_INPUT comes from Claude Code's structured hook protocol,
    # so "file_path" always appears as a top-level JSON key (not inside content).
    _PTN_PATH=""
    case "$TOOL_INPUT" in
      *'"file_path"'*)
        _PTN_PATH="${TOOL_INPUT#*\"file_path\"}"
        _PTN_PATH="${_PTN_PATH#*:}"
        _PTN_PATH="${_PTN_PATH#*\"}"
        _PTN_PATH="${_PTN_PATH%%\"*}"
        ;;
    esac

    if [[ -n "$_PTN_PATH" ]]; then
      _PTN_FNAME="${_PTN_PATH##*/}"
      _PTN_REL="${_PTN_PATH#./}"; _PTN_REL="${_PTN_REL#/}"
      _PTN_WARNS=""

      # Inline glob matcher (same logic as _intel_glob_match in intel.sh)
      _ptn_match() {
        local _p="$1"
        # shellcheck disable=SC2254
        case "$_PTN_PATH"  in $_p) return 0 ;; esac
        # shellcheck disable=SC2254
        case "$_PTN_FNAME" in $_p) return 0 ;; esac
        # shellcheck disable=SC2254
        case "$_PTN_REL"   in $_p) return 0 ;; esac
        # shellcheck disable=SC2254
        case "./$_PTN_REL" in $_p) return 0 ;; esac
        return 1
      }

      # Single-pass parser with flush function — no duplicated "last entry" block
      _p_id="" _p_text="" _p_scope="" _p_sev=""
      _ptn_flush() {
        if [[ -n "$_p_id" && -n "$_p_scope" ]] && _ptn_match "$_p_scope"; then
          local _icon="⚠️"
          case "$_p_sev" in error) _icon="🚨" ;; info) _icon="ℹ️" ;; esac
          _PTN_WARNS="${_PTN_WARNS}${_icon} ${_p_id}: ${_p_text}\n"
        fi
      }

      while IFS= read -r _line; do
        case "$_line" in
          *"- id: "*)    _ptn_flush; _p_id="${_line#*"- id: "}"; _p_id="${_p_id//\"/}"; _p_id="${_p_id## }"; _p_text="" _p_scope="" _p_sev="" ;;
          *"text: "*)    _p_text="${_line#*"text: "}"; _p_text="${_p_text//\"/}" ;;
          *"scope: "*)   _p_scope="${_line#*"scope: "}"; _p_scope="${_p_scope//\"/}" ;;
          *"severity: "*) _p_sev="${_line#*"severity: "}"; _p_sev="${_p_sev//\"/}" ;;
        esac
      done < "$_PTN_FILE"
      _ptn_flush  # last entry

      # btrace: log pattern matches
      if [[ -n "$_PTN_WARNS" ]]; then
        _bt_ptn_count=$(echo -e "$_PTN_WARNS" | grep -c "P-" 2>/dev/null || true)
        _bt_ptn_count="${_bt_ptn_count## }"; _bt_ptn_count="${_bt_ptn_count%%[!0-9]*}"; _bt_ptn_count="${_bt_ptn_count:-0}"
        btrace "PreToolUse" "pattern_match" "{\"file\":$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$_PTN_FNAME" 2>/dev/null || echo '""'),\"matches\":${_bt_ptn_count:-0}}" 2>/dev/null || true
      fi

      # Output warnings to stderr (visible to agent, doesn't break JSON stdout)
      if [[ -n "$_PTN_WARNS" ]]; then
        echo -e "📋 Pattern warnings for ${_PTN_FNAME}:" >&2
        echo -e "$_PTN_WARNS" >&2
        # Change 6c: One-time correction persistence hint
        if [[ ! -f "$PROJECT_ROOT/.agentic/session/.correction_hint_shown" ]]; then
          echo -e "   💡 If this edit is a deliberate override: \`ag intel remember \"reason\" --context \"editing ${_PTN_FNAME}\"\`" >&2
          touch "$PROJECT_ROOT/.agentic/session/.correction_hint_shown" 2>/dev/null || true
        fi
        # Log enforcement event to intel-events.log
        _warn_count=$(echo -e "$_PTN_WARNS" | grep -c "P-" 2>/dev/null || echo 0)
        _warn_count="${_warn_count## }"; _warn_count="${_warn_count%% }"; _warn_count="${_warn_count%%[!0-9]*}"
        _warn_count="${_warn_count:-0}"
        _il_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")"
        mkdir -p "$PROJECT_ROOT/.agentic/session" 2>/dev/null || true
        printf '%s|%s|%s|%s\n' "$_il_ts" "enforce" "pattern:${_PTN_FNAME}" "$_warn_count" \
            >> "$PROJECT_ROOT/.agentic/session/intel-events.log" 2>/dev/null || true
      fi
    fi
  fi
fi

# btrace: log allow
btrace "PreToolUse" "gate_result" "{\"decision\":\"allow\",\"exit_code\":$GATE_RC,\"duration_ms\":${_BT_GATE_MS:-0}}" 2>/dev/null || true

# Allow — no output needed
exit 0
