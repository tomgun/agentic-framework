#!/usr/bin/env python3
"""
Tests for gate functions (ADR-001 Phase 1).

Covers all 8 forward transition gates and the registration mechanism.
"""
import sys
import tempfile
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "auto"))

from auto.gates import (
    GateResult,
    DEFAULT_GATES,
    gate_planned_to_specced,
    gate_specced_to_criteria_set,
    gate_criteria_set_to_tests_written,
    gate_tests_written_to_implementing,
    gate_implementing_to_verified,
    gate_verified_to_documented,
    gate_documented_to_committed,
    gate_committed_to_shipped,
    register_default_gates,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def project_dir():
    """Temporary project with FEATURES.md and paths infrastructure."""
    # Clear settings module cache to avoid stale data across tests
    from settings import _cache
    _cache.clear()

    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        (root / ".agentic" / "lib").mkdir(parents=True)
        (root / ".agentic" / "spec" / "acceptance").mkdir(parents=True)
        (root / ".agentic" / "session").mkdir(parents=True)
        (root / "tests").mkdir(parents=True)
        lib_src = Path(__file__).parent.parent / ".agentic" / "lib"
        for f in ["paths.py", "settings.py"]:
            src = lib_src / f
            if src.exists():
                (root / ".agentic" / "lib" / f).write_text(src.read_text())
        (root / "STACK.md").write_text("## Settings\n- profile: formal\n")

        # Default FEATURES.md with a test feature
        features_content = """# Features

## F-0042: Test Feature

**Status**: planned
**Category**: Test

**Description**: A test feature for gate testing.

---
"""
        (root / ".agentic" / "spec" / "FEATURES.md").write_text(features_content)
        yield root


# ---------------------------------------------------------------------------
# GateResult
# ---------------------------------------------------------------------------

class TestGateResult:
    def test_ok(self):
        r = GateResult.ok()
        assert r.allowed
        assert r.reasons == []
        assert r.warnings == []

    def test_ok_with_warnings(self):
        r = GateResult.ok(["heads up"])
        assert r.allowed
        assert r.warnings == ["heads up"]

    def test_blocked(self):
        r = GateResult.blocked(["must fix"])
        assert not r.allowed
        assert r.reasons == ["must fix"]

    def test_merge_both_ok(self):
        a = GateResult.ok(["w1"])
        b = GateResult.ok(["w2"])
        merged = a.merge(b)
        assert merged.allowed
        assert merged.warnings == ["w1", "w2"]

    def test_merge_one_blocked(self):
        a = GateResult.ok()
        b = GateResult.blocked(["fail"])
        merged = a.merge(b)
        assert not merged.allowed


# ---------------------------------------------------------------------------
# Gate 1: planned -> specced
# ---------------------------------------------------------------------------

class TestGatePlannedToSpecced:
    def test_passes_with_description(self, project_dir):
        r = gate_planned_to_specced("F-0042", project_dir)
        assert r.allowed

    def test_fails_without_feature(self, project_dir):
        r = gate_planned_to_specced("F-9999", project_dir)
        assert not r.allowed
        assert any("not found" in reason for reason in r.reasons)

    def test_fails_without_description(self, project_dir):
        features = """# Features

## F-0042: No Desc

**Status**: planned
**Category**: Test

---
"""
        (project_dir / ".agentic" / "spec" / "FEATURES.md").write_text(features)
        r = gate_planned_to_specced("F-0042", project_dir)
        assert not r.allowed
        assert any("Description" in reason for reason in r.reasons)


# ---------------------------------------------------------------------------
# Gate 2: specced -> criteria_set
# ---------------------------------------------------------------------------

class TestGateSpeccedToCriteriaSet:
    def test_passes_with_ac_file(self, project_dir):
        ac_content = """# F-0042 Acceptance Criteria

- [ ] **AC-01**: Must do X
- [ ] **AC-02**: Must do Y
"""
        (project_dir / ".agentic" / "spec" / "acceptance" / "F-0042.md").write_text(ac_content)
        r = gate_specced_to_criteria_set("F-0042", project_dir)
        assert r.allowed

    def test_fails_without_ac_file(self, project_dir):
        r = gate_specced_to_criteria_set("F-0042", project_dir)
        assert not r.allowed
        assert any("missing" in reason.lower() for reason in r.reasons)

    def test_fails_with_empty_ac_file(self, project_dir):
        (project_dir / ".agentic" / "spec" / "acceptance" / "F-0042.md").write_text(
            "# F-0042 Acceptance Criteria\n\nNo criteria yet.\n"
        )
        r = gate_specced_to_criteria_set("F-0042", project_dir)
        assert not r.allowed
        assert any("No acceptance criteria" in reason for reason in r.reasons)


# ---------------------------------------------------------------------------
# Gate 3: criteria_set -> tests_written
# ---------------------------------------------------------------------------

class TestGateCriteriaSetToTestsWritten:
    def test_passes_with_test_referencing_feature(self, project_dir):
        (project_dir / "tests" / "test_f0042.py").write_text(
            '"""Tests for F-0042."""\ndef test_feature(): pass\n'
        )
        r = gate_criteria_set_to_tests_written("F-0042", project_dir)
        assert r.allowed

    def test_fails_without_test_file(self, project_dir):
        r = gate_criteria_set_to_tests_written("F-0042", project_dir)
        assert not r.allowed
        assert any("No test files" in reason for reason in r.reasons)

    def test_passes_with_test_in_subdirectory(self, project_dir):
        (project_dir / "tests" / "unit").mkdir()
        (project_dir / "tests" / "unit" / "test_auth.py").write_text(
            "# Tests for F-0042 authentication\n"
        )
        r = gate_criteria_set_to_tests_written("F-0042", project_dir)
        assert r.allowed


# ---------------------------------------------------------------------------
# Gate 4: tests_written -> implementing
# ---------------------------------------------------------------------------

class TestGateTestsWrittenToImplementing:
    def test_always_allows_with_advisory(self, project_dir):
        r = gate_tests_written_to_implementing("F-0042", project_dir)
        assert r.allowed
        assert len(r.warnings) > 0  # should have advisory messages


# ---------------------------------------------------------------------------
# Gate 5: implementing -> verified
# ---------------------------------------------------------------------------

class TestGateImplementingToVerified:
    def test_passes_with_ac_file_and_tests(self, project_dir):
        (project_dir / ".agentic" / "spec" / "acceptance" / "F-0042.md").write_text(
            "# AC\n- [ ] **AC-01**: X\n"
        )
        (project_dir / "tests" / "test_f0042.py").write_text(
            "# Tests for F-0042\n"
        )
        r = gate_implementing_to_verified("F-0042", project_dir)
        assert r.allowed

    def test_fails_without_ac_file(self, project_dir):
        (project_dir / "tests" / "test_f0042.py").write_text(
            "# Tests for F-0042\n"
        )
        r = gate_implementing_to_verified("F-0042", project_dir)
        assert not r.allowed


# ---------------------------------------------------------------------------
# Gate 6: verified -> documented
# ---------------------------------------------------------------------------

class TestGateVerifiedToDocumented:
    def test_docs_gate_off_skips_all(self, project_dir):
        """docs_gate=off should skip all checks and return ok."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- docs_gate: off\n"
        )
        r = gate_verified_to_documented("F-0042", project_dir)
        assert r.allowed
        assert r.warnings == []
        assert r.reasons == []

    def test_docs_gate_warning_allows_with_warnings(self, project_dir):
        """docs_gate=warning should allow but emit warnings when CHANGELOG missing."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- docs_gate: warning\n"
        )
        (project_dir / "CHANGELOG.md").write_text("# Changelog\n\n## v0.1.0\n- stuff\n")
        r = gate_verified_to_documented("F-0042", project_dir)
        assert r.allowed
        assert any("CHANGELOG" in w for w in r.warnings)

    def test_docs_gate_blocking_blocks_changelog_without_drift_script(self, project_dir):
        """docs_gate=blocking without drift.sh blocks on missing CHANGELOG entry."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- docs_gate: blocking\n"
        )
        (project_dir / "CHANGELOG.md").write_text("# Changelog\n\n## v0.1.0\n- stuff\n")
        # drift.sh won't exist in temp dir, so drift check is skipped
        # but CHANGELOG check still fires as a blocker
        r = gate_verified_to_documented("F-0042", project_dir)
        assert not r.allowed
        assert any("CHANGELOG" in reason for reason in r.reasons)

    def test_docs_gate_blocking_blocks_when_drift_found(self, project_dir):
        """docs_gate=blocking with a drift.sh that exits non-zero should block."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- docs_gate: blocking\n"
        )
        # Create a fake drift.sh that always reports drift (exit 1)
        tools_dir = project_dir / ".agentic" / "lib" / "tools"
        tools_dir.mkdir(parents=True, exist_ok=True)
        (tools_dir / "drift.sh").write_text(
            '#!/usr/bin/env bash\necho "stale docs found"\nexit 1\n'
        )
        (tools_dir / "drift.sh").chmod(0o755)
        r = gate_verified_to_documented("F-0042", project_dir)
        assert not r.allowed
        assert any("drift" in reason.lower() for reason in r.reasons)

    def test_docs_gate_default_off(self, project_dir):
        """Default docs_gate should be 'off' (discovery profile default)."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: discovery\n"
        )
        r = gate_verified_to_documented("F-0042", project_dir)
        assert r.allowed

    def test_warns_when_changelog_missing_feature(self, project_dir):
        """docs_gate=warning should warn about CHANGELOG missing feature."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- docs_gate: warning\n"
        )
        (project_dir / "CHANGELOG.md").write_text("# Changelog\n\n## v0.1.0\n- stuff\n")
        r = gate_verified_to_documented("F-0042", project_dir)
        assert r.allowed
        assert any("CHANGELOG" in w for w in r.warnings)

    def test_no_changelog_warning_when_feature_present(self, project_dir):
        """No CHANGELOG warning when feature is mentioned."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- docs_gate: warning\n"
        )
        (project_dir / "CHANGELOG.md").write_text(
            "# Changelog\n\n## v0.1.0\n- F-0042: Added feature\n"
        )
        r = gate_verified_to_documented("F-0042", project_dir)
        assert r.allowed
        assert not any("CHANGELOG" in w for w in r.warnings)

    def test_changelog_blocks_when_docs_gate_blocking(self, project_dir):
        """docs_gate=blocking blocks when CHANGELOG doesn't mention feature."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- docs_gate: blocking\n"
        )
        (project_dir / "CHANGELOG.md").write_text(
            "# Changelog\n\n## v0.1.0\n- unrelated stuff\n"
        )
        r = gate_verified_to_documented("F-0042", project_dir)
        assert not r.allowed
        assert any("CHANGELOG" in reason for reason in r.reasons)

    def test_changelog_warns_when_docs_gate_warning(self, project_dir):
        """docs_gate=warning warns but allows when CHANGELOG missing feature."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- docs_gate: warning\n"
        )
        (project_dir / "CHANGELOG.md").write_text(
            "# Changelog\n\n## v0.1.0\n- unrelated stuff\n"
        )
        r = gate_verified_to_documented("F-0042", project_dir)
        assert r.allowed
        assert any("CHANGELOG" in w for w in r.warnings)

    def test_journal_freshness_advisory(self, project_dir):
        """Stale journal emits advisory warning."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- docs_gate: warning\n"
        )
        journal_dir = project_dir / ".agentic" / "journal"
        journal_dir.mkdir(parents=True, exist_ok=True)
        (journal_dir / "JOURNAL.md").write_text(
            "# Journal\n\n## 2020-01-01\nOld entry\n"
        )
        r = gate_verified_to_documented("F-0042", project_dir)
        assert r.allowed
        assert any("JOURNAL" in w for w in r.warnings)


