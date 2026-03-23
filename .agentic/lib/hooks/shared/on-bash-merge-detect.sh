#!/usr/bin/env bash
# on-bash-merge-detect.sh — Detect raw `gh pr merge` bypassing `ag merge`
#
# Called by tool-specific wrappers after Bash tool use.
# Fast exit: if tool input doesn't contain "gh pr merge", exit immediately.
# If detected, warn to use `ag merge` instead (chains ag done automatically).
#
# Exit code: always 0 (advisory — never blocks the agent)
#
# Stdin: JSON with tool_name + tool_input (from Claude Code PostToolUse hook)

# Bootstrap: ensure lib/ is extracted (inline check avoids fork when lib exists)
[[ -d "${CLAUDE_PROJECT_DIR:-.}/.agentic/lib/tools" ]] || bash "${CLAUDE_PROJECT_DIR:-.}/.agentic/bootstrap.sh" 2>/dev/null || true

set -uo pipefail

# Read stdin once — fast exit if empty or no merge command
STDIN_DATA=""
if [[ ! -t 0 ]]; then
  STDIN_DATA=$(cat)
fi

# Fast path: no stdin or no gh pr merge → exit immediately
[[ -n "$STDIN_DATA" ]] || exit 0
echo "$STDIN_DATA" | grep -q 'gh pr merge\|gh merge' || exit 0

# Extract the command from tool_input for the warning
COMMAND=""
if command -v jq >/dev/null 2>&1; then
  COMMAND=$(echo "$STDIN_DATA" | jq -r '.tool_input.command // empty' 2>/dev/null)
else
  COMMAND=$(echo "$STDIN_DATA" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi

# Confirm it's actually gh pr merge (not just mentioned in output/comments)
if [[ -n "$COMMAND" ]] && echo "$COMMAND" | grep -qE 'gh\s+pr\s+merge'; then
  echo ""
  echo "⚠️  MERGE DETECTED WITHOUT ag merge"
  echo "   ag merge chains ag done automatically: dogfood, VERSION, backlog, flush."
  echo ""
  echo "REQUIRED NEXT ACTION:"
  echo "   Run: ag done F-XXXX"
  echo "   (Marks feature shipped, bumps VERSION, syncs instruction files, updates backlog)"
  echo ""
  echo "   If you don't know the feature ID, run: ag status"
  echo ""
fi

exit 0
