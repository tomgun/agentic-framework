#!/usr/bin/env python3
"""
Tests for Taste and Style Settings (F-0183).

Covers:
- AC-001: STACK.md style settings parsing
- AC-002: Style settings loaded into critical agent context
- AC-003: taste_review.md template used for taste reviews
- AC-004: Missing style settings preserves existing behavior
- AC-005: Tests verify taste settings loading and passing (this file)
- AC-006: review_taste wired into review checkpoint system
- Review finding #1: Verdict artifact filename uses taste_ prefix
- Review finding #2: Pending review files include review_setting
- Review finding #3: Style context appears only once in prompt (not duplicated)
- Review finding #4: Multi-line HTML comment handling
- Review finding #8: Path traversal guard on referenced files
"""
import json
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "auto"))

from auto.critical_agent import CriticalAgent, _REVIEW_FOCUS
from auto.review import (
    check_taste_review,
    get_taste_review_mode,
    ReviewMode,
    _has_style_settings,
    _write_verdict_artifact,
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


APPROVED_VERDICT = json.dumps({
    "verdict": "approved",
    "confidence": "high",
    "summary": "Style consistent",
    "issues": [],
    "recommendation": "Proceed",
})

REQUEST_CHANGES_VERDICT = json.dumps({
    "verdict": "request_changes",
    "confidence": "high",
    "summary": "API style inconsistent",
    "issues": [
        {"severity": "high", "category": "taste",
         "description": "Endpoint uses camelCase, project uses snake_case",
         "location": "api/users.py:15"}
    ],
    "recommendation": "Rename endpoints",
})

ESCALATE_VERDICT = json.dumps({
    "verdict": "escalate",
    "confidence": "low",
    "summary": "Style settings too vague to evaluate",
    "issues": [],
    "recommendation": "Human should review",
})


# ---------------------------------------------------------------------------
# AC-001: STACK.md style settings parsing
# ---------------------------------------------------------------------------

class TestStyleSettingsParsing:
    def test_has_style_settings_with_settings(self, project_dir):
        _add_style_settings(project_dir)
        assert _has_style_settings(project_dir) is True

    def test_has_style_settings_without_section(self, project_dir):
        assert _has_style_settings(project_dir) is False

    def test_has_style_settings_all_commented_single_line(self, project_dir):
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

    def test_has_style_settings_multi_line_comment(self, project_dir):
        """Review finding #4: Multi-line HTML comments must not be treated as active."""
        content = (project_dir / "STACK.md").read_text()
        content += (
            "\n## Style & taste\n"
            "<!--\n"
            "- style_guide: docs/style.md\n"
            "- api_style: rest\n"
            "-->\n"
        )
        (project_dir / "STACK.md").write_text(content)
        assert _has_style_settings(project_dir) is False

    def test_has_style_settings_mixed_comment_and_active(self, project_dir):
        """Active setting after a multi-line comment block."""
        content = (project_dir / "STACK.md").read_text()
        content += (
            "\n## Style & taste\n"
            "<!--\n"
            "- style_guide: docs/style.md\n"
            "-->\n"
            "- api_style: graphql\n"
        )
        (project_dir / "STACK.md").write_text(content)
        assert _has_style_settings(project_dir) is True


# ---------------------------------------------------------------------------
# AC-002: Style settings loaded into critical agent context
# ---------------------------------------------------------------------------

class TestStyleSettingsInContext:
    def test_taste_review_context_does_NOT_include_style_settings(self, project_dir):
        """Review finding #3: Style context goes in prompt template only, not context."""
        _add_style_settings(project_dir)
        agent = CriticalAgent(project_dir)
        context = agent._assemble_context(
            "F-0042", "documented", "committed", "review_taste",
        )
        # Style settings should NOT be in _assemble_context (they're in _build_prompt)
        assert "Style Settings" not in context

    def test_code_review_does_not_include_style_settings(self, project_dir):
        _add_style_settings(project_dir)
        agent = CriticalAgent(project_dir)
        context = agent._assemble_context(
            "F-0042", "documented", "committed", "review_code",
        )
        assert "Style Settings" not in context

    def test_taste_review_loads_referenced_files(self, project_dir):
        """Referenced style guide files should be loaded into prompt."""
        (project_dir / "docs").mkdir(exist_ok=True)
        (project_dir / "docs" / "style-guide.md").write_text(
            "# Style Guide\n\nUse blue primary color.\n"
        )
        _add_style_settings(project_dir)
        agent = CriticalAgent(project_dir)
        prompt = agent._build_prompt("test context", "review_taste")
        assert "Use blue primary color" in prompt

    def test_taste_review_path_traversal_blocked(self, project_dir):
        """Review finding #8: Path traversal in style_guide references must be blocked."""
        _add_style_settings(project_dir, "- style_guide: ../../etc/passwd\n")
        agent = CriticalAgent(project_dir)
        style = agent._load_style_settings()
        # Should have the declared setting but NOT the file content
        assert "style_guide" in style
        assert "root:" not in style  # /etc/passwd content not loaded


# ---------------------------------------------------------------------------
# AC-003: taste_review.md prompt template
# ---------------------------------------------------------------------------

class TestTasteReviewTemplate:
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

    def test_style_context_appears_exactly_once(self, project_dir):
        """Review finding #3: Style context must not be duplicated."""
        _add_style_settings(project_dir, "- api_style: rest-jsonapi\n")
        agent = CriticalAgent(project_dir)
        prompt = agent._build_prompt("test context", "review_taste")
        # The setting value "rest-jsonapi" should appear exactly once
        # (api_style as a word may appear in template checklist text too)
        assert prompt.count("rest-jsonapi") == 1

    def test_style_context_not_replaced_in_critical_template(self, project_dir):
        """Review finding #9: {style_context} replacement only runs for taste."""
        agent = CriticalAgent(project_dir)
        prompt = agent._build_prompt("test context", "review_code")
        assert "{style_context}" not in prompt  # template doesn't have it


# ---------------------------------------------------------------------------
# AC-004: Missing style settings preserves existing behavior
# ---------------------------------------------------------------------------

class TestMissingStyleSettings:
    def test_no_style_settings_skips_taste_review(self, project_dir):
        can_proceed, msgs = check_taste_review(
            project_dir, "F-0042", "documented", "committed",
        )
        assert can_proceed is True
        assert msgs == []

    def test_style_settings_present_triggers_review(self, project_dir):
        _add_style_settings(project_dir)
        with patch("auto.critical_agent.spawn_claude",
                    return_value=f"```json\n{APPROVED_VERDICT}\n```"):
            can_proceed, msgs = check_taste_review(
                project_dir, "F-0042", "documented", "committed",
            )
        assert can_proceed is True
        assert any("Taste review approved" in m for m in msgs)


# ---------------------------------------------------------------------------
# AC-006: review_taste wired into review checkpoint system
# ---------------------------------------------------------------------------

class TestReviewTasteWiring:
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
        _add_style_settings(project_dir)
        can_proceed, msgs = check_taste_review(
            project_dir, "F-0042", "planned", "specced",
        )
        assert can_proceed is True

    def test_review_taste_critical_agent_approved(self, project_dir):
        _add_style_settings(project_dir)
        with patch("auto.critical_agent.spawn_claude",
                    return_value=f"```json\n{APPROVED_VERDICT}\n```"):
            can_proceed, msgs = check_taste_review(
                project_dir, "F-0042", "documented", "committed",
            )
        assert can_proceed is True

    def test_review_taste_critical_agent_request_changes(self, project_dir):
        _add_style_settings(project_dir)
        with patch("auto.critical_agent.spawn_claude",
                    return_value=f"```json\n{REQUEST_CHANGES_VERDICT}\n```"):
            can_proceed, msgs = check_taste_review(
                project_dir, "F-0042", "documented", "committed",
            )
        assert can_proceed is False
        assert any("request" in m.lower() for m in msgs)

    def test_review_taste_critical_agent_escalate(self, project_dir):
        """Review finding #13: Escalation path must be tested."""
        _add_style_settings(project_dir)
        with patch("auto.critical_agent.spawn_claude",
                    return_value=f"```json\n{ESCALATE_VERDICT}\n```"):
            can_proceed, msgs = check_taste_review(
                project_dir, "F-0042", "documented", "committed",
            )
        assert can_proceed is False
        assert any("escalat" in m.lower() for m in msgs)

    def test_get_taste_review_mode_from_profile(self, project_dir):
        mode = get_taste_review_mode(project_dir)
        assert mode == ReviewMode.CRITICAL_AGENT

    def test_get_taste_review_mode_explicit_skip(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- review_taste: skip\n"
        )
        mode = get_taste_review_mode(project_dir)
        assert mode == ReviewMode.SKIP

    def test_review_taste_focus_exists(self):
        assert "review_taste" in _REVIEW_FOCUS
        assert "style" in _REVIEW_FOCUS["review_taste"].lower()


# ---------------------------------------------------------------------------
# Review finding #1: Verdict artifact uses taste_ prefix (CRITICAL)
# ---------------------------------------------------------------------------

class TestTasteVerdictArtifact:
    def test_approved_verdict_creates_taste_prefixed_artifact(self, project_dir):
        """Critical fix: taste verdict artifact must use taste_ prefix."""
        _add_style_settings(project_dir)
        with patch("auto.critical_agent.spawn_claude",
                    return_value=f"```json\n{APPROVED_VERDICT}\n```"):
            check_taste_review(
                project_dir, "F-0042", "documented", "committed",
            )
        # Verify the artifact was written with taste_ prefix
        verdict_file = (
            project_dir / ".agentic" / "spec" / "reviews" / "F-0042"
            / "taste_documented_to_committed.md"
        )
        assert verdict_file.exists(), "Taste verdict artifact must use taste_ prefix"
        content = verdict_file.read_text()
        assert "review_taste" in content

    def test_taste_artifact_does_not_clobber_code_review_artifact(self, project_dir):
        """Critical fix: taste artifact and code review artifact are separate files."""
        _add_style_settings(project_dir)
        from paths import get_paths
        paths = get_paths(project_dir)

        # Write a code review verdict first
        _write_verdict_artifact(
            paths, "F-0042", "documented", "committed",
            "review_code", "approved", "Code looks good",
            "critical_agent", "critical_agent",
        )
        code_file = (
            project_dir / ".agentic" / "spec" / "reviews" / "F-0042"
            / "documented_to_committed.md"
        )
        assert code_file.exists()

        # Now write a taste verdict
        _write_verdict_artifact(
            paths, "F-0042", "documented", "committed",
            "review_taste", "approved", "Style consistent",
            "critical_agent", "critical_agent",
            filename_prefix="taste_",
        )
        taste_file = (
            project_dir / ".agentic" / "spec" / "reviews" / "F-0042"
            / "taste_documented_to_committed.md"
        )
        assert taste_file.exists()
        # Code review artifact must still exist (not clobbered)
        assert code_file.exists()
        assert "Code looks good" in code_file.read_text()

    def test_existing_taste_verdict_prevents_re_review(self, project_dir):
        _add_style_settings(project_dir)
        # Pre-create taste verdict artifact
        verdict_dir = project_dir / ".agentic" / "spec" / "reviews" / "F-0042"
        verdict_dir.mkdir(parents=True, exist_ok=True)
        (verdict_dir / "taste_documented_to_committed.md").write_text(
            "Approved\n"
        )
        can_proceed, msgs = check_taste_review(
            project_dir, "F-0042", "documented", "committed",
        )
        assert can_proceed is True


# ---------------------------------------------------------------------------
# Review finding #2: Pending review files include review_setting
# ---------------------------------------------------------------------------

class TestPendingReviewCollision:
    def test_human_taste_review_creates_unique_pending_file(self, project_dir):
        """High fix: taste pending review filename must differ from code review."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- review_taste: human\n"
        )
        _add_style_settings(project_dir)
        check_taste_review(
            project_dir, "F-0042", "documented", "committed",
        )
        # Check that the pending file includes review_taste in the name
        pending_dir = project_dir / ".agentic" / "session" / "reviews"
        pending_files = list(pending_dir.glob("F-0042_*_committed.json"))
        assert len(pending_files) == 1
        assert "review_taste" in pending_files[0].name


# ---------------------------------------------------------------------------
# Review finding #4: Multi-line HTML comment handling in _load_style_settings
# ---------------------------------------------------------------------------

class TestMultiLineComments:
    def test_load_style_settings_ignores_multi_line_comments(self, project_dir):
        """Style settings inside multi-line comments must not be loaded."""
        content = (project_dir / "STACK.md").read_text()
        content += (
            "\n## Style & taste\n"
            "<!--\n"
            "- style_guide: docs/style.md\n"
            "- api_style: rest\n"
            "-->\n"
            "- design_system: docs/ds.md\n"
        )
        (project_dir / "STACK.md").write_text(content)
        agent = CriticalAgent(project_dir)
        style = agent._load_style_settings()
        assert "design_system" in style
        assert "style_guide" not in style
        assert "api_style" not in style
