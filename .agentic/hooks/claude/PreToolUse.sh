#!/usr/bin/env bash
# Thin wrapper — delegates to lib/claude-hooks/PreToolUse.sh
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
bash "$PROJECT_ROOT/.agentic/bootstrap.sh" 2>/dev/null || exit 0
exec bash "$PROJECT_ROOT/.agentic/lib/claude-hooks/PreToolUse.sh"
