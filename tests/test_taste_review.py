"""
Tests for F-0183: Taste and Style Settings.

Tests cover:
- Style settings parsing from STACK.md
- Style settings injection into critical agent context
- Taste review prompt template
- Missing style settings behavior (AC-004)
- review_taste wiring through review checkpoint system (AC-006)
- Taste verdict artifact naming (filename_prefix)
- Pending review filename collision prevention
- Multi-line HTML comment handling
- Human-resolved taste review verdict artifacts
"""
from __future__ import annotations

import json
import os
import re
import sys
import textwrap
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

# ---------------------------------------------------------------------------
# Path setup — match the pattern used by the modules under test
# ---------------------------------------------------------------------------
_LIB_DIR = Path(__file__).resolve().parent.parent / ".agentic" / "lib"
sys.path.insert(0, str(_LIB_DIR))
sys.path.insert(0, str(_LIB_DIR / "auto"))


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def tmp_project(tmp_path):
    """Create a minimal project structure for testing."""
    agentic = tmp_path / ".agentic"
    (agentic / "spec" / "acceptance").mkdir(parents=True)
    (agentic / "spec" / "reviews").mkdir(parents=True)
    (agentic / "session" / "reviews").mkdir(parents=True)

    # Minimal FEATURES.md
    (agentic / "spec" / "FEATURES.md").write_text(
        "## F-0042: Test Feature\n- **Status**: in_progress\n"
    )

    # Minimal AC file
    (agentic / "spec" / "acceptance" / "F-0042.md").write_text(
        "# F-0042: Test Feature\n\n- [ ] **AC-001**: Something\n"
    )

    # profiles.conf (needed by settings.py)
    presets = agentic / "presets"
    presets.mkdir(parents=True)
    # Copy real profiles.conf
    real_profiles = _LIB_DIR / "presets" / "profiles.conf"
    if real_profiles.exists():
        import shutil
        shutil.copy(real_profiles, presets / "profiles.conf")
    else:
        (presets / "profiles.conf").write_text(
            "discovery.review_taste=skip\n"
            "formal.review_taste=critical_agent\n"
        )

    return tmp_path


@pytest.fixture
def stack_with_style(tmp_project):
    """Create STACK.md with active style settings."""
    (tmp_project / "STACK.md").write_text(textwrap.dedent("""\
        ## Settings
        - profile: formal
        - review_taste: critical_agent

        ## Style & taste
        - style_guide: https://example.com/style
        - design_system: material-design-3
        - api_style: rest-jsonapi
    """))
    return tmp_project


@pytest.fixture
def stack_no_style(tmp_project):
    """Create STACK.md with style section fully commented out."""
    (tmp_project / "STACK.md").write_text(textwrap.dedent("""\
        ## Settings
        - profile: discovery
        - review_taste: skip

        ## Style & taste
        <!-- - style_guide: https://example.com/style -->
        <!-- - design_system: material-design-3 -->
        <!-- - api_style: rest-jsonapi -->
    """))
    return tmp_project


@pytest.fixture
def stack_taste_skip(tmp_project):
    """Create STACK.md with review_taste: skip but style settings present."""
    (tmp_project / "STACK.md").write_text(textwrap.dedent("""\
        ## Settings
        - profile: discovery
        - review_taste: skip

        ## Style & taste
        - style_guide: https://example.com/style
    """))
    return tmp_project


# ---------------------------------------------------------------------------
# TestStyleSettingsParsing
# ---------------------------------------------------------------------------

