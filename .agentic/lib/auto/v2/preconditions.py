"""
preconditions.py — Artifact existence and gate checks for state transitions.

Extracts precondition logic from scattered bash scripts into a unified system
driven by state_machine_af.yaml configuration.
"""
from __future__ import annotations

import re
import shlex
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

from .config import WorkflowConfig, ArtifactDef, load_config
from . import work_items

# Strict pattern: feature IDs must match F-XXXX (4+ digits, no special chars)
_FEATURE_ID_RE = re.compile(r"^F-\d{4,}$")


# ---------------------------------------------------------------------------
# Check results
# ---------------------------------------------------------------------------


@dataclass
class CheckResult:
    """Result of a precondition check."""
    passed: bool
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    @staticmethod
    def ok(warnings: list[str] | None = None) -> CheckResult:
        return CheckResult(passed=True, warnings=warnings or [])

    @staticmethod
    def fail(errors: list[str], warnings: list[str] | None = None) -> CheckResult:
        return CheckResult(passed=False, errors=errors, warnings=warnings or [])

    def merge(self, other: CheckResult) -> CheckResult:
        return CheckResult(
            passed=self.passed and other.passed,
            errors=self.errors + other.errors,
            warnings=self.warnings + other.warnings,
        )


# ---------------------------------------------------------------------------
# Artifact checking
# ---------------------------------------------------------------------------


def check_artifact(
    project_root: Path,
    feature_id: str,
    artifact_name: str,
    config: WorkflowConfig,
    quick: bool = False,
) -> CheckResult:
    """Check if a single artifact requirement is satisfied.

    Artifacts can be checked by:
    1. File existence (location template in config)
    2. Custom command (check template in config)
    3. Default: file in work item directory

    When quick=True, skip artifacts that require command execution
    (only check file-existence based artifacts). This keeps checks <500ms.
    """
    artifact_def = config.artifacts.get(artifact_name)
    work_dir = work_items.item_dir(project_root, feature_id)

    if artifact_def and artifact_def.check:
        # In quick mode, skip command-based checks entirely
        if quick:
            return CheckResult.ok(warnings=[f"Skipped '{artifact_name}' (quick mode)"])
        # Validate feature_id before shell interpolation to prevent injection
        if not _FEATURE_ID_RE.match(feature_id):
            return CheckResult.fail(
                [f"Invalid feature ID format: '{feature_id}' (must match F-XXXX)"]
            )
        # Run custom check command with safe interpolation
        cmd = artifact_def.check.format(
            work_dir=shlex.quote(str(work_dir)),
            feature_id=shlex.quote(feature_id),
            project_root=shlex.quote(str(project_root)),
        )
        try:
            result = subprocess.run(
                cmd, shell=True, cwd=str(project_root),
                capture_output=True, text=True, timeout=30,
            )
            if result.returncode == 0:
                return CheckResult.ok()
            return CheckResult.fail(
                [f"Artifact check failed for '{artifact_name}': {result.stderr.strip() or 'command returned non-zero'}"]
            )
        except subprocess.TimeoutExpired:
            return CheckResult.fail([f"Artifact check timed out for '{artifact_name}'"])
        except Exception as e:
            return CheckResult.fail([f"Artifact check error for '{artifact_name}': {e}"])

    if artifact_def and artifact_def.location:
        # Check file existence via location template
        path_str = artifact_def.location.format(
            work_dir=work_dir,
            feature_id=feature_id,
            project_root=project_root,
        )
        path = Path(path_str)
        if path.exists() and path.stat().st_size > 0:
            return CheckResult.ok()
        return CheckResult.fail(
            [f"Required artifact '{artifact_name}' not found at {path}"]
        )

    # Default: file in work item directory
    path = work_dir / artifact_name
    if path.exists() and path.stat().st_size > 0:
        return CheckResult.ok()
    return CheckResult.fail(
        [f"Required artifact '{artifact_name}' not found at {path}"]
    )


def check_transition_artifacts(
    project_root: Path,
    feature_id: str,
    target_state: str,
    config: WorkflowConfig,
    mode: str,
    quick: bool = False,
) -> CheckResult:
    """Check all artifact requirements for a transition to target_state.

    Combines:
    1. Transition-level requires (from workflow.transitions)
    2. Mode-level required_artifacts (from modes.<mode>.required_artifacts)

    When quick=True, only file-existence checks run (no command execution).
    """
    result = CheckResult.ok()

    # 1. Check transition-level requires
    item = work_items.load(project_root, feature_id)
    transition = config.get_transition(item.status, target_state)
    if transition:
        for artifact_name in transition.requires:
            artifact_result = check_artifact(
                project_root, feature_id, artifact_name, config, quick=quick,
            )
            result = result.merge(artifact_result)

    # 2. Check mode-level required artifacts
    mode_artifacts = config.get_required_artifacts(mode, target_state)
    for artifact_name in mode_artifacts:
        # Don't double-check if already checked in transition requires
        if transition and artifact_name in transition.requires:
            continue
        artifact_result = check_artifact(
            project_root, feature_id, artifact_name, config, quick=quick,
        )
        result = result.merge(artifact_result)

    return result


def check_all_artifacts(
    project_root: Path,
    feature_id: str,
    config: WorkflowConfig,
    mode: str,
) -> CheckResult:
    """Check all artifacts for a work item's current state and mode.

    Used by `ag check F-XXXX` to validate current state.
    """
    item = work_items.load(project_root, feature_id)
    return check_transition_artifacts(
        project_root, feature_id, item.status, config, mode
    )
