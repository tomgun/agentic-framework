"""Tests for framework_verify.py (F-0215)."""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import textwrap
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

# Ensure auto module is importable
import sys
_LIB_DIR = Path(__file__).resolve().parent.parent / ".agentic" / "lib"
sys.path.insert(0, str(_LIB_DIR))
sys.path.insert(0, str(_LIB_DIR / "tools"))


# ---------------------------------------------------------------------------
# SpawnResult tests
# ---------------------------------------------------------------------------

class TestSpawnResult:
    """Verify SpawnResult(str) subclass behavior."""

    def test_is_str(self):
        from auto import SpawnResult
        r = SpawnResult("hello", returncode=0)
        assert isinstance(r, str)

    def test_string_operations(self):
        from auto import SpawnResult
        r = SpawnResult("Hello World", returncode=0)
        assert r.upper() == "HELLO WORLD"
        assert r[:5] == "Hello"
        assert r.startswith("Hello")
        assert "World" in r
        assert len(r) == 11

    def test_returncode(self):
        from auto import SpawnResult
        r = SpawnResult("output", returncode=42)
        assert r.returncode == 42

    def test_timed_out_default(self):
        from auto import SpawnResult
        r = SpawnResult("output")
        assert r.timed_out is False
        assert r.returncode == 0

    def test_timed_out_true(self):
        from auto import SpawnResult
        r = SpawnResult("error: timed out", returncode=-1, timed_out=True)
        assert r.timed_out is True
        assert r.returncode == -1

    def test_str_concat(self):
        from auto import SpawnResult
        r = SpawnResult("hello", returncode=0)
        combined = r + " world"
        assert combined == "hello world"
        # Concatenation returns plain str, not SpawnResult
        assert isinstance(combined, str)

    def test_slice_returns_str(self):
        """Slicing a SpawnResult returns plain str (no .returncode)."""
        from auto import SpawnResult
        r = SpawnResult("hello", returncode=42)
        sliced = r[:3]
        assert sliced == "hel"
        assert not hasattr(sliced, "returncode") or type(sliced) is str


# ---------------------------------------------------------------------------
# Scenario loading tests
# ---------------------------------------------------------------------------

class TestScenarioLoading:
    """Test YAML scenario loading."""

    def test_load_todo_app(self):
        from auto.framework_verify import load_scenario
        s = load_scenario("todo_app")
        assert s["name"] == "Todo App"
        assert s["type"] == "single"
        assert s["timeout"] == 3600
        assert len(s["settings_matrix"]) == 2
        assert len(s["required_milestones"]) == 4

    def test_load_monorepo(self):
        from auto.framework_verify import load_scenario
        s = load_scenario("fullstack_monorepo")
        assert s["type"] == "monorepo"
        assert len(s["components"]) == 3
        assert s["timeout"] == 7200

    def test_load_multirepo(self):
        from auto.framework_verify import load_scenario
        s = load_scenario("fullstack_multirepo")
        assert s["type"] == "multirepo"
        assert len(s["components"]) == 2
        assert len(s["contracts"]) == 1

    def test_list_scenarios(self):
        from auto.framework_verify import list_scenarios
        scenarios = list_scenarios()
        assert "todo_app" in scenarios
        assert "fullstack_monorepo" in scenarios
        assert "fullstack_multirepo" in scenarios
        assert len(scenarios) >= 5

    def test_load_nonexistent(self):
        from auto.framework_verify import load_scenario
        with pytest.raises(FileNotFoundError):
            load_scenario("nonexistent_scenario")


# ---------------------------------------------------------------------------
# MilestoneChecker tests
# ---------------------------------------------------------------------------

