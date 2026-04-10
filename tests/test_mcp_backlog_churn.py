"""
End-to-end tests for MCP-driven backlog churning.

Simulates an orchestrator using MCP coordination tools to iterate through
a multi-feature backlog: claim → list ACs → delegate → track progress →
release → next feature. Tests the full loop that `ag auto crunch` would
drive via the MCP coordination server.

Exercises:
- Multi-feature backlog ordering and isolation
- Claim/release lifecycle per feature
- AC-level delegation prompt generation and progress tracking
- Cross-feature state isolation
- Error handling and retry routing
- get_unblocked integration with feature state
- CrunchRunner._read_backlog_features integration
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import textwrap
import time
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

_PROJECT_ROOT = Path(__file__).resolve().parent.parent
_MCP_SERVER = _PROJECT_ROOT / ".agentic" / "lib" / "auto" / "mcp_server.py"
_PYTHONPATH = str(_PROJECT_ROOT / ".agentic" / "lib")


# ---------------------------------------------------------------------------
# Test project setup
# ---------------------------------------------------------------------------

def _create_backlog_project(tmp_path: Path, num_features: int = 3) -> Path:
    """Create a project with a BACKLOG.json and multiple features with contracts."""
    agentic = tmp_path / ".agentic"
    session = agentic / "session"
    spec = agentic / "spec"
    contracts = spec / "contracts"
    acceptance = spec / "acceptance"
    progress = session / "progress"
    plans = agentic / "journal" / "plans"

    for d in [session, spec, contracts, acceptance, progress, plans]:
        d.mkdir(parents=True)

    # AGENTS.json (empty)
    (session / "AGENTS.json").write_text("[]\n")

    # Build FEATURES.md with multiple features
    features_lines = ["# Features\n\n---\n"]
    backlog_items = []

    for i in range(1, num_features + 1):
        fid = f"F-{i:03d}"
        features_lines.append(f"\n## {fid}: Test Feature {i}\n")
        features_lines.append(f"**Status**: planned\n")
        features_lines.append(f"**Category**: Test\n")

        # Contract YAML with 2 ACs each
        (contracts / f"{fid}.yaml").write_text(textwrap.dedent(f"""\
            id: {fid}
            name: Test Feature {i}
            lifecycle: specifying
            description: Feature {i} for backlog churn testing

            assertions:
              - id: AC-001
                text: Implement component {i}A with validation
                type: behavioral
              - id: AC-002
                text: Add integration tests for component {i}B
                type: structural
        """))

        # Plan file
        (plans / f"2026-04-10-{fid}-plan.md").write_text(textwrap.dedent(f"""\
            # {fid} Implementation Plan

            **Status**: APPROVED

            ## Steps
            1. Build component {i}A
            2. Build component {i}B
            3. Write integration tests
        """))

        # Backlog entry (feature type with id)
        backlog_items.append({
            "type": "feature",
            "id": fid,
            "description": f"{fid}: Test Feature {i}",
            "added_at": f"2026-04-10T12:00:0{i}Z",
            "added_by": "test",
        })

    (spec / "FEATURES.md").write_text("\n".join(features_lines))

    # BACKLOG.json
    (agentic / "BACKLOG.json").write_text(json.dumps(backlog_items, indent=2))

    # Minimal .git so paths resolve
    (tmp_path / ".git").mkdir()

    return tmp_path


# ---------------------------------------------------------------------------
# MCP Client (reused from test_mcp_e2e.py pattern)
# ---------------------------------------------------------------------------

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

        # MCP handshake
        resp = self._request("initialize", {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "backlog-churn-test", "version": "1.0.0"},
        })
        assert resp["result"]["protocolVersion"] == "2024-11-05"
        self._notify("notifications/initialized", {})

    def call_tool(self, name: str, arguments: dict) -> dict:
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
        time.sleep(0.05)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def project(tmp_path):
    return _create_backlog_project(tmp_path, num_features=3)


@pytest.fixture
def mcp(project):
    client = MCPClient(project)
    yield client
    client.close()


@pytest.fixture
def project_5(tmp_path):
    """Project with 5 features for larger batch tests."""
    return _create_backlog_project(tmp_path, num_features=5)


@pytest.fixture
def mcp_5(project_5):
    client = MCPClient(project_5)
    yield client
    client.close()


# ---------------------------------------------------------------------------
# Helper: simulate full feature completion via MCP tools
# ---------------------------------------------------------------------------

def _complete_feature_via_mcp(mcp: MCPClient, feature_id: str) -> dict:
    """Simulate a full feature completion cycle using MCP tools.

    Returns the final get_next_action result (should be "done").
    """
    # List ACs
    acs = mcp.call_tool("list_acs", {"feature_id": feature_id})
    ac_ids = [ac["ac_id"] for ac in acs["criteria"]]

    # Implement each AC
    for ac_id in ac_ids:
        # Get next action (should point to this AC)
        action = mcp.call_tool("get_next_action", {"feature_id": feature_id})
        assert action["action"] == "implement_ac"

        # Get delegation prompt
        delegation = mcp.call_tool("get_delegation_prompt", {
            "feature_id": feature_id, "ac_id": ac_id,
        })
        assert len(delegation["prompt"]) > 50

        # Save as passed
        mcp.call_tool("save_progress", {
            "feature_id": feature_id, "ac_id": ac_id,
            "status": "passed", "note": f"Implemented {ac_id}",
        })

    # Verify
    action = mcp.call_tool("get_next_action", {"feature_id": feature_id})
    assert action["action"] == "verify"
    mcp.call_tool("save_progress", {
        "feature_id": feature_id, "ac_id": "__verify__",
        "status": "passed", "note": "All tests pass",
    })

    # Create PR
    action = mcp.call_tool("get_next_action", {"feature_id": feature_id})
    assert action["action"] == "create_pr"
    mcp.call_tool("save_progress", {
        "feature_id": feature_id, "ac_id": "__pr__",
        "status": "passed", "note": "PR created",
    })

    # Should be done
    final = mcp.call_tool("get_next_action", {"feature_id": feature_id})
    assert final["action"] == "done"
    return final


# ===========================================================================
# Tests: Multi-Feature Backlog Churning via MCP
# ===========================================================================

class TestBacklogChurnOrchestration:
    """Simulate a full backlog churn session using MCP tools."""

    def test_full_backlog_churn_3_features(self, mcp, project):
        """Complete 3-feature backlog churn: claim → implement ACs → verify → PR → release."""
        backlog = json.loads(
            (project / ".agentic" / "BACKLOG.json").read_text()
        )
        feature_ids = [item["id"] for item in backlog if item.get("type") == "feature"]
        assert len(feature_ids) == 3

        completed = []
        for fid in feature_ids:
            # Claim
            claim = mcp.call_tool("claim_feature", {
                "feature_id": fid, "agent": "orchestrator",
            })
            assert claim["claimed"] is True

            # Complete feature (all ACs, verify, PR)
            _complete_feature_via_mcp(mcp, fid)

            # Report status
            mcp.call_tool("report_status", {
                "feature_id": fid, "note": f"Completed all ACs for {fid}",
            })

            # Release
            release = mcp.call_tool("release_feature", {"feature_id": fid})
            assert release["released"] is True

            completed.append(fid)

        assert completed == ["F-001", "F-002", "F-003"]

        # Verify all progress files exist and are isolated
        for fid in feature_ids:
            pf = project / ".agentic" / "session" / "progress" / f"{fid}.json"
            assert pf.exists(), f"Progress file missing for {fid}"
            data = json.loads(pf.read_text())
            # Each feature: AC-001, AC-002, __verify__, __pr__ = 4 entries
            assert len(data) == 4, f"{fid} has {len(data)} entries, expected 4"
            # All entries should reference this feature's ACs, not another feature's
            ac_ids_in_progress = {e["ac_id"] for e in data}
            assert ac_ids_in_progress == {"AC-001", "AC-002", "__verify__", "__pr__"}

    def test_backlog_ordering_preserved(self, mcp, project):
        """Features are available in BACKLOG.json order."""
        backlog = json.loads(
            (project / ".agentic" / "BACKLOG.json").read_text()
        )
        ids_in_order = [item["id"] for item in backlog if item.get("type") == "feature"]
        assert ids_in_order == ["F-001", "F-002", "F-003"]

        # Each feature should have its own ACs
        for i, fid in enumerate(ids_in_order, start=1):
            acs = mcp.call_tool("list_acs", {"feature_id": fid})
            assert acs["total"] == 2
            # AC text should reference the right feature number
            assert f"component {i}A" in acs["criteria"][0]["text"]

    def test_claim_prevents_double_work(self, mcp):
        """Second claim on same feature is rejected."""
        mcp.call_tool("claim_feature", {
            "feature_id": "F-001", "agent": "agent-1",
        })
        # Second claim raises because coord_tools returns error → isError in MCP
        with pytest.raises(RuntimeError, match="already claimed"):
            mcp.call_tool("claim_feature", {
                "feature_id": "F-001", "agent": "agent-2",
            })


class TestCrossFeatureIsolation:
    """Verify progress for one feature doesn't leak into another."""

    def test_progress_isolated_between_features(self, mcp, project):
        """Completing ACs for F-001 doesn't affect F-002's state."""
        # Complete F-001's AC-001
        mcp.call_tool("save_progress", {
            "feature_id": "F-001", "ac_id": "AC-001",
            "status": "passed", "note": "Done",
        })

        # F-002 should still have all ACs pending
        acs = mcp.call_tool("list_acs", {"feature_id": "F-002"})
        assert acs["completed"] == 0
        assert acs["pending"] == 2
        for ac in acs["criteria"]:
            assert ac["status"] == "pending"

    def test_next_action_isolated(self, mcp):
        """get_next_action for F-002 unaffected by F-001's progress."""
        # Advance F-001 to verify
        mcp.call_tool("save_progress", {
            "feature_id": "F-001", "ac_id": "AC-001",
            "status": "passed", "note": "Done",
        })
        mcp.call_tool("save_progress", {
            "feature_id": "F-001", "ac_id": "AC-002",
            "status": "passed", "note": "Done",
        })
        action_f001 = mcp.call_tool("get_next_action", {"feature_id": "F-001"})
        assert action_f001["action"] == "verify"

        # F-002 should still be on AC-001
        action_f002 = mcp.call_tool("get_next_action", {"feature_id": "F-002"})
        assert action_f002["action"] == "implement_ac"
        assert action_f002["details"]["ac_id"] == "AC-001"

    def test_delegation_prompts_feature_specific(self, mcp):
        """Delegation prompts reference the correct feature context."""
        prompt_1 = mcp.call_tool("get_delegation_prompt", {
            "feature_id": "F-001", "ac_id": "AC-001",
        })
        prompt_2 = mcp.call_tool("get_delegation_prompt", {
            "feature_id": "F-002", "ac_id": "AC-001",
        })

        # Each prompt references the right feature
        assert "F-001" in prompt_1["prompt"]
        assert "component 1A" in prompt_1["prompt"]
        assert "F-002" in prompt_2["prompt"]
        assert "component 2A" in prompt_2["prompt"]

        # Plan context should differ
        assert "Feature 1" in prompt_1["prompt"] or "Build component 1" in prompt_1["prompt"]
        assert "Feature 2" in prompt_2["prompt"] or "Build component 2" in prompt_2["prompt"]


