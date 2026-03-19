#!/usr/bin/env python3
"""
Tests for plan convergence loop (F-0236).
"""
import json
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "auto"))

from auto.plan_convergence import (
    ConvergenceDetector,
    ConvergenceResult,
    ConvergenceLoop,
    PlanSynthesizer,
)
from auto.reviewer_catalog import ReviewerRole


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def project_dir():
    """Minimal project dir for convergence tests."""
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        (root / ".agentic" / "lib" / "tools").mkdir(parents=True)
        (root / ".agentic" / "lib" / "auto" / "prompts").mkdir(parents=True)
        (root / ".agentic" / "lib" / "agents" / "shared").mkdir(parents=True)
        (root / ".agentic" / "lib" / "agents" / "claude" / "subagents").mkdir(
            parents=True
        )
        (root / ".agentic" / "session").mkdir(parents=True)
        (root / ".agentic" / "spec" / "acceptance").mkdir(parents=True)
        (root / ".agentic" / "journal" / "plans").mkdir(parents=True)
        (root / ".agentic" / "presets").mkdir(parents=True)

        # Copy infrastructure
        lib_src = Path(__file__).parent.parent / ".agentic" / "lib"
        for f in ["paths.py", "settings.py"]:
            src = lib_src / f
            if src.exists():
                (root / ".agentic" / "lib" / f).write_text(src.read_text())

        # Copy presets
        src_presets = lib_src / "presets" / "profiles.conf"
        if src_presets.exists():
            (root / ".agentic" / "presets" / "profiles.conf").write_text(
                src_presets.read_text()
            )

        # Copy prompt templates
        prompts_src = lib_src / "auto" / "prompts"
        for f in ["plan_synthesis.md", "plan_revision.md"]:
            src = prompts_src / f
            if src.exists():
                (root / ".agentic" / "lib" / "auto" / "prompts" / f).write_text(
                    src.read_text()
                )

        # Copy reviewer catalog
        catalog_src = (
            lib_src / "agents" / "shared" / "reviewer_roles.json"
        )
        if catalog_src.exists():
            (
                root / ".agentic" / "lib" / "agents" / "shared"
                / "reviewer_roles.json"
            ).write_text(catalog_src.read_text())

        # Blocker.sh stub
        (root / ".agentic" / "lib" / "tools" / "blocker.sh").write_text(
            '#!/bin/bash\necho "HN-001"\n'
        )

        (root / "STACK.md").write_text(
            "## Settings\n- profile: formal\n"
            "- plan_review_enabled: yes\n"
            "- plan_review_convergence: auto\n"
            "- plan_review_max_iterations: 3\n"
            "- plan_review_reviewers: critic,advocate\n"
        )

        # AC file
        (root / ".agentic" / "spec" / "acceptance" / "F-0042.md").write_text(
            "# F-0042\n## Acceptance Criteria\n- [ ] AC-001: Test\n"
        )

        # Plan file
        plan_file = root / ".agentic" / "journal" / "plans" / "2026-01-01-F-0042-plan.md"
        plan_file.write_text(
            "# Plan: F-0042\n\n**Status**: DRAFT\n**Iteration**: 1\n\n"
            "## Approach\nDo the thing.\n"
        )

        yield root


@pytest.fixture(autouse=True)
def clear_caches():
    yield
    try:
        from settings import _cache
        _cache.clear()
    except (ImportError, AttributeError):
        pass


# ---------------------------------------------------------------------------
# Tests: ConvergenceDetector
# ---------------------------------------------------------------------------

