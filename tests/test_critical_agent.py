#!/usr/bin/env python3
"""
Tests for the Critical Review Agent (F-0182, ADR-001 Phase 4).

Covers:
- ReviewVerdict dataclass
- _parse_verdict: fenced JSON, bare JSON, malformed, multiple blocks (last wins)
- _assemble_context: per-review-type context (code, spec, plan, regression)
- _get_git_diff: branch detection and truncation
- _resolve_model: full fallback chain (explicit → agent_mode → None)
- _parse_model_customization: commented-out section handling
- review(): end-to-end with mocked spawn_claude
- Error handling: timeout, transient (retry), unavailable
- Escalation on parse failure
- Read-only: spawn_claude called with print_mode=True
- Only approved verdicts produce artifacts (tested via review.py integration)
"""
import json
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch, MagicMock, call

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "auto"))

from auto.critical_agent import CriticalAgent, ReviewVerdict, _DIFF_MAX_LINES


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
    """Temporary project directory with settings infrastructure."""
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        (root / ".agentic" / "lib" / "auto" / "prompts").mkdir(parents=True)
        (root / ".agentic" / "lib" / "tools").mkdir(parents=True)
        (root / ".agentic" / "spec" / "acceptance").mkdir(parents=True)
        (root / ".agentic" / "spec" / "reviews").mkdir(parents=True)
        (root / ".agentic" / "session" / "reviews").mkdir(parents=True)
        (root / ".agentic" / "journal" / "plans").mkdir(parents=True)

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

        # Copy prompt template
        prompt_src = lib_src / "auto" / "prompts" / "critical_review.md"
        if prompt_src.exists():
            (root / ".agentic" / "lib" / "auto" / "prompts" / "critical_review.md").write_text(
                prompt_src.read_text()
            )

        # Create blocker.sh mock
        (root / ".agentic" / "lib" / "tools" / "blocker.sh").write_text(
            "#!/bin/bash\necho 'mock'\n"
        )

        # Default STACK.md
        (root / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- agent_mode: premium\n"
        )

        # Sample FEATURES.md
        (root / ".agentic" / "spec" / "FEATURES.md").write_text(
            "# Features\n\n"
            "## F-0042: Test Feature\n\n"
            "**Status**: implementing\n"
            "**Category**: Test\n\n"
            "**Description**: A test feature.\n\n---\n\n"
            "## F-0043: Other Feature\n\n"
            "**Status**: planned\n\n---\n"
        )

        # Sample acceptance criteria
        (root / ".agentic" / "spec" / "acceptance" / "F-0042.md").write_text(
            "# F-0042: Test Feature\n\n"
            "- [ ] **AC-001**: Something works\n"
            "- [ ] **AC-002**: Something else works\n"
        )

        yield root


def make_agent(project_dir):
    """Create a CriticalAgent for the temp project."""
    return CriticalAgent(project_dir)


# ---------------------------------------------------------------------------
# Sample verdict JSON for tests
# ---------------------------------------------------------------------------

APPROVED_JSON = json.dumps({
    "verdict": "approved",
    "confidence": "high",
    "summary": "Changes look correct and well-tested",
    "issues": [],
    "recommendation": "Proceed with merge",
})

REQUEST_CHANGES_JSON = json.dumps({
    "verdict": "request_changes",
    "confidence": "high",
    "summary": "Missing error handling in parser",
    "issues": [
        {
            "severity": "high",
            "category": "correctness",
            "description": "No try/except around JSON parsing",
            "location": "parser.py:42",
        },
        {
            "severity": "medium",
            "category": "testing",
            "description": "Missing test for empty input",
            "location": "test_parser.py",
        },
    ],
    "recommendation": "Add error handling and test coverage",
})

ESCALATE_JSON = json.dumps({
    "verdict": "escalate",
    "confidence": "low",
    "summary": "Complex architectural change needs human judgment",
    "issues": [],
    "recommendation": "Human should review the design decision",
})


# ---------------------------------------------------------------------------
# TestReviewVerdict
# ---------------------------------------------------------------------------