class TestStyleSettingsParsing:
    """AC-001: STACK.md supports style settings."""

    def test_all_three_settings_parsed(self, stack_with_style):
        from auto.critical_agent import CriticalAgent
        agent = CriticalAgent(stack_with_style)
        result = agent._load_style_settings()
        assert "style_guide: https://example.com/style" in result
        assert "design_system: material-design-3" in result
        assert "api_style: rest-jsonapi" in result

    def test_commented_out_settings_ignored(self, stack_no_style):
        from auto.critical_agent import CriticalAgent
        agent = CriticalAgent(stack_no_style)
        result = agent._load_style_settings()
        assert result == ""

    def test_partial_settings(self, tmp_project):
        (tmp_project / "STACK.md").write_text(textwrap.dedent("""\
            ## Style & taste
            - style_guide: https://example.com/style
            <!-- - design_system: material-design-3 -->
        """))
        from auto.critical_agent import CriticalAgent
        agent = CriticalAgent(tmp_project)
        result = agent._load_style_settings()
        assert "style_guide" in result
        assert "design_system" not in result

    def test_no_stack_file(self, tmp_project):
        from auto.critical_agent import CriticalAgent
        agent = CriticalAgent(tmp_project)
        result = agent._load_style_settings()
        assert result == ""

    def test_no_style_section(self, tmp_project):
        (tmp_project / "STACK.md").write_text("## Settings\n- profile: discovery\n")
        from auto.critical_agent import CriticalAgent
        agent = CriticalAgent(tmp_project)
        result = agent._load_style_settings()
        assert result == ""

    def test_path_traversal_guard(self, tmp_project):
        (tmp_project / "STACK.md").write_text(textwrap.dedent("""\
            ## Style & taste
            - style_guide: ../../etc/passwd
            - design_system: safe-value
        """))
        from auto.critical_agent import CriticalAgent
        agent = CriticalAgent(tmp_project)
        result = agent._load_style_settings()
        assert "../../etc/passwd" not in result
        assert "safe-value" in result


# ---------------------------------------------------------------------------
# TestStyleSettingsInContext
# ---------------------------------------------------------------------------

class TestStyleSettingsInContext:
    """AC-002: Style settings loaded into critical agent context for taste reviews."""

    def test_taste_review_gets_style_context(self, stack_with_style):
        from auto.critical_agent import CriticalAgent
        agent = CriticalAgent(stack_with_style)
        context = "## Transition\nF-0042: documented → committed"
        prompt = agent._build_prompt(context, "review_taste")
        assert "rest-jsonapi" in prompt
        assert "material-design-3" in prompt

    def test_code_review_no_style_context(self, stack_with_style):
        from auto.critical_agent import CriticalAgent
        agent = CriticalAgent(stack_with_style)
        context = "## Transition\nF-0042: documented → committed"
        prompt = agent._build_prompt(context, "review_code")
        # Style settings should NOT appear in code review
        assert "rest-jsonapi" not in prompt
        assert "{style_context}" not in prompt

    def test_taste_review_empty_style(self, tmp_project):
        (tmp_project / "STACK.md").write_text("## Settings\n- profile: discovery\n")
        from auto.critical_agent import CriticalAgent
        agent = CriticalAgent(tmp_project)
        context = "## Transition\nF-0042: documented → committed"
        prompt = agent._build_prompt(context, "review_taste")
        assert "No style settings declared" in prompt

    def test_style_context_single_occurrence(self, stack_with_style):
        """Style context should appear exactly once in the prompt."""
        from auto.critical_agent import CriticalAgent
        agent = CriticalAgent(stack_with_style)
        context = "## Transition\nF-0042: documented → committed"
        prompt = agent._build_prompt(context, "review_taste")
        # Count occurrences of the unique value
        assert prompt.count("rest-jsonapi") == 1


# ---------------------------------------------------------------------------
# TestTasteReviewTemplate
# ---------------------------------------------------------------------------

class TestTasteReviewTemplate:
    """AC-003: taste_review.md prompt template."""

    def test_template_exists(self):
        template = _LIB_DIR / "auto" / "prompts" / "taste_review.md"
        assert template.exists()

    def test_template_has_required_placeholders(self):
        template = _LIB_DIR / "auto" / "prompts" / "taste_review.md"
        content = template.read_text()
        assert "{style_context}" in content
        assert "{context}" in content
        assert "{focus}" in content
        assert "{verdict_schema}" in content

    def test_template_has_checklist(self):
        template = _LIB_DIR / "auto" / "prompts" / "taste_review.md"
        content = template.read_text()
        assert "Naming Conventions" in content
        assert "API Consistency" in content
        assert "Pattern Consistency" in content

    def test_template_different_from_critical_review(self):
        taste = (_LIB_DIR / "auto" / "prompts" / "taste_review.md").read_text()
        critical = (_LIB_DIR / "auto" / "prompts" / "critical_review.md").read_text()
        assert taste != critical
        assert "STYLE CONSISTENCY" in taste
        assert "CRITICAL REVIEWER" in critical

    def test_non_taste_uses_critical_template(self, stack_with_style):
        from auto.critical_agent import CriticalAgent
        agent = CriticalAgent(stack_with_style)
        prompt = agent._build_prompt("context", "review_code")
        assert "CRITICAL REVIEWER" in prompt

    def test_taste_uses_taste_template(self, stack_with_style):
        from auto.critical_agent import CriticalAgent
        agent = CriticalAgent(stack_with_style)
        prompt = agent._build_prompt("context", "review_taste")
        assert "STYLE CONSISTENCY" in prompt


