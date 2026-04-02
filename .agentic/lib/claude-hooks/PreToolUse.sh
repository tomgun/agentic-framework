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

# Call ag gate pretool
GATE_OUTPUT=""
GATE_RC=0
GATE_OUTPUT=$(PYTHONPATH="$PROJECT_ROOT/.agentic/lib" python3 -m gate pretool \
  --tool "${TOOL_NAME}" \
  --input "${TOOL_INPUT}" \
  --project-root "$PROJECT_ROOT" 2>&1) || GATE_RC=$?

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
  PATTERNS_FILE="$PROJECT_ROOT/.agentic/intel/patterns.yaml"
  if [[ -f "$PATTERNS_FILE" ]]; then
    # Extract file path from tool input (pure bash — avoid Python for speed)
    FILE_PATH=""
    case "$TOOL_INPUT" in
      *'"file_path"'*)
        # Extract value after "file_path": "..."
        FILE_PATH="${TOOL_INPUT#*\"file_path\"}"
        FILE_PATH="${FILE_PATH#*:}"
        FILE_PATH="${FILE_PATH#*\"}"
        FILE_PATH="${FILE_PATH%%\"*}"
        ;;
    esac

    if [[ -n "$FILE_PATH" ]]; then
      # Get just the filename for simple glob matching
      _FILENAME="${FILE_PATH##*/}"
      # Normalize: strip leading ./ or /
      _REL="${FILE_PATH#./}"
      _REL="${_REL#/}"

      _PATTERN_WARNINGS=""
      _p_id="" _p_text="" _p_scope="" _p_severity=""

      while IFS= read -r _line; do
        case "$_line" in
          *"- id: "*)
            # Check previous entry if exists
            if [[ -n "$_p_id" && -n "$_p_scope" ]]; then
              _matched=false
              # shellcheck disable=SC2254
              case "$FILE_PATH" in $_p_scope) _matched=true ;; esac
              if ! $_matched; then
                # shellcheck disable=SC2254
                case "$_FILENAME" in $_p_scope) _matched=true ;; esac
              fi
              if ! $_matched; then
                # shellcheck disable=SC2254
                case "$_REL" in $_p_scope) _matched=true ;; esac
              fi
              if $_matched; then
                local_icon="⚠️"
                case "$_p_severity" in error) local_icon="🚨" ;; info) local_icon="ℹ️" ;; esac
                _PATTERN_WARNINGS="${_PATTERN_WARNINGS}${local_icon} ${_p_id}: ${_p_text}\n"
              fi
            fi
            _p_id="${_line#*"- id: "}"
            _p_id="${_p_id//\"/}"
            _p_id="${_p_id## }"
            _p_text="" _p_scope="" _p_severity=""
            ;;
          *"text: "*)
            _p_text="${_line#*"text: "}"
            _p_text="${_p_text//\"/}"
            ;;
          *"scope: "*)
            _p_scope="${_line#*"scope: "}"
            _p_scope="${_p_scope//\"/}"
            ;;
          *"severity: "*)
            _p_severity="${_line#*"severity: "}"
            _p_severity="${_p_severity//\"/}"
            ;;
        esac
      done < "$PATTERNS_FILE"

      # Check last entry
      if [[ -n "$_p_id" && -n "$_p_scope" ]]; then
        _matched=false
        # shellcheck disable=SC2254
        case "$FILE_PATH" in $_p_scope) _matched=true ;; esac
        if ! $_matched; then
          # shellcheck disable=SC2254
          case "$_FILENAME" in $_p_scope) _matched=true ;; esac
        fi
        if ! $_matched; then
          # shellcheck disable=SC2254
          case "$_REL" in $_p_scope) _matched=true ;; esac
        fi
        if $_matched; then
          local_icon="⚠️"
          case "$_p_severity" in error) local_icon="🚨" ;; info) local_icon="ℹ️" ;; esac
          _PATTERN_WARNINGS="${_PATTERN_WARNINGS}${local_icon} ${_p_id}: ${_p_text}\n"
        fi
      fi

      # Output warnings to stderr (visible to agent, doesn't break JSON stdout)
      if [[ -n "$_PATTERN_WARNINGS" ]]; then
        echo -e "📋 Pattern warnings for ${FILE_PATH##*/}:" >&2
        echo -e "$_PATTERN_WARNINGS" >&2
      fi
    fi
  fi
fi

# Allow — no output needed
exit 0
