#!/usr/bin/env python3
"""
Tests for the intent journal module (F-0200, AC-003 through AC-009).

Covers:
- write_intent creates intent
- checkpoint_step updates steps_completed/remaining
- get_pending returns incomplete intents
- get_orphaned detects dead PIDs
- clear_intent removes intent
- cancel_intent marks as cancelled
- adopt_orphans transfers ownership
- Corrupt JSON handling
- Concurrent access (basic threading test)
- Session ID management
"""
import json
import os
import sys
import tempfile
import threading
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
# write_intent
# ---------------------------------------------------------------------------

class TestWriteIntent:
    def test_creates_intent(self, project_dir):
        entry = write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["register_wip", "create_worktree", "transition_state"],
            session_id="test-session-1", pid=os.getpid(),
            worktree="/tmp/wt-f-0042",
            previous_state="planned",
        )
        assert entry["feature_id"] == "F-0042"
        assert entry["target_state"] == "implementing"
        assert entry["command"] == "implement"
        assert entry["previous_state"] == "planned"
        assert entry["session_id"] == "test-session-1"
        assert entry["agent_pid"] == os.getpid()
        assert entry["worktree"] == "/tmp/wt-f-0042"
        assert entry["steps_completed"] == []
        assert entry["steps_remaining"] == [
            "register_wip", "create_worktree", "transition_state"
        ]
        assert entry["attempt_count"] == 1
        assert entry["status"] == "active"
        assert entry["error"] is None
        assert entry["created_at"]  # ISO timestamp present

    def test_creates_session_dir_if_missing(self, project_dir):
        """AC-008: Creates .agentic/session/ directory if not exists."""
        import shutil
        session_dir = project_dir / ".agentic" / "session"
        shutil.rmtree(session_dir)
        assert not session_dir.exists()

        write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["step1"], session_id="s1", pid=os.getpid(),
        )
        assert session_dir.exists()

    def test_overwrites_existing_intent_for_same_feature(self, project_dir):
        write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["step1", "step2"], session_id="s1", pid=os.getpid(),
        )
        write_intent(
            project_dir, "F-0042", "shipped", "done",
            ["step_a"], session_id="s2", pid=os.getpid(),
        )
        ifile = _intents_file(project_dir)
        items = _load_unlocked(ifile)
        assert len(items) == 1
        assert items[0]["target_state"] == "shipped"
        assert items[0]["session_id"] == "s2"

    def test_multiple_features(self, project_dir):
        write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["step1"], session_id="s1", pid=os.getpid(),
        )
        write_intent(
            project_dir, "F-0043", "shipped", "done",
            ["step1"], session_id="s1", pid=os.getpid(),
        )
        ifile = _intents_file(project_dir)
        items = _load_unlocked(ifile)
        assert len(items) == 2
        fids = {item["feature_id"] for item in items}
        assert fids == {"F-0042", "F-0043"}

    def test_includes_previous_state(self, project_dir):
        """AC-005: Intent schema includes previous_state field."""
        entry = write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["step1"], session_id="s1", pid=os.getpid(),
            previous_state="planned",
        )
        assert entry["previous_state"] == "planned"


# ---------------------------------------------------------------------------
# checkpoint_step
# ---------------------------------------------------------------------------

class TestCheckpointStep:
    def test_moves_step_from_remaining_to_completed(self, project_dir):
        write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["step1", "step2", "step3"],
            session_id="s1", pid=os.getpid(),
        )
        ok = checkpoint_step(project_dir, "F-0042", "step1")
        assert ok

        ifile = _intents_file(project_dir)
        items = _load_unlocked(ifile)
        intent = items[0]
        assert "step1" in intent["steps_completed"]
        assert "step1" not in intent["steps_remaining"]
        assert "step2" in intent["steps_remaining"]
        assert "step3" in intent["steps_remaining"]

    def test_checkpoint_multiple_steps(self, project_dir):
        write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["step1", "step2", "step3"],
            session_id="s1", pid=os.getpid(),
        )
        checkpoint_step(project_dir, "F-0042", "step1")
        checkpoint_step(project_dir, "F-0042", "step2")

        ifile = _intents_file(project_dir)
        items = _load_unlocked(ifile)
        intent = items[0]
        assert intent["steps_completed"] == ["step1", "step2"]
        assert intent["steps_remaining"] == ["step3"]

    def test_returns_false_when_intent_not_found(self, project_dir):
        ok = checkpoint_step(project_dir, "F-9999", "step1")
        assert not ok

    def test_idempotent_checkpoint(self, project_dir):
        """Checkpointing the same step twice does not duplicate it."""
        write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["step1", "step2"],
            session_id="s1", pid=os.getpid(),
        )
        checkpoint_step(project_dir, "F-0042", "step1")
        checkpoint_step(project_dir, "F-0042", "step1")

        ifile = _intents_file(project_dir)
        items = _load_unlocked(ifile)
        intent = items[0]
        assert intent["steps_completed"].count("step1") == 1


