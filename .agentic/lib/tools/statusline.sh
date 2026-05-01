#!/usr/bin/env bash
# statusline.sh — Claude Code status line shim.
#
# Reads the statusLine envelope on stdin, delegates to statusline.py.
# Stays exit 0 always — a broken statusline must never block the editor.
#
# Wired by `ag hooks register` / `ag hooks install` into .claude/settings.json
# under the "statusLine" key. See .agentic/lib/claude-hooks/statusline.json.

set -uo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
[[ ! -d "$PROJECT_ROOT/.agentic" ]] && exit 0

PYTHONPATH="$PROJECT_ROOT/.agentic/lib${PYTHONPATH:+:$PYTHONPATH}" \
    python3 "$PROJECT_ROOT/.agentic/lib/tools/statusline.py" || true

exit 0
