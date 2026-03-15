"""Tests for framework_verify.py (F-0215)."""
from __future__ import annotations

import json
import os
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
