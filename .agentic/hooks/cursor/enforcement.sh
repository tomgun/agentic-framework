#!/usr/bin/env bash
# Cursor enforcement hook adapter
#
# Cursor hooks use the same gate checks as Claude but with different:
# - JSON schema (Cursor's hook format)
# - Tool names ("Shell" vs "Bash")
# - Blocking mechanism (exit 2 = deny for all hooks)
#
# This adapter parses Cursor-format JSON, normalizes tool names,
# calls ag gate, and formats the response for Cursor.
#
# Fail-closed: any error → exit 2 (deny)

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-.}"
cd "$PROJECT_ROOT"

# Read hook input from stdin
INPUT=""
if [[ ! -t 0 ]]; then
  INPUT=$(cat)
fi

# Determine hook event from environment or first argument
HOOK_EVENT="${CURSOR_HOOK_EVENT:-${1:-}}"

# Parse tool name and input using jq (required for Cursor — no manual JSON parsing)
if ! command -v jq >/dev/null 2>&1; then
  echo "jq required for Cursor hooks" >&2
  exit 2  # Fail-closed
fi

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // .tool // ""' 2>/dev/null || echo "")
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // .input // {}' 2>/dev/null || echo "{}")

case "$HOOK_EVENT" in
  PreToolUse|pre_tool_use)
    GATE_OUTPUT=$(PYTHONPATH="$PROJECT_ROOT/.agentic/lib" python3 -m gate pretool \
      --tool "${TOOL_NAME}" \
      --input "${TOOL_INPUT}" \
      --project-root "$PROJECT_ROOT" 2>&1) || {
      # Gate returned deny (exit 2) or error (exit 1)
      DECISION=$(echo "$GATE_OUTPUT" | jq -r '.decision // "deny"' 2>/dev/null || echo "deny")
      if [[ "$DECISION" == "deny" ]]; then
        REASONS=$(echo "$GATE_OUTPUT" | jq -r '.reasons // [] | join(". ")' 2>/dev/null || echo "Blocked by policy")
        echo "$REASONS" >&2
        exit 2
      fi
    }
    ;;

  Stop|stop)
    GATE_OUTPUT=$(PYTHONPATH="$PROJECT_ROOT/.agentic/lib" python3 -m gate stop \
      --project-root "$PROJECT_ROOT" 2>&1) || {
      DECISION=$(echo "$GATE_OUTPUT" | jq -r '.decision // "deny"' 2>/dev/null || echo "deny")
      if [[ "$DECISION" == "deny" ]]; then
        REASONS=$(echo "$GATE_OUTPUT" | jq -r '.reasons // [] | join(". ")' 2>/dev/null || echo "Verification not passed")
        echo "$REASONS" >&2
        exit 2
      fi
    }
    ;;

  *)
    # Unknown hook event — allow (don't block on unknown events)
    ;;
esac

# If we get here, allow
exit 0
