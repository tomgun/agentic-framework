"""
mcp_server.py — Minimal MCP server over stdio (JSON-RPC 2.0).

Implements the Model Context Protocol (MCP) specification for providing
agentic framework tools to AI coding assistants. Uses stdio transport
with zero external dependencies (Python stdlib only).

Protocol:
    stdin  → JSON-RPC 2.0 messages (one per line)
    stdout ← JSON-RPC 2.0 responses (one per line)

MCP handshake:
    1. Client sends "initialize" with capabilities
    2. Server responds with serverInfo + capabilities
    3. Client sends "initialized" notification
    4. Normal tool calls via "tools/list" and "tools/call"

Usage:
    python3 -m auto.v2.mcp_server
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from .mcp_tools import MCP_TOOLS, get_tool_definitions

# MCP protocol version
PROTOCOL_VERSION = "2024-11-05"

# JSON-RPC 2.0 error codes
PARSE_ERROR = -32700
INVALID_REQUEST = -32600
METHOD_NOT_FOUND = -32601
INVALID_PARAMS = -32602
INTERNAL_ERROR = -32603


# ---------------------------------------------------------------------------
# JSON-RPC helpers
# ---------------------------------------------------------------------------


def _jsonrpc_success(req_id, result: dict) -> dict:
    return {"jsonrpc": "2.0", "result": result, "id": req_id}


def _jsonrpc_error(req_id, code: int, message: str) -> dict:
    return {"jsonrpc": "2.0", "error": {"code": code, "message": message}, "id": req_id}


# ---------------------------------------------------------------------------
# MCP Server
# ---------------------------------------------------------------------------


class MCPServer:
    """Minimal MCP server over stdio."""

    def __init__(self, project_root: Path):
        self.project_root = project_root
        self.initialized = False

    def handle_message(self, msg: dict) -> dict | None:
        """Route a JSON-RPC message to the appropriate handler.

        Returns a response dict, or None for notifications (no id).
        """
        req_id = msg.get("id")
        method = msg.get("method", "")
        params = msg.get("params", {})

        # Notifications (no id) — don't respond
        if req_id is None:
            if method == "notifications/initialized":
                self.initialized = True
            return None

        if method == "initialize":
            return self._handle_initialize(req_id, params)
        elif method == "tools/list":
            return self._handle_tools_list(req_id)
        elif method == "tools/call":
            return self._handle_tools_call(req_id, params)
        else:
            return _jsonrpc_error(req_id, METHOD_NOT_FOUND, f"Unknown method: {method}")

    def _handle_initialize(self, req_id, params: dict) -> dict:
        """Handle the MCP initialize handshake."""
        return _jsonrpc_success(req_id, {
            "protocolVersion": PROTOCOL_VERSION,
            "capabilities": {
                "tools": {},
            },
            "serverInfo": {
                "name": "agentic-framework",
                "version": "1.0.0",
            },
        })

    def _handle_tools_list(self, req_id) -> dict:
        """Return available tool definitions."""
        return _jsonrpc_success(req_id, {
            "tools": get_tool_definitions(),
        })

    def _handle_tools_call(self, req_id, params: dict) -> dict:
        """Execute a tool call."""
        tool_name = params.get("name", "")
        arguments = params.get("arguments", {})

        tool = MCP_TOOLS.get(tool_name)
        if not tool:
            return _jsonrpc_error(
                req_id, METHOD_NOT_FOUND,
                f"Unknown tool: {tool_name}",
            )

        try:
            handler = tool["handler"]
            result = handler(self.project_root, arguments)
            # MCP tools/call returns content array
            return _jsonrpc_success(req_id, {
                "content": [
                    {
                        "type": "text",
                        "text": json.dumps(result, indent=2),
                    }
                ],
            })
        except Exception as e:
            return _jsonrpc_error(req_id, INTERNAL_ERROR, str(e))

    def run_stdio(self):
        """Run the server on stdin/stdout.

        Reads one JSON-RPC message per line from stdin,
        writes responses to stdout.
        """
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue

            try:
                msg = json.loads(line)
            except json.JSONDecodeError:
                resp = _jsonrpc_error(None, PARSE_ERROR, "Invalid JSON")
                sys.stdout.write(json.dumps(resp) + "\n")
                sys.stdout.flush()
                continue

            # Validate basic JSON-RPC structure
            if not isinstance(msg, dict) or msg.get("jsonrpc") != "2.0":
                resp = _jsonrpc_error(
                    msg.get("id"), INVALID_REQUEST,
                    "Not a valid JSON-RPC 2.0 message",
                )
                sys.stdout.write(json.dumps(resp) + "\n")
                sys.stdout.flush()
                continue

            response = self.handle_message(msg)
            if response is not None:
                sys.stdout.write(json.dumps(response) + "\n")
                sys.stdout.flush()


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def _resolve_project_root() -> Path:
    """Walk up from cwd to find .agentic/ directory."""
    current = Path.cwd()
    while current != current.parent:
        if (current / ".agentic").is_dir():
            return current
        current = current.parent
    return Path.cwd()  # fallback


def main():
    project_root = _resolve_project_root()
    server = MCPServer(project_root)
    server.run_stdio()


if __name__ == "__main__":
    main()
