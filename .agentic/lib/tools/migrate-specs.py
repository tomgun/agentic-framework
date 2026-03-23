#!/usr/bin/env python3
"""migrate-specs.py — Convert markdown acceptance criteria to YAML contracts.

Usage:
    python3 migrate-specs.py --project-root <dir> [--dry-run] [--archive]

Reads .agentic/spec/acceptance/F-*.md files and generates corresponding
.agentic/spec/contracts/F-*.yaml contracts. Optionally archives old files.
"""

import argparse
import re
import sys
from pathlib import Path

# Allow importing from lib/
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from contracts import Contract, Assertion, save_contract


# Patterns for extracting ACs from markdown
AC_PATTERNS = [
    # **AC-001**: text  or  **AC-001** text
    re.compile(r"\*\*AC-?(\d+)\*\*:?\s*(.+)"),
    # - [ ] AC-001: text  or  - [ ] AC1: text
    re.compile(r"-\s*\[[ x]\]\s*AC-?(\d+):?\s*(.+)"),
    # AC-001: text  (plain)
    re.compile(r"^AC-?(\d+):?\s*(.+)", re.MULTILINE),
]

# Extract feature name from heading: # F-0004: Feature Name
TITLE_RE = re.compile(r"^#\s*F-\d+:\s*(.+?)(?:\s*-\s*Acceptance Criteria)?$", re.MULTILINE)

# Extract behavior/description section
BEHAVIOR_RE = re.compile(
    r"##\s*Behavior.*?\n(.*?)(?=\n##|\Z)", re.DOTALL | re.IGNORECASE
)

# Extract profile from ## Verification section
PROFILE_RE = re.compile(r"\*\*Profile\*\*:\s*(\w+)", re.IGNORECASE)

# Extract test file references
TEST_RE = re.compile(r"`([^`]+(?:\.py|\.sh|\.ts|\.js)[^`]*)`")


def parse_acceptance_md(path: Path) -> dict:
    """Parse a markdown acceptance criteria file into structured data."""
    text = path.read_text(encoding="utf-8")
    feature_id = path.stem  # e.g. "F-0004"

    # Extract name
    m = TITLE_RE.search(text)
    name = m.group(1).strip() if m else feature_id

    # Extract description from Behavior section or Feature line
    description = ""
    m = BEHAVIOR_RE.search(text)
    if m:
        desc_text = m.group(1).strip()
        # Remove HTML comments
        desc_text = re.sub(r"<!--.*?-->", "", desc_text, flags=re.DOTALL).strip()
        if desc_text and not desc_text.startswith("["):
            description = desc_text
    if not description:
        # Try **Feature**: line
        m = re.search(r"\*\*Feature\*\*:\s*(.+)", text)
        if m:
            description = m.group(1).strip()
    if not description:
        description = f"TODO: Describe {name}"

    # Extract assertions
    assertions = []
    seen_ids = set()
    for pattern in AC_PATTERNS:
        for m in pattern.finditer(text):
            ac_num = m.group(1).lstrip("0") or "1"
            ac_id = f"AC-{int(ac_num):03d}"
            if ac_id in seen_ids:
                continue
            seen_ids.add(ac_id)
            ac_text = m.group(2).strip()
            # Remove trailing markdown artifacts
            ac_text = re.sub(r"\s*\(NFR-\d+\)\s*$", "", ac_text)
            assertions.append(
                Assertion(
                    id=ac_id,
                    text=ac_text,
                    type="structural",
                    draft=True,
                )
            )

    # Sort by AC number
    assertions.sort(key=lambda a: int(a.id.split("-")[1]))

    # Ensure at least one assertion
    if not assertions:
        assertions = [
            Assertion(
                id="AC-001",
                text="TODO: Extract acceptance criteria from source",
                type="structural",
                draft=True,
            )
        ]

    # Extract profile
    profile = "both"
    m = PROFILE_RE.search(text)
    if m:
        p = m.group(1).lower()
        if p in ("formal", "discovery", "both"):
            profile = p
        elif "formal" in p:
            profile = "formal"

    # Extract test references
    tests = TEST_RE.findall(text)
    # Filter to likely test paths
    tests = [t for t in tests if "test" in t.lower() or t.startswith("tests/")]

    return {
        "id": feature_id,
        "name": name,
        "description": description,
        "assertions": assertions,
        "profile": profile,
        "tests": tests,
    }


def get_features_status(project_root: Path) -> dict[str, str]:
    """Read FEATURES.md to get status for each feature ID."""
    features_file = project_root / ".agentic" / "spec" / "FEATURES.md"
    if not features_file.exists():
        return {}

    statuses = {}
    text = features_file.read_text(encoding="utf-8")

    # Heading format: ## F-0004: Name \n **Status**: shipped
    for m in re.finditer(
        r"##\s+(F-\d+):.*?\n.*?\*\*Status\*\*:\s*(\w+)", text, re.DOTALL
    ):
        statuses[m.group(1)] = m.group(2)

    # Table format: | F-0004 | Name | shipped |
    for m in re.finditer(r"\|\s*(F-\d+)\s*\|[^|]*\|\s*(\w+)\s*\|", text):
        if m.group(1) not in statuses:
            statuses[m.group(1)] = m.group(2)

    return statuses


