#!/usr/bin/env python3
"""
Tests for the autonomous workflow engine: control socket, settings generation,
AC decomposition for large criteria.
"""
import json
import os
import socket
import sys
import tempfile
import threading
import time
from pathlib import Path

import pytest

# Add lib/ to path
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "auto"))

from auto import build_claude_cmd
from auto.engine import AutoEngine, ControlServer, EngineState
from auto.control import send_command, format_status
from auto.init import detect_stack, generate_settings


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def project_dir():
    """Create a minimal project directory with required structure."""
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        (root / ".agentic").mkdir()
        (root / ".agentic" / "lib").mkdir()
        (root / ".agentic" / "session").mkdir()
        (root / ".agentic" / "spec" / "acceptance").mkdir(parents=True)
        (root / "STACK.md").write_text(
            "## Settings\n- profile: formal\n\n"
            "## Languages & runtimes\n- Language(s): Python, Bash\n\n"
            "## Tooling\n- Package manager: pip\n"
        )
        # Symlink paths.py so imports work
        lib_src = Path(__file__).parent.parent / ".agentic" / "lib"
        for f in ["paths.py", "settings.py", "paths.sh", "settings.sh"]:
            src = lib_src / f
            if src.exists():
                dst = root / ".agentic" / "lib" / f
                dst.write_text(src.read_text())
        yield root


@pytest.fixture
def engine_state():
    return EngineState()


# ---------------------------------------------------------------------------
# EngineState tests
# ---------------------------------------------------------------------------

