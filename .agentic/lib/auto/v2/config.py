"""
config.py — Load and validate state_machine_af.yaml.

Single source of truth for workflow configuration.
"""
from __future__ import annotations

import json
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional

# ---------------------------------------------------------------------------
# YAML loading — use PyYAML if available, fall back to basic parser
# ---------------------------------------------------------------------------


def _load_yaml(path: Path) -> dict:
    """Load a YAML file, trying PyYAML first, then a minimal fallback."""
    text = path.read_text()
    try:
        import yaml
        return yaml.safe_load(text)
    except ImportError:
        return _basic_yaml_parse(text)


def _basic_yaml_parse(text: str) -> dict:
    """Minimal YAML-subset parser for state_machine_af.yaml.

    Handles: scalars, lists (- item), nested dicts, inline dicts ({k: v}),
    inline lists [a, b], comments (#). Enough for our config file.
    NOT a general-purpose YAML parser.
    """
    import re

    lines = text.split("\n")
    result: dict = {}
    stack: list[tuple[int, dict | list]] = [(-1, result)]

    i = 0
    while i < len(lines):
        raw = lines[i]
        i += 1

        # Strip comments (but not inside quotes)
        stripped = raw.split("#")[0].rstrip() if "#" in raw and '"' not in raw.split("#")[0] else raw.rstrip()
        if not stripped or stripped.lstrip().startswith("#"):
            continue

        indent = len(stripped) - len(stripped.lstrip())
        content = stripped.lstrip()

        # Pop stack to correct indent level
        while len(stack) > 1 and stack[-1][0] >= indent:
            stack.pop()

        parent_indent, parent = stack[-1]

        # List item: - value or - {inline}
        if content.startswith("- "):
            item_content = content[2:].strip()
            if isinstance(parent, list):
                target_list = parent
            elif isinstance(parent, dict):
                # Find last key added to parent — that should be the list
                last_key = list(parent.keys())[-1] if parent else None
                if last_key and isinstance(parent.get(last_key), list):
                    target_list = parent[last_key]
                else:
                    target_list = []
                    if last_key:
                        parent[last_key] = target_list
            else:
                continue

            if item_content.startswith("{") and item_content.endswith("}"):
                target_list.append(_parse_inline_dict(item_content))
            else:
                target_list.append(_parse_scalar(item_content))
            continue

        # Key: value
        if ":" in content:
            colon_pos = content.index(":")
            key = content[:colon_pos].strip()
            value_part = content[colon_pos + 1:].strip()

            if isinstance(parent, dict):
                if not value_part:
                    # Could be a dict or list — peek at next line
                    next_meaningful = _peek_next(lines, i)
                    if next_meaningful and next_meaningful.lstrip().startswith("- "):
                        parent[key] = []
                        stack.append((indent, parent[key]))
                    else:
                        parent[key] = {}
                        stack.append((indent, parent[key]))
                elif value_part.startswith("[") and value_part.endswith("]"):
                    parent[key] = _parse_inline_list(value_part)
                elif value_part.startswith("{") and value_part.endswith("}"):
                    parent[key] = _parse_inline_dict(value_part)
                else:
                    parent[key] = _parse_scalar(value_part)

    return result


def _peek_next(lines: list[str], start: int) -> Optional[str]:
    """Return the next non-empty, non-comment line."""
    for j in range(start, len(lines)):
        s = lines[j].strip()
        if s and not s.startswith("#"):
            return lines[j]
    return None


def _parse_scalar(s: str) -> Any:
    """Parse a YAML scalar value."""
    if not s:
        return None
    # Strip quotes
    if (s.startswith('"') and s.endswith('"')) or (s.startswith("'") and s.endswith("'")):
        return s[1:-1]
    # Booleans
    if s.lower() in ("true", "yes"):
        return True
    if s.lower() in ("false", "no"):
        return False
    # Null
    if s.lower() in ("null", "~"):
        return None
    # Numbers
    try:
        return int(s)
    except ValueError:
        try:
            return float(s)
        except ValueError:
            return s


