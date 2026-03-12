"""Tests for kickoff.py — Vision-to-Backlog pipeline."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

# Ensure lib/ is on path
_LIB_DIR = Path(__file__).resolve().parent.parent / ".agentic" / "lib"
sys.path.insert(0, str(_LIB_DIR))
sys.path.insert(0, str(_LIB_DIR / "auto"))
sys.path.insert(0, str(_LIB_DIR / "tools"))

from auto.kickoff import (
    generate_to_staging,
    validate_staging,
    promote_staging,
    review_staging,
    staging_status,
    merge_staging_features,
    split_staging_feature,
    rename_staging_feature,
    reorder_staging_backlog,
    remove_staging_feature,
    discard_staging,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def tmp_project(tmp_path):
    """Create a minimal project structure for testing."""
    agentic = tmp_path / ".agentic"
    agentic.mkdir()
    session = agentic / "session"
    session.mkdir()
    spec = agentic / "spec"
    spec.mkdir()
    acceptance = spec / "acceptance"
    acceptance.mkdir()

    # FEATURES.md with some existing features
    features = spec / "FEATURES.md"
    features.write_text(
        "# Features\n\n"
        "## F-0001: Existing Feature\n\n"
        "**Status**: shipped\n"
        "**Category**: Core\n\n"
        "---\n\n"
        "## F-0005: Another Feature\n\n"
        "**Status**: planned\n"
        "**Category**: Core\n\n"
        "---\n\n"
    )

    # STACK.md with settings
    stack = tmp_path / "STACK.md"
    stack.write_text(
        "# STACK.md\n\n"
        "## Settings\n"
        "- review_decomposition: skip\n"
    )

    return tmp_path


@pytest.fixture
def sample_features():
    """Sample features data for testing."""
    return [
        {
            "name": "User Authentication",
            "description": "Login, signup, password reset",
            "criteria": [
                "Users can sign up with email and password",
                "Users can log in with existing credentials",
                "Users can reset their password via email",
            ],
            "dependencies": [],
        },
        {
            "name": "Task Management",
            "description": "CRUD operations for tasks",
            "criteria": [
                "Users can create tasks with title and description",
                "Users can mark tasks as complete",
            ],
            "dependencies": ["User Authentication"],
        },
        {
            "name": "Real-time Sync",
            "description": "WebSocket-based real-time updates",
            "criteria": [
                "Changes sync across devices in real-time",
            ],
            "dependencies": ["Task Management"],
        },
    ]


# ---------------------------------------------------------------------------
# generate_to_staging tests
# ---------------------------------------------------------------------------

class TestGenerateToStaging:
    def test_generates_all_artifacts(self, tmp_project, sample_features):
        success, msgs = generate_to_staging(
            tmp_project, sample_features, overview_text="A todo app"
        )
        assert success
        staging = tmp_project / ".agentic" / "session" / "kickoff-draft"
        assert staging.exists()
        assert (staging / "OVERVIEW.md").exists()
        assert (staging / "FEATURES.md").exists()
        assert (staging / "BACKLOG.json").exists()
        assert (staging / ".metadata.json").exists()

    def test_generates_ac_files(self, tmp_project, sample_features):
        generate_to_staging(tmp_project, sample_features)
        staging = tmp_project / ".agentic" / "session" / "kickoff-draft"
        spec_dir = staging / "spec" / "acceptance"
        assert (spec_dir / "F-NEW-001.md").exists()
        assert (spec_dir / "F-NEW-002.md").exists()
        assert (spec_dir / "F-NEW-003.md").exists()

    def test_placeholder_ids(self, tmp_project, sample_features):
        generate_to_staging(tmp_project, sample_features)
        staging = tmp_project / ".agentic" / "session" / "kickoff-draft"
        metadata = json.loads((staging / ".metadata.json").read_text())
        assert metadata["feature_count"] == 3
        ids = [f["placeholder_id"] for f in metadata["features"]]
        assert ids == ["F-NEW-001", "F-NEW-002", "F-NEW-003"]

    def test_proposal_markers(self, tmp_project, sample_features):
        generate_to_staging(tmp_project, sample_features, "Overview text")
        staging = tmp_project / ".agentic" / "session" / "kickoff-draft"
        overview = (staging / "OVERVIEW.md").read_text()
        assert "<!-- PROPOSAL -->" in overview

    def test_blocks_if_staging_exists(self, tmp_project, sample_features):
        generate_to_staging(tmp_project, sample_features)
        success, msgs = generate_to_staging(tmp_project, sample_features)
        assert not success
        assert "already exists" in msgs[0]

    def test_empty_features_rejected(self, tmp_project):
        success, msgs = generate_to_staging(tmp_project, [])
        assert not success

    def test_backlog_ordered_by_deps(self, tmp_project, sample_features):
        generate_to_staging(tmp_project, sample_features)
        staging = tmp_project / ".agentic" / "session" / "kickoff-draft"
        backlog = json.loads((staging / "BACKLOG.json").read_text())
        ids = [item["id"] for item in backlog]
        # Auth should come before Task Management (which depends on it)
        auth_idx = ids.index("F-NEW-001")
        task_idx = ids.index("F-NEW-002")
        assert auth_idx < task_idx

    def test_no_overview_text(self, tmp_project, sample_features):
        success, _ = generate_to_staging(tmp_project, sample_features)
        assert success
        staging = tmp_project / ".agentic" / "session" / "kickoff-draft"
        overview = (staging / "OVERVIEW.md").read_text()
        assert "No overview provided" in overview


# ---------------------------------------------------------------------------
# validate_staging tests
# ---------------------------------------------------------------------------

class TestValidateStaging:
    def test_valid_staging(self, tmp_project, sample_features):
        generate_to_staging(tmp_project, sample_features, "My app")
        valid, errors = validate_staging(tmp_project)
        assert valid
        assert errors == []

    def test_no_staging(self, tmp_project):
        valid, errors = validate_staging(tmp_project)
        assert not valid

    def test_empty_criteria_detected(self, tmp_project):
        features = [{"name": "Bad Feature", "description": "x", "criteria": []}]
        generate_to_staging(tmp_project, features, "Overview")
        valid, errors = validate_staging(tmp_project)
        assert not valid
        assert any("no acceptance criteria" in e for e in errors)

    def test_circular_dependency_detected(self, tmp_project):
        features = [
            {
                "name": "A",
                "description": "Feature A",
                "criteria": ["Criterion 1"],
                "dependencies": ["B"],
            },
            {
                "name": "B",
                "description": "Feature B",
                "criteria": ["Criterion 1"],
                "dependencies": ["A"],
            },
        ]
        generate_to_staging(tmp_project, features, "Overview")
        valid, errors = validate_staging(tmp_project)
        assert not valid
        assert any("Circular dependency" in e for e in errors)


# ---------------------------------------------------------------------------
# review_staging tests
# ---------------------------------------------------------------------------

class TestReviewStaging:
    def test_review_returns_summary(self, tmp_project, sample_features):
        generate_to_staging(tmp_project, sample_features, "A todo app")
        success, summary = review_staging(tmp_project)
        assert success
        assert "overview" in summary
        assert "features" in summary
        assert len(summary["features"]) == 3
        assert "backlog_order" in summary
        assert "validation" in summary
        assert summary["validation"]["valid"]

    def test_review_no_staging(self, tmp_project):
        success, summary = review_staging(tmp_project)
        assert not success


# ---------------------------------------------------------------------------
# staging_status tests
# ---------------------------------------------------------------------------

class TestStagingStatus:
    def test_status_no_staging(self, tmp_project):
        status = staging_status(tmp_project)
        assert not status["exists"]
        assert status["feature_count"] == 0

    def test_status_with_staging(self, tmp_project, sample_features):
        generate_to_staging(tmp_project, sample_features, "Overview")
        status = staging_status(tmp_project)
        assert status["exists"]
        assert status["feature_count"] == 3
        assert status["valid"]


# ---------------------------------------------------------------------------
# Edit operation tests
# ---------------------------------------------------------------------------

class TestMergeFeatures:
    def test_merge(self, tmp_project, sample_features):
        generate_to_staging(tmp_project, sample_features)
        success, msgs = merge_staging_features(
            tmp_project, "F-NEW-003", "F-NEW-002"
        )
        assert success
        # Source should be gone
        staging = tmp_project / ".agentic" / "session" / "kickoff-draft"
        metadata = json.loads((staging / ".metadata.json").read_text())
        assert metadata["feature_count"] == 2
        ids = [f["placeholder_id"] for f in metadata["features"]]
        assert "F-NEW-003" not in ids
        assert "F-NEW-002" in ids

    def test_merge_nonexistent_source(self, tmp_project, sample_features):
        generate_to_staging(tmp_project, sample_features)
        success, _ = merge_staging_features(
            tmp_project, "F-NEW-999", "F-NEW-002"
        )
        assert not success


class TestSplitFeature:
    def test_split(self, tmp_project, sample_features):
        generate_to_staging(tmp_project, sample_features)
        success, msgs = split_staging_feature(
            tmp_project,
            "F-NEW-001",
            [
                {"name": "Signup", "criteria": [1]},
                {"name": "Login", "criteria": [2]},
            ],
        )
        assert success
        staging = tmp_project / ".agentic" / "session" / "kickoff-draft"
        metadata = json.loads((staging / ".metadata.json").read_text())
        # Original kept AC-3 (password reset), two new features created
        ids = [f["placeholder_id"] for f in metadata["features"]]
        assert "F-NEW-004" in ids  # Signup
        assert "F-NEW-005" in ids  # Login
        assert "F-NEW-001" in ids  # Still exists with remaining AC

    def test_split_invalid_index(self, tmp_project, sample_features):
        generate_to_staging(tmp_project, sample_features)
        success, msgs = split_staging_feature(
            tmp_project,
            "F-NEW-001",
            [{"name": "Bad", "criteria": [99]}],
        )
        assert not success


class TestRenameFeature:
    def test_rename(self, tmp_project, sample_features):
        generate_to_staging(tmp_project, sample_features)
        success, msgs = rename_staging_feature(
            tmp_project, "F-NEW-001", "Auth System"
        )
        assert success
        staging = tmp_project / ".agentic" / "session" / "kickoff-draft"
        metadata = json.loads((staging / ".metadata.json").read_text())
        feature = next(
            f for f in metadata["features"]
            if f["placeholder_id"] == "F-NEW-001"
        )
        assert feature["name"] == "Auth System"


class TestReorderBacklog:
    def test_reorder(self, tmp_project, sample_features):
        generate_to_staging(tmp_project, sample_features)
        success, msgs = reorder_staging_backlog(
            tmp_project, ["F-NEW-003", "F-NEW-001", "F-NEW-002"]
        )
        assert success
        staging = tmp_project / ".agentic" / "session" / "kickoff-draft"
        backlog = json.loads((staging / "BACKLOG.json").read_text())
        assert backlog[0]["id"] == "F-NEW-003"
        assert backlog[1]["id"] == "F-NEW-001"

    def test_reorder_unknown_id(self, tmp_project, sample_features):
        generate_to_staging(tmp_project, sample_features)
        success, _ = reorder_staging_backlog(
            tmp_project, ["F-NEW-999"]
        )
        assert not success


class TestRemoveFeature:
    def test_remove(self, tmp_project, sample_features):
        generate_to_staging(tmp_project, sample_features)
        success, msgs = remove_staging_feature(tmp_project, "F-NEW-002")
        assert success
        staging = tmp_project / ".agentic" / "session" / "kickoff-draft"
        metadata = json.loads((staging / ".metadata.json").read_text())
        assert metadata["feature_count"] == 2
        ids = [f["placeholder_id"] for f in metadata["features"]]
        assert "F-NEW-002" not in ids
        # AC file should be gone
        assert not (staging / "spec" / "acceptance" / "F-NEW-002.md").exists()


# ---------------------------------------------------------------------------
# promote_staging tests
# ---------------------------------------------------------------------------

class TestPromoteStaging:
    def test_promote_creates_real_features(self, tmp_project, sample_features):
        generate_to_staging(tmp_project, sample_features, "A todo app")
        success, msgs = promote_staging(tmp_project)
        assert success

        # Staging should be gone
        staging = tmp_project / ".agentic" / "session" / "kickoff-draft"
        assert not staging.exists()

        # Real features should exist
        features_file = tmp_project / ".agentic" / "spec" / "FEATURES.md"
        content = features_file.read_text()
        assert "## F-0006:" in content  # Next ID after F-0005
        assert "## F-0007:" in content
        assert "## F-0008:" in content

    def test_promote_creates_ac_files(self, tmp_project, sample_features):
        generate_to_staging(tmp_project, sample_features, "Overview")
        promote_staging(tmp_project)
        ac_dir = tmp_project / ".agentic" / "spec" / "acceptance"
        assert (ac_dir / "F-0006.md").exists()
        assert (ac_dir / "F-0007.md").exists()
        assert (ac_dir / "F-0008.md").exists()

    def test_promote_strips_proposal_markers(self, tmp_project, sample_features):
        generate_to_staging(tmp_project, sample_features, "Overview")
        promote_staging(tmp_project)
        ac_dir = tmp_project / ".agentic" / "spec" / "acceptance"
        content = (ac_dir / "F-0006.md").read_text()
        assert "<!-- PROPOSAL -->" not in content

    def test_promote_creates_overview(self, tmp_project, sample_features):
        generate_to_staging(tmp_project, sample_features, "My great app")
        promote_staging(tmp_project)
        overview = tmp_project / ".agentic" / "OVERVIEW.md"
        assert overview.exists()
        content = overview.read_text()
        assert "My great app" in content
        assert "<!-- PROPOSAL -->" not in content

    def test_promote_fails_if_overview_exists(self, tmp_project, sample_features):
        # Create existing OVERVIEW.md
        (tmp_project / ".agentic" / "OVERVIEW.md").write_text("Existing overview\n")
        generate_to_staging(tmp_project, sample_features, "New overview")
        success, msgs = promote_staging(tmp_project)
        assert not success
        assert any("already exists" in m for m in msgs)

    def test_promote_force_overview(self, tmp_project, sample_features):
        (tmp_project / ".agentic" / "OVERVIEW.md").write_text("Old\n")
        generate_to_staging(tmp_project, sample_features, "New overview")
        success, msgs = promote_staging(tmp_project, force_overview=True)
        assert success

    def test_promote_adds_to_backlog(self, tmp_project, sample_features):
        generate_to_staging(tmp_project, sample_features, "Overview")
        promote_staging(tmp_project)
        backlog_file = tmp_project / ".agentic" / "BACKLOG.json"
        assert backlog_file.exists()
        backlog = json.loads(backlog_file.read_text())
        ids = [item["id"] for item in backlog]
        assert "F-0006" in ids
        assert "F-0007" in ids

    def test_promote_fails_validation(self, tmp_project):
        features = [{"name": "Bad", "description": "x", "criteria": []}]
        generate_to_staging(tmp_project, features, "Overview")
        success, msgs = promote_staging(tmp_project)
        assert not success
        assert any("Validation failed" in m for m in msgs)

    def test_promote_allocates_fresh_ids(self, tmp_project, sample_features):
        """IDs allocated at promotion time, not generation time."""
        generate_to_staging(tmp_project, sample_features, "Overview")

        # Simulate another feature being created between generate and promote
        features_file = tmp_project / ".agentic" / "spec" / "FEATURES.md"
        content = features_file.read_text()
        content += (
            "\n## F-0006: Interloper\n\n"
            "**Status**: planned\n"
            "**Category**: Core\n\n---\n\n"
        )
        features_file.write_text(content)

        success, msgs = promote_staging(tmp_project)
        assert success
        # Should start from F-0007, not F-0006
        content = features_file.read_text()
        assert "## F-0007:" in content
        assert "## F-0008:" in content
        assert "## F-0009:" in content


# ---------------------------------------------------------------------------
# discard_staging tests
# ---------------------------------------------------------------------------

class TestDiscardStaging:
    def test_discard(self, tmp_project, sample_features):
        generate_to_staging(tmp_project, sample_features)
        success, msgs = discard_staging(tmp_project)
        assert success
        staging = tmp_project / ".agentic" / "session" / "kickoff-draft"
        assert not staging.exists()

    def test_discard_no_staging(self, tmp_project):
        success, msgs = discard_staging(tmp_project)
        assert not success


# ---------------------------------------------------------------------------
# CLI tests
# ---------------------------------------------------------------------------

class TestCLI:
    def test_generate_cli(self, tmp_project, sample_features):
        """Test CLI generate command via subprocess."""
        import subprocess
        features_json = json.dumps(sample_features)
        result = subprocess.run(
            [
                sys.executable, "-m", "auto.kickoff",
                "generate",
                "--features-json", features_json,
                "--overview", "My app overview",
                "--project-root", str(tmp_project),
            ],
            capture_output=True, text=True,
            cwd=str(_LIB_DIR),
        )
        assert result.returncode == 0
        assert "Generated 3 features" in result.stdout

    def test_validate_cli(self, tmp_project, sample_features):
        import subprocess
        generate_to_staging(tmp_project, sample_features, "Overview")
        result = subprocess.run(
            [
                sys.executable, "-m", "auto.kickoff",
                "validate",
                "--project-root", str(tmp_project),
            ],
            capture_output=True, text=True,
            cwd=str(_LIB_DIR),
        )
        assert result.returncode == 0
        assert "valid" in result.stdout.lower()

    def test_status_cli(self, tmp_project, sample_features):
        import subprocess
        generate_to_staging(tmp_project, sample_features, "Overview")
        result = subprocess.run(
            [
                sys.executable, "-m", "auto.kickoff",
                "status",
                "--project-root", str(tmp_project),
            ],
            capture_output=True, text=True,
            cwd=str(_LIB_DIR),
        )
        assert result.returncode == 0
        status = json.loads(result.stdout)
        assert status["exists"]
        assert status["feature_count"] == 3

    def test_discard_cli(self, tmp_project, sample_features):
        import subprocess
        generate_to_staging(tmp_project, sample_features)
        result = subprocess.run(
            [
                sys.executable, "-m", "auto.kickoff",
                "discard",
                "--project-root", str(tmp_project),
            ],
            capture_output=True, text=True,
            cwd=str(_LIB_DIR),
        )
        assert result.returncode == 0
        assert "discarded" in result.stdout.lower()
