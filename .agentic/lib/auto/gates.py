"""
gates.py -- Gate functions for feature state machine transitions.

Each gate checks preconditions for a transition.  Gates return GateResult
with (allowed, reasons, warnings).  Hard blocks prevent the transition;
advisory warnings are logged but do not block.

State flow:
  planned -> specced -> criteria_set -> tests_written -> implementing
  -> verified -> documented -> committed -> shipped

Usage:
    from auto.gates import gate_planned_to_specced, GateResult
    result = gate_planned_to_specced("F-0042", Path("/project"))
    if not result.allowed:
        print("Blocked:", result.reasons)
"""
from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
from paths import get_paths  # noqa: E402


# ---------------------------------------------------------------------------
# GateResult
# ---------------------------------------------------------------------------

@dataclass
class GateResult:
    """Result of a transition gate check."""
    allowed: bool
    reasons: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    @staticmethod
    def ok(warnings: list[str] | None = None) -> GateResult:
        return GateResult(allowed=True, reasons=[], warnings=warnings or [])

    @staticmethod
    def blocked(reasons: list[str], warnings: list[str] | None = None) -> GateResult:
        return GateResult(allowed=False, reasons=reasons, warnings=warnings or [])

    def merge(self, other: GateResult) -> GateResult:
        """Combine two results — blocked if either is blocked."""
        return GateResult(
            allowed=self.allowed and other.allowed,
            reasons=self.reasons + other.reasons,
            warnings=self.warnings + other.warnings,
        )


# ---------------------------------------------------------------------------
# Type alias for gate functions
# ---------------------------------------------------------------------------
GateFunc = Callable[[str, Path], GateResult]


# ---------------------------------------------------------------------------
# Helper: read FEATURES.md and extract a feature block
# ---------------------------------------------------------------------------

def _read_feature_block(feature_id: str, project_root: Path) -> str | None:
    """Return the raw text block for *feature_id* from FEATURES.md, or None."""
    paths = get_paths(project_root)
    features_file = paths.features_file
    if not features_file.exists():
        return None

    content = features_file.read_text()
    # Feature blocks start with "## F-XXXX:" and end at the next "---" or "## F-"
    pattern = rf"(## {re.escape(feature_id)}\b.*?)(?=\n---|\n## F-|\Z)"
    match = re.search(pattern, content, re.DOTALL)
    if match:
        return match.group(1)
    return None


# ---------------------------------------------------------------------------
# Gate 1: planned -> specced
# ---------------------------------------------------------------------------

def gate_planned_to_specced(feature_id: str, project_root: Path) -> GateResult:
    """Feature must exist in FEATURES.md with a non-empty Description."""
    block = _read_feature_block(feature_id, project_root)
    reasons: list[str] = []
    warnings: list[str] = []

    if block is None:
        reasons.append(f"{feature_id} not found in FEATURES.md")
        return GateResult.blocked(reasons)

    # Check for a Description field with content
    desc_match = re.search(
        r"\*\*Description\*\*:\s*(.+)", block,
    )
    if not desc_match or not desc_match.group(1).strip():
        reasons.append(
            f"{feature_id} has no Description in FEATURES.md"
        )

    if reasons:
        return GateResult.blocked(reasons, warnings)
    return GateResult.ok(warnings)


# ---------------------------------------------------------------------------
# Gate 2: specced -> criteria_set
# ---------------------------------------------------------------------------

def gate_specced_to_criteria_set(feature_id: str, project_root: Path) -> GateResult:
    """Acceptance criteria file must exist and contain at least one AC line."""
    paths = get_paths(project_root)
    ac_file = paths.acceptance_dir / f"{feature_id}.md"
    reasons: list[str] = []
    warnings: list[str] = []

    if not ac_file.exists():
        reasons.append(
            f"Acceptance criteria file missing: spec/acceptance/{feature_id}.md"
        )
        return GateResult.blocked(reasons)

    content = ac_file.read_text()

    # Look for AC lines in any of the common formats
    ac_pattern = re.compile(
        r"(- \[[ x]\]\s*\*?\*?AC-|### AC-)", re.IGNORECASE,
    )
    if not ac_pattern.search(content):
        reasons.append(
            f"No acceptance criteria found in spec/acceptance/{feature_id}.md "
            f"(expected lines matching '- [ ] AC-' or '### AC-')"
        )

    if reasons:
        return GateResult.blocked(reasons, warnings)
    return GateResult.ok(warnings)


