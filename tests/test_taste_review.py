#!/usr/bin/env python3
"""
Tests for Taste and Style Settings (F-0183).

Covers:
- AC-001: STACK.md style settings parsing
- AC-002: Style settings loaded into critical agent context
- AC-003: taste_review.md template used for taste reviews
- AC-004: Missing style settings preserves existing behavior (skip gracefully)
- AC-005: Tests verify taste settings loading and passing (this file)
- AC-006: review_taste wired into review checkpoint system
"""
import json
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "auto"))

from auto.critical_agent import CriticalAgent, _REVIEW_FOCUS
from auto.review import (
    check_taste_review,
    get_taste_review_mode,
    ReviewMode,
    _has_style_settings,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(autouse=True)
def clear_caches():
    """Clear settings and paths caches between tests."""
    import settings as settings_mod
    import paths as paths_mod
    yield
    if hasattr(settings_mod, '_cache'):
        settings_mod._cache.clear()
    if hasattr(paths_mod, '_paths_cache'):
        paths_mod._paths_cache.clear()


@pytest.fixture
def project_dir():
    """Temporary project directory with taste review infrastructure."""
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        (root / ".agentic" / "lib" / "auto" / "prompts").mkdir(parents=True)
        (root / ".agentic" / "lib" / "tools").mkdir(parents=True)
        (root / ".agentic" / "spec" / "acceptance").mkdir(parents=True)
        (root / ".agentic" / "spec" / "reviews").mkdir(parents=True)
        (root / ".agentic" / "session" / "reviews").mkdir(parents=True)
        (root / ".agentic" / "journal" / "plans").mkdir(parents=True)
        (root / ".agentic" / "presets").mkdir(parents=True)

        # Copy settings infrastructure
        lib_src = Path(__file__).parent.parent / ".agentic" / "lib"
        for f in ["paths.py", "settings.py"]:
            src = lib_src / f
            if src.exists():
                (root / ".agentic" / "lib" / f).write_text(src.read_text())

        # Copy profiles.conf to correct location
        profiles_src = lib_src / "presets" / "profiles.conf"
        if profiles_src.exists():
            (root / ".agentic" / "presets" / "profiles.conf").write_text(
                profiles_src.read_text()
            )

        # Copy prompt templates
        for tmpl in ("critical_review.md", "taste_review.md"):
            src = lib_src / "auto" / "prompts" / tmpl
            if src.exists():
                (root / ".agentic" / "lib" / "auto" / "prompts" / tmpl).write_text(
                    src.read_text()
                )

        # Create blocker.sh mock
        (root / ".agentic" / "lib" / "tools" / "blocker.sh").write_text(
            "#!/bin/bash\necho 'mock'\n"
        )

        # Default STACK.md with no style settings
        (root / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- agent_mode: balanced\n"
        )

        # Sample feature
        (root / ".agentic" / "spec" / "FEATURES.md").write_text(
            "# Features\n\n"
            "## F-0042: Test Feature\n\n"
            "**Status**: implementing\n\n---\n"
        )
        (root / ".agentic" / "spec" / "acceptance" / "F-0042.md").write_text(
            "# F-0042\n- [ ] **AC-001**: Something works\n"
        )

        yield root


def _add_style_settings(root: Path, settings: str = "") -> None:
    """Add style & taste section to STACK.md."""
    content = (root / "STACK.md").read_text()
    if not settings:
        settings = (
            "- style_guide: docs/style-guide.md\n"
            "- design_system: docs/design-system.md\n"
            "- api_style: rest-jsonapi\n"
        )
    content += f"\n## Style & taste\n{settings}\n## Summary\n"
    (root / "STACK.md").write_text(content)


# ---------------------------------------------------------------------------
# AC-001: STACK.md style settings parsing
# ---------------------------------------------------------------------------

class TestStyleSettingsParsing:
    """Test that style settings are correctly parsed from STACK.md."""

    def test_has_style_settings_with_settings(self, project_dir):
        _add_style_settings(project_dir)
        assert _has_style_settings(project_dir) is True

    def test_has_style_settings_without_section(self, project_dir):
        assert _has_style_settings(project_dir) is False

    def test_has_style_settings_all_commented(self, project_dir):
        content = (project_dir / "STACK.md").read_text()
        content += (
            "\n## Style & taste\n"
            "<!-- - style_guide: docs/style.md -->\n"
            "<!-- - api_style: rest -->\n"
        )
        (project_dir / "STACK.md").write_text(content)
        assert _has_style_settings(project_dir) is False

    def test_has_style_settings_partial(self, project_dir):
        _add_style_settings(project_dir, "- api_style: graphql\n")
        assert _has_style_settings(project_dir) is True


# ---------------------------------------------------------------------------
# AC-002: Style settings loaded into critical agent context
# ---------------------------------------------------------------------------

class TestStyleSettingsInContext:
    """Test that style settings appear in critical agent context."""

    def test_taste_review_includes_style_settings(self, project_dir):
        _add_style_settings(project_dir)
        agent = CriticalAgent(project_dir)
        context = agent._assemble_context(
            "F-0042", "documented", "committed", "review_taste",
        )
        assert "Style Settings" in context
        assert "style_guide" in context
        assert "api_style" in context

    def test_code_review_does_not_include_style_settings(self, project_dir):
        _add_style_settings(project_dir)
        agent = CriticalAgent(project_dir)
        context = agent._assemble_context(
            "F-0042", "documented", "committed", "review_code",
        )
        assert "Style Settings" not in context

    def test_taste_review_loads_referenced_files(self, project_dir):
        """Referenced style guide files should be loaded into context."""
        (project_dir / "docs").mkdir(exist_ok=True)
        (project_dir / "docs" / "style-guide.md").write_text(
            "# Style Guide\n\nUse blue primary color.\n"
        )
        _add_style_settings(project_dir)
        agent = CriticalAgent(project_dir)
        context = agent._assemble_context(
            "F-0042", "documented", "committed", "review_taste",
        )
        assert "Use blue primary color" in context

    def test_taste_review_without_style_settings_has_empty_context(self, project_dir):
        """When no style settings exist, style context is empty."""
        agent = CriticalAgent(project_dir)
        context = agent._assemble_context(
            "F-0042", "documented", "committed", "review_taste",
        )
        assert "Style Settings" not in context


# ---------------------------------------------------------------------------
# AC-003: taste_review.md prompt template
# ---------------------------------------------------------------------------

class TestTasteReviewTemplate:
    """Test that taste reviews use the dedicated template."""

    def test_taste_review_uses_taste_template(self, project_dir):
        _add_style_settings(project_dir)
        agent = CriticalAgent(project_dir)
        prompt = agent._build_prompt("test context", "review_taste")
        assert "TASTE REVIEWER" in prompt
        assert "CRITICAL REVIEWER" not in prompt

    def test_code_review_uses_critical_template(self, project_dir):
        agent = CriticalAgent(project_dir)
        prompt = agent._build_prompt("test context", "review_code")
        assert "CRITICAL REVIEWER" in prompt
        assert "TASTE REVIEWER" not in prompt

    def test_taste_template_includes_style_context(self, project_dir):
        _add_style_settings(project_dir)
        agent = CriticalAgent(project_dir)
        prompt = agent._build_prompt("test context", "review_taste")
        assert "style_guide" in prompt
        assert "api_style" in prompt

    def test_taste_template_no_settings_shows_fallback(self, project_dir):
        agent = CriticalAgent(project_dir)
        prompt = agent._build_prompt("test context", "review_taste")
        assert "No style settings declared" in prompt


# ---------------------------------------------------------------------------
# AC-004: Missing style settings preserves existing behavior
# ---------------------------------------------------------------------------

class TestMissingStyleSettings:
    """Test that omitting style settings skips taste review gracefully."""

    def test_no_style_settings_skips_taste_review(self, project_dir):
        # review_taste is critical_agent in formal profile, but no style settings
        can_proceed, msgs = check_taste_review(
            project_dir, "F-0042", "documented", "committed",
        )
        assert can_proceed is True
        assert msgs == []

    def test_style_settings_present_triggers_review(self, project_dir):
        _add_style_settings(project_dir)
        # Mock spawn_claude to return approved verdict
        approved = json.dumps({
            "verdict": "approved",
            "confidence": "high",
            "summary": "Style consistent",
            "issues": [],
            "recommendation": "Proceed",
        })
        with patch("auto.critical_agent.spawn_claude", return_value=f"```json\n{approved}\n```"):
            can_proceed, msgs = check_taste_review(
                project_dir, "F-0042", "documented", "committed",
            )
        assert can_proceed is True
        assert any("Taste review approved" in m for m in msgs)


# ---------------------------------------------------------------------------
# AC-006: review_taste wired into review checkpoint system
# ---------------------------------------------------------------------------

class TestReviewTasteWiring:
    """Test review_taste setting routing: skip/human/critical_agent."""

    def test_review_taste_skip_bypasses(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: discovery\n- review_taste: skip\n"
        )
        _add_style_settings(project_dir)
        can_proceed, msgs = check_taste_review(
            project_dir, "F-0042", "documented", "committed",
        )
        assert can_proceed is True

    def test_review_taste_non_code_transition_skips(self, project_dir):
        """Taste review only fires on code review transitions."""
        _add_style_settings(project_dir)
        can_proceed, msgs = check_taste_review(
            project_dir, "F-0042", "planned", "specced",
        )
        assert can_proceed is True

    def test_review_taste_critical_agent_approved(self, project_dir):
        _add_style_settings(project_dir)
        approved = json.dumps({
            "verdict": "approved",
            "confidence": "high",
            "summary": "Style OK",
            "issues": [],
            "recommendation": "Proceed",
        })
        with patch("auto.critical_agent.spawn_claude", return_value=f"```json\n{approved}\n```"):
            can_proceed, msgs = check_taste_review(
                project_dir, "F-0042", "documented", "committed",
            )
        assert can_proceed is True

    def test_review_taste_critical_agent_request_changes(self, project_dir):
        _add_style_settings(project_dir)
        changes = json.dumps({
            "verdict": "request_changes",
            "confidence": "high",
            "summary": "API style inconsistent",
            "issues": [
                {"severity": "high", "category": "taste",
                 "description": "Endpoint uses camelCase, project uses snake_case",
                 "location": "api/users.py:15"}
            ],
            "recommendation": "Rename endpoints to snake_case",
        })
        with patch("auto.critical_agent.spawn_claude", return_value=f"```json\n{changes}\n```"):
            can_proceed, msgs = check_taste_review(
                project_dir, "F-0042", "documented", "committed",
            )
        assert can_proceed is False
        assert any("request" in m.lower() for m in msgs)

    def test_get_taste_review_mode_from_profile(self, project_dir):
        """Formal profile defaults to critical_agent for review_taste."""
        mode = get_taste_review_mode(project_dir)
        assert mode == ReviewMode.CRITICAL_AGENT

    def test_get_taste_review_mode_explicit_skip(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- review_taste: skip\n"
        )
        mode = get_taste_review_mode(project_dir)
        assert mode == ReviewMode.SKIP

    def test_review_taste_focus_exists(self):
        """review_taste has a focus entry in _REVIEW_FOCUS."""
        assert "review_taste" in _REVIEW_FOCUS
        assert "style" in _REVIEW_FOCUS["review_taste"].lower()


# ---------------------------------------------------------------------------
# Integration: existing verdict artifact prevents re-review
# ---------------------------------------------------------------------------

class TestTasteVerdictArtifact:
    """Test that existing verdict artifacts prevent re-triggering taste review."""

    def test_existing_verdict_skips_review(self, project_dir):
        _add_style_settings(project_dir)
        # Create a verdict artifact in the reviews dir (spec/reviews/)
        verdict_dir = project_dir / ".agentic" / "spec" / "reviews" / "F-0042"
        verdict_dir.mkdir(parents=True, exist_ok=True)
        (verdict_dir / "taste_documented_to_committed.md").write_text(
            "Approved by critical agent\n"
        )
        can_proceed, msgs = check_taste_review(
            project_dir, "F-0042", "documented", "committed",
        )
        assert can_proceed is True