class TestErrorHandlingDuringChurn:
    """Test error/retry routing when ACs fail during backlog churning."""

    def test_failed_ac_retry_routing(self, mcp):
        """After an AC fails, get_next_action routes back to retry it."""
        # Fail AC-001
        mcp.call_tool("save_progress", {
            "feature_id": "F-001", "ac_id": "AC-001",
            "status": "failed", "note": "Test failure in parser",
        })

        # Next action should be retry of AC-001 (attempt 2)
        action = mcp.call_tool("get_next_action", {"feature_id": "F-001"})
        assert action["action"] == "implement_ac"
        assert action["details"]["ac_id"] == "AC-001"
        assert action["details"]["attempt"] == 2

    def test_failed_ac_context_in_retry_prompt(self, mcp):
        """Delegation prompt for retry includes prior failure context."""
        mcp.call_tool("save_progress", {
            "feature_id": "F-001", "ac_id": "AC-001",
            "status": "failed", "note": "ImportError: missing lxml dependency",
        })

        prompt = mcp.call_tool("get_delegation_prompt", {
            "feature_id": "F-001", "ac_id": "AC-001",
        })
        assert "ImportError" in prompt["prompt"]
        assert "lxml" in prompt["prompt"]

    def test_partial_feature_then_continue(self, mcp, project):
        """Complete one AC, fail another, then fix — feature still completes."""
        # Pass AC-001
        mcp.call_tool("save_progress", {
            "feature_id": "F-001", "ac_id": "AC-001",
            "status": "passed", "note": "Done",
        })

        # Fail AC-002
        mcp.call_tool("save_progress", {
            "feature_id": "F-001", "ac_id": "AC-002",
            "status": "failed", "note": "Assertion error",
        })

        # Next action: retry AC-002
        action = mcp.call_tool("get_next_action", {"feature_id": "F-001"})
        assert action["action"] == "implement_ac"
        assert action["details"]["ac_id"] == "AC-002"
        assert action["details"]["attempt"] == 2

        # Fix AC-002
        mcp.call_tool("save_progress", {
            "feature_id": "F-001", "ac_id": "AC-002",
            "status": "passed", "note": "Fixed assertion",
        })

        # Should be at verify now
        action = mcp.call_tool("get_next_action", {"feature_id": "F-001"})
        assert action["action"] == "verify"

    def test_feature_failure_doesnt_block_next_feature(self, mcp, project):
        """Failing all ACs in F-001 doesn't prevent working on F-002."""
        # Exhaust retries on F-001 (3 failures)
        for i in range(3):
            mcp.call_tool("save_progress", {
                "feature_id": "F-001", "ac_id": "AC-001",
                "status": "failed", "note": f"Attempt {i+1} failed",
            })

        # F-001 is stuck but F-002 is pristine
        action_f002 = mcp.call_tool("get_next_action", {"feature_id": "F-002"})
        assert action_f002["action"] == "implement_ac"
        assert action_f002["details"]["ac_id"] == "AC-001"
        assert action_f002["details"]["attempt"] == 1

        # Can complete F-002 independently
        _complete_feature_via_mcp(mcp, "F-002")


