#!/usr/bin/env bash
# mcp_start.sh — Shell entry point for MCP coordination server.
#
# MCP clients (Cursor, Windsurf, VS Code) configure this as their server command:
#   {"command": "bash", "args": [".agentic/lib/auto/mcp_start.sh"]}
#
# Resolves project root, finds Python, launches the MCP stdio server.

set -euo pipefail

# Resolve project root by walking up for .agentic/
find_project_root() {
    local dir
    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.agentic" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    pwd
}

PROJECT_ROOT="$(find_project_root)"

# Find Python
PYTHON=""
if command -v python3 &>/dev/null; then
    PYTHON="python3"
elif command -v python &>/dev/null; then
    PYTHON="python"
else
    echo '{"jsonrpc":"2.0","error":{"code":-32603,"message":"Python not found. Install Python 3 to use the MCP coordination server."},"id":null}' >&1
    exit 1
fi

export PYTHONPATH="$PROJECT_ROOT/.agentic/lib${PYTHONPATH:+:$PYTHONPATH}"
export AG_PROJECT_ROOT="$PROJECT_ROOT"

exec "$PYTHON" "$PROJECT_ROOT/.agentic/lib/auto/mcp_server.py"
