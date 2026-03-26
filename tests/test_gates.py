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
        assert any("no contract" in reason.lower() for reason in r.reasons)

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

    def test_docs_gate_blocking_blocks_changelog_missing_feature(self, project_dir):
        """docs_gate=blocking should BLOCK when CHANGELOG doesn't mention feature."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- docs_gate: blocking\n"
        )
        (project_dir / "CHANGELOG.md").write_text("# Changelog\n\n## v0.1.0\n- stuff\n")
        r = gate_verified_to_documented("F-0042", project_dir)
        assert not r.allowed
        assert any("CHANGELOG" in reason for reason in r.reasons)

    def test_docs_gate_blocking_blocks_when_drift_found(self, project_dir):
        """docs_gate=blocking with a drift.sh that exits non-zero should block."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- docs_gate: blocking\n"
        )
        # CHANGELOG mentions feature so only drift triggers the block
        (project_dir / "CHANGELOG.md").write_text(
            "# Changelog\n\n## v0.1.0\n- F-0042: stuff\n"
        )
        tools_dir = project_dir / ".agentic" / "lib" / "tools"
        tools_dir.mkdir(parents=True, exist_ok=True)
        (tools_dir / "drift.sh").write_text(
            '#!/usr/bin/env bash\necho "stale docs found"\nexit 1\n'
        )
        (tools_dir / "drift.sh").chmod(0o755)
        r = gate_verified_to_documented("F-0042", project_dir)
        assert not r.allowed
        assert any("drift" in reason.lower() for reason in r.reasons)

    def test_docs_gate_blocking_collects_both_changelog_and_drift(self, project_dir):
        """docs_gate=blocking should collect BOTH changelog and drift reasons."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- docs_gate: blocking\n"
        )
        (project_dir / "CHANGELOG.md").write_text("# Changelog\n\n## v0.1.0\n- stuff\n")
        tools_dir = project_dir / ".agentic" / "lib" / "tools"
        tools_dir.mkdir(parents=True, exist_ok=True)
        (tools_dir / "drift.sh").write_text(
            '#!/usr/bin/env bash\necho "stale docs found"\nexit 1\n'
        )
        (tools_dir / "drift.sh").chmod(0o755)
        r = gate_verified_to_documented("F-0042", project_dir)
        assert not r.allowed
        assert len(r.reasons) >= 2  # both CHANGELOG and drift

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

    def test_journal_freshness_advisory(self, project_dir):
        """Should warn when journal has no entry for today."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- docs_gate: warning\n"
        )
        journal_dir = project_dir / ".agentic" / "journal"
        journal_dir.mkdir(parents=True, exist_ok=True)
        (journal_dir / "JOURNAL.md").write_text("# Journal\n\n## 2020-01-01\n- old entry\n")
        r = gate_verified_to_documented("F-0042", project_dir)
        assert r.allowed
        assert any("JOURNAL" in w for w in r.warnings)


# ---------------------------------------------------------------------------
# Gate 7: documented -> committed
# ---------------------------------------------------------------------------

class TestGateDocumentedToCommitted:
    def test_blocks_without_git(self, project_dir):
        """Should block when .git directory doesn't exist."""
        r = gate_documented_to_committed("F-0042", project_dir)
        assert not r.allowed
        assert any("git" in reason.lower() for reason in r.reasons)

    def test_passes_with_clean_tree_and_feature_commit(self, project_dir):
        """Should pass when tree is clean and a commit references the feature."""
        import subprocess
        subprocess.run(["git", "init"], cwd=str(project_dir), capture_output=True)
        subprocess.run(["git", "config", "user.email", "test@test.com"], cwd=str(project_dir), capture_output=True)
        subprocess.run(["git", "config", "user.name", "Test"], cwd=str(project_dir), capture_output=True)
        subprocess.run(["git", "add", "-A"], cwd=str(project_dir), capture_output=True)
        subprocess.run(
            ["git", "commit", "-m", "feat(F-0042): initial"],
            cwd=str(project_dir), capture_output=True,
        )
        r = gate_documented_to_committed("F-0042", project_dir)
        assert r.allowed

    def test_blocks_dirty_tree(self, project_dir):
        """Should block when working tree has uncommitted changes."""
        import subprocess
        subprocess.run(["git", "init"], cwd=str(project_dir), capture_output=True)
        subprocess.run(["git", "config", "user.email", "test@test.com"], cwd=str(project_dir), capture_output=True)
        subprocess.run(["git", "config", "user.name", "Test"], cwd=str(project_dir), capture_output=True)
        subprocess.run(["git", "add", "-A"], cwd=str(project_dir), capture_output=True)
        subprocess.run(
            ["git", "commit", "-m", "feat(F-0042): initial"],
            cwd=str(project_dir), capture_output=True,
        )
        # Create dirty file
        (project_dir / "dirty.txt").write_text("uncommitted")
        r = gate_documented_to_committed("F-0042", project_dir)
        assert not r.allowed
        assert any("uncommitted" in reason.lower() for reason in r.reasons)

    def test_blocks_no_feature_commits(self, project_dir):
        """Should block when no commits reference the feature ID."""
        import subprocess
        subprocess.run(["git", "init"], cwd=str(project_dir), capture_output=True)
        subprocess.run(["git", "config", "user.email", "test@test.com"], cwd=str(project_dir), capture_output=True)
        subprocess.run(["git", "config", "user.name", "Test"], cwd=str(project_dir), capture_output=True)
        subprocess.run(["git", "add", "-A"], cwd=str(project_dir), capture_output=True)
        subprocess.run(
            ["git", "commit", "-m", "unrelated commit"],
            cwd=str(project_dir), capture_output=True,
        )
        r = gate_documented_to_committed("F-0042", project_dir)
        assert not r.allowed
        assert any("No commits reference" in reason for reason in r.reasons)


# ---------------------------------------------------------------------------
# Gate 8: committed -> shipped
# ---------------------------------------------------------------------------

class TestGateCommittedToShipped:
    def test_graceful_when_gh_unavailable(self, project_dir):
        """Should warn (not crash) when gh CLI is not installed."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- git_workflow: pull_request\n"
        )
        r = gate_committed_to_shipped("F-0042", project_dir)
        # gh not available in test env → warning, not block
        assert r.allowed or any("gh" in w.lower() for w in r.warnings)

    def test_direct_mode_passes_without_remote(self, project_dir):
        """Direct mode should warn (not crash) when no upstream exists."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- git_workflow: direct\n"
        )
        # Create VERSION so we get at least one warning
        (project_dir / ".agentic" / "lib" / "VERSION").write_text("0.1.0\n")
        r = gate_committed_to_shipped("F-0042", project_dir)
        # No git repo or upstream → graceful degradation (warning, not crash)
        assert r.allowed or any("unpushed" in w.lower() for w in r.warnings)

    def test_version_advisory(self, project_dir):
        """Should advise about VERSION bump when VERSION file exists."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- git_workflow: direct\n"
        )
        (project_dir / ".agentic" / "lib" / "VERSION").write_text("0.1.0\n")
        r = gate_committed_to_shipped("F-0042", project_dir)
        assert any("VERSION" in w for w in r.warnings)


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
