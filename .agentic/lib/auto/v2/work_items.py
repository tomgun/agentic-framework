"""
work_items.py — Per-work-item directory management.

Each feature gets a directory at .agentic/work/F-XXXX/ containing:
  - item.yaml: metadata, status, transition log
  - plan.md, spec.md, review.md, journal.md, etc.
"""
from __future__ import annotations

import os
import sys
import tempfile
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional

from .config import _load_yaml

# ---------------------------------------------------------------------------
# YAML writing (minimal, for item.yaml)
# ---------------------------------------------------------------------------


def _dump_yaml(data: dict, indent: int = 0) -> str:
    """Minimal YAML serializer for item.yaml. Handles our subset."""
    lines: list[str] = []
    prefix = "  " * indent

    for key, value in data.items():
        if value is None:
            lines.append(f"{prefix}{key}:")
        elif isinstance(value, bool):
            lines.append(f"{prefix}{key}: {'true' if value else 'false'}")
        elif isinstance(value, (int, float)):
            lines.append(f"{prefix}{key}: {value}")
        elif isinstance(value, str):
            # Quote strings that contain special chars or quotes
            needs_quoting = (
                any(c in value for c in ':{}\n[]#,\'"')
                or value.startswith(("- ", "  "))
            )
            if needs_quoting:
                escaped = value.replace("\\", "\\\\").replace('"', '\\"')
                lines.append(f'{prefix}{key}: "{escaped}"')
            else:
                lines.append(f"{prefix}{key}: {value}")
        elif isinstance(value, list):
            if not value:
                lines.append(f"{prefix}{key}: []")
            elif isinstance(value[0], dict):
                lines.append(f"{prefix}{key}:")
                for item in value:
                    # Inline dict for transition log
                    parts = []
                    for k, v in item.items():
                        if isinstance(v, bool):
                            parts.append(f"{k}: {'true' if v else 'false'}")
                        elif isinstance(v, str) and any(c in v for c in ':{}\n[]#,\'"'):
                            escaped = v.replace("\\", "\\\\").replace('"', '\\"')
                            parts.append(f'{k}: "{escaped}"')
                        else:
                            parts.append(f"{k}: {v}")
                    lines.append(f"{prefix}  - {{{', '.join(parts)}}}")
            else:
                lines.append(f"{prefix}{key}:")
                for item in value:
                    lines.append(f"{prefix}  - {item}")
        elif isinstance(value, dict):
            lines.append(f"{prefix}{key}:")
            lines.append(_dump_yaml(value, indent + 1))
        else:
            lines.append(f"{prefix}{key}: {value}")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# WorkItem data class
# ---------------------------------------------------------------------------


@dataclass
class WorkItem:
    """In-memory representation of a work item."""
    id: str
    title: str
    status: str
    mode: str
    profile: str
    created: str
    type: str = "feature"
    priority: int = 0
    branch: Optional[str] = None
    parent: Optional[str] = None
    updated: Optional[str] = None
    transitions: list[dict[str, Any]] = field(default_factory=list)
    artifacts: dict[str, dict[str, Any]] = field(default_factory=dict)

    @staticmethod
    def from_dict(d: dict) -> WorkItem:
        return WorkItem(
            id=d["id"],
            title=d["title"],
            status=d["status"],
            mode=d["mode"],
            profile=d["profile"],
            created=d["created"],
            type=d.get("type", "feature"),
            priority=d.get("priority", 0),
            branch=d.get("branch"),
            parent=d.get("parent"),
            updated=d.get("updated"),
            transitions=d.get("transitions", []),
            artifacts=d.get("artifacts", {}),
        )

    def to_dict(self) -> dict:
        d: dict[str, Any] = {
            "id": self.id,
            "title": self.title,
            "type": self.type,
            "status": self.status,
            "mode": self.mode,
            "profile": self.profile,
            "priority": self.priority,
            "created": self.created,
        }
        if self.updated:
            d["updated"] = self.updated
        if self.branch:
            d["branch"] = self.branch
        if self.parent:
            d["parent"] = self.parent
        if self.transitions:
            d["transitions"] = self.transitions
        if self.artifacts:
            d["artifacts"] = self.artifacts
        return d

    def add_transition(
        self,
        from_state: str,
        to_state: str,
        by: str = "agent",
        reason: Optional[str] = None,
        skipped: bool = False,
    ) -> None:
        """Record a transition in the append-only log."""
        entry: dict[str, Any] = {
            "from": from_state,
            "to": to_state,
            "at": datetime.now(timezone.utc).isoformat(),
            "by": by,
        }
        if reason:
            entry["reason"] = reason
        if skipped:
            entry["skipped"] = True
        self.transitions.append(entry)
        self.status = to_state
        self.updated = datetime.now(timezone.utc).strftime("%Y-%m-%d")


