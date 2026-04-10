"""
End-to-end tests for MCP task delegation tools.

Spawns the actual MCP server as a subprocess over stdio, sends JSON-RPC
messages, and verifies the full delegation workflow: list_acs → get_delegation_prompt
→ save_progress → get_next_action cycle.

These tests exercise the real file I/O, contract parsing, progress persistence,
and state machine routing — not mocks.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import textwrap
import time
from pathlib import Path

import pytest

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_PROJECT_ROOT = Path(__file__).resolve().parent.parent
_MCP_SERVER = _PROJECT_ROOT / ".agentic" / "lib" / "auto" / "mcp_server.py"
_PYTHONPATH = str(_PROJECT_ROOT / ".agentic" / "lib")


def _create_test_project(tmp_path: Path) -> Path:
    """Create a realistic project structure for e2e testing."""
    agentic = tmp_path / ".agentic"
    session = agentic / "session"
    spec = agentic / "spec"
    contracts = spec / "contracts"
    acceptance = spec / "acceptance"
    progress = session / "progress"
    plans = agentic / "journal" / "plans"

    for d in [session, spec, contracts, acceptance, progress, plans]:
        d.mkdir(parents=True)

    # AGENTS.json
    (session / "AGENTS.json").write_text("[]\n")

    # FEATURES.md
    (spec / "FEATURES.md").write_text(textwrap.dedent("""\
        # Features

        ---

        ## F-099: E2E Test Feature

        **Status**: planned
        **Category**: Test
    """))

    # Contract YAML with 3 ACs (1 draft)
    (contracts / "F-099.yaml").write_text(textwrap.dedent("""\
        id: F-099
        name: E2E Test Feature
        lifecycle: specifying
        description: Feature for end-to-end MCP delegation testing

        assertions:
          - id: AC-001
            text: Implement the widget parser with error handling
            type: behavioral
          - id: AC-002
            text: Add validation for input schema
            type: structural
            verify: |
              test -f src/validator.py
          - id: AC-003
            text: Draft criterion not ready yet
            type: behavioral
            draft: true
    """))

    # A plan file
    (plans / "2026-04-10-F-099-plan.md").write_text(textwrap.dedent("""\
        # F-099 Implementation Plan

        **Status**: APPROVED

        ## Steps
        1. Parse widget format
        2. Add schema validation
        3. Write tests
    """))

    # Legacy markdown AC for F-100
    (acceptance / "F-100.md").write_text(textwrap.dedent("""\
        # F-100

        - [ ] AC-001: Build the dashboard component
        - [ ] AC-002: Add filtering support
        - [x] AC-003: Setup routing (done)
    """))

    # Minimal .git so paths resolve
    (tmp_path / ".git").mkdir()

    return tmp_path


class MCPClient:
    """Communicate with the MCP server subprocess over stdio."""

    def __init__(self, project_root: Path):
        env = os.environ.copy()
        env["PYTHONPATH"] = _PYTHONPATH
        env["AG_PROJECT_ROOT"] = str(project_root)

        self.proc = subprocess.Popen(
            [sys.executable, str(_MCP_SERVER)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=str(project_root),
            env=env,
        )
        self._req_id = 0

        # Initialize MCP handshake
        resp = self._request("initialize", {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "e2e-test", "version": "1.0.0"},
        })
        assert resp["result"]["protocolVersion"] == "2024-11-05"

        # Send initialized notification (no response expected)
        self._notify("notifications/initialized", {})

    def call_tool(self, name: str, arguments: dict) -> dict:
        """Call an MCP tool and return the parsed result."""
        resp = self._request("tools/call", {"name": name, "arguments": arguments})
        if "error" in resp:
            raise RuntimeError(f"JSON-RPC error: {resp['error']}")
        result = resp["result"]
        content = result["content"][0]["text"]
        parsed = json.loads(content)
        if result.get("isError"):
            raise RuntimeError(f"Tool error: {parsed}")
        return parsed

    def list_tools(self) -> list[str]:
        """Get names of all available tools."""
        resp = self._request("tools/list", {})
        return [t["name"] for t in resp["result"]["tools"]]

    def close(self):
        if self.proc.stdin:
            self.proc.stdin.close()
        try:
            self.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait()

    def _request(self, method: str, params: dict) -> dict:
        self._req_id += 1
        msg = {"jsonrpc": "2.0", "id": self._req_id, "method": method, "params": params}
        line = json.dumps(msg) + "\n"
        self.proc.stdin.write(line.encode())
        self.proc.stdin.flush()
        raw = self.proc.stdout.readline()
        return json.loads(raw)

    def _notify(self, method: str, params: dict):
        msg = {"jsonrpc": "2.0", "method": method, "params": params}
        line = json.dumps(msg) + "\n"
        self.proc.stdin.write(line.encode())
        self.proc.stdin.flush()
        # No response for notifications — give server a moment to process
        time.sleep(0.05)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def project(tmp_path):
    return _create_test_project(tmp_path)


@pytest.fixture
def mcp(project):
    client = MCPClient(project)
    yield client
    client.close()


# ---------------------------------------------------------------------------
# Tests: MCP Server Startup & Tool Discovery
# ---------------------------------------------------------------------------

class TestServerStartup:
    def test_handshake_completes(self, mcp):
        """Server starts and completes MCP handshake."""
        tools = mcp.list_tools()
        assert len(tools) == 13

    def test_all_delegation_tools_present(self, mcp):
        tools = mcp.list_tools()
        for name in ("list_acs", "get_task_brief", "save_progress",
                      "get_next_action", "get_delegation_prompt"):
            assert name in tools, f"Missing tool: {name}"


# ---------------------------------------------------------------------------
# Tests: Full Delegation Workflow (E2E)
# ---------------------------------------------------------------------------

class TestDelegationWorkflow:
    """Simulate the full orchestrator loop over real MCP stdio."""

    def test_list_acs_from_contract_yaml(self, mcp):
        result = mcp.call_tool("list_acs", {"feature_id": "F-099"})
        assert result["total"] == 2  # AC-003 is draft
        assert result["pending"] == 2
        assert result["completed"] == 0
        ids = [ac["ac_id"] for ac in result["criteria"]]
        assert ids == ["AC-001", "AC-002"]

    def test_list_acs_from_legacy_markdown(self, mcp):
        result = mcp.call_tool("list_acs", {"feature_id": "F-100"})
        assert result["total"] == 3
        ids = [ac["ac_id"] for ac in result["criteria"]]
        assert "AC-001" in ids

    def test_get_task_brief_returns_context(self, mcp):
        result = mcp.call_tool("get_task_brief", {
            "feature_id": "F-099", "ac_id": "AC-001",
        })
        assert "widget parser" in result["ac_text"]
        assert isinstance(result["token_estimate"], int)
        assert isinstance(result["files_hint"], list)
        assert isinstance(result["prior_notes"], list)

    def test_get_task_brief_includes_plan(self, mcp):
        result = mcp.call_tool("get_task_brief", {
            "feature_id": "F-099",
        })
        assert "APPROVED" in result["plan_summary"]
        assert "Parse widget" in result["plan_summary"]

    def test_get_task_brief_extracts_file_hints_from_verify(self, mcp):
        result = mcp.call_tool("get_task_brief", {
            "feature_id": "F-099", "ac_id": "AC-002",
        })
        assert "src/validator.py" in result["files_hint"]

    def test_save_progress_persists(self, mcp, project):
        result = mcp.call_tool("save_progress", {
            "feature_id": "F-099", "ac_id": "AC-001",
            "status": "passed", "note": "Widget parser implemented",
            "files_changed": ["src/parser.py", "tests/test_parser.py"],
        })
        assert result["recorded"] is True
        assert result["acs_completed"] == 1
        assert result["acs_remaining"] == 1

        # Verify file actually written
        pf = project / ".agentic" / "session" / "progress" / "F-099.json"
        assert pf.exists()
        data = json.loads(pf.read_text())
        assert len(data) == 1
        assert data[0]["note"] == "Widget parser implemented"

    def test_get_next_action_routes_correctly(self, mcp):
        # Before any progress: should suggest AC-001
        result = mcp.call_tool("get_next_action", {"feature_id": "F-099"})
        assert result["action"] == "implement_ac"
        assert result["details"]["ac_id"] == "AC-001"
        assert result["acs_remaining"] == 2

    def test_get_delegation_prompt_builds_complete_prompt(self, mcp):
        result = mcp.call_tool("get_delegation_prompt", {
            "feature_id": "F-099", "ac_id": "AC-001",
        })
        prompt = result["prompt"]
        assert "AC-001" in prompt
        assert "widget parser" in prompt
        assert "Instructions" in prompt
        assert result["model_hint"] in ("sonnet", "opus")
        assert isinstance(result["use_worktree"], bool)

    def test_full_orchestration_loop(self, mcp, project):
        """Simulate a complete orchestrator session: list → implement → save → next → done."""

        # Step 1: List ACs
        acs = mcp.call_tool("list_acs", {"feature_id": "F-099"})
        assert acs["total"] == 2

        # Step 2: Get next action (should be AC-001)
        action = mcp.call_tool("get_next_action", {"feature_id": "F-099"})
        assert action["action"] == "implement_ac"
        assert action["details"]["ac_id"] == "AC-001"

        # Step 3: Get delegation prompt for AC-001
        delegation = mcp.call_tool("get_delegation_prompt", {
            "feature_id": "F-099", "ac_id": "AC-001",
        })
        assert len(delegation["prompt"]) > 100  # Non-trivial prompt

        # Step 4: Simulate subagent completion — save progress
        mcp.call_tool("save_progress", {
            "feature_id": "F-099", "ac_id": "AC-001",
            "status": "passed", "note": "Parser done with error handling",
            "files_changed": ["src/parser.py"],
        })

        # Step 5: Get next action (should be AC-002 now)
        action = mcp.call_tool("get_next_action", {"feature_id": "F-099"})
        assert action["action"] == "implement_ac"
        assert action["details"]["ac_id"] == "AC-002"
        assert action["acs_remaining"] == 1

        # Step 6: Get delegation prompt for AC-002
        delegation2 = mcp.call_tool("get_delegation_prompt", {
            "feature_id": "F-099", "ac_id": "AC-002",
        })
        assert "validation" in delegation2["prompt"].lower()

        # Step 7: Save AC-002 as passed
        result = mcp.call_tool("save_progress", {
            "feature_id": "F-099", "ac_id": "AC-002",
            "status": "passed", "note": "Schema validator added",
        })
        assert result["acs_completed"] == 2
        assert result["acs_remaining"] == 0

        # Step 8: Get next action — should be verify
        action = mcp.call_tool("get_next_action", {"feature_id": "F-099"})
        assert action["action"] == "verify"

        # Step 9: Save verification as passed
        mcp.call_tool("save_progress", {
            "feature_id": "F-099", "ac_id": "__verify__",
            "status": "passed", "note": "All tests pass",
        })

        # Step 10: Get next action — should be create_pr
        action = mcp.call_tool("get_next_action", {"feature_id": "F-099"})
        assert action["action"] == "create_pr"

        # Step 11: Save PR as done
        mcp.call_tool("save_progress", {
            "feature_id": "F-099", "ac_id": "__pr__",
            "status": "passed", "note": "PR #42 created",
        })

        # Step 12: Get next action — should be done
        action = mcp.call_tool("get_next_action", {"feature_id": "F-099"})
        assert action["action"] == "done"

        # Verify progress file has full history
        pf = project / ".agentic" / "session" / "progress" / "F-099.json"
        history = json.loads(pf.read_text())
        assert len(history) == 4  # AC-001, AC-002, __verify__, __pr__

    def test_prior_progress_appears_in_brief(self, mcp):
        """After saving progress, get_task_brief includes it in prior_notes."""
        mcp.call_tool("save_progress", {
            "feature_id": "F-099", "ac_id": "AC-001",
            "status": "failed", "note": "ImportError in parser module",
        })
        result = mcp.call_tool("get_task_brief", {
            "feature_id": "F-099", "ac_id": "AC-001",
        })
        assert any("ImportError" in n for n in result["prior_notes"])

    def test_prior_progress_appears_in_delegation_prompt(self, mcp):
        """Delegation prompt includes failure context for retries."""
        mcp.call_tool("save_progress", {
            "feature_id": "F-099", "ac_id": "AC-001",
            "status": "failed", "note": "Missing dependency: lxml",
        })
        result = mcp.call_tool("get_delegation_prompt", {
            "feature_id": "F-099", "ac_id": "AC-001",
        })
        assert "Missing dependency" in result["prompt"]


# ---------------------------------------------------------------------------
# Tests: Regression & Edge Cases
# ---------------------------------------------------------------------------

class TestRegressionAndEdgeCases:
    def test_passed_then_failed_regression(self, mcp):
        """AC passed then failed → get_next_action should retry it."""
        mcp.call_tool("save_progress", {
            "feature_id": "F-099", "ac_id": "AC-001",
            "status": "passed", "note": "Seemed to work",
        })
        mcp.call_tool("save_progress", {
            "feature_id": "F-099", "ac_id": "AC-001",
            "status": "failed", "note": "Broke in integration",
        })
        action = mcp.call_tool("get_next_action", {"feature_id": "F-099"})
        assert action["action"] == "implement_ac"
        assert action["details"]["ac_id"] == "AC-001"
        assert action["details"]["attempt"] == 3

    def test_invalid_feature_id_rejected(self, mcp):
        """Path traversal attempt should be rejected."""
        with pytest.raises(RuntimeError, match="invalid"):
            mcp.call_tool("list_acs", {"feature_id": "../../etc/passwd"})

    def test_invalid_feature_id_in_save_progress(self, mcp):
        with pytest.raises(RuntimeError, match="invalid"):
            mcp.call_tool("save_progress", {
                "feature_id": "../traversal",
                "ac_id": "AC-001", "status": "passed", "note": "test",
            })

    def test_nonexistent_feature_returns_error(self, mcp):
        # list_acs with no criteria returns isError because result has "error" key
        with pytest.raises(RuntimeError, match="no criteria found"):
            mcp.call_tool("list_acs", {"feature_id": "F-999"})

    def test_save_progress_invalid_status(self, mcp):
        with pytest.raises(RuntimeError, match="status must be"):
            mcp.call_tool("save_progress", {
                "feature_id": "F-099", "status": "invalid",
            })

    def test_get_delegation_prompt_missing_ac_id(self, mcp):
        with pytest.raises(RuntimeError, match="ac_id"):
            mcp.call_tool("get_delegation_prompt", {"feature_id": "F-099"})

    def test_multiple_features_isolated(self, mcp):
        """Progress for F-099 doesn't leak into F-100."""
        mcp.call_tool("save_progress", {
            "feature_id": "F-099", "ac_id": "AC-001",
            "status": "passed", "note": "Done",
        })
        result = mcp.call_tool("list_acs", {"feature_id": "F-100"})
        # All F-100 ACs should still be pending
        for ac in result["criteria"]:
            assert ac["status"] == "pending"

    def test_attempt_counter_across_failures(self, mcp):
        """Multiple failures increment the attempt counter correctly."""
        for i in range(3):
            mcp.call_tool("save_progress", {
                "feature_id": "F-099", "ac_id": "AC-001",
                "status": "failed", "note": f"Attempt {i+1}",
            })
        action = mcp.call_tool("get_next_action", {"feature_id": "F-099"})
        assert action["details"]["attempt"] == 4  # 3 failed + next attempt


