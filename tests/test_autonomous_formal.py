#!/usr/bin/env python3
"""
Tests for the autonomous_formal profile (F-029, ADR-001 Phase 3).

Covers:
- Profile loads all 30 settings from profiles.conf
- Review defaults match ADR table (only review_code and review_regression differ from formal)
- is_formal_like() helper in settings.py
- Profile validation rejects invalid profiles
- Round-trip: write to STACK.md, read back via settings.py
"""
import subprocess
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))

from settings import get_setting, is_formal_like, _load_profile_presets, _cache


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(autouse=True)
def clear_caches():
    """Clear settings caches between tests."""
    yield
    _cache.clear()


@pytest.fixture
def project_dir():
    """Temporary project directory with settings infrastructure."""
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        (root / ".agentic" / "lib").mkdir(parents=True)
        (root / ".agentic" / "spec" / "acceptance").mkdir(parents=True)

        # Copy settings infrastructure
        lib_src = Path(__file__).parent.parent / ".agentic" / "lib"
        for f in ["paths.py", "settings.py"]:
            src = lib_src / f
            if src.exists():
                (root / ".agentic" / "lib" / f).write_text(src.read_text())

        # Copy profiles.conf
        presets_dir = root / ".agentic" / "presets"
        presets_dir.mkdir(parents=True)
        profiles_src = lib_src / "presets" / "profiles.conf"
        if profiles_src.exists():
            (presets_dir / "profiles.conf").write_text(profiles_src.read_text())

        # Default STACK.md with autonomous_formal profile
        (root / "STACK.md").write_text(
            "## Settings\n- profile: autonomous_formal\n"
        )
        yield root


# ---------------------------------------------------------------------------
# TestIsFormalLike
# ---------------------------------------------------------------------------

class TestIsFormalLike:
    def test_formal_returns_true(self):
        assert is_formal_like("formal") is True

    def test_autonomous_formal_returns_true(self):
        assert is_formal_like("autonomous_formal") is True

    def test_discovery_returns_false(self):
        assert is_formal_like("discovery") is False

    def test_empty_returns_false(self):
        assert is_formal_like("") is False

    def test_bogus_returns_false(self):
        assert is_formal_like("bogus") is False


# ---------------------------------------------------------------------------
# TestAutonomousFormalProfileLoads
# ---------------------------------------------------------------------------

class TestAutonomousFormalProfileLoads:
    def test_profile_resolves(self, project_dir):
        """autonomous_formal profile resolves from STACK.md."""
        profile = get_setting(project_dir, "profile")
        assert profile == "autonomous_formal"

    def test_all_settings_resolve(self, project_dir):
        """All 30 settings from profiles.conf resolve for autonomous_formal."""
        presets_path = project_dir / ".agentic" / "presets" / "profiles.conf"
        presets = _load_profile_presets(presets_path)
        af_settings = presets.get("autonomous_formal", {})

        # Must have at least 30 settings defined
        assert len(af_settings) >= 30, (
            f"Expected 30+ settings, got {len(af_settings)}: {sorted(af_settings.keys())}"
        )

        # Each setting should resolve correctly via get_setting
        for key, expected in af_settings.items():
            actual = get_setting(project_dir, key)
            assert actual == expected, (
                f"Setting '{key}': expected '{expected}', got '{actual}'"
            )


# ---------------------------------------------------------------------------
# TestAutonomousFormalReviewDefaults
# ---------------------------------------------------------------------------

class TestAutonomousFormalReviewDefaults:
    """Verify review checkpoints match ADR-001 table."""

    EXPECTED_REVIEWS = {
        "review_spec": "critical_agent",
        "review_criteria": "critical_agent",
        "review_plan": "critical_agent",
        "review_code": "critical_agent",
        "review_merge": "human",
        "review_decomposition": "critical_agent",
        "review_regression": "critical_agent",
        "review_taste": "critical_agent",
    }

    def test_review_defaults(self, project_dir):
        for setting, expected in self.EXPECTED_REVIEWS.items():
            actual = get_setting(project_dir, setting)
            assert actual == expected, (
                f"{setting}: expected '{expected}', got '{actual}'"
            )


# ---------------------------------------------------------------------------
# TestAutonomousFormalDiffFromFormal
# ---------------------------------------------------------------------------

class TestAutonomousFormalDiffFromFormal:
    """Verify only review_code and review_regression differ from formal."""

    def test_only_two_settings_differ(self, project_dir):
        presets_path = project_dir / ".agentic" / "presets" / "profiles.conf"
        presets = _load_profile_presets(presets_path)

        formal = presets.get("formal", {})
        autonomous_formal = presets.get("autonomous_formal", {})

        # Both profiles should have the same keys
        assert set(formal.keys()) == set(autonomous_formal.keys()), (
            f"Key mismatch.\n"
            f"Only in formal: {set(formal.keys()) - set(autonomous_formal.keys())}\n"
            f"Only in autonomous_formal: {set(autonomous_formal.keys()) - set(formal.keys())}"
        )

        # Find differences
        diffs = {
            k: (formal[k], autonomous_formal[k])
            for k in formal
            if formal[k] != autonomous_formal[k]
        }

        expected_diffs = {"review_code", "review_regression"}
        assert set(diffs.keys()) == expected_diffs, (
            f"Expected only {expected_diffs} to differ, but got: {diffs}"
        )

        # Verify the specific differences
        assert diffs["review_code"] == ("human", "critical_agent")
        assert diffs["review_regression"] == ("human", "critical_agent")