# ---------------------------------------------------------------------------
# Gate 7: documented -> committed
# ---------------------------------------------------------------------------

class TestGateDocumentedToCommitted:
    def test_blocks_dirty_tree(self, project_dir):
        """Dirty working tree blocks transition to committed."""
        # Create a git repo with uncommitted changes
        import subprocess
        subprocess.run(["git", "init"], cwd=str(project_dir), capture_output=True)
        subprocess.run(["git", "add", "."], cwd=str(project_dir), capture_output=True)
        subprocess.run(
            ["git", "commit", "-m", "init"],
            cwd=str(project_dir), capture_output=True,
            env={**__import__("os").environ, "GIT_AUTHOR_NAME": "test",
                 "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "test",
                 "GIT_COMMITTER_EMAIL": "t@t"},
        )
        # Create uncommitted file
        (project_dir / "dirty.txt").write_text("uncommitted")
        r = gate_documented_to_committed("F-0042", project_dir)
        assert not r.allowed
        assert any("uncommitted" in reason.lower() for reason in r.reasons)

    def test_allows_clean_tree(self, project_dir):
        """Clean working tree with feature commit passes."""
        import subprocess, os
        env = {**os.environ, "GIT_AUTHOR_NAME": "test",
               "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "test",
               "GIT_COMMITTER_EMAIL": "t@t"}
        subprocess.run(["git", "init"], cwd=str(project_dir), capture_output=True)
        subprocess.run(["git", "add", "."], cwd=str(project_dir), capture_output=True)
        subprocess.run(
            ["git", "commit", "-m", "F-0042: initial"],
            cwd=str(project_dir), capture_output=True, env=env,
        )
        r = gate_documented_to_committed("F-0042", project_dir)
        assert r.allowed

    def test_blocks_no_feature_commits(self, project_dir):
        """No commits referencing the feature blocks transition."""
        import subprocess, os
        env = {**os.environ, "GIT_AUTHOR_NAME": "test",
               "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "test",
               "GIT_COMMITTER_EMAIL": "t@t"}
        subprocess.run(["git", "init"], cwd=str(project_dir), capture_output=True)
        subprocess.run(["git", "add", "."], cwd=str(project_dir), capture_output=True)
        subprocess.run(
            ["git", "commit", "-m", "unrelated commit"],
            cwd=str(project_dir), capture_output=True, env=env,
        )
        r = gate_documented_to_committed("F-0042", project_dir)
        assert not r.allowed
        assert any("No commits reference" in reason for reason in r.reasons)

    def test_allows_with_feature_commits(self, project_dir):
        """Commit referencing feature allows transition."""
        import subprocess, os
        env = {**os.environ, "GIT_AUTHOR_NAME": "test",
               "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "test",
               "GIT_COMMITTER_EMAIL": "t@t"}
        subprocess.run(["git", "init"], cwd=str(project_dir), capture_output=True)
        subprocess.run(["git", "add", "."], cwd=str(project_dir), capture_output=True)
        subprocess.run(
            ["git", "commit", "-m", "feat(F-0042): implement feature"],
            cwd=str(project_dir), capture_output=True, env=env,
        )
        r = gate_documented_to_committed("F-0042", project_dir)
        assert r.allowed

    def test_handles_git_error_gracefully(self, project_dir):
        """Subprocess errors produce warnings, not crashes."""
        # Create .git so the gate doesn't block on missing git dir
        (project_dir / ".git").mkdir(exist_ok=True)
        from unittest.mock import patch
        with patch("auto.gates.subprocess.run", side_effect=OSError("mock error")):
            r = gate_documented_to_committed("F-0042", project_dir)
            # Subprocess errors → warnings (graceful degradation)
            assert r.allowed
            assert any("mock error" in w for w in r.warnings)

    def test_no_git_dir_blocks(self, project_dir):
        """Missing .git directory blocks transition."""
        import shutil
        git_dir = project_dir / ".git"
        if git_dir.exists():
            shutil.rmtree(git_dir)
        r = gate_documented_to_committed("F-0042", project_dir)
        assert not r.allowed
        assert any("Not a git repository" in reason for reason in r.reasons)


