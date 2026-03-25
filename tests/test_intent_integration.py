#!/usr/bin/env python3
"""
Integration tests for F-0200: Intent Journal + Reconciliation (AC-027 through AC-030).

Tests:
- Full lifecycle: write intent, checkpoint, clear
- Orphan detection with dead PID
- adopt_orphans transfers ownership
- Session isolation (different session_ids)
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from unittest.mock import patch

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "auto"))

from auto.intents import (
    write_intent,
    checkpoint_step,
    get_pending,
    get_orphaned,
    clear_intent,
    cancel_intent,
    adopt_orphans,
    get_or_create_session_id,
    _intents_file,
    _load_unlocked,
    _ORPHAN_AGE_MINUTES,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def project_dir():
    """Temporary project directory mimicking framework layout."""
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        (root / ".agentic" / "lib").mkdir(parents=True)
        (root / ".agentic" / "session").mkdir(parents=True)
        (root / ".agentic" / "spec").mkdir(parents=True)
        # Copy paths.py so get_paths works
        lib_src = Path(__file__).parent.parent / ".agentic" / "lib"
        for f in ["paths.py", "settings.py"]:
            src = lib_src / f
            if src.exists():
                (root / ".agentic" / "lib" / f).write_text(src.read_text())
        (root / "STACK.md").write_text("## Settings\n- profile: formal\n")
        # Initialize git so paths.py can resolve main_project_root
        os.system(f"cd {root} && git init -q 2>/dev/null")
        yield root


# ---------------------------------------------------------------------------
# AC-027: Full lifecycle (write, checkpoint, clear)
# ---------------------------------------------------------------------------

class TestFullLifecycle:
    """AC-027: Test: write intent, checkpoint, clear (full lifecycle)."""

    def test_write_checkpoint_clear(self, project_dir):
        """Write intent -> checkpoint steps -> clear on completion."""
        # Step 1: Write intent
        entry = write_intent(
            project_dir, "F-0100", "implementing", "implement",
            ["register_wip", "create_worktree", "transition_state", "update_status"],
            session_id="lifecycle-session", pid=os.getpid(),
            worktree="/tmp/wt-f-0100",
            previous_state="planned",
        )
        assert entry["feature_id"] == "F-0100"
        assert len(entry["steps_remaining"]) == 4
        assert len(entry["steps_completed"]) == 0

        # Verify it shows up as pending
        pending = get_pending(project_dir, session_id="lifecycle-session")
        assert len(pending) == 1

        # Step 2: Checkpoint each step
        for step in ["register_wip", "create_worktree", "transition_state", "update_status"]:
            ok = checkpoint_step(project_dir, "F-0100", step)
            assert ok

        # After all steps checkpointed, no longer pending
        # (steps_remaining is empty)
        pending = get_pending(project_dir, session_id="lifecycle-session")
        assert len(pending) == 0

        # Step 3: Clear the completed intent
        cleared = clear_intent(project_dir, "F-0100")
        assert cleared

        # Verify file is clean
        ifile = _intents_file(project_dir)
        items = _load_unlocked(ifile)
        assert len(items) == 0

    def test_cancel_lifecycle(self, project_dir):
        """Write intent -> partial progress -> cancel."""
        write_intent(
            project_dir, "F-011", "implementing", "implement",
            ["step1", "step2", "step3"],
            session_id="cancel-session", pid=os.getpid(),
            previous_state="planned",
        )

        # Complete one step
        checkpoint_step(project_dir, "F-011", "step1")

        # Cancel the intent
        ok = cancel_intent(project_dir, "F-011")
        assert ok

        # Verify it's no longer pending (status changed to cancelled)
        pending = get_pending(project_dir, session_id="cancel-session")
        assert len(pending) == 0

        # Verify the entry still exists with cancelled status
        ifile = _intents_file(project_dir)
        items = _load_unlocked(ifile)
        assert len(items) == 1
        assert items[0]["status"] == "cancelled"


# ---------------------------------------------------------------------------
# AC-029: Orphan detection with dead PID
# ---------------------------------------------------------------------------

class TestOrphanDetection:
    """AC-029: Test: write intent with dead PID -> get_orphaned detects it."""

    def test_dead_pid_detected_as_orphan(self, project_dir):
        """Intent with a PID that no longer exists is detected as orphaned."""
        # Use a PID that almost certainly doesn't exist
        dead_pid = 99999999

        # Mock time to make the intent old enough
        write_intent(
            project_dir, "F-0200", "implementing", "implement",
            ["step1", "step2"],
            session_id="dead-session", pid=dead_pid,
        )

        # Patch the created_at to be old enough (> 5 minutes)
        ifile = _intents_file(project_dir)
        with open(ifile, "r") as f:
            items = json.load(f)
        items[0]["created_at"] = "2020-01-01T00:00:00Z"  # Very old
        with open(ifile, "w") as f:
            json.dump(items, f)

        # Should detect as orphaned
        orphaned = get_orphaned(project_dir)
        assert len(orphaned) == 1
        assert orphaned[0]["feature_id"] == "F-0200"
        assert orphaned[0]["agent_pid"] == dead_pid

    def test_live_pid_not_orphaned(self, project_dir):
        """Intent with the current (alive) PID is NOT orphaned."""
        write_intent(
            project_dir, "F-0201", "implementing", "implement",
            ["step1"],
            session_id="live-session", pid=os.getpid(),
        )

        # Even with old timestamp, alive PID means not orphaned
        ifile = _intents_file(project_dir)
        with open(ifile, "r") as f:
            items = json.load(f)
        items[0]["created_at"] = "2020-01-01T00:00:00Z"
        with open(ifile, "w") as f:
            json.dump(items, f)

        orphaned = get_orphaned(project_dir)
        assert len(orphaned) == 0

    def test_recent_dead_pid_not_orphaned_yet(self, project_dir):
        """Dead PID but created recently (< 5 min) should NOT be orphaned."""
        dead_pid = 99999999

        write_intent(
            project_dir, "F-0202", "implementing", "implement",
            ["step1"],
            session_id="recent-dead", pid=dead_pid,
        )
        # created_at is "now" — within the 5-minute threshold

        orphaned = get_orphaned(project_dir)
        assert len(orphaned) == 0


# ---------------------------------------------------------------------------
# AC-028 (partial): adopt_orphans transfers ownership
# ---------------------------------------------------------------------------

class TestAdoptOrphans:
    """Test: adopt_orphans transfers ownership to current session."""

    def test_adopt_transfers_session_and_pid(self, project_dir):
        """Adopt updates session_id and agent_pid on orphaned intents."""
        dead_pid = 99999999

        write_intent(
            project_dir, "F-0300", "implementing", "implement",
            ["step1", "step2"],
            session_id="old-session", pid=dead_pid,
        )

        # Make it old enough
        ifile = _intents_file(project_dir)
        with open(ifile, "r") as f:
            items = json.load(f)
        items[0]["created_at"] = "2020-01-01T00:00:00Z"
        with open(ifile, "w") as f:
            json.dump(items, f)

        # Adopt into new session
        new_session = "new-session-uuid"
        new_pid = os.getpid()
        adopted = adopt_orphans(project_dir, new_session, new_pid)

        assert adopted == ["F-0300"]

        # Verify the intent now belongs to new session
        items = _load_unlocked(ifile)
        assert items[0]["session_id"] == new_session
        assert items[0]["agent_pid"] == new_pid
        # attempt_count incremented
        assert items[0]["attempt_count"] == 2

    def test_adopt_does_not_touch_live_agents(self, project_dir):
        """Intents with alive PIDs are not adopted."""
        write_intent(
            project_dir, "F-0301", "implementing", "implement",
            ["step1"],
            session_id="other-session", pid=os.getpid(),  # alive
        )

        # Make it old
        ifile = _intents_file(project_dir)
        with open(ifile, "r") as f:
            items = json.load(f)
        items[0]["created_at"] = "2020-01-01T00:00:00Z"
        with open(ifile, "w") as f:
            json.dump(items, f)

        adopted = adopt_orphans(project_dir, "adopter-session", os.getpid())
        assert adopted == []


# ---------------------------------------------------------------------------
# AC-030: Session isolation
# ---------------------------------------------------------------------------

class TestSessionIsolation:
    """AC-030: Test: session isolation (different session_ids)."""

    def test_pending_filters_by_session(self, project_dir):
        """get_pending with session_id only returns that session's intents."""
        write_intent(
            project_dir, "F-0400", "implementing", "implement",
            ["step1"], session_id="session-A", pid=os.getpid(),
        )
        write_intent(
            project_dir, "F-0401", "shipped", "done",
            ["step1"], session_id="session-B", pid=os.getpid(),
        )
        write_intent(
            project_dir, "F-0402", "implementing", "implement",
            ["step1"], session_id="session-A", pid=os.getpid(),
        )

        pending_a = get_pending(project_dir, session_id="session-A")
        pending_b = get_pending(project_dir, session_id="session-B")

        assert len(pending_a) == 2
        assert len(pending_b) == 1

        fids_a = {p["feature_id"] for p in pending_a}
        fids_b = {p["feature_id"] for p in pending_b}
        assert fids_a == {"F-0400", "F-0402"}
        assert fids_b == {"F-0401"}

    def test_session_id_persists(self, project_dir):
        """Session ID created once and reused."""
        sid1 = get_or_create_session_id(project_dir)
        sid2 = get_or_create_session_id(project_dir)
        assert sid1 == sid2
        assert len(sid1) > 0

    def test_session_id_file_survives(self, project_dir):
        """Session ID file persists across calls."""
        sid = get_or_create_session_id(project_dir)
        sid_file = project_dir / ".agentic" / "session" / ".current-session-id"
        assert sid_file.exists()
        assert sid_file.read_text().strip() == sid


