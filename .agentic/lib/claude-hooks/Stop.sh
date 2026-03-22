#!/usr/bin/env bash
# Stop.sh: Enforcement hook — blocks session stop until verification passes
#
# This is an ENFORCEMENT hook. It calls `ag gate stop` and returns:
#   exit 0 = allow (session can end)
#   exit 2 = deny (session must not end — verification failed)
#
# Triggered by: Claude Code Stop hook
# Timeout: 5 seconds

# Bootstrap: ensure lib/ is extracted (inline check avoids fork when lib exists)
[[ -d "${CLAUDE_PROJECT_DIR:-.}/.agentic/lib/tools" ]] || bash "${CLAUDE_PROJECT_DIR:-.}/.agentic/bootstrap.sh" 2>/dev/null || true

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_ROOT"
source "$PROJECT_ROOT/.agentic/lib/paths.sh" 2>/dev/null || true
source "$PROJECT_ROOT/.agentic/lib/tools/fwlog.sh" 2>/dev/null || true
flog "hook:stop" "fire" "" "start" 2>/dev/null || true

# Skip if not an agentic project
if [[ ! -d ".agentic" ]]; then
  exit 0
fi

# --- Enforcement: call ag gate stop ---
GATE_OUTPUT=""
GATE_RC=0
GATE_OUTPUT=$(PYTHONPATH="$PROJECT_ROOT/.agentic/lib" python3 -m gate stop --project-root "$PROJECT_ROOT" 2>&1) || GATE_RC=$?

# Parse JSON response
DECISION="allow"
if command -v jq >/dev/null 2>&1 && echo "$GATE_OUTPUT" | jq -e . >/dev/null 2>&1; then
  DECISION=$(echo "$GATE_OUTPUT" | jq -r '.decision // "allow"')
  REASONS=$(echo "$GATE_OUTPUT" | jq -r '.reasons // [] | join("; ")' 2>/dev/null || echo "")
  WARNINGS=$(echo "$GATE_OUTPUT" | jq -r '.warnings // [] | join("; ")' 2>/dev/null || echo "")
else
  # jq not available or invalid JSON — parse manually
  if echo "$GATE_OUTPUT" | grep -q '"decision".*"deny"'; then
    DECISION="deny"
  fi
  REASONS=$(echo "$GATE_OUTPUT" | grep -o '"reasons":\s*\[.*\]' | head -1 || echo "")
  WARNINGS=""
fi

# --- Deregister session (F-0195: multi-session collision prevention) ---
AGENTIC_LIB="$PROJECT_ROOT/.agentic/lib"
if [[ -f "$AGENTIC_LIB/tools/agents_helpers.py" ]]; then
  python3 "$AGENTIC_LIB/tools/agents_helpers.py" \
    --project-root "$PROJECT_ROOT" session-deregister "$PROJECT_ROOT" --pid "$PPID" 2>/dev/null || true
fi

# --- Output and exit ---
if [[ "$DECISION" == "deny" ]]; then
  echo ""
  echo "🚫 Session stop BLOCKED — verification not passed"
  echo ""
  if [[ -n "$REASONS" ]]; then
    echo "Reasons:"
    echo "  $REASONS"
  fi
  echo ""
  echo "Fix the issues above, then try stopping again."
  echo "Or run: ag verify <feature-id>"
  echo ""
  exit 2
fi

# Allowed — show advisory warnings if any
if [[ -n "${WARNINGS:-}" && "$WARNINGS" != "" ]]; then
  echo ""
  echo "👋 Session ending — advisory reminders:"
  echo "  $WARNINGS"
  echo ""
fi

echo ""
echo "✓ All checks passed. Session ending."
echo ""
exit 0