# ---------------------------------------------------------------------------
# Gate 3: criteria_set -> tests_written
# ---------------------------------------------------------------------------

def gate_criteria_set_to_tests_written(feature_id: str, project_root: Path) -> GateResult:
    """At least one test file must reference the feature ID."""
    reasons: list[str] = []
    warnings: list[str] = []

    # Search for the feature ID in test files
    test_dirs = [
        project_root / "tests",
        project_root / "test",
        project_root / "spec",  # some projects put specs/tests here
    ]

    found = False
    fid_lower = feature_id.lower()
    fid_upper = feature_id.upper()

    for test_dir in test_dirs:
        if not test_dir.is_dir():
            continue
        for test_file in test_dir.rglob("*"):
            if not test_file.is_file():
                continue
            # Check common test file extensions
            if test_file.suffix not in (".py", ".js", ".ts", ".sh", ".rb", ".go", ".rs"):
                continue
            try:
                text = test_file.read_text(errors="ignore")
                if fid_lower in text.lower() or fid_upper in text:
                    found = True
                    break
            except OSError:
                continue
        if found:
            break

    if not found:
        reasons.append(
            f"No test files found referencing {feature_id} "
            f"(searched tests/, test/, spec/)"
        )

    if reasons:
        return GateResult.blocked(reasons, warnings)
    return GateResult.ok(warnings)


# ---------------------------------------------------------------------------
# Gate 4: tests_written -> implementing
# ---------------------------------------------------------------------------

def gate_tests_written_to_implementing(feature_id: str, project_root: Path) -> GateResult:
    """Advisory checks only — TDD readiness."""
    warnings: list[str] = []

    paths = get_paths(project_root)

    # Advisory: WIP.md should be created to track work-in-progress
    if not paths.wip_file.exists():
        warnings.append(
            "WIP.md not found — consider creating it to track in-progress work"
        )

    # Advisory: tests should run and fail (TDD) — can't check statically
    warnings.append(
        "Advisory: verify tests fail before implementing (TDD red-green-refactor)"
    )

    return GateResult.ok(warnings)


# ---------------------------------------------------------------------------
# Gate 5: implementing -> verified
# ---------------------------------------------------------------------------

def gate_implementing_to_verified(feature_id: str, project_root: Path) -> GateResult:
    """Test files and AC file must exist.  Advisory: tests cover all ACs."""
    paths = get_paths(project_root)
    reasons: list[str] = []
    warnings: list[str] = []

    # Hard: acceptance criteria file must still exist
    ac_file = paths.acceptance_dir / f"{feature_id}.md"
    if not ac_file.exists():
        reasons.append(
            f"Acceptance criteria file missing: spec/acceptance/{feature_id}.md"
        )

    # Hard: at least one test file references the feature
    test_dirs = [project_root / "tests", project_root / "test"]
    found_test = False
    for test_dir in test_dirs:
        if not test_dir.is_dir():
            continue
        for test_file in test_dir.rglob("*"):
            if not test_file.is_file():
                continue
            if test_file.suffix not in (".py", ".js", ".ts", ".sh", ".rb", ".go", ".rs"):
                continue
            try:
                text = test_file.read_text(errors="ignore")
                if feature_id.lower() in text.lower():
                    found_test = True
                    break
            except OSError:
                continue
        if found_test:
            break

    if not found_test:
        reasons.append(
            f"No test files reference {feature_id}"
        )

    # Advisory: check if tests reference all ACs from the acceptance file
    if ac_file.exists() and found_test:
        ac_content = ac_file.read_text()
        ac_ids = re.findall(r"\*?\*?AC-(\d+)\*?\*?", ac_content)
        if ac_ids:
            warnings.append(
                f"Advisory: verify that tests cover all {len(set(ac_ids))} "
                f"acceptance criteria"
            )

    if reasons:
        return GateResult.blocked(reasons, warnings)
    return GateResult.ok(warnings)