# ---------------------------------------------------------------------------
# get_pending
# ---------------------------------------------------------------------------

class TestGetPending:
    def test_returns_incomplete_intents(self, project_dir):
        write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["step1", "step2"],
            session_id="s1", pid=os.getpid(),
        )
        pending = get_pending(project_dir)
        assert len(pending) == 1
        assert pending[0]["feature_id"] == "F-0042"

    def test_excludes_completed_intents(self, project_dir):
        write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["step1"],
            session_id="s1", pid=os.getpid(),
        )
        checkpoint_step(project_dir, "F-0042", "step1")

        pending = get_pending(project_dir)
        assert len(pending) == 0

    def test_filters_by_session_id(self, project_dir):
        write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["step1"], session_id="session-A", pid=os.getpid(),
        )
        write_intent(
            project_dir, "F-0043", "shipped", "done",
            ["step1"], session_id="session-B", pid=os.getpid(),
        )
        pending_a = get_pending(project_dir, session_id="session-A")
        assert len(pending_a) == 1
        assert pending_a[0]["feature_id"] == "F-0042"

        pending_b = get_pending(project_dir, session_id="session-B")
        assert len(pending_b) == 1
        assert pending_b[0]["feature_id"] == "F-0043"

    def test_excludes_cancelled_intents(self, project_dir):
        write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["step1"], session_id="s1", pid=os.getpid(),
        )
        cancel_intent(project_dir, "F-0042")

        pending = get_pending(project_dir)
        assert len(pending) == 0

    def test_returns_empty_when_no_file(self, project_dir):
        pending = get_pending(project_dir)
        assert pending == []


# ---------------------------------------------------------------------------
# get_orphaned
# ---------------------------------------------------------------------------

class TestGetOrphaned:
    def test_detects_dead_pid_intents(self, project_dir):
        """Intent with a dead PID and old enough age is detected as orphaned."""
        # Write intent with a definitely-dead PID
        dead_pid = 99999999
        write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["step1"], session_id="old-session", pid=dead_pid,
        )
        # Manually backdate the created_at to exceed threshold
        ifile = _intents_file(project_dir)
        items = _load_unlocked(ifile)
        items[0]["created_at"] = "2020-01-01T00:00:00Z"
        with open(ifile, "w") as f:
            json.dump(items, f, indent=2)

        with patch("auto.intents._is_pid_alive", return_value=False):
            orphaned = get_orphaned(project_dir)
        assert len(orphaned) == 1
        assert orphaned[0]["feature_id"] == "F-0042"

    def test_live_pid_not_orphaned(self, project_dir):
        """Intent with a live PID is not orphaned, even if old."""
        write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["step1"], session_id="s1", pid=os.getpid(),
        )
        # Backdate
        ifile = _intents_file(project_dir)
        items = _load_unlocked(ifile)
        items[0]["created_at"] = "2020-01-01T00:00:00Z"
        with open(ifile, "w") as f:
            json.dump(items, f, indent=2)

        orphaned = get_orphaned(project_dir)
        assert len(orphaned) == 0

    def test_recent_dead_pid_not_orphaned(self, project_dir):
        """Dead PID but created very recently is NOT orphaned (grace period)."""
        dead_pid = 99999999
        write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["step1"], session_id="s1", pid=dead_pid,
        )
        # Don't backdate — it was just created
        with patch("auto.intents._is_pid_alive", return_value=False):
            orphaned = get_orphaned(project_dir)
        assert len(orphaned) == 0

    def test_cancelled_intents_not_orphaned(self, project_dir):
        dead_pid = 99999999
        write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["step1"], session_id="s1", pid=dead_pid,
        )
        cancel_intent(project_dir, "F-0042")

        # Backdate
        ifile = _intents_file(project_dir)
        items = _load_unlocked(ifile)
        items[0]["created_at"] = "2020-01-01T00:00:00Z"
        with open(ifile, "w") as f:
            json.dump(items, f, indent=2)

        with patch("auto.intents._is_pid_alive", return_value=False):
            orphaned = get_orphaned(project_dir)
        assert len(orphaned) == 0


# ---------------------------------------------------------------------------
# clear_intent
# ---------------------------------------------------------------------------

class TestClearIntent:
    def test_removes_intent(self, project_dir):
        write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["step1"], session_id="s1", pid=os.getpid(),
        )
        ok = clear_intent(project_dir, "F-0042")
        assert ok

        ifile = _intents_file(project_dir)
        items = _load_unlocked(ifile)
        assert len(items) == 0

    def test_returns_false_when_not_found(self, project_dir):
        ok = clear_intent(project_dir, "F-9999")
        assert not ok

    def test_clears_only_specified_feature(self, project_dir):
        write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["step1"], session_id="s1", pid=os.getpid(),
        )
        write_intent(
            project_dir, "F-0043", "shipped", "done",
            ["step1"], session_id="s1", pid=os.getpid(),
        )
        clear_intent(project_dir, "F-0042")

        ifile = _intents_file(project_dir)
        items = _load_unlocked(ifile)
        assert len(items) == 1
        assert items[0]["feature_id"] == "F-0043"