# ---------------------------------------------------------------------------
# TestMissingStyleSettings
# ---------------------------------------------------------------------------

class TestMissingStyleSettings:
    """AC-004: Omitting style settings preserves existing behavior."""

    def test_no_style_settings_skips_taste_review(self, stack_no_style):
        from auto.review import check_taste_review
        ok, msgs = check_taste_review(
            stack_no_style, "F-0042", "documented", "committed",
        )
        assert ok is True
        assert msgs == []

    def test_skip_mode_skips_taste_review(self, stack_taste_skip):
        from auto.review import check_taste_review
        ok, msgs = check_taste_review(
            stack_taste_skip, "F-0042", "documented", "committed",
        )
        assert ok is True
        assert msgs == []


# ---------------------------------------------------------------------------
# TestReviewTasteWiring
# ---------------------------------------------------------------------------

class TestReviewTasteWiring:
    """AC-006: review_taste wired into review checkpoint system."""

    def test_skip_mode_allows_transition(self, stack_taste_skip):
        from auto.review import get_taste_review_mode, ReviewMode
        mode = get_taste_review_mode(stack_taste_skip)
        assert mode == ReviewMode.SKIP

    def test_critical_agent_mode_resolved(self, stack_with_style):
        from auto.review import get_taste_review_mode, ReviewMode
        mode = get_taste_review_mode(stack_with_style)
        assert mode == ReviewMode.CRITICAL_AGENT

    def test_non_code_transition_skips(self, stack_with_style):
        """Taste review only fires on code review transitions."""
        from auto.review import check_taste_review
        ok, msgs = check_taste_review(
            stack_with_style, "F-0042", "planned", "specced",
        )
        assert ok is True

    def test_code_transition_triggers(self, stack_with_style):
        """Taste review fires on documented→committed."""
        from auto.review import check_taste_review

        # Mock CriticalAgent to avoid spawning actual Claude
        mock_verdict = MagicMock()
        mock_verdict.verdict = "approved"
        mock_verdict.summary = "Looks consistent"

        with patch("auto.critical_agent.CriticalAgent") as MockAgent:
            MockAgent.return_value.review.return_value = mock_verdict
            ok, msgs = check_taste_review(
                stack_with_style, "F-0042", "documented", "committed",
            )
        assert ok is True
        assert any("approved" in m.lower() for m in msgs)

    def test_request_changes_blocks(self, stack_with_style):
        from auto.review import check_taste_review

        mock_verdict = MagicMock()
        mock_verdict.verdict = "request_changes"
        mock_verdict.summary = "Naming inconsistent"
        mock_verdict.issues = [
            {"severity": "medium", "description": "camelCase mixed with snake_case"}
        ]

        with patch("auto.critical_agent.CriticalAgent") as MockAgent:
            MockAgent.return_value.review.return_value = mock_verdict
            ok, msgs = check_taste_review(
                stack_with_style, "F-0042", "documented", "committed",
            )
        assert ok is False
        assert any("request" in m.lower() for m in msgs)

    def test_escalate_falls_back_to_human(self, stack_with_style):
        from auto.review import check_taste_review

        mock_verdict = MagicMock()
        mock_verdict.verdict = "escalate"
        mock_verdict.summary = "Ambiguous style direction"

        with patch("auto.critical_agent.CriticalAgent") as MockAgent, \
             patch("auto.review.create_pending_review", return_value="HN-099"):
            MockAgent.return_value.review.return_value = mock_verdict
            ok, msgs = check_taste_review(
                stack_with_style, "F-0042", "documented", "committed",
            )
        assert ok is False
        assert any("escalat" in m.lower() for m in msgs)

    def test_agent_error_non_blocking(self, stack_with_style):
        """Taste review errors are non-blocking (unlike code review)."""
        from auto.review import check_taste_review

        with patch("auto.critical_agent.CriticalAgent") as MockAgent:
            MockAgent.return_value.review.side_effect = RuntimeError("timeout")
            ok, msgs = check_taste_review(
                stack_with_style, "F-0042", "documented", "committed",
            )
        assert ok is True
        assert any("non-blocking" in m.lower() for m in msgs)

    def test_human_mode_creates_pending(self, tmp_project):
        (tmp_project / "STACK.md").write_text(textwrap.dedent("""\
            ## Settings
            - review_taste: human

            ## Style & taste
            - style_guide: https://example.com/style
        """))
        from auto.review import check_taste_review

        with patch("auto.review.create_pending_review", return_value=None) as mock_create:
            ok, msgs = check_taste_review(
                tmp_project, "F-0042", "documented", "committed",
            )
        assert ok is False
        mock_create.assert_called_once_with(
            tmp_project, "F-0042", "documented", "committed",
            "review_taste", "human",
        )

    def test_existing_taste_verdict_prevents_rerun(self, stack_with_style):
        """If taste verdict artifact exists, skip taste review."""
        from auto.review import check_taste_review
        from paths import get_paths

        paths = get_paths(stack_with_style)
        verdict_dir = paths.reviews_dir / "F-0042"
        verdict_dir.mkdir(parents=True, exist_ok=True)
        (verdict_dir / "taste_documented_to_committed.md").write_text("verdict")

        ok, msgs = check_taste_review(
            stack_with_style, "F-0042", "documented", "committed",
        )
        assert ok is True
        assert msgs == []


