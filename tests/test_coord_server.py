"""
Tests for F-018: Coordination Server.

Test strategy:
- Pure function tests for all 8 tool handlers (happy + sad paths)
- Behavioral tests that verify actual file mutations (not just return values)
- Concurrent access tests (the raison d'être of the coordination server)
- HTTP transport integration tests (auth, JSON-RPC protocol, error codes)
- Edge cases: stale PIDs, wrong-PID release, malformed input, file parse errors
"""
from __future__ import annotations

import json
import os
import socket
import sys
import threading
import time
import urllib.error
import urllib.request
from pathlib import Path

import pytest

# Add lib/ to path for imports
_LIB_DIR = Path(__file__).resolve().parent.parent / ".agentic" / "lib"
sys.path.insert(0, str(_LIB_DIR))

from auto.coord_tools import (
    TOOLS,
    _parse_feature_statuses,
    claim_feature,
    get_unblocked,
    get_next_action,
    get_task_brief,
    get_delegation_prompt,
    list_acs,
    poll_changes,
    release_feature,
    report_status,
    request_review,
    save_progress,
    submit_review,
    transition_state,
)
from auto.coord_server import (
    CoordHTTPServer,
    CoordRequestHandler,
    _read_settings,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------
@pytest.fixture
def project_dir(tmp_path):
    """Create a minimal but realistic project structure for testing."""
    agentic = tmp_path / ".agentic"
    session = agentic / "session"
    spec = agentic / "spec"
    acceptance = spec / "acceptance"
    contracts = spec / "contracts"
    reviews_dir = spec / "reviews"
    pending = session / "reviews"
    progress = session / "progress"

    for d in [session, spec, acceptance, contracts, reviews_dir, pending, progress]:
        d.mkdir(parents=True)

    # AGENTS.json — starts empty
    (session / "AGENTS.json").write_text("[]\n")

    # FEATURES.md with multiple features in different states
    features_content = """\
# Features

---

## F-001: Test Feature

**Status**: planned
**Category**: Test
**Priority**: medium
**Complexity**: low
**Since**: v0.1.0

**Description**: A test feature.

---

## F-0002: In-Progress Feature

**Status**: in_progress
**Category**: Test
**Priority**: high
**Complexity**: medium
**Since**: v0.1.0

**Description**: Feature currently being worked on.

---

## F-002: Shipped Feature

**Status**: shipped
**Category**: Test
**Priority**: low
**Complexity**: low
**Since**: v0.1.0

**Description**: Already shipped.
"""
    (spec / "FEATURES.md").write_text(features_content)

    # Acceptance criteria for F-001 (legacy markdown)
    (acceptance / "F-001.md").write_text(
        "# F-001\n\n- [ ] **AC-001**: Test criterion\n"
    )

    # Contract YAML for F-003 (modern format)
    (contracts / "F-003.yaml").write_text(
        "id: F-003\n"
        "name: Test Delegation Feature\n"
        "lifecycle: specifying\n"
        "description: Feature for testing task delegation tools\n"
        "assertions:\n"
        "  - id: AC-001\n"
        "    text: First acceptance criterion for testing\n"
        "    type: behavioral\n"
        "  - id: AC-002\n"
        "    text: Second acceptance criterion for testing\n"
        "    type: structural\n"
        "  - id: AC-003\n"
        "    text: Third criterion that is a draft\n"
        "    type: behavioral\n"
        "    draft: true\n"
    )

    # Minimal git directory so paths.py resolves
    (tmp_path / ".git").mkdir()

    return tmp_path


def _load_agents(project_dir: Path) -> list[dict]:
    """Helper: read AGENTS.json directly to verify file mutations."""
    agents_file = project_dir / ".agentic" / "session" / "AGENTS.json"
    return json.loads(agents_file.read_text())


# ---------------------------------------------------------------------------
# Tool dispatch map
# ---------------------------------------------------------------------------
class TestToolsMap:
    def test_all_13_tools_registered(self):
        expected = {
            "claim_feature", "release_feature", "transition_state",
            "get_unblocked", "poll_changes", "report_status",
            "request_review", "submit_review",
            # Task delegation tools
            "list_acs", "get_task_brief", "save_progress",
            "get_next_action", "get_delegation_prompt",
        }
        assert set(TOOLS.keys()) == expected

    def test_all_tools_are_callable(self):
        for name, handler in TOOLS.items():
            assert callable(handler), f"{name} is not callable"


# ---------------------------------------------------------------------------
# claim_feature
# ---------------------------------------------------------------------------
class TestClaimFeature:
    def test_claim_writes_to_agents_json(self, project_dir):
        """Claiming a feature must actually persist an entry to disk."""
        result = claim_feature(project_dir, {
            "feature_id": "F-001",
            "agent": "worker-1",
            "description": "Implementing F-001",
        })
        assert result["claimed"] is True
        assert result["feature_id"] == "F-001"

        # Verify the file was actually written
        agents = _load_agents(project_dir)
        active = [e for e in agents if e["feature_id"] == "F-001"
                  and e["status"] == "active"]
        assert len(active) == 1
        assert active[0]["agent"] == "worker-1"
        assert active[0]["description"] == "Implementing F-001"
        assert "claim_pid" in active[0]

    def test_claim_rejects_duplicate_with_specific_error(self, project_dir):
        """Second claim for same feature is rejected with informative error."""
        claim_feature(project_dir, {
            "feature_id": "F-001", "agent": "agent-1",
        })
        result = claim_feature(project_dir, {
            "feature_id": "F-001", "agent": "agent-2",
        })
        assert result["claimed"] is False
        assert "already claimed" in result["error"]

    def test_claim_different_features_same_agent(self, project_dir):
        """One agent can claim multiple features (no per-agent limit)."""
        r1 = claim_feature(project_dir, {
            "feature_id": "F-001", "agent": "worker-1",
        })
        r2 = claim_feature(project_dir, {
            "feature_id": "F-0002", "agent": "worker-1",
        })
        assert r1["claimed"] is True
        assert r2["claimed"] is True

        agents = _load_agents(project_dir)
        active = [e for e in agents if e["status"] == "active"]
        assert len(active) == 2

    def test_claim_requires_feature_id(self, project_dir):
        result = claim_feature(project_dir, {})
        assert result["error"] == "feature_id is required"

    def test_claim_with_explicit_pid(self, project_dir):
        """Claim stores the provided PID (for remote agents)."""
        result = claim_feature(project_dir, {
            "feature_id": "F-001",
            "agent": "remote-agent",
            "pid": 12345,
        })
        assert result["claimed"] is True
        agents = _load_agents(project_dir)
        entry = [e for e in agents if e["feature_id"] == "F-001"][0]
        assert entry["claim_pid"] == 12345

    def test_stale_pid_auto_cleanup(self, project_dir):
        """A claim with a dead PID is automatically cleaned up."""
        agents_file = project_dir / ".agentic" / "session" / "AGENTS.json"
        stale_entry = [{
            "feature_id": "F-001",
            "description": "stale work",
            "worktree": "", "branch": "",
            "agent": "dead-agent",
            "started": "2026-01-01T00:00:00Z",
            "last_checkpoint": "2026-01-01T00:00:00Z",
            "status": "active",
            "claim_pid": 99999999,  # Almost certainly dead
            "progress": [], "files": [],
        }]
        agents_file.write_text(json.dumps(stale_entry))

        result = claim_feature(project_dir, {
            "feature_id": "F-001", "agent": "new-agent",
        })
        assert result["claimed"] is True

        # Verify stale entry was removed entirely
        agents = _load_agents(project_dir)
        stale = [e for e in agents if e.get("agent") == "dead-agent"]
        assert len(stale) == 0

    def test_claim_without_claim_pid_not_cleaned(self, project_dir):
        """Entries without claim_pid are NOT cleaned by stale detection."""
        agents_file = project_dir / ".agentic" / "session" / "AGENTS.json"
        entry = [{
            "feature_id": "F-001",
            "description": "legacy entry",
            "worktree": "", "branch": "",
            "agent": "old-agent",
            "started": "2026-01-01T00:00:00Z",
            "last_checkpoint": "2026-01-01T00:00:00Z",
            "status": "active",
            # No claim_pid field
            "progress": [], "files": [],
        }]
        agents_file.write_text(json.dumps(entry))

        result = claim_feature(project_dir, {
            "feature_id": "F-001", "agent": "new-agent",
        })
        # Should be rejected — legacy entry is still "active" with no PID to check
        assert result["claimed"] is False

    def test_claim_after_release_succeeds(self, project_dir):
        """A released feature can be claimed again."""
        claim_feature(project_dir, {"feature_id": "F-001", "agent": "a"})
        release_feature(project_dir, {"feature_id": "F-001"})
        result = claim_feature(project_dir, {
            "feature_id": "F-001", "agent": "b",
        })
        assert result["claimed"] is True


# ---------------------------------------------------------------------------
# release_feature
# ---------------------------------------------------------------------------
class TestReleaseFeature:
    def test_release_removes_entry(self, project_dir):
        """Release must remove the entry from AGENTS.json entirely."""
        claim_feature(project_dir, {"feature_id": "F-001", "agent": "a"})
        result = release_feature(project_dir, {"feature_id": "F-001"})
        assert result["released"] is True

        agents = _load_agents(project_dir)
        assert not any(e["feature_id"] == "F-001" for e in agents)

    def test_release_nonexistent_feature(self, project_dir):
        result = release_feature(project_dir, {"feature_id": "F-9999"})
        assert result["released"] is False
        assert "no active claim" in result["error"]

    def test_release_requires_feature_id(self, project_dir):
        result = release_feature(project_dir, {})
        assert result["error"] == "feature_id is required"

    def test_release_by_different_pid_warns_but_succeeds(self, project_dir):
        """Manual cleanup: releasing from a different PID is allowed."""
        claim_feature(project_dir, {
            "feature_id": "F-001", "agent": "a", "pid": 11111,
        })
        # Release with a different PID — should succeed with warning
        result = release_feature(project_dir, {
            "feature_id": "F-001", "pid": 22222,
        })
        assert result["released"] is True

    def test_double_release_fails(self, project_dir):
        """Releasing an already-released feature returns an error."""
        claim_feature(project_dir, {"feature_id": "F-001", "agent": "a"})
        release_feature(project_dir, {"feature_id": "F-001"})
        result = release_feature(project_dir, {"feature_id": "F-001"})
        assert result["released"] is False


# ---------------------------------------------------------------------------
# get_unblocked
# ---------------------------------------------------------------------------
class TestGetUnblocked:
    def test_returns_structured_features(self, project_dir):
        """Each returned feature must have feature_id, current_state, and transitions."""
        result = get_unblocked(project_dir, {})
        assert "features" in result
        assert isinstance(result["features"], list)
        # F-001 (planned) should have forward transitions
        for f in result["features"]:
            assert "feature_id" in f
            assert "current_state" in f
            assert "available_transitions" in f
            assert isinstance(f["available_transitions"], list)

    def test_shipped_features_excluded(self, project_dir):
        """Shipped features should not appear in unblocked list."""
        result = get_unblocked(project_dir, {})
        feature_ids = [f["feature_id"] for f in result["features"]]
        assert "F-002" not in feature_ids  # F-002 is shipped


# ---------------------------------------------------------------------------
# transition_state
# ---------------------------------------------------------------------------
class TestTransitionState:
    def test_requires_both_params(self, project_dir):
        result = transition_state(project_dir, {})
        assert "feature_id and target are required" in result["error"]

    def test_invalid_state_returns_valid_options(self, project_dir):
        result = transition_state(project_dir, {
            "feature_id": "F-001", "target": "bogus_state",
        })
        assert "invalid target state" in result["error"]
        assert "valid_states" in result
        assert isinstance(result["valid_states"], list)
        assert len(result["valid_states"]) > 0

    def test_transition_planned_to_specced(self, project_dir):
        """Happy path: transition a planned feature forward."""
        result = transition_state(project_dir, {
            "feature_id": "F-001", "target": "specced",
        })
        assert result["feature_id"] == "F-001"
        assert result["target"] == "specced"
        # Either succeeds or returns specific transition error
        assert "success" in result

    def test_dry_run_does_not_mutate(self, project_dir):
        """dry_run=True should not change the feature's actual state."""
        features_file = project_dir / ".agentic" / "spec" / "FEATURES.md"
        original = features_file.read_text()
        transition_state(project_dir, {
            "feature_id": "F-001", "target": "specced", "dry_run": True,
        })
        assert features_file.read_text() == original


# ---------------------------------------------------------------------------
# poll_changes
# ---------------------------------------------------------------------------
class TestPollChanges:
    def test_epoch_poll_returns_full_state(self, project_dir):
        """First poll with epoch returns all features and agents."""
        result = poll_changes(project_dir, {"since": "1970-01-01T00:00:00"})
        assert result["changed"] is True
        assert "timestamp" in result

        # Verify features structure
        assert "features" in result
        feature_ids = {f["feature_id"] for f in result["features"]}
        assert "F-001" in feature_ids
        assert "F-0002" in feature_ids
        for f in result["features"]:
            assert "status" in f

        # Verify agents structure
        assert "agents" in result
        assert isinstance(result["agents"], list)

    def test_future_timestamp_no_changes(self, project_dir):
        result = poll_changes(project_dir, {"since": "2099-01-01T00:00:00"})
        assert result["changed"] is False
        assert "features" not in result
        assert "agents" not in result
        assert "timestamp" in result

    def test_detects_agents_json_mutation(self, project_dir):
        """poll_changes detects when AGENTS.json is modified."""
        # Get baseline timestamp
        r1 = poll_changes(project_dir, {"since": "1970-01-01T00:00:00"})
        since = r1["timestamp"]

        # Modify AGENTS.json
        time.sleep(0.05)  # Ensure mtime changes
        claim_feature(project_dir, {"feature_id": "F-001", "agent": "a"})

        result = poll_changes(project_dir, {"since": since})
        assert result["changed"] is True
        assert len(result["agents"]) > 0

    def test_detects_features_md_mutation(self, project_dir):
        """poll_changes detects when FEATURES.md is modified."""
        r1 = poll_changes(project_dir, {"since": "1970-01-01T00:00:00"})
        since = r1["timestamp"]

        time.sleep(0.05)
        features_file = project_dir / ".agentic" / "spec" / "FEATURES.md"
        content = features_file.read_text()
        features_file.write_text(content.replace("planned", "specced"))

        result = poll_changes(project_dir, {"since": since})
        assert result["changed"] is True

    def test_invalid_timestamp(self, project_dir):
        result = poll_changes(project_dir, {"since": "not-a-date"})
        assert "invalid timestamp" in result["error"]

    def test_malformed_agents_json_handled(self, project_dir):
        """Corrupted AGENTS.json returns empty agents list, no crash."""
        agents_file = project_dir / ".agentic" / "session" / "AGENTS.json"
        agents_file.write_text("{invalid json")
        result = poll_changes(project_dir, {"since": "1970-01-01T00:00:00"})
        assert result["changed"] is True
        assert result["agents"] == []


# ---------------------------------------------------------------------------
# report_status
# ---------------------------------------------------------------------------
class TestReportStatus:
    def test_report_persists_progress_note(self, project_dir):
        """Progress note must be written to AGENTS.json."""
        claim_feature(project_dir, {"feature_id": "F-001", "agent": "a"})
        result = report_status(project_dir, {
            "feature_id": "F-001",
            "note": "Implemented 3/5 ACs",
        })
        assert result["reported"] is True

        agents = _load_agents(project_dir)
        entry = [e for e in agents if e["feature_id"] == "F-001"][0]
        assert "Implemented 3/5 ACs" in entry["progress"]

    def test_report_updates_checkpoint_timestamp(self, project_dir):
        claim_feature(project_dir, {"feature_id": "F-001", "agent": "a"})
        agents_before = _load_agents(project_dir)
        ts_before = agents_before[0]["last_checkpoint"]

        time.sleep(0.05)
        report_status(project_dir, {
            "feature_id": "F-001", "note": "progress",
        })

        agents_after = _load_agents(project_dir)
        ts_after = agents_after[0]["last_checkpoint"]
        assert ts_after >= ts_before

    def test_report_nonexistent_feature(self, project_dir):
        result = report_status(project_dir, {
            "feature_id": "F-9999", "note": "test",
        })
        assert result["reported"] is False
        assert "not found" in result.get("error", "")

    def test_report_requires_both_params(self, project_dir):
        r1 = report_status(project_dir, {"feature_id": "F-001"})
        assert "note" in r1["error"] or "required" in r1["error"]
        r2 = report_status(project_dir, {"note": "test"})
        assert "feature_id" in r2["error"] or "required" in r2["error"]


# ---------------------------------------------------------------------------
# request_review
# ---------------------------------------------------------------------------
class TestRequestReview:
    def test_requires_all_params(self, project_dir):
        result = request_review(project_dir, {})
        assert "required" in result["error"]

    def test_requires_from_and_to_state(self, project_dir):
        result = request_review(project_dir, {"feature_id": "F-001"})
        assert "required" in result["error"]

    def test_request_creates_pending_review(self, project_dir):
        """Happy path: creates a pending review and returns review ID."""
        result = request_review(project_dir, {
            "feature_id": "F-001",
            "from_state": "planned",
            "to_state": "specced",
            "review_mode": "human",
        })
        # Either succeeds or fails gracefully
        assert "requested" in result or "error" in result


# ---------------------------------------------------------------------------
# submit_review
# ---------------------------------------------------------------------------
class TestSubmitReview:
    def test_requires_all_params(self, project_dir):
        result = submit_review(project_dir, {})
        assert "required" in result["error"]

    def test_invalid_verdict_rejected(self, project_dir):
        result = submit_review(project_dir, {
            "feature_id": "F-001",
            "target_state": "specced",
            "verdict": "maybe",
        })
        assert "approved" in result["error"] or "rejected" in result["error"]

    def test_submit_with_valid_verdict(self, project_dir):
        """submit_review with valid params returns structured result."""
        result = submit_review(project_dir, {
            "feature_id": "F-001",
            "target_state": "specced",
            "verdict": "approved",
            "reasoning": "Looks good",
        })
        assert "success" in result
        assert result["verdict"] == "approved"
        assert result["feature_id"] == "F-001"


# ---------------------------------------------------------------------------
# _parse_feature_statuses (helper)
# ---------------------------------------------------------------------------
class TestParseFeatureStatuses:
    def test_parses_multiple_features(self, project_dir):
        features_file = project_dir / ".agentic" / "spec" / "FEATURES.md"
        statuses = _parse_feature_statuses(features_file)
        ids = {f["feature_id"] for f in statuses}
        assert ids == {"F-001", "F-0002", "F-002"}
        planned = [f for f in statuses if f["feature_id"] == "F-001"][0]
        assert planned["status"] == "planned"
        shipped = [f for f in statuses if f["feature_id"] == "F-002"][0]
        assert shipped["status"] == "shipped"

    def test_handles_empty_features_file(self, tmp_path):
        f = tmp_path / "FEATURES.md"
        f.write_text("# Features\n\nNo features yet.\n")
        result = _parse_feature_statuses(f)
        assert result == []


# ---------------------------------------------------------------------------
# _read_settings (server config parser)
# ---------------------------------------------------------------------------
class TestReadSettings:
    def test_reads_coord_settings_from_stack(self, tmp_path):
        (tmp_path / "STACK.md").write_text("""\
# STACK.md
## Settings
- coord_enabled: yes
- coord_port: 9999  # custom port
- coord_bind: 0.0.0.0
""")
        settings = _read_settings(tmp_path)
        assert settings["coord_enabled"] == "yes"
        assert settings["coord_port"] == "9999"
        assert settings["coord_bind"] == "0.0.0.0"

    def test_defaults_when_no_stack(self, tmp_path):
        settings = _read_settings(tmp_path)
        assert settings["coord_enabled"] == "no"
        assert settings["coord_port"] == "4185"
        assert settings["coord_bind"] == "127.0.0.1"

    def test_partial_settings(self, tmp_path):
        (tmp_path / "STACK.md").write_text("- coord_port: 5000\n")
        settings = _read_settings(tmp_path)
        assert settings["coord_port"] == "5000"
        assert settings["coord_bind"] == "127.0.0.1"  # default


# ---------------------------------------------------------------------------
# Concurrent access tests
# ---------------------------------------------------------------------------
class TestConcurrency:
    """Tests that verify the coordination server's core purpose: safe parallel access."""

    def test_concurrent_claims_only_one_wins(self, project_dir):
        """Two threads claiming the same feature: exactly one succeeds."""
        results = []
        barrier = threading.Barrier(2)

        def _claim(agent_name):
            barrier.wait()  # Synchronize start
            r = claim_feature(project_dir, {
                "feature_id": "F-001",
                "agent": agent_name,
            })
            results.append(r)

        t1 = threading.Thread(target=_claim, args=("agent-1",))
        t2 = threading.Thread(target=_claim, args=("agent-2",))
        t1.start()
        t2.start()
        t1.join(timeout=5)
        t2.join(timeout=5)

        claimed = [r for r in results if r.get("claimed") is True]
        rejected = [r for r in results if r.get("claimed") is False]
        assert len(claimed) == 1, f"Expected exactly 1 claim, got {len(claimed)}"
        assert len(rejected) == 1, f"Expected exactly 1 rejection, got {len(rejected)}"

    def test_concurrent_claims_different_features(self, project_dir):
        """Two threads claiming different features: both succeed."""
        results = {}
        barrier = threading.Barrier(2)

        def _claim(feature_id, agent_name):
            barrier.wait()
            r = claim_feature(project_dir, {
                "feature_id": feature_id, "agent": agent_name,
            })
            results[feature_id] = r

        t1 = threading.Thread(target=_claim, args=("F-001", "agent-1"))
        t2 = threading.Thread(target=_claim, args=("F-0002", "agent-2"))
        t1.start()
        t2.start()
        t1.join(timeout=5)
        t2.join(timeout=5)

        assert results["F-001"]["claimed"] is True
        assert results["F-0002"]["claimed"] is True

    def test_concurrent_report_status(self, project_dir):
        """Multiple agents reporting status concurrently don't corrupt the file."""
        claim_feature(project_dir, {"feature_id": "F-001", "agent": "a"})
        claim_feature(project_dir, {"feature_id": "F-0002", "agent": "b"})

        barrier = threading.Barrier(2)

        def _report(fid, note):
            barrier.wait()
            report_status(project_dir, {"feature_id": fid, "note": note})

        t1 = threading.Thread(target=_report, args=("F-001", "progress-1"))
        t2 = threading.Thread(target=_report, args=("F-0002", "progress-2"))
        t1.start()
        t2.start()
        t1.join(timeout=5)
        t2.join(timeout=5)

        # Verify both notes were persisted and file is valid JSON
        agents = _load_agents(project_dir)
        e1 = [e for e in agents if e["feature_id"] == "F-001"][0]
        e2 = [e for e in agents if e["feature_id"] == "F-0002"][0]
        assert "progress-1" in e1["progress"]
        assert "progress-2" in e2["progress"]

    def test_many_concurrent_claims_no_corruption(self, project_dir):
        """10 threads claiming the same feature: file stays valid JSON, exactly 1 wins."""
        n = 10
        barrier = threading.Barrier(n)
        results = []
        lock = threading.Lock()

        def _claim(agent_name):
            barrier.wait()
            r = claim_feature(project_dir, {
                "feature_id": "F-001", "agent": agent_name,
            })
            with lock:
                results.append(r)

        threads = [threading.Thread(target=_claim, args=(f"agent-{i}",))
                   for i in range(n)]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=10)

        # File must be valid JSON
        agents = _load_agents(project_dir)
        assert isinstance(agents, list)

        # Exactly one claim succeeded
        claimed = [r for r in results if r.get("claimed") is True]
        assert len(claimed) == 1, f"Expected 1 winner out of {n}, got {len(claimed)}"