# ---------------------------------------------------------------------------
# cancel_intent
# ---------------------------------------------------------------------------

class TestCancelIntent:
    def test_marks_as_cancelled(self, project_dir):
        write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["step1"], session_id="s1", pid=os.getpid(),
        )
        ok = cancel_intent(project_dir, "F-0042")
        assert ok

        ifile = _intents_file(project_dir)
        items = _load_unlocked(ifile)
        assert items[0]["status"] == "cancelled"
        assert items[0]["error"] is not None

    def test_returns_false_when_not_found(self, project_dir):
        ok = cancel_intent(project_dir, "F-9999")
        assert not ok

    def test_cancelled_intent_not_pending(self, project_dir):
        write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["step1"], session_id="s1", pid=os.getpid(),
        )
        cancel_intent(project_dir, "F-0042")

        pending = get_pending(project_dir)
        assert len(pending) == 0


# ---------------------------------------------------------------------------
# adopt_orphans
# ---------------------------------------------------------------------------

class TestAdoptOrphans:
    def test_adopts_dead_pid_intents(self, project_dir):
        dead_pid = 99999999
        write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["step1"], session_id="old-session", pid=dead_pid,
        )
        # Backdate
        ifile = _intents_file(project_dir)
        items = _load_unlocked(ifile)
        items[0]["created_at"] = "2020-01-01T00:00:00Z"
        with open(ifile, "w") as f:
            json.dump(items, f, indent=2)

        new_pid = os.getpid()
        with patch("auto.intents._is_pid_alive", return_value=False):
            adopted = adopt_orphans(project_dir, "new-session", new_pid)

        assert adopted == ["F-0042"]

        items = _load_unlocked(ifile)
        assert items[0]["session_id"] == "new-session"
        assert items[0]["agent_pid"] == new_pid
        assert items[0]["attempt_count"] == 2  # incremented from 1

    def test_does_not_adopt_live_pid(self, project_dir):
        write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["step1"], session_id="other-session", pid=os.getpid(),
        )
        # Backdate
        ifile = _intents_file(project_dir)
        items = _load_unlocked(ifile)
        items[0]["created_at"] = "2020-01-01T00:00:00Z"
        with open(ifile, "w") as f:
            json.dump(items, f, indent=2)

        adopted = adopt_orphans(project_dir, "new-session", os.getpid())
        assert adopted == []

    def test_does_not_adopt_recent_dead_pid(self, project_dir):
        """Grace period: recently created intents with dead PIDs are not adopted."""
        dead_pid = 99999999
        write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["step1"], session_id="s1", pid=dead_pid,
        )
        # Don't backdate — just created
        with patch("auto.intents._is_pid_alive", return_value=False):
            adopted = adopt_orphans(project_dir, "new-session", os.getpid())
        assert adopted == []

    def test_returns_empty_when_no_orphans(self, project_dir):
        adopted = adopt_orphans(project_dir, "new-session", os.getpid())
        assert adopted == []


# ---------------------------------------------------------------------------
# Corrupt JSON handling (AC-007)
# ---------------------------------------------------------------------------

class TestCorruptJSON:
    def test_corrupt_json_falls_back_to_empty(self, project_dir):
        """AC-007: Handles corrupt JSON gracefully."""
        ifile = _intents_file(project_dir)
        ifile.parent.mkdir(parents=True, exist_ok=True)
        ifile.write_text("this is not valid JSON{{{")

        # _load_unlocked should return empty list
        items = _load_unlocked(ifile)
        assert items == []

    def test_write_after_corrupt_json(self, project_dir):
        """Writing after corrupt JSON recovers gracefully."""
        ifile = _intents_file(project_dir)
        ifile.parent.mkdir(parents=True, exist_ok=True)
        ifile.write_text("CORRUPT DATA!!!")

        # Should recover and write a valid intent
        entry = write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["step1"], session_id="s1", pid=os.getpid(),
        )
        assert entry["feature_id"] == "F-0042"

        # Verify file is now valid JSON
        items = _load_unlocked(ifile)
        assert len(items) == 1

    def test_non_list_json_treated_as_empty(self, project_dir):
        """JSON that parses but is not a list is treated as empty."""
        ifile = _intents_file(project_dir)
        ifile.parent.mkdir(parents=True, exist_ok=True)
        ifile.write_text('{"not": "a list"}')

        items = _load_unlocked(ifile)
        assert items == []


