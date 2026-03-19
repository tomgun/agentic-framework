#!/usr/bin/env python3
"""
Tests for PR auto-review (F-0235): PRReviewer class, fix loop, verdict routing.
"""
import json
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch, MagicMock, call

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "auto"))

from auto.pr_review import PRReviewer, PRReviewResult


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def project_dir():
    """Minimal project dir for PR review tests."""
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        (root / ".agentic" / "lib" / "tools").mkdir(parents=True)
        (root / ".agentic" / "lib" / "auto" / "prompts").mkdir(parents=True)
        (root / ".agentic" / "session" / "reviews").mkdir(parents=True)
        (root / ".agentic" / "spec" / "acceptance").mkdir(parents=True)
        (root / ".agentic" / "journal" / "plans").mkdir(parents=True)

        # Copy infrastructure
        lib_src = Path(__file__).parent.parent / ".agentic" / "lib"
        for f in ["paths.py", "settings.py"]:
            src = lib_src / f
            if src.exists():
                (root / ".agentic" / "lib" / f).write_text(src.read_text())

        # Copy presets
        presets_dir = root / ".agentic" / "presets"
        presets_dir.mkdir(parents=True)
        src_presets = lib_src / "presets" / "profiles.conf"
        if src_presets.exists():
            (presets_dir / "profiles.conf").write_text(src_presets.read_text())

        # Copy prompt templates
        prompts_src = lib_src / "auto" / "prompts"
        for f in ["pr_review.md", "pr_fix.md"]:
            src = prompts_src / f
            if src.exists():
                (root / ".agentic" / "lib" / "auto" / "prompts" / f).write_text(
                    src.read_text()
                )

        # Blocker.sh stub
        (root / ".agentic" / "lib" / "tools" / "blocker.sh").write_text(
            '#!/bin/bash\necho "HN-001"\n'
        )

        (root / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- review_pr: critical_agent\n"
            "- pr_fix_max_attempts: 2\n"
        )

        # AC file
        (root / ".agentic" / "spec" / "acceptance" / "F-0042.md").write_text(
            "# F-0042\n## Acceptance Criteria\n- [ ] AC-001: Test criterion\n"
        )

        yield root


@pytest.fixture(autouse=True)
def clear_caches():
    """Clear settings caches between tests."""
    yield
    try:
        from settings import _cache
        _cache.clear()
    except (ImportError, AttributeError):
        pass


# ---------------------------------------------------------------------------
# Tests: PRReviewResult
# ---------------------------------------------------------------------------

class TestPRReviewResult:
    def test_defaults(self):
        result = PRReviewResult()
        assert result.verdict == ""
        assert result.summary == ""
        assert result.must_fix == []
        assert result.should_fix == []
        assert result.fix_attempts == 0


# ---------------------------------------------------------------------------
# Tests: Review output parsing
# ---------------------------------------------------------------------------

class TestParseReviewOutput:
    def test_parse_approved(self, project_dir):
        reviewer = PRReviewer(project_dir)
        result = PRReviewResult()
        output = (
            "VERDICT: APPROVED\n\n"
            "SUMMARY: Code looks good, all ACs met.\n\n"
            "MUST_FIX:\n\n"
            "SHOULD_FIX:\n"
        )
        reviewer._parse_review_output(output, result)
        assert result.verdict == "approved"
        assert "looks good" in result.summary

    def test_parse_request_changes(self, project_dir):
        reviewer = PRReviewer(project_dir)
        result = PRReviewResult()
        output = (
            "VERDICT: REQUEST_CHANGES\n\n"
            "SUMMARY: Missing error handling in auth module.\n\n"
            "MUST_FIX:\n"
            "- Add try/catch in login handler\n"
            "- Validate email format\n\n"
            "SHOULD_FIX:\n"
            "- Add logging to auth flow\n"
        )
        reviewer._parse_review_output(output, result)
        assert result.verdict == "request_changes"
        assert len(result.must_fix) == 2
        assert len(result.should_fix) == 1

    def test_parse_needs_discussion(self, project_dir):
        reviewer = PRReviewer(project_dir)
        result = PRReviewResult()
        output = "VERDICT: NEEDS_DISCUSSION\n\nSUMMARY: Architecture question.\n"
        reviewer._parse_review_output(output, result)
        assert result.verdict == "needs_discussion"

    def test_parse_missing_verdict_defaults_discussion(self, project_dir):
        reviewer = PRReviewer(project_dir)
        result = PRReviewResult()
        output = "Some unparseable review output without structure"
        reviewer._parse_review_output(output, result)
        assert result.verdict == "needs_discussion"


