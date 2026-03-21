#!/usr/bin/env bash
# Thin wrapper — delegates to lib/claude-hooks/PreToolUse.sh
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"

exec bash "$PROJECT_ROOT/.agentic/lib/claude-hooks/PreToolUse.sh"