class TestCoordinationDuringChurn:
    """Test that coordination tools (claim, release, poll) integrate correctly."""

    def test_claim_release_cycle_per_feature(self, mcp):
        """Each feature goes through a clean claim/release cycle."""
        for fid in ["F-001", "F-002", "F-003"]:
            claim = mcp.call_tool("claim_feature", {
                "feature_id": fid, "agent": "churn-bot",
            })
            assert claim["claimed"] is True

            # Do some work
            mcp.call_tool("save_progress", {
                "feature_id": fid, "ac_id": "AC-001",
                "status": "passed", "note": "Quick impl",
            })

            release = mcp.call_tool("release_feature", {"feature_id": fid})
            assert release["released"] is True

        # All released — can reclaim any
        reclaim = mcp.call_tool("claim_feature", {
            "feature_id": "F-001", "agent": "another-agent",
        })
        assert reclaim["claimed"] is True

    def test_report_status_during_churn(self, mcp):
        """Status reports work during multi-feature processing."""
        mcp.call_tool("claim_feature", {
            "feature_id": "F-001", "agent": "orchestrator",
        })

        report = mcp.call_tool("report_status", {
            "feature_id": "F-001", "note": "Starting AC-001 implementation",
        })
        assert report["reported"] is True

        report2 = mcp.call_tool("report_status", {
            "feature_id": "F-001", "note": "AC-001 complete, moving to AC-002",
        })
        assert report2["reported"] is True

    def test_poll_changes_after_progress(self, mcp, project):
        """poll_changes detects mutations after progress saves."""
        # Get baseline
        before = mcp.call_tool("poll_changes", {"since": "1970-01-01T00:00:00Z"})
        assert before["changed"] is True  # FEATURES.md was created

        # Record the timestamp
        ts = before["timestamp"]

        # Small delay to ensure mtime advances
        time.sleep(0.05)

        # Mutate AGENTS.json by claiming
        mcp.call_tool("claim_feature", {
            "feature_id": "F-001", "agent": "test",
        })

        # Poll should detect the change
        after = mcp.call_tool("poll_changes", {"since": ts})
        assert after["changed"] is True
        assert "agents" in after