# ---------------------------------------------------------------------------
# Tests: review_and_fix() flow
# ---------------------------------------------------------------------------

class TestReviewAndFix:
    @patch("auto.pr_review.spawn_claude")
    @patch("auto.pr_review.subprocess.run")
    def test_skip_mode(self, mock_run, mock_spawn, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: discovery\n- review_pr: skip\n"
        )
        reviewer = PRReviewer(project_dir)
        result = reviewer.review_and_fix(42, "F-0042")
        assert result.verdict == "skipped"
        mock_spawn.assert_not_called()

    @patch("auto.pr_review.spawn_claude")
    @patch("auto.pr_review.subprocess.run")
    def test_approved_no_fix_needed(self, mock_run, mock_spawn, project_dir):
        # gh pr diff returns diff
        mock_run.return_value = MagicMock(
            stdout="diff --git a/file.py\n+new line\n",
            returncode=0,
        )
        # Review agent returns APPROVED
        mock_spawn.return_value = (
            "VERDICT: APPROVED\n\nSUMMARY: Looks great.\n\n"
            "MUST_FIX:\n\nSHOULD_FIX:\n"
        )
        reviewer = PRReviewer(project_dir)
        result = reviewer.review_and_fix(42, "F-0042")
        assert result.verdict == "approved"
        assert result.fix_attempts == 0
        # spawn_claude called once (review only, no fix)
        assert mock_spawn.call_count == 1

    @patch("auto.pr_review.spawn_claude")
    @patch("auto.pr_review.subprocess.run")
    def test_fix_loop_then_approved(self, mock_run, mock_spawn, project_dir):
        # gh pr diff / gh pr comment / gh pr review all succeed
        mock_run.return_value = MagicMock(
            stdout="diff content\n", returncode=0,
        )
        # First review: REQUEST_CHANGES, second review (after fix): APPROVED
        mock_spawn.side_effect = [
            # 1st review
            "VERDICT: REQUEST_CHANGES\n\nSUMMARY: Bug found.\n\n"
            "MUST_FIX:\n- Fix the bug\n\nSHOULD_FIX:\n",
            # fix agent
            "Fixed the bug and pushed.",
            # 2nd review
            "VERDICT: APPROVED\n\nSUMMARY: Bug fixed.\n\n"
            "MUST_FIX:\n\nSHOULD_FIX:\n",
        ]
        reviewer = PRReviewer(project_dir)
        result = reviewer.review_and_fix(42, "F-0042")
        assert result.verdict == "approved"
        assert result.fix_attempts == 1

    @patch("auto.pr_review.spawn_claude")
    @patch("auto.pr_review.subprocess.run")
    def test_max_fix_attempts_escalates(self, mock_run, mock_spawn, project_dir):
        mock_run.return_value = MagicMock(
            stdout="diff content\n", returncode=0,
        )
        # All reviews return REQUEST_CHANGES
        mock_spawn.return_value = (
            "VERDICT: REQUEST_CHANGES\n\nSUMMARY: Still broken.\n\n"
            "MUST_FIX:\n- Fix it\n\nSHOULD_FIX:\n"
        )
        reviewer = PRReviewer(project_dir)
        result = reviewer.review_and_fix(42, "F-0042")
        assert result.verdict == "request_changes"
        assert result.fix_attempts == 2  # max attempts used
        # 1 initial review + 2*(fix+review) = 5 spawn calls
        assert mock_spawn.call_count == 5

    @patch("auto.pr_review.spawn_claude")
    @patch("auto.pr_review.subprocess.run")
    def test_human_mode_creates_block(self, mock_run, mock_spawn, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- review_pr: human\n"
        )
        mock_run.return_value = MagicMock(stdout="HN-001\n", returncode=0)
        reviewer = PRReviewer(project_dir)
        result = reviewer.review_and_fix(42, "F-0042")
        assert result.verdict == "needs_discussion"
        # Check block file was created
        block_file = (
            project_dir / ".agentic" / "session" / "reviews"
            / "F-0042_pr_review.json"
        )
        assert block_file.exists()
        data = json.loads(block_file.read_text())
        assert data["pr_number"] == 42
        assert data["feature_id"] == "F-0042"

    @patch("auto.pr_review.spawn_claude")
    @patch("auto.pr_review.subprocess.run")
    def test_empty_diff_returns_skipped(self, mock_run, mock_spawn, project_dir):
        mock_run.return_value = MagicMock(stdout="", returncode=1)
        reviewer = PRReviewer(project_dir)
        result = reviewer.review_and_fix(42, "F-0042")
        assert result.verdict == "skipped"
        mock_spawn.assert_not_called()


