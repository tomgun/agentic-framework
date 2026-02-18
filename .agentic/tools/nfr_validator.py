"""NFR content validation — validates NFR.md field content beyond cross-references.

Extracted from doctor.py to keep it under the 1200-line complexity limit.
"""
from __future__ import annotations

import re
from pathlib import Path

VALID_NFR_CATEGORIES = {
    "performance", "security", "scalability", "usability",
    "reliability", "maintainability", "compliance",
}

VALID_NFR_STATUSES = {"unknown", "partial", "met", "violated"}

PLACEHOLDER_RE = re.compile(r"\s*<!--.*?-->\s*", re.DOTALL)


def _strip_trailing_comment(value: str) -> str:
    """Strip trailing HTML comments from a field value.

    'unknown  <!-- unknown | partial | met | violated -->' -> 'unknown'
    """
    return re.sub(r"\s*<!--.*?-->\s*$", "", value).strip()


def _is_placeholder(value: str) -> bool:
    """Check if a field value is entirely a placeholder comment."""
    return bool(PLACEHOLDER_RE.fullmatch(value))


def parse_nfr_entries(md: str) -> list[dict]:
    """Parse NFR.md into structured entries using state-machine approach.

    Returns list of dicts with keys: id, category, how_to_measure,
    tests, ci, current_status.
    """
    entries = []
    current = None
    in_where_enforced = False

    for line in md.splitlines():
        # Step 1: NFR header
        m = re.match(r"^##\s+(NFR-\d{4}):\s*(.*)", line)
        if m:
            if current:
                entries.append(current)
            current = {
                "id": m.group(1),
                "name": m.group(2).strip(),
                "category": None,
                "how_to_measure": None,
                "tests": None,
                "ci": None,
                "current_status": None,
            }
            in_where_enforced = False
            continue

        if not current:
            continue

        stripped = line.strip()

        # Step 2-3: Top-level fields
        if stripped.startswith("- Category:"):
            current["category"] = stripped.split(":", 1)[1].strip()
            in_where_enforced = False
        elif stripped.startswith("- Statement:"):
            in_where_enforced = False
        elif stripped.startswith("- How to measure:"):
            current["how_to_measure"] = stripped.split(":", 1)[1].strip()
            in_where_enforced = False
        elif stripped.startswith("- Where enforced:"):
            in_where_enforced = True
        elif stripped.startswith("- Current status:"):
            raw = stripped.split(":", 1)[1].strip()
            current["current_status"] = _strip_trailing_comment(raw)
            in_where_enforced = False
        elif stripped.startswith("- Notes:"):
            in_where_enforced = False
        elif stripped.startswith("- Applies to:"):
            in_where_enforced = False
        # Step 5-6: Nested under "Where enforced:"
        elif in_where_enforced and stripped.startswith("- Tests:"):
            current["tests"] = stripped.split(":", 1)[1].strip()
        elif in_where_enforced and stripped.startswith("- CI:"):
            current["ci"] = stripped.split(":", 1)[1].strip()

    if current:
        entries.append(current)

    return entries


def validate_nfr_content(root: Path) -> list[str]:
    """Validate NFR.md field content (not just cross-references)."""
    issues = []

    nfr_path = root / "spec" / "NFR.md"
    if not nfr_path.exists():
        return []

    try:
        nfr_md = nfr_path.read_text(encoding="utf-8")
    except Exception:
        return []

    entries = parse_nfr_entries(nfr_md)

    for entry in entries:
        nfr_id = entry["id"]

        # Validate Category
        cat = entry.get("category")
        if cat and not _is_placeholder(cat):
            if cat.lower() not in VALID_NFR_CATEGORIES:
                issues.append(
                    f"{nfr_id}: invalid category '{cat}' "
                    f"(valid: {', '.join(sorted(VALID_NFR_CATEGORIES))})"
                )

        # Validate "How to measure" is non-placeholder
        htm = entry.get("how_to_measure")
        if htm and _is_placeholder(htm):
            issues.append(
                f"{nfr_id}: 'How to measure' is still a placeholder"
            )

        # Validate "Current status" enum
        status = entry.get("current_status")
        if status and status not in VALID_NFR_STATUSES:
            issues.append(
                f"{nfr_id}: invalid status '{status}' "
                f"(valid: {', '.join(sorted(VALID_NFR_STATUSES))})"
            )

        # Validate "Where enforced: Tests:" file paths exist
        tests_val = entry.get("tests")
        if tests_val and not _is_placeholder(tests_val):
            # Extract file paths (ignore test::method suffixes)
            for part in re.split(r"[,;]", tests_val):
                part = part.strip()
                if not part or part.lower() in {"none", "n/a", "manual"}:
                    continue
                # Strip ::method or (description) suffixes
                file_path = re.split(r"::|[\(\)]", part)[0].strip()
                file_path = file_path.strip("`")
                if file_path and not (root / file_path).exists():
                    issues.append(
                        f"{nfr_id}: test path '{file_path}' does not exist"
                    )

        # Check acceptance file exists for non-unknown NFRs
        status = entry.get("current_status")
        if status and status != "unknown":
            acc_file = root / "spec" / "acceptance" / f"{nfr_id}.md"
            if not acc_file.exists():
                issues.append(
                    f"{nfr_id}: acceptance file spec/acceptance/{nfr_id}.md not found"
                )

    return issues