class TestMilestoneChecker:
    """Test milestone detection logic."""

    def test_kickoff_complete_pass(self, tmp_path):
        from auto import SpawnResult
        from auto.framework_verify import MilestoneChecker
        spec_dir = tmp_path / ".agentic" / "spec"
        spec_dir.mkdir(parents=True)
        (spec_dir / "FEATURES.md").write_text("## F-0001: Test\n**Status**: planned\n")
        result = SpawnResult("ok", returncode=0)
        checker = MilestoneChecker(tmp_path, result)
        m = checker.check("kickoff_complete")
        assert m.passed

    def test_kickoff_complete_fail_no_file(self, tmp_path):
        from auto import SpawnResult
        from auto.framework_verify import MilestoneChecker
        result = SpawnResult("ok", returncode=0)
        checker = MilestoneChecker(tmp_path, result)
        m = checker.check("kickoff_complete")
        assert not m.passed

    def test_kickoff_complete_fail_no_features(self, tmp_path):
        from auto import SpawnResult
        from auto.framework_verify import MilestoneChecker
        spec_dir = tmp_path / ".agentic" / "spec"
        spec_dir.mkdir(parents=True)
        (spec_dir / "FEATURES.md").write_text("# Features\nNothing here\n")
        result = SpawnResult("ok", returncode=0)
        checker = MilestoneChecker(tmp_path, result)
        m = checker.check("kickoff_complete")
        assert not m.passed

    def test_features_specced_pass(self, tmp_path):
        from auto import SpawnResult
        from auto.framework_verify import MilestoneChecker
        ac_dir = tmp_path / ".agentic" / "spec" / "acceptance"
        ac_dir.mkdir(parents=True)
        (ac_dir / "F-0001.md").write_text("# AC\n")
        result = SpawnResult("ok", returncode=0)
        checker = MilestoneChecker(tmp_path, result)
        m = checker.check("features_specced")
        assert m.passed

    def test_component_features_scoped_pass(self, tmp_path):
        from auto import SpawnResult
        from auto.framework_verify import MilestoneChecker
        spec_dir = tmp_path / ".agentic" / "spec"
        spec_dir.mkdir(parents=True)
        (spec_dir / "FEATURES.md").write_text(
            "## F-0001: API\n**Component**: api\n"
        )
        result = SpawnResult("ok", returncode=0)
        checker = MilestoneChecker(tmp_path, result)
        m = checker.check("component_features_scoped")
        assert m.passed

    def test_contracts_defined_pass(self, tmp_path):
        from auto import SpawnResult
        from auto.framework_verify import MilestoneChecker
        (tmp_path / "STACK.md").write_text("# STACK\n\n## Contracts\n| Name |\n")
        result = SpawnResult("ok", returncode=0)
        checker = MilestoneChecker(tmp_path, result)
        m = checker.check("contracts_defined")
        assert m.passed

    def test_verification_green_pass(self, tmp_path):
        from auto import SpawnResult
        from auto.framework_verify import MilestoneChecker
        result = SpawnResult("all good", returncode=0)
        checker = MilestoneChecker(tmp_path, result)
        m = checker.check("verification_green")
        assert m.passed

    def test_verification_green_fail_timeout(self, tmp_path):
        from auto import SpawnResult
        from auto.framework_verify import MilestoneChecker
        result = SpawnResult("error: timed out", returncode=-1, timed_out=True)
        checker = MilestoneChecker(tmp_path, result)
        m = checker.check("verification_green")
        assert not m.passed

    def test_verification_green_fail_nonzero(self, tmp_path):
        from auto import SpawnResult
        from auto.framework_verify import MilestoneChecker
        result = SpawnResult("error", returncode=1)
        checker = MilestoneChecker(tmp_path, result)
        m = checker.check("verification_green")
        assert not m.passed

    def test_unknown_milestone(self, tmp_path):
        from auto import SpawnResult
        from auto.framework_verify import MilestoneChecker
        result = SpawnResult("ok", returncode=0)
        checker = MilestoneChecker(tmp_path, result)
        m = checker.check("nonexistent_milestone")
        assert not m.passed
        assert "Unknown" in m.detail

    def test_implementation_done(self, tmp_path):
        from auto import SpawnResult
        from auto.framework_verify import MilestoneChecker
        # Create a git repo with 2 commits
        subprocess.run(["git", "init"], cwd=str(tmp_path), check=True,
                       capture_output=True, text=True)
        (tmp_path / "f1.txt").write_text("init")
        subprocess.run(["git", "add", "."], cwd=str(tmp_path), check=True,
                       capture_output=True, text=True)
        subprocess.run(["git", "commit", "-m", "init"], cwd=str(tmp_path),
                       check=True, capture_output=True, text=True)
        (tmp_path / "f2.txt").write_text("impl")
        subprocess.run(["git", "add", "."], cwd=str(tmp_path), check=True,
                       capture_output=True, text=True)
        subprocess.run(["git", "commit", "-m", "implement"], cwd=str(tmp_path),
                       check=True, capture_output=True, text=True)
        result = SpawnResult("ok", returncode=0)
        checker = MilestoneChecker(tmp_path, result)
        m = checker.check("implementation_done")
        assert m.passed


