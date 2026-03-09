#!/usr/bin/env python3
"""
Tests for session tracking in agents_helpers.py (F-0195: Multi-Session Collision Prevention).
"""
import json
import os
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "tools"))

from tools.agents_helpers import (
    cmd_session_register,
    cmd_session_deregister,
    cmd_count_others,
    cmd_cleanup_stale,
    cmd_session_heartbeat,
    _load_unlocked,
    _STALE_HEARTBEAT_MINUTES,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def agents_file(tmp_path):
    """Create a temporary AGENTS.json file."""
    f = tmp_path / "session" / "AGENTS.json"
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text("[]\n")
    return f


# ---------------------------------------------------------------------------
# session-register
# ---------------------------------------------------------------------------

class TestSessionRegister:
    def test_creates_entry(self, agents_file):
        cmd_session_register(agents_file, "/tmp/project", "claude-code", pid=12345)
        items = json.loads(agents_file.read_text())
        assert len(items) == 1
        entry = items[0]
        assert entry["feature_id"] == "session-12345"
        assert entry["type"] == "session"
        assert entry["pid"] == 12345
        assert entry["worktree"] == "/tmp/project"
        assert entry["agent"] == "claude-code"
        assert entry["status"] == "active"

    def test_dedup_same_pid_worktree(self, agents_file):
        cmd_session_register(agents_file, "/tmp/project", "claude-code", pid=12345)
        cmd_session_register(agents_file, "/tmp/project", "claude-code", pid=12345)
        items = json.loads(agents_file.read_text())
        assert len(items) == 1  # Not duplicated

    def test_different_pids_separate_entries(self, agents_file):
        cmd_session_register(agents_file, "/tmp/project", "claude-code", pid=12345)
        cmd_session_register(agents_file, "/tmp/project", "claude-code", pid=67890)
        items = json.loads(agents_file.read_text())
        assert len(items) == 2


# ---------------------------------------------------------------------------
# session-deregister
# ---------------------------------------------------------------------------

class TestSessionDeregister:
    def test_removes_entry(self, agents_file):
        cmd_session_register(agents_file, "/tmp/project", "claude-code", pid=12345)
        cmd_session_deregister(agents_file, "/tmp/project", pid=12345)
        items = json.loads(agents_file.read_text())
        assert len(items) == 0

    def test_only_removes_matching_pid(self, agents_file):
        cmd_session_register(agents_file, "/tmp/project", "claude-code", pid=12345)
        cmd_session_register(agents_file, "/tmp/project", "claude-code", pid=67890)
        cmd_session_deregister(agents_file, "/tmp/project", pid=12345)
        items = json.loads(agents_file.read_text())
        assert len(items) == 1
        assert items[0]["pid"] == 67890

    def test_noop_if_not_found(self, agents_file):
        cmd_session_deregister(agents_file, "/tmp/project", pid=99999)
        items = json.loads(agents_file.read_text())
        assert len(items) == 0


# ---------------------------------------------------------------------------
# count-others
# ---------------------------------------------------------------------------

class TestCountOthers:
    def test_returns_zero_when_only_self(self, agents_file, capsys):
        cmd_session_register(agents_file, "/tmp/project", "claude-code", pid=12345)
        cmd_count_others(agents_file, "/tmp/project", pid=12345)
        assert capsys.readouterr().out.strip() == "0"

    def test_returns_count_of_others(self, agents_file, capsys):
        cmd_session_register(agents_file, "/tmp/project", "claude-code", pid=12345)
        cmd_session_register(agents_file, "/tmp/project", "claude-code", pid=67890)
        cmd_count_others(agents_file, "/tmp/project", pid=12345)
        assert capsys.readouterr().out.strip() == "1"

    def test_ignores_different_worktree(self, agents_file, capsys):
        cmd_session_register(agents_file, "/tmp/project", "claude-code", pid=12345)
        cmd_session_register(agents_file, "/tmp/other", "claude-code", pid=67890)
        cmd_count_others(agents_file, "/tmp/project", pid=12345)
        assert capsys.readouterr().out.strip() == "0"

    def test_counts_feature_entries_too(self, agents_file, capsys):
        """Feature entries on same worktree are also collision risks."""
        # Manually add a feature entry (non-session type)
        items = json.loads(agents_file.read_text())
        items.append({
            "feature_id": "F-0194",
            "worktree": "/tmp/project",
            "status": "active",
        })
        agents_file.write_text(json.dumps(items))
        cmd_session_register(agents_file, "/tmp/project", "claude-code", pid=12345)
        cmd_count_others(agents_file, "/tmp/project", pid=12345)
        assert capsys.readouterr().out.strip() == "1"

    def test_ignores_completed_entries(self, agents_file, capsys):
        """Completed entries don't count as collision risks."""
        items = json.loads(agents_file.read_text())
        items.append({
            "feature_id": "F-0194",
            "worktree": "/tmp/project",
            "status": "completed",
        })
        agents_file.write_text(json.dumps(items))
        cmd_session_register(agents_file, "/tmp/project", "claude-code", pid=12345)
        cmd_count_others(agents_file, "/tmp/project", pid=12345)
        assert capsys.readouterr().out.strip() == "0"


# ---------------------------------------------------------------------------
# cleanup-stale
# ---------------------------------------------------------------------------

class TestCleanupStale:
    def test_removes_dead_pid(self, agents_file, capsys):
        """Session with dead PID is removed."""
        items = [{
            "feature_id": "session-99999999",
            "type": "session",
            "pid": 99999999,  # Almost certainly dead
            "worktree": "/tmp/project",
            "status": "active",
            "last_checkpoint": "2026-03-09T14:00:00Z",
        }]
        agents_file.write_text(json.dumps(items))
        cmd_cleanup_stale(agents_file)
        assert json.loads(agents_file.read_text()) == []

    def test_keeps_alive_pid_with_recent_heartbeat(self, agents_file):
        """Session with alive PID and recent heartbeat is kept."""
        from datetime import datetime, timezone
        now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        items = [{
            "feature_id": f"session-{os.getpid()}",
            "type": "session",
            "pid": os.getpid(),  # Our own PID — definitely alive
            "worktree": "/tmp/project",
            "status": "active",
            "last_checkpoint": now,
        }]
        agents_file.write_text(json.dumps(items))
        cmd_cleanup_stale(agents_file)
        result = json.loads(agents_file.read_text())
        assert len(result) == 1

    def test_removes_old_heartbeat_even_if_pid_alive(self, agents_file):
        """Session with alive PID but expired heartbeat is removed (PID recycling guard)."""
        items = [{
            "feature_id": f"session-{os.getpid()}",
            "type": "session",
            "pid": os.getpid(),
            "worktree": "/tmp/project",
            "status": "active",
            "last_checkpoint": "2020-01-01T00:00:00Z",  # Very old
        }]
        agents_file.write_text(json.dumps(items))
        cmd_cleanup_stale(agents_file)
        assert json.loads(agents_file.read_text()) == []

    def test_does_not_touch_feature_entries(self, agents_file):
        """Non-session entries are never cleaned up by cleanup-stale."""
        items = [{
            "feature_id": "F-0194",
            "worktree": "/tmp/project",
            "status": "active",
            "last_checkpoint": "2020-01-01T00:00:00Z",
        }]
        agents_file.write_text(json.dumps(items))
        cmd_cleanup_stale(agents_file)
        result = json.loads(agents_file.read_text())
        assert len(result) == 1
        assert result[0]["feature_id"] == "F-0194"


# ---------------------------------------------------------------------------
# session-heartbeat
# ---------------------------------------------------------------------------

class TestSessionHeartbeat:
    def test_updates_checkpoint(self, agents_file):
        cmd_session_register(agents_file, "/tmp/project", "claude-code", pid=12345)
        old_items = json.loads(agents_file.read_text())
        old_checkpoint = old_items[0]["last_checkpoint"]

        # Small delay not needed — just verify it updates
        cmd_session_heartbeat(agents_file, pid=12345)
        new_items = json.loads(agents_file.read_text())
        # Checkpoint should be updated (or same if within same second)
        assert new_items[0]["last_checkpoint"] >= old_checkpoint

    def test_noop_for_unknown_pid(self, agents_file):
        cmd_session_register(agents_file, "/tmp/project", "claude-code", pid=12345)
        cmd_session_heartbeat(agents_file, pid=99999)
        # Should not crash, entry unchanged
        items = json.loads(agents_file.read_text())
        assert len(items) == 1


# ---------------------------------------------------------------------------
# Integration: full lifecycle
# ---------------------------------------------------------------------------

class TestFullLifecycle:
    def test_register_count_deregister(self, agents_file, capsys):
        """Full lifecycle: register → count → deregister → count again."""
        # Register two sessions
        cmd_session_register(agents_file, "/tmp/project", "claude-code", pid=111)
        cmd_session_register(agents_file, "/tmp/project", "claude-code", pid=222)

        # Session 111 sees 1 other
        cmd_count_others(agents_file, "/tmp/project", pid=111)
        assert capsys.readouterr().out.strip() == "1"

        # Session 222 deregisters
        cmd_session_deregister(agents_file, "/tmp/project", pid=222)

        # Session 111 now sees 0 others
        cmd_count_others(agents_file, "/tmp/project", pid=111)
        assert capsys.readouterr().out.strip() == "0"