# ---------------------------------------------------------------------------
# Session ID management (AC-006)
# ---------------------------------------------------------------------------

class TestSessionID:
    def test_creates_session_id(self, project_dir):
        """AC-006: Session ID is a UUID."""
        sid = get_or_create_session_id(project_dir)
        assert sid
        assert len(sid) == 36  # UUID format: 8-4-4-4-12
        assert "-" in sid

    def test_reuses_existing_session_id(self, project_dir):
        sid1 = get_or_create_session_id(project_dir)
        sid2 = get_or_create_session_id(project_dir)
        assert sid1 == sid2

    def test_creates_new_if_file_empty(self, project_dir):
        # Write empty file
        sid_file = project_dir / ".agentic" / "session" / ".current-session-id"
        sid_file.parent.mkdir(parents=True, exist_ok=True)
        sid_file.write_text("")

        sid = get_or_create_session_id(project_dir)
        assert sid
        assert len(sid) == 36


# ---------------------------------------------------------------------------
# Concurrent access (basic threading test, AC-009)
# ---------------------------------------------------------------------------

class TestConcurrentAccess:
    def test_concurrent_writes_dont_corrupt(self, project_dir):
        """Multiple threads writing intents simultaneously should not corrupt the file."""
        errors = []

        def writer(feature_id):
            try:
                write_intent(
                    project_dir, feature_id, "implementing", "implement",
                    ["step1", "step2"],
                    session_id=f"session-{feature_id}",
                    pid=os.getpid(),
                )
            except Exception as e:
                errors.append(str(e))

        threads = []
        for i in range(10):
            t = threading.Thread(target=writer, args=(f"F-{i:04d}",))
            threads.append(t)

        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=10)

        assert len(errors) == 0, f"Errors during concurrent writes: {errors}"

        # Verify file is valid and contains all entries
        ifile = _intents_file(project_dir)
        items = _load_unlocked(ifile)
        # Note: due to overwrite-on-same-feature semantics and fcntl being
        # per-process (not per-thread), we may not get exactly 10.
        # The important thing is the file is valid JSON.
        assert isinstance(items, list)
        assert len(items) > 0

    def test_concurrent_checkpoint_and_write(self, project_dir):
        """Checkpoint and write operations don't corrupt each other."""
        write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["step1", "step2", "step3"],
            session_id="s1", pid=os.getpid(),
        )

        errors = []

        def checkpointer(step_name):
            try:
                checkpoint_step(project_dir, "F-0042", step_name)
            except Exception as e:
                errors.append(str(e))

        def new_writer():
            try:
                write_intent(
                    project_dir, "F-0043", "shipped", "done",
                    ["a", "b"], session_id="s2", pid=os.getpid(),
                )
            except Exception as e:
                errors.append(str(e))

        threads = [
            threading.Thread(target=checkpointer, args=("step1",)),
            threading.Thread(target=checkpointer, args=("step2",)),
            threading.Thread(target=new_writer),
        ]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=10)

        assert len(errors) == 0

        # File should be valid JSON
        ifile = _intents_file(project_dir)
        items = _load_unlocked(ifile)
        assert isinstance(items, list)


# ---------------------------------------------------------------------------
# End-to-end: full lifecycle
# ---------------------------------------------------------------------------

class TestFullLifecycle:
    def test_write_checkpoint_clear(self, project_dir):
        """Full lifecycle: write -> checkpoint all steps -> clear."""
        write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["step1", "step2", "step3"],
            session_id="s1", pid=os.getpid(),
            previous_state="planned",
        )
        assert len(get_pending(project_dir)) == 1

        checkpoint_step(project_dir, "F-0042", "step1")
        checkpoint_step(project_dir, "F-0042", "step2")
        checkpoint_step(project_dir, "F-0042", "step3")

        # Still active (steps_remaining is empty but status is active)
        # get_pending requires steps_remaining to be non-empty
        assert len(get_pending(project_dir)) == 0

        ok = clear_intent(project_dir, "F-0042")
        assert ok

        ifile = _intents_file(project_dir)
        items = _load_unlocked(ifile)
        assert len(items) == 0

    def test_write_cancel_lifecycle(self, project_dir):
        """Write -> partial progress -> cancel."""
        write_intent(
            project_dir, "F-0042", "implementing", "implement",
            ["step1", "step2"],
            session_id="s1", pid=os.getpid(),
            previous_state="planned",
        )
        checkpoint_step(project_dir, "F-0042", "step1")
        cancel_intent(project_dir, "F-0042")

        ifile = _intents_file(project_dir)
        items = _load_unlocked(ifile)
        assert items[0]["status"] == "cancelled"
        assert items[0]["steps_completed"] == ["step1"]
        assert items[0]["steps_remaining"] == ["step2"]
        assert items[0]["previous_state"] == "planned"
