#!/usr/bin/env python3
"""
Detect current development phase based on project state.
Used by hooks and verification to run context-appropriate checks.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

# Import shared settings library
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from settings import get_setting
from paths import get_paths
from ids import FEATURE_ID_RE


def detect_phase(root: Path) -> str:
    """
    Detect current development phase.

    Returns one of:
    - "no-feature-tracking": Feature tracking disabled (setting or profile)
    - "blocked": Has unresolved blockers in HUMAN_NEEDED.md
    - "start": No active work (no .agentic/session/WIP.md)
    - "planning": Feature started but no acceptance criteria
    - "implement": Has acceptance, implementing
    - "complete": Feature shipped, awaiting validation
    """
    p = get_paths(root)
    ft = get_setting(root, "feature_tracking", "no")

    # No feature tracking = no feature-based phases
    if ft != "yes":
        return "no-feature-tracking"

    # Check for blockers first
    human_needed = p.human_needed_file
    if human_needed.exists():
        try:
            content = human_needed.read_text()
            if re.search(r"##\s+HN-\d{4}", content):
                return "blocked"
        except Exception:
            pass

    # Check WIP.md for active feature (format: **Feature**: F-001: description)
    wip = p.wip_file
    if not wip.exists():
        return "start"

    try:
        wip_content = wip.read_text()
    except Exception:
        return "start"

    # Match WIP.md format: **Feature**: F-001
    feature_match = re.search(r"\*\*Feature\*\*:\s*" + FEATURE_ID_RE.pattern, wip_content)
    if not feature_match:
        # Also try simpler format: Feature: F-001
        feature_match = re.search(r"Feature:\s*" + FEATURE_ID_RE.pattern, wip_content)

    if not feature_match:
        return "start"

    feature_id = feature_match.group(1)

    # Check if acceptance exists (contract YAML or legacy markdown)
    contract = p.contracts_dir / f"{feature_id}.yaml"
    acceptance = p.acceptance_dir / f"{feature_id}.md"
    if not contract.exists() and not acceptance.exists():
        return "planning"

    # Check if feature is shipped (would be in complete phase)
    features_path = p.features_file
    if features_path.exists():
        try:
            content = features_path.read_text()
            # Look for this feature's status
            pattern = rf"##\s+{feature_id}:.*?- Status:\s*(\w+)"
            match = re.search(pattern, content, re.DOTALL)
            if match and match.group(1).lower() == "shipped":
                return "complete"
        except Exception:
            pass

    return "implement"


def main() -> int:
    root = Path.cwd()
    phase = detect_phase(root)
    print(phase)
    return 0


if __name__ == "__main__":
    sys.exit(main())
