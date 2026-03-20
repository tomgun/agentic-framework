#!/usr/bin/env python3
"""
Tests for the v2 workflow engine.

Covers:
- Config loading from state_machine_af.yaml (with basic YAML parser)
- Work item creation, loading, and listing
- Transition enforcement (formal mode blocks, lean mode allows skips)
- Artifact precondition checking
- Skip transitions with audit logging
- Regression transitions
- Deprecated state handling
- CLI workflow commands (start, transition, check, verify, ship, status, next, info)
- State mapping (v1 → v2)
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

from auto.v2.config import (
    WorkflowConfig,
    load_config,
    is_v2_engine,
    _basic_yaml_parse,
    _CONFIG_CACHE,
)
from auto.v2 import work_items
from auto.v2.work_items import WorkItem
from auto.v2.transitions import TransitionOrchestrator, TransitionResult
from auto.v2.preconditions import CheckResult, check_artifact, check_transition_artifacts
from auto.v2.workflow import main as workflow_main


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def tmp_project(tmp_path):
    """Create a temporary project with state_machine_af.yaml."""
    agentic = tmp_path / ".agentic"
    agentic.mkdir()
    work_dir = agentic / "work"
    work_dir.mkdir()
    prompts_dir = agentic / "prompts"
    prompts_dir.mkdir()

    # Write a minimal config
    config_path = agentic / "state_machine_af.yaml"
    config_path.write_text(MINIMAL_CONFIG)

    # Write a role prompt for testing
    (prompts_dir / "planner.md").write_text("# Planner\nPlan the feature.\n")
    (prompts_dir / "implementer.md").write_text("# Implementer\nImplement the feature.\n")

    # Clear config cache
    _CONFIG_CACHE.clear()

    yield tmp_path

    _CONFIG_CACHE.clear()


MINIMAL_CONFIG = """\
version: 1
engine: v2

workflow:
  states:
    - idea
    - queued
    - planning
    - plan_review
    - spec
    - implementation
    - verification
    - docs
    - ready_to_ship
    - shipped
    - deprecated

  transitions:
    - {from: idea, to: queued}
    - {from: queued, to: planning}
    - {from: planning, to: plan_review, requires: [plan.md]}
    - {from: plan_review, to: spec, requires: [review.md], gate: plan_approved}
    - {from: spec, to: implementation, requires: [spec.md]}
    - {from: implementation, to: verification, requires: [tests_exist]}
    - {from: verification, to: docs, requires: [verification_pass]}
    - {from: docs, to: ready_to_ship, requires: [docs_updated]}
    - {from: ready_to_ship, to: shipped, gate: pr_merged}
    - {from: implementation, to: spec, type: regression}
    - {from: verification, to: implementation, type: regression}

modes:
  formal:
    escape_hatches: false
    skip_transitions: []
    required_artifacts:
      plan_review:
        - plan.md
      implementation:
        - spec.md
        - plan.md

  lean:
    escape_hatches: true
    skip_transitions:
      - {from: queued, to: implementation}
      - {from: planning, to: implementation}
    required_artifacts:
      implementation: []

profiles:
  hands_on:
    description: "Human reviews everything"
    gates:
      plan_approved: human
      pr_merged: human

  guided:
    description: "Human reviews plans, AI reviews code"
    gates:
      plan_approved: human
      pr_merged: human

  autonomous:
    description: "AI reviews everything except merge"
    gates:
      plan_approved: ai
      pr_merged: human

verification:
  commands:
    - {name: tests, run: "echo PASS", timeout: 10}
    - {name: lint, run: "echo OK", timeout: 10}

artifacts:
  plan.md:
    description: "Implementation plan"
    location: "{work_dir}/plan.md"

  review.md:
    description: "Adversarial review output"
    location: "{work_dir}/review.md"

  spec.md:
    description: "Acceptance criteria"
    location: "{work_dir}/spec.md"

  tests_exist:
    description: "Tests reference this feature"
    check: "test -f {work_dir}/spec.md"

  verification_pass:
    description: "Verification passed"
    location: "{work_dir}/verification.json"

  docs_updated:
    description: "Docs are up to date"
    check: "true"

  journal.md:
    description: "Per-feature decision log"
    location: "{work_dir}/journal.md"

state_mapping:
  planned: planning
  specced: spec
  implementing: implementation
  shipped: shipped