def _parse_inline_list(s: str) -> list:
    """Parse [a, b, c] → list."""
    inner = s[1:-1].strip()
    if not inner:
        return []
    return [_parse_scalar(item.strip()) for item in inner.split(",")]


def _parse_inline_dict(s: str) -> dict:
    """Parse {k: v, k2: v2, k3: [a, b]} → dict.

    Handles nested inline lists by tracking bracket depth.
    """
    inner = s[1:-1].strip()
    if not inner:
        return {}

    # Split on commas, but not inside brackets
    pairs: list[str] = []
    current = ""
    depth = 0
    for ch in inner:
        if ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
        elif ch == "," and depth == 0:
            pairs.append(current.strip())
            current = ""
            continue
        current += ch
    if current.strip():
        pairs.append(current.strip())

    result = {}
    for pair in pairs:
        if ":" in pair:
            k, v = pair.split(":", 1)
            v = v.strip()
            if v.startswith("[") and v.endswith("]"):
                result[k.strip()] = _parse_inline_list(v)
            else:
                result[k.strip()] = _parse_scalar(v)
    return result


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------


@dataclass
class Transition:
    """A workflow transition definition."""
    from_state: str
    to_state: str
    requires: list[str] = field(default_factory=list)
    gate: Optional[str] = None
    type: str = "forward"

    @staticmethod
    def from_dict(d: dict) -> Transition:
        return Transition(
            from_state=d["from"],
            to_state=d["to"],
            requires=d.get("requires", []),
            gate=d.get("gate"),
            type=d.get("type", "forward"),
        )


@dataclass
class SkipTransition:
    """A skip transition allowed in lean mode."""
    from_state: str
    to_state: str

    @staticmethod
    def from_dict(d: dict) -> SkipTransition:
        return SkipTransition(from_state=d["from"], to_state=d["to"])


@dataclass
class Mode:
    """Workflow mode (formal/lean)."""
    name: str
    escape_hatches: bool
    skip_transitions: list[SkipTransition]
    required_artifacts: dict[str, list[str]]

    @staticmethod
    def from_dict(name: str, d: dict) -> Mode:
        return Mode(
            name=name,
            escape_hatches=d.get("escape_hatches", False),
            skip_transitions=[
                SkipTransition.from_dict(s) for s in d.get("skip_transitions", [])
            ],
            required_artifacts=d.get("required_artifacts", {}),
        )


@dataclass
class Profile:
    """Review profile."""
    name: str
    description: str
    gates: dict[str, str]  # gate_name -> "human" | "ai" | "skip"

    @staticmethod
    def from_dict(name: str, d: dict) -> Profile:
        return Profile(
            name=name,
            description=d.get("description", ""),
            gates=d.get("gates", {}),
        )


@dataclass
class VerificationCommand:
    """A named verification command."""
    name: str
    run: str
    timeout: int = 120

    @staticmethod
    def from_dict(d: dict) -> VerificationCommand:
        return VerificationCommand(
            name=d["name"],
            run=d["run"],
            timeout=d.get("timeout", 120),
        )


@dataclass
class ArtifactDef:
    """Definition of a required artifact."""
    name: str
    description: str
    location: Optional[str] = None
    check: Optional[str] = None

    @staticmethod
    def from_dict(name: str, d: dict) -> ArtifactDef:
        return ArtifactDef(
            name=name,
            description=d.get("description", ""),
            location=d.get("location"),
            check=d.get("check"),
        )