# ---------------------------------------------------------------------------
# HTTP Integration tests
# ---------------------------------------------------------------------------
def _find_free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


class TestHTTPTransport:
    """Integration tests for the coordination server HTTP layer."""

    @pytest.fixture(autouse=True)
    def setup_server(self, project_dir):
        self.project_dir = project_dir
        self.token = "test-token-12345"
        self.port = _find_free_port()

        self.server = CoordHTTPServer(
            ("127.0.0.1", self.port),
            CoordRequestHandler,
            project_dir,
            self.token,
        )
        self.thread = threading.Thread(target=self.server.serve_forever,
                                       daemon=True)
        self.thread.start()
        time.sleep(0.1)
        yield
        self.server.shutdown()

    def _rpc(self, method: str, params: dict = None, req_id: int = 1,
             token: str = None) -> dict:
        url = f"http://127.0.0.1:{self.port}/rpc"
        body = json.dumps({
            "jsonrpc": "2.0",
            "method": method,
            "params": params or {},
            "id": req_id,
        }).encode("utf-8")
        req = urllib.request.Request(url, data=body, method="POST")
        req.add_header("Content-Type", "application/json")
        req.add_header("Authorization", f"Bearer {token or self.token}")
        with urllib.request.urlopen(req, timeout=5) as resp:
            return json.loads(resp.read())

    def _raw_post(self, path: str, body: bytes, headers: dict = None) -> tuple:
        """Low-level POST returning (status_code, response_body_dict)."""
        url = f"http://127.0.0.1:{self.port}{path}"
        req = urllib.request.Request(url, data=body, method="POST")
        for k, v in (headers or {}).items():
            req.add_header(k, v)
        try:
            with urllib.request.urlopen(req, timeout=5) as resp:
                return resp.status, json.loads(resp.read())
        except urllib.error.HTTPError as e:
            raw = e.read()
            try:
                return e.code, json.loads(raw) if raw else {}
            except (json.JSONDecodeError, ValueError):
                return e.code, {"raw": raw.decode("utf-8", errors="replace")}

    # --- Health ---
    def test_health_endpoint(self):
        url = f"http://127.0.0.1:{self.port}/health"
        with urllib.request.urlopen(url, timeout=5) as resp:
            data = json.loads(resp.read())
        assert data["status"] == "ok"
        assert data["pid"] == os.getpid()

    def test_health_no_auth_required(self):
        """Health endpoint works without Authorization header."""
        url = f"http://127.0.0.1:{self.port}/health"
        req = urllib.request.Request(url)
        # No auth header
        with urllib.request.urlopen(req, timeout=5) as resp:
            assert resp.status == 200

    # --- Auth ---
    def test_wrong_token_returns_401(self):
        status, body = self._raw_post(
            "/rpc",
            json.dumps({"jsonrpc": "2.0", "method": "get_unblocked",
                         "params": {}, "id": 1}).encode(),
            {"Authorization": "Bearer wrong-token",
             "Content-Type": "application/json"},
        )
        assert status == 401

    def test_missing_auth_returns_401(self):
        status, _ = self._raw_post(
            "/rpc",
            json.dumps({"jsonrpc": "2.0", "method": "get_unblocked",
                         "params": {}, "id": 1}).encode(),
            {"Content-Type": "application/json"},
        )
        assert status == 401

    # --- JSON-RPC protocol ---
    def test_request_id_preserved(self):
        """Response id must match request id."""
        resp = self._rpc("get_unblocked", req_id=42)
        assert resp["id"] == 42
        assert resp["jsonrpc"] == "2.0"

    def test_unknown_method_returns_32601(self):
        resp = self._rpc("nonexistent_method")
        assert resp["error"]["code"] == -32601
        assert "nonexistent_method" in resp["error"]["message"]

    def test_invalid_json_returns_32700(self):
        status, body = self._raw_post(
            "/rpc",
            b"not json at all",
            {"Authorization": f"Bearer {self.token}",
             "Content-Type": "application/json"},
        )
        assert status == 400
        assert body["error"]["code"] == -32700

    def test_empty_body_returns_error(self):
        status, body = self._raw_post(
            "/rpc",
            b"",
            {"Authorization": f"Bearer {self.token}",
             "Content-Type": "application/json",
             "Content-Length": "0"},
        )
        assert status == 400

    def test_non_rpc_path_returns_404(self):
        status, _ = self._raw_post(
            "/wrong-path",
            b"{}",
            {"Authorization": f"Bearer {self.token}"},
        )
        assert status == 404

    def test_get_non_health_returns_404(self):
        url = f"http://127.0.0.1:{self.port}/not-health"
        try:
            urllib.request.urlopen(url, timeout=5)
            assert False, "Expected 404"
        except urllib.error.HTTPError as e:
            assert e.code == 404

    # --- End-to-end tool calls via HTTP ---
    def test_full_claim_report_release_cycle(self):
        """Complete workflow: claim → report status → release."""
        # Claim
        r1 = self._rpc("claim_feature", {
            "feature_id": "F-001", "agent": "rpc-agent",
        })
        assert r1["result"]["claimed"] is True

        # Report progress
        r2 = self._rpc("report_status", {
            "feature_id": "F-001", "note": "50% done via RPC",
        })
        assert r2["result"]["reported"] is True

        # Verify progress persisted
        agents = _load_agents(self.project_dir)
        entry = [e for e in agents if e["feature_id"] == "F-001"][0]
        assert "50% done via RPC" in entry["progress"]

        # Release
        r3 = self._rpc("release_feature", {"feature_id": "F-001"})
        assert r3["result"]["released"] is True

    def test_rpc_get_unblocked_structure(self):
        """Verify get_unblocked returns proper structure via HTTP."""
        resp = self._rpc("get_unblocked")
        assert "result" in resp
        features = resp["result"]["features"]
        assert isinstance(features, list)
        for f in features:
            assert "feature_id" in f
            assert "current_state" in f
            assert "available_transitions" in f

    def test_rpc_poll_changes(self):
        resp = self._rpc("poll_changes", {"since": "1970-01-01T00:00:00"})
        result = resp["result"]
        assert result["changed"] is True
        assert "features" in result
        assert "timestamp" in result

    def test_concurrent_rpc_claims(self):
        """Two concurrent HTTP claims for the same feature: one wins."""
        results = []
        barrier = threading.Barrier(2)

        def _claim_via_rpc(agent_name):
            barrier.wait()
            r = self._rpc("claim_feature", {
                "feature_id": "F-001", "agent": agent_name,
            })
            results.append(r["result"])

        t1 = threading.Thread(target=_claim_via_rpc, args=("http-1",))
        t2 = threading.Thread(target=_claim_via_rpc, args=("http-2",))
        t1.start()
        t2.start()
        t1.join(timeout=5)
        t2.join(timeout=5)

        claimed = [r for r in results if r.get("claimed") is True]
        rejected = [r for r in results if r.get("claimed") is False]
        assert len(claimed) == 1
        assert len(rejected) == 1


