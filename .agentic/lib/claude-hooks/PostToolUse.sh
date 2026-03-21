#!/usr/bin/env bash
# PostToolUse.sh: Run quick quality checks after code edits
#
# This hook runs after Claude uses any tool (file edits, terminal commands, etc.)
# It performs fast, non-blocking quality checks to catch issues early.
# When v2 engine is active, also runs ag check --quick for artifact enforcement.
#
# Triggered by: Claude Code PostToolUse hook
# Timeout: 2 seconds

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_ROOT"
source "$PROJECT_ROOT/.agentic/lib/paths.sh" 2>/dev/null || true
source "$PROJECT_ROOT/.agentic/lib/tools/fwlog.sh" 2>/dev/null || true
flog "hook:post-tool-use" "fire" "" "start"

# Skip if not an agentic project
if [[ ! -d ".agentic" ]]; then
  exit 0
fi

# --- Advisory artifact check (hooks-first: uses gate.py) ---
# After tool use, check artifact status for active feature. Advisory only.
# PreToolUse already handles blocking for Write/Edit — this adds awareness
# for other tools (Bash, Read, Agent, etc.).
GATE_OUT=$(PYTHONPATH="$PROJECT_ROOT/.agentic/lib" python3 -c "
import sys; sys.path.insert(0, '$PROJECT_ROOT/.agentic/lib')
from gate import resolve_active_feature, check_feature_has_spec, check_feature_has_ac
from pathlib import Path
root = Path('$PROJECT_ROOT')
f = resolve_active_feature(root)
if f:
    s = check_feature_has_spec(f, root)
    a = check_feature_has_ac(f, root)
    issues = s.reasons + a.reasons
    if issues:
        print(f'📋 {f}: ' + '; '.join(issues))
" 2>/dev/null || true)

if [[ -n "$GATE_OUT" ]]; then
  echo "$GATE_OUT"
fi

# Only run linter checks after file writes (not after reads)
# PostToolUse receives JSON on stdin with tool_name, tool_input, tool_response
# This generic hook matches all tools (matcher: ".*"), so we infer from file modifications
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

# Auto-log checkpoint (every ~10 tool uses to avoid spam)
COUNTER_FILE=".agentic/.cache/tool_use_counter"
mkdir -p ".agentic/.cache" 2>/dev/null || true

if [[ -f "$COUNTER_FILE" ]]; then
  COUNT=$(cat "$COUNTER_FILE")
  COUNT=$((COUNT + 1))
else
  COUNT=1
fi

echo "$COUNT" > "$COUNTER_FILE"

# Log every 10th tool use as a checkpoint
if [[ $((COUNT % 10)) -eq 0 ]] && [[ -x ".agentic/lib/tools/session_log.sh" ]]; then
  bash .agentic/lib/tools/session_log.sh \
    "Checkpoint (${COUNT} actions)" \
    "Automatic checkpoint after ${COUNT} tool uses." \
    "checkpoint=auto,actions=${COUNT}" 2>/dev/null || true
fi

exit 0  # Always exit 0 (advisory only, don't block Claude)