class TestEngineState:
    def test_initial_state(self, engine_state):
        assert engine_state.state == "idle"
        assert engine_state.current_ac is None

    def test_state_transitions(self, engine_state):
        engine_state.state = "running"
        assert engine_state.state == "running"
        engine_state.state = "paused"
        assert engine_state.state == "paused"

    def test_ac_progress(self, engine_state):
        engine_state.set_ac_status("AC-001", "in_progress")
        engine_state.set_ac_status("AC-002", "passed")
        state = engine_state.to_dict()
        assert state["progress"]["AC-001"] == "in_progress"
        assert state["progress"]["AC-002"] == "passed"

    def test_feedback_queue(self, engine_state):
        engine_state.add_feedback("AC-001", "use existing auth")
        engine_state.add_feedback("AC-001", "also add rate limiting")
        engine_state.add_feedback("AC-002", "different AC")

        # Get feedback for AC-001 (should drain those entries)
        fb = engine_state.get_pending_feedback("AC-001")
        assert len(fb) == 2
        assert fb[0]["text"] == "use existing auth"

        # AC-002 feedback still there
        fb2 = engine_state.get_pending_feedback("AC-002")
        assert len(fb2) == 1

        # AC-001 now empty
        fb3 = engine_state.get_pending_feedback("AC-001")
        assert len(fb3) == 0

    def test_decomposition_tracking(self, engine_state):
        sub_tasks = [
            {"id": "AC-003.1", "text": "set up schema", "status": "pending"},
            {"id": "AC-003.2", "text": "implement endpoint", "status": "pending"},
        ]
        engine_state.record_decomposition("AC-003", sub_tasks)
        state = engine_state.to_dict()
        assert "AC-003" in state["decomposed"]
        assert len(state["decomposed"]["AC-003"]) == 2

    def test_subtask_status_update(self, engine_state):
        sub_tasks = [
            {"id": "AC-001.1", "text": "step 1", "status": "pending"},
            {"id": "AC-001.2", "text": "step 2", "status": "pending"},
        ]
        engine_state.record_decomposition("AC-001", sub_tasks)
        engine_state.set_subtask_status("AC-001", 0, "passed")
        engine_state.set_subtask_status("AC-001", 1, "in_progress")
        state = engine_state.to_dict()
        assert state["decomposed"]["AC-001"][0]["status"] == "passed"
        assert state["decomposed"]["AC-001"][1]["status"] == "in_progress"

    def test_thread_safety(self, engine_state):
        """Concurrent state modifications should not corrupt data."""
        errors = []

        def writer(ac_prefix, count):
            try:
                for i in range(count):
                    engine_state.set_ac_status(f"{ac_prefix}-{i:03d}", "passed")
                    engine_state.add_feedback(f"{ac_prefix}-{i:03d}", f"note {i}")
            except Exception as e:
                errors.append(e)

        threads = [threading.Thread(target=writer, args=(f"T{t}", 50)) for t in range(4)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

        assert len(errors) == 0
        state = engine_state.to_dict()
        assert len(state["progress"]) == 200  # 4 threads x 50 ACs


# ---------------------------------------------------------------------------
# ControlServer tests
# ---------------------------------------------------------------------------

class TestControlServer:
    def test_socket_lifecycle(self, engine_state):
        """Server creates socket, handles commands, cleans up."""
        with tempfile.TemporaryDirectory() as tmpdir:
            sock_path = Path(tmpdir) / "test.sock"
            server = ControlServer(sock_path, engine_state)
            engine_state.state = "running"

            server.start()
            assert sock_path.exists()

            # Send a pause command
            response = send_command(sock_path, {"cmd": "pause"})
            assert response["ack"] is True
            assert response["state"] == "paused"
            assert engine_state.state == "paused"

            # Resume
            response = send_command(sock_path, {"cmd": "resume"})
            assert response["ack"] is True
            assert response["state"] == "running"

            # Status
            response = send_command(sock_path, {"cmd": "status"})
            assert response["ack"] is True
            assert response["state"] == "running"

            # Stop
            response = send_command(sock_path, {"cmd": "stop"})
            assert response["ack"] is True
            assert response["state"] == "stopping"

            server.stop()
            assert not sock_path.exists()

    def test_feedback_via_socket(self, engine_state):
        """Feedback command queues feedback for an AC."""
        with tempfile.TemporaryDirectory() as tmpdir:
            sock_path = Path(tmpdir) / "test.sock"
            server = ControlServer(sock_path, engine_state)
            engine_state.state = "running"
            server.start()

            response = send_command(sock_path, {
                "cmd": "feedback",
                "ac": "AC-003",
                "text": "use the existing auth module",
            })
            assert response["ack"] is True
            assert response["queued"] is True

            # Verify feedback was stored
            fb = engine_state.get_pending_feedback("AC-003")
            assert len(fb) == 1
            assert fb[0]["text"] == "use the existing auth module"

            server.stop()

    def test_invalid_json(self, engine_state):
        """Server handles malformed input gracefully."""
        with tempfile.TemporaryDirectory() as tmpdir:
            sock_path = Path(tmpdir) / "test.sock"
            server = ControlServer(sock_path, engine_state)
            server.start()

            # Send raw garbage
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            sock.connect(str(sock_path))
            sock.sendall(b"not json\n")
            data = sock.recv(4096)
            sock.close()

            response = json.loads(data.decode().strip())
            assert response["ack"] is False
            assert "invalid JSON" in response["error"]

            server.stop()

    def test_unknown_command(self, engine_state):
        """Unknown commands get an error response."""
        with tempfile.TemporaryDirectory() as tmpdir:
            sock_path = Path(tmpdir) / "test.sock"
            server = ControlServer(sock_path, engine_state)
            server.start()

            response = send_command(sock_path, {"cmd": "explode"})
            assert response["ack"] is False
            assert "unknown command" in response["error"]

            server.stop()

    def test_stale_socket_cleanup(self, engine_state):
        """Stale socket from a dead process is cleaned up automatically."""
        with tempfile.TemporaryDirectory() as tmpdir:
            sock_path = Path(tmpdir) / "test.sock"
            # Create a stale socket file (just a regular file, not a real socket)
            sock_path.write_text("stale")

            # ControlServer should detect it's stale and remove it
            server = ControlServer(sock_path, engine_state)
            server.start()
            assert sock_path.exists()  # New socket created
            server.stop()

    def test_no_socket_returns_error(self):
        """send_command with no socket returns error dict."""
        result = send_command(Path("/nonexistent/test.sock"), {"cmd": "status"})
        assert "error" in result
        assert "not running" in result["error"]


# ---------------------------------------------------------------------------
# Settings generation tests (init.py)
# ---------------------------------------------------------------------------

class TestSettingsGeneration:
    def test_detect_stack_python(self, project_dir):
        stack = detect_stack(project_dir)
        assert stack["package_manager"] == "pip"
        assert "python" in stack["languages"]
        assert "bash" in stack["languages"]

    def test_detect_stack_missing_file(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / ".agentic" / "lib").mkdir(parents=True)
            # Copy paths.py for import
            lib_src = Path(__file__).parent.parent / ".agentic" / "lib"
            for f in ["paths.py", "settings.py"]:
                src = lib_src / f
                if src.exists():
                    (root / ".agentic" / "lib" / f).write_text(src.read_text())
            stack = detect_stack(root)
            assert stack["package_manager"] is None
            assert stack["languages"] == []

    def test_generate_tier1(self, project_dir):
        settings = generate_settings(project_dir, tier=1)
        assert settings["_comment"].startswith("Tier 1")
        assert "*" in settings["permissions"]["allow"]

    def test_generate_tier2_includes_stack_rules(self, project_dir):
        settings = generate_settings(project_dir, tier=2)
        assert settings["_tier"] == 2
        allow = settings["permissions"]["allow"]
        # Should include Python-specific rules from stack detection
        assert any("python" in r for r in allow)
        assert any("pytest" in r for r in allow)
        # Should include pip rules
        assert any("pip" in r for r in allow)
        # Should include base rules
        assert "Read" in allow
        assert "Edit" in allow
        assert "Glob" in allow

    def test_generate_tier2_denies_dangerous(self, project_dir):
        settings = generate_settings(project_dir, tier=2)
        deny = settings["permissions"]["deny"]
        assert any("rm -rf" in r for r in deny)
        assert any("sudo" in r for r in deny)

    def test_generate_tier3(self, project_dir):
        settings = generate_settings(project_dir, tier=3)
        assert settings["_comment"].startswith("Tier 3")
        assert settings["permissions"]["allow"] == []

    def test_npm_stack(self):
        """Settings include npm rules when STACK.md says npm."""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / ".agentic" / "lib").mkdir(parents=True)
            lib_src = Path(__file__).parent.parent / ".agentic" / "lib"
            for f in ["paths.py", "settings.py"]:
                src = lib_src / f
                if src.exists():
                    (root / ".agentic" / "lib" / f).write_text(src.read_text())
            (root / "STACK.md").write_text(
                "## Tooling\n- Package manager: npm\n"
                "## Languages & runtimes\n- Language(s): TypeScript\n"
            )
            settings = generate_settings(root, tier=2)
            allow = settings["permissions"]["allow"]
            assert any("npm test" in r for r in allow)
            assert any("npx" in r for r in allow)


