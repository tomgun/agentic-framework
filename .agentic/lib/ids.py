"""Centralized ID patterns for the Agentic Framework.

Single source of truth for feature ID validation, formatting, and allocation.
All Python consumers should import from this module rather than defining
their own patterns.

@feature F-0004 (consolidated from F-0193)
"""
from __future__ import annotations

import re
from pathlib import Path

# ---------------------------------------------------------------------------
# Feature IDs — matches F-0001 (legacy 4-digit) and F-10000+ (future)
# ---------------------------------------------------------------------------

# Inline reference: captures F-XXXX anywhere in text
FEATURE_ID_RE = re.compile(r"\b(F-\d{4,})\b")

# Markdown header: ## F-XXXX: Title (MULTILINE so ^ matches line starts)
FEATURE_HEADER_RE = re.compile(r"^##\s+(F-\d{4,}):\s*(.+?)\s*$", re.MULTILINE)

# Strict validation: entire string must be a feature ID
FEATURE_ID_STRICT_RE = re.compile(r"^F-\d{4,}$")


def is_valid_feature_id(s: str) -> bool:
    """Check if a string is a valid feature ID (F-0001 through F-99999+)."""
    return bool(FEATURE_ID_STRICT_RE.match(s))


def format_feature_id(n: int) -> str:
    """Format an integer as a feature ID with zero-padding up to 9999.

    F-0001 through F-9999 use zero-padding for sort stability.
    F-10000+ use natural width.
    """
    return f"F-{n:04d}" if n < 10000 else f"F-{n}"


def get_next_feature_id(features_file: Path) -> int:
    """Get the next available feature ID number.

    Scans FEATURES.md for the highest existing ID and returns max + 1.

    Note: not atomic — concurrent operations could allocate overlapping IDs.
    Acceptable because callers (decompose, kickoff) are human-gated.
    """
    if not features_file.exists():
        return 1

    content = features_file.read_text()
    ids = [
        int(m.group(1))
        for m in re.finditer(r"^## F-(\d{4,}):", content, re.MULTILINE)
    ]
    return max(ids) + 1 if ids else 1