# ---------------------------------------------------------------------------
# Project setup tests
# ---------------------------------------------------------------------------

class TestProjectSetup:
    """Test example project setup."""

    def test_setup_single_project(self, tmp_path):
        from auto.framework_verify import setup_project
        # Create a fake VW with .agentic
        vw = tmp_path / "vw"
        (vw / ".agentic" / "lib").mkdir(parents=True)
        (vw / ".agentic" / "lib" / "placeholder.txt").write_text("x")

        project = tmp_path / "project"
        scenario = {
            "type": "single",
            "description": "Test",
            "stack": {"language": "python", "framework": "fastapi"},
        }
        settings = {"profile": "discovery", "git_workflow": "direct"}
        setup_project(scenario, vw, project, settings)

        assert (project / ".agentic" / "lib" / "placeholder.txt").exists()
        assert (project / ".claude" / "settings.json").exists()
        assert (project / "STACK.md").exists()

        # Verify tier-1 settings
        s = json.loads((project / ".claude" / "settings.json").read_text())
        assert s["_tier"] == 1

        # Verify git init
        result = subprocess.run(
            ["git", "log", "--oneline"],
            capture_output=True, text=True, cwd=str(project),
        )
        assert result.returncode == 0
        assert "init" in result.stdout

    def test_setup_bootstraps_agent_files(self, tmp_path):
        """setup_project must create CLAUDE.md and .claude/skills/ for the build agent."""
        from auto.framework_verify import setup_project
        # Use the REAL framework source so templates exist
        vw = Path(__file__).resolve().parent.parent

        project = tmp_path / "project"
        scenario = {
            "type": "single",
            "description": "Bootstrap test",
            "stack": {"language": "python"},
        }
        settings = {"profile": "discovery", "git_workflow": "direct"}
        setup_project(scenario, vw, project, settings)

        # CLAUDE.md must exist (auto-loaded by Claude Code)
        assert (project / "CLAUDE.md").exists(), "CLAUDE.md not bootstrapped"
        content = (project / "CLAUDE.md").read_text()
        assert "ag " in content, "CLAUDE.md should reference ag commands"

        # Skills must be generated
        skills_dir = project / ".claude" / "skills"
        assert skills_dir.is_dir(), ".claude/skills/ not bootstrapped"
        skill_names = [d.name for d in skills_dir.iterdir() if d.is_dir()]
        assert "implementing-features" in skill_names
        assert "session-start" in skill_names

        # AGENTS.md must exist (non-negotiable rules)
        assert (project / "AGENTS.md").exists(), "AGENTS.md not bootstrapped"

        # Presets must be accessible for get_setting()
        assert (project / ".agentic" / "presets" / "profiles.conf").exists()

    def test_setup_monorepo_creates_component_dirs(self, tmp_path):
        from auto.framework_verify import setup_project
        vw = tmp_path / "vw"
        (vw / ".agentic" / "lib").mkdir(parents=True)
        (vw / ".agentic" / "lib" / "placeholder.txt").write_text("x")

        project = tmp_path / "project"
        scenario = {
            "type": "monorepo",
            "description": "Monorepo test",
            "stack": {"language": "python"},
            "components": [
                {"name": "api", "path": "packages/api", "type": "python"},
                {"name": "web", "path": "packages/web", "type": "typescript"},
            ],
        }
        settings = {"profile": "formal", "git_workflow": "pull_request"}
        setup_project(scenario, vw, project, settings)

        assert (project / "packages" / "api").is_dir()
        assert (project / "packages" / "web").is_dir()
        assert (project / "STACK.md").exists()

        # Verify STACK.md has Components table
        content = (project / "STACK.md").read_text()
        assert "## Components" in content
        assert "api" in content
        assert "web" in content