"""


# ---------------------------------------------------------------------------
# Config loading tests
# ---------------------------------------------------------------------------


class TestConfigLoading:
    """Test loading and parsing state_machine_af.yaml."""

    def test_load_config(self, tmp_project):
        config = load_config(tmp_project)
        assert config.version == 1
        assert config.engine == "v2"
        assert len(config.states) == 11
        assert "idea" in config.states
        assert "shipped" in config.states
        assert "deprecated" in config.states

    def test_load_config_transitions(self, tmp_project):
        config = load_config(tmp_project)
        assert len(config.transitions) > 0
        # Check a specific transition
        t = config.get_transition("planning", "plan_review")
        assert t is not None
        assert t.requires == ["plan.md"]

    def test_load_config_modes(self, tmp_project):
        config = load_config(tmp_project)
        assert "formal" in config.modes
        assert "lean" in config.modes
        assert config.modes["formal"].escape_hatches is False
        assert config.modes["lean"].escape_hatches is True

    def test_load_config_profiles(self, tmp_project):
        config = load_config(tmp_project)
        assert "hands_on" in config.profiles
        assert "guided" in config.profiles
        assert "autonomous" in config.profiles
        assert config.profiles["autonomous"].gates["plan_approved"] == "ai"

    def test_load_config_caching(self, tmp_project):
        config1 = load_config(tmp_project)
        config2 = load_config(tmp_project)
        assert config1 is config2  # Same object (cached)

    def test_load_config_force_reload(self, tmp_project):
        config1 = load_config(tmp_project)
        config2 = load_config(tmp_project, force=True)
        assert config1 is not config2

    def test_is_v2_engine(self, tmp_project):
        assert is_v2_engine(tmp_project) is True

    def test_is_v2_engine_missing_config(self, tmp_path):
        assert is_v2_engine(tmp_path) is False

    def test_state_mapping(self, tmp_project):
        config = load_config(tmp_project)
        assert config.resolve_v1_state("planned") == "planning"
        assert config.resolve_v1_state("implementing") == "implementation"
        assert config.resolve_v1_state("shipped") == "shipped"
        assert config.resolve_v1_state("unknown") is None

    def test_is_valid_state(self, tmp_project):
        config = load_config(tmp_project)
        assert config.is_valid_state("idea") is True
        assert config.is_valid_state("shipped") is True
        assert config.is_valid_state("deprecated") is True
        assert config.is_valid_state("nonexistent") is False

    def test_skip_transitions(self, tmp_project):
        config = load_config(tmp_project)
        assert config.is_skip_allowed("lean", "queued", "implementation") is True
        assert config.is_skip_allowed("lean", "planning", "implementation") is True
        assert config.is_skip_allowed("formal", "queued", "implementation") is False

    def test_get_required_artifacts(self, tmp_project):
        config = load_config(tmp_project)
        arts = config.get_required_artifacts("formal", "implementation")
        assert "spec.md" in arts
        assert "plan.md" in arts
        arts_lean = config.get_required_artifacts("lean", "implementation")
        assert arts_lean == []

    def test_get_gate_reviewer(self, tmp_project):
        config = load_config(tmp_project)
        assert config.get_gate_reviewer("autonomous", "plan_approved") == "ai"
        assert config.get_gate_reviewer("hands_on", "plan_approved") == "human"
        assert config.get_gate_reviewer("guided", "pr_merged") == "human"

    def test_missing_config_raises(self, tmp_path):
        with pytest.raises(FileNotFoundError, match="state_machine_af.yaml"):
            load_config(tmp_path)


# ---------------------------------------------------------------------------
# YAML parser tests
# ---------------------------------------------------------------------------


class TestBasicYamlParser:
    """Test the fallback YAML parser."""

    def test_scalars(self):
        data = _basic_yaml_parse("name: hello\ncount: 42\nactive: true\n")
        assert data["name"] == "hello"
        assert data["count"] == 42
        assert data["active"] is True

    def test_inline_list(self):
        data = _basic_yaml_parse("items: [a, b, c]\n")
        assert data["items"] == ["a", "b", "c"]

    def test_inline_dict(self):
        data = _basic_yaml_parse("- {from: a, to: b}\n")
        # Top-level list not supported in basic parser without context

    def test_nested_dict(self):
        data = _basic_yaml_parse("parent:\n  child: value\n")
        assert data["parent"]["child"] == "value"

    def test_list_items(self):
        data = _basic_yaml_parse("items:\n  - one\n  - two\n  - three\n")
        assert data["items"] == ["one", "two", "three"]

    def test_inline_dict_with_list(self):
        data = _basic_yaml_parse("items:\n  - {from: a, to: b, requires: [x, y]}\n")
        assert data["items"][0]["from"] == "a"
        assert data["items"][0]["requires"] == ["x", "y"]

    def test_comments_stripped(self):
        data = _basic_yaml_parse("name: hello # this is a comment\n")
        assert data["name"] == "hello"

    def test_quoted_strings(self):
        data = _basic_yaml_parse('name: "hello world"\n')
        assert data["name"] == "hello world"

    def test_boolean_variants(self):
        data = _basic_yaml_parse("a: true\nb: false\nc: yes\nd: no\n")
        assert data["a"] is True
        assert data["b"] is False
        assert data["c"] is True
        assert data["d"] is False


# ---------------------------------------------------------------------------
# Work items tests
# ---------------------------------------------------------------------------


class TestWorkItems:
    """Test work item CRUD operations."""

    def test_create(self, tmp_project):
        item = work_items.create(tmp_project, "F-0001", "Test feature")
        assert item.id == "F-0001"
        assert item.title == "Test feature"
        assert item.status == "idea"
        assert item.mode == "formal"
        assert item.profile == "guided"

    def test_create_custom(self, tmp_project):
        item = work_items.create(
            tmp_project, "F-0002", "Lean feature",
            mode="lean", profile="autonomous", item_type="bugfix",
        )
        assert item.mode == "lean"
        assert item.profile == "autonomous"
        assert item.type == "bugfix"

    def test_load(self, tmp_project):
        work_items.create(tmp_project, "F-0001", "Test feature")
        loaded = work_items.load(tmp_project, "F-0001")
        assert loaded.id == "F-0001"
        assert loaded.title == "Test feature"

    def test_load_nonexistent(self, tmp_project):
        with pytest.raises(FileNotFoundError):
            work_items.load(tmp_project, "F-9999")

    def test_exists(self, tmp_project):
        assert work_items.exists(tmp_project, "F-0001") is False
        work_items.create(tmp_project, "F-0001", "Test")
        assert work_items.exists(tmp_project, "F-0001") is True

    def test_list_items(self, tmp_project):
        work_items.create(tmp_project, "F-0001", "First")
        work_items.create(tmp_project, "F-0002", "Second")
        items = work_items.list_items(tmp_project)
        assert len(items) == 2
        assert items[0].id == "F-0001"
        assert items[1].id == "F-0002"

    def test_list_by_status(self, tmp_project):
        work_items.create(tmp_project, "F-0001", "First")
        work_items.create(tmp_project, "F-0002", "Second")
        ideas = work_items.list_by_status(tmp_project, "idea")
        assert len(ideas) == 2
        shipped = work_items.list_by_status(tmp_project, "shipped")
        assert len(shipped) == 0

    def test_add_transition(self, tmp_project):
        item = work_items.create(tmp_project, "F-0001", "Test")
        item.add_transition("idea", "queued", by="system")
        assert item.status == "queued"
        assert len(item.transitions) == 1
        assert item.transitions[0]["from"] == "idea"
        assert item.transitions[0]["to"] == "queued"

    def test_has_artifact(self, tmp_project):
        work_items.create(tmp_project, "F-0001", "Test")
        assert work_items.has_artifact(tmp_project, "F-0001", "plan.md") is False
        # Create the artifact
        plan_path = work_items.artifact_path(tmp_project, "F-0001", "plan.md")
        plan_path.write_text("# Plan\n")
        assert work_items.has_artifact(tmp_project, "F-0001", "plan.md") is True

    def test_save_and_reload(self, tmp_project):
        item = work_items.create(tmp_project, "F-0001", "Test")
        item.add_transition("idea", "queued")
        item.add_transition("queued", "planning")
        item.branch = "feat/F-0001"
        work_items.save(tmp_project, item)

        reloaded = work_items.load(tmp_project, "F-0001")
        assert reloaded.status == "planning"
        assert reloaded.branch == "feat/F-0001"
        assert len(reloaded.transitions) == 2


# ---------------------------------------------------------------------------
# Transition enforcement tests
# ---------------------------------------------------------------------------


class TestTransitions:
    """Test the TransitionOrchestrator."""

    def test_forward_transition(self, tmp_project):
        work_items.create(tmp_project, "F-0001", "Test")
        orch = TransitionOrchestrator(tmp_project)
        r = orch.transition("F-0001", "queued")
        assert r.success is True
        assert r.from_state == "idea"
        assert r.to_state == "queued"

    def test_invalid_transition(self, tmp_project):
        work_items.create(tmp_project, "F-0001", "Test")
        orch = TransitionOrchestrator(tmp_project)
        # idea → shipped is not valid
        r = orch.transition("F-0001", "shipped")
        assert r.success is False
        assert "No valid transition" in r.errors[0]

    def test_invalid_state(self, tmp_project):
        work_items.create(tmp_project, "F-0001", "Test")
        orch = TransitionOrchestrator(tmp_project)
        r = orch.transition("F-0001", "nonexistent")
        assert r.success is False
        assert "Invalid state" in r.errors[0]

    def test_artifact_enforcement_formal(self, tmp_project):
        """Formal mode: transition blocked without required artifact."""
        work_items.create(tmp_project, "F-0001", "Test", mode="formal")
        orch = TransitionOrchestrator(tmp_project)
        orch.transition("F-0001", "queued")
        orch.transition("F-0001", "planning")

        # plan_review requires plan.md
        r = orch.transition("F-0001", "plan_review")
        assert r.success is False
        assert any("plan.md" in e for e in r.errors)

    def test_artifact_enforcement_formal_passes(self, tmp_project):
        """Formal mode: transition succeeds with required artifact."""
        work_items.create(tmp_project, "F-0001", "Test", mode="formal")
        orch = TransitionOrchestrator(tmp_project)
        orch.transition("F-0001", "queued")
        orch.transition("F-0001", "planning")

        # Create plan.md
        plan = work_items.artifact_path(tmp_project, "F-0001", "plan.md")
        plan.write_text("# Plan\nImplement the thing.\n")

        r = orch.transition("F-0001", "plan_review")
        assert r.success is True

    def test_skip_blocked_formal(self, tmp_project):
        """Formal mode: skip transitions are blocked."""
        work_items.create(tmp_project, "F-0001", "Test", mode="formal")
        orch = TransitionOrchestrator(tmp_project)
        orch.transition("F-0001", "queued")
        orch.transition("F-0001", "planning")

        r = orch.transition("F-0001", "implementation", force_skip=True)
        assert r.success is False
        assert "not allowed" in r.errors[0].lower() or "skip" in r.errors[0].lower()

    def test_skip_allowed_lean(self, tmp_project):
        """Lean mode: skip transitions are allowed with audit logging."""
        work_items.create(tmp_project, "F-0001", "Test", mode="lean")
        orch = TransitionOrchestrator(tmp_project)
        orch.transition("F-0001", "queued")
        orch.transition("F-0001", "planning")

        r = orch.transition("F-0001", "implementation")
        assert r.success is True
        assert r.skipped is True

        # Check audit log
        item = work_items.load(tmp_project, "F-0001")
        skip_transitions = [t for t in item.transitions if t.get("skipped")]
        assert len(skip_transitions) == 1

    def test_deprecated_from_any_state(self, tmp_project):
        """Deprecated is reachable from any state."""
        work_items.create(tmp_project, "F-0001", "Test")
        orch = TransitionOrchestrator(tmp_project)
        orch.transition("F-0001", "queued")

        r = orch.transition("F-0001", "deprecated", reason="No longer needed")
        assert r.success is True
        item = work_items.load(tmp_project, "F-0001")
        assert item.status == "deprecated"

    def test_regression_transition(self, tmp_project):
        """Regression transitions work and require reason."""
        work_items.create(tmp_project, "F-0001", "Test", mode="lean")
        orch = TransitionOrchestrator(tmp_project)
        orch.transition("F-0001", "queued")
        orch.transition("F-0001", "implementation")  # skip in lean

        r = orch.transition("F-0001", "spec", reason="Need to update spec")
        assert r.success is True

        item = work_items.load(tmp_project, "F-0001")
        assert item.status == "spec"

    def test_nonexistent_feature(self, tmp_project):
        orch = TransitionOrchestrator(tmp_project)
        r = orch.transition("F-9999", "queued")
        assert r.success is False
        assert "not found" in r.errors[0].lower()

    def test_next_state(self, tmp_project):
        work_items.create(tmp_project, "F-0001", "Test")
        orch = TransitionOrchestrator(tmp_project)
        orch.transition("F-0001", "queued")
        orch.transition("F-0001", "planning")
        ns = orch.next_state("F-0001")
        assert ns == "plan_review"

    def test_can_transition(self, tmp_project):
        work_items.create(tmp_project, "F-0001", "Test", mode="formal")
        orch = TransitionOrchestrator(tmp_project)
        orch.transition("F-0001", "queued")
        orch.transition("F-0001", "planning")

        # Can't transition to plan_review without plan.md
        r = orch.can_transition("F-0001", "plan_review")
        assert r.passed is False

        # Create plan.md
        plan = work_items.artifact_path(tmp_project, "F-0001", "plan.md")
        plan.write_text("# Plan\n")
        r = orch.can_transition("F-0001", "plan_review")
        assert r.passed is True

    def test_gate_reviewer_in_result(self, tmp_project):
        """Transition result includes gate reviewer info."""
        work_items.create(tmp_project, "F-0001", "Test", mode="formal", profile="hands_on")
        orch = TransitionOrchestrator(tmp_project)
        orch.transition("F-0001", "queued")
        orch.transition("F-0001", "planning")

        plan = work_items.artifact_path(tmp_project, "F-0001", "plan.md")
        plan.write_text("# Plan\n")
        r = orch.transition("F-0001", "plan_review")
        assert r.success is True

        # plan_review → spec has gate: plan_approved
        review = work_items.artifact_path(tmp_project, "F-0001", "review.md")
        review.write_text("# Review\nApproved.\n")
        r = orch.transition("F-0001", "spec")
        assert r.success is True
        assert r.gate_reviewer == "human"

    def test_role_prompt_emitted(self, tmp_project):
        """Transition to planning emits planner prompt."""
        work_items.create(tmp_project, "F-0001", "Test")
        orch = TransitionOrchestrator(tmp_project)
        orch.transition("F-0001", "queued")
        r = orch.transition("F-0001", "planning")
        assert r.success is True
        assert r.prompt is not None
        assert "Planner" in r.prompt

    def test_mode_artifact_enforcement(self, tmp_project):
        """Formal mode requires additional artifacts beyond transition requires."""
        work_items.create(tmp_project, "F-0001", "Test", mode="formal")
        orch = TransitionOrchestrator(tmp_project)
        orch.transition("F-0001", "queued")
        orch.transition("F-0001", "planning")

        # Create plan.md for plan_review
        plan = work_items.artifact_path(tmp_project, "F-0001", "plan.md")
        plan.write_text("# Plan\n")
        orch.transition("F-0001", "plan_review")

        # Create review.md for spec
        review = work_items.artifact_path(tmp_project, "F-0001", "review.md")
        review.write_text("# Review\n")
        orch.transition("F-0001", "spec")

        # spec → implementation requires spec.md (from transition)
        # AND plan.md, spec.md (from formal mode required_artifacts)
        spec = work_items.artifact_path(tmp_project, "F-0001", "spec.md")
        spec.write_text("# Spec\n")

        r = orch.transition("F-0001", "implementation")
        assert r.success is True  # Both plan.md and spec.md exist


# ---------------------------------------------------------------------------
# Preconditions tests
# ---------------------------------------------------------------------------


class TestPreconditions:
    """Test artifact precondition checking."""

    def test_file_artifact_missing(self, tmp_project):
        config = load_config(tmp_project)
        work_items.create(tmp_project, "F-0001", "Test")
        r = check_artifact(tmp_project, "F-0001", "plan.md", config)
        assert r.passed is False

    def test_file_artifact_exists(self, tmp_project):
        config = load_config(tmp_project)
        work_items.create(tmp_project, "F-0001", "Test")
        plan = work_items.artifact_path(tmp_project, "F-0001", "plan.md")
        plan.write_text("# Plan\n")
        r = check_artifact(tmp_project, "F-0001", "plan.md", config)
        assert r.passed is True

    def test_file_artifact_empty(self, tmp_project):
        """Empty files don't count as present artifacts."""
        config = load_config(tmp_project)
        work_items.create(tmp_project, "F-0001", "Test")
        plan = work_items.artifact_path(tmp_project, "F-0001", "plan.md")
        plan.write_text("")
        r = check_artifact(tmp_project, "F-0001", "plan.md", config)
        assert r.passed is False

    def test_check_command_passes(self, tmp_project):
        """Custom check command that succeeds."""
        config = load_config(tmp_project)
        work_items.create(tmp_project, "F-0001", "Test")
        r = check_artifact(tmp_project, "F-0001", "docs_updated", config)
        assert r.passed is True  # check: "true" always passes

    def test_check_command_fails(self, tmp_project):
        """Custom check command that fails."""
        config = load_config(tmp_project)
        work_items.create(tmp_project, "F-0001", "Test")
        r = check_artifact(tmp_project, "F-0001", "tests_exist", config)
        assert r.passed is False  # check: "test -f spec.md" fails when spec.md doesn't exist

    def test_unknown_artifact_default(self, tmp_project):
        """Unknown artifacts fall back to checking in work dir."""
        config = load_config(tmp_project)
        work_items.create(tmp_project, "F-0001", "Test")
        r = check_artifact(tmp_project, "F-0001", "unknown.txt", config)
        assert r.passed is False

    def test_check_result_merge(self):
        r1 = CheckResult.ok(["warning1"])
        r2 = CheckResult.fail(["error1"], ["warning2"])
        merged = r1.merge(r2)
        assert merged.passed is False
        assert "error1" in merged.errors
        assert "warning1" in merged.warnings
        assert "warning2" in merged.warnings