class TestLargerBacklog:
    """Test with 5 features to verify scaling behavior."""

    def test_churn_5_features_sequentially(self, mcp_5, project_5):
        """Churn through 5 features sequentially, all complete."""
        completed_ids = []
        for i in range(1, 6):
            fid = f"F-{i:03d}"
            _complete_feature_via_mcp(mcp_5, fid)
            completed_ids.append(fid)

        assert len(completed_ids) == 5

        # Each feature should have 4 progress entries
        for fid in completed_ids:
            pf = project_5 / ".agentic" / "session" / "progress" / f"{fid}.json"
            data = json.loads(pf.read_text())
            assert len(data) == 4

    def test_mixed_success_failure_across_backlog(self, mcp_5, project_5):
        """Some features complete, some fail — proper accounting."""
        results = {}

        # F-001: complete
        _complete_feature_via_mcp(mcp_5, "F-001")
        results["F-001"] = "done"

        # F-002: fail AC-001 three times
        for i in range(3):
            mcp_5.call_tool("save_progress", {
                "feature_id": "F-002", "ac_id": "AC-001",
                "status": "failed", "note": f"Fail {i+1}",
            })
        results["F-002"] = "stuck"

        # F-003: complete
        _complete_feature_via_mcp(mcp_5, "F-003")
        results["F-003"] = "done"

        # F-004: partial (only AC-001)
        mcp_5.call_tool("save_progress", {
            "feature_id": "F-004", "ac_id": "AC-001",
            "status": "passed", "note": "Done",
        })
        results["F-004"] = "partial"

        # F-005: complete
        _complete_feature_via_mcp(mcp_5, "F-005")
        results["F-005"] = "done"

        # Verify states
        done_f001 = mcp_5.call_tool("get_next_action", {"feature_id": "F-001"})
        assert done_f001["action"] == "done"

        stuck_f002 = mcp_5.call_tool("get_next_action", {"feature_id": "F-002"})
        assert stuck_f002["action"] == "implement_ac"
        assert stuck_f002["details"]["attempt"] == 4  # 3 failures + retry

        done_f003 = mcp_5.call_tool("get_next_action", {"feature_id": "F-003"})
        assert done_f003["action"] == "done"

        partial_f004 = mcp_5.call_tool("get_next_action", {"feature_id": "F-004"})
        assert partial_f004["action"] == "implement_ac"
        assert partial_f004["details"]["ac_id"] == "AC-002"

        done_f005 = mcp_5.call_tool("get_next_action", {"feature_id": "F-005"})
        assert done_f005["action"] == "done"


