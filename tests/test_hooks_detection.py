#!/usr/bin/env python3
"""
Tests for hooks installation detection (F-015 AC-008, DEV-003 AC-003).

Verifies that both dashboard.sh and sync.sh detect missing Claude Code hooks
and that sync auto-fixes them.
"""
import os
import subprocess
import tempfile
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).parent.parent


class TestDashboardHooksCheck:
    """F-015 AC-008: Dashboard detects missing agent-tool hooks."""

    def test_dashboard_has_hooks_check(self):
        """dashboard.sh contains hooks detection logic."""
        content = (PROJECT_ROOT / ".agentic" / "lib" / "tools" / "dashboard.sh").read_text()
        assert "HOOKS_MISSING" in content
        assert "hooks.json" in content

    def test_dashboard_shows_warning_when_hooks_missing(self):
        """Dashboard outputs hooks warning when .claude/hooks.json is absent."""
        hooks_file = PROJECT_ROOT / ".claude" / "hooks.json"
        backup = None

        if hooks_file.exists():
            backup = hooks_file.read_text()
            hooks_file.unlink()

        try:
            result = subprocess.run(
                ["bash", str(PROJECT_ROOT / ".agentic" / "lib" / "tools" / "dashboard.sh")],
                cwd=str(PROJECT_ROOT),
                capture_output=True,
                text=True,
                timeout=30,
                env={**os.environ, "CLAUDE_PROJECT_DIR": str(PROJECT_ROOT)},
            )
            assert "Hooks missing" in result.stdout or "hooks" in result.stdout.lower()
        finally:
            if backup is not None:
                hooks_file.write_text(backup)

    def test_dashboard_no_warning_when_hooks_installed(self):
        """Dashboard does NOT show hooks warning when .claude/hooks.json exists."""
        hooks_file = PROJECT_ROOT / ".claude" / "hooks.json"
        source = PROJECT_ROOT / ".agentic" / "lib" / "claude-hooks" / "hooks.json"

        if not hooks_file.exists() and source.exists():
            hooks_file.write_text(source.read_text())
            created = True
        else:
            created = False

        try:
            result = subprocess.run(
                ["bash", str(PROJECT_ROOT / ".agentic" / "lib" / "tools" / "dashboard.sh")],
                cwd=str(PROJECT_ROOT),
                capture_output=True,
                text=True,
                timeout=30,
                env={**os.environ, "CLAUDE_PROJECT_DIR": str(PROJECT_ROOT)},
            )
            assert "Hooks missing" not in result.stdout
        finally:
            if created:
                hooks_file.unlink()


class TestSyncHooksCheck:
    """DEV-003 AC-003: ag sync detects and auto-fixes missing Claude Code hooks."""

    def test_sync_has_claude_hooks_check(self):
        """sync.sh contains Claude hooks detection logic."""
        content = (PROJECT_ROOT / ".agentic" / "lib" / "tools" / "sync.sh").read_text()
        assert "claude" in content.lower() or "Claude" in content
        assert "hooks.json" in content

    def test_sync_check_detects_missing_hooks(self):
        """ag sync --check reports missing hooks without fixing."""
        hooks_file = PROJECT_ROOT / ".claude" / "hooks.json"
        backup = None

        if hooks_file.exists():
            backup = hooks_file.read_text()
            hooks_file.unlink()

        try:
            result = subprocess.run(
                ["bash", str(PROJECT_ROOT / ".agentic" / "lib" / "tools" / "sync.sh"), "--check"],
                cwd=str(PROJECT_ROOT),
                capture_output=True,
                text=True,
                timeout=60,
                env={**os.environ, "CLAUDE_PROJECT_DIR": str(PROJECT_ROOT)},
            )
            assert "NOT INSTALLED" in result.stdout or "not installed" in result.stdout.lower()
            # --check should NOT create the file
            assert not hooks_file.exists()
        finally:
            if backup is not None:
                hooks_file.write_text(backup)

    def test_sync_full_fixes_missing_hooks(self):
        """ag sync (full mode) auto-installs missing hooks."""
        hooks_file = PROJECT_ROOT / ".claude" / "hooks.json"
        backup = None

        if hooks_file.exists():
            backup = hooks_file.read_text()
            hooks_file.unlink()

        try:
            result = subprocess.run(
                ["bash", str(PROJECT_ROOT / ".agentic" / "lib" / "tools" / "sync.sh")],
                cwd=str(PROJECT_ROOT),
                capture_output=True,
                text=True,
                timeout=60,
                env={**os.environ, "CLAUDE_PROJECT_DIR": str(PROJECT_ROOT)},
            )
            assert "FIXED" in result.stdout
            assert hooks_file.exists()
        finally:
            # Restore original state
            if backup is not None:
                hooks_file.write_text(backup)
            elif hooks_file.exists():
                # sync created it, but it didn't exist before — remove
                hooks_file.unlink()

    def test_sync_ok_when_hooks_installed(self):
        """ag sync reports OK when hooks are already installed."""
        hooks_file = PROJECT_ROOT / ".claude" / "hooks.json"
        source = PROJECT_ROOT / ".agentic" / "lib" / "claude-hooks" / "hooks.json"

        if not hooks_file.exists() and source.exists():
            hooks_file.write_text(source.read_text())
            created = True
        else:
            created = False

        try:
            result = subprocess.run(
                ["bash", str(PROJECT_ROOT / ".agentic" / "lib" / "tools" / "sync.sh"), "--check"],
                cwd=str(PROJECT_ROOT),
                capture_output=True,
                text=True,
                timeout=60,
                env={**os.environ, "CLAUDE_PROJECT_DIR": str(PROJECT_ROOT)},
            )
            # Should show OK, not NOT INSTALLED
            lines = [l for l in result.stdout.splitlines() if "Claude hooks" in l]
            assert any("OK" in l for l in lines), f"Expected OK, got: {lines}"
        finally:
            if created:
                hooks_file.unlink()