# ---------------------------------------------------------------------------
# Gate 6: verified -> documented
# ---------------------------------------------------------------------------

def gate_verified_to_documented(feature_id: str, project_root: Path) -> GateResult:
    """Advisory checks for documentation updates."""
    warnings: list[str] = []

    # Advisory: CHANGELOG should mention the feature
    changelog = project_root / "CHANGELOG.md"
    if changelog.exists():
        content = changelog.read_text()
        if feature_id not in content:
            warnings.append(
                f"CHANGELOG.md does not mention {feature_id} — "
                f"consider adding a changelog entry"
            )
    else:
        warnings.append("No CHANGELOG.md found")

    # Advisory: docs should be updated (general reminder)
    warnings.append(
        "Advisory: ensure documentation is updated alongside code changes"
    )

    return GateResult.ok(warnings)


# ---------------------------------------------------------------------------
# Gate 7: documented -> committed
# ---------------------------------------------------------------------------

def gate_documented_to_committed(feature_id: str, project_root: Path) -> GateResult:
    """Advisory checks for commit readiness."""
    warnings: list[str] = []

    # Advisory: check for unstaged changes (without running git)
    # We check if the git directory exists as a basic sanity check
    git_dir = project_root / ".git"
    if not git_dir.exists():
        warnings.append("Not a git repository — cannot verify commit readiness")
    else:
        # Advisory: remind about pre-commit checks
        warnings.append(
            "Advisory: ensure pre-commit checks pass before committing "
            "(bash tests/validate_framework.sh)"
        )

    return GateResult.ok(warnings)


# ---------------------------------------------------------------------------
# Gate 8: committed -> shipped
# ---------------------------------------------------------------------------

def gate_committed_to_shipped(feature_id: str, project_root: Path) -> GateResult:
    """Advisory checks for ship readiness — entirely non-blocking."""
    warnings: list[str] = []

    # Advisory: branch should be pushed
    warnings.append(
        "Advisory: ensure branch is pushed to remote"
    )

    # Advisory: PR should exist for review
    warnings.append(
        "Advisory: ensure a pull request exists and has been reviewed"
    )

    # Advisory: VERSION should be bumped
    paths = get_paths(project_root)
    if paths.version_file.exists():
        warnings.append(
            "Advisory: verify VERSION has been bumped (at least patch)"
        )

    return GateResult.ok(warnings)


# ---------------------------------------------------------------------------
# Gate registration
# ---------------------------------------------------------------------------

# Default gate list for bulk registration
DEFAULT_GATES: list[tuple[str, str, GateFunc]] = [
    ("planned", "specced", gate_planned_to_specced),
    ("specced", "criteria_set", gate_specced_to_criteria_set),
    ("criteria_set", "tests_written", gate_criteria_set_to_tests_written),
    ("tests_written", "implementing", gate_tests_written_to_implementing),
    ("implementing", "verified", gate_implementing_to_verified),
    ("verified", "documented", gate_verified_to_documented),
    ("documented", "committed", gate_documented_to_committed),
    ("committed", "shipped", gate_committed_to_shipped),
]


def register_default_gates(sm: object, state_enum: type | None = None) -> None:
    """Register all default gate functions on a FeatureStateMachine instance.

    Args:
        sm: FeatureStateMachine instance with register_gate(from, to, fn) method.
        state_enum: FeatureState enum class. If None, imports from auto.state_machine.
            Pass explicitly when calling from __main__ to avoid dual-import issues.
    """
    if state_enum is None:
        from auto.state_machine import FeatureState
        state_enum = FeatureState

    for from_str, to_str, gate_fn in DEFAULT_GATES:
        from_state = state_enum(from_str)
        to_state = state_enum(to_str)
        sm.register_gate(from_state, to_state, gate_fn)
