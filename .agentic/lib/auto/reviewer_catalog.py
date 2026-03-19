"""
reviewer_catalog.py -- Reviewer role catalog for plan review (F-0236).

Loads reviewer roles from reviewer_roles.json, resolves active reviewers
from STACK.md settings, ensures required roles are always present.

Usage:
    from auto.reviewer_catalog import get_active_reviewers, ReviewerRole
    reviewers = get_active_reviewers(project_root)
"""
from __future__ import annotations

import json
import sys
from dataclasses import dataclass
from pathlib import Path

_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
from settings import get_setting  # noqa: E402


@dataclass
class ReviewerRole:
    """A reviewer role from the catalog."""
    name: str
    agent_file: str
    mandate: str
    required: bool
    model_tier: str


def load_catalog(project_root: Path | None = None) -> dict[str, ReviewerRole]:
    """Load reviewer roles from reviewer_roles.json.

    Falls back to the bundled catalog if no project-level override exists.
    """
    # Check project-level override first
    if project_root:
        project_catalog = (
            project_root / ".agentic" / "lib" / "agents"
            / "shared" / "reviewer_roles.json"
        )
        if project_catalog.exists():
            return _parse_catalog(project_catalog)

    # Fall back to bundled catalog
    bundled = (
        Path(__file__).resolve().parent.parent
        / "agents" / "shared" / "reviewer_roles.json"
    )
    if bundled.exists():
        return _parse_catalog(bundled)

    return {}


def _parse_catalog(catalog_file: Path) -> dict[str, ReviewerRole]:
    """Parse a reviewer_roles.json file into ReviewerRole objects."""
    try:
        data = json.loads(catalog_file.read_text())
    except (json.JSONDecodeError, OSError):
        return {}

    roles = {}
    for name, info in data.get("roles", {}).items():
        roles[name] = ReviewerRole(
            name=name,
            agent_file=info.get("agent_file", ""),
            mandate=info.get("mandate", ""),
            required=info.get("required", False),
            model_tier=info.get("model_tier", "mid-tier"),
        )
    return roles


def get_setting_list(project_root: Path, key: str, default: str = "") -> list[str]:
    """Parse a setting that can be comma-separated or bracket-list format.

    Examples:
        "critic,advocate" → ["critic", "advocate"]
        "[critic, advocate, security_expert]" → ["critic", "advocate", "security_expert"]
        "" → []
    """
    raw = get_setting(project_root, key, default)
    if not raw:
        return []

    # Strip brackets if present
    raw = raw.strip()
    if raw.startswith("[") and raw.endswith("]"):
        raw = raw[1:-1]

    # Split on comma, strip whitespace
    items = [item.strip() for item in raw.split(",")]
    return [item for item in items if item]


def get_active_reviewers(project_root: Path) -> list[ReviewerRole]:
    """Get the list of active reviewer roles for plan review.

    1. Reads plan_review_reviewers from STACK.md
    2. Loads catalog
    3. Always includes required=true roles
    4. Warns on unknown role names (skips them)
    """
    catalog = load_catalog(project_root)
    if not catalog:
        return []

    requested = get_setting_list(
        project_root, "plan_review_reviewers", "critic,advocate",
    )

    active: list[ReviewerRole] = []
    seen: set[str] = set()

    # Add requested roles (skip duplicates)
    for name in requested:
        if name in seen:
            continue
        if name in catalog:
            active.append(catalog[name])
            seen.add(name)
        else:
            print(
                f"  Warning: unknown reviewer role '{name}' — skipping",
                file=sys.stderr,
            )

    # Ensure required roles are always present
    for name, role in catalog.items():
        if role.required and name not in seen:
            active.insert(0, role)  # required roles go first
            seen.add(name)

    return active