# ---------------------------------------------------------------------------
# Tests: GitHub verdict application
# ---------------------------------------------------------------------------

class TestApplyVerdict:
    @patch("auto.pr_review.subprocess.run")
    def test_approve_calls_gh(self, mock_run, project_dir):
        reviewer = PRReviewer(project_dir)
        result = PRReviewResult(verdict="approved", summary="Good code")
        reviewer._apply_verdict(42, result)
        # Filter to only gh calls (paths.py also calls subprocess.run)
        gh_calls = [
            c for c in mock_run.call_args_list
            if c[0][0][0] == "gh"
        ]
        assert len(gh_calls) == 1
        assert "--approve" in gh_calls[0][0][0]

    @patch("auto.pr_review.subprocess.run")
    def test_request_changes_calls_gh(self, mock_run, project_dir):
        reviewer = PRReviewer(project_dir)
        result = PRReviewResult(
            verdict="request_changes",
            summary="Needs fixes",
            must_fix=["Fix the thing"],
        )
        reviewer._apply_verdict(42, result)
        gh_calls = [
            c for c in mock_run.call_args_list
            if c[0][0][0] == "gh"
        ]
        assert len(gh_calls) == 1
        assert "--request-changes" in gh_calls[0][0][0]


# ---------------------------------------------------------------------------
# Tests: check_pr_review_resolved (static method)
# ---------------------------------------------------------------------------

class TestCheckPRReviewResolved:
    @patch("auto.pr_review.subprocess.run")
    def test_resolved_when_approved(self, mock_run, project_dir):
        # Create block file
        reviews_dir = project_dir / ".agentic" / "session" / "reviews"
        block_file = reviews_dir / "F-0042_pr_review.json"
        block_file.write_text(json.dumps({
            "feature_id": "F-0042",
            "pr_number": 42,
        }))

        # gh pr view returns APPROVED
        mock_run.return_value = MagicMock(
            stdout=json.dumps({"reviewDecision": "APPROVED"}),
            returncode=0,
        )

        resolved = PRReviewer.check_pr_review_resolved(project_dir, "F-0042")
        assert resolved is True
        assert not block_file.exists()  # cleaned up

    @patch("auto.pr_review.subprocess.run")
    def test_not_resolved_when_pending(self, mock_run, project_dir):
        reviews_dir = project_dir / ".agentic" / "session" / "reviews"
        block_file = reviews_dir / "F-0042_pr_review.json"
        block_file.write_text(json.dumps({
            "feature_id": "F-0042",
            "pr_number": 42,
        }))

        mock_run.return_value = MagicMock(
            stdout=json.dumps({"reviewDecision": ""}),
            returncode=0,
        )

        resolved = PRReviewer.check_pr_review_resolved(project_dir, "F-0042")
        assert resolved is False
        assert block_file.exists()  # still present

    def test_resolved_when_no_block_file(self, project_dir):
        resolved = PRReviewer.check_pr_review_resolved(project_dir, "F-0042")
        assert resolved is True


# ---------------------------------------------------------------------------
# Tests: TaskResult extension
# ---------------------------------------------------------------------------

class TestTaskResultExtension:
    def test_to_dict_includes_pr_review_fields(self):
        from auto.task import TaskResult
        result = TaskResult(
            feature_id="F-0042",
            success=True,
            pr_review_verdict="approved",
            pr_review_summary="Looks good",
            pr_fix_attempts=1,
        )
        d = result.to_dict()
        assert d["pr_review_verdict"] == "approved"
        assert d["pr_review_summary"] == "Looks good"
        assert d["pr_fix_attempts"] == 1

    def test_to_dict_omits_empty_pr_review(self):
        from auto.task import TaskResult
        result = TaskResult(feature_id="F-0042", success=True)
        d = result.to_dict()
        assert "pr_review_verdict" not in d