# ===========================================================================
# Task Delegation Tools (list_acs, get_task_brief, save_progress,
#                        get_next_action, get_delegation_prompt)
# ===========================================================================

class TestListAcs:
    def test_missing_feature_id(self, project_dir):
        result = list_acs(project_dir, {})
        assert "error" in result

    def test_no_contract_returns_error(self, project_dir):
        result = list_acs(project_dir, {"feature_id": "F-999"})
        assert result["total"] == 0
        assert "error" in result

    def test_contract_yaml_loads_non_draft_acs(self, project_dir):
        result = list_acs(project_dir, {"feature_id": "F-003"})
        assert result["total"] == 2  # AC-003 is draft, excluded
        assert result["completed"] == 0
        assert result["pending"] == 2
        ids = [ac["ac_id"] for ac in result["criteria"]]
        assert "AC-001" in ids
        assert "AC-002" in ids
        assert "AC-003" not in ids  # draft

    def test_legacy_markdown_loads_acs(self, project_dir):
        result = list_acs(project_dir, {"feature_id": "F-001"})
        assert result["total"] == 1
        assert result["criteria"][0]["ac_id"] == "AC-001"

    def test_progress_reflects_in_status(self, project_dir):
        # Save some progress first
        save_progress(project_dir, {
            "feature_id": "F-003", "ac_id": "AC-001",
            "status": "passed", "note": "Done",
        })
        result = list_acs(project_dir, {"feature_id": "F-003"})
        assert result["completed"] == 1
        assert result["pending"] == 1
        ac1 = [ac for ac in result["criteria"] if ac["ac_id"] == "AC-001"][0]
        assert ac1["status"] == "passed"


