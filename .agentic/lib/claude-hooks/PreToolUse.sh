#!/usr/bin/env bash
# PreToolUse.sh: v2 artifact enforcement before code edits
#
# When the v2 engine is active, checks that the active feature has required
# artifacts (plan, spec) before allowing Write/Edit operations on non-framework
# files. Returns permissionDecision: "deny" to block, or exits silently to allow.
#
# Triggered by: Claude Code PreToolUse hook (matcher: Write|Edit|MultiEdit)
# Timeout: 1 second

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_ROOT"
source "$PROJECT_ROOT/.agentic/lib/tools/fwlog.sh" 2>/dev/null || true
flog "hook:pre-tool-use" "fire" "" "start"

# Skip if not an agentic project
if [[ ! -d ".agentic" ]]; then
  exit 0
fi

# Only enforce when v2 engine is active
_AF_CONFIG="$PROJECT_ROOT/.agentic/state_machine_af.yaml"
if [[ ! -f "$_AF_CONFIG" ]] || ! grep -q '^engine: v2' "$_AF_CONFIG" 2>/dev/null; then
  exit 0
fi

# Read tool input from stdin to check what file is being edited
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ti = d.get('tool_input', {})
print(ti.get('file_path', ''))
" 2>/dev/null || true)

# Allow edits to framework/config/state files (not user code)
# These are always safe: .agentic/*, tests/*, docs/*, *.md, *.json, *.yaml, *.yml, *.sh
# Both absolute (*/tests/*) and relative (tests/*) paths are matched.
case "$FILE_PATH" in
  .agentic/*|*/.agentic/*|tests/*|*/tests/*|test/*|*/test/*|docs/*|*/docs/*|*.md|*.json|*.yaml|*.yml|*.sh|*.toml|*.cfg|*.ini)
    exit 0
    ;;
esac

# Run ag check --quick --active — only care about failures
CHECK_OUT=$(PYTHONPATH="$PROJECT_ROOT/.agentic/lib" python3 -m auto.v2.workflow check --quick --active 2>/dev/null || true)

if [[ -n "$CHECK_OUT" ]]; then
  # Artifacts are missing — deny the edit with the reason
  CHECK_OUT_ESCAPED=$(echo "$CHECK_OUT" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))" 2>/dev/null || echo '""')
  python3 -c "
import json, sys
detail = json.loads($CHECK_OUT_ESCAPED)
reason = f'Artifact check failed — required artifacts are missing for the active feature.\n{detail}\nComplete required artifacts (plan, spec, acceptance criteria) before editing code.'
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': reason,
    }
}))
"
  exit 0
fi

# All clear — allow the edit (no output = allow)
exit 0
