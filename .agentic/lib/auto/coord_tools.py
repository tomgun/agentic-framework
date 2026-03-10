"""
coord_tools.py -- 8 tool handlers for the Coordination Server (F-0185).

Each handler takes a project_root Path and params dict, returns a result dict.
Files are read on every request (no in-memory cache). Delegates to existing
Python classes where possible; claim/release use agents_helpers directly.
"""
from __future__ import annotations

import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
from paths import get_paths  # noqa: E402


def _iso_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# ---------------------------------------------------------------------------
# Tool: claim_feature
# ---------------------------------------------------------------------------
def claim_feature(project_root: Path, params: dict) -> dict:
    """Atomically claim a feature for an agent. Rejects if already claimed."""
    feature_id = params.get("feature_id", "")
    agent = params.get("agent", "")
    description = params.get("description", "")
    pid = params.get("pid", 0)
    if not feature_id:
        return {"error": "feature_id is required"}

    from tools.agents_helpers import cmd_claim
    paths = get_paths(project_root)
    rc = cmd_claim(paths.agents_json, feature_id, agent, description, pid)
    if rc == 0:
        return {"claimed": True, "feature_id": feature_id}
    return {"claimed": False, "feature_id": feature_id,
            "error": "already claimed"}


# ---------------------------------------------------------------------------
# Tool: release_feature
# ---------------------------------------------------------------------------
def release_feature(project_root: Path, params: dict) -> dict:
    """Release a feature claim."""
    feature_id = params.get("feature_id", "")
    pid = params.get("pid", 0)
    if not feature_id:
        return {"error": "feature_id is required"}

    from tools.agents_helpers import cmd_release
    paths = get_paths(project_root)
    rc = cmd_release(paths.agents_json, feature_id, pid)
    if rc == 0:
        return {"released": True, "feature_id": feature_id}
    return {"released": False, "feature_id": feature_id,
            "error": "no active claim"}


# ---------------------------------------------------------------------------
# Tool: transition_state
# ---------------------------------------------------------------------------
def transition_state(project_root: Path, params: dict) -> dict:
    """Transition a feature to a new state. Always uses review_mode=skip."""
    feature_id = params.get("feature_id", "")
    target = params.get("target", "")
    dry_run = params.get("dry_run", False)
    if not feature_id or not target:
        return {"error": "feature_id and target are required"}

    from auto.state_machine import FeatureStateMachine, FeatureState

    try:
        target_state = FeatureState(target)
    except ValueError:
        valid = [s.value for s in FeatureState]
        return {"error": f"invalid target state: {target}",
                "valid_states": valid}

    # Constraint: RPC always skips review checkpoints. Blocking reviews
    # (critical-agent, 60+ seconds) would hold the dispatch lock and freeze
    # all other RPC requests. Transitions needing review go through CLI.
    sm = FeatureStateMachine(project_root, enforce=False)
    success, messages = sm.transition(feature_id, target_state,
                                      dry_run=dry_run, skip_review=True)
    return {"success": success, "messages": messages,
            "feature_id": feature_id, "target": target}


# ---------------------------------------------------------------------------
# Tool: get_unblocked
# ---------------------------------------------------------------------------
def get_unblocked(project_root: Path, params: dict) -> dict:
    """Find all features with at least one available forward transition."""
    from auto.state_machine import FeatureStateMachine

    sm = FeatureStateMachine(project_root, enforce=False)
    results = sm.get_unblocked()
    features = []
    for fid, current, nexts in results:
        features.append({
            "feature_id": fid,
            "current_state": current.value if hasattr(current, 'value') else str(current),
            "available_transitions": [
                n.value if hasattr(n, 'value') else str(n) for n in nexts
            ],
        })
    return {"features": features}