# ===========================================================================
# Tests: CrunchRunner backlog integration
# ===========================================================================

class TestCrunchRunnerBacklogIntegration:
    """Test that CrunchRunner correctly reads BACKLOG.json for feature ordering."""

    def test_read_backlog_features(self, project):
        """CrunchRunner reads feature IDs from BACKLOG.json in order."""
        sys.path.insert(0, str(_PROJECT_ROOT / ".agentic" / "lib"))
        from auto.crunch import CrunchRunner

        runner = CrunchRunner(project_root=project)
        features = runner._read_backlog_features()
        assert features == ["F-001", "F-002", "F-003"]

    def test_backlog_skips_non_feature_items(self, project):
        """Task-type items in BACKLOG.json are skipped."""
        # Add a task item to the backlog
        backlog_file = project / ".agentic" / "BACKLOG.json"
        backlog = json.loads(backlog_file.read_text())
        backlog.insert(0, {
            "type": "task",
            "description": "T-0001: Some task",
            "added_at": "2026-04-10T11:00:00Z",
            "added_by": "test",
        })
        backlog_file.write_text(json.dumps(backlog, indent=2))

        sys.path.insert(0, str(_PROJECT_ROOT / ".agentic" / "lib"))
        from auto.crunch import CrunchRunner

        runner = CrunchRunner(project_root=project)
        features = runner._read_backlog_features()
        # Should only return feature-type items
        assert features == ["F-001", "F-002", "F-003"]

    def test_empty_backlog_falls_through(self, tmp_path):
        """Empty BACKLOG.json causes fallthrough to state machine."""
        agentic = tmp_path / ".agentic"
        (agentic / "session").mkdir(parents=True)
        (agentic / "spec").mkdir(parents=True)
        (agentic / "BACKLOG.json").write_text("[]")
        (tmp_path / ".git").mkdir()

        sys.path.insert(0, str(_PROJECT_ROOT / ".agentic" / "lib"))
        from auto.crunch import CrunchRunner

        runner = CrunchRunner(project_root=tmp_path)
        features = runner._read_backlog_features()
        assert features == []

    def test_missing_backlog_returns_empty(self, tmp_path):
        """No BACKLOG.json returns empty list."""
        agentic = tmp_path / ".agentic"
        (agentic / "session").mkdir(parents=True)
        (agentic / "spec").mkdir(parents=True)
        (tmp_path / ".git").mkdir()

        sys.path.insert(0, str(_PROJECT_ROOT / ".agentic" / "lib"))
        from auto.crunch import CrunchRunner

        runner = CrunchRunner(project_root=tmp_path)
        features = runner._read_backlog_features()
        assert features == []

    def test_backlog_with_only_tasks_returns_empty(self, tmp_path):
        """BACKLOG.json with only task items returns empty (no features)."""
        agentic = tmp_path / ".agentic"
        (agentic / "session").mkdir(parents=True)
        (agentic / "spec").mkdir(parents=True)
        backlog = [
            {"type": "task", "description": "T-001: Do something"},
            {"type": "task", "description": "T-002: Do something else"},
        ]
        (agentic / "BACKLOG.json").write_text(json.dumps(backlog))
        (tmp_path / ".git").mkdir()

        sys.path.insert(0, str(_PROJECT_ROOT / ".agentic" / "lib"))
        from auto.crunch import CrunchRunner

        runner = CrunchRunner(project_root=tmp_path)
        features = runner._read_backlog_features()
        assert features == []