class TestConvergenceDetector:
    def setup_method(self):
        self.detector = ConvergenceDetector()

    def test_not_converged_iteration_1(self):
        """Minimum 2 iterations required."""
        converged, reason = self.detector.detect(
            "### High-Confidence Concerns\nNone\n", {}, 1,
        )
        assert converged is False
        assert "Minimum 2" in reason

    def test_converged_no_concerns_iteration_2(self):
        output = (
            "## Critic Assessment\n\n"
            "### High-Confidence Concerns\nNone\n\n"
            "### Convergence Signal\n"
            "- [x] Plan is fundamentally sound\n"
        )
        converged, reason = self.detector.detect(output, {}, 2)
        assert converged is True

    def test_not_converged_with_concerns(self):
        output = (
            "## Critic Assessment\n\n"
            "### High-Confidence Concerns\n"
            "1. **Missing auth**: No authentication in the API\n"
            "2. **No tests**: Testing strategy is absent\n"
        )
        converged, reason = self.detector.detect(output, {}, 2)
        assert converged is False
        assert "high-confidence" in reason.lower()

    def test_expert_concerns_block_convergence(self):
        critic_output = (
            "### High-Confidence Concerns\nNone\n"
        )
        expert_outputs = {
            "advocate": "### Convergence Signal\n- [x] Plan is fundamentally sound\n",
            "security_expert": (
                "### High-Confidence Concerns\n"
                "1. **SQL injection**: Input not sanitized\n"
            ),
        }
        converged, reason = self.detector.detect(
            critic_output, expert_outputs, 2,
        )
        assert converged is False
        assert "security_expert" in reason

    def test_malformed_output_defaults_not_converged(self):
        """If parsing fails, safe default is NOT converged."""
        converged, reason = self.detector.detect(
            "Some random text without any sections", {}, 3,
        )
        assert converged is False

    def test_empty_output_treated_as_no_concerns(self):
        converged, reason = self.detector.detect("", {}, 2)
        assert converged is True

    def test_section_with_only_whitespace(self):
        output = "### High-Confidence Concerns\n   \n\n### Possible Concerns\n"
        converged, reason = self.detector.detect(output, {}, 2)
        assert converged is True

    def test_bullet_items_detected_as_concerns(self):
        output = (
            "### High-Confidence Concerns\n"
            "- **Issue**: Something is wrong\n"
        )
        converged, reason = self.detector.detect(output, {}, 2)
        assert converged is False

    def test_convergence_checkbox_detection(self):
        assert self.detector._has_convergence_signal(
            "### Convergence Signal\n- [x] Plan is fundamentally sound\n"
        )
        assert not self.detector._has_convergence_signal(
            "### Convergence Signal\n- [ ] Plan is fundamentally sound\n"
        )


# ---------------------------------------------------------------------------
# Tests: PlanSynthesizer
# ---------------------------------------------------------------------------

class TestPlanSynthesizer:
    def test_simple_synthesis_fallback(self, project_dir):
        synth = PlanSynthesizer(project_dir)
        result = synth._simple_synthesis(
            {"critic": "Critic output", "advocate": "Advocate output"},
            "F-0042", 1,
        )
        assert "F-0042" in result
        assert "Critic" in result
        assert "Advocate" in result

    def test_extract_revision_guidance(self, project_dir):
        synth = PlanSynthesizer(project_dir)
        synthesis = (
            "## High-Confidence Findings\nSome findings.\n\n"
            "## Revision Guidance\n"
            "1. Fix the auth module\n"
            "2. Add tests\n"
        )
        guidance = synth.extract_revision_guidance(synthesis)
        assert "Fix the auth" in guidance
        assert "Add tests" in guidance

    def test_extract_revision_guidance_missing(self, project_dir):
        synth = PlanSynthesizer(project_dir)
        guidance = synth.extract_revision_guidance("No guidance section here")
        assert guidance == ""


# ---------------------------------------------------------------------------
# Tests: ConvergenceLoop
# ---------------------------------------------------------------------------