# ---------------------------------------------------------------------------
# CLI workflow command tests
# ---------------------------------------------------------------------------


class TestWorkflowCLI:
    """Test the workflow CLI entry point."""

    def test_help(self, capsys):
        rc = workflow_main([])
        assert rc == 0
        out = capsys.readouterr().out
        assert "start" in out
        assert "transition" in out

    def test_start(self, tmp_project, capsys):
        os.chdir(tmp_project)
        rc = workflow_main(["start", "F-0001", "CLI test feature", "--mode", "formal", "--profile", "guided"])
        assert rc == 0
        out = capsys.readouterr().out
        assert "F-0001" in out
        assert work_items.exists(tmp_project, "F-0001")

    def test_start_duplicate(self, tmp_project, capsys):
        os.chdir(tmp_project)
        workflow_main(["start", "F-0001", "First"])
        rc = workflow_main(["start", "F-0001", "Second"])
        assert rc == 1

    def test_status_empty(self, tmp_project, capsys):
        os.chdir(tmp_project)
        rc = workflow_main(["status"])
        assert rc == 0

    def test_status_with_items(self, tmp_project, capsys):
        os.chdir(tmp_project)
        workflow_main(["start", "F-0001", "Test"])
        rc = workflow_main(["status"])
        assert rc == 0
        out = capsys.readouterr().out
        assert "F-0001" in out

    def test_transition_happy_path(self, tmp_project, capsys):
        os.chdir(tmp_project)
        workflow_main(["start", "F-0001", "Test"])
        # F-0001 is now in "planning" state
        # Create plan.md
        plan = work_items.artifact_path(tmp_project, "F-0001", "plan.md")
        plan.write_text("# Plan\n")
        rc = workflow_main(["transition", "F-0001", "plan_review"])
        assert rc == 0

    def test_transition_blocked(self, tmp_project, capsys):
        os.chdir(tmp_project)
        workflow_main(["start", "F-0001", "Test"])
        # Try plan_review without plan.md
        rc = workflow_main(["transition", "F-0001", "plan_review"])
        assert rc == 1

    def test_check(self, tmp_project, capsys):
        os.chdir(tmp_project)
        workflow_main(["start", "F-0001", "Test"])
        rc = workflow_main(["check", "F-0001"])
        # In planning state, no specific artifacts required (transition to plan_review needs plan.md)
        assert rc == 0

    def test_info(self, tmp_project, capsys):
        os.chdir(tmp_project)
        workflow_main(["start", "F-0001", "Test feature"])
        rc = workflow_main(["info", "F-0001"])
        assert rc == 0
        out = capsys.readouterr().out
        assert "Test feature" in out
        assert "planning" in out

    def test_verify(self, tmp_project, capsys):
        os.chdir(tmp_project)
        workflow_main(["start", "F-0001", "Test"])
        rc = workflow_main(["verify", "F-0001"])
        assert rc == 0
        # Check verification.json was created
        vpath = work_items.artifact_path(tmp_project, "F-0001", "verification.json")
        assert vpath.exists()
        data = json.loads(vpath.read_text())
        assert data["passed"] is True

    def test_ship_wrong_state(self, tmp_project, capsys):
        os.chdir(tmp_project)
        workflow_main(["start", "F-0001", "Test"])
        rc = workflow_main(["ship", "F-0001"])
        assert rc == 1  # Not in ready_to_ship

    def test_next_empty(self, tmp_project, capsys):
        os.chdir(tmp_project)
        rc = workflow_main(["next"])
        assert rc == 0

    def test_unknown_command(self, tmp_project, capsys):
        os.chdir(tmp_project)
        rc = workflow_main(["nonexistent"])
        assert rc == 1