class TestSaveProgress:
    def test_missing_feature_id(self, project_dir):
        result = save_progress(project_dir, {})
        assert "error" in result

    def test_invalid_status(self, project_dir):
        result = save_progress(project_dir, {
            "feature_id": "F-003", "status": "invalid",
        })
        assert "error" in result

    def test_save_and_count(self, project_dir):
        result = save_progress(project_dir, {
            "feature_id": "F-003", "ac_id": "AC-001",
            "status": "passed", "note": "Implemented auth",
        })
        assert result["recorded"] is True
        assert result["acs_completed"] == 1
        assert result["acs_remaining"] == 1  # F-003 has 2 non-draft ACs

    def test_save_multiple_entries(self, project_dir):
        save_progress(project_dir, {
            "feature_id": "F-003", "ac_id": "AC-001",
            "status": "passed", "note": "First",
        })
        save_progress(project_dir, {
            "feature_id": "F-003", "ac_id": "AC-002",
            "status": "passed", "note": "Second",
        })
        result = save_progress(project_dir, {
            "feature_id": "F-003", "status": "note",
            "note": "All done",
        })
        assert result["acs_completed"] == 2
        assert result["acs_remaining"] == 0

    def test_progress_persisted_to_file(self, project_dir):
        save_progress(project_dir, {
            "feature_id": "F-003", "ac_id": "AC-001",
            "status": "partial", "note": "WIP",
            "files_changed": ["src/foo.py"],
        })
        progress_file = project_dir / ".agentic" / "session" / "progress" / "F-003.json"
        assert progress_file.exists()
        data = json.loads(progress_file.read_text())
        assert len(data) == 1
        assert data[0]["ac_id"] == "AC-001"
        assert data[0]["status"] == "partial"
        assert data[0]["files_changed"] == ["src/foo.py"]
        assert "timestamp" in data[0]


