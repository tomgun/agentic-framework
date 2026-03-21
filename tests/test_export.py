#!/usr/bin/env python3
"""
Tests for the v2 export system (ag export).

Covers:
- Section generation (content correctness)
- Tool adapter configuration
- ExportGenerator: generate, diff, write, MCP config
- Safe regeneration (marker detection, backup)
- Project settings injection
- CLI command dispatch
"""
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))

from auto.v2.config import _CONFIG_CACHE
from auto.v2.export_sections import (
    SECTIONS,
    ProjectSettings,
    preamble,
    session_start,
    workflow_commands,
    artifacts,
    trigger_words,
    plan_mode_exit,
    core_rules,
    token_scripts,
    sandbox_note,
    conventions_ref,
    project_settings,
)
from auto.v2.export_adapters import (
    ADAPTERS,
    ToolAdapter,
    get_adapter,
    list_adapters,
)
from auto.v2.export import (
    ExportGenerator,
    _make_marker,
    _has_marker,
    cmd_export,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def tmp_project(tmp_path):
    """Create a temporary project with minimal v2 config."""
    agentic = tmp_path / ".agentic"
    agentic.mkdir()
    work_dir = agentic / "work"
    work_dir.mkdir()

    config_path = agentic / "state_machine_af.yaml"
    config_path.write_text("""\
version: 1
engine: v2

workflow:
  states:
    - idea
    - queued
    - planning
    - shipped

  transitions:
    - {from: idea, to: queued}
    - {from: queued, to: planning}

modes:
  formal:
    escape_hatches: false
    skip_transitions: []
    required_artifacts:
      planning: []

profiles:
  guided:
    description: "Default"
    gates:
      plan_approved: human

verification:
  commands:
    - {name: tests, run: "echo PASS", timeout: 10}

artifacts:
  plan.md:
    description: "Implementation plan"
    location: "{work_dir}/plan.md"
""")

    # STACK.md with settings
    stack = tmp_path / "STACK.md"
    stack.write_text("""\
# STACK.md

## Settings
- profile: guided
- plan_review_enabled: yes
""")

    _CONFIG_CACHE.clear()
    yield tmp_path
    _CONFIG_CACHE.clear()


# ---------------------------------------------------------------------------
# Section tests
# ---------------------------------------------------------------------------


class TestSections:
    """Test individual section content generation."""

    def test_preamble_mentions_framework(self):
        text = preamble()
        assert "agentic development framework" in text
        assert ".agentic/" in text

    def test_session_start_has_dashboard(self):
        text = session_start()
        assert "dashboard.sh" in text
        assert "ONE tool call" in text

    def test_workflow_commands_lists_ag(self):
        text = workflow_commands()
        assert "ag start" in text
        assert "ag transition" in text
        assert "ag export" in text

    def test_artifacts_mentions_work_dir(self):
        text = artifacts()
        assert ".agentic/work/F-XXXX/" in text
        assert "plan.md" in text

    def test_trigger_words_has_table(self):
        text = trigger_words()
        assert "| User intent" in text
        assert "STOP" in text
        assert "ag commit" in text

    def test_plan_mode_exit_has_protocol(self):
        text = plan_mode_exit()
        assert "DRAFT" in text
        assert "Critic + Advocate" in text

    def test_core_rules_has_essentials(self):
        text = core_rules()
        assert "Never auto-commit" in text
        assert "PR by default" in text

    def test_token_scripts_has_all(self):
        text = token_scripts()
        assert "status.sh" in text
        assert "journal.sh" in text
        assert "blocker.sh" in text
        assert "todo.sh" in text

    def test_sandbox_note_mentions_codex(self):
        text = sandbox_note()
        assert "Codex" in text
        assert "|| true" in text

    def test_conventions_ref(self):
        text = conventions_ref()
        assert "conventions.md" in text

    def test_project_settings_renders(self):
        settings = ProjectSettings(
            profile="autonomous",
            mode="formal",
            plan_review_enabled=True,
            verification_commands=["make test", "make lint"],
        )
        text = project_settings(settings)
        assert "autonomous" in text
        assert "formal" in text
        assert "enabled" in text
        assert "make test" in text

    def test_section_registry_complete(self):
        expected = {
            "preamble", "session_start", "workflow_commands",
            "artifacts", "trigger_words", "plan_mode_exit",
            "core_rules", "token_scripts", "sandbox_note",
            "conventions_ref", "project_settings",
        }
        assert set(SECTIONS.keys()) == expected


# ---------------------------------------------------------------------------
# Adapter tests
# ---------------------------------------------------------------------------


class TestAdapters:
    """Test tool adapter configuration."""

    def test_four_adapters_exist(self):
        assert set(ADAPTERS.keys()) == {"claude", "cursor", "copilot", "codex"}

    def test_list_adapters_sorted(self):
        names = list_adapters()
        assert names == sorted(names)

    def test_get_adapter_returns_correct(self):
        adapter = get_adapter("claude")
        assert adapter is not None
        assert adapter.output_path == "CLAUDE.md"

    def test_get_adapter_unknown_returns_none(self):
        assert get_adapter("unknown") is None

    def test_claude_has_session_start(self):
        adapter = get_adapter("claude")
        assert "session_start" in adapter.sections

    def test_cursor_has_trigger_words(self):
        adapter = get_adapter("cursor")
        assert "trigger_words" in adapter.sections
        assert "session_start" not in adapter.sections

    def test_codex_has_sandbox_note(self):
        adapter = get_adapter("codex")
        assert "sandbox_note" in adapter.sections

    def test_claude_has_mcp_config(self):
        adapter = get_adapter("claude")
        assert adapter.mcp_config_path == ".claude/mcp.json"

    def test_copilot_no_mcp_config(self):
        adapter = get_adapter("copilot")
        assert adapter.mcp_config_path is None


# ---------------------------------------------------------------------------
# Marker tests
# ---------------------------------------------------------------------------


class TestMarkers:
    """Test regeneration markers."""

    def test_make_marker_html(self):
        marker = _make_marker("claude", "html")
        assert marker == "<!-- ag-export: claude v1 -->"

    def test_make_marker_hash(self):
        marker = _make_marker("cursor", "hash")
        assert marker == "# ag-export: cursor v1"

    def test_has_marker_present(self, tmp_path):
        f = tmp_path / "test.md"
        f.write_text("<!-- ag-export: claude v1 -->\n# Content\n")
        assert _has_marker(f, "claude") is True

    def test_has_marker_absent(self, tmp_path):
        f = tmp_path / "test.md"
        f.write_text("# Regular file\n")
        assert _has_marker(f, "claude") is False

    def test_has_marker_nonexistent(self, tmp_path):
        f = tmp_path / "nope.md"
        assert _has_marker(f, "claude") is False


# ---------------------------------------------------------------------------
# Generator tests
# ---------------------------------------------------------------------------


class TestExportGenerator:
    """Test the full export generator."""

    def test_generate_claude(self, tmp_project):
        gen = ExportGenerator(tmp_project)
        content = gen.generate("claude")
        assert "ag-export: claude v1" in content
        assert "Project Instructions" in content
        assert "dashboard.sh" in content
        assert "ag start" in content

    def test_generate_cursor(self, tmp_project):
        gen = ExportGenerator(tmp_project)
        content = gen.generate("cursor")
        assert "ag-export: cursor v1" in content
        assert "Trigger Words" in content
        assert "dashboard.sh" not in content

    def test_generate_codex(self, tmp_project):
        gen = ExportGenerator(tmp_project)
        content = gen.generate("codex")
        assert "sandbox" in content.lower()

    def test_generate_copilot(self, tmp_project):
        gen = ExportGenerator(tmp_project)
        content = gen.generate("copilot")
        assert "Copilot Instructions" in content

    def test_generate_unknown_raises(self, tmp_project):
        gen = ExportGenerator(tmp_project)
        with pytest.raises(ValueError, match="Unknown tool"):
            gen.generate("unknown")

    def test_generate_includes_project_settings(self, tmp_project):
        gen = ExportGenerator(tmp_project)
        content = gen.generate("claude")
        assert "guided" in content
        assert "Plan review" in content

    def test_generate_idempotent(self, tmp_project):
        gen = ExportGenerator(tmp_project)
        first = gen.generate("claude")
        second = gen.generate("claude")
        assert first == second

    def test_diff_new_file(self, tmp_project):
        gen = ExportGenerator(tmp_project)
        # No CLAUDE.md exists yet at this path — but the real project has one
        # In our tmp_project there's no CLAUDE.md
        diff = gen.generate_diff("claude")
        assert "[NEW]" in diff

    def test_diff_no_change(self, tmp_project):
        gen = ExportGenerator(tmp_project)
        # Write the file first
        gen.write("claude")
        diff = gen.generate_diff("claude")
        assert diff is None

    def test_diff_with_change(self, tmp_project):
        gen = ExportGenerator(tmp_project)
        target = tmp_project / "CLAUDE.md"
        target.write_text("<!-- ag-export: claude v1 -->\nOld content\n")
        diff = gen.generate_diff("claude")
        assert "[CHANGED]" in diff

    def test_write_creates_file(self, tmp_project):
        gen = ExportGenerator(tmp_project)
        path, backed_up = gen.write("claude")
        assert path == "CLAUDE.md"
        assert backed_up is False
        assert (tmp_project / "CLAUDE.md").exists()

    def test_write_backs_up_unmarked(self, tmp_project):
        gen = ExportGenerator(tmp_project)
        target = tmp_project / "CLAUDE.md"
        target.write_text("# Old custom CLAUDE.md\n")
        path, backed_up = gen.write("claude")
        assert backed_up is True
        assert (tmp_project / "CLAUDE.md.bak").exists()
        assert (tmp_project / "CLAUDE.md.bak").read_text() == "# Old custom CLAUDE.md\n"

    def test_write_overwrites_marked(self, tmp_project):
        gen = ExportGenerator(tmp_project)
        target = tmp_project / "CLAUDE.md"
        target.write_text("<!-- ag-export: claude v1 -->\nOld export\n")
        path, backed_up = gen.write("claude")
        assert backed_up is False
        assert "ag-export: claude v1" in target.read_text()

    def test_write_creates_parent_dirs(self, tmp_project):
        gen = ExportGenerator(tmp_project)
        path, _ = gen.write("copilot")
        assert path == ".github/copilot-instructions.md"
        assert (tmp_project / ".github" / "copilot-instructions.md").exists()

    def test_write_mcp_config(self, tmp_project):
        gen = ExportGenerator(tmp_project)
        mcp_path = gen.write_mcp_config("claude")
        assert mcp_path == ".claude/mcp.json"
        config = json.loads((tmp_project / ".claude" / "mcp.json").read_text())
        assert "mcpServers" in config
        assert "agentic" in config["mcpServers"]

    def test_write_mcp_config_unsupported(self, tmp_project):
        gen = ExportGenerator(tmp_project)
        result = gen.write_mcp_config("copilot")
        assert result is None


# ---------------------------------------------------------------------------
# CLI tests
# ---------------------------------------------------------------------------


class TestCLI:
    """Test the cmd_export CLI handler."""

    def test_no_args_shows_usage(self, tmp_project, capsys):
        rc = cmd_export(tmp_project, [])
        assert rc == 0
        out = capsys.readouterr().out
        assert "Usage" in out

    def test_list(self, tmp_project, capsys):
        rc = cmd_export(tmp_project, ["--list"])
        assert rc == 0
        out = capsys.readouterr().out
        assert "claude" in out
        assert "cursor" in out

    def test_export_single(self, tmp_project, capsys):
        rc = cmd_export(tmp_project, ["claude"])
        assert rc == 0
        assert (tmp_project / "CLAUDE.md").exists()

    def test_export_all(self, tmp_project, capsys):
        rc = cmd_export(tmp_project, ["all"])
        assert rc == 0
        assert (tmp_project / "CLAUDE.md").exists()
        assert (tmp_project / ".cursorrules").exists()
        assert (tmp_project / "AGENTS.md").exists()
        assert (tmp_project / ".github" / "copilot-instructions.md").exists()

    def test_diff_mode(self, tmp_project, capsys):
        rc = cmd_export(tmp_project, ["--diff", "claude"])
        assert rc == 0
        out = capsys.readouterr().out
        assert "[NEW]" in out

    def test_unknown_tool(self, tmp_project, capsys):
        rc = cmd_export(tmp_project, ["unknown"])
        assert rc == 1

    def test_export_with_mcp(self, tmp_project, capsys):
        rc = cmd_export(tmp_project, ["claude", "--mcp"])
        assert rc == 0
        assert (tmp_project / ".claude" / "mcp.json").exists()
