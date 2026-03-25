"""Tests for F-032: Multi-Session Plan Phase Tracking.

@feature F-032
"""
import sys
import textwrap
from pathlib import Path

import pytest

# Ensure auto/ is importable
_LIB_DIR = Path(__file__).resolve().parent.parent / ".agentic" / "lib"
sys.path.insert(0, str(_LIB_DIR))

from auto.phases import (
    create_tasks_file,
    extract_phases_from_plan,
    get_next_phase,
    get_progress_summary,
    has_incomplete_phases,
    load_tasks_file,
    sync_phases_with_plan,
    update_phase_status,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

PLAN_WITH_PHASES = textwrap.dedent("""\
    # F-031: Spec System Overhaul

    **Status**: APPROVED

    ## Phase 0: Feature Consolidation & Triage (2-3 sessions)

    Details about phase 0...

    ## Phase 1: Contract Infrastructure (2 sessions)

    Details about phase 1...

    ## Phase 2: Contract Writing (4-6 sessions)

    Details about phase 2...

    ## Phase 3: The Switchover (3-4 sessions)

    Details about phase 3...

    ## Phase 4: Protection & V2 Cleanup (2 sessions)

    Details about phase 4...
""")

PLAN_WITHOUT_PHASES = textwrap.dedent("""\
    # F-0100: Simple Feature

    **Status**: APPROVED

    ## Implementation

    Just one step.
""")

PLAN_WITH_SUBPHASES = textwrap.dedent("""\
    # F-013: QA Suite

    ## Phase 3A: Spec Verification Tool (F-XXXX)

    Details...

    ## Phase 3B: Change Propagation Pipeline (F-XXXX)

    More details...
""")

PLAN_WITH_STATUS_MARKERS = textwrap.dedent("""\
    # F-031: Test

    ## Phase 0: Done Phase ✅ COMPLETE

    ## Phase 1: Active Phase — NEXT

    ## Phase 2: Future Phase (1 session)
""")

PLAN_WITH_NO_PARENS = textwrap.dedent("""\
    # F-0201: Plan

    ## Phase 1: Foundation — Python Backend + Acceptance Criteria (8 files)

    ## Phase 2: CLI + Review Loop — ag kickoff in ag.sh (5 files)

    ## Phase 3: Instruction File Updates (10 files, 2 commits)
""")

PLAN_COLON_OPTIONAL = textwrap.dedent("""\
    # F-0226: Plan

    ## Phase 2 Algorithm: Sentinel-Based Content Drift Detection

    Details...
""")


@pytest.fixture
def tmp_project(tmp_path):
    """Create a minimal project structure."""
    (tmp_path / ".agentic" / "work" / "F-0042").mkdir(parents=True)
    (tmp_path / ".agentic" / "spec").mkdir(parents=True)
    (tmp_path / ".agentic" / "journal" / "plans").mkdir(parents=True)
    return tmp_path


@pytest.fixture
def plan_file(tmp_project):
    """Create a plan file with phases."""
    path = tmp_project / ".agentic" / "journal" / "plans" / "2026-03-23-F-0042-plan.md"
    path.write_text(PLAN_WITH_PHASES)
    return path


# ---------------------------------------------------------------------------
# Tests: extract_phases_from_plan
# ---------------------------------------------------------------------------

class TestExtractPhases:
    def test_extracts_phases_with_estimates(self, tmp_path):
        plan = tmp_path / "plan.md"
        plan.write_text(PLAN_WITH_PHASES)
        phases = extract_phases_from_plan(plan)

        assert len(phases) == 5
        assert phases[0]["id"] == "0"
        assert phases[0]["title"] == "Feature Consolidation & Triage"
        assert phases[0]["sessions_estimate"] == "2-3 sessions"
        assert phases[0]["status"] == "pending"
        assert phases[0]["tasks"] == []

        assert phases[4]["id"] == "4"
        assert phases[4]["title"] == "Protection & V2 Cleanup"

    def test_no_phases_returns_empty(self, tmp_path):
        plan = tmp_path / "plan.md"
        plan.write_text(PLAN_WITHOUT_PHASES)
        phases = extract_phases_from_plan(plan)
        assert phases == []

    def test_subphases(self, tmp_path):
        plan = tmp_path / "plan.md"
        plan.write_text(PLAN_WITH_SUBPHASES)
        phases = extract_phases_from_plan(plan)

        assert len(phases) == 2
        assert phases[0]["id"] == "3A"
        assert phases[1]["id"] == "3B"

    def test_strips_status_markers(self, tmp_path):
        plan = tmp_path / "plan.md"
        plan.write_text(PLAN_WITH_STATUS_MARKERS)
        phases = extract_phases_from_plan(plan)

        assert len(phases) == 3
        assert phases[0]["title"] == "Done Phase"
        assert phases[1]["title"] == "Active Phase"
        assert phases[2]["title"] == "Future Phase"

    def test_complex_titles_with_parens(self, tmp_path):
        plan = tmp_path / "plan.md"
        plan.write_text(PLAN_WITH_NO_PARENS)
        phases = extract_phases_from_plan(plan)

        assert len(phases) == 3
        assert phases[0]["sessions_estimate"] == "8 files"
        assert "Python Backend" in phases[0]["title"]

    def test_colon_optional_format(self, tmp_path):
        plan = tmp_path / "plan.md"
        plan.write_text(PLAN_COLON_OPTIONAL)
        phases = extract_phases_from_plan(plan)

        assert len(phases) == 1
        assert phases[0]["id"] == "2"
        assert "Sentinel-Based" in phases[0]["title"]

    def test_nonexistent_file(self, tmp_path):
        plan = tmp_path / "nonexistent.md"
        assert extract_phases_from_plan(plan) == []


# ---------------------------------------------------------------------------
# Tests: create / load tasks.yaml
# ---------------------------------------------------------------------------

class TestTasksFile:
    def test_create_and_load(self, tmp_project, plan_file):
        phases = extract_phases_from_plan(plan_file)
        path = create_tasks_file(tmp_project, "F-0042", phases, str(plan_file))

        assert path.exists()
        data = load_tasks_file(tmp_project, "F-0042")
        assert data is not None
        assert data["feature"] == "F-0042"
        assert len(data["phases"]) == 5
        assert all(p["tasks"] == [] for p in data["phases"])

    def test_load_missing_returns_none(self, tmp_project):
        assert load_tasks_file(tmp_project, "F-9999") is None

    def test_creates_work_directory(self, tmp_path):
        """tasks.yaml creation should create .agentic/work/F-XXXX/ if missing."""
        plan = tmp_path / "plan.md"
        plan.write_text(PLAN_WITH_PHASES)
        phases = extract_phases_from_plan(plan)

        path = create_tasks_file(tmp_path, "F-NEW", phases, str(plan))
        assert path.exists()
        assert path.parent.name == "F-NEW"


# ---------------------------------------------------------------------------
# Tests: update_phase_status
# ---------------------------------------------------------------------------

class TestUpdatePhaseStatus:
    def test_pending_to_active(self, tmp_project, plan_file):
        phases = extract_phases_from_plan(plan_file)
        create_tasks_file(tmp_project, "F-0042", phases, str(plan_file))

        assert update_phase_status(tmp_project, "F-0042", "0", "active")
        data = load_tasks_file(tmp_project, "F-0042")
        assert data["phases"][0]["status"] == "active"

    def test_active_to_complete(self, tmp_project, plan_file):
        phases = extract_phases_from_plan(plan_file)
        create_tasks_file(tmp_project, "F-0042", phases, str(plan_file))
        update_phase_status(tmp_project, "F-0042", "0", "active")

        assert update_phase_status(tmp_project, "F-0042", "0", "complete")
        data = load_tasks_file(tmp_project, "F-0042")
        assert data["phases"][0]["status"] == "complete"
        assert data["phases"][0]["completed_at"] is not None

    def test_invalid_transition_rejected(self, tmp_project, plan_file):
        phases = extract_phases_from_plan(plan_file)
        create_tasks_file(tmp_project, "F-0042", phases, str(plan_file))

        # pending → complete is not valid (must go through active)
        assert not update_phase_status(tmp_project, "F-0042", "0", "complete")
        data = load_tasks_file(tmp_project, "F-0042")
        assert data["phases"][0]["status"] == "pending"

    def test_pending_to_dropped(self, tmp_project, plan_file):
        phases = extract_phases_from_plan(plan_file)
        create_tasks_file(tmp_project, "F-0042", phases, str(plan_file))

        assert update_phase_status(tmp_project, "F-0042", "0", "dropped")
        data = load_tasks_file(tmp_project, "F-0042")
        assert data["phases"][0]["status"] == "dropped"
        assert data["phases"][0]["completed_at"] is not None

    def test_nonexistent_phase(self, tmp_project, plan_file):
        phases = extract_phases_from_plan(plan_file)
        create_tasks_file(tmp_project, "F-0042", phases, str(plan_file))

        assert not update_phase_status(tmp_project, "F-0042", "99", "active")

    def test_no_tasks_file(self, tmp_project):
        assert not update_phase_status(tmp_project, "F-9999", "0", "active")


# ---------------------------------------------------------------------------
# Tests: progress / completion
# ---------------------------------------------------------------------------

class TestProgress:
    def test_progress_summary(self, tmp_project, plan_file):
        phases = extract_phases_from_plan(plan_file)
        create_tasks_file(tmp_project, "F-0042", phases, str(plan_file))

        assert get_progress_summary(tmp_project, "F-0042") == "0/5 phases complete"

        update_phase_status(tmp_project, "F-0042", "0", "active")
        update_phase_status(tmp_project, "F-0042", "0", "complete")
        assert get_progress_summary(tmp_project, "F-0042") == "1/5 phases complete"

    def test_progress_none_without_tasks(self, tmp_project):
        assert get_progress_summary(tmp_project, "F-9999") is None

    def test_has_incomplete_phases(self, tmp_project, plan_file):
        phases = extract_phases_from_plan(plan_file)
        create_tasks_file(tmp_project, "F-0042", phases, str(plan_file))

        incomplete, msg = has_incomplete_phases(tmp_project, "F-0042")
        assert incomplete
        assert "0/5" in msg

    def test_all_complete(self, tmp_project, plan_file):
        phases = extract_phases_from_plan(plan_file)
        create_tasks_file(tmp_project, "F-0042", phases, str(plan_file))

        for p in phases:
            update_phase_status(tmp_project, "F-0042", p["id"], "active")
            update_phase_status(tmp_project, "F-0042", p["id"], "complete")

        incomplete, msg = has_incomplete_phases(tmp_project, "F-0042")
        assert not incomplete
        assert "All 5 phases complete" in msg

    def test_dropped_counts_as_done(self, tmp_project, plan_file):
        phases = extract_phases_from_plan(plan_file)
        create_tasks_file(tmp_project, "F-0042", phases, str(plan_file))

        for p in phases:
            update_phase_status(tmp_project, "F-0042", p["id"], "dropped")

        incomplete, msg = has_incomplete_phases(tmp_project, "F-0042")
        assert not incomplete

    def test_no_tasks_file_not_incomplete(self, tmp_project):
        incomplete, msg = has_incomplete_phases(tmp_project, "F-9999")
        assert not incomplete

    def test_get_next_phase(self, tmp_project, plan_file):
        phases = extract_phases_from_plan(plan_file)
        create_tasks_file(tmp_project, "F-0042", phases, str(plan_file))

        # First pending
        nxt = get_next_phase(tmp_project, "F-0042")
        assert nxt["id"] == "0"

        # Active takes priority
        update_phase_status(tmp_project, "F-0042", "2", "active")
        nxt = get_next_phase(tmp_project, "F-0042")
        assert nxt["id"] == "2"


# ---------------------------------------------------------------------------
# Tests: sync_phases_with_plan
# ---------------------------------------------------------------------------

class TestSyncPhases:
    def test_sync_adds_new_phases(self, tmp_project, plan_file):
        # Start with first 3 phases only
        phases = extract_phases_from_plan(plan_file)[:3]
        create_tasks_file(tmp_project, "F-0042", phases, str(plan_file))

        # Sync with full plan (5 phases)
        result = sync_phases_with_plan(tmp_project, "F-0042", plan_file)
        assert len(result["added"]) == 2
        assert "3" in result["added"]
        assert "4" in result["added"]

        data = load_tasks_file(tmp_project, "F-0042")
        assert len(data["phases"]) == 5

    def test_sync_marks_removed_as_dropped(self, tmp_project, plan_file):
        phases = extract_phases_from_plan(plan_file)
        create_tasks_file(tmp_project, "F-0042", phases, str(plan_file))

        # Create a shorter plan (phases 0-2 only)
        short_plan = tmp_project / "short.md"
        short_plan.write_text(textwrap.dedent("""\
            # Revised Plan

            ## Phase 0: Feature Consolidation & Triage (2-3 sessions)

            ## Phase 1: Contract Infrastructure (2 sessions)

            ## Phase 2: Contract Writing (4-6 sessions)
        """))

        result = sync_phases_with_plan(tmp_project, "F-0042", short_plan)
        assert "3" in result["dropped"]
        assert "4" in result["dropped"]

    def test_sync_preserves_existing_status(self, tmp_project, plan_file):
        phases = extract_phases_from_plan(plan_file)
        create_tasks_file(tmp_project, "F-0042", phases, str(plan_file))

        # Mark phase 0 complete
        update_phase_status(tmp_project, "F-0042", "0", "active")
        update_phase_status(tmp_project, "F-0042", "0", "complete")

        # Sync — phase 0 should stay complete
        result = sync_phases_with_plan(tmp_project, "F-0042", plan_file)
        data = load_tasks_file(tmp_project, "F-0042")
        assert data["phases"][0]["status"] == "complete"

    def test_sync_creates_fresh_when_no_tasks(self, tmp_project, plan_file):
        result = sync_phases_with_plan(tmp_project, "F-0042", plan_file)
        assert len(result["added"]) == 5
        assert load_tasks_file(tmp_project, "F-0042") is not None


# ---------------------------------------------------------------------------
# Tests: D3 forward-compatibility
# ---------------------------------------------------------------------------

class TestD3ForwardCompat:
    def test_tasks_list_is_empty(self, tmp_project, plan_file):
        """Each phase must have tasks: [] for D3 extension."""
        phases = extract_phases_from_plan(plan_file)
        create_tasks_file(tmp_project, "F-0042", phases, str(plan_file))

        data = load_tasks_file(tmp_project, "F-0042")
        for phase in data["phases"]:
            assert "tasks" in phase
            assert phase["tasks"] == []
