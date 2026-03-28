#!/usr/bin/env python3
"""
Tests for the workflow definition YAML loader (F-036).

Covers:
- Loading the real state_machine_af.yaml
- Dataclass parsing (modes, profiles, artifacts, verification, docs_policy)
- State mapping completeness
- Consistency validation (positive and negative cases)
- Graceful degradation (missing file, malformed YAML)
- Module-level caching
"""
import sys
import tempfile
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "auto"))

from auto.workflow import (
    ArtifactDef,
    DocsPolicyConfig,
    ModeConfig,
    ProfileConfig,
    Transition,
    VerificationConfig,
    VerifyCommand,
    WorkflowConfig,
    WorkflowDefinition,
    clear_cache,
    get_workflow,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).parent.parent


@pytest.fixture(autouse=True)
def _clear_workflow_cache():
    """Clear the module-level cache before each test."""
    clear_cache()
    yield
    clear_cache()


@pytest.fixture
def wf() -> WorkflowDefinition:
    """Load the real workflow definition from the repo."""
    return get_workflow(REPO_ROOT)


# ---------------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------------

class TestLoading:

    def test_load_from_real_file(self, wf: WorkflowDefinition):
        assert wf.version == 1
        assert wf.engine == "v1"
        assert len(wf.workflow.states) >= 10
        assert len(wf.workflow.transitions) > 0

    def test_load_missing_file(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / ".agentic").mkdir()
            with pytest.raises(FileNotFoundError):
                get_workflow(root)

    def test_load_malformed_yaml(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / ".agentic").mkdir()
            yaml_path = root / ".agentic" / "state_machine_af.yaml"
            yaml_path.write_text("not: [valid: yaml: structure")
            # This should raise during YAML parsing
            with pytest.raises(Exception):
                WorkflowDefinition.load(yaml_path)

    def test_load_empty_yaml(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            yaml_path = root / "empty.yaml"
            yaml_path.write_text("---\n{}")
            wf = WorkflowDefinition.load(yaml_path)
            assert wf.version == 1
            assert wf.engine == "v1"
            assert wf.workflow.states == []
            assert wf.modes == {}


# ---------------------------------------------------------------------------
# Caching
# ---------------------------------------------------------------------------

class TestCaching:

    def test_same_instance_returned(self):
        wf1 = get_workflow(REPO_ROOT)
        wf2 = get_workflow(REPO_ROOT)
        assert wf1 is wf2

    def test_clear_cache_forces_reload(self):
        wf1 = get_workflow(REPO_ROOT)
        clear_cache()
        wf2 = get_workflow(REPO_ROOT)
        assert wf1 is not wf2
        assert wf1.version == wf2.version


# ---------------------------------------------------------------------------
# Workflow states and transitions
# ---------------------------------------------------------------------------

class TestWorkflowConfig:

    def test_states_include_core(self, wf: WorkflowDefinition):
        states = wf.workflow.states
        for expected in ["planning", "spec", "implementation", "verification",
                         "docs", "ready_to_ship", "shipped"]:
            assert expected in states, f"Missing state: {expected}"

    def test_forward_transitions_exist(self, wf: WorkflowDefinition):
        forward = [t for t in wf.workflow.transitions if t.type != "regression"]
        assert len(forward) >= 8

    def test_regression_transitions_exist(self, wf: WorkflowDefinition):
        regressions = [t for t in wf.workflow.transitions if t.type == "regression"]
        assert len(regressions) >= 4

    def test_transition_states_in_states_list(self, wf: WorkflowDefinition):
        valid_states = set(wf.workflow.states)
        for t in wf.workflow.transitions:
            assert t.from_state in valid_states, \
                f"Transition from unknown state: {t.from_state}"
            assert t.to_state in valid_states, \
                f"Transition to unknown state: {t.to_state}"

    def test_transition_has_requires(self, wf: WorkflowDefinition):
        """At least some transitions have artifact requirements."""
        transitions_with_requires = [
            t for t in wf.workflow.transitions if t.requires
        ]
        assert len(transitions_with_requires) >= 3

    def test_transition_from_dict(self):
        t = Transition.from_dict({
            "from": "a", "to": "b", "requires": ["x.md"], "gate": "g1"
        })
        assert t.from_state == "a"
        assert t.to_state == "b"
        assert t.requires == ["x.md"]
        assert t.gate == "g1"
        assert t.type == "forward"


# ---------------------------------------------------------------------------
# Modes
# ---------------------------------------------------------------------------

class TestModes:

    def test_formal_mode(self, wf: WorkflowDefinition):
        formal = wf.get_mode("formal")
        assert formal.escape_hatches is False
        assert formal.skip_transitions == []
        assert "plan_review" in formal.required_artifacts
        assert "plan.md" in formal.required_artifacts["plan_review"]

    def test_lean_mode(self, wf: WorkflowDefinition):
        lean = wf.get_mode("lean")
        assert lean.escape_hatches is True
        assert len(lean.skip_transitions) >= 3

    def test_unknown_mode_raises(self, wf: WorkflowDefinition):
        with pytest.raises(KeyError):
            wf.get_mode("nonexistent")

    def test_formal_required_artifacts(self, wf: WorkflowDefinition):
        formal = wf.get_mode("formal")
        assert "spec.md" in formal.required_artifacts.get("implementation", [])


# ---------------------------------------------------------------------------
# Profiles
# ---------------------------------------------------------------------------

class TestProfiles:

    def test_hands_on_all_human(self, wf: WorkflowDefinition):
        profile = wf.get_profile("hands_on")
        assert all(v == "human" for v in profile.gates.values())

    def test_autonomous_mostly_ai(self, wf: WorkflowDefinition):
        profile = wf.get_profile("autonomous")
        assert profile.gates.get("plan_approved") == "ai"
        assert profile.gates.get("code_review") == "ai"
        assert profile.gates.get("merge") == "human"

    def test_guided_mix(self, wf: WorkflowDefinition):
        profile = wf.get_profile("guided")
        assert profile.gates.get("plan_approved") == "human"
        assert profile.gates.get("code_review") == "ai"

    def test_unknown_profile_raises(self, wf: WorkflowDefinition):
        with pytest.raises(KeyError):
            wf.get_profile("nonexistent")

    def test_profile_has_description(self, wf: WorkflowDefinition):
        for name, profile in wf.profiles.items():
            assert profile.description, f"Profile {name} missing description"


# ---------------------------------------------------------------------------
# Artifacts
# ---------------------------------------------------------------------------

class TestArtifacts:

    def test_plan_md(self, wf: WorkflowDefinition):
        art = wf.get_artifact("plan.md")
        assert art is not None
        assert art.location is not None
        assert "{work_dir}" in art.location

    def test_spec_md(self, wf: WorkflowDefinition):
        art = wf.get_artifact("spec.md")
        assert art is not None

    def test_tests_exist_has_check(self, wf: WorkflowDefinition):
        art = wf.get_artifact("tests_exist")
        assert art is not None
        assert art.check is not None
        assert "grep" in art.check

    def test_unknown_artifact_returns_none(self, wf: WorkflowDefinition):
        assert wf.get_artifact("nonexistent") is None

    def test_all_mode_artifacts_defined(self, wf: WorkflowDefinition):
        """Every artifact referenced in modes.required_artifacts exists."""
        for mode_name, mode in wf.modes.items():
            for state, artifacts in mode.required_artifacts.items():
                for artifact_name in artifacts:
                    assert wf.get_artifact(artifact_name) is not None, \
                        f"Mode {mode_name}/{state} references undefined artifact: {artifact_name}"


# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------

class TestVerification:

    def test_commands_parsed(self, wf: WorkflowDefinition):
        assert len(wf.verification.commands) >= 2

    def test_command_fields(self, wf: WorkflowDefinition):
        cmd = wf.verification.commands[0]
        assert cmd.name
        assert cmd.run
        assert cmd.timeout > 0

    def test_tests_command(self, wf: WorkflowDefinition):
        names = {c.name for c in wf.verification.commands}
        assert "tests" in names


# ---------------------------------------------------------------------------
# Docs policy
# ---------------------------------------------------------------------------

class TestDocsPolicy:

    def test_fields_parsed(self, wf: WorkflowDefinition):
        assert wf.docs_policy.require_update_on_code_change is True
        assert wf.docs_policy.stale_days == 30
        assert len(wf.docs_policy.docs_paths) >= 1


# ---------------------------------------------------------------------------
# State mapping
# ---------------------------------------------------------------------------

class TestStateMapping:

    def test_covers_all_v1_states(self, wf: WorkflowDefinition):
        """Every v1 FeatureState value has a mapping entry."""
        from auto.state_machine import FeatureState
        for state in FeatureState:
            assert state.value in wf.state_mapping, \
                f"v1 state '{state.value}' missing from state_mapping"

    def test_maps_to_valid_v2_states(self, wf: WorkflowDefinition):
        """Every mapped v2 state exists in the workflow states list."""
        v2_states = set(wf.workflow.states)
        for v1_name, v2_name in wf.state_mapping.items():
            assert v2_name in v2_states, \
                f"state_mapping[{v1_name}] = {v2_name} not in v2 states"


# ---------------------------------------------------------------------------
# Consistency validation
# ---------------------------------------------------------------------------

class TestConsistencyValidation:

    def test_real_tables_consistent(self, wf: WorkflowDefinition):
        """Real v1 tables should be consistent with the YAML."""
        from auto.state_machine import FORWARD_TRANSITIONS, REGRESSION_TRANSITIONS
        errors = wf.validate_consistency(FORWARD_TRANSITIONS, REGRESSION_TRANSITIONS)
        assert errors == [], f"Consistency errors: {errors}"

    def test_detects_missing_state_mapping(self, wf: WorkflowDefinition):
        """Removing a state_mapping entry should trigger an error."""
        import copy
        wf2 = copy.copy(wf)
        wf2.state_mapping = {
            k: v for k, v in wf.state_mapping.items() if k != "planned"
        }
        from auto.state_machine import FORWARD_TRANSITIONS, REGRESSION_TRANSITIONS
        errors = wf2.validate_consistency(FORWARD_TRANSITIONS, REGRESSION_TRANSITIONS)
        assert any("planned" in e and "state_mapping" in e for e in errors)

    def test_detects_unreachable_transition(self, wf: WorkflowDefinition):
        """A fake backward forward transition should be caught."""
        from auto.state_machine import FeatureState, FORWARD_TRANSITIONS, REGRESSION_TRANSITIONS
        wrong = FORWARD_TRANSITIONS | {(FeatureState.SHIPPED, FeatureState.PLANNED)}
        errors = wf.validate_consistency(wrong, REGRESSION_TRANSITIONS)
        assert any("shipped->planned" in e for e in errors)

    def test_self_mapping_transitions_silently_skipped(self, wf: WorkflowDefinition):
        """v1 transitions where both states map to same v2 state should not error."""
        from auto.state_machine import FeatureState, FORWARD_TRANSITIONS, REGRESSION_TRANSITIONS
        errors = wf.validate_consistency(FORWARD_TRANSITIONS, REGRESSION_TRANSITIONS)
        # specced->criteria_set both map to 'spec' — should not appear in errors
        self_map_errors = [e for e in errors if "specced->criteria_set" in e]
        assert self_map_errors == [], f"Self-mapping should be silent: {self_map_errors}"

    def test_reachability_through_intermediate(self, wf: WorkflowDefinition):
        """v1 planned->specced maps to planning->spec via plan_review intermediate."""
        from auto.state_machine import FeatureState, FORWARD_TRANSITIONS, REGRESSION_TRANSITIONS
        errors = wf.validate_consistency(FORWARD_TRANSITIONS, REGRESSION_TRANSITIONS)
        # planned->specced maps to planning->spec, reachable via plan_review
        reach_errors = [e for e in errors if "planned->specced" in e]
        assert reach_errors == [], f"Should be reachable via plan_review: {reach_errors}"
