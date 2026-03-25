#!/usr/bin/env python3
"""
Tests for phase_detect.py - validates phase detection logic.
"""
import sys
import tempfile
from pathlib import Path

# Add .agentic/lib/tools to path
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "tools"))

from phase_detect import detect_phase

# Import get_setting for profile resolution testing
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))
from settings import get_setting, _cache


def _clear_settings_cache():
    """Clear module-level settings cache between tests."""
    _cache.clear()


def _create_formal_stack(root: Path):
    """Create a STACK.md with feature_tracking=yes for formal-like behavior."""
    (root / "STACK.md").write_text(
        "## Settings\n- profile: formal\n- feature_tracking: yes\n"
    )


def test_discovery_profile_returns_no_feature_tracking():
    """Discovery profile (no feature tracking) should return 'no-feature-tracking'."""
    _clear_settings_cache()
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        (root / "STACK.md").write_text("- Profile: discovery\n")
        assert detect_phase(root) == "no-feature-tracking"


def test_no_wip_returns_start():
    """No WIP.md should return 'start'."""
    _clear_settings_cache()
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        _create_formal_stack(root)
        (root / ".agentic" / "spec").mkdir(parents=True)
        (root / ".agentic" / "STATUS.md").write_text("# Status\n")
        assert detect_phase(root) == "start"


def test_wip_without_acceptance_returns_planning():
    """.agentic/session/WIP.md with feature but no acceptance file should return 'planning'."""
    _clear_settings_cache()
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        _create_formal_stack(root)
        (root / ".agentic" / "spec" / "acceptance").mkdir(parents=True)
        (root / ".agentic" / "STATUS.md").write_text("# Status\n")
        (root / ".agentic" / "session").mkdir(parents=True, exist_ok=True)
        (root / ".agentic" / "session" / "WIP.md").write_text("**Feature**: F-001: Test feature\n")
        assert detect_phase(root) == "planning"


def test_wip_with_acceptance_returns_implement():
    """.agentic/session/WIP.md with feature and acceptance file should return 'implement'."""
    _clear_settings_cache()
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        _create_formal_stack(root)
        (root / ".agentic" / "spec" / "acceptance").mkdir(parents=True)
        (root / ".agentic" / "STATUS.md").write_text("# Status\n")
        (root / ".agentic" / "session").mkdir(parents=True, exist_ok=True)
        (root / ".agentic" / "session" / "WIP.md").write_text("**Feature**: F-001: Test feature\n")
        (root / ".agentic" / "spec" / "acceptance" / "F-001.md").write_text("# Acceptance\n")
        assert detect_phase(root) == "implement"


def test_blocker_returns_blocked():
    """HUMAN_NEEDED.md with blocker should return 'blocked'."""
    _clear_settings_cache()
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        _create_formal_stack(root)
        (root / ".agentic" / "spec").mkdir(parents=True)
        (root / ".agentic" / "STATUS.md").write_text("# Status\n")
        (root / ".agentic" / "HUMAN_NEEDED.md").write_text("## HN-0001: Need help\n")
        assert detect_phase(root) == "blocked"


def test_profile_defaults():
    """Test profile detection defaults via get_setting."""
    _clear_settings_cache()
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        assert get_setting(root, "profile", "discovery") == "discovery"

    _clear_settings_cache()
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        (root / "spec").mkdir()
        assert get_setting(root, "profile", "discovery") == "formal"


if __name__ == "__main__":
    test_discovery_profile_returns_no_feature_tracking()
    test_no_wip_returns_start()
    test_wip_without_acceptance_returns_planning()
    test_wip_with_acceptance_returns_implement()
    test_blocker_returns_blocked()
    test_profile_defaults()
    print("✓ All phase_detect tests passed")