# ---------------------------------------------------------------------------
# VerifyResult tests
# ---------------------------------------------------------------------------

class TestPreFlight:
    """Test pre-flight safety checks."""

    def test_framework_only_guard_blocks_user_projects(self, tmp_path):
        """verify-framework must refuse to run in non-framework repos."""
        from auto.framework_verify import FrameworkVerifier
        # tmp_path has no FRAMEWORK_DEVELOPMENT.md
        verifier = FrameworkVerifier(tmp_path)
        errors = verifier.pre_flight()
        assert any("FRAMEWORK_DEVELOPMENT.md" in e for e in errors)

    def test_framework_only_guard_passes_in_framework_repo(self):
        """verify-framework should pass the guard in the actual framework repo."""
        from auto.framework_verify import FrameworkVerifier
        project_root = Path(__file__).parent.parent
        verifier = FrameworkVerifier(project_root)
        errors = verifier.pre_flight()
        # Should not have the framework-only error (may have others like "on main")
        assert not any("FRAMEWORK_DEVELOPMENT.md" in e for e in errors)


class TestVerifyResult:
    """Test result serialization."""

    def test_to_dict(self):
        from auto.framework_verify import VerifyResult, ScenarioRun, MilestoneResult
        r = VerifyResult(
            success=True,
            runs=[
                ScenarioRun(
                    scenario_name="Todo App",
                    settings_label="discovery",
                    success=True,
                    milestones=[MilestoneResult("kickoff_complete", True)],
                ),
            ],
            total_fixes=0,
        )
        d = r.to_dict()
        assert d["success"] is True
        assert len(d["runs"]) == 1
        assert d["runs"][0]["scenario"] == "Todo App"
        assert d["runs"][0]["milestones"][0]["passed"] is True


# ---------------------------------------------------------------------------
# Build prompt tests
# ---------------------------------------------------------------------------

class TestBuildPrompt:
    """Test prompt generation."""

    def test_build_prompt_includes_vision(self):
        from auto.framework_verify import build_prompt
        scenario = {
            "vision": "Build a todo app",
            "stack": {"language": "python"},
        }
        settings = {"profile": "discovery", "git_workflow": "direct"}
        prompt = build_prompt(scenario, settings)
        assert "Build a todo app" in prompt
        assert "discovery" in prompt


# ---------------------------------------------------------------------------
# AG_TRUNK_BRANCH env var tests
# ---------------------------------------------------------------------------

class TestTrunkBranchEnvVar:
    """Test that AG_TRUNK_BRANCH env var is accepted by modified scripts."""

    def test_state_commit_accepts_trunk_branch(self):
        """state-commit.sh should accept AG_TRUNK_BRANCH."""
        script = Path(__file__).parent.parent / ".agentic" / "lib" / "tools" / "state-commit.sh"
        content = script.read_text()
        assert "AG_TRUNK_BRANCH" in content

    def test_wip_accepts_trunk_branch(self):
        """wip.sh should accept AG_TRUNK_BRANCH."""
        script = Path(__file__).parent.parent / ".agentic" / "lib" / "tools" / "wip.sh"
        content = script.read_text()
        assert "AG_TRUNK_BRANCH" in content

    def test_manifest_accepts_trunk_branch(self):
        """manifest.sh should accept AG_TRUNK_BRANCH."""
        script = Path(__file__).parent.parent / ".agentic" / "lib" / "tools" / "manifest.sh"
        content = script.read_text()
        assert "AG_TRUNK_BRANCH" in content

    def test_critical_agent_accepts_trunk_branch(self):
        """critical_agent.py should use AG_TRUNK_BRANCH."""
        script = Path(__file__).parent.parent / ".agentic" / "lib" / "auto" / "critical_agent.py"
        content = script.read_text()
        assert "AG_TRUNK_BRANCH" in content

    def test_ag_sh_accepts_trunk_branch(self):
        """ag.sh should accept AG_TRUNK_BRANCH."""
        script = Path(__file__).parent.parent / ".agentic" / "lib" / "tools" / "ag.sh"
        content = script.read_text()
        assert "AG_TRUNK_BRANCH" in content


# ---------------------------------------------------------------------------
# ExpectationChecker tests
# ---------------------------------------------------------------------------