# ---------------------------------------------------------------------------
# Corrupt JSON handling
# ---------------------------------------------------------------------------

class TestCorruptJson:
    """Corrupt intents.json should not crash operations."""

    def test_corrupt_json_handled_gracefully(self, project_dir):
        """Writing to a corrupt file replaces it cleanly."""
        ifile = _intents_file(project_dir)
        ifile.parent.mkdir(parents=True, exist_ok=True)
        ifile.write_text("THIS IS NOT JSON {{{")

        # Should not raise
        entry = write_intent(
            project_dir, "F-0500", "implementing", "implement",
            ["step1"], session_id="s1", pid=os.getpid(),
        )
        assert entry["feature_id"] == "F-0500"

        # File should now be valid
        items = _load_unlocked(ifile)
        assert len(items) == 1

    def test_get_pending_with_corrupt_file(self, project_dir):
        """get_pending returns empty on corrupt file."""
        ifile = _intents_file(project_dir)
        ifile.parent.mkdir(parents=True, exist_ok=True)
        ifile.write_text("NOT JSON")

        pending = get_pending(project_dir)
        assert pending == []


# ---------------------------------------------------------------------------
# CLI integration (calls intents.py as subprocess)
# ---------------------------------------------------------------------------

class TestCLIIntegration:
    """Test the CLI entry point of intents.py."""

    def test_cli_write_and_get_pending(self, project_dir):
        """CLI write-intent + get-pending round-trip."""
        intents_script = (
            Path(__file__).parent.parent / ".agentic" / "lib" / "auto" / "intents.py"
        )

        # Write intent via CLI
        result = subprocess.run(
            [
                sys.executable, str(intents_script),
                "--project-root", str(project_dir),
                "write-intent", "F-0600",
                "--target-state", "implementing",
                "--command-name", "implement",
                "--steps", "step1,step2,step3",
                "--session-id", "cli-session",
                "--pid", str(os.getpid()),
            ],
            capture_output=True, text=True,
        )
        assert result.returncode == 0

        # Get pending via CLI
        result = subprocess.run(
            [
                sys.executable, str(intents_script),
                "--project-root", str(project_dir),
                "get-pending", "--session-id", "cli-session",
            ],
            capture_output=True, text=True,
        )
        assert result.returncode == 0
        pending = json.loads(result.stdout)
        assert len(pending) == 1
        assert pending[0]["feature_id"] == "F-0600"

    def test_cli_checkpoint_and_clear(self, project_dir):
        """CLI checkpoint-step + clear-intent."""
        intents_script = (
            Path(__file__).parent.parent / ".agentic" / "lib" / "auto" / "intents.py"
        )

        # Write intent
        subprocess.run(
            [
                sys.executable, str(intents_script),
                "--project-root", str(project_dir),
                "write-intent", "F-0601",
                "--target-state", "shipped",
                "--command-name", "done",
                "--steps", "step1",
                "--session-id", "cli-session-2",
                "--pid", str(os.getpid()),
            ],
            capture_output=True, text=True,
        )

        # Checkpoint
        result = subprocess.run(
            [
                sys.executable, str(intents_script),
                "--project-root", str(project_dir),
                "checkpoint-step", "F-0601", "step1",
            ],
            capture_output=True, text=True,
        )
        assert result.returncode == 0

        # Clear
        result = subprocess.run(
            [
                sys.executable, str(intents_script),
                "--project-root", str(project_dir),
                "clear-intent", "F-0601",
            ],
            capture_output=True, text=True,
        )
        assert result.returncode == 0
        assert "Cleared" in result.stdout
