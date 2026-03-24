"""Centralized ID patterns for the Agentic Framework.

Single source of truth for feature ID validation, formatting, and allocation.
All Python consumers should import from this module rather than defining
their own patterns.

Supported prefixes: F- (features), DEV- (dev infrastructure), E- (epics).

@feature F-0004 (consolidated from F-0193)
"""
from __future__ import annotations

import re
from pathlib import Path

# ---------------------------------------------------------------------------
# Feature IDs — matches F-0001, DEV-0001, E-0001 (4-digit+)
# ---------------------------------------------------------------------------

# Inline reference: captures F-XXXX / DEV-XXXX / E-XXXX anywhere in text
FEATURE_ID_RE = re.compile(r"\b((?:F|DEV|E)-\d{4,})\b")

# Markdown header: ## F-XXXX: Title  or  ## DEV-XXXX: Title  (MULTILINE)
FEATURE_HEADER_RE = re.compile(r"^##\s+((?:F|DEV|E)-\d{4,}):\s*(.+?)\s*$", re.MULTILINE)

# Strict validation: entire string must be an ID
FEATURE_ID_STRICT_RE = re.compile(r"^(?:F|DEV|E)-\d{4,}$")


def is_valid_feature_id(s: str) -> bool:
    """Check if a string is a valid feature ID (F-0001, DEV-0001, E-0001, etc.)."""
    return bool(FEATURE_ID_STRICT_RE.match(s))


def format_feature_id(n: int, prefix: str = "F") -> str:
    """Format an integer as a feature ID with zero-padding up to 9999.

    F-0001 through F-9999 use zero-padding for sort stability.
    F-10000+ use natural width. Prefix can be F, DEV, or E.
    """
    return f"{prefix}-{n:04d}" if n < 10000 else f"{prefix}-{n}"


def get_next_feature_id(features_file: Path) -> int:
    """Get the next available feature ID number.

    Scans FEATURES.md for the highest existing F- ID and returns max + 1.

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