class TestExpectationChecker:
    """Test BDD-style behavioral expectations."""

    def test_files_exist_pass(self, tmp_path):
        from auto.framework_verify import ExpectationChecker
        (tmp_path / "app").mkdir()
        (tmp_path / "app" / "main.py").write_text("print('hello')")
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({"files_exist": ["app/**/*.py"]})
        assert len(results) == 1
        assert results[0].passed

    def test_files_exist_fail(self, tmp_path):
        from auto.framework_verify import ExpectationChecker
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({"files_exist": ["app/**/*.py"]})
        assert len(results) == 1
        assert not results[0].passed

    def test_command_passes_pass(self, tmp_path):
        from auto.framework_verify import ExpectationChecker
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({"commands_pass": ["true"]})
        assert len(results) == 1
        assert results[0].passed

    def test_command_passes_fail(self, tmp_path):
        from auto.framework_verify import ExpectationChecker
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({"commands_pass": ["false"]})
        assert len(results) == 1
        assert not results[0].passed
        assert "exit 1" in results[0].detail

    def test_source_contains_pass(self, tmp_path):
        from auto.framework_verify import ExpectationChecker
        (tmp_path / "app").mkdir()
        (tmp_path / "app" / "main.py").write_text("from fastapi import FastAPI")
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({
            "source_contains": [{"pattern": "FastAPI", "glob": "app/**/*.py"}],
        })
        assert len(results) == 1
        assert results[0].passed

    def test_source_contains_fail(self, tmp_path):
        from auto.framework_verify import ExpectationChecker
        (tmp_path / "app").mkdir()
        (tmp_path / "app" / "main.py").write_text("import flask")
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({
            "source_contains": [{"pattern": "FastAPI", "glob": "app/**/*.py"}],
        })
        assert len(results) == 1
        assert not results[0].passed

    def test_source_contains_no_matching_files(self, tmp_path):
        from auto.framework_verify import ExpectationChecker
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({
            "source_contains": [{"pattern": "FastAPI", "glob": "app/**/*.py"}],
        })
        assert len(results) == 1
        assert not results[0].passed
        assert "no files" in results[0].detail

    def test_multiple_expectations(self, tmp_path):
        from auto.framework_verify import ExpectationChecker
        (tmp_path / "app").mkdir()
        (tmp_path / "app" / "main.py").write_text("from fastapi import FastAPI")
        (tmp_path / "tests").mkdir()
        (tmp_path / "tests" / "test_app.py").write_text("def test_hello(): pass")
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({
            "files_exist": ["app/**/*.py", "tests/test_*.py"],
            "source_contains": [{"pattern": "def test_", "glob": "tests/**/*.py"}],
            "commands_pass": ["true"],
        })
        assert len(results) == 4
        assert all(r.passed for r in results)

    def test_empty_expectations(self, tmp_path):
        from auto.framework_verify import ExpectationChecker
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({})
        assert results == []

    def test_scenarios_have_expectations(self):
        """All scenarios should have behavioral expectations."""
        from auto.framework_verify import list_scenarios, load_scenario
        for name in list_scenarios():
            s = load_scenario(name)
            assert "expectations" in s, f"Scenario '{name}' missing expectations"
            exp = s["expectations"]
            assert len(exp) > 0, f"Scenario '{name}' has empty expectations"

    def test_no_workflow_in_yaml(self):
        """No settings_matrix entry should have workflow expectations (derived at runtime)."""
        from auto.framework_verify import list_scenarios, load_scenario
        for name in list_scenarios():
            s = load_scenario(name)
            for settings in s.get("settings_matrix", []):
                exp = settings.get("expectations", {})
                assert "workflow" not in exp, (
                    f"{name}/{settings.get('profile', '?')}: "
                    "workflow expectations must be derived, not hardcoded in YAML"
                )


# ---------------------------------------------------------------------------
# Workflow expectation tests
# ---------------------------------------------------------------------------