class TestConvergenceLoop:
    def test_returns_early_when_review_disabled(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Settings\n- plan_review_enabled: no\n"
        )
        loop = ConvergenceLoop(project_dir)
        result = loop.run("F-0042", "dummy_path")
        assert result.plan_status == "APPROVED"
        assert result.converged is True

    def test_returns_manual_when_convergence_manual(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n"
            "- plan_review_enabled: yes\n"
            "- plan_review_convergence: manual\n"
        )
        loop = ConvergenceLoop(project_dir)
        result = loop.run("F-0042", "dummy_path")
        assert result.plan_status == "MANUAL"

    def test_plan_not_found_escalates(self, project_dir):
        loop = ConvergenceLoop(project_dir)
        result = loop.run("F-0042", "/nonexistent/plan.md")
        assert result.plan_status == "ESCALATED"

    @patch("auto.plan_convergence.spawn_claude")
    def test_converges_in_two_iterations(self, mock_spawn, project_dir):
        plan_path = str(
            project_dir / ".agentic" / "journal" / "plans"
            / "2026-01-01-F-0042-plan.md"
        )

        # Iteration 1: critic has concerns, advocate defends
        # Iteration 2: no concerns, converged
        call_count = [0]

        def spawn_side_effect(*args, **kwargs):
            call_count[0] += 1
            prompt = args[2] if len(args) > 2 else kwargs.get("prompt", "")
            if "CRITIC" in prompt.upper():
                if call_count[0] <= 2:
                    # First iteration — concerns
                    return (
                        "### High-Confidence Concerns\n"
                        "1. **Missing tests**: No test strategy\n\n"
                        "### Convergence Signal\n"
                        "- [ ] Plan is fundamentally sound\n"
                    )
                else:
                    # Second iteration — no concerns
                    return (
                        "### High-Confidence Concerns\nNone\n\n"
                        "### Convergence Signal\n"
                        "- [x] Plan is fundamentally sound\n"
                    )
            elif "ADVOCATE" in prompt.upper():
                return (
                    "### Honest Weaknesses\nNone significant\n\n"
                    "### Convergence Signal\n"
                    "- [x] Plan is fundamentally sound\n"
                )
            else:
                # Synthesis or revision agent
                return (
                    "## Revision Guidance\n1. Add test strategy\n"
                )

        mock_spawn.side_effect = spawn_side_effect

        reviewers = [
            ReviewerRole("critic", "plan-critic-agent.md", "Find flaws", True, "mid-tier"),
            ReviewerRole("advocate", "plan-advocate-agent.md", "Defend", True, "mid-tier"),
        ]

        loop = ConvergenceLoop(project_dir)
        result = loop.run(
            "F-0042", plan_path,
            max_iterations=3, reviewers=reviewers, autonomous=True,
        )
        assert result.converged is True
        assert result.plan_status == "APPROVED"
        assert result.iteration_count == 2

    @patch("auto.plan_convergence.spawn_claude")
    def test_escalates_at_max_iterations(self, mock_spawn, project_dir):
        plan_path = str(
            project_dir / ".agentic" / "journal" / "plans"
            / "2026-01-01-F-0042-plan.md"
        )

        # Always return concerns — never converge
        mock_spawn.return_value = (
            "### High-Confidence Concerns\n"
            "1. **Persistent issue**: Still broken\n\n"
            "### Convergence Signal\n"
            "- [ ] Plan is fundamentally sound\n"
        )

        reviewers = [
            ReviewerRole("critic", "plan-critic-agent.md", "Find flaws", True, "mid-tier"),
            ReviewerRole("advocate", "plan-advocate-agent.md", "Defend", True, "mid-tier"),
        ]

        loop = ConvergenceLoop(project_dir)
        result = loop.run(
            "F-0042", plan_path,
            max_iterations=2, reviewers=reviewers, autonomous=True,
        )
        assert result.converged is False
        assert result.plan_status == "ESCALATED"
        assert result.iteration_count == 2

    @patch("auto.plan_convergence.spawn_claude")
    def test_interactive_mode_returns_converged_not_approved(
        self, mock_spawn, project_dir,
    ):
        plan_path = str(
            project_dir / ".agentic" / "journal" / "plans"
            / "2026-01-01-F-0042-plan.md"
        )

        mock_spawn.return_value = (
            "### High-Confidence Concerns\nNone\n\n"
            "### Convergence Signal\n"
            "- [x] Plan is fundamentally sound\n"
        )

        reviewers = [
            ReviewerRole("critic", "plan-critic-agent.md", "Find flaws", True, "mid-tier"),
            ReviewerRole("advocate", "plan-advocate-agent.md", "Defend", True, "mid-tier"),
        ]

        loop = ConvergenceLoop(project_dir)
        result = loop.run(
            "F-0042", plan_path,
            max_iterations=3, reviewers=reviewers, autonomous=False,
        )
        assert result.converged is True
        assert result.plan_status == "CONVERGED"  # not APPROVED — user decides


# ---------------------------------------------------------------------------
# Tests: Plan status update
# ---------------------------------------------------------------------------

class TestPlanStatusUpdate:
    def test_updates_status_in_file(self, project_dir):
        plan_path = str(
            project_dir / ".agentic" / "journal" / "plans"
            / "2026-01-01-F-0042-plan.md"
        )
        loop = ConvergenceLoop(project_dir)
        loop._update_plan_status(plan_path, "APPROVED")
        content = Path(plan_path).read_text()
        assert "**Status**: APPROVED" in content

    def test_nonexistent_file_noop(self, project_dir):
        loop = ConvergenceLoop(project_dir)
        loop._update_plan_status("/nonexistent/plan.md", "APPROVED")
        # Should not raise