class TestReviewVerdict:
    def test_defaults(self):
        v = ReviewVerdict(verdict="approved")
        assert v.verdict == "approved"
        assert v.confidence == "medium"
        assert v.summary == ""
        assert v.issues == []
        assert v.raw_output == ""

    def test_full_construction(self):
        v = ReviewVerdict(
            verdict="request_changes",
            confidence="high",
            summary="Needs work",
            issues=[{"severity": "high", "description": "Bug"}],
            recommendation="Fix it",
            raw_output="raw...",
        )
        assert v.verdict == "request_changes"
        assert len(v.issues) == 1


# ---------------------------------------------------------------------------
# TestParseVerdict
# ---------------------------------------------------------------------------

class TestParseVerdict:
    def test_fenced_json(self, project_dir):
        agent = make_agent(project_dir)
        output = f"Here is my review:\n\n```json\n{APPROVED_JSON}\n```\n\nThat's all."
        verdict = agent._parse_verdict(output)
        assert verdict.verdict == "approved"
        assert verdict.confidence == "high"
        assert verdict.summary == "Changes look correct and well-tested"

    def test_fenced_json_case_insensitive(self, project_dir):
        agent = make_agent(project_dir)
        output = f"```JSON\n{APPROVED_JSON}\n```"
        verdict = agent._parse_verdict(output)
        assert verdict.verdict == "approved"

    def test_multiple_fenced_blocks_last_wins(self, project_dir):
        agent = make_agent(project_dir)
        wrong = json.dumps({"verdict": "escalate", "summary": "wrong"})
        right = json.dumps({"verdict": "approved", "summary": "correct"})
        output = f"```json\n{wrong}\n```\n\nActually:\n\n```json\n{right}\n```"
        verdict = agent._parse_verdict(output)
        assert verdict.verdict == "approved"
        assert verdict.summary == "correct"

    def test_bare_json_fallback(self, project_dir):
        agent = make_agent(project_dir)
        output = f"My verdict is: {APPROVED_JSON}"
        verdict = agent._parse_verdict(output)
        assert verdict.verdict == "approved"

    def test_malformed_json_escalates(self, project_dir):
        agent = make_agent(project_dir)
        output = "```json\n{not valid json\n```"
        verdict = agent._parse_verdict(output)
        assert verdict.verdict == "escalate"
        assert "parse" in verdict.summary.lower()

    def test_no_json_escalates(self, project_dir):
        agent = make_agent(project_dir)
        output = "I reviewed the code and it looks fine."
        verdict = agent._parse_verdict(output)
        assert verdict.verdict == "escalate"
        assert verdict.confidence == "low"

    def test_unknown_verdict_value_becomes_escalate(self, project_dir):
        agent = make_agent(project_dir)
        bad_verdict = json.dumps({"verdict": "maybe", "summary": "unsure"})
        output = f"```json\n{bad_verdict}\n```"
        verdict = agent._parse_verdict(output)
        assert verdict.verdict == "escalate"

    def test_request_changes_with_issues(self, project_dir):
        agent = make_agent(project_dir)
        output = f"```json\n{REQUEST_CHANGES_JSON}\n```"
        verdict = agent._parse_verdict(output)
        assert verdict.verdict == "request_changes"
        assert len(verdict.issues) == 2
        assert verdict.issues[0]["severity"] == "high"

    def test_raw_output_preserved(self, project_dir):
        agent = make_agent(project_dir)
        output = f"preamble\n```json\n{APPROVED_JSON}\n```\npostamble"
        verdict = agent._parse_verdict(output)
        assert "preamble" in verdict.raw_output
        assert "postamble" in verdict.raw_output


# ---------------------------------------------------------------------------
# TestResolveModel
# ---------------------------------------------------------------------------