def status_to_lifecycle(status: str) -> str:
    """Map FEATURES.md status to contract lifecycle."""
    mapping = {
        "planned": "exploring",
        "specced": "specifying",
        "criteria_set": "specifying",
        "tests_written": "implementing",
        "implementing": "implementing",
        "in_progress": "implementing",
        "verified": "shipping",
        "documented": "shipping",
        "committed": "shipping",
        "shipped": "shipped",
        "deprecated": "deprecated",
    }
    return mapping.get(status, "exploring")


def status_to_protection(lifecycle: str) -> str:
    """Determine protection level from lifecycle."""
    if lifecycle == "shipped":
        return "advisory"  # Start as advisory; user promotes to contract
    if lifecycle in ("implementing", "verifying", "shipping"):
        return "advisory"
    return "none"


def migrate_one(
    md_path: Path,
    contracts_dir: Path,
    statuses: dict[str, str],
    dry_run: bool = False,
) -> tuple[bool, str]:
    """Migrate one markdown AC file to a YAML contract. Returns (created, message)."""
    feature_id = md_path.stem
    contract_path = contracts_dir / f"{feature_id}.yaml"

    if contract_path.exists():
        return False, f"  SKIP {feature_id}: contract already exists"

    parsed = parse_acceptance_md(md_path)

    status = statuses.get(feature_id, "planned")
    lifecycle = status_to_lifecycle(status)
    protection = status_to_protection(lifecycle)

    # Attach extracted test references to assertions
    if parsed["tests"]:
        for assertion in parsed["assertions"]:
            assertion.tests = list(parsed["tests"])

    contract = Contract(
        id=parsed["id"],
        name=parsed["name"],
        lifecycle=lifecycle,
        description=parsed["description"],
        assertions=parsed["assertions"],
        protection=protection,
        profile=parsed["profile"],
    )

    if dry_run:
        ac_count = len(contract.assertions)
        return True, f"  WOULD CREATE {feature_id}: {contract.name} ({lifecycle}, {ac_count} ACs)"

    save_contract(contract, contract_path)
    ac_count = len(contract.assertions)
    return True, f"  NEW  {feature_id}: {contract.name} ({lifecycle}, {ac_count} ACs)"


def main():
    parser = argparse.ArgumentParser(description="Migrate markdown ACs to YAML contracts")
    parser.add_argument("--project-root", required=True, help="Project root directory")
    parser.add_argument("--dry-run", action="store_true", help="Preview without writing files")
    parser.add_argument("--archive", action="store_true", help="Move markdown files to docs/archive/acceptance/")
    parser.add_argument("--feature", help="Migrate a single feature (e.g. F-0004)")
    args = parser.parse_args()

    root = Path(args.project_root).resolve()
    acceptance_dir = root / ".agentic" / "spec" / "acceptance"
    contracts_dir = root / ".agentic" / "spec" / "contracts"
    archive_dir = root / "docs" / "archive" / "acceptance"

    if not acceptance_dir.is_dir():
        print("No acceptance directory found at .agentic/spec/acceptance/")
        print("Nothing to migrate.")
        return 0

    # Find markdown files to migrate
    if args.feature:
        md_files = list(acceptance_dir.glob(f"{args.feature}.md"))
        if not md_files:
            print(f"No acceptance file found for {args.feature}")
            return 1
    else:
        md_files = sorted(acceptance_dir.glob("F-*.md"))

    if not md_files:
        print("No acceptance criteria files found to migrate.")
        return 0

    contracts_dir.mkdir(parents=True, exist_ok=True)
    statuses = get_features_status(root)

    print(f"{'[DRY RUN] ' if args.dry_run else ''}Migrating {len(md_files)} acceptance files to YAML contracts")
    print(f"  Source: {acceptance_dir}")
    print(f"  Target: {contracts_dir}")
    print()

    created = 0
    skipped = 0
    errors = 0

    for md_file in md_files:
        try:
            was_created, msg = migrate_one(md_file, contracts_dir, statuses, dry_run=args.dry_run)
            print(msg)
            if was_created:
                created += 1
            else:
                skipped += 1
        except Exception as e:
            print(f"  ERROR {md_file.stem}: {e}")
            errors += 1

    print()
    print(f"Results: {created} created, {skipped} skipped, {errors} errors")

    # Archive if requested
    if args.archive and not args.dry_run and created > 0:
        archive_dir.mkdir(parents=True, exist_ok=True)
        archived = 0
        for md_file in md_files:
            feature_id = md_file.stem
            contract_path = contracts_dir / f"{feature_id}.yaml"
            if contract_path.exists():
                dest = archive_dir / md_file.name
                md_file.rename(dest)
                archived += 1
        print(f"Archived {archived} markdown files to {archive_dir}")

    if created > 0 and not args.dry_run:
        print()
        print("Next steps:")
        print("  1. Review generated contracts: ag contract list")
        print("  2. Validate contracts: ag contract validate")
        print("  3. Refine assertions: ag contract set F-XXXX lifecycle specifying")
        print("  4. Remove draft flags as assertions are verified")

    return 0 if errors == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