# ---------------------------------------------------------------------------
# TestTasteVerdictArtifact
# ---------------------------------------------------------------------------

class TestTasteVerdictArtifact:
    """Taste verdicts use filename_prefix to avoid clobbering code verdicts."""

    def test_taste_prefix_in_filename(self, stack_with_style):
        from auto.review import _write_verdict_artifact
        from paths import get_paths

        paths = get_paths(stack_with_style)
        result = _write_verdict_artifact(
            paths, "F-0042", "documented", "committed",
            "review_taste", "approved", "consistent",
            "critical_agent", "critical_agent",
            filename_prefix="taste_",
        )
        assert result.name == "taste_documented_to_committed.md"

    def test_no_clobber_with_code_verdict(self, stack_with_style):
        from auto.review import _write_verdict_artifact
        from paths import get_paths

        paths = get_paths(stack_with_style)

        # Write code review verdict
        code_verdict = _write_verdict_artifact(
            paths, "F-0042", "documented", "committed",
            "review_code", "approved", "code ok",
            "critical_agent", "critical_agent",
        )

        # Write taste verdict — should NOT overwrite code verdict
        taste_verdict = _write_verdict_artifact(
            paths, "F-0042", "documented", "committed",
            "review_taste", "approved", "style ok",
            "critical_agent", "critical_agent",
            filename_prefix="taste_",
        )

        assert code_verdict.exists()
        assert taste_verdict.exists()
        assert code_verdict != taste_verdict
        assert "code ok" in code_verdict.read_text()
        assert "style ok" in taste_verdict.read_text()

    def test_taste_verdict_prevents_rerun(self, stack_with_style):
        """Existing taste verdict artifact should prevent re-review."""
        from auto.review import _write_verdict_artifact, check_taste_review
        from paths import get_paths

        paths = get_paths(stack_with_style)
        _write_verdict_artifact(
            paths, "F-0042", "documented", "committed",
            "review_taste", "approved", "ok",
            "critical_agent", "critical_agent",
            filename_prefix="taste_",
        )

        ok, msgs = check_taste_review(
            stack_with_style, "F-0042", "documented", "committed",
        )
        assert ok is True
        assert msgs == []


# ---------------------------------------------------------------------------
# TestPendingReviewCollision
# ---------------------------------------------------------------------------

class TestPendingReviewCollision:
    """Pending review filenames must not collide between code and taste reviews."""

    def test_unique_pending_filenames(self, stack_with_style):
        from auto.review import create_pending_review
        from paths import get_paths

        paths = get_paths(stack_with_style)

        with patch("auto.review.get_paths", return_value=paths), \
             patch("subprocess.run"):
            # Simulate creating both code and taste pending reviews
            code_file = (
                paths.pending_reviews_dir
                / "F-0042_review_code_committed.json"
            )
            taste_file = (
                paths.pending_reviews_dir
                / "F-0042_review_taste_committed.json"
            )

            # Create code review pending file
            create_pending_review(
                stack_with_style, "F-0042", "documented", "committed",
                "review_code", "human",
            )
            # Create taste review pending file
            create_pending_review(
                stack_with_style, "F-0042", "documented", "committed",
                "review_taste", "human",
            )

            assert code_file.exists()
            assert taste_file.exists()
            assert code_file != taste_file


# ---------------------------------------------------------------------------
# TestMultiLineComments
# ---------------------------------------------------------------------------

