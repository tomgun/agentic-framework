#!/usr/bin/env python3
"""
Tests for the debugging-framework skill (F-025 AC-006, AC-007, AC-008).

Verifies the skill has the required investigation methodology, covers all
evidence sources, and provides structured root cause categorization.
"""
from pathlib import Path

import pytest

SKILL_PATH = Path(__file__).parent.parent / ".claude" / "skills" / "debugging-framework" / "SKILL.md"


@pytest.fixture
def skill_content():
    """Read the debugging-framework SKILL.md content."""
    assert SKILL_PATH.exists(), f"Skill file not found: {SKILL_PATH}"
    return SKILL_PATH.read_text()


class TestDebuggingSkillStructure:
    """AC-006: Skill exists with investigation methodology."""

    def test_skill_file_exists(self):
        assert SKILL_PATH.exists()

    def test_has_frontmatter(self, skill_content):
        assert skill_content.startswith("---")
        assert "name: debugging-framework" in skill_content

    def test_has_five_steps(self, skill_content):
        assert "Step 1" in skill_content
        assert "Step 2" in skill_content
        assert "Step 3" in skill_content
        assert "Step 4" in skill_content
        assert "Step 5" in skill_content

    def test_step1_expected_behavior(self, skill_content):
        assert "what should have happened" in skill_content.lower()

    def test_step2_trace_actual_events(self, skill_content):
        assert "Session logs" in skill_content
        assert "Hook configuration" in skill_content
        assert "State files" in skill_content

    def test_step3_build_timeline(self, skill_content):
        assert "Build the event timeline" in skill_content
        assert "evidence" in skill_content.lower()

    def test_step4_root_causes(self, skill_content):
        assert "root cause" in skill_content.lower()

    def test_step5_report(self, skill_content):
        assert "Report" in skill_content
        assert "structural" in skill_content.lower()


class TestDebuggingSkillContent:
    """AC-007: Covers all evidence sources."""

    def test_covers_session_logs(self, skill_content):
        """Skill instructs checking .jsonl session logs."""
        assert ".jsonl" in skill_content

    def test_covers_hook_settings(self, skill_content):
        """Skill instructs checking settings.json for hook registration."""
        assert "settings.json" in skill_content
        assert "hooks" in skill_content.lower()

    def test_covers_agent_tracking(self, skill_content):
        """Skill instructs checking AGENTS.json for WIP state."""
        assert "AGENTS.json" in skill_content

    def test_covers_plan_files(self, skill_content):
        """Skill instructs checking both ephemeral and durable plan locations."""
        assert "journal/plans" in skill_content
        assert ".claude/plans" in skill_content

    def test_covers_all_evidence_sources(self, skill_content):
        """AC-007: All four evidence sources present."""
        sources = [".jsonl", "settings.json", "AGENTS.json", "journal/plans"]
        for source in sources:
            assert source in skill_content, f"Missing evidence source: {source}"

    def test_distinguishes_script_exists_vs_hook_wired(self, skill_content):
        """Key insight from the incident that spawned this skill."""
        assert "scripts existing" in skill_content.lower() or "script exists" in skill_content.lower()
        assert "not registered" in skill_content.lower() or "not wired" in skill_content.lower()


class TestDebuggingSkillRootCauses:
    """AC-008: Root cause categorization."""

    def test_root_cause_categories(self, skill_content):
        """All five root cause categories present."""
        categories = [
            "Not wired",
            "Not triggered",
            "Advisory only",
            "Agent ignored",
            "Missing enforcement",
        ]
        for cat in categories:
            assert cat in skill_content, f"Missing root cause category: {cat}"

    def test_structural_vs_behavioral_distinction(self, skill_content):
        """Skill distinguishes structural fixes from behavioral ones."""
        assert "structural" in skill_content.lower()
        assert "behavioral" in skill_content.lower()
