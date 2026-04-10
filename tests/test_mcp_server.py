"""
Tests for F-018 AC-002/003/004: MCP coordination transport.

Test strategy:
- MCP protocol compliance (initialize, tools/list, tools/call, notifications)
- Tool dispatch to coord_tools handlers (mocked)
- Error handling: protocol errors vs tool errors (isError pattern)
- Structural: mcp_tool_defs keys match coord_tools.TOOLS keys
- Stdout capture: handler print() does not corrupt JSON-RPC stream
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

# Add lib/ to path for imports
_LIB_DIR = Path(__file__).resolve().parent.parent / ".agentic" / "lib"
sys.path.insert(0, str(_LIB_DIR))

from auto.mcp_server import MCPServer, _capture_output, _jsonrpc_error, _jsonrpc_success
from auto.mcp_tool_defs import MCP_TOOL_DEFS, get_tool_definitions


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------
@pytest.fixture
def server(tmp_path):
    """Create an MCPServer with a temporary project root."""
    (tmp_path / ".agentic").mkdir()
    return MCPServer(tmp_path)


# ---------------------------------------------------------------------------
# Protocol tests
# ---------------------------------------------------------------------------
class TestMCPProtocol:
    """Test MCP handshake and message routing."""

    def test_initialize(self, server):
        msg = {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}}
        resp = server.handle_message(msg)
        assert resp["id"] == 1
        assert resp["result"]["protocolVersion"] == "2024-11-05"
        assert resp["result"]["serverInfo"]["name"] == "agentic-coord"
        assert "tools" in resp["result"]["capabilities"]

    def test_notification_returns_none(self, server):
        msg = {"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}}
        resp = server.handle_message(msg)
        assert resp is None

    def test_unknown_method(self, server):
        msg = {"jsonrpc": "2.0", "id": 2, "method": "unknown/method", "params": {}}
        resp = server.handle_message(msg)
        assert "error" in resp
        assert resp["error"]["code"] == -32601  # METHOD_NOT_FOUND

    def test_tools_list(self, server):
        msg = {"jsonrpc": "2.0", "id": 3, "method": "tools/list", "params": {}}
        resp = server.handle_message(msg)
        assert "result" in resp
        tools = resp["result"]["tools"]
        assert len(tools) == 13
        names = {t["name"] for t in tools}
        assert "claim_feature" in names
        assert "get_unblocked" in names
        # Task delegation tools
        assert "list_acs" in names
        assert "get_task_brief" in names
        assert "save_progress" in names
        assert "get_next_action" in names
        assert "get_delegation_prompt" in names

    def test_tools_list_has_input_schemas(self, server):
        msg = {"jsonrpc": "2.0", "id": 4, "method": "tools/list", "params": {}}
        resp = server.handle_message(msg)
        for tool in resp["result"]["tools"]:
            assert "inputSchema" in tool, f"Missing inputSchema for {tool['name']}"
            assert tool["inputSchema"]["type"] == "object"


# ---------------------------------------------------------------------------
# Tool call tests
# ---------------------------------------------------------------------------
class TestToolCalls:
    """Test tools/call dispatch and error handling."""

    def test_unknown_tool(self, server):
        msg = {
            "jsonrpc": "2.0", "id": 5,
            "method": "tools/call",
            "params": {"name": "nonexistent_tool", "arguments": {}},
        }
        resp = server.handle_message(msg)
        assert "error" in resp
        assert resp["error"]["code"] == -32601

    @patch.dict("auto.coord_tools.TOOLS", {"get_unblocked": MagicMock(return_value={"features": []})}, clear=True)
    def test_successful_tool_call(self, server):
        msg = {
            "jsonrpc": "2.0", "id": 6,
            "method": "tools/call",
            "params": {"name": "get_unblocked", "arguments": {}},
        }
        resp = server.handle_message(msg)
        assert "result" in resp
        content = resp["result"]["content"]
        assert len(content) == 1
        assert content[0]["type"] == "text"
        result_data = json.loads(content[0]["text"])
        assert result_data["features"] == []
        # No isError on success
        assert "isError" not in resp["result"]

    @patch.dict("auto.coord_tools.TOOLS", {
        "claim_feature": MagicMock(return_value={"claimed": False, "error": "already claimed"})
    }, clear=True)
    def test_tool_error_uses_isError(self, server):
        msg = {
            "jsonrpc": "2.0", "id": 7,
            "method": "tools/call",
            "params": {"name": "claim_feature", "arguments": {"feature_id": "F-0042"}},
        }
        resp = server.handle_message(msg)
        # Tool-level errors return successful JSON-RPC with isError in result
        assert "result" in resp
        assert resp["result"]["isError"] is True
        content = resp["result"]["content"]
        result_data = json.loads(content[0]["text"])
        assert "error" in result_data

    @patch.dict("auto.coord_tools.TOOLS", {
        "claim_feature": MagicMock(side_effect=RuntimeError("disk full"))
    }, clear=True)
    def test_tool_exception_uses_isError(self, server):
        msg = {
            "jsonrpc": "2.0", "id": 8,
            "method": "tools/call",
            "params": {"name": "claim_feature", "arguments": {"feature_id": "F-0042"}},
        }
        resp = server.handle_message(msg)
        # Exceptions also use isError, not JSON-RPC error
        assert "result" in resp
        assert resp["result"]["isError"] is True
        content = resp["result"]["content"]
        result_data = json.loads(content[0]["text"])
        assert "disk full" in result_data["error"]


# ---------------------------------------------------------------------------
# Stdout capture tests
# ---------------------------------------------------------------------------
class TestStdoutCapture:
    """Test that handler stdout does not corrupt JSON-RPC stream."""

    def test_capture_output_catches_print(self):
        def noisy_handler(root, params):
            print("this should not reach stdout")
            return {"success": True}

        result = _capture_output(noisy_handler, Path("/tmp"), {})
        assert result == {"success": True}

    def test_capture_output_handles_system_exit(self):
        def exiting_handler(root, params):
            raise SystemExit(1)

        result = _capture_output(exiting_handler, Path("/tmp"), {})
        assert "error" in result
        assert "SystemExit" in result["error"]


# ---------------------------------------------------------------------------
# Structural tests
# ---------------------------------------------------------------------------
class TestStructural:
    """Verify mcp_tool_defs stays in sync with coord_tools."""

    def test_tool_defs_match_coord_tools(self):
        from auto.coord_tools import TOOLS
        mcp_names = set(MCP_TOOL_DEFS.keys())
        coord_names = set(TOOLS.keys())
        assert mcp_names == coord_names, (
            f"Mismatch: mcp_tool_defs has {mcp_names - coord_names} extra, "
            f"coord_tools has {coord_names - mcp_names} extra"
        )

    def test_get_tool_definitions_format(self):
        defs = get_tool_definitions()
        assert isinstance(defs, list)
        assert len(defs) == len(MCP_TOOL_DEFS)
        for d in defs:
            assert "name" in d
            assert "description" in d
            assert "inputSchema" in d


# ---------------------------------------------------------------------------
# JSON-RPC helper tests
# ---------------------------------------------------------------------------
class TestJsonRpcHelpers:

    def test_success_response(self):
        resp = _jsonrpc_success(42, {"data": "value"})
        assert resp == {
            "jsonrpc": "2.0",
            "result": {"data": "value"},
            "id": 42,
        }

    def test_error_response(self):
        resp = _jsonrpc_error(42, -32600, "bad request")
        assert resp == {
            "jsonrpc": "2.0",
            "error": {"code": -32600, "message": "bad request"},
            "id": 42,
        }
