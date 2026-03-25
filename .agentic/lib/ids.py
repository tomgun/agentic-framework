"""Centralized ID patterns for the Agentic Framework.

Single source of truth for feature ID validation, formatting, and allocation.
All Python consumers should import from this module rather than defining
their own patterns.

Supported prefixes: F- (features), DEV- (dev infrastructure), E- (epics).
Supports dotted hierarchical IDs: F-003.1, F-003.1.2 (children start at .1).

@feature F-003 (consolidated from F-0193)
@feature F-005
"""
from __future__ import annotations

import re
from pathlib import Path

# Maximum nesting depth for dotted IDs (root=0, child=1, grandchild=2)
MAX_DEPTH = 2

# ---------------------------------------------------------------------------
# Feature IDs — matches F-001, DEV-001, E-0001 (3-digit+ with optional dotted children)
# Dotted children: F-003.1, F-003.1.2 (never .0 — children start at 1)
# During transition: both 3-digit (F-003) and 4-digit (F-002) accepted.
# ---------------------------------------------------------------------------

# Inline reference: captures F-XXXX / DEV-XXXX / E-XXXX anywhere in text
# Includes dotted children like F-003.1.2
FEATURE_ID_RE = re.compile(r"\b((?:F|DEV|E)-\d{3,}(?:\.[1-9]\d*)*)\b")

# Markdown header: ## F-XXXX: Title  or  ## DEV-XXXX: Title  (MULTILINE)
# Includes dotted children like ## F-003.1: Title
FEATURE_HEADER_RE = re.compile(r"^##\s+((?:F|DEV|E)-\d{3,}(?:\.[1-9]\d*)*):\s*(.+?)\s*$", re.MULTILINE)

# Strict validation: entire string must be an ID
FEATURE_ID_STRICT_RE = re.compile(r"^(?:F|DEV|E)-\d{3,}(?:\.[1-9]\d*)*$")


def is_valid_feature_id(s: str) -> bool:
    """Check if a string is a valid feature ID (F-001, DEV-001, F-003.1, etc.)."""
    return bool(FEATURE_ID_STRICT_RE.match(s))


def get_parent_id(feature_id: str) -> str | None:
    """Get the parent ID of a dotted feature ID.

    F-003.1.2 → F-003.1, F-003.1 → F-003, F-003 → None
    """
    parts = feature_id.rsplit(".", 1)
    return parts[0] if len(parts) > 1 else None


def get_depth(feature_id: str) -> int:
    """Get the nesting depth of a feature ID.

    F-003 → 0 (root), F-003.1 → 1 (child), F-003.1.2 → 2 (grandchild)
    """
    base_match = re.match(r"^(?:F|DEV|E)-\d{3,}", feature_id)
    if not base_match:
        return 0
    suffix = feature_id[base_match.end():]
    if not suffix:
        return 0
    return suffix.count(".")


def get_root_id(feature_id: str) -> str:
    """Get the root (top-level) feature ID.

    F-003.1.2 → F-003, F-003.1 → F-003, F-003 → F-003
    """
    match = re.match(r"^(?:F|DEV|E)-\d{3,}", feature_id)
    return match.group(0) if match else feature_id


def get_next_child_id(parent_id: str, existing_children: list[str]) -> str:
    """Get the next available child ID for a parent.

    F-003 with children [F-003.1, F-003.2] → F-003.3
    F-003.1 with children [F-003.1.1] → F-003.1.2
    """
    if not existing_children:
        return f"{parent_id}.1"

    prefix = f"{parent_id}."
    child_nums = []
    for child in existing_children:
        if child.startswith(prefix):
            suffix = child[len(prefix):]
            if "." not in suffix and suffix.isdigit():
                child_nums.append(int(suffix))

    next_num = max(child_nums) + 1 if child_nums else 1
    return f"{parent_id}.{next_num}"


def format_feature_id(n: int, prefix: str = "F", width: int = 4) -> str:
    """Format an integer as a feature ID with zero-padding.

    Default width=4 for backward compatibility during transition.
    F-001 through F-9999 use zero-padding for sort stability.
    F-10000+ use natural width. Prefix can be F, DEV, or E.
    """
    limit = 10 ** width
    return f"{prefix}-{n:0{width}d}" if n < limit else f"{prefix}-{n}"


def get_next_feature_id(features_file: Path) -> int:
    """Get the next available feature ID number.

    Scans FEATURES.md for the highest existing F- ID and returns max + 1.
    Only counts root-level IDs (ignores dotted children like F-003.1).

    Note: not atomic — concurrent operations could allocate overlapping IDs.
    Acceptable because callers (decompose, kickoff) are human-gated.
    """
    if not features_file.exists():
        return 1

    content = features_file.read_text()
    ids = [
        int(m.group(1))
        for m in re.finditer(r"^## F-(\d{3,}):", content, re.MULTILINE)
        if "." not in m.group(0)
    ]
    return max(ids) + 1 if ids else 1