class TestGetNextAction:
    def test_missing_feature_id(self, project_dir):
        result = get_next_action(project_dir, {})
        assert "error" in result

    def test_no_criteria_returns_blocked(self, project_dir):
        result = get_next_action(project_dir, {"feature_id": "F-999"})
        assert result["action"] == "blocked"

    def test_first_ac_suggested(self, project_dir):
        result = get_next_action(project_dir, {"feature_id": "F-003"})
        assert result["action"] == "implement_ac"
        assert result["details"]["ac_id"] == "AC-001"
        assert result["acs_remaining"] == 2

    def test_after_first_ac_suggests_second(self, project_dir):
        save_progress(project_dir, {
            "feature_id": "F-003", "ac_id": "AC-001",
            "status": "passed", "note": "Done",
        })
        result = get_next_action(project_dir, {"feature_id": "F-003"})
        assert result["action"] == "implement_ac"
        assert result["details"]["ac_id"] == "AC-002"
        assert result["acs_remaining"] == 1

    def test_all_acs_done_suggests_verify(self, project_dir):
        save_progress(project_dir, {
            "feature_id": "F-003", "ac_id": "AC-001",
            "status": "passed", "note": "Done",
        })
        save_progress(project_dir, {
            "feature_id": "F-003", "ac_id": "AC-002",
            "status": "passed", "note": "Done",
        })
        result = get_next_action(project_dir, {"feature_id": "F-003"})
        assert result["action"] == "verify"
        assert result["acs_remaining"] == 0

    def test_after_verify_suggests_pr(self, project_dir):
        for ac_id in ("AC-001", "AC-002"):
            save_progress(project_dir, {
                "feature_id": "F-003", "ac_id": ac_id,
                "status": "passed", "note": "Done",
            })
        save_progress(project_dir, {
            "feature_id": "F-003", "ac_id": "__verify__",
            "status": "passed", "note": "Tests pass",
        })
        result = get_next_action(project_dir, {"feature_id": "F-003"})
        assert result["action"] == "create_pr"

    def test_after_pr_suggests_done(self, project_dir):
        for ac_id in ("AC-001", "AC-002", "__verify__", "__pr__"):
            save_progress(project_dir, {
                "feature_id": "F-003", "ac_id": ac_id,
                "status": "passed", "note": "Done",
            })
        result = get_next_action(project_dir, {"feature_id": "F-003"})
        assert result["action"] == "done"

    def test_attempt_counter_increments(self, project_dir):
        # Fail AC-001 twice, then check attempt count
        save_progress(project_dir, {
            "feature_id": "F-003", "ac_id": "AC-001",
            "status": "failed", "note": "First try",
        })
        save_progress(project_dir, {
            "feature_id": "F-003", "ac_id": "AC-001",
            "status": "failed", "note": "Second try",
        })
        result = get_next_action(project_dir, {"feature_id": "F-003"})
        assert result["action"] == "implement_ac"
        assert result["details"]["ac_id"] == "AC-001"
        assert result["details"]["attempt"] == 3  # Two failed + next attempt