@dataclass
class WorkflowConfig:
    """Parsed workflow configuration from state_machine_af.yaml."""
    version: int
    engine: str
    states: list[str]
    transitions: list[Transition]
    modes: dict[str, Mode]
    profiles: dict[str, Profile]
    verification_commands: list[VerificationCommand]
    docs_policy: dict[str, Any]
    artifacts: dict[str, ArtifactDef]
    state_mapping: dict[str, str]

    def get_transition(self, from_state: str, to_state: str) -> Optional[Transition]:
        """Find a defined transition between two states."""
        for t in self.transitions:
            if t.from_state == from_state and t.to_state == to_state:
                return t
        return None

    def is_valid_state(self, state: str) -> bool:
        """Check if a state name is valid."""
        return state in self.states or state == "deprecated"

    def get_skip_transitions(self, mode_name: str) -> list[SkipTransition]:
        """Get allowed skip transitions for a mode."""
        mode = self.modes.get(mode_name)
        if not mode:
            return []
        return mode.skip_transitions

    def is_skip_allowed(self, mode_name: str, from_state: str, to_state: str) -> bool:
        """Check if a skip transition is allowed for the given mode."""
        for skip in self.get_skip_transitions(mode_name):
            if skip.from_state == from_state and skip.to_state == to_state:
                return True
        return False

    def get_required_artifacts(self, mode_name: str, target_state: str) -> list[str]:
        """Get required artifacts for entering a state in a given mode."""
        mode = self.modes.get(mode_name)
        if not mode:
            return []
        return mode.required_artifacts.get(target_state, [])

    def get_gate_reviewer(self, profile_name: str, gate_name: str) -> str:
        """Get who reviews a gate (human/ai/skip) for a profile."""
        profile = self.profiles.get(profile_name)
        if not profile:
            return "human"  # safe default
        return profile.gates.get(gate_name, "human")

    def resolve_v1_state(self, v1_state: str) -> Optional[str]:
        """Map a v1 state name to v2."""
        return self.state_mapping.get(v1_state)


# ---------------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------------

_CONFIG_CACHE: dict[str, WorkflowConfig] = {}


def load_config(project_root: Path, force: bool = False) -> WorkflowConfig:
    """Load and parse state_machine_af.yaml.

    Results are cached per project_root unless force=True.
    """
    key = str(project_root.resolve())
    if not force and key in _CONFIG_CACHE:
        return _CONFIG_CACHE[key]

    config_path = project_root / ".agentic" / "state_machine_af.yaml"
    if not config_path.exists():
        raise FileNotFoundError(
            f"Workflow config not found: {config_path}\n"
            "Run 'ag init' to create it, or set engine: v1 in STACK.md."
        )

    raw = _load_yaml(config_path)

    # Parse sections
    workflow_raw = raw.get("workflow", {})
    modes_raw = raw.get("modes", {})
    profiles_raw = raw.get("profiles", {})
    verification_raw = raw.get("verification", {})
    artifacts_raw = raw.get("artifacts", {})

    config = WorkflowConfig(
        version=raw.get("version", 1),
        engine=raw.get("engine", "v1"),
        states=workflow_raw.get("states", []),
        transitions=[Transition.from_dict(t) for t in workflow_raw.get("transitions", [])],
        modes={name: Mode.from_dict(name, d) for name, d in modes_raw.items()},
        profiles={name: Profile.from_dict(name, d) for name, d in profiles_raw.items()},
        verification_commands=[
            VerificationCommand.from_dict(c) for c in verification_raw.get("commands", [])
        ],
        docs_policy=raw.get("docs_policy", {}),
        artifacts={name: ArtifactDef.from_dict(name, d) for name, d in artifacts_raw.items()},
        state_mapping=raw.get("state_mapping", {}),
    )

    _CONFIG_CACHE[key] = config
    return config


def is_v2_engine(project_root: Path) -> bool:
    """Quick check: is the v2 engine active?"""
    config_path = project_root / ".agentic" / "state_machine_af.yaml"
    if not config_path.exists():
        return False
    try:
        raw = _load_yaml(config_path)
        return raw.get("engine") == "v2"
    except Exception:
        return False