# ---------------------------------------------------------------------------
# Gate 8: committed -> shipped
# ---------------------------------------------------------------------------

class TestGateCommittedToShipped:
    def test_blocks_no_merged_pr(self, project_dir):
        """No merged PR blocks shipping in pull_request mode."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- git_workflow: pull_request\n"
        )
        from unittest.mock import patch, MagicMock
        mock_proc = MagicMock()
        mock_proc.returncode = 0
        mock_proc.stdout = "[]"
        with patch("auto.gates.subprocess.run", return_value=mock_proc):
            r = gate_committed_to_shipped("F-0042", project_dir)
        assert not r.allowed
        assert any("No merged PR" in reason for reason in r.reasons)

    def test_allows_merged_pr(self, project_dir):
        """Merged PR allows shipping in pull_request mode."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- git_workflow: pull_request\n"
        )
        from unittest.mock import patch, MagicMock
        mock_proc = MagicMock()
        mock_proc.returncode = 0
        mock_proc.stdout = '[{"number": 42}]'
        with patch("auto.gates.subprocess.run", return_value=mock_proc):
            r = gate_committed_to_shipped("F-0042", project_dir)
        assert r.allowed

    def test_discovery_skips_pr_check(self, project_dir):
        """Discovery profile with no git_workflow defaults to pull_request."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: discovery\n- git_workflow: direct\n"
        )
        from unittest.mock import patch, MagicMock
        # In direct mode, check for unpushed commits — mock clean state
        mock_proc = MagicMock()
        mock_proc.returncode = 0
        mock_proc.stdout = ""  # no unpushed commits
        with patch("auto.gates.subprocess.run", return_value=mock_proc):
            r = gate_committed_to_shipped("F-0042", project_dir)
        assert r.allowed

    def test_blocks_unpushed_direct(self, project_dir):
        """Unpushed commits block shipping in direct mode."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- git_workflow: direct\n"
        )
        from unittest.mock import patch, MagicMock
        mock_proc = MagicMock()
        mock_proc.returncode = 0
        mock_proc.stdout = "abc1234 some commit"
        with patch("auto.gates.subprocess.run", return_value=mock_proc):
            r = gate_committed_to_shipped("F-0042", project_dir)
        assert not r.allowed
        assert any("Unpushed" in reason for reason in r.reasons)

    def test_handles_gh_unavailable(self, project_dir):
        """Missing gh CLI produces warning, not block."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- git_workflow: pull_request\n"
        )
        from unittest.mock import patch
        with patch("auto.gates.subprocess.run", side_effect=FileNotFoundError("gh not found")):
            r = gate_committed_to_shipped("F-0042", project_dir)
        assert r.allowed
        assert any("gh CLI not available" in w for w in r.warnings)


# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------

class TestRegistration:
    def test_default_gates_covers_all_forward_transitions(self):
        assert len(DEFAULT_GATES) == 8
        from_to_pairs = [(f, t) for f, t, _ in DEFAULT_GATES]
        assert ("planned", "specced") in from_to_pairs
        assert ("committed", "shipped") in from_to_pairs

    def test_register_default_gates_on_state_machine(self, project_dir):
        from auto.state_machine import FeatureStateMachine, FeatureState
        sm = FeatureStateMachine(project_root=project_dir)
        register_default_gates(sm)
        # Check that the state machine has the gate registered
        result = sm.check_gate(
            "F-0042", FeatureState.PLANNED, FeatureState.SPECCED,
        )
        assert isinstance(result, GateResult)
