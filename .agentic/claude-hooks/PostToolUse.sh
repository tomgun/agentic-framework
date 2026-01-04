#!/usr/bin/env bash
# PostToolUse.sh: Run quick quality checks after code edits
#
# This hook runs after Claude uses any tool (file edits, terminal commands, etc.)
# It performs fast, non-blocking quality checks to catch issues early.
#
# Triggered by: Claude Desktop PostToolUse hook
# Timeout: 2 seconds

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_ROOT"

# Skip if not an agentic project
if [[ ! -d ".agentic" ]]; then
  exit 0
fi

# Only run checks after file writes (not after reads)
# Claude doesn't provide tool name in hook, so we check for recent file modifications
RECENT_CHANGES=$(find . -type f -mmin -1 -not -path "./.git/*" -not -path "./.agentic/.cache/*" 2>/dev/null | head -5)

if [[ -z "$RECENT_CHANGES" ]]; then
  # No recent changes, skip checks
  exit 0
fi

# Run fast linter checks only (no tests, those are slow)
# This is advisory only - doesn't block Claude, just provides feedback

HAS_ISSUES=false

# Check for common syntax errors (if applicable stack)
if [[ -f "package.json" ]] && command -v npx >/dev/null 2>&1; then
  # JavaScript/TypeScript project
  if npx eslint --quiet --max-warnings 0 . 2>/dev/null; then
    :  # No issues
  else
    HAS_ISSUES=true
  fi
elif [[ -f "Cargo.toml" ]] && command -v cargo >/dev/null 2>&1; then
  # Rust project
  if cargo check --quiet 2>/dev/null; then
    :  # No issues
  else
    HAS_ISSUES=true
  fi
elif command -v python3 >/dev/null 2>&1 && find . -name "*.py" -mmin -1 2>/dev/null | grep -q .; then
  # Python project with recent .py changes
  if command -v ruff >/dev/null 2>&1; then
    if ruff check --quiet . 2>/dev/null; then
      :  # No issues
    else
      HAS_ISSUES=true
    fi
  fi
fi

if [[ "$HAS_ISSUES" == "true" ]]; then
  echo ""
  echo "⚠️  Quick lint check found issues. Run your linter to see details."
  echo ""
fi

exit 0  # Always exit 0 (advisory only, don't block Claude)