class TestResolveModel:
    def test_no_model_customization_uses_agent_mode(self, project_dir):
        """agent_mode: premium → None (use CLI default)."""
        agent = make_agent(project_dir)
        assert agent._resolve_model() is None

    def test_agent_mode_balanced(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- agent_mode: balanced\n"
        )
        agent = make_agent(project_dir)
        assert agent._resolve_model() == "sonnet"

    def test_agent_mode_economy(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- agent_mode: economy\n"
        )
        agent = make_agent(project_dir)
        assert agent._resolve_model() == "haiku"

    def test_explicit_model_customization(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- agent_mode: premium\n\n"
            "## Model customization\n"
            "- models:\n"
            "    planning: opus\n"
            "    review: sonnet\n"
            "    search: haiku\n"
        )
        agent = make_agent(project_dir)
        assert agent._resolve_model() == "sonnet"

    def test_commented_out_model_customization_ignored(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- agent_mode: balanced\n\n"
            "## Model customization (optional)\n"
            "<!-- Override default models for any task type -->\n"
            "<!-- - models: -->\n"
            "<!--     planning: opus -->\n"
            "<!--     review: opus -->\n"
            "<!--     search: sonnet -->\n"
        )
        agent = make_agent(project_dir)
        # Should fall through to agent_mode: balanced → sonnet
        assert agent._resolve_model() == "sonnet"

    def test_no_stack_md(self, project_dir):
        (project_dir / "STACK.md").unlink()
        agent = make_agent(project_dir)
        assert agent._resolve_model() is None

    def test_model_customization_overrides_agent_mode(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- agent_mode: economy\n\n"
            "## Model customization\n"
            "- models:\n"
            "    review: opus\n"
        )
        agent = make_agent(project_dir)
        # Explicit model customization takes priority over agent_mode
        assert agent._resolve_model() == "opus"


# ---------------------------------------------------------------------------
# TestAssembleContext
# ---------------------------------------------------------------------------

class TestAssembleContext:
    def test_review_spec_includes_features_and_acs(self, project_dir):
        agent = make_agent(project_dir)
        ctx = agent._assemble_context("F-0042", "planned", "specced", "review_spec")
        assert "F-0042" in ctx
        assert "Test Feature" in ctx
        assert "AC-001" in ctx

    def test_review_code_includes_diff(self, project_dir):
        agent = make_agent(project_dir)
        with patch.object(agent, "_get_git_diff", return_value="+ new line"):
            ctx = agent._assemble_context(
                "F-0042", "documented", "committed", "review_code",
            )
        assert "+ new line" in ctx
        assert "Code Changes" in ctx

    def test_review_code_no_diff(self, project_dir):
        agent = make_agent(project_dir)
        with patch.object(agent, "_get_git_diff", return_value=""):
            ctx = agent._assemble_context(
                "F-0042", "documented", "committed", "review_code",
            )
        assert "No changes detected" in ctx

    def test_review_plan_includes_plan_file(self, project_dir):
        plan_dir = project_dir / ".agentic" / "journal" / "plans"
        plan_dir.mkdir(parents=True, exist_ok=True)
        (plan_dir / "F-0042-plan.md").write_text("# Plan\nDo the thing.\n")

        agent = make_agent(project_dir)
        ctx = agent._assemble_context(
            "F-0042", "tests_written", "implementing", "review_plan",
        )
        assert "Do the thing" in ctx
        assert "Implementation Plan" in ctx

    def test_nfrs_included_when_present(self, project_dir):
        nfr_dir = project_dir / ".agentic" / "spec"
        nfr_dir.mkdir(parents=True, exist_ok=True)
        (nfr_dir / "NFR.md").write_text("# NFRs\n- NFR-001: Response time < 200ms\n")

        agent = make_agent(project_dir)
        ctx = agent._assemble_context("F-0042", "planned", "specced", "review_spec")
        assert "Response time" in ctx
        assert "Non-Functional" in ctx

    def test_missing_feature_handled(self, project_dir):
        agent = make_agent(project_dir)
        ctx = agent._assemble_context("F-9999", "planned", "specced", "review_spec")
        assert "F-9999" in ctx
        # Should not crash, just missing feature section

    def test_extract_feature_section(self, project_dir):
        agent = make_agent(project_dir)
        content = (project_dir / ".agentic" / "spec" / "FEATURES.md").read_text()
        section = agent._extract_feature_section(content, "F-0042")
        assert "Test Feature" in section
        assert "F-0043" not in section


