"""
mcp_server.py — MCP stdio transport for coordination tools (F-018 AC-002).

Implements the Model Context Protocol (MCP) over stdio (JSON-RPC 2.0),
exposing the same 8 coordination tool handlers that coord_server.py
serves over HTTP. Zero external dependencies (Python stdlib only).

Architecture:
    coord_tools.py (8 handlers, shared)
        ├── coord_server.py  (HTTP JSON-RPC, port 4185, bearer auth)
        └── mcp_server.py    (MCP stdio, this file)

Protocol:
    stdin  → JSON-RPC 2.0 messages (one per line)
    stdout ← JSON-RPC 2.0 responses (one per line)
    stderr ← diagnostics / captured handler output

MCP handshake:
    1. Client sends "initialize" with capabilities
    2. Server responds with serverInfo + capabilities
    3. Client sends "notifications/initialized"
    4. Normal tool calls via "tools/list" and "tools/call"

Note: This server is intentionally single-threaded. coord_tools handlers
are NOT thread-safe (they do file I/O on AGENTS.json, FEATURES.md, etc.).
MCP stdio processes one message at a time — no concurrency.

Usage:
    python3 .agentic/lib/auto/mcp_server.py
    # Or via shell wrapper:
    bash .agentic/lib/auto/mcp_start.sh
"""
from __future__ import annotations

import io
import json
import os
import signal
import subprocess
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# MCP protocol constants
# ---------------------------------------------------------------------------
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
# Stdout/stderr capture for tool handlers
# ---------------------------------------------------------------------------

def _capture_output(fn, *args, **kwargs):
    """Run a function while capturing stdout/stderr.

    coord_tools handlers import CLI modules (agents_helpers, state_machine,
    review) that may print() to stdout. Any stdout output would corrupt the
    MCP JSON-RPC stream. This captures it and routes to stderr for diagnostics.

    Safe for single-threaded MCP stdio transport. Not suitable for concurrent use.
    """
    old_stdout = sys.stdout
    old_stderr = sys.stderr
    sys.stdout = stdout_buf = io.StringIO()
    sys.stderr = stderr_buf = io.StringIO()
    try:
        result = fn(*args, **kwargs)
    except SystemExit as e:
        result = {"error": f"SystemExit: {e.code}"}
    finally:
        sys.stdout = old_stdout
        sys.stderr = old_stderr

    # Route captured output to stderr for diagnostics
    captured = stdout_buf.getvalue() + stderr_buf.getvalue()
    if captured.strip():
        _log(f"[captured handler output] {captured.strip()}")

    return result


# ---------------------------------------------------------------------------
# Logging (stderr only — stdout is reserved for JSON-RPC)
# ---------------------------------------------------------------------------

def _log(msg: str):
    """Write diagnostic message to stderr."""
    print(f"[mcp] {msg}", file=sys.stderr, flush=True)


# ---------------------------------------------------------------------------
# MCP Server
# ---------------------------------------------------------------------------

class MCPServer:
    """MCP coordination server over stdio."""

    def __init__(self, project_root: Path):
        self.project_root = project_root

    def handle_message(self, msg: dict) -> dict | None:
        """Route a JSON-RPC message to the appropriate handler.

        Returns a response dict, or None for notifications (no id).
        """
        req_id = msg.get("id")
        method = msg.get("method", "")
        params = msg.get("params", {})

        # Notifications (no id) — don't respond
        if req_id is None:
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
                "name": "agentic-coord",
                "version": "1.0.0",
            },
        })

    def _handle_tools_list(self, req_id) -> dict:
        """Return available tool definitions."""
        from auto.mcp_tool_defs import get_tool_definitions
        return _jsonrpc_success(req_id, {
            "tools": get_tool_definitions(),
        })

    def _handle_tools_call(self, req_id, params: dict) -> dict:
        """Execute a tool call via coord_tools handlers."""
        from auto.coord_tools import TOOLS

        tool_name = params.get("name", "")
        arguments = params.get("arguments", {})

        if tool_name not in TOOLS:
            return _jsonrpc_error(
                req_id, METHOD_NOT_FOUND,
                f"Unknown tool: {tool_name}",
            )

        _log(f"tools/call: {tool_name}")

        try:
            handler = TOOLS[tool_name]
            result = _capture_output(handler, self.project_root, arguments)

            # Per MCP spec: tool results return content array.
            # Tool-level errors use isError in content, NOT JSON-RPC errors.
            is_error = isinstance(result, dict) and "error" in result
            return _jsonrpc_success(req_id, {
                "content": [
                    {
                        "type": "text",
                        "text": json.dumps(result, indent=2),
                    }
                ],
                **({"isError": True} if is_error else {}),
            })
        except Exception as e:
            _log(f"tools/call error: {tool_name}: {e}")
            # Tool execution exception → MCP isError content, not JSON-RPC error
            return _jsonrpc_success(req_id, {
                "content": [
                    {
                        "type": "text",
                        "text": json.dumps({"error": str(e)}),
                    }
                ],
                "isError": True,
            })

    def run_stdio(self):
        """Run the server on stdin/stdout.

        Reads one JSON-RPC message per line from stdin,
        writes responses to stdout.
        """
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue

            # Reject oversized messages (1MB limit)
            if len(line) > 1_048_576:
                resp = _jsonrpc_error(None, PARSE_ERROR, "Message too large")
                self._write(resp)
                continue

            try:
                msg = json.loads(line)
            except json.JSONDecodeError:
                resp = _jsonrpc_error(None, PARSE_ERROR, "Invalid JSON")
                self._write(resp)
                continue

            # Validate basic JSON-RPC structure
            if not isinstance(msg, dict) or msg.get("jsonrpc") != "2.0":
                resp = _jsonrpc_error(
                    msg.get("id") if isinstance(msg, dict) else None,
                    INVALID_REQUEST,
                    "Not a valid JSON-RPC 2.0 message",
                )
                self._write(resp)
                continue

            response = self.handle_message(msg)
            if response is not None:
                self._write(response)

    def _write(self, response: dict):
        """Write a JSON-RPC response to stdout, handling BrokenPipeError."""
        try:
            sys.stdout.write(json.dumps(response) + "\n")
            sys.stdout.flush()
        except BrokenPipeError:
            _log("stdout pipe broken, exiting")
            sys.exit(0)


# ---------------------------------------------------------------------------
# Project root resolution
# ---------------------------------------------------------------------------

def _resolve_project_root() -> Path:
    """Resolve project root from env var, git, or walk-up."""
    # 1. Explicit env var (set by ag commands or IDE config)
    env_root = os.environ.get("AG_PROJECT_ROOT")
    if env_root:
        return Path(env_root).resolve()

    # 2. Git root
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode == 0:
            return Path(result.stdout.strip()).resolve()
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    # 3. Walk up looking for .agentic/
    current = Path.cwd()
    while current != current.parent:
        if (current / ".agentic").is_dir():
            return current
        current = current.parent

    return Path.cwd().resolve()


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    project_root = _resolve_project_root()
    _log(f"starting, project_root={project_root}")

    server = MCPServer(project_root)

    # Clean exit on SIGTERM/SIGINT
    def _signal_handler(signum, frame):
        _log(f"received signal {signum}, exiting")
        sys.exit(0)

    signal.signal(signal.SIGTERM, _signal_handler)
    signal.signal(signal.SIGINT, _signal_handler)

    server.run_stdio()


if __name__ == "__main__":
    main()
