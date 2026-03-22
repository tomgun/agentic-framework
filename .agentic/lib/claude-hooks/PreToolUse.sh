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

# Allow — no output needed
exit 0
