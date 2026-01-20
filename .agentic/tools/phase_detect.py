#!/usr/bin/env python3
"""
Detect current development phase based on project state.
Used by hooks and verification to run context-appropriate checks.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path


def read_profile(root: Path) -> str:
    """Determine profile from STACK.md or infer from structure."""
    stack = root / "STACK.md"
    if stack.exists():
        try:
            md = stack.read_text(encoding="utf-8")
            m = re.search(r"(?m)^\s*-\s*Profile:\s*([a-z+_-]+)\s*$", md)
            if m and m.group(1).strip() in {"core", "core+product"}:
                return m.group(1).strip()
        except Exception:
            pass
    if (root / "spec").is_dir() or (root / "STATUS.md").is_file():
        return "core+product"
    return "core"


def detect_phase(root: Path) -> str:
    """
    Detect current development phase.

    Returns one of:
    - "core-mode": Core profile (no feature tracking)
    - "blocked": Has unresolved blockers in HUMAN_NEEDED.md
    - "start": No active work (no .agentic/WIP.md)
    - "planning": Feature started but no acceptance criteria
    - "implement": Has acceptance, implementing
    - "complete": Feature shipped, awaiting validation
    """
    profile = read_profile(root)

    # Core profile has no feature-based phases
    if profile == "core":
        return "core-mode"

    # Check for blockers first
    human_needed = root / "HUMAN_NEEDED.md"
    if human_needed.exists():
        try:
            content = human_needed.read_text()
            if re.search(r"##\s+HN-\d{4}", content):
                return "blocked"
        except Exception:
            pass

    # Check .agentic/WIP.md for active feature (format: **Feature**: F-0001: description)
    wip = root / ".agentic" / "WIP.md"
    if not wip.exists():
        return "start"

    try:
        wip_content = wip.read_text()
    except Exception:
        return "start"

    # Match .agentic/WIP.md format: **Feature**: F-0001
    feature_match = re.search(r"\*\*Feature\*\*:\s*(F-\d{4})", wip_content)
    if not feature_match:
        # Also try simpler format: Feature: F-0001
        feature_match = re.search(r"Feature:\s*(F-\d{4})", wip_content)

    if not feature_match:
        return "start"

    feature_id = feature_match.group(1)

    # Check if acceptance exists
    acceptance = root / "spec" / "acceptance" / f"{feature_id}.md"
    if not acceptance.exists():
        return "planning"

    # Check if feature is shipped (would be in complete phase)
    features_path = root / "spec" / "FEATURES.md"
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
