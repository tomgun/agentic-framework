#!/usr/bin/env bash
# Thin wrapper — delegates to lib/hooks/shared/on-code-edit.sh
# Passes stdin through (contains tool_name, tool_input, tool_response JSON)
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
bash "$PROJECT_ROOT/.agentic/bootstrap.sh" 2>/dev/null || exit 0
exec bash "$PROJECT_ROOT/.agentic/lib/hooks/shared/on-code-edit.sh"