# ===========================================================================
# Tests: Task brief context across backlog features
# ===========================================================================

class TestTaskBriefContextDuringChurn:
    """Verify that task briefs are feature-specific during batch processing."""

    def test_plan_summary_per_feature(self, mcp):
        """Each feature's brief includes its own plan, not another's."""
        brief_1 = mcp.call_tool("get_task_brief", {"feature_id": "F-001"})
        brief_2 = mcp.call_tool("get_task_brief", {"feature_id": "F-002"})

        assert "Build component 1" in brief_1["plan_summary"]
        assert "Build component 2" in brief_2["plan_summary"]
        # No cross-contamination
        assert "Build component 2" not in brief_1["plan_summary"]
        assert "Build component 1" not in brief_2["plan_summary"]

    def test_prior_progress_per_feature(self, mcp):
        """Prior notes in task brief are scoped to the requested feature."""
        mcp.call_tool("save_progress", {
            "feature_id": "F-001", "ac_id": "AC-001",
            "status": "failed", "note": "F-001 specific error: NullRef",
        })
        mcp.call_tool("save_progress", {
            "feature_id": "F-002", "ac_id": "AC-001",
            "status": "failed", "note": "F-002 specific error: Timeout",
        })

        brief_1 = mcp.call_tool("get_task_brief", {
            "feature_id": "F-001", "ac_id": "AC-001",
        })
        brief_2 = mcp.call_tool("get_task_brief", {
            "feature_id": "F-002", "ac_id": "AC-001",
        })

        # F-001's brief mentions its error, not F-002's
        assert any("NullRef" in n for n in brief_1["prior_notes"])
        assert not any("Timeout" in n for n in brief_1["prior_notes"])

        # F-002's brief mentions its error, not F-001's
        assert any("Timeout" in n for n in brief_2["prior_notes"])
        assert not any("NullRef" in n for n in brief_2["prior_notes"])

    def test_ac_text_correct_per_feature(self, mcp):
        """AC text in task brief matches the requested feature's contract."""
        brief_1 = mcp.call_tool("get_task_brief", {
            "feature_id": "F-001", "ac_id": "AC-001",
        })
        brief_3 = mcp.call_tool("get_task_brief", {
            "feature_id": "F-003", "ac_id": "AC-001",
        })

        assert "component 1A" in brief_1["ac_text"]
        assert "component 3A" in brief_3["ac_text"]


# ===========================================================================
# Tests: Regression scenarios for backlog churning
# ===========================================================================

class TestChurnRegressions:

    def test_regression_passed_then_failed_mid_churn(self, mcp):
        """AC passes for F-001, then regresses — get_next_action catches it."""
        mcp.call_tool("save_progress", {
            "feature_id": "F-001", "ac_id": "AC-001",
            "status": "passed", "note": "Looks good",
        })
        mcp.call_tool("save_progress", {
            "feature_id": "F-001", "ac_id": "AC-001",
            "status": "failed", "note": "Regression: integration test broke",
        })

        action = mcp.call_tool("get_next_action", {"feature_id": "F-001"})
        assert action["action"] == "implement_ac"
        assert action["details"]["ac_id"] == "AC-001"
        # 2 entries (pass + fail) + next attempt = 3
        assert action["details"]["attempt"] == 3

    def test_double_claim_different_features_ok(self, mcp):
        """Same agent can claim multiple features (different IDs)."""
        c1 = mcp.call_tool("claim_feature", {
            "feature_id": "F-001", "agent": "multi-worker",
        })
        c2 = mcp.call_tool("claim_feature", {
            "feature_id": "F-002", "agent": "multi-worker",
        })
        assert c1["claimed"] is True
        assert c2["claimed"] is True

    def test_save_progress_after_all_features_claimed(self, mcp):
        """Progress can be saved even after features are claimed by another."""
        mcp.call_tool("claim_feature", {
            "feature_id": "F-001", "agent": "agent-A",
        })

        # Different "subagent" saves progress (claims don't gate saves)
        result = mcp.call_tool("save_progress", {
            "feature_id": "F-001", "ac_id": "AC-001",
            "status": "passed", "note": "Subagent completed",
        })
        assert result["recorded"] is True
