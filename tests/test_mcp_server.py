#!/usr/bin/env python3
"""
Tests for the MCP server (auto.v2.mcp_server).

Covers:
- JSON-RPC protocol handling
- MCP initialization handshake
- Tool listing
- Tool dispatch (ag_status, ag_check, ag_read_artifact)
- Error handling (unknown tool, invalid JSON, missing params)
"""
import json
import sys
from pathlib import Path
from unittest.mock import patch

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))

from auto.v2.config import _CONFIG_CACHE
from auto.v2 import work_items
from auto.v2.mcp_server import (
    MCPServer,
    _jsonrpc_success,
    _jsonrpc_error,
    PARSE_ERROR,
    INVALID_REQUEST,
    METHOD_NOT_FOUND,
    INTERNAL_ERROR,
)
from auto.v2.mcp_tools import (
    MCP_TOOLS,
    get_tool_definitions,
    handle_ag_status,
    handle_ag_check,
    handle_ag_read_artifact,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


MINIMAL_CONFIG = """\
version: 1
engine: v2

workflow:
  states:
    - idea
    - queued
    - planning
    - shipped

  transitions:
    - {from: idea, to: queued}
    - {from: queued, to: planning}

modes:
  formal:
    escape_hatches: false
    skip_transitions: []
    required_artifacts:
      planning: []

profiles:
  guided:
    description: "Default"
    gates:
      plan_approved: human

verification:
  commands:
    - {name: tests, run: "echo PASS", timeout: 10}

artifacts:
  plan.md:
    description: "Implementation plan"
    location: "{work_dir}/plan.md"
"""


@pytest.fixture
def tmp_project(tmp_path):
    """Create a temporary project with minimal v2 config."""
    agentic = tmp_path / ".agentic"
    agentic.mkdir()
    work_dir = agentic / "work"
    work_dir.mkdir()

    config_path = agentic / "state_machine_af.yaml"
    config_path.write_text(MINIMAL_CONFIG)

    _CONFIG_CACHE.clear()
    yield tmp_path
    _CONFIG_CACHE.clear()


@pytest.fixture
def server(tmp_project):
    """Create an MCP server instance."""
    return MCPServer(tmp_project)


@pytest.fixture
def feature_project(tmp_project):
    """Project with a work item and artifacts."""
    item_dir = tmp_project / ".agentic" / "work" / "F-0001"
    item_dir.mkdir()
    (item_dir / "item.yaml").write_text(
        'id: F-0001\ntitle: "Test Feature"\ntype: feature\n'
        "status: planning\nmode: formal\nprofile: guided\n"
        "priority: 1\ncreated: 2026-01-01T00:00:00Z\n"
        "transitions: []\n"
    )
    (item_dir / "plan.md").write_text("# Plan\nThis is the plan.\n")
    return tmp_project


# ---------------------------------------------------------------------------
# JSON-RPC helper tests
# ---------------------------------------------------------------------------


class TestJSONRPCHelpers:
    def test_success_response(self):
        resp = _jsonrpc_success(1, {"status": "ok"})
        assert resp["jsonrpc"] == "2.0"
        assert resp["id"] == 1
        assert resp["result"]["status"] == "ok"

    def test_error_response(self):
        resp = _jsonrpc_error(2, -32600, "Bad request")
        assert resp["jsonrpc"] == "2.0"
        assert resp["id"] == 2
        assert resp["error"]["code"] == -32600
        assert resp["error"]["message"] == "Bad request"


# ---------------------------------------------------------------------------
# Protocol tests
# ---------------------------------------------------------------------------


class TestProtocol:
    """Test MCP protocol handling."""

    def test_initialize(self, server):
        msg = {"jsonrpc": "2.0", "method": "initialize", "id": 1, "params": {}}
        resp = server.handle_message(msg)
        assert resp["id"] == 1
        assert "protocolVersion" in resp["result"]
        assert "capabilities" in resp["result"]
        assert "serverInfo" in resp["result"]

    def test_initialized_notification(self, server):
        msg = {"jsonrpc": "2.0", "method": "notifications/initialized"}
        resp = server.handle_message(msg)
        assert resp is None  # notification, no response
        assert server.initialized is True

    def test_unknown_method(self, server):
        msg = {"jsonrpc": "2.0", "method": "unknown/method", "id": 5, "params": {}}
        resp = server.handle_message(msg)
        assert resp["error"]["code"] == METHOD_NOT_FOUND

    def test_tools_list(self, server):
        msg = {"jsonrpc": "2.0", "method": "tools/list", "id": 2, "params": {}}
        resp = server.handle_message(msg)
        assert resp["id"] == 2
        tools = resp["result"]["tools"]
        tool_names = {t["name"] for t in tools}
        assert "ag_status" in tool_names
        assert "ag_transition" in tool_names
        assert "ag_check" in tool_names
        assert "ag_verify" in tool_names
        assert "ag_read_artifact" in tool_names

    def test_tools_call_unknown_tool(self, server):
        msg = {
            "jsonrpc": "2.0",
            "method": "tools/call",
            "id": 3,
            "params": {"name": "nonexistent", "arguments": {}},
        }
        resp = server.handle_message(msg)
        assert resp["error"]["code"] == METHOD_NOT_FOUND

    def test_tools_call_returns_content(self, server, tmp_project):
        msg = {
            "jsonrpc": "2.0",
            "method": "tools/call",
            "id": 4,
            "params": {"name": "ag_status", "arguments": {}},
        }
        resp = server.handle_message(msg)
        assert resp["id"] == 4
        assert "content" in resp["result"]
        assert resp["result"]["content"][0]["type"] == "text"


# ---------------------------------------------------------------------------
# Tool handler tests
# ---------------------------------------------------------------------------


class TestToolHandlers:
    """Test individual tool handlers."""

    def test_ag_status_empty(self, tmp_project):
        result = handle_ag_status(tmp_project, {})
        assert result["success"] is True

    def test_ag_check_no_active(self, tmp_project):
        result = handle_ag_check(tmp_project, {"quick": True})
        assert result["success"] is True

    def test_ag_read_artifact_success(self, feature_project):
        result = handle_ag_read_artifact(
            feature_project, {"feature_id": "F-0001", "artifact_name": "plan.md"}
        )
        assert result["success"] is True
        assert "This is the plan" in result["content"]

    def test_ag_read_artifact_not_found(self, feature_project):
        result = handle_ag_read_artifact(
            feature_project, {"feature_id": "F-0001", "artifact_name": "nope.md"}
        )
        assert result["success"] is False
        assert "not found" in result["error"].lower()

    def test_ag_read_artifact_missing_params(self, feature_project):
        result = handle_ag_read_artifact(feature_project, {})
        assert result["success"] is False
        assert "required" in result["error"]

    def test_ag_read_artifact_path_traversal(self, feature_project):
        result = handle_ag_read_artifact(
            feature_project, {"feature_id": "F-0001", "artifact_name": "../item.yaml"}
        )
        assert result["success"] is False
        assert "Invalid" in result["error"]

    def test_ag_read_artifact_bad_feature_id(self, feature_project):
        result = handle_ag_read_artifact(
            feature_project, {"feature_id": "not-valid", "artifact_name": "plan.md"}
        )
        assert result["success"] is False
        assert "Invalid" in result["error"]


# ---------------------------------------------------------------------------
# Tool definitions tests
# ---------------------------------------------------------------------------


class TestToolDefinitions:
    """Test MCP tool definition format."""

    def test_five_tools_defined(self):
        assert len(MCP_TOOLS) == 5

    def test_definitions_have_required_fields(self):
        defs = get_tool_definitions()
        for tool_def in defs:
            assert "name" in tool_def
            assert "description" in tool_def
            assert "inputSchema" in tool_def

    def test_definitions_no_handler(self):
        """Exported definitions must not include handler callable."""
        defs = get_tool_definitions()
        for tool_def in defs:
            assert "handler" not in tool_def