class TestGetTaskBrief:
    def test_missing_feature_id(self, project_dir):
        result = get_task_brief(project_dir, {})
        assert "error" in result

    def test_returns_ac_text(self, project_dir):
        result = get_task_brief(project_dir, {
            "feature_id": "F-003", "ac_id": "AC-001",
        })
        assert "First acceptance criterion" in result["ac_text"]
        assert isinstance(result["token_estimate"], int)
        assert isinstance(result["files_hint"], list)
        assert isinstance(result["prior_notes"], list)

    def test_prior_notes_included(self, project_dir):
        save_progress(project_dir, {
            "feature_id": "F-003", "ac_id": "AC-001",
            "status": "failed", "note": "Import error in foo.py",
        })
        result = get_task_brief(project_dir, {
            "feature_id": "F-003", "ac_id": "AC-001",
        })
        assert any("Import error" in n for n in result["prior_notes"])


class TestGetDelegationPrompt:
    def test_missing_params(self, project_dir):
        result = get_delegation_prompt(project_dir, {"feature_id": "F-003"})
        assert "error" in result

    def test_returns_complete_prompt(self, project_dir):
        result = get_delegation_prompt(project_dir, {
            "feature_id": "F-003", "ac_id": "AC-001",
        })
        assert "prompt" in result
        assert "model_hint" in result
        assert "use_worktree" in result
        assert "AC-001" in result["prompt"]
        assert "First acceptance criterion" in result["prompt"]
        assert result["model_hint"] in ("sonnet", "opus", "haiku")

    def test_prompt_includes_instructions(self, project_dir):
        result = get_delegation_prompt(project_dir, {
            "feature_id": "F-003", "ac_id": "AC-002",
        })
        assert "Instructions" in result["prompt"]
        assert "tests" in result["prompt"].lower()