# ---------------------------------------------------------------------------
# Tests: Coordination + Delegation Integration
# ---------------------------------------------------------------------------

class TestCoordinationIntegration:
    """Test that delegation tools work alongside existing coordination tools."""

    def test_claim_then_delegate(self, mcp):
        """Claim a feature, then use delegation tools."""
        # Claim
        claim = mcp.call_tool("claim_feature", {
            "feature_id": "F-099", "agent": "orchestrator",
        })
        assert claim["claimed"] is True

        # Delegate
        acs = mcp.call_tool("list_acs", {"feature_id": "F-099"})
        assert acs["total"] == 2

        prompt = mcp.call_tool("get_delegation_prompt", {
            "feature_id": "F-099", "ac_id": "AC-001",
        })
        assert len(prompt["prompt"]) > 50

        # Report status via coordination tool
        report = mcp.call_tool("report_status", {
            "feature_id": "F-099", "note": "Delegating AC-001",
        })
        assert report["reported"] is True

        # Save progress via delegation tool
        mcp.call_tool("save_progress", {
            "feature_id": "F-099", "ac_id": "AC-001",
            "status": "passed", "note": "Subagent done",
        })

        # Release
        release = mcp.call_tool("release_feature", {"feature_id": "F-099"})
        assert release["released"] is True