# ---------------------------------------------------------------------------
# Tool: poll_changes
# ---------------------------------------------------------------------------
def poll_changes(project_root: Path, params: dict) -> dict:
    """Check for changes since a given timestamp. Stateless — uses file mtime."""
    since_str = params.get("since", "1970-01-01T00:00:00")
    try:
        since_dt = datetime.fromisoformat(since_str.replace("Z", "+00:00"))
    except (ValueError, TypeError):
        return {"error": f"invalid timestamp: {since_str}"}

    paths = get_paths(project_root)
    since_ts = since_dt.timestamp()
    changed = False

    # Check FEATURES.md mtime
    if paths.features_file.exists():
        if os.path.getmtime(paths.features_file) > since_ts:
            changed = True

    # Check AGENTS.json mtime
    if paths.agents_json.exists():
        if os.path.getmtime(paths.agents_json) > since_ts:
            changed = True

    result: dict = {
        "changed": changed,
        "timestamp": _iso_now(),
    }

    if changed:
        # Return current state of both files
        if paths.features_file.exists():
            # Parse feature statuses from FEATURES.md
            result["features"] = _parse_feature_statuses(paths.features_file)
        if paths.agents_json.exists():
            try:
                agents_data = json.loads(paths.agents_json.read_text())
                result["agents"] = agents_data if isinstance(agents_data, list) else []
            except (json.JSONDecodeError, OSError):
                result["agents"] = []

    return result


def _parse_feature_statuses(features_file: Path) -> list[dict]:
    """Extract feature IDs and statuses from FEATURES.md."""
    features = []
    content = features_file.read_text()
    current_id = None
    for line in content.splitlines():
        m = re.match(r'^## (F-\d{4}):', line)
        if m:
            current_id = m.group(1)
            continue
        if current_id and line.startswith("**Status**:"):
            status = line.split(":", 1)[1].strip()
            features.append({"feature_id": current_id, "status": status})
            current_id = None
    return features


# ---------------------------------------------------------------------------
# Tool: report_status
# ---------------------------------------------------------------------------
def report_status(project_root: Path, params: dict) -> dict:
    """Agent reports progress on a feature (delegates to cmd_checkpoint)."""
    feature_id = params.get("feature_id", "")
    note = params.get("note", "")
    if not feature_id or not note:
        return {"error": "feature_id and note are required"}

    from tools.agents_helpers import cmd_checkpoint
    paths = get_paths(project_root)
    rc = cmd_checkpoint(paths.agents_json, feature_id, note)
    if rc == 0:
        return {"reported": True, "feature_id": feature_id}
    return {"reported": False, "error": "feature not found"}


# ---------------------------------------------------------------------------
# Tool: request_review
# ---------------------------------------------------------------------------
def request_review(project_root: Path, params: dict) -> dict:
    """Submit a feature for review (creates pending review)."""
    feature_id = params.get("feature_id", "")
    from_state = params.get("from_state", "")
    to_state = params.get("to_state", "")
    review_mode = params.get("review_mode", "human")
    if not feature_id or not from_state or not to_state:
        return {"error": "feature_id, from_state, and to_state are required"}

    from auto.review import create_pending_review

    # Determine review_setting from the transition
    setting_map = {
        "specced": "review_spec",
        "criteria_set": "review_criteria",
        "implementing": "review_plan",
        "committed": "review_code",
        "shipped": "review_merge",
    }
    review_setting = setting_map.get(to_state, "review_code")

    hn_id = create_pending_review(
        project_root, feature_id, from_state, to_state,
        review_setting, review_mode,
    )
    if hn_id:
        return {"requested": True, "feature_id": feature_id,
                "review_id": hn_id}
    return {"requested": False, "error": "could not create review"}


# ---------------------------------------------------------------------------
# Tool: submit_review
# ---------------------------------------------------------------------------
def submit_review(project_root: Path, params: dict) -> dict:
    """Submit a review verdict (approve/reject)."""
    feature_id = params.get("feature_id", "")
    target_state = params.get("target_state", "")
    verdict = params.get("verdict", "")
    reasoning = params.get("reasoning", "")
    if not feature_id or not target_state or not verdict:
        return {"error": "feature_id, target_state, and verdict are required"}
    if verdict not in ("approved", "rejected"):
        return {"error": "verdict must be 'approved' or 'rejected'"}

    from auto.review import resolve_review

    success, messages = resolve_review(
        project_root, feature_id, target_state, verdict, reasoning,
    )
    return {"success": success, "messages": messages,
            "feature_id": feature_id, "verdict": verdict}


# ---------------------------------------------------------------------------
# Tool dispatch map
# ---------------------------------------------------------------------------
TOOLS = {
    "claim_feature": claim_feature,
    "release_feature": release_feature,
    "transition_state": transition_state,
    "get_unblocked": get_unblocked,
    "poll_changes": poll_changes,
    "report_status": report_status,
    "request_review": request_review,
    "submit_review": submit_review,
}
