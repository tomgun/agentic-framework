"""
workflow.py -- YAML loader for state_machine_af.yaml (F-036).

Loads the workflow definition file into typed dataclasses, providing
structured access to modes, profiles, artifacts, verification commands,
docs policy, and state mapping.  Also provides consistency validation
between the YAML transitions and the Python hardcoded transition tables.

Usage:
    from pathlib import Path
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
    from auto.workflow import get_workflow

    wf = get_workflow(Path("."))
    print(wf.modes["formal"].escape_hatches)       # False
    print(wf.profiles["autonomous"].gates)          # {'plan_approved': 'ai', ...}
    print(wf.artifacts["plan.md"].location)         # '{work_dir}/plan.md'
    print(wf.verification.commands[0].run)           # 'make test'
"""
from __future__ import annotations

import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional

_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))


# ---------------------------------------------------------------------------
# YAML loading — requires PyYAML (same pattern as contracts.py)
# ---------------------------------------------------------------------------

def _load_yaml(path: Path) -> dict[str, Any]:
    """Load a YAML file. Requires PyYAML."""
    try:
        import yaml
    except ImportError:
        raise RuntimeError(
            "PyYAML is required for workflow definition parsing. "
            "Install with: pip install pyyaml"
        )
    with open(path, "r") as f:
        data = yaml.safe_load(f)
    if not isinstance(data, dict):
        raise ValueError(f"Workflow file must be a YAML mapping: {path}")
    return data


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class Transition:
    """A single workflow transition."""
    from_state: str
    to_state: str
    requires: list[str] = field(default_factory=list)
    gate: Optional[str] = None
    type: str = "forward"  # "forward" or "regression"

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> Transition:
        return cls(
            from_state=d["from"],
            to_state=d["to"],
            requires=d.get("requires", []),
            gate=d.get("gate"),
            type=d.get("type", "forward"),
        )


@dataclass
class WorkflowConfig:
    """Workflow states and transitions."""
    states: list[str]
    transitions: list[Transition]

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> WorkflowConfig:
        return cls(
            states=d.get("states", []),
            transitions=[Transition.from_dict(t) for t in d.get("transitions", [])],
        )


@dataclass
class ModeConfig:
    """Configuration for a workflow mode (formal/lean)."""
    escape_hatches: bool = False
    skip_transitions: list[tuple[str, str]] = field(default_factory=list)
    required_artifacts: dict[str, list[str]] = field(default_factory=dict)

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> ModeConfig:
        skips = [
            (s["from"], s["to"]) for s in d.get("skip_transitions", [])
        ]
        return cls(
            escape_hatches=d.get("escape_hatches", False),
            skip_transitions=skips,
            required_artifacts=d.get("required_artifacts", {}),
        )


@dataclass
class ProfileConfig:
    """Configuration for a review profile (hands_on/guided/autonomous)."""
    description: str = ""
    gates: dict[str, str] = field(default_factory=dict)

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> ProfileConfig:
        return cls(
            description=d.get("description", ""),
            gates=d.get("gates", {}),
        )


@dataclass
class VerifyCommand:
    """A single verification command (test/lint)."""
    name: str
    run: str
    timeout: int = 120

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> VerifyCommand:
        return cls(
            name=d["name"],
            run=d["run"],
            timeout=d.get("timeout", 120),
        )


@dataclass
class VerificationConfig:
    """Verification commands configuration."""
    commands: list[VerifyCommand] = field(default_factory=list)

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> VerificationConfig:
        return cls(
            commands=[VerifyCommand.from_dict(c) for c in d.get("commands", [])],
        )


@dataclass
class DocsPolicyConfig:
    """Documentation policy configuration."""
    require_update_on_code_change: bool = True
    docs_paths: list[str] = field(default_factory=list)
    stale_days: int = 30

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> DocsPolicyConfig:
        return cls(
            require_update_on_code_change=d.get("require_update_on_code_change", True),
            docs_paths=d.get("docs_paths", []),
            stale_days=d.get("stale_days", 30),
        )


@dataclass
class ArtifactDef:
    """Definition of a workflow artifact."""
    description: str
    location: Optional[str] = None
    check: Optional[str] = None

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> ArtifactDef:
        return cls(
            description=d.get("description", ""),
            location=d.get("location"),
            check=d.get("check"),
        )


