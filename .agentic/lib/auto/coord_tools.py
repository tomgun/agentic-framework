"""
coord_tools.py -- 13 tool handlers for the Coordination Server (F-018).

Each handler takes a project_root Path and params dict, returns a result dict.
Files are read on every request (no in-memory cache). Delegates to existing
Python classes where possible; claim/release use agents_helpers directly.

Tools 1-8: Multi-agent coordination (claim, release, transition, etc.)
Tools 9-13: Task delegation for context-optimized subagent spawning.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
from paths import get_paths  # noqa: E402
from ids import FEATURE_HEADER_RE  # noqa: E402


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
        m = FEATURE_HEADER_RE.match(line)
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


# ===========================================================================
# Task Delegation Tools (9-13) — Context-optimized subagent spawning
# ===========================================================================

def _load_progress(session_dir: Path, feature_id: str) -> list[dict]:
    """Load progress entries for a feature from session progress file."""
    progress_file = session_dir / "progress" / f"{feature_id}.json"
    if not progress_file.exists():
        return []
    try:
        data = json.loads(progress_file.read_text())
        return data if isinstance(data, list) else []
    except (json.JSONDecodeError, OSError):
        return []


def _save_progress_entry(session_dir: Path, feature_id: str, entry: dict) -> None:
    """Append a progress entry atomically using file locking."""
    progress_dir = session_dir / "progress"
    progress_dir.mkdir(parents=True, exist_ok=True)
    progress_file = progress_dir / f"{feature_id}.json"

    import fcntl
    lock_file = progress_dir / f".{feature_id}.lock"
    with open(lock_file, "w") as lf:
        fcntl.flock(lf, fcntl.LOCK_EX)
        try:
            entries = []
            if progress_file.exists():
                try:
                    entries = json.loads(progress_file.read_text())
                except (json.JSONDecodeError, OSError):
                    entries = []
            entries.append(entry)
            progress_file.write_text(json.dumps(entries, indent=2))
        finally:
            fcntl.flock(lf, fcntl.LOCK_UN)


def _load_criteria(project_root: Path, feature_id: str) -> list[dict]:
    """Load acceptance criteria from contract YAML or legacy markdown."""
    paths = get_paths(project_root)

    # Try contract YAML first
    contract_file = paths.contracts_dir / f"{feature_id}.yaml"
    if contract_file.exists():
        try:
            from contracts import load_contract
            contract = load_contract(contract_file)
            return [
                {"ac_id": a.id, "text": a.text, "type": a.type, "draft": a.draft}
                for a in contract.assertions if not a.draft
            ]
        except (ImportError, ValueError, OSError):
            pass

    # Fall back to legacy markdown
    ac_file = paths.acceptance_dir / f"{feature_id}.md"
    if not ac_file.exists():
        return []

    criteria = []
    counter = 0
    for line in ac_file.read_text().splitlines():
        stripped = line.strip()
        if stripped.startswith("- [ ]") or stripped.startswith("- [x]"):
            counter += 1
            text = stripped.lstrip("- [ ]").lstrip("- [x]").strip()
            ac_id = f"AC-{counter:03d}"
            if text.startswith("AC-"):
                parts = text.split(":", 1)
                ac_id = parts[0].strip()
                text = parts[1].strip() if len(parts) > 1 else text
            criteria.append({"ac_id": ac_id, "text": text, "type": "behavioral", "draft": False})
    return criteria


# ---------------------------------------------------------------------------
# Tool 9: list_acs
# ---------------------------------------------------------------------------
def list_acs(project_root: Path, params: dict) -> dict:
    """List acceptance criteria for a feature with completion status."""
    feature_id = params.get("feature_id", "")
    if not feature_id:
        return {"error": "feature_id is required"}

    criteria = _load_criteria(project_root, feature_id)
    if not criteria:
        return {"error": f"no criteria found for {feature_id}",
                "criteria": [], "total": 0, "completed": 0, "pending": 0}

    paths = get_paths(project_root)
    progress = _load_progress(paths.session_dir, feature_id)

    # Build status map from progress entries
    status_map: dict[str, dict] = {}
    for entry in progress:
        ac_id = entry.get("ac_id", "")
        if ac_id:
            status_map[ac_id] = {
                "status": entry.get("status", "pending"),
                "attempts": status_map.get(ac_id, {}).get("attempts", 0) + 1,
            }

    result_criteria = []
    completed = 0
    for ac in criteria:
        info = status_map.get(ac["ac_id"], {"status": "pending", "attempts": 0})
        if info["status"] == "passed":
            completed += 1
        result_criteria.append({
            "ac_id": ac["ac_id"],
            "text": ac["text"],
            "status": info["status"],
            "attempts": info["attempts"],
        })

    return {
        "criteria": result_criteria,
        "total": len(criteria),
        "completed": completed,
        "pending": len(criteria) - completed,
    }


# ---------------------------------------------------------------------------
# Tool 10: get_task_brief
# ---------------------------------------------------------------------------
def get_task_brief(project_root: Path, params: dict) -> dict:
    """Assemble focused context for a subagent working on a feature."""
    feature_id = params.get("feature_id", "")
    ac_id = params.get("ac_id", "")
    role = params.get("role", "implementation-agent")
    component = params.get("component", "")
    if not feature_id:
        return {"error": "feature_id is required"}

    paths = get_paths(project_root)

    # Get AC text if specific AC requested
    ac_text = ""
    criteria = _load_criteria(project_root, feature_id)
    if ac_id:
        for ac in criteria:
            if ac["ac_id"] == ac_id:
                ac_text = ac["text"]
                break

    # Assemble context via context-for-role.sh
    brief = ""
    context_script = paths.tools_dir / "context-for-role.sh"
    if context_script.exists():
        cmd = ["bash", str(context_script), role, feature_id]
        if component:
            cmd.extend(["--component", component])
        try:
            result = subprocess.run(
                cmd, capture_output=True, text=True, timeout=30,
                cwd=str(project_root),
            )
            brief = result.stdout.strip()
        except (subprocess.TimeoutExpired, OSError):
            brief = f"(context assembly failed for role={role})"

    # Get plan summary if it exists
    plan_summary = ""
    plans_dir = project_root / ".agentic" / "journal" / "plans"
    if plans_dir.is_dir():
        for plan_file in plans_dir.glob(f"*{feature_id}*plan*.md"):
            try:
                content = plan_file.read_text()
                # Take first 50 lines as summary
                plan_summary = "\n".join(content.splitlines()[:50])
            except OSError:
                pass
            break

    # Get file hints from contract
    files_hint: list[str] = []
    contract_file = paths.contracts_dir / f"{feature_id}.yaml"
    if contract_file.exists():
        try:
            from contracts import load_contract
            contract = load_contract(contract_file)
            # Extract file paths from verify commands
            for a in contract.assertions:
                if a.verify:
                    for word in a.verify.split():
                        if "/" in word and not word.startswith("-"):
                            files_hint.append(word)
        except (ImportError, ValueError, OSError):
            pass

    # Get prior progress notes
    progress = _load_progress(paths.session_dir, feature_id)
    prior_notes = [
        f"[{e.get('ac_id', '?')}] {e.get('status', '?')}: {e.get('note', '')}"
        for e in progress if e.get("note")
    ]

    # Estimate tokens (~1.3 tokens per word)
    all_text = brief + ac_text + plan_summary
    token_estimate = int(len(all_text.split()) * 1.33)

    return {
        "brief": brief,
        "ac_text": ac_text,
        "plan_summary": plan_summary,
        "files_hint": files_hint[:20],  # Cap at 20
        "prior_notes": prior_notes[-10:],  # Last 10
        "token_estimate": token_estimate,
    }


# ---------------------------------------------------------------------------
# Tool 11: save_progress
# ---------------------------------------------------------------------------
def save_progress(project_root: Path, params: dict) -> dict:
    """Persist subagent results for a feature/AC."""
    feature_id = params.get("feature_id", "")
    if not feature_id:
        return {"error": "feature_id is required"}

    ac_id = params.get("ac_id", "")
    status = params.get("status", "note")
    note = params.get("note", "")
    files_changed = params.get("files_changed", [])

    if status not in ("passed", "failed", "partial", "note"):
        return {"error": "status must be one of: passed, failed, partial, note"}

    paths = get_paths(project_root)
    entry = {
        "ac_id": ac_id,
        "status": status,
        "note": note,
        "files_changed": files_changed if isinstance(files_changed, list) else [],
        "timestamp": _iso_now(),
    }
    _save_progress_entry(paths.session_dir, feature_id, entry)

    # Count completed ACs
    progress = _load_progress(paths.session_dir, feature_id)
    passed_acs = {e["ac_id"] for e in progress if e.get("status") == "passed" and e.get("ac_id")}
    criteria = _load_criteria(project_root, feature_id)
    total = len(criteria)

    return {
        "recorded": True,
        "acs_completed": len(passed_acs),
        "acs_remaining": max(0, total - len(passed_acs)),
    }


# ---------------------------------------------------------------------------
# Tool 12: get_next_action
# ---------------------------------------------------------------------------
def get_next_action(project_root: Path, params: dict) -> dict:
    """Determine the next action for a feature based on state + progress."""
    feature_id = params.get("feature_id", "")
    if not feature_id:
        return {"error": "feature_id is required"}

    paths = get_paths(project_root)

    # Load criteria and progress
    criteria = _load_criteria(project_root, feature_id)
    progress = _load_progress(paths.session_dir, feature_id)
    passed_acs = {e["ac_id"] for e in progress if e.get("status") == "passed" and e.get("ac_id")}

    # Find next unfinished AC
    for ac in criteria:
        if ac["ac_id"] not in passed_acs:
            # Count attempts for this AC
            attempts = sum(1 for e in progress if e.get("ac_id") == ac["ac_id"])
            return {
                "action": "implement_ac",
                "details": {
                    "ac_id": ac["ac_id"],
                    "ac_text": ac["text"],
                    "attempt": attempts + 1,
                    "max_retries": 3,
                },
                "acs_remaining": len(criteria) - len(passed_acs),
            }

    # All ACs done — suggest verification
    if criteria and len(passed_acs) >= len(criteria):
        # Check if verification has been done
        has_verify = any(
            e.get("status") == "passed" and e.get("ac_id") == "__verify__"
            for e in progress
        )
        if not has_verify:
            return {
                "action": "verify",
                "details": {},
                "acs_remaining": 0,
            }

        # Verification done — suggest PR
        has_pr = any(
            e.get("status") == "passed" and e.get("ac_id") == "__pr__"
            for e in progress
        )
        if not has_pr:
            return {
                "action": "create_pr",
                "details": {
                    "acs_completed": len(passed_acs),
                },
                "acs_remaining": 0,
            }

        return {
            "action": "done",
            "details": {},
            "acs_remaining": 0,
        }

    # No criteria found
    if not criteria:
        return {
            "action": "blocked",
            "details": {"reason": f"no acceptance criteria found for {feature_id}"},
            "acs_remaining": 0,
        }

    return {
        "action": "blocked",
        "details": {"reason": "unknown state"},
        "acs_remaining": len(criteria) - len(passed_acs),
    }


# ---------------------------------------------------------------------------
# Tool 13: get_delegation_prompt
# ---------------------------------------------------------------------------
def get_delegation_prompt(project_root: Path, params: dict) -> dict:
    """Build a complete prompt for delegating an AC to a subagent."""
    feature_id = params.get("feature_id", "")
    ac_id = params.get("ac_id", "")
    role = params.get("role", "implementation-agent")
    if not feature_id or not ac_id:
        return {"error": "feature_id and ac_id are required"}

    # Get task brief (reuse existing tool)
    brief_result = get_task_brief(project_root, {
        "feature_id": feature_id,
        "ac_id": ac_id,
        "role": role,
    })
    if "error" in brief_result and not brief_result.get("brief"):
        return brief_result

    # Get test command from STACK.md
    test_command = ""
    try:
        from settings import get_setting
        test_command = get_setting(project_root, "test_command", "")
    except (ImportError, OSError):
        pass

    # Build the delegation prompt
    sections = []

    if brief_result.get("brief"):
        sections.append(f"## Project Context\n{brief_result['brief']}")

    sections.append(f"## Task\nImplement acceptance criterion {ac_id} for feature {feature_id}.")

    if brief_result.get("ac_text"):
        sections.append(f"## Acceptance Criterion\n**{ac_id}**: {brief_result['ac_text']}")

    if brief_result.get("plan_summary"):
        sections.append(f"## Plan Summary\n{brief_result['plan_summary']}")

    if brief_result.get("prior_notes"):
        notes_text = "\n".join(f"- {n}" for n in brief_result["prior_notes"])
        sections.append(f"## Prior Progress\n{notes_text}")

    if brief_result.get("files_hint"):
        files_text = "\n".join(f"- {f}" for f in brief_result["files_hint"])
        sections.append(f"## Relevant Files\n{files_text}")

    instructions = [
        "## Instructions",
        "1. Read the relevant source files before making changes",
        "2. Implement the acceptance criterion described above",
        "3. Write or update tests to cover the new behavior",
    ]
    if test_command:
        instructions.append(f"4. Run tests to verify: `{test_command}`")
    else:
        instructions.append("4. Run the project's test suite to verify")
    instructions.append("5. Keep changes focused — only modify what's needed for this AC")
    sections.append("\n".join(instructions))

    prompt = "\n\n".join(sections)

    # Model hint based on complexity heuristic
    ac_text = brief_result.get("ac_text", "")
    text_lower = ac_text.lower()
    large_keywords = ["full system", "complete implementation", "infrastructure",
                      "database schema", "migration", "authentication system"]
    if any(kw in text_lower for kw in large_keywords):
        model_hint = "opus"
    elif len(ac_text) > 200:
        model_hint = "sonnet"
    else:
        model_hint = "sonnet"

    # Worktree recommendation
    try:
        from settings import get_setting as gs
        git_mode = gs(project_root, "git_mode", "default")
        use_worktree = git_mode not in ("deferred", "none")
    except (ImportError, OSError):
        use_worktree = True

    return {
        "prompt": prompt,
        "model_hint": model_hint,
        "use_worktree": use_worktree,
    }


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
    "list_acs": list_acs,
    "get_task_brief": get_task_brief,
    "save_progress": save_progress,
    "get_next_action": get_next_action,
    "get_delegation_prompt": get_delegation_prompt,
}
