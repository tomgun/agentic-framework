"""
features_sync.py — Write-through shim: keeps FEATURES.md in sync on v2 transitions.

During Phase 2, many modules still read feature state from FEATURES.md.
This hook fires after every successful TransitionOrchestrator.transition()
and maps the v2 state back to v1, writing via feature.sh.

Removed in Phase 3 when FEATURES.md consumers are eliminated.
"""
from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Optional

# v2 state → v1 status (reverse of state_mapping in state_machine_af.yaml)
# Where multiple v1 states map to one v2 state, we pick the most advanced.
V2_TO_V1: dict[str, str] = {
    "idea": "planned",
    "queued": "planned",
    "planning": "planned",
    "plan_review": "specced",
    "spec": "criteria_set",
    "implementation": "implementing",
    "verification": "verified",
    "docs": "documented",
    "ready_to_ship": "committed",
    "shipped": "shipped",
    "deprecated": "deprecated",
}


def sync_to_features_md(
    project_root: Path,
    feature_id: str,
    target_state: str,
) -> Optional[str]:
    """Write v2 state to FEATURES.md via feature.sh.

    Returns None on success, error string on failure.
    """
    v1_status = V2_TO_V1.get(target_state)
    if not v1_status:
        return f"No v1 mapping for state '{target_state}'"

    feature_sh = project_root / ".agentic" / "lib" / "tools" / "feature.sh"
    if not feature_sh.exists():
        # No feature.sh means no FEATURES.md to sync (e.g. test env)
        return None

    try:
        result = subprocess.run(
            ["bash", str(feature_sh), feature_id, "status", v1_status],
            cwd=str(project_root),
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode != 0:
            return f"feature.sh exited {result.returncode}: {result.stderr.strip()}"
    except subprocess.TimeoutExpired:
        return f"feature.sh timed out syncing {feature_id} → {v1_status}"
    except Exception as e:
        return f"feature.sh failed: {e}"

    return None
