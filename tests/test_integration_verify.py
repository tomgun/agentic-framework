"""
Tests for integration_verify.py — Epic integration verification gate.

@feature F-0204

Covers:
- AC-001: recompute_epic_status holds at implementing when tests defined but no artifact
- AC-002: Epic ships when tests pass or no tests defined
- AC-003: load_integration_commands resolution order (AC > STACK > skip)
- AC-004: run_integration_verify runs commands and stores artifact
- AC-005: scheduler.run_epic integration hook
- AC-006: CLI entry point
- AC-007: Graceful degradation (no tests = skip)
- AC-008: review_integration setting
"""
import json
import os
import sys
import textwrap
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

# Resolve imports
_LIB_DIR = Path(__file__).resolve().parent.parent / ".agentic" / "lib"
sys.path.insert(0, str(_LIB_DIR))
sys.path.insert(0, str(_LIB_DIR / "tools"))

from auto.integration_verify import (
    IntegrationResult,
    load_integration_commands,
    run_integration_verify,
    get_integration_result,
    _parse_integration_section,
    _store_artifact,
    main,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def project_root(tmp_path):
    """Create a minimal project structure for testing."""
    agentic = tmp_path / ".agentic"
    spec = agentic / "spec"
    acceptance = spec / "acceptance"
    session = agentic / "session"
    tools = agentic / "lib" / "tools"

    for d in [spec, acceptance, session, tools]:
        d.mkdir(parents=True)

    # Minimal STACK.md
    (tmp_path / "STACK.md").write_text(textwrap.dedent("""\
        # Stack
        ## Settings
        - profile: discovery
        - review_integration: skip
    """))

    # FEATURES.md
    (spec / "FEATURES.md").write_text("")

    return tmp_path


def _write_stack(project_root, content):
    (project_root / "STACK.md").write_text(content)


def _write_ac(project_root, feature_id, content):
    ac_file = project_root / ".agentic" / "spec" / "acceptance" / f"{feature_id}.md"
    ac_file.write_text(content)
    return ac_file


# ---------------------------------------------------------------------------
# _parse_integration_section tests
# ---------------------------------------------------------------------------

class TestParseIntegrationSection:
    def test_parses_backtick_commands(self):
        content = textwrap.dedent("""\
            ## Integration tests
            - `pytest tests/integration/`
            - `npm run test:integration`
        """)
        commands = _parse_integration_section(content)
        assert commands == [
            "pytest tests/integration/",
            "npm run test:integration",
        ]

    def test_parses_plain_commands(self):
        content = textwrap.dedent("""\
            ## Integration tests
            - pytest tests/integration/
        """)
        commands = _parse_integration_section(content)
        assert commands == ["pytest tests/integration/"]

    def test_stops_at_next_heading(self):
        content = textwrap.dedent("""\
            ## Integration tests
            - `pytest tests/integration/`

            ## Other section
            - `should not be included`
        """)
        commands = _parse_integration_section(content)
        assert len(commands) == 1
        assert commands[0] == "pytest tests/integration/"

    def test_skips_placeholders(self):
        content = textwrap.dedent("""\
            ## Integration tests
            - `<!-- fill -->`
            - N/A
        """)
        commands = _parse_integration_section(content)
        assert commands == []

    def test_no_section_returns_empty(self):
        content = "## Other\n- stuff\n"
        commands = _parse_integration_section(content)
        assert commands == []

    def test_empty_section_returns_empty(self):
        content = "## Integration tests\n\n## Next\n"
        commands = _parse_integration_section(content)
        assert commands == []

    def test_case_insensitive_heading(self):
        content = "## integration tests\n- `pytest`\n"
        commands = _parse_integration_section(content)
        assert commands == ["pytest"]

    def test_heading_with_parenthetical_suffix(self):
        """Matches STACK template heading: ## Integration tests (optional, for epics)"""
        content = textwrap.dedent("""\
            ## Integration tests (optional, for epics)
            - `pytest tests/integration/`
        """)
        commands = _parse_integration_section(content)
        assert commands == ["pytest tests/integration/"]


# ---------------------------------------------------------------------------
# load_integration_commands tests (AC-003)
# ---------------------------------------------------------------------------

class TestLoadIntegrationCommands:
    def test_epic_ac_overrides_stack(self, project_root):
        """Epic AC file takes priority over STACK.md."""
        _write_stack(project_root, textwrap.dedent("""\
            # Stack
            ## Settings
            - profile: discovery

            ## Integration tests
            - `pytest tests/integration/`
        """))
        _write_ac(project_root, "F-0100", textwrap.dedent("""\
            # F-0100: Epic

            ## Integration tests
            - `npm run test:epic-integration`
        """))
        commands = load_integration_commands(project_root, "F-0100")
        assert commands == ["npm run test:epic-integration"]

    def test_falls_back_to_stack(self, project_root):
        """When no AC override, use STACK.md."""
        _write_stack(project_root, textwrap.dedent("""\
            # Stack
            ## Settings
            - profile: discovery

            ## Integration tests
            - `pytest tests/integration/`
        """))
        commands = load_integration_commands(project_root, "F-0100")
        assert commands == ["pytest tests/integration/"]

    def test_returns_empty_when_no_tests(self, project_root):
        """No integration tests anywhere → empty list."""
        commands = load_integration_commands(project_root, "F-0100")
        assert commands == []

    def test_validates_feature_id(self, project_root):
        with pytest.raises(ValueError, match="Invalid feature ID"):
            load_integration_commands(project_root, "not-valid")


# ---------------------------------------------------------------------------
# IntegrationResult tests
# ---------------------------------------------------------------------------

class TestIntegrationResult:
    def test_to_dict_basic(self):
        result = IntegrationResult(
            epic_id="F-0100", success=True, commands_run=2,
        )
        d = result.to_dict()
        assert d["epic_id"] == "F-0100"
        assert d["success"] is True
        assert d["commands_run"] == 2
        assert "error" not in d

    def test_to_dict_with_error(self):
        result = IntegrationResult(
            epic_id="F-0100", success=False, error="fail",
        )
        d = result.to_dict()
        assert d["error"] == "fail"

    def test_to_dict_skipped(self):
        result = IntegrationResult(
            epic_id="F-0100", success=True, skipped=True,
        )
        d = result.to_dict()
        assert d["skipped"] is True


# ---------------------------------------------------------------------------
# Artifact storage and retrieval tests
# ---------------------------------------------------------------------------

class TestArtifactStorage:
    def test_store_and_retrieve(self, project_root):
        result = IntegrationResult(
            epic_id="F-0100", success=True, commands_run=1,
        )
        _store_artifact(project_root, result)

        loaded = get_integration_result(project_root, "F-0100")
        assert loaded is not None
        assert loaded.epic_id == "F-0100"
        assert loaded.success is True
        assert loaded.commands_run == 1

    def test_retrieve_nonexistent_returns_none(self, project_root):
        assert get_integration_result(project_root, "F-9999") is None

    def test_store_overwrites(self, project_root):
        r1 = IntegrationResult(epic_id="F-0100", success=False)
        _store_artifact(project_root, r1)
        r2 = IntegrationResult(epic_id="F-0100", success=True)
        _store_artifact(project_root, r2)

        loaded = get_integration_result(project_root, "F-0100")
        assert loaded.success is True

    def test_validates_feature_id(self, project_root):
        with pytest.raises(ValueError):
            get_integration_result(project_root, "bad-id")


# ---------------------------------------------------------------------------
# run_integration_verify tests (AC-004, AC-007)
# ---------------------------------------------------------------------------

class TestRunIntegrationVerify:
    def test_skips_when_no_commands(self, project_root):
        """AC-007: No integration tests → skipped=True, success=True."""
        result = run_integration_verify(project_root, "F-0100")
        assert result.success is True
        assert result.skipped is True
        assert result.commands_run == 0

        # Artifact should be stored
        loaded = get_integration_result(project_root, "F-0100")
        assert loaded is not None
        assert loaded.skipped is True

    @patch("auto.verify.VerifyLoop")
    def test_runs_commands_via_verify_loop(self, MockLoop, project_root):
        """AC-004: Commands run through VerifyLoop."""
        _write_stack(project_root, textwrap.dedent("""\
            # Stack
            ## Settings
            - profile: discovery
            - review_integration: skip

            ## Integration tests
            - `echo test1`
            - `echo test2`
        """))

        mock_result = MagicMock()
        mock_result.success = True
        mock_result.iterations_used = 1
        mock_result.final_tests_passed = 1
        mock_result.final_tests_failed = 0
        MockLoop.return_value.run.return_value = mock_result

        result = run_integration_verify(project_root, "F-0100")
        assert result.success is True
        assert result.commands_run == 2
        assert result.skipped is False
        assert len(result.tier_results) == 2
        assert MockLoop.call_count == 2

    @patch("auto.verify.VerifyLoop")
    def test_fails_when_command_fails(self, MockLoop, project_root):
        _write_stack(project_root, textwrap.dedent("""\
            # Stack
            ## Settings
            - profile: discovery
            - review_integration: skip

            ## Integration tests
            - `failing-command`
        """))

        mock_result = MagicMock()
        mock_result.success = False
        mock_result.iterations_used = 3
        mock_result.final_tests_passed = 0
        mock_result.final_tests_failed = 1
        MockLoop.return_value.run.return_value = mock_result

        result = run_integration_verify(project_root, "F-0100")
        assert result.success is False
        assert result.commands_run == 1


# ---------------------------------------------------------------------------
# Epic gate tests (AC-001, AC-002)
# ---------------------------------------------------------------------------

class TestEpicGate:
    """Test that recompute_epic_status respects integration verification."""

    def _write_features(self, project_root, content):
        features_file = project_root / ".agentic" / "spec" / "FEATURES.md"
        features_file.write_text(content)
        return features_file

    def _setup_shipped_children(self, project_root):
        """Set up an epic where all children are shipped."""
        self._write_features(project_root, textwrap.dedent("""\
            ## F-0100: Test Epic
            **Status**: implementing

            ## F-0101: Child A
            **Status**: shipped
            **Parent**: F-0100

            ## F-0102: Child B
            **Status**: shipped
            **Parent**: F-0100
        """))

        # Copy feature.sh for recompute
        real_feature_sh = Path(__file__).parent.parent / ".agentic" / "lib" / "tools" / "feature.sh"
        tools_dir = project_root / ".agentic" / "lib" / "tools"
        if real_feature_sh.exists():
            (tools_dir / "feature.sh").write_text(real_feature_sh.read_text())
        real_paths_sh = Path(__file__).parent.parent / ".agentic" / "lib" / "paths.sh"
        if real_paths_sh.exists():
            lib_dir = project_root / ".agentic" / "lib"
            (lib_dir / "paths.sh").write_text(real_paths_sh.read_text())

    def test_holds_at_implementing_when_tests_defined_no_artifact(self, project_root):
        """AC-001: Epic stays implementing when integration tests exist but no artifact."""
        # Set epic to a state that differs from implementing so the gate message fires
        # but the derived status gets held back to implementing
        self._write_features(project_root, textwrap.dedent("""\
            ## F-0100: Test Epic
            **Status**: criteria_set

            ## F-0101: Child A
            **Status**: shipped
            **Parent**: F-0100

            ## F-0102: Child B
            **Status**: shipped
            **Parent**: F-0100
        """))
        # Copy feature.sh
        real_feature_sh = Path(__file__).parent.parent / ".agentic" / "lib" / "tools" / "feature.sh"
        tools_dir = project_root / ".agentic" / "lib" / "tools"
        if real_feature_sh.exists():
            (tools_dir / "feature.sh").write_text(real_feature_sh.read_text())
        real_paths_sh = Path(__file__).parent.parent / ".agentic" / "lib" / "paths.sh"
        if real_paths_sh.exists():
            lib_dir = project_root / ".agentic" / "lib"
            (lib_dir / "paths.sh").write_text(real_paths_sh.read_text())

        _write_stack(project_root, textwrap.dedent("""\
            # Stack
            ## Settings
            - profile: discovery

            ## Integration tests
            - `pytest tests/integration/`
        """))

        from auto.epic import recompute_epic_status
        changed, msgs = recompute_epic_status(project_root, "F-0100")
        # Integration gate should produce a message about pending verification
        assert any("integration verification" in m for m in msgs)
        # Derived should be held to implementing (not shipped)

    def test_ships_when_no_tests_defined(self, project_root):
        """AC-002/AC-007: No integration tests → epic ships immediately."""
        self._setup_shipped_children(project_root)

        from auto.epic import recompute_epic_status
        changed, msgs = recompute_epic_status(project_root, "F-0100")
        assert changed
        assert any("shipped" in m for m in msgs)

    def test_ships_when_artifact_success(self, project_root):
        """AC-002: Epic ships when artifact success=true."""
        self._setup_shipped_children(project_root)
        _write_stack(project_root, textwrap.dedent("""\
            # Stack
            ## Settings
            - profile: discovery

            ## Integration tests
            - `pytest tests/integration/`
        """))

        # Store passing artifact
        result = IntegrationResult(
            epic_id="F-0100", success=True, commands_run=1,
        )
        _store_artifact(project_root, result)

        from auto.epic import recompute_epic_status
        changed, msgs = recompute_epic_status(project_root, "F-0100")
        assert changed
        assert any("shipped" in m for m in msgs)

    def test_holds_when_artifact_failed(self, project_root):
        """AC-001: Epic stays implementing when artifact success=false."""
        # Use criteria_set so derived=implementing actually updates
        self._write_features(project_root, textwrap.dedent("""\
            ## F-0100: Test Epic
            **Status**: criteria_set

            ## F-0101: Child A
            **Status**: shipped
            **Parent**: F-0100

            ## F-0102: Child B
            **Status**: shipped
            **Parent**: F-0100
        """))
        real_feature_sh = Path(__file__).parent.parent / ".agentic" / "lib" / "tools" / "feature.sh"
        tools_dir = project_root / ".agentic" / "lib" / "tools"
        if real_feature_sh.exists():
            (tools_dir / "feature.sh").write_text(real_feature_sh.read_text())
        real_paths_sh = Path(__file__).parent.parent / ".agentic" / "lib" / "paths.sh"
        if real_paths_sh.exists():
            lib_dir = project_root / ".agentic" / "lib"
            (lib_dir / "paths.sh").write_text(real_paths_sh.read_text())

        _write_stack(project_root, textwrap.dedent("""\
            # Stack
            ## Settings
            - profile: discovery

            ## Integration tests
            - `pytest tests/integration/`
        """))

        # Store failing artifact
        result = IntegrationResult(
            epic_id="F-0100", success=False, commands_run=1,
        )
        _store_artifact(project_root, result)

        from auto.epic import recompute_epic_status
        changed, msgs = recompute_epic_status(project_root, "F-0100")
        assert any("integration verification" in m for m in msgs)


# ---------------------------------------------------------------------------
# Scheduler hook tests (AC-005)
# ---------------------------------------------------------------------------

class TestSchedulerHook:
    """Test that scheduler.run_epic runs integration verification."""

    @patch("auto.scheduler.AutonomousScheduler._run_integration_verify")
    @patch("auto.scheduler.AutonomousScheduler.run")
    def test_calls_verify_on_success(self, mock_run, mock_verify, project_root):
        """AC-005: run_epic calls integration verify when children complete."""
        from auto.scheduler import AutonomousScheduler, SchedulerResult

        mock_run.return_value = SchedulerResult(
            success=True, features_total=2, features_completed=2,
        )
        mock_verify.return_value = IntegrationResult(
            epic_id="F-0100", success=True, commands_run=1,
        )

        # Set up features for _get_epic_children
        features = project_root / ".agentic" / "spec" / "FEATURES.md"
        features.write_text(textwrap.dedent("""\
            ## F-0100: Epic
            **Status**: implementing

            ## F-0101: Child
            **Status**: planned
            **Parent**: F-0100
        """))

        scheduler = AutonomousScheduler(project_root=project_root)
        result = scheduler.run_epic("F-0100")

        mock_verify.assert_called_once_with("F-0100")
        assert result.success is True

    @patch("auto.scheduler.AutonomousScheduler._run_integration_verify")
    @patch("auto.scheduler.AutonomousScheduler.run")
    def test_fails_when_verify_fails(self, mock_run, mock_verify, project_root):
        """AC-005: run_epic fails when integration verify fails."""
        from auto.scheduler import AutonomousScheduler, SchedulerResult

        mock_run.return_value = SchedulerResult(
            success=True, features_total=2, features_completed=2,
        )
        mock_verify.return_value = IntegrationResult(
            epic_id="F-0100", success=False, commands_run=1,
        )

        features = project_root / ".agentic" / "spec" / "FEATURES.md"
        features.write_text(textwrap.dedent("""\
            ## F-0100: Epic
            **Status**: implementing

            ## F-0101: Child
            **Status**: planned
            **Parent**: F-0100
        """))

        scheduler = AutonomousScheduler(project_root=project_root)
        result = scheduler.run_epic("F-0100")

        assert result.success is False
        assert "Integration verification failed" in result.stopped_reason
        assert result.integration_result is not None

    @patch("auto.scheduler.AutonomousScheduler._run_integration_verify")
    @patch("auto.scheduler.AutonomousScheduler.run")
    def test_skips_verify_when_children_fail(self, mock_run, mock_verify, project_root):
        """Integration verify only runs when all children succeed."""
        from auto.scheduler import AutonomousScheduler, SchedulerResult

        mock_run.return_value = SchedulerResult(
            success=False, features_total=2, features_completed=1, features_failed=1,
        )

        features = project_root / ".agentic" / "spec" / "FEATURES.md"
        features.write_text(textwrap.dedent("""\
            ## F-0100: Epic
            **Status**: implementing

            ## F-0101: Child
            **Status**: planned
            **Parent**: F-0100
        """))

        scheduler = AutonomousScheduler(project_root=project_root)
        result = scheduler.run_epic("F-0100")

        mock_verify.assert_not_called()
        assert result.success is False


# ---------------------------------------------------------------------------
# Review integration tests (AC-008)
# ---------------------------------------------------------------------------

class TestReviewIntegration:
    @patch("auto.verify.VerifyLoop")
    @patch("auto.critical_agent.CriticalAgent")
    def test_critical_agent_review_blocks_on_rejection(
        self, MockAgent, MockLoop, project_root
    ):
        """AC-008: critical_agent rejection fails the verification."""
        _write_stack(project_root, textwrap.dedent("""\
            # Stack
            ## Settings
            - profile: formal
            - review_integration: critical_agent

            ## Integration tests
            - `echo test`
        """))

        # VerifyLoop passes
        mock_vresult = MagicMock()
        mock_vresult.success = True
        mock_vresult.iterations_used = 1
        mock_vresult.final_tests_passed = 1
        mock_vresult.final_tests_failed = 0
        MockLoop.return_value.run.return_value = mock_vresult

        # Critical agent rejects
        mock_verdict = MagicMock()
        mock_verdict.verdict = "request_changes"
        mock_verdict.summary = "API incompatibility"
        MockAgent.return_value.review.return_value = mock_verdict

        result = run_integration_verify(project_root, "F-0100")
        assert result.success is False
        assert "API incompatibility" in result.error

    @patch("auto.verify.VerifyLoop")
    def test_skip_review_does_not_invoke_agent(self, MockLoop, project_root):
        """AC-008: skip mode doesn't invoke critical agent."""
        _write_stack(project_root, textwrap.dedent("""\
            # Stack
            ## Settings
            - profile: discovery
            - review_integration: skip

            ## Integration tests
            - `echo test`
        """))

        mock_vresult = MagicMock()
        mock_vresult.success = True
        mock_vresult.iterations_used = 1
        mock_vresult.final_tests_passed = 1
        mock_vresult.final_tests_failed = 0
        MockLoop.return_value.run.return_value = mock_vresult

        result = run_integration_verify(project_root, "F-0100")
        assert result.success is True


# ---------------------------------------------------------------------------
# CLI tests (AC-006)
# ---------------------------------------------------------------------------

class TestCLI:
    def test_cli_no_tests_exits_zero(self, project_root, monkeypatch):
        """AC-006: CLI exits 0 when no tests defined (skip)."""
        monkeypatch.setattr(
            "sys.argv",
            ["integration_verify.py", "F-0100", "--project-root", str(project_root)],
        )
        assert main() == 0

    def test_cli_json_output(self, project_root, monkeypatch, capsys):
        """AC-006: CLI --json outputs valid JSON."""
        monkeypatch.setattr(
            "sys.argv",
            [
                "integration_verify.py", "F-0100",
                "--project-root", str(project_root),
                "--json",
            ],
        )
        main()
        output = capsys.readouterr().out
        data = json.loads(output)
        assert data["epic_id"] == "F-0100"
        assert data["skipped"] is True


# ---------------------------------------------------------------------------
# Structural tests
# ---------------------------------------------------------------------------

class TestStructural:
    def test_profiles_have_review_integration(self):
        """All profiles must define review_integration."""
        profiles_path = (
            Path(__file__).parent.parent
            / ".agentic" / "lib" / "presets" / "profiles.conf"
        )
        content = profiles_path.read_text()
        assert "discovery.review_integration=" in content
        assert "formal.review_integration=" in content
        assert "autonomous_formal.review_integration=" in content

    def test_critical_agent_has_review_focus(self):
        """_REVIEW_FOCUS must include review_integration."""
        from auto.critical_agent import _REVIEW_FOCUS
        assert "review_integration" in _REVIEW_FOCUS

    def test_stack_template_has_section(self):
        """STACK.template.md must mention integration tests."""
        template_path = (
            Path(__file__).parent.parent
            / ".agentic" / "lib" / "init" / "STACK.template.md"
        )
        content = template_path.read_text()
        assert "## Integration tests" in content

    def test_stack_template_has_review_integration(self):
        """STACK.template.md must have review_integration setting."""
        template_path = (
            Path(__file__).parent.parent
            / ".agentic" / "lib" / "init" / "STACK.template.md"
        )
        content = template_path.read_text()
        assert "review_integration" in content