# ---------------------------------------------------------------------------
# Full lifecycle test
# ---------------------------------------------------------------------------


class TestFullLifecycle:
    """Test a complete feature lifecycle from idea to shipped."""

    def test_lean_lifecycle(self, tmp_project):
        """Walk a lean feature through: start → skip to implementation → verify → ship."""
        orch = TransitionOrchestrator(tmp_project)

        # Start
        work_items.create(tmp_project, "F-0001", "Quick fix", mode="lean", profile="autonomous")
        orch.transition("F-0001", "queued")

        # Skip to implementation (lean allows)
        r = orch.transition("F-0001", "implementation")
        assert r.success is True
        assert r.skipped is True

        # Create spec.md for tests_exist check
        spec = work_items.artifact_path(tmp_project, "F-0001", "spec.md")
        spec.write_text("# Spec\n")

        # Verify
        vpath = work_items.artifact_path(tmp_project, "F-0001", "verification.json")
        vpath.write_text(json.dumps({"passed": True}))
        r = orch.transition("F-0001", "verification")
        assert r.success is True

        # Docs
        r = orch.transition("F-0001", "docs")
        assert r.success is True

        # Ready to ship
        r = orch.transition("F-0001", "ready_to_ship")
        assert r.success is True

        # Ship
        r = orch.transition("F-0001", "shipped")
        assert r.success is True

        item = work_items.load(tmp_project, "F-0001")
        assert item.status == "shipped"
        # Verify transition log
        assert len(item.transitions) >= 6

    def test_formal_lifecycle(self, tmp_project):
        """Walk a formal feature through all states with required artifacts."""
        orch = TransitionOrchestrator(tmp_project)

        # Start
        work_items.create(tmp_project, "F-0001", "Full feature", mode="formal", profile="hands_on")
        orch.transition("F-0001", "queued")
        orch.transition("F-0001", "planning")

        # Plan
        plan = work_items.artifact_path(tmp_project, "F-0001", "plan.md")
        plan.write_text("# Plan\nStep 1: Do the thing.\n")
        r = orch.transition("F-0001", "plan_review")
        assert r.success is True

        # Review
        review = work_items.artifact_path(tmp_project, "F-0001", "review.md")
        review.write_text("# Review\nLGTM.\n")
        r = orch.transition("F-0001", "spec")
        assert r.success is True

        # Spec
        spec = work_items.artifact_path(tmp_project, "F-0001", "spec.md")
        spec.write_text("# Spec\nAC-1: It works.\n")
        r = orch.transition("F-0001", "implementation")
        assert r.success is True

        # Implementation → verification
        r = orch.transition("F-0001", "verification")
        assert r.success is True

        # Verification → docs
        vpath = work_items.artifact_path(tmp_project, "F-0001", "verification.json")
        vpath.write_text(json.dumps({"passed": True}))
        r = orch.transition("F-0001", "docs")
        assert r.success is True

        # Docs → ready_to_ship
        r = orch.transition("F-0001", "ready_to_ship")
        assert r.success is True

        # Ready to ship → shipped
        r = orch.transition("F-0001", "shipped")
        assert r.success is True

        item = work_items.load(tmp_project, "F-0001")
        assert item.status == "shipped"