class TestMultiLineComments:
    """Multi-line HTML comments must be handled correctly."""

    def test_multiline_comment_ignored(self, tmp_project):
        (tmp_project / "STACK.md").write_text(textwrap.dedent("""\
            ## Style & taste
            <!--
            - style_guide: https://example.com/style
            - design_system: material-design-3
            -->
            - api_style: rest-jsonapi
        """))
        from auto.critical_agent import CriticalAgent
        agent = CriticalAgent(tmp_project)
        result = agent._load_style_settings()
        assert "style_guide" not in result
        assert "design_system" not in result
        assert "api_style: rest-jsonapi" in result

    def test_has_style_settings_ignores_comments(self, tmp_project):
        (tmp_project / "STACK.md").write_text(textwrap.dedent("""\
            ## Style & taste
            <!--
            - style_guide: https://example.com/style
            -->
        """))
        from auto.review import _has_style_settings
        assert _has_style_settings(tmp_project) is False

    def test_has_style_settings_detects_uncommented(self, tmp_project):
        (tmp_project / "STACK.md").write_text(textwrap.dedent("""\
            ## Style & taste
            <!-- Optional section -->
            - style_guide: https://example.com/style
        """))
        from auto.review import _has_style_settings
        assert _has_style_settings(tmp_project) is True


# ---------------------------------------------------------------------------
# TestHumanResolvedTasteReview
# ---------------------------------------------------------------------------

class TestHumanResolvedTasteReview:
    """Human-resolved taste reviews must write verdict with taste_ prefix."""

    def test_resolve_taste_review_uses_prefix(self, stack_with_style):
        from auto.review import create_pending_review, resolve_review
        from paths import get_paths

        paths = get_paths(stack_with_style)

        # Create a taste pending review manually
        pending_dir = paths.pending_reviews_dir
        pending_dir.mkdir(parents=True, exist_ok=True)
        pending_file = pending_dir / "F-0042_review_taste_committed.json"
        pending_file.write_text(json.dumps({
            "feature_id": "F-0042",
            "from_state": "documented",
            "to_state": "committed",
            "review_setting": "review_taste",
            "review_mode": "human",
            "hn_id": None,
        }))

        # Resolve with approval — should write taste_ prefix verdict
        with patch("auto.state_machine.FeatureStateMachine") as MockSM, \
             patch("auto.gates.register_default_gates"), \
             patch("auto.state_machine.FeatureState"):
            mock_sm = MagicMock()
            mock_sm.transition.return_value = (True, ["Transitioned"])
            MockSM.return_value = mock_sm
            success, messages = resolve_review(
                stack_with_style, "F-0042", "committed",
                "approved", "Looks good",
            )

        # Check that taste_ prefix verdict was written
        verdict_dir = paths.reviews_dir / "F-0042"
        taste_verdict = verdict_dir / "taste_documented_to_committed.md"
        code_verdict = verdict_dir / "documented_to_committed.md"

        assert taste_verdict.exists(), "Taste verdict should use taste_ prefix"
        assert not code_verdict.exists(), "Should NOT write unprefixed verdict for taste"
        assert "review_taste" in taste_verdict.read_text()

    def test_resolve_code_review_no_prefix(self, stack_with_style):
        """Regular code reviews should NOT get taste_ prefix."""
        from auto.review import resolve_review
        from paths import get_paths

        paths = get_paths(stack_with_style)

        pending_dir = paths.pending_reviews_dir
        pending_dir.mkdir(parents=True, exist_ok=True)
        pending_file = pending_dir / "F-0042_review_code_committed.json"
        pending_file.write_text(json.dumps({
            "feature_id": "F-0042",
            "from_state": "documented",
            "to_state": "committed",
            "review_setting": "review_code",
            "review_mode": "human",
            "hn_id": None,
        }))

        with patch("auto.state_machine.FeatureStateMachine") as MockSM, \
             patch("auto.gates.register_default_gates"), \
             patch("auto.state_machine.FeatureState"):
            mock_sm = MagicMock()
            mock_sm.transition.return_value = (True, ["Transitioned"])
            MockSM.return_value = mock_sm
            success, messages = resolve_review(
                stack_with_style, "F-0042", "committed",
                "approved", "Code OK",
            )

        verdict_dir = paths.reviews_dir / "F-0042"
        code_verdict = verdict_dir / "documented_to_committed.md"
        taste_verdict = verdict_dir / "taste_documented_to_committed.md"

        assert code_verdict.exists(), "Code verdict should use no prefix"
        assert not taste_verdict.exists(), "Should NOT write taste_ prefix for code review"