# ---------------------------------------------------------------------------
# AC loading and complexity estimation tests
# ---------------------------------------------------------------------------

class TestACHandling:
    def test_load_acceptance_criteria(self, project_dir):
        """Engine loads ACs from spec/acceptance/F-XXXX.md."""
        ac_file = project_dir / ".agentic" / "spec" / "acceptance" / "F-0042.md"
        ac_file.write_text(
            "# F-0042: User Authentication\n\n"
            "## Acceptance Criteria\n"
            "- [ ] AC-001: Given valid credentials, when POST /login, then return JWT\n"
            "- [ ] AC-002: Given invalid password, when POST /login, then return 401\n"
            "- [x] AC-003: Given expired token, when accessing protected route, then return 401\n"
        )
        engine = AutoEngine(project_dir)
        criteria = engine._load_acceptance_criteria("F-0042")
        assert len(criteria) == 3
        assert criteria[0][0] == "AC-001"
        assert "JWT" in criteria[0][1]
        assert criteria[2][0] == "AC-003"

    def test_load_ac_without_ids(self, project_dir):
        """ACs without explicit IDs get auto-generated ones."""
        ac_file = project_dir / ".agentic" / "spec" / "acceptance" / "F-0099.md"
        ac_file.write_text(
            "## Acceptance Criteria\n"
            "- [ ] Given a user, when they log in, then session created\n"
            "- [ ] Given a session, when expired, then redirect to login\n"
        )
        engine = AutoEngine(project_dir)
        criteria = engine._load_acceptance_criteria("F-0099")
        assert len(criteria) == 2
        assert criteria[0][0] == "AC-001"
        assert criteria[1][0] == "AC-002"

    def test_missing_ac_file(self, project_dir):
        engine = AutoEngine(project_dir)
        criteria = engine._load_acceptance_criteria("F-9999")
        assert criteria == []

    def test_complexity_estimation_small(self, project_dir):
        engine = AutoEngine(project_dir)
        assert engine._estimate_complexity("AC-001", "Add a button") == "SMALL"

    def test_complexity_estimation_large(self, project_dir):
        engine = AutoEngine(project_dir)
        result = engine._estimate_complexity(
            "AC-001", "Implement full authentication system with database schema"
        )
        assert result == "LARGE"

    def test_complexity_estimation_medium(self, project_dir):
        engine = AutoEngine(project_dir)
        result = engine._estimate_complexity(
            "AC-001",
            "Given a user with valid credentials, when they submit the login form "
            "with their email and password, then the system should validate the "
            "credentials against the user database, create a new JWT token with "
            "appropriate claims, and return it in the response body along with "
            "a refresh token cookie that expires in 7 days, plus update the "
            "last_login timestamp in the user profile record"
        )
        assert result == "MEDIUM"

    def test_decompose_ac_returns_subtasks(self, project_dir):
        """_decompose_ac returns a list of sub-task dicts."""
        engine = AutoEngine(project_dir)
        sub_tasks = engine._decompose_ac("AC-001", "Implement full auth system")
        assert len(sub_tasks) >= 1
        assert all("id" in st and "text" in st and "status" in st for st in sub_tasks)
        assert sub_tasks[0]["id"].startswith("AC-001.")
        assert sub_tasks[0]["status"] == "pending"

    def test_implement_large_ac_records_decomposition(self, project_dir):
        """LARGE ACs trigger decomposition and record sub-tasks in state."""
        engine = AutoEngine(project_dir)
        engine.engine_state.state = "running"
        engine._implement_large_ac("AC-005", "Build entire infrastructure")
        state = engine.engine_state.to_dict()
        assert "AC-005" in state["decomposed"]
        assert len(state["decomposed"]["AC-005"]) >= 1

    def test_large_ac_routed_to_decomposition(self, project_dir):
        """ACs estimated LARGE go through _implement_large_ac path."""
        ac_file = project_dir / ".agentic" / "spec" / "acceptance" / "F-0077.md"
        ac_file.write_text(
            "## Acceptance Criteria\n"
            "- [ ] AC-001: Implement full authentication system with database schema and JWT\n"
        )
        engine = AutoEngine(project_dir)
        # Verify estimation
        criteria = engine._load_acceptance_criteria("F-0077")
        assert len(criteria) == 1
        complexity = engine._estimate_complexity(criteria[0][0], criteria[0][1])
        assert complexity == "LARGE"