# ---------------------------------------------------------------------------
# Main workflow definition
# ---------------------------------------------------------------------------

@dataclass
class WorkflowDefinition:
    """Typed representation of state_machine_af.yaml."""
    version: int
    engine: str
    workflow: WorkflowConfig
    modes: dict[str, ModeConfig]
    profiles: dict[str, ProfileConfig]
    verification: VerificationConfig
    docs_policy: DocsPolicyConfig
    artifacts: dict[str, ArtifactDef]
    state_mapping: dict[str, str]  # v1_name -> v2_name

    @classmethod
    def load(cls, yaml_path: Path) -> WorkflowDefinition:
        """Load and parse state_machine_af.yaml into a WorkflowDefinition."""
        data = _load_yaml(yaml_path)
        return cls(
            version=data.get("version", 1),
            engine=data.get("engine", "v1"),
            workflow=WorkflowConfig.from_dict(data.get("workflow", {})),
            modes={
                name: ModeConfig.from_dict(conf)
                for name, conf in data.get("modes", {}).items()
            },
            profiles={
                name: ProfileConfig.from_dict(conf)
                for name, conf in data.get("profiles", {}).items()
            },
            verification=VerificationConfig.from_dict(
                data.get("verification", {})
            ),
            docs_policy=DocsPolicyConfig.from_dict(
                data.get("docs_policy", {})
            ),
            artifacts={
                name: ArtifactDef.from_dict(conf)
                for name, conf in data.get("artifacts", {}).items()
            },
            state_mapping=data.get("state_mapping", {}),
        )

    def get_mode(self, name: str) -> ModeConfig:
        """Get mode config by name. Raises KeyError if unknown."""
        return self.modes[name]

    def get_profile(self, name: str) -> ProfileConfig:
        """Get profile config by name. Raises KeyError if unknown."""
        return self.profiles[name]

    def get_artifact(self, name: str) -> Optional[ArtifactDef]:
        """Get artifact definition by name, or None."""
        return self.artifacts.get(name)

    # -- Helpers -------------------------------------------------------------

    @staticmethod
    def _is_reachable(
        from_state: str, to_state: str, transitions: set[tuple[str, str]],
        max_depth: int = 5,
    ) -> bool:
        """Check if to_state is reachable from from_state via forward transitions."""
        visited: set[str] = set()
        frontier = {from_state}
        for _ in range(max_depth):
            next_frontier: set[str] = set()
            for s in frontier:
                if s in visited:
                    continue
                visited.add(s)
                for f, t in transitions:
                    if f == s:
                        if t == to_state:
                            return True
                        next_frontier.add(t)
            frontier = next_frontier - visited
            if not frontier:
                break
        return False

    # -- Consistency validation ----------------------------------------------

    def validate_consistency(
        self,
        v1_forward: set[tuple[Any, Any]],
        v1_regression: set[tuple[Any, Any]],
    ) -> list[str]:
        """Cross-check YAML transitions against Python hardcoded tables.

        Uses state_mapping (v1->v2) to translate Python's v1 state pairs
        into v2 state pairs and checks coverage in both directions.

        The mapping is many-to-one (e.g., specced + criteria_set -> spec),
        so multiple v1 transitions may map to a single v2 transition.
        This is expected and not reported as an error.

        Returns a list of discrepancy messages (empty = consistent).
        """
        errors: list[str] = []

        # Build reverse mapping: v2 -> set of v1 names
        v2_to_v1: dict[str, set[str]] = {}
        for v1_name, v2_name in self.state_mapping.items():
            v2_to_v1.setdefault(v2_name, set()).add(v1_name)

        # Collect v2 transitions by type
        yaml_forward = {
            (t.from_state, t.to_state) for t in self.workflow.transitions
            if t.type != "regression"
        }
        yaml_regression = {
            (t.from_state, t.to_state) for t in self.workflow.transitions
            if t.type == "regression"
        }

        # Direction 1: every v1 forward transition should map to a v2 transition
        for from_v1, to_v1 in v1_forward:
            from_v1_str = from_v1.value if hasattr(from_v1, "value") else str(from_v1)
            to_v1_str = to_v1.value if hasattr(to_v1, "value") else str(to_v1)
            from_v2 = self.state_mapping.get(from_v1_str)
            to_v2 = self.state_mapping.get(to_v1_str)
            if from_v2 is None:
                errors.append(
                    f"v1 state '{from_v1_str}' has no entry in state_mapping"
                )
                continue
            if to_v2 is None:
                errors.append(
                    f"v1 state '{to_v1_str}' has no entry in state_mapping"
                )
                continue
            if from_v2 == to_v2:
                continue  # Many-to-one: both v1 states map to same v2 state
            if (from_v2, to_v2) not in yaml_forward:
                # Check reachability: v2 may route through intermediate states
                if not self._is_reachable(from_v2, to_v2, yaml_forward):
                    errors.append(
                        f"v1 forward transition {from_v1_str}->{to_v1_str} "
                        f"maps to {from_v2}->{to_v2} which is not reachable in YAML"
                    )

        # Direction 1b: every v1 regression transition should map to a v2 regression
        for from_v1, to_v1 in v1_regression:
            from_v1_str = from_v1.value if hasattr(from_v1, "value") else str(from_v1)
            to_v1_str = to_v1.value if hasattr(to_v1, "value") else str(to_v1)
            from_v2 = self.state_mapping.get(from_v1_str)
            to_v2 = self.state_mapping.get(to_v1_str)
            if from_v2 is None or to_v2 is None:
                continue  # Already caught above
            if from_v2 == to_v2:
                continue  # Many-to-one: both v1 states map to same v2 state
            if (from_v2, to_v2) not in yaml_regression:
                errors.append(
                    f"v1 regression {from_v1_str}->{to_v1_str} "
                    f"maps to {from_v2}->{to_v2} which is not in YAML regressions"
                )

        # Direction 2: every v2 forward transition should have at least one v1 match
        v2_states = set(self.workflow.states)
        # Precompute v1 forward transition strings once (avoid O(n²) rebuild)
        v1_forward_strs: set[tuple[str, str]] = {
            (a.value if hasattr(a, "value") else str(a),
             b.value if hasattr(b, "value") else str(b))
            for a, b in v1_forward
        }
        for from_v2, to_v2 in yaml_forward:
            if from_v2 not in v2_states:
                errors.append(
                    f"YAML transition references unknown state '{from_v2}'"
                )
            if to_v2 not in v2_states:
                errors.append(
                    f"YAML transition references unknown state '{to_v2}'"
                )
            # Check that at least one v1 transition maps here
            from_v1_set = v2_to_v1.get(from_v2, set())
            to_v1_set = v2_to_v1.get(to_v2, set())
            if not from_v1_set or not to_v1_set:
                # v2 states with no v1 equivalent (e.g., idea, queued) — expected
                continue
            has_v1_match = any(
                (f, t) in v1_forward_strs
                for f in from_v1_set
                for t in to_v1_set
            )
            if not has_v1_match:
                errors.append(
                    f"YAML forward transition {from_v2}->{to_v2} "
                    f"has no matching v1 transition"
                )

        return errors


# ---------------------------------------------------------------------------
# Module-level cached loader
# ---------------------------------------------------------------------------

_workflow_cache: dict[str, WorkflowDefinition] = {}


def get_workflow(project_root: Optional[Path] = None) -> WorkflowDefinition:
    """Load the workflow definition, with per-project caching.

    Raises FileNotFoundError if state_machine_af.yaml does not exist.
    Raises RuntimeError if PyYAML is not installed.
    """
    if project_root is None:
        project_root = Path.cwd()
    key = str(project_root.resolve())
    if key not in _workflow_cache:
        from paths import get_paths
        paths = get_paths(project_root)
        yaml_path = paths.workflow_file
        if not yaml_path.exists():
            raise FileNotFoundError(
                f"Workflow definition not found: {yaml_path}"
            )
        _workflow_cache[key] = WorkflowDefinition.load(yaml_path)
    return _workflow_cache[key]


def clear_cache() -> None:
    """Clear the workflow cache (useful for tests)."""
    _workflow_cache.clear()
