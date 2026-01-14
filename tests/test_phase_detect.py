#!/usr/bin/env python3
"""
Tests for phase_detect.py - validates phase detection logic.
"""
import sys
import tempfile
from pathlib import Path

# Add .agentic/tools to path
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "tools"))

from phase_detect import detect_phase, read_profile


def test_core_profile_returns_core_mode():
    """Core profile should return 'core-mode'."""
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        # Create minimal STACK.md with core profile
        (root / "STACK.md").write_text("- Profile: core\n")

        assert detect_phase(root) == "core-mode"


def test_no_wip_returns_start():
    """No WIP.md should return 'start'."""
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        # Create core+product profile indicators
        (root / "spec").mkdir()
        (root / "STATUS.md").write_text("# Status\n")

        assert detect_phase(root) == "start"


def test_wip_without_acceptance_returns_planning():
    """WIP.md with feature but no acceptance file should return 'planning'."""
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        # Setup core+product
        (root / "spec").mkdir()
        (root / "spec" / "acceptance").mkdir()
        (root / "STATUS.md").write_text("# Status\n")
        # Create WIP.md with feature
        (root / "WIP.md").write_text("**Feature**: F-0001: Test feature\n")

        assert detect_phase(root) == "planning"


def test_wip_with_acceptance_returns_implement():
    """WIP.md with feature and acceptance file should return 'implement'."""
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        # Setup core+product
        (root / "spec").mkdir()
        (root / "spec" / "acceptance").mkdir()
        (root / "STATUS.md").write_text("# Status\n")
        # Create WIP.md with feature
        (root / "WIP.md").write_text("**Feature**: F-0001: Test feature\n")
        # Create acceptance file
        (root / "spec" / "acceptance" / "F-0001.md").write_text("# Acceptance\n")

        assert detect_phase(root) == "implement"


def test_blocker_returns_blocked():
    """HUMAN_NEEDED.md with blocker should return 'blocked'."""
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        # Setup core+product
        (root / "spec").mkdir()
        (root / "STATUS.md").write_text("# Status\n")
        # Create blocker
        (root / "HUMAN_NEEDED.md").write_text("## HN-0001: Need help\n")

        assert detect_phase(root) == "blocked"


def test_read_profile_defaults():
    """Test profile detection defaults."""
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        # No indicators = core
        assert read_profile(root) == "core"

        # spec/ dir = core+product
        (root / "spec").mkdir()
        assert read_profile(root) == "core+product"


if __name__ == "__main__":
    test_core_profile_returns_core_mode()
    test_no_wip_returns_start()
    test_wip_without_acceptance_returns_planning()
    test_wip_with_acceptance_returns_implement()
    test_blocker_returns_blocked()
    test_read_profile_defaults()
    print("✓ All phase_detect tests passed")
