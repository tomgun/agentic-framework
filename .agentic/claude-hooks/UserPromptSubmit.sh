#!/usr/bin/env bash
# UserPromptSubmit.sh: Auto-inject .continue-here.md if available
#
# This hook runs before Claude processes each user prompt.
# It automatically adds .continue-here.md to context if the file exists
# and hasn't been injected yet in this session.
#
# Triggered by: Claude Desktop UserPromptSubmit hook
# Timeout: 3 seconds

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_ROOT"

# Track if we've already injected in this session
SESSION_MARKER="/tmp/.agentic-claude-session-$$"

# Only inject once per session
if [[ -f "$SESSION_MARKER" ]]; then
  exit 0
fi

# Check if .continue-here.md exists
if [[ ! -f ".continue-here.md" ]]; then
  exit 0
fi

# Check file age (don't inject if > 7 days old)
if command -v stat >/dev/null 2>&1; then
  if [[ "$(uname)" == "Darwin" ]]; then
    FILE_AGE_SECONDS=$(( $(date +%s) - $(stat -f %m .continue-here.md) ))
  else
    FILE_AGE_SECONDS=$(( $(date +%s) - $(stat -c %Y .continue-here.md) ))
  fi
  
  SEVEN_DAYS=$((7 * 24 * 60 * 60))
  if [[ $FILE_AGE_SECONDS -gt $SEVEN_DAYS ]]; then
    echo "Note: .continue-here.md is stale (>7 days old). Generate fresh: python3 .agentic/tools/continue_here.py"
    exit 0
  fi
fi

# Inject the file content as a system message (Claude will see it before the user prompt)
echo ""
echo "📄 Auto-injecting session context from .continue-here.md:"
echo ""
cat .continue-here.md
echo ""
echo "---"
echo ""

# Mark as injected for this session
touch "$SESSION_MARKER"

exit 0

