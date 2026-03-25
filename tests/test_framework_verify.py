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
        (spec_dir / "FEATURES.md").write_text("## F-001: Test\n**Status**: planned\n")
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
        (ac_dir / "F-001.md").write_text("# AC\n")
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
            "## F-001: API\n**Component**: api\n"
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
        # Default is discovery template — has "instruction files" not profile name
        assert "instruction files" in prompt

    def test_build_prompt_recipe_includes_profile(self):
        from auto.framework_verify import build_prompt
        scenario = {
            "vision": "Build a todo app",
            "stack": {"language": "python"},
        }
        settings = {"profile": "discovery", "git_workflow": "direct",
                     "prompt_tier": "recipe"}
        prompt = build_prompt(scenario, settings)
        assert "Build a todo app" in prompt
        assert "discovery" in prompt
        assert "ag kickoff" in prompt


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
            "## F-001: Todo CRUD\n**Status**: shipped\n"
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
            "## F-001: Todo CRUD\n**Status**: planned\n"
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
        (plans / "F-001-plan.md").write_text("# Plan\n**Status**: APPROVED\n")
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({
            "workflow": [{"type": "plans_exist", "min": 1}],
        })
        assert results[0].passed

    def test_plans_approved_pass(self, tmp_path):
        from auto.framework_verify import ExpectationChecker
        plans = tmp_path / ".agentic" / "journal" / "plans"
        plans.mkdir(parents=True)
        (plans / "F-001-plan.md").write_text("# Plan\n**Status**: APPROVED\n")
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({
            "workflow": [{"type": "plans_approved", "min": 1}],
        })
        assert results[0].passed

    def test_plans_approved_fail_draft(self, tmp_path):
        from auto.framework_verify import ExpectationChecker
        plans = tmp_path / ".agentic" / "journal" / "plans"
        plans.mkdir(parents=True)
        (plans / "F-001-plan.md").write_text("# Plan\n**Status**: DRAFT\n")
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({
            "workflow": [{"type": "plans_approved", "min": 1}],
        })
        assert not results[0].passed

    def test_acceptance_criteria_checked_pass(self, tmp_path):
        from auto.framework_verify import ExpectationChecker
        ac_dir = tmp_path / ".agentic" / "spec" / "acceptance"
        ac_dir.mkdir(parents=True)
        (ac_dir / "F-001.md").write_text("- [x] API returns todos\n- [x] Tests pass\n")
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({
            "workflow": [{"type": "acceptance_criteria_checked", "min": 1}],
        })
        assert results[0].passed

    def test_acceptance_criteria_checked_fail(self, tmp_path):
        from auto.framework_verify import ExpectationChecker
        ac_dir = tmp_path / ".agentic" / "spec" / "acceptance"
        ac_dir.mkdir(parents=True)
        (ac_dir / "F-001.md").write_text("- [x] API returns todos\n- [ ] Tests pass\n")
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({
            "workflow": [{"type": "acceptance_criteria_checked", "min": 1}],
        })
        assert not results[0].passed

    def test_journal_updated_pass(self, tmp_path):
        from auto.framework_verify import ExpectationChecker
        journal_dir = tmp_path / ".agentic" / "journal"
        journal_dir.mkdir(parents=True)
        (journal_dir / "JOURNAL.md").write_text("### Session: 2026-03-15 - Test\nDid some work\n")
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
        subprocess.run(["git", "commit", "-m", "feat(F-001): add todo API"],
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

    def test_check_one_returns_single_result(self, tmp_path):
        """check_one should return only the named expectation."""
        from auto.framework_verify import ExpectationChecker
        checker = ExpectationChecker(tmp_path)
        expectations = {
            "workflow": [
                {"type": "journal_updated"},
                {"type": "no_wip_at_end"},
            ],
        }
        result = checker.check_one(expectations, "no_wip_at_end")
        assert result is not None
        assert result.name == "no_wip_at_end"
        assert result.passed  # no WIP in tmp_path

    def test_check_one_returns_none_for_missing(self, tmp_path):
        """check_one should return None for non-existent check name."""
        from auto.framework_verify import ExpectationChecker
        checker = ExpectationChecker(tmp_path)
        result = checker.check_one({"workflow": [{"type": "no_wip_at_end"}]}, "nonexistent")
        assert result is None

    def test_journal_header_only_does_not_pass(self, tmp_path):
        """A journal with only ## headings (no ### Session entries) should fail."""
        from auto.framework_verify import ExpectationChecker
        journal_dir = tmp_path / ".agentic" / "journal"
        journal_dir.mkdir(parents=True)
        (journal_dir / "JOURNAL.md").write_text("## Session History\n\nNothing yet.\n")
        checker = ExpectationChecker(tmp_path)
        results = checker.check_all({"workflow": [{"type": "journal_updated"}]})
        assert not results[0].passed

    def test_derive_wired_into_scenario_expectations(self):
        """Verify that scenario loading + derive produces the right workflow checks.

        Integration test: loads a real scenario, simulates what run_scenario does
        with the expectation merge, and checks the workflow checks are correct.
        """
        from auto.framework_verify import (
            load_scenario, derive_workflow_expectations, setup_project,
        )
        import tempfile

        scenario = load_scenario("todo_app")

        for settings in scenario["settings_matrix"]:
            with tempfile.TemporaryDirectory() as tmp:
                project_dir = Path(tmp) / "project"
                vw = Path(__file__).resolve().parent.parent
                setup_project(scenario, vw, project_dir, settings)

                # Simulate run_scenario's expectation merge
                expectations = dict(scenario.get("expectations", {}))
                expectations["workflow"] = derive_workflow_expectations(project_dir)

                assert "workflow" in expectations
                types = {c["type"] for c in expectations["workflow"]}

                # All profiles must have base checks
                assert "journal_updated" in types
                assert "no_wip_at_end" in types

                profile = settings.get("profile", "")
                if profile == "autonomous_formal":
                    # Formal must have plans + features + AC
                    assert "plans_exist" in types
                    assert "features_have_status" in types
                elif profile == "discovery":
                    # Discovery must NOT have plans or features
                    assert "plans_exist" not in types
                    assert "features_have_status" not in types


# ---------------------------------------------------------------------------
# Build prompt discovery/recipe tests
# ---------------------------------------------------------------------------

class TestBuildPromptTiers:
    """Test discovery vs recipe prompt selection."""

    def test_default_uses_discovery(self):
        from auto.framework_verify import build_prompt
        scenario = {
            "vision": "Build a todo app",
            "stack": {"language": "python"},
        }
        settings = {"profile": "discovery", "git_workflow": "direct"}
        prompt = build_prompt(scenario, settings)
        assert "Build a todo app" in prompt
        # Discovery prompt should NOT have prescriptive steps
        assert "ag kickoff" not in prompt
        assert "ag implement" not in prompt
        # Discovery prompt should mention instruction files
        assert "instruction files" in prompt

    def test_recipe_uses_original_template(self):
        from auto.framework_verify import build_prompt
        scenario = {
            "vision": "Build a todo app",
            "stack": {"language": "python"},
        }
        settings = {
            "profile": "discovery", "git_workflow": "direct",
            "prompt_tier": "recipe",
        }
        prompt = build_prompt(scenario, settings)
        assert "Build a todo app" in prompt
        # Recipe prompt has prescriptive steps
        assert "ag kickoff" in prompt
        assert "discovery" in prompt

    def test_explicit_discovery_tier(self):
        from auto.framework_verify import build_prompt
        scenario = {
            "vision": "Build a CLI tool",
            "stack": {"language": "python", "framework": "click"},
        }
        settings = {
            "profile": "formal", "git_workflow": "pull_request",
            "prompt_tier": "discovery",
        }
        prompt = build_prompt(scenario, settings)
        assert "Build a CLI tool" in prompt
        assert "instruction files" in prompt


# ---------------------------------------------------------------------------
# Behavioral expectation checker tests
# ---------------------------------------------------------------------------

class TestBehavioralExpectations:
    """Test discovery-mode behavioral checkers."""

    def test_spec_before_code_pass(self, tmp_path):
        """AC committed before code → pass."""
        from auto.framework_verify import ExpectationChecker
        subprocess.run(["git", "init"], cwd=str(tmp_path),
                       check=True, capture_output=True)
        # Commit 1: AC file
        ac_dir = tmp_path / ".agentic" / "spec" / "acceptance"
        ac_dir.mkdir(parents=True)
        (ac_dir / "F-001.md").write_text("- [ ] API works\n")
        subprocess.run(["git", "add", "."], cwd=str(tmp_path),
                       check=True, capture_output=True)
        subprocess.run(["git", "commit", "-m", "spec: add AC"],
                       cwd=str(tmp_path), check=True, capture_output=True)
        # Commit 2: source code
        (tmp_path / "app").mkdir()
        (tmp_path / "app" / "main.py").write_text("print('hello')")
        subprocess.run(["git", "add", "."], cwd=str(tmp_path),
                       check=True, capture_output=True)
        subprocess.run(["git", "commit", "-m", "feat: add app"],
                       cwd=str(tmp_path), check=True, capture_output=True)

        checker = ExpectationChecker(tmp_path)
        result = checker._wf_spec_before_code({})
        assert result.passed

    def test_spec_before_code_fail(self, tmp_path):
        """Code committed before AC → fail."""
        from auto.framework_verify import ExpectationChecker
        subprocess.run(["git", "init"], cwd=str(tmp_path),
                       check=True, capture_output=True)
        # Commit 1: source code first
        (tmp_path / "app").mkdir()
        (tmp_path / "app" / "main.py").write_text("print('hello')")
        subprocess.run(["git", "add", "."], cwd=str(tmp_path),
                       check=True, capture_output=True)
        subprocess.run(["git", "commit", "-m", "feat: add app"],
                       cwd=str(tmp_path), check=True, capture_output=True)
        # Commit 2: AC after code
        ac_dir = tmp_path / ".agentic" / "spec" / "acceptance"
        ac_dir.mkdir(parents=True)
        (ac_dir / "F-001.md").write_text("- [ ] API works\n")
        subprocess.run(["git", "add", "."], cwd=str(tmp_path),
                       check=True, capture_output=True)
        subprocess.run(["git", "commit", "-m", "spec: add AC"],
                       cwd=str(tmp_path), check=True, capture_output=True)

        checker = ExpectationChecker(tmp_path)
        result = checker._wf_spec_before_code({})
        assert not result.passed

    def test_spec_before_code_same_commit(self, tmp_path):
        """AC and code in same commit → pass."""
        from auto.framework_verify import ExpectationChecker
        subprocess.run(["git", "init"], cwd=str(tmp_path),
                       check=True, capture_output=True)
        ac_dir = tmp_path / ".agentic" / "spec" / "acceptance"
        ac_dir.mkdir(parents=True)
        (ac_dir / "F-001.md").write_text("- [ ] API works\n")
        (tmp_path / "app").mkdir()
        (tmp_path / "app" / "main.py").write_text("print('hello')")
        subprocess.run(["git", "add", "."], cwd=str(tmp_path),
                       check=True, capture_output=True)
        subprocess.run(["git", "commit", "-m", "feat: add everything"],
                       cwd=str(tmp_path), check=True, capture_output=True)

        checker = ExpectationChecker(tmp_path)
        result = checker._wf_spec_before_code({})
        assert result.passed

    def test_workflow_commands_used_kickoff(self, tmp_path):
        """FEATURES.md with structured format → kickoff detected."""
        from auto.framework_verify import ExpectationChecker
        spec_dir = tmp_path / ".agentic" / "spec"
        spec_dir.mkdir(parents=True)
        (spec_dir / "FEATURES.md").write_text(
            "## F-001: Todo CRUD\n**Status**: planned\n**Description**: CRUD ops\n"
        )
        checker = ExpectationChecker(tmp_path)
        result = checker._wf_workflow_commands_used({
            "command": "kickoff", "evidence": "features_md_format",
        })
        assert result.passed

    def test_workflow_commands_used_kickoff_status_on_different_line(self, tmp_path):
        """FEATURES.md with F-XXXX and Status on different lines → still detected."""
        from auto.framework_verify import ExpectationChecker
        spec_dir = tmp_path / ".agentic" / "spec"
        spec_dir.mkdir(parents=True)
        (spec_dir / "FEATURES.md").write_text(
            "## F-001: Todo CRUD\n\n**Status**: shipped\n\n**Description**: CRUD ops\n"
        )
        checker = ExpectationChecker(tmp_path)
        result = checker._wf_workflow_commands_used({
            "command": "kickoff", "evidence": "features_md_format",
        })
        assert result.passed

    def test_workflow_commands_used_kickoff_fail(self, tmp_path):
        """FEATURES.md without structured format → kickoff not detected."""
        from auto.framework_verify import ExpectationChecker
        spec_dir = tmp_path / ".agentic" / "spec"
        spec_dir.mkdir(parents=True)
        (spec_dir / "FEATURES.md").write_text("# Features\nSome random text\n")
        checker = ExpectationChecker(tmp_path)
        result = checker._wf_workflow_commands_used({
            "command": "kickoff", "evidence": "features_md_format",
        })
        assert not result.passed

    def test_workflow_commands_used_commit(self, tmp_path):
        """Conventional commit messages → commit command detected."""
        from auto.framework_verify import ExpectationChecker
        subprocess.run(["git", "init"], cwd=str(tmp_path),
                       check=True, capture_output=True)
        (tmp_path / "f.txt").write_text("x")
        subprocess.run(["git", "add", "."], cwd=str(tmp_path),
                       check=True, capture_output=True)
        subprocess.run(["git", "commit", "-m", "feat(todo): add CRUD API"],
                       cwd=str(tmp_path), check=True, capture_output=True)

        checker = ExpectationChecker(tmp_path)
        result = checker._wf_workflow_commands_used({
            "command": "commit", "evidence": "conventional_commits",
        })
        assert result.passed

    def test_session_start_ran_pass_status(self, tmp_path):
        """STATUS.md with content → session start detected."""
        from auto.framework_verify import ExpectationChecker
        (tmp_path / ".agentic").mkdir()
        (tmp_path / ".agentic" / "STATUS.md").write_text(
            "# Current Focus\n\nImplementing F-001: Todo CRUD API\n\n## Context\nBuilding the app"
        )
        checker = ExpectationChecker(tmp_path)
        result = checker._wf_session_start_ran({})
        assert result.passed

    def test_session_start_ran_fail(self, tmp_path):
        """No STATUS.md or JOURNAL.md → session start not detected."""
        from auto.framework_verify import ExpectationChecker
        checker = ExpectationChecker(tmp_path)
        result = checker._wf_session_start_ran({})
        assert not result.passed

    def test_plans_reviewed_pass(self, tmp_path):
        """Plan with APPROVED status → review detected."""
        from auto.framework_verify import ExpectationChecker
        plans = tmp_path / ".agentic" / "journal" / "plans"
        plans.mkdir(parents=True)
        (plans / "F-001-plan.md").write_text("# Plan\n**Status**: APPROVED\n")
        checker = ExpectationChecker(tmp_path)
        result = checker._wf_plans_reviewed({})
        assert result.passed

    def test_plans_reviewed_fail_draft(self, tmp_path):
        """Plan with DRAFT status → review not complete."""
        from auto.framework_verify import ExpectationChecker
        plans = tmp_path / ".agentic" / "journal" / "plans"
        plans.mkdir(parents=True)
        (plans / "F-001-plan.md").write_text("# Plan\n**Status**: DRAFT\n")
        checker = ExpectationChecker(tmp_path)
        result = checker._wf_plans_reviewed({})
        assert not result.passed

    def test_instruction_files_consulted_pass(self, tmp_path):
        """Agent log with instruction file references → pass."""
        from auto.framework_verify import ExpectationChecker
        log = tmp_path / "agent.log"
        log.write_text(
            "Reading CLAUDE.md...\nChecking skills/ directory...\n"
            "Found implementing-features skill\n"
        )
        checker = ExpectationChecker(tmp_path, agent_log=log)
        result = checker._wf_instruction_files_consulted({})
        assert result.passed

    def test_instruction_files_consulted_fail_no_log(self, tmp_path):
        """No agent log → fail."""
        from auto.framework_verify import ExpectationChecker
        checker = ExpectationChecker(tmp_path)
        result = checker._wf_instruction_files_consulted({})
        assert not result.passed

    def test_check_behavioral_method(self, tmp_path):
        """check_behavioral dispatches to _wf_ methods."""
        from auto.framework_verify import ExpectationChecker
        checker = ExpectationChecker(tmp_path)
        results = checker.check_behavioral([
            {"type": "session_start_ran", "severity": "warning"},
        ])
        assert len(results) == 1
        assert results[0].name == "session_start_ran"

    def test_check_behavioral_unknown_type(self, tmp_path):
        """Unknown behavioral check type → fail gracefully."""
        from auto.framework_verify import ExpectationChecker
        checker = ExpectationChecker(tmp_path)
        results = checker.check_behavioral([
            {"type": "nonexistent_check", "severity": "warning"},
        ])
        assert len(results) == 1
        assert not results[0].passed
        assert "Unknown" in results[0].detail


# ---------------------------------------------------------------------------
# Derive behavioral expectations tests
# ---------------------------------------------------------------------------

class TestDeriveBehavioralExpectations:
    """Test derive_behavioral_expectations()."""

    _FRAMEWORK_ROOT = Path(__file__).resolve().parent.parent

    def _setup_test_project(self, root: Path, profile: str,
                            overrides: dict[str, str] | None = None) -> None:
        """Create a minimal test project with STACK.md and profiles.conf."""
        presets_dst = root / ".agentic" / "presets"
        presets_dst.mkdir(parents=True, exist_ok=True)
        presets_src = self._FRAMEWORK_ROOT / ".agentic" / "lib" / "presets" / "profiles.conf"
        shutil.copy2(str(presets_src), str(presets_dst / "profiles.conf"))

        lines = [
            "# STACK.md", "",
            "## Settings",
            f"- profile: {profile}",
        ]
        for key, val in (overrides or {}).items():
            lines.append(f"- {key}: {val}")
        lines.append("")
        (root / "STACK.md").write_text("\n".join(lines))

    def test_recipe_returns_empty(self, tmp_path):
        """Recipe mode → no behavioral expectations."""
        from auto.framework_verify import derive_behavioral_expectations
        self._setup_test_project(tmp_path, "discovery")
        checks = derive_behavioral_expectations(tmp_path, "recipe")
        assert checks == []

    def test_discovery_returns_base_checks(self, tmp_path):
        """Discovery mode → base behavioral checks."""
        from auto.framework_verify import derive_behavioral_expectations
        self._setup_test_project(tmp_path, "discovery")
        checks = derive_behavioral_expectations(tmp_path, "discovery")
        types = [c["type"] for c in checks]
        assert "spec_before_code" in types
        assert "session_start_ran" in types
        assert "workflow_commands_used" in types
        # All should be severity: warning
        assert all(c["severity"] == "warning" for c in checks)

    def test_discovery_no_plans_for_discovery_profile(self, tmp_path):
        """Discovery profile has no plan_review → no plans_reviewed check."""
        from auto.framework_verify import derive_behavioral_expectations
        self._setup_test_project(tmp_path, "discovery")
        checks = derive_behavioral_expectations(tmp_path, "discovery")
        types = [c["type"] for c in checks]
        assert "plans_reviewed" not in types

    def test_formal_adds_plans_reviewed(self, tmp_path):
        """Formal profile with plan_review → includes plans_reviewed."""
        from auto.framework_verify import derive_behavioral_expectations
        self._setup_test_project(tmp_path, "formal")
        checks = derive_behavioral_expectations(tmp_path, "discovery")
        types = [c["type"] for c in checks]
        assert "plans_reviewed" in types


# ---------------------------------------------------------------------------
# timeout_override and prompt_tier in ScenarioRun tests
# ---------------------------------------------------------------------------

class TestScenarioRunExtensions:
    """Test prompt_tier and behavioral_results in ScenarioRun."""

    def test_scenario_run_prompt_tier_default(self):
        from auto.framework_verify import ScenarioRun
        run = ScenarioRun(scenario_name="Test", settings_label="discovery")
        assert run.prompt_tier == "discovery"
        assert run.behavioral_results == []

    def test_scenario_run_prompt_tier_recipe(self):
        from auto.framework_verify import ScenarioRun
        run = ScenarioRun(
            scenario_name="Test", settings_label="formal",
            prompt_tier="recipe",
        )
        assert run.prompt_tier == "recipe"

    def test_to_dict_includes_prompt_tier(self):
        from auto.framework_verify import VerifyResult, ScenarioRun, MilestoneResult
        r = VerifyResult(
            success=True,
            runs=[
                ScenarioRun(
                    scenario_name="Todo App",
                    settings_label="discovery",
                    success=True,
                    prompt_tier="discovery",
                    milestones=[MilestoneResult("kickoff_complete", True)],
                    behavioral_results=[
                        MilestoneResult("session_start_ran", True, "STATUS.md has content"),
                    ],
                ),
            ],
            total_fixes=0,
        )
        d = r.to_dict()
        assert d["runs"][0]["prompt_tier"] == "discovery"
        assert len(d["runs"][0]["behavioral_results"]) == 1
        assert d["runs"][0]["behavioral_results"][0]["name"] == "session_start_ran"

    def test_timeout_override_in_yaml(self):
        """todo_app.yaml autonomous_formal should have timeout_override."""
        from auto.framework_verify import load_scenario
        s = load_scenario("todo_app")
        formal_settings = [
            m for m in s["settings_matrix"]
            if m.get("profile") == "autonomous_formal"
        ]
        assert len(formal_settings) == 1
        assert formal_settings[0].get("timeout_override") == 7200

    def test_prompt_tier_recipe_in_monorepo(self):
        """fullstack_monorepo should have prompt_tier: recipe."""
        from auto.framework_verify import load_scenario
        s = load_scenario("fullstack_monorepo")
        for settings in s["settings_matrix"]:
            assert settings.get("prompt_tier") == "recipe"

    def test_prompt_tier_recipe_in_multirepo(self):
        """fullstack_multirepo should have prompt_tier: recipe."""
        from auto.framework_verify import load_scenario
        s = load_scenario("fullstack_multirepo")
        for settings in s["settings_matrix"]:
            assert settings.get("prompt_tier") == "recipe"


# --- F-0242: Phase expectations ---


class TestPhaseExpectations:
    """Test phase_expectations YAML extension (F-0242)."""

    def test_scenarios_phase_expectations_optional(self):
        """All scenarios load without error, regardless of phase_expectations."""
        from auto.framework_verify import load_scenario, list_scenarios
        for slug in list_scenarios():
            s = load_scenario(slug)
            assert s is not None
            # phase_expectations is optional — should not raise
            _ = s.get("phase_expectations", [])

    def test_todo_app_has_phase_expectations(self):
        """todo_app.yaml has phase_expectations with expected structure."""
        from auto.framework_verify import load_scenario
        s = load_scenario("todo_app")
        pe = s.get("phase_expectations", [])
        assert len(pe) >= 2
        phases = {p["phase"] for p in pe}
        assert "kickoff" in phases
        assert "implement" in phases
        for p in pe:
            assert "detect_via" in p
            assert "framework_log" in p["detect_via"]

    def test_cli_tool_has_phase_expectations(self):
        """cli_tool.yaml has phase_expectations."""
        from auto.framework_verify import load_scenario
        s = load_scenario("cli_tool")
        pe = s.get("phase_expectations", [])
        assert len(pe) >= 2


class TestDiscoverJsonl:
    """Tests for discover_jsonl (F-0242)."""

    def test_returns_none_when_dir_missing(self, tmp_path):
        from auto import discover_jsonl
        # Project with no ~/.claude/projects/<hash>/ directory
        result = discover_jsonl(tmp_path / "nonexistent-project-abc123")
        assert result is None

    def test_returns_none_when_no_jsonl_files(self, tmp_path, monkeypatch):
        from auto import discover_jsonl
        # Create the expected directory but with no .jsonl files
        project_hash = str(tmp_path.resolve()).replace("/", "-")
        session_dir = tmp_path / "fake_home" / ".claude" / "projects" / project_hash
        session_dir.mkdir(parents=True)
        (session_dir / "some_other_file.txt").write_text("not jsonl")

        monkeypatch.setattr("pathlib.Path.home", lambda: tmp_path / "fake_home")
        result = discover_jsonl(tmp_path)
        assert result is None

    def test_returns_most_recent_jsonl(self, tmp_path, monkeypatch):
        import time
        from auto import discover_jsonl

        project_hash = str(tmp_path.resolve()).replace("/", "-")
        session_dir = tmp_path / "fake_home" / ".claude" / "projects" / project_hash
        session_dir.mkdir(parents=True)

        # Create two JSONL files with different mtimes
        older = session_dir / "old-session.jsonl"
        older.write_text('{"type":"user"}\n')

        # Ensure mtime difference is detectable
        time.sleep(0.05)

        newer = session_dir / "new-session.jsonl"
        newer.write_text('{"type":"user"}\n')

        monkeypatch.setattr("pathlib.Path.home", lambda: tmp_path / "fake_home")
        result = discover_jsonl(tmp_path)
        assert result is not None
        assert result.name == "new-session.jsonl"

    def test_path_hashing(self, tmp_path, monkeypatch):
        from auto import discover_jsonl

        # Create project at a specific path and verify the hash convention
        project_dir = tmp_path / "my" / "project"
        project_dir.mkdir(parents=True)
        project_hash = str(project_dir.resolve()).replace("/", "-")
        session_dir = tmp_path / "fake_home" / ".claude" / "projects" / project_hash
        session_dir.mkdir(parents=True)
        (session_dir / "session.jsonl").write_text('{"type":"user"}\n')

        monkeypatch.setattr("pathlib.Path.home", lambda: tmp_path / "fake_home")
        result = discover_jsonl(project_dir)
        assert result is not None
        assert result.name == "session.jsonl"
