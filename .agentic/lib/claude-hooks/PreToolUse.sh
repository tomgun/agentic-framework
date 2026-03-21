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

# Skip if not an agentic project
if [[ ! -d "$PROJECT_ROOT/.agentic" ]]; then
  exit 0
fi

# Only enforce when v2 engine is active
_AF_CONFIG="$PROJECT_ROOT/.agentic/state_machine_af.yaml"
if [[ ! -f "$_AF_CONFIG" ]] || ! grep -q '^engine: v2' "$_AF_CONFIG" 2>/dev/null; then
  exit 0
fi

# Read tool input from stdin to check what file is being edited
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || true)
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ti = d.get('tool_input', {})
# Write has file_path, Edit has file_path
print(ti.get('file_path', ''))
" 2>/dev/null || true)

# Allow edits to framework/config/state files (not user code)
# These are always safe: .agentic/*, tests/*, docs/*, *.md, *.json, *.yaml, *.yml, *.sh
case "$FILE_PATH" in
  */.agentic/*|*/tests/*|*/docs/*|*.md|*.json|*.yaml|*.yml|*.sh|*.toml|*.cfg|*.ini)
    exit 0
    ;;
esac

# Run ag check --quick --active — only care about failures
CHECK_OUT=$(PYTHONPATH="$PROJECT_ROOT/.agentic/lib" python3 -m auto.v2.workflow check --quick --active 2>/dev/null || true)

if [[ -n "$CHECK_OUT" ]]; then
  # Artifacts are missing — deny the edit with the reason
  python3 -c "
import json, sys
reason = '''Artifact check failed — required artifacts are missing for the active feature.
$CHECK_OUT
Complete required artifacts (plan, spec, acceptance criteria) before editing code.'''
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
