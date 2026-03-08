"""
review.py -- Review checkpoint framework for the Agentic Framework.

Implements ADR-001 Phase 3: configurable review modes (human/critical_agent/auto)
per state transition. Reviews happen after gates pass, before the transition writes.

Usage:
    from auto.review import check_review, has_pending_review, resolve_review

    # During transition:
    can_proceed, msgs = check_review(project_root, "F-0042", "planned", "specced")

    # Resolving a blocked review:
    resolve_review(project_root, "F-0042", "specced", "approved", "Looks good")

CLI:
    python -m auto.review                          # List all pending
    python -m auto.review F-0042                   # List pending for feature
    python -m auto.review F-0042 specced           # Approve (default)
    python -m auto.review F-0042 specced --reject  # Reject
    python -m auto.review F-0042 specced --reason "text"
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from enum import Enum
from pathlib import Path
from typing import Optional

# ---------------------------------------------------------------------------
# Resolve paths.py from the lib/ directory (our parent)
# ---------------------------------------------------------------------------
_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
from paths import get_paths  # noqa: E402
from settings import get_setting  # noqa: E402


# ---------------------------------------------------------------------------
# Feature ID validation
# ---------------------------------------------------------------------------

_FEATURE_ID_RE = re.compile(r"^F-\d{4,}$")


def _validate_feature_id(feature_id: str) -> None:
    """Validate feature ID format to prevent path traversal."""
    if not _FEATURE_ID_RE.match(feature_id):
        raise ValueError(
            f"Invalid feature ID: '{feature_id}'. Must match F-XXXX format."
        )


# ---------------------------------------------------------------------------
# Review modes
# ---------------------------------------------------------------------------

class ReviewMode(Enum):
    """Review mode for a transition checkpoint."""
    HUMAN = "human"
    CRITICAL_AGENT = "critical_agent"
    AUTO = "auto"


# ---------------------------------------------------------------------------
# Transition → review setting map
# ---------------------------------------------------------------------------

# Maps (from_state, to_state) → setting key in STACK.md/profiles.conf
# Uses FeatureState values (strings) to avoid circular import with state_machine.
# The _build_regression_pairs() function derives regression pairs from the
# state_machine source of truth at import time.
TRANSITION_REVIEW_MAP: dict[tuple[str, str], str] = {
    # Forward transitions
    ("planned", "specced"): "review_spec",
    ("specced", "criteria_set"): "review_criteria",
    ("tests_written", "implementing"): "review_plan",
    ("documented", "committed"): "review_code",
    ("committed", "shipped"): "review_merge",

    # Skip transitions → most restrictive skipped review
    ("planned", "implementing"): "review_plan",
    ("planned", "shipped"): "review_merge",
    ("implementing", "shipped"): "review_merge",
    ("implementing", "committed"): "review_code",
}

# Unmapped forward transitions (auto by default, structural gates suffice):
# criteria_set → tests_written, implementing → verified, verified → documented

# Derive regression pairs from state_machine.REGRESSION_TRANSITIONS (source of truth)
# to avoid sync drift between the two modules.
def _build_regression_pairs() -> set[tuple[str, str]]:
    from auto.state_machine import REGRESSION_TRANSITIONS
    return {(fr.value, to.value) for fr, to in REGRESSION_TRANSITIONS}

_REGRESSION_PAIRS: set[tuple[str, str]] = _build_regression_pairs()

# review_decomposition and review_taste exist in profiles.conf and STACK.md
# but are not wired to transitions yet. They are placeholders for future
# features (epic decomposition, subjective design decisions).


def _get_review_setting_key(from_state: str, to_state: str) -> Optional[str]:
    """Get the review setting key for a transition."""
    pair = (from_state, to_state)
    if pair in TRANSITION_REVIEW_MAP:
        return TRANSITION_REVIEW_MAP[pair]
    if pair in _REGRESSION_PAIRS:
        return "review_regression"
    # Unmapped forward transitions default to auto (no setting needed)
    return None


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def get_review_mode(
    project_root: Path, from_state: str, to_state: str
) -> ReviewMode:
    """Resolve the review mode for a transition via settings."""
    setting_key = _get_review_setting_key(from_state, to_state)
    if setting_key is None:
        return ReviewMode.AUTO

    value = get_setting(project_root, setting_key, "auto")
    try:
        return ReviewMode(value)
    except ValueError:
        return ReviewMode.AUTO


def check_review(
    project_root: Path,
    feature_id: str,
    from_state: str,
    to_state: str,
) -> tuple[bool, list[str]]:
    """Check if a review is needed for this transition.

    Returns (can_proceed, messages).
    - auto: auto-approves (True, []) — structural gates still apply
    - human/critical_agent: creates pending review, returns (False, [instructions])

    If a verdict artifact already exists, returns (True, []) to prevent
    re-review loops when resolve_review triggers transition().
    """
    # Check for existing verdict artifact
    paths = get_paths(project_root)
    verdict_dir = paths.reviews_dir / feature_id
    verdict_file = verdict_dir / f"{from_state}_to_{to_state}.md"
    if verdict_file.exists():
        return True, []

    mode = get_review_mode(project_root, from_state, to_state)
    if mode == ReviewMode.AUTO:
        return True, []

    # human or critical_agent → block
    setting_key = _get_review_setting_key(from_state, to_state) or "unknown"

    if mode == ReviewMode.CRITICAL_AGENT:
        fallback_msg = (
            f"Note: critical_agent review not yet available (F-0182). "
            f"Falling back to human review."
        )
    else:
        fallback_msg = None

    hn_id = create_pending_review(
        project_root, feature_id, from_state, to_state,
        setting_key, mode.value,
    )

    messages = []
    if fallback_msg:
        messages.append(fallback_msg)
    messages.append(
        f"Review required: {feature_id} {from_state} → {to_state} "
        f"(setting: {setting_key}, mode: {mode.value})"
    )
    messages.append(
        f"Resolve with: ag review {feature_id} {to_state}"
    )
    if hn_id:
        messages.append(f"Tracked as {hn_id} in HUMAN_NEEDED.md")

    return False, messages


def create_pending_review(
    project_root: Path,
    feature_id: str,
    from_state: str,
    to_state: str,
    review_setting: str,
    review_mode: str,
) -> Optional[str]:
    """Create a pending review JSON file and HUMAN_NEEDED entry.

    Returns the HN-ID if successfully created, None otherwise.
    """
    paths = get_paths(project_root)
    reviews_dir = paths.pending_reviews_dir
    reviews_dir.mkdir(parents=True, exist_ok=True)

    # Create pending review JSON
    now = datetime.now(timezone.utc).isoformat()
    review_data = {
        "feature_id": feature_id,
        "from_state": from_state,
        "to_state": to_state,
        "review_setting": review_setting,
        "review_mode": review_mode,
        "created_at": now,
    }

    review_file = reviews_dir / f"{feature_id}_{to_state}.json"

    # Create HUMAN_NEEDED entry via blocker.sh
    blocker_sh = paths.tools_dir / "blocker.sh"
    hn_id = None
    if blocker_sh.exists():
        try:
            result = subprocess.run(
                [
                    "bash", str(blocker_sh), "add",
                    f"Review: {feature_id} → {to_state}",
                    "decision",
                    f"Review checkpoint ({review_setting}, mode: {review_mode}). "
                    f"Resolve with: ag review {feature_id} {to_state}",
                ],
                capture_output=True, text=True,
                cwd=str(project_root),
            )
            # Parse HN-ID from blocker.sh output (supports any digit count)
            match = re.search(r"HN-\d+", result.stdout)
            if match:
                hn_id = match.group(0)
        except (OSError, subprocess.SubprocessError):
            pass

    review_data["hn_id"] = hn_id
    review_file.write_text(json.dumps(review_data, indent=2) + "\n")

    return hn_id


def has_pending_review(
    project_root: Path, feature_id: str, to_state: str
) -> bool:
    """Check if a pending review exists for this feature/state."""
    paths = get_paths(project_root)
    review_file = paths.pending_reviews_dir / f"{feature_id}_{to_state}.json"
    return review_file.exists()


def get_pending_reviews(
    project_root: Path, feature_id: Optional[str] = None
) -> list[dict]:
    """List pending reviews, optionally filtered by feature_id."""
    paths = get_paths(project_root)
    reviews_dir = paths.pending_reviews_dir
    if not reviews_dir.exists():
        return []

    results = []
    pattern = f"{feature_id}_*.json" if feature_id else "*.json"
    for review_file in sorted(reviews_dir.glob(pattern)):
        try:
            data = json.loads(review_file.read_text())
            results.append(data)
        except (json.JSONDecodeError, OSError):
            continue
    return results


def resolve_review(
    project_root: Path,
    feature_id: str,
    target_state: str,
    verdict: str,
    reasoning: str = "",
) -> tuple[bool, list[str]]:
    """Resolve a pending review and attempt the transition.

    1. Stores verdict artifact (prevents re-review loop)
    2. Deletes pending review JSON
    3. Resolves HUMAN_NEEDED entry
    4. If approved, calls state machine transition

    Returns (success, messages). Success means the review was resolved
    successfully — both approvals and rejections return True. A rejection
    is a valid resolution; False means an error occurred.
    """
    _validate_feature_id(feature_id)
    paths = get_paths(project_root)
    messages = []

    # Load pending review data
    pending_file = paths.pending_reviews_dir / f"{feature_id}_{target_state}.json"
    if not pending_file.exists():
        return False, [
            f"No pending review for {feature_id} → {target_state}"
        ]

    try:
        review_data = json.loads(pending_file.read_text())
    except (json.JSONDecodeError, OSError) as e:
        return False, [f"Failed to read pending review: {e}"]

    from_state = review_data.get("from_state", "unknown")
    review_setting = review_data.get("review_setting", "unknown")
    review_mode = review_data.get("review_mode", "unknown")
    hn_id = review_data.get("hn_id")

    # 1. Store verdict artifact first (prevents re-review loop)
    #    Write to temp file then rename for atomicity
    verdict_dir = paths.reviews_dir / feature_id
    verdict_dir.mkdir(parents=True, exist_ok=True)
    verdict_file = verdict_dir / f"{from_state}_to_{target_state}.md"
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    verdict_content = (
        f"# Review: {feature_id} {from_state} → {target_state}\n"
        f"- **Verdict**: {verdict}\n"
        f"- **Reviewer**: human\n"
        f"- **Date**: {today}\n"
        f"- **Setting**: {review_setting} (mode: {review_mode})\n"
        f"\n"
        f"## Reasoning\n"
        f"{reasoning if reasoning else 'No reasoning provided.'}\n"
    )
    fd, tmp_path = tempfile.mkstemp(
        dir=str(verdict_dir), suffix=".tmp", prefix=".verdict-"
    )
    try:
        os.write(fd, verdict_content.encode())
        os.close(fd)
        os.rename(tmp_path, str(verdict_file))
    except OSError:
        os.close(fd) if not os.get_inheritable(fd) else None
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
        raise
    messages.append(f"Verdict recorded: {verdict}")

    # 2. Delete pending review JSON
    try:
        pending_file.unlink()
    except OSError:
        messages.append("Warning: Could not remove pending review file")
    messages.append("Pending review cleared")

    # 3. Resolve HUMAN_NEEDED entry
    if hn_id:
        blocker_sh = paths.tools_dir / "blocker.sh"
        if blocker_sh.exists():
            try:
                subprocess.run(
                    [
                        "bash", str(blocker_sh), "resolve",
                        hn_id, f"Review {verdict}: {reasoning or 'resolved'}",
                    ],
                    capture_output=True, text=True,
                    cwd=str(project_root),
                )
            except (OSError, subprocess.SubprocessError):
                messages.append(f"Warning: Could not resolve {hn_id} in HUMAN_NEEDED.md")

    # 4. If approved, execute the transition
    if verdict == "approved":
        from auto.state_machine import FeatureStateMachine, FeatureState
        from auto.gates import register_default_gates

        sm = FeatureStateMachine(project_root=project_root, enforce=True)
        register_default_gates(sm, state_enum=FeatureState)

        target = FeatureState(target_state)
        success, transition_msgs = sm.transition(feature_id, target)
        messages.extend(transition_msgs)
        if not success:
            messages.append("Warning: Review approved but transition failed")
            return False, messages
    else:
        messages.append(f"Review rejected — transition {from_state} → {target_state} blocked")

    return True, messages


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main() -> int:
    """CLI for `ag review`."""
    import argparse

    parser = argparse.ArgumentParser(
        description="Review checkpoint management"
    )
    parser.add_argument(
        "feature_id",
        nargs="?",
        default=None,
        help="Feature ID (e.g., F-0042)",
    )
    parser.add_argument(
        "target_state",
        nargs="?",
        default=None,
        help="Target state to review (e.g., specced)",
    )
    verdict_group = parser.add_mutually_exclusive_group()
    verdict_group.add_argument(
        "--approve",
        action="store_true",
        help="Approve the review (default)",
    )
    verdict_group.add_argument(
        "--reject",
        action="store_true",
        help="Reject the review",
    )
    parser.add_argument(
        "--reason",
        type=str,
        default="",
        help="Reasoning for the verdict",
    )
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path.cwd(),
        help="Project root directory",
    )
    args = parser.parse_args()

    project_root = args.project_root.resolve()

    # List mode: no feature_id
    if not args.feature_id:
        reviews = get_pending_reviews(project_root)
        if not reviews:
            print("No pending reviews.")
            return 0
        print(f"Pending reviews ({len(reviews)}):")
        for r in reviews:
            print(
                f"  {r['feature_id']}: {r['from_state']} → {r['to_state']} "
                f"({r['review_setting']}, mode: {r['review_mode']})"
            )
        return 0

    # Validate feature_id format
    try:
        _validate_feature_id(args.feature_id)
    except ValueError as e:
        print(f"Error: {e}")
        return 1

    # Feature-specific list: no target_state
    if not args.target_state:
        reviews = get_pending_reviews(project_root, args.feature_id)
        if not reviews:
            print(f"No pending reviews for {args.feature_id}.")
            return 0
        print(f"Pending reviews for {args.feature_id}:")
        for r in reviews:
            print(
                f"  {r['from_state']} → {r['to_state']} "
                f"({r['review_setting']}, mode: {r['review_mode']})"
            )
        return 0

    # Resolve mode
    verdict = "rejected" if args.reject else "approved"
    success, messages = resolve_review(
        project_root, args.feature_id, args.target_state,
        verdict, args.reason,
    )
    for msg in messages:
        print(msg)
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