# ---------------------------------------------------------------------------
# TestGetGitDiff
# ---------------------------------------------------------------------------

class TestGetGitDiff:
    def test_truncation(self, project_dir):
        agent = make_agent(project_dir)
        long_diff = "\n".join([f"+ line {i}" for i in range(_DIFF_MAX_LINES + 500)])
        truncated = agent._truncate_diff(long_diff)
        lines = truncated.splitlines()
        # Should have _DIFF_MAX_LINES content lines + 1 blank + 1 truncation note
        assert "[diff truncated," in truncated
        assert str(_DIFF_MAX_LINES + 500) in truncated

    def test_short_diff_not_truncated(self, project_dir):
        agent = make_agent(project_dir)
        short_diff = "+ line 1\n+ line 2\n"
        result = agent._truncate_diff(short_diff)
        assert result == short_diff
        assert "truncated" not in result


# ---------------------------------------------------------------------------
# TestBuildPrompt
# ---------------------------------------------------------------------------

class TestBuildPrompt:
    def test_prompt_contains_context(self, project_dir):
        agent = make_agent(project_dir)
        prompt = agent._build_prompt("my context here", "review_code")
        assert "my context here" in prompt
        assert "CRITICAL REVIEWER" in prompt

    def test_prompt_contains_focus(self, project_dir):
        agent = make_agent(project_dir)
        prompt = agent._build_prompt("ctx", "review_code")
        assert "security" in prompt.lower()
        assert "correctness" in prompt.lower()

    def test_prompt_contains_verdict_schema(self, project_dir):
        agent = make_agent(project_dir)
        prompt = agent._build_prompt("ctx", "review_spec")
        assert "approved" in prompt
        assert "request_changes" in prompt
        assert "escalate" in prompt

    def test_fallback_prompt_when_template_missing(self, project_dir):
        # Remove the template
        template_path = (
            project_dir / ".agentic" / "lib" / "auto" / "prompts" / "critical_review.md"
        )
        if template_path.exists():
            template_path.unlink()

        agent = make_agent(project_dir)
        prompt = agent._build_prompt("ctx", "review_code")
        assert "CRITICAL REVIEWER" in prompt
        assert "ctx" in prompt


# ---------------------------------------------------------------------------
# TestErrorHandling
# ---------------------------------------------------------------------------

class TestErrorHandling:
    def test_is_error(self, project_dir):
        agent = make_agent(project_dir)
        assert agent._is_error("error: Claude timed out after 300s")
        assert agent._is_error("error: claude command not found")
        assert agent._is_error("error: something went wrong")
        assert not agent._is_error("Some normal output")
        assert not agent._is_error("")

    def test_classify_timeout(self, project_dir):
        agent = make_agent(project_dir)
        assert agent._classify_error("error: Claude timed out after 300s") == "timeout"

    def test_classify_unavailable(self, project_dir):
        agent = make_agent(project_dir)
        assert agent._classify_error("error: claude command not found") == "unavailable"

    def test_classify_transient(self, project_dir):
        agent = make_agent(project_dir)
        assert agent._classify_error("error: connection reset") == "transient"

    @patch("auto.critical_agent.spawn_claude")
    def test_timeout_raises_immediately(self, mock_spawn, project_dir):
        mock_spawn.return_value = "error: Claude timed out after 600s"
        agent = make_agent(project_dir)
        with pytest.raises(RuntimeError, match="timeout"):
            agent.review("F-0042", "planned", "specced", "review_spec")
        # Should NOT retry — only one call
        assert mock_spawn.call_count == 1

    @patch("auto.critical_agent.spawn_claude")
    def test_unavailable_raises_immediately(self, mock_spawn, project_dir):
        mock_spawn.return_value = "error: claude command not found"
        agent = make_agent(project_dir)
        with pytest.raises(RuntimeError, match="unavailable"):
            agent.review("F-0042", "planned", "specced", "review_spec")
        assert mock_spawn.call_count == 1

    @patch("auto.critical_agent.time.sleep")
    @patch("auto.critical_agent.spawn_claude")
    def test_transient_error_retries_once(self, mock_spawn, mock_sleep, project_dir):
        # First call: error. Second call: success.
        mock_spawn.side_effect = [
            "error: connection reset",
            f"```json\n{APPROVED_JSON}\n```",
        ]
        agent = make_agent(project_dir)
        verdict = agent.review("F-0042", "planned", "specced", "review_spec")
        assert verdict.verdict == "approved"
        assert mock_spawn.call_count == 2
        mock_sleep.assert_called_once_with(5)

    @patch("auto.critical_agent.time.sleep")
    @patch("auto.critical_agent.spawn_claude")
    def test_transient_error_retry_fails(self, mock_spawn, mock_sleep, project_dir):
        # Both calls: error
        mock_spawn.side_effect = [
            "error: connection reset",
            "error: connection reset again",
        ]
        agent = make_agent(project_dir)
        with pytest.raises(RuntimeError, match="failed after retry"):
            agent.review("F-0042", "planned", "specced", "review_spec")
        assert mock_spawn.call_count == 2