# ---------------------------------------------------------------------------
# Format status output test
# ---------------------------------------------------------------------------

class TestFormatStatus:
    def test_format_running_status(self):
        status = {
            "state": "running",
            "feature_id": "F-0042",
            "mode": "task",
            "current_ac": "AC-002",
            "progress": {"AC-001": "passed", "AC-002": "in_progress"},
            "decomposed": {},
            "feedback_queue_size": 0,
        }
        output = format_status(status)
        assert "running" in output
        assert "F-0042" in output
        assert "1/2 passed" in output

    def test_format_error(self):
        output = format_status({"error": "Engine not running"})
        assert "Engine not running" in output

    def test_format_with_decomposed(self):
        status = {
            "state": "stopped",
            "feature_id": "F-0042",
            "mode": "task",
            "current_ac": None,
            "progress": {"AC-001": "passed", "AC-002": "passed"},
            "decomposed": {
                "AC-002": [
                    {"id": "AC-002.1", "text": "schema", "status": "passed"},
                    {"id": "AC-002.2", "text": "endpoint", "status": "passed"},
                    {"id": "AC-002.3", "text": "tests", "status": "failed"},
                ]
            },
            "feedback_queue_size": 0,
        }
        output = format_status(status)
        assert "Decomposed" in output
        assert "AC-002" in output
        assert "2/3 sub-tasks passed" in output


# ---------------------------------------------------------------------------
# build_claude_cmd tests (shared helper from auto/__init__.py)
# ---------------------------------------------------------------------------

class TestBuildClaudeCmd:
    def test_no_settings_uses_interactive(self):
        """Without settings.json, no permission flags (safe default)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            cmd = build_claude_cmd("claude", root, "hello")
            assert "--dangerously-skip-permissions" not in cmd
            assert "--settings" not in cmd
            assert "--print" in cmd
            assert "hello" in cmd

    def test_tier1_uses_dangerous_skip(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / ".claude").mkdir()
            (root / ".claude" / "settings.json").write_text(
                json.dumps({"_tier": 1, "permissions": {"allow": ["*"], "deny": []}})
            )
            cmd = build_claude_cmd("claude", root, "hello")
            assert "--dangerously-skip-permissions" in cmd

    def test_tier2_uses_settings_file(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / ".claude").mkdir()
            settings_path = root / ".claude" / "settings.json"
            settings_path.write_text(
                json.dumps({"_tier": 2, "permissions": {"allow": ["Read"], "deny": []}})
            )
            cmd = build_claude_cmd("claude", root, "hello")
            assert "--settings" in cmd
            assert str(settings_path) in cmd
            assert "--dangerously-skip-permissions" not in cmd

    def test_tier3_uses_interactive(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / ".claude").mkdir()
            (root / ".claude" / "settings.json").write_text(
                json.dumps({"_tier": 3, "permissions": {"allow": [], "deny": []}})
            )
            cmd = build_claude_cmd("claude", root, "hello")
            assert "--dangerously-skip-permissions" not in cmd
            assert "--settings" not in cmd

    def test_corrupt_settings_falls_to_interactive(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / ".claude").mkdir()
            (root / ".claude" / "settings.json").write_text("not valid json")
            cmd = build_claude_cmd("claude", root, "hello")
            assert "--dangerously-skip-permissions" not in cmd

    def test_print_mode_disabled(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            cmd = build_claude_cmd("claude", root, "hello", print_mode=False)
            assert "--print" not in cmd