class TestWorkflowExpectations:
    """Test framework workflow verification."""

    def test_features_have_status_pass(self, tmp_path):
        from auto.framework_verify import ExpectationChecker
        spec_dir = tmp_path / ".agentic" / "spec"
        spec_dir.mkdir(parents=True)
        (spec_dir / "FEATURES.md").write_text(
            "## F-0001: Todo CRUD\n**Status**: shipped\n"
        )
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({
            "workflow": [{"type": "features_have_status", "status": "shipped", "min": 1}],
        })
        assert len(results) == 1
        assert results[0].passed

    def test_features_have_status_fail(self, tmp_path):
        from auto.framework_verify import ExpectationChecker
        spec_dir = tmp_path / ".agentic" / "spec"
        spec_dir.mkdir(parents=True)
        (spec_dir / "FEATURES.md").write_text(
            "## F-0001: Todo CRUD\n**Status**: planned\n"
        )
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({
            "workflow": [{"type": "features_have_status", "status": "shipped", "min": 1}],
        })
        assert len(results) == 1
        assert not results[0].passed

    def test_plans_exist_pass(self, tmp_path):
        from auto.framework_verify import ExpectationChecker
        plans = tmp_path / ".agentic" / "journal" / "plans"
        plans.mkdir(parents=True)
        (plans / "F-0001-plan.md").write_text("# Plan\n**Status**: APPROVED\n")
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({
            "workflow": [{"type": "plans_exist", "min": 1}],
        })
        assert results[0].passed

    def test_plans_approved_pass(self, tmp_path):
        from auto.framework_verify import ExpectationChecker
        plans = tmp_path / ".agentic" / "journal" / "plans"
        plans.mkdir(parents=True)
        (plans / "F-0001-plan.md").write_text("# Plan\n**Status**: APPROVED\n")
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({
            "workflow": [{"type": "plans_approved", "min": 1}],
        })
        assert results[0].passed

    def test_plans_approved_fail_draft(self, tmp_path):
        from auto.framework_verify import ExpectationChecker
        plans = tmp_path / ".agentic" / "journal" / "plans"
        plans.mkdir(parents=True)
        (plans / "F-0001-plan.md").write_text("# Plan\n**Status**: DRAFT\n")
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({
            "workflow": [{"type": "plans_approved", "min": 1}],
        })
        assert not results[0].passed

    def test_acceptance_criteria_checked_pass(self, tmp_path):
        from auto.framework_verify import ExpectationChecker
        ac_dir = tmp_path / ".agentic" / "spec" / "acceptance"
        ac_dir.mkdir(parents=True)
        (ac_dir / "F-0001.md").write_text("- [x] API returns todos\n- [x] Tests pass\n")
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({
            "workflow": [{"type": "acceptance_criteria_checked", "min": 1}],
        })
        assert results[0].passed

    def test_acceptance_criteria_checked_fail(self, tmp_path):
        from auto.framework_verify import ExpectationChecker
        ac_dir = tmp_path / ".agentic" / "spec" / "acceptance"
        ac_dir.mkdir(parents=True)
        (ac_dir / "F-0001.md").write_text("- [x] API returns todos\n- [ ] Tests pass\n")
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({
            "workflow": [{"type": "acceptance_criteria_checked", "min": 1}],
        })
        assert not results[0].passed

    def test_journal_updated_pass(self, tmp_path):
        from auto.framework_verify import ExpectationChecker
        journal_dir = tmp_path / ".agentic" / "journal"
        journal_dir.mkdir(parents=True)
        (journal_dir / "JOURNAL.md").write_text("## Session 1\nDid some work\n")
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({
            "workflow": [{"type": "journal_updated"}],
        })
        assert results[0].passed

    def test_no_wip_at_end_pass(self, tmp_path):
        from auto.framework_verify import ExpectationChecker
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({
            "workflow": [{"type": "no_wip_at_end"}],
        })
        assert results[0].passed

    def test_no_wip_at_end_fail_wip(self, tmp_path):
        from auto.framework_verify import ExpectationChecker
        session = tmp_path / ".agentic" / "session"
        session.mkdir(parents=True)
        (session / "WIP.md").write_text("working on stuff")
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({
            "workflow": [{"type": "no_wip_at_end"}],
        })
        assert not results[0].passed

    def test_commits_follow_convention(self, tmp_path):
        from auto.framework_verify import ExpectationChecker
        subprocess.run(["git", "init"], cwd=str(tmp_path),
                       check=True, capture_output=True)
        (tmp_path / "f1.txt").write_text("init")
        subprocess.run(["git", "add", "."], cwd=str(tmp_path),
                       check=True, capture_output=True)
        subprocess.run(["git", "commit", "-m", "init: scaffold"],
                       cwd=str(tmp_path), check=True, capture_output=True)
        (tmp_path / "f2.txt").write_text("code")
        subprocess.run(["git", "add", "."], cwd=str(tmp_path),
                       check=True, capture_output=True)
        subprocess.run(["git", "commit", "-m", "feat(F-0001): add todo API"],
                       cwd=str(tmp_path), check=True, capture_output=True)
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({
            "workflow": [{"type": "commits_follow_convention", "min": 1}],
        })
        assert results[0].passed

    def test_unknown_workflow_type(self, tmp_path):
        from auto.framework_verify import ExpectationChecker
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({
            "workflow": [{"type": "nonexistent_check"}],
        })
        assert not results[0].passed
        assert "Unknown" in results[0].detail