# ---------------------------------------------------------------------------
# TestInvalidProfileRejected
# ---------------------------------------------------------------------------

class TestInvalidProfileRejected:
    def test_bogus_profile_not_accepted(self, project_dir):
        """A bogus profile in STACK.md falls back to directory inference."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: bogus\n"
        )
        # Should fall back to inference (no spec dir → discovery)
        profile = get_setting(project_dir, "profile")
        assert profile == "discovery"

    def test_ag_set_rejects_bogus(self):
        """ag set profile bogus should fail (tested via shell)."""
        ag_sh = Path(__file__).parent.parent / ".agentic" / "lib" / "tools" / "ag.sh"
        if not ag_sh.exists():
            pytest.skip("ag.sh not found")

        result = subprocess.run(
            ["bash", str(ag_sh), "set", "profile", "bogus"],
            capture_output=True,
            text=True,
            cwd=str(Path(__file__).parent.parent),
        )
        assert result.returncode != 0
        assert "bogus" in result.stderr or "bogus" in result.stdout


# ---------------------------------------------------------------------------
# TestAutonomousFormalRoundTrip
# ---------------------------------------------------------------------------

class TestAutonomousFormalRoundTrip:
    def test_write_and_read_back(self, project_dir):
        """Write autonomous_formal to STACK.md, read back via settings.py."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: autonomous_formal\n"
        )
        assert get_setting(project_dir, "profile") == "autonomous_formal"

        # Verify formal-like behavior
        assert is_formal_like(get_setting(project_dir, "profile"))

        # Verify non-review settings match formal
        assert get_setting(project_dir, "feature_tracking") == "yes"
        assert get_setting(project_dir, "acceptance_criteria") == "blocking"
        assert get_setting(project_dir, "git_workflow") == "pull_request"
        assert get_setting(project_dir, "spec_directory") == "yes"


# ---------------------------------------------------------------------------
# TestScaffoldAutonomousFormal
# ---------------------------------------------------------------------------

class TestScaffoldAutonomousFormal:
    def test_scaffold_creates_spec_dirs(self, tmp_path):
        """Verify scaffold.sh with autonomous_formal creates formal-only state files."""
        # Set up minimal framework structure
        root = tmp_path / "project"
        root.mkdir()

        # Copy .agentic from the real framework
        src_agentic = Path(__file__).parent.parent / ".agentic"
        if not src_agentic.exists():
            pytest.skip(".agentic directory not found")

        import shutil
        shutil.copytree(str(src_agentic), str(root / ".agentic"))

        # Initialize git
        subprocess.run(
            ["git", "init"], cwd=str(root),
            capture_output=True, check=True,
        )

        result = subprocess.run(
            ["bash", ".agentic/lib/init/scaffold.sh",
             "--profile", "autonomous_formal", "--non-interactive"],
            cwd=str(root),
            capture_output=True,
            text=True,
            timeout=30,
        )

        assert result.returncode == 0, (
            f"scaffold.sh failed:\nstdout: {result.stdout}\nstderr: {result.stderr}"
        )

        # Verify formal-only directories and files were created
        assert (root / ".agentic" / "spec").is_dir(), "spec/ directory not created"
        assert (root / "STACK.md").exists(), "STACK.md not created"

        # Verify STACK.md has autonomous_formal profile
        stack_content = (root / "STACK.md").read_text()
        assert "autonomous_formal" in stack_content


# ---------------------------------------------------------------------------
# TestUpgradeAutonomousFormal
# ---------------------------------------------------------------------------

class TestUpgradeAutonomousFormal:
    def test_state_files_conf_formal_entries_created(self, project_dir):
        """Verify formal-only entries in state-files.conf are included
        for autonomous_formal (via is_formal_like)."""
        conf_path = (
            Path(__file__).parent.parent
            / ".agentic" / "lib" / "init" / "state-files.conf"
        )
        if not conf_path.exists():
            pytest.skip("state-files.conf not found")

        formal_entries = []
        for line in conf_path.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split(":")
            if len(parts) >= 3 and parts[2].strip() == "formal":
                formal_entries.append(parts[0])

        # These formal-only entries should all exist when is_formal_like is true
        assert len(formal_entries) > 0, "No formal-only entries in state-files.conf"

        # is_formal_like("autonomous_formal") should return True,
        # meaning these files would be created
        assert is_formal_like("autonomous_formal")

        # Verify specific expected formal-only files
        assert any("FEATURES" in e for e in formal_entries)
        assert any("NFR" in e for e in formal_entries)


# ---------------------------------------------------------------------------
# TestShellIsFormalLike
# ---------------------------------------------------------------------------

class TestShellIsFormalLike:
    """Test the shell is_formal_like() function via bash."""

    def _run_is_formal_like(self, profile):
        settings_sh = (
            Path(__file__).parent.parent / ".agentic" / "lib" / "settings.sh"
        )
        if not settings_sh.exists():
            pytest.skip("settings.sh not found")

        script = f"""
source "{settings_sh}"
if is_formal_like "{profile}"; then
    echo "true"
else
    echo "false"
fi
"""
        result = subprocess.run(
            ["bash", "-c", script],
            capture_output=True,
            text=True,
            timeout=5,
        )
        return result.stdout.strip()

    def test_formal_true(self):
        assert self._run_is_formal_like("formal") == "true"

    def test_autonomous_formal_true(self):
        assert self._run_is_formal_like("autonomous_formal") == "true"

    def test_discovery_false(self):
        assert self._run_is_formal_like("discovery") == "false"

    def test_bogus_false(self):
        assert self._run_is_formal_like("bogus") == "false"