# ---------------------------------------------------------------------------
# TestReviewEndToEnd
# ---------------------------------------------------------------------------

class TestReviewEndToEnd:
    @patch("auto.critical_agent.spawn_claude")
    def test_approved_verdict(self, mock_spawn, project_dir):
        mock_spawn.return_value = f"```json\n{APPROVED_JSON}\n```"
        agent = make_agent(project_dir)
        verdict = agent.review("F-0042", "planned", "specced", "review_spec")
        assert verdict.verdict == "approved"
        assert verdict.confidence == "high"

    @patch("auto.critical_agent.spawn_claude")
    def test_request_changes_verdict(self, mock_spawn, project_dir):
        mock_spawn.return_value = f"```json\n{REQUEST_CHANGES_JSON}\n```"
        agent = make_agent(project_dir)
        verdict = agent.review("F-0042", "planned", "specced", "review_spec")
        assert verdict.verdict == "request_changes"
        assert len(verdict.issues) == 2

    @patch("auto.critical_agent.spawn_claude")
    def test_escalate_verdict(self, mock_spawn, project_dir):
        mock_spawn.return_value = f"```json\n{ESCALATE_JSON}\n```"
        agent = make_agent(project_dir)
        verdict = agent.review("F-0042", "planned", "specced", "review_spec")
        assert verdict.verdict == "escalate"

    @patch("auto.critical_agent.spawn_claude")
    def test_spawn_called_with_print_mode(self, mock_spawn, project_dir):
        """AC-002: Read-only — verify print_mode=True."""
        mock_spawn.return_value = f"```json\n{APPROVED_JSON}\n```"
        agent = make_agent(project_dir)
        agent.review("F-0042", "planned", "specced", "review_spec")
        _, kwargs = mock_spawn.call_args
        assert kwargs.get("print_mode") is True

    @patch("auto.critical_agent.spawn_claude")
    def test_spawn_called_with_timeout_600(self, mock_spawn, project_dir):
        mock_spawn.return_value = f"```json\n{APPROVED_JSON}\n```"
        agent = make_agent(project_dir)
        agent.review("F-0042", "planned", "specced", "review_spec")
        _, kwargs = mock_spawn.call_args
        assert kwargs.get("timeout") == 600

    @patch("auto.critical_agent.spawn_claude")
    def test_spawn_called_with_model(self, mock_spawn, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- agent_mode: balanced\n"
        )
        mock_spawn.return_value = f"```json\n{APPROVED_JSON}\n```"
        agent = make_agent(project_dir)
        agent.review("F-0042", "planned", "specced", "review_spec")
        _, kwargs = mock_spawn.call_args
        assert kwargs.get("model") == "sonnet"

    @patch("auto.critical_agent.spawn_claude")
    def test_parse_failure_escalates(self, mock_spawn, project_dir):
        mock_spawn.return_value = "I think it looks good but I'm not sure."
        agent = make_agent(project_dir)
        verdict = agent.review("F-0042", "planned", "specced", "review_spec")
        assert verdict.verdict == "escalate"
        assert "parse" in verdict.summary.lower()