# ---------------------------------------------------------------------------
# Settings-driven workflow derivation tests
# ---------------------------------------------------------------------------

class TestDeriveWorkflowExpectations:
    """Test that workflow expectations are derived from resolved settings."""

    _FRAMEWORK_ROOT = Path(__file__).resolve().parent.parent

    def _setup_test_project(self, root: Path, profile: str,
                            overrides: dict[str, str] | None = None) -> None:
        """Create a minimal test project with STACK.md and profiles.conf."""
        # Copy profiles.conf from the real framework
        presets_dst = root / ".agentic" / "presets"
        presets_dst.mkdir(parents=True, exist_ok=True)
        presets_src = self._FRAMEWORK_ROOT / ".agentic" / "lib" / "presets" / "profiles.conf"
        shutil.copy2(str(presets_src), str(presets_dst / "profiles.conf"))

        # Write STACK.md with profile + overrides
        lines = [
            "# STACK.md", "",
            "## Settings",
            f"- profile: {profile}",
        ]
        for key, val in (overrides or {}).items():
            lines.append(f"- {key}: {val}")
        lines.append("")
        (root / "STACK.md").write_text("\n".join(lines))

    def test_discovery_gets_base_checks(self, tmp_path):
        """Discovery profile: only journal + commits + no_wip."""
        from auto.framework_verify import derive_workflow_expectations
        self._setup_test_project(tmp_path, "discovery")
        checks = derive_workflow_expectations(tmp_path)
        types = {c["type"] for c in checks}
        assert types == {"journal_updated", "commits_follow_convention", "no_wip_at_end"}

    def test_formal_gets_full_checks(self, tmp_path):
        """Formal profile: adds features, AC, plans."""
        from auto.framework_verify import derive_workflow_expectations
        self._setup_test_project(tmp_path, "formal")
        checks = derive_workflow_expectations(tmp_path)
        types = {c["type"] for c in checks}
        expected = {
            "journal_updated", "commits_follow_convention", "no_wip_at_end",
            "features_have_status", "acceptance_criteria_checked",
            "plans_exist", "plans_approved",
        }
        assert types == expected

    def test_override_disables_plans(self, tmp_path):
        """Formal with plan_review_enabled: no should remove plan checks."""
        from auto.framework_verify import derive_workflow_expectations
        self._setup_test_project(tmp_path, "formal", {"plan_review_enabled": "no"})
        checks = derive_workflow_expectations(tmp_path)
        types = {c["type"] for c in checks}
        assert "plans_exist" not in types
        assert "plans_approved" not in types
        # But features + AC should still be present
        assert "features_have_status" in types
        assert "acceptance_criteria_checked" in types

    def test_override_enables_features_on_discovery(self, tmp_path):
        """Discovery with feature_tracking: yes should add feature check."""
        from auto.framework_verify import derive_workflow_expectations
        self._setup_test_project(tmp_path, "discovery", {"feature_tracking": "yes"})
        checks = derive_workflow_expectations(tmp_path)
        types = {c["type"] for c in checks}
        assert "features_have_status" in types
        # But no plans or AC (not enabled)
        assert "plans_exist" not in types
        assert "acceptance_criteria_checked" not in types