# ---------------------------------------------------------------------------
# Work directory operations
# ---------------------------------------------------------------------------


def work_dir(project_root: Path) -> Path:
    """Return the base work directory."""
    return project_root / ".agentic" / "work"


def item_dir(project_root: Path, feature_id: str) -> Path:
    """Return the directory for a specific work item."""
    return work_dir(project_root) / feature_id


def item_yaml_path(project_root: Path, feature_id: str) -> Path:
    """Return the path to a work item's item.yaml."""
    return item_dir(project_root, feature_id) / "item.yaml"


def artifact_path(project_root: Path, feature_id: str, artifact_name: str) -> Path:
    """Return the path to a work item's artifact file."""
    return item_dir(project_root, feature_id) / artifact_name


def exists(project_root: Path, feature_id: str) -> bool:
    """Check if a work item directory exists."""
    return item_yaml_path(project_root, feature_id).exists()


def create(
    project_root: Path,
    feature_id: str,
    title: str,
    mode: str = "formal",
    profile: str = "guided",
    item_type: str = "feature",
    priority: int = 0,
    parent: Optional[str] = None,
) -> WorkItem:
    """Create a new work item directory and item.yaml."""
    d = item_dir(project_root, feature_id)
    d.mkdir(parents=True, exist_ok=True)

    now = datetime.now(timezone.utc)
    item = WorkItem(
        id=feature_id,
        title=title,
        status="idea",
        mode=mode,
        profile=profile,
        created=now.strftime("%Y-%m-%d"),
        type=item_type,
        priority=priority,
        parent=parent,
        updated=now.strftime("%Y-%m-%d"),
        transitions=[],
    )

    save(project_root, item)
    return item


def load(project_root: Path, feature_id: str) -> WorkItem:
    """Load a work item from its item.yaml."""
    path = item_yaml_path(project_root, feature_id)
    if not path.exists():
        raise FileNotFoundError(f"Work item not found: {feature_id} (expected {path})")

    raw = _load_yaml(path)
    return WorkItem.from_dict(raw)


def save(project_root: Path, item: WorkItem) -> None:
    """Save a work item to its item.yaml atomically.

    Uses write-to-temp-then-rename to prevent corruption if the process
    dies mid-write (e.g., multi-agent race or crash).
    """
    path = item_yaml_path(project_root, item.id)
    path.parent.mkdir(parents=True, exist_ok=True)
    content = _dump_yaml(item.to_dict())

    # Atomic write: write to temp file in same directory, then rename
    fd, tmp_path = tempfile.mkstemp(
        dir=str(path.parent), prefix=".item-", suffix=".yaml.tmp"
    )
    closed = False
    try:
        os.write(fd, (content + "\n").encode())
        os.fsync(fd)
        os.close(fd)
        closed = True
        os.rename(tmp_path, str(path))
    except Exception:
        if not closed:
            os.close(fd)
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise


def list_items(project_root: Path) -> list[WorkItem]:
    """List all work items."""
    base = work_dir(project_root)
    if not base.exists():
        return []

    items = []
    for d in sorted(base.iterdir()):
        if d.is_dir() and (d / "item.yaml").exists():
            try:
                items.append(load(project_root, d.name))
            except Exception:
                continue
    return items


def list_by_status(project_root: Path, status: str) -> list[WorkItem]:
    """List work items with a specific status."""
    return [item for item in list_items(project_root) if item.status == status]


def has_artifact(project_root: Path, feature_id: str, artifact_name: str) -> bool:
    """Check if a specific artifact file exists for a work item."""
    return artifact_path(project_root, feature_id, artifact_name).exists()
