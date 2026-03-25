#!/usr/bin/env python3
"""
F-0184 Phase 2: Clean Renumber Script

Renames all live feature IDs from 4-digit (F-0001) to 3-digit sequential (F-001)
using the mapping in renumber_mapping.json.

Algorithm:
  1. Load mapping, sort longest-first to prevent substring collisions
  2. For contract YAML files: parse structurally, update id/parent/children fields,
     skip consolidated_from and nfr_refs
  3. For all other files: word-boundary regex replacement
  4. Rename contract files via git mv
  5. Validate afterwards with validate_framework.sh + pytest

Exclusions:
  - consolidated_from arrays (dead IDs / historical tombstones)
  - nfr_refs arrays (NFR IDs unchanged)
  - docs/archive/ (historical snapshots)
  - .agentic/journal/ (historical references)
  - .git/ directory
  - Binary files
  - This script itself and the mapping file

Usage:
  python3 renumber.py [--dry-run] [--verbose] [--verify] [--project-root PATH]
"""

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path


def load_mapping(mapping_path: Path) -> tuple[dict[str, str], list[str]]:
    """Load the old→new ID mapping and optional exclude_dirs list."""
    with open(mapping_path) as f:
        data = json.load(f)
    exclude_dirs = data.get("exclude_dirs", [])
    return data["mapping"], exclude_dirs


def sort_replacements(mapping: dict[str, str]) -> list[tuple[str, str]]:
    """Sort replacements longest-first to prevent substring collisions.
    E.g., F-0302 must be replaced before F-0003."""
    return sorted(mapping.items(), key=lambda x: len(x[0]), reverse=True)


def build_regex(old_ids: list[str]) -> re.Pattern:
    """Build a single compiled regex that matches any old ID with word boundaries.

    Uses negative lookbehind/lookahead to avoid matching inside longer IDs:
    - Lookbehind: reject if preceded by digit or dot (prevents matching suffix of longer ID)
    - Lookahead: reject if followed by digit OR dot+digit (prevents matching inside
      dotted child IDs like F-0003.1). Allows dot+letter (F-0101.yaml is fine).
    """
    # Escape each ID and join with alternation, longest first
    escaped = [re.escape(oid) for oid in old_ids]
    pattern = r"(?<![0-9.])(" + "|".join(escaped) + r")(?!\d|\.\d)"
    return re.compile(pattern)


# --- YAML-aware contract processing ---

# Lines we must NOT rename (dead IDs, NFR refs, migration metadata)
_YAML_SKIP_FIELDS = re.compile(
    r"^(consolidated_from|nfr_refs)\s*:"
)

# Lines in YAML that are migration metadata (reason/description referencing old IDs)
_YAML_MIGRATION_TEXT = re.compile(
    r"^\s*(reason|description)\s*:"
)


def process_contract_yaml(content: str, mapping_dict: dict[str, str],
                          regex: re.Pattern) -> str:
    """Process a contract YAML file with field-aware replacement.

    Strategy: go line-by-line. Track whether we're inside a consolidated_from
    or nfr_refs block (which are YAML arrays). Only replace in safe lines.
    """
    lines = content.split("\n")
    result = []
    in_skip_block = False

    for line in lines:
        stripped = line.lstrip()

        # Detect start of a skip block (consolidated_from: or nfr_refs:)
        if _YAML_SKIP_FIELDS.match(stripped):
            in_skip_block = True
            result.append(line)
            continue

        # Detect end of skip block: a new top-level key (not indented list item)
        if in_skip_block:
            if stripped and not stripped.startswith("-") and not stripped.startswith("#"):
                # New field at top level — end skip block
                in_skip_block = False
            else:
                # Still inside skip block — don't replace
                result.append(line)
                continue

        # Safe line — apply replacements
        result.append(regex.sub(lambda m: mapping_dict[m.group(0)], line))

    return "\n".join(result)


_NORENUMBER = "norenumber"


def process_text_file(content: str, mapping_dict: dict[str, str],
                      regex: re.Pattern) -> str:
    """Process a generic text file with word-boundary regex replacement.

    Lines containing '# norenumber' or '// norenumber' are skipped.
    """
    lines = content.split("\n")
    result = []
    for line in lines:
        if _NORENUMBER in line:
            result.append(line)
        else:
            result.append(regex.sub(lambda m: mapping_dict[m.group(0)], line))
    return "\n".join(result)


def count_replacements(old_content: str, new_content: str) -> int:
    """Count actual replacements by diffing line-by-line."""
    old_lines = old_content.split("\n")
    new_lines = new_content.split("\n")
    count = 0
    for old_line, new_line in zip(old_lines, new_lines):
        if old_line != new_line:
            count += 1
    return count


# --- File discovery ---

# Extensions to process
TEXT_EXTENSIONS = {
    ".py", ".sh", ".md", ".json", ".yaml", ".yml",
    ".txt", ".toml", ".cfg", ".ini", ".html", ".css", ".js", ".ts",
}

# Paths to skip entirely (relative to project root)
SKIP_DIRS = {
    ".git",
    "docs/archive",
    ".agentic/journal",
    "node_modules",
    "__pycache__",
    ".venv",
    ".agentic/lib/tools/renumber.py",  # This script
    ".agentic/lib/tools/renumber_mapping.json",  # The mapping
}

# File patterns to skip
SKIP_FILES = {
    "renumber.py",
    "renumber_mapping.json",
}

# Test files that use synthetic feature IDs as fixtures (not real feature references).
# These create temporary project dirs with IDs like F-0001 that collide with real features.
SKIP_PATHS_SUFFIX = {
    "tests/test_ids.py",
    "tests/test_kickoff.py",
    "tests/test_phase_checker.py",
}


def should_skip(path: Path, project_root: Path) -> bool:
    """Check if a file should be skipped."""
    rel = path.relative_to(project_root)
    rel_str = str(rel)

    # Skip directories
    for skip_dir in SKIP_DIRS:
        if rel_str == skip_dir or rel_str.startswith(skip_dir + "/"):
            return True

    # Skip specific files
    if path.name in SKIP_FILES:
        return True

    # Skip files by path suffix (utility test files with generic ID examples)
    for suffix in SKIP_PATHS_SUFFIX:
        if rel_str.endswith(suffix):
            return True

    return False


def is_text_file(path: Path) -> bool:
    """Check if file is a text file we should process."""
    return path.suffix.lower() in TEXT_EXTENSIONS


def is_contract_yaml(path: Path, project_root: Path) -> bool:
    """Check if file is a contract YAML in spec/contracts/."""
    rel = str(path.relative_to(project_root))
    return rel.startswith(".agentic/spec/contracts/") and path.suffix in (".yaml", ".yml")


def _detect_exclude_dirs(project_root: Path) -> set[str]:
    """Auto-detect top-level directories that are separate projects.

    A directory is excluded if it contains its own package.json, .agentic/,
    or is itself a git submodule.
    """
    exclude = set()
    for entry in project_root.iterdir():
        if not entry.is_dir() or entry.name.startswith("."):
            continue
        # Has its own package.json or .agentic/ → separate project
        if (entry / "package.json").exists() or (entry / ".agentic").exists():
            exclude.add(entry.name)
        # Contains sub-projects (like agentic-tests/)
        if any((entry / child / "package.json").exists() for child in entry.iterdir()
               if child.is_dir()):
            exclude.add(entry.name)
    return exclude


def find_files(project_root: Path, extra_exclude_dirs: set[str] | None = None) -> list[Path]:
    """Find all text files to process."""
    auto_exclude = _detect_exclude_dirs(project_root)
    skip_top = auto_exclude | (extra_exclude_dirs or set())

    files = []
    for root, dirs, filenames in os.walk(project_root):
        root_path = Path(root)

        # Prune directories
        dirs[:] = [
            d for d in dirs
            if not should_skip(root_path / d, project_root)
            and not (root_path == project_root and d in skip_top)
        ]

        for fname in filenames:
            fpath = root_path / fname
            if should_skip(fpath, project_root):
                continue
            if is_text_file(fpath):
                files.append(fpath)

    return sorted(files)


# --- Git operations ---

def git_mv(old_path: Path, new_path: Path, project_root: Path, dry_run: bool) -> None:
    """Rename a file using git mv to preserve history."""
    if dry_run:
        print(f"  [dry-run] git mv {old_path.relative_to(project_root)} → {new_path.relative_to(project_root)}")
        return
    subprocess.run(
        ["git", "mv", str(old_path), str(new_path)],
        cwd=project_root,
        check=True,
        capture_output=True,
    )


# --- Verify mode ---

def run_verify(project_root: Path, mapping: dict[str, str],
               extra_exclude_dirs: set[str] | None = None,
               verbose: bool = False) -> bool:
    """Verify no old IDs remain in the codebase (post-renumber check).

    Uses the same file discovery and exclusion rules as run_renumber.
    """
    old_ids = list(mapping.keys())
    regex = build_regex(old_ids)
    files = find_files(project_root, extra_exclude_dirs)
    stale = []

    for fpath in files:
        try:
            content = fpath.read_text(encoding="utf-8")
        except (UnicodeDecodeError, PermissionError):
            continue

        # For contract YAML, skip consolidated_from/nfr_refs blocks and migration text
        if is_contract_yaml(fpath, project_root):
            in_skip = False
            for lineno, line in enumerate(content.split("\n"), 1):
                stripped = line.lstrip()
                if _YAML_SKIP_FIELDS.match(stripped):
                    in_skip = True
                    continue
                if in_skip:
                    if stripped and not stripped.startswith("-") and not stripped.startswith("#"):
                        in_skip = False
                    else:
                        continue
                # Skip migration reason/description lines (legitimately reference old IDs)
                if _YAML_MIGRATION_TEXT.match(stripped):
                    continue
                matches = regex.findall(line)
                if matches:
                    rel = fpath.relative_to(project_root)
                    stale.append((rel, lineno, matches, line.strip()))
        else:
            for lineno, line in enumerate(content.split("\n"), 1):
                if _NORENUMBER in line:
                    continue
                matches = regex.findall(line)
                if matches:
                    rel = fpath.relative_to(project_root)
                    stale.append((rel, lineno, matches, line.strip()))

    if stale:
        print(f"VERIFY FAILED: {len(stale)} stale old ID reference(s) found:\n")
        for rel, lineno, matches, line_text in stale:
            print(f"  {rel}:{lineno}: {matches}")
            if verbose:
                print(f"    {line_text}")
        return False
    else:
        print(f"VERIFY OK: No stale old IDs found ({len(files)} files checked)")
        return True


# --- Main ---

def run_renumber(project_root: Path, extra_exclude_dirs: set[str] | None = None,
                 dry_run: bool = False, verbose: bool = False) -> dict:
    """Execute the renumber operation. Returns stats dict."""
    mapping_path = project_root / ".agentic" / "lib" / "tools" / "renumber_mapping.json"
    if not mapping_path.exists():
        print(f"ERROR: Mapping file not found: {mapping_path}")
        sys.exit(1)

    mapping, cfg_exclude = load_mapping(mapping_path)
    all_exclude = (extra_exclude_dirs or set()) | set(cfg_exclude)
    replacements = sort_replacements(mapping)
    old_ids = [r[0] for r in replacements]
    regex = build_regex(old_ids)
    mapping_dict = dict(replacements)

    stats = {
        "files_scanned": 0,
        "files_modified": 0,
        "contract_files_renamed": 0,
        "total_replacements": 0,
        "errors": [],
        "modified_files": [],
    }

    # Phase 1: Find all files
    files = find_files(project_root, all_exclude)
    stats["files_scanned"] = len(files)

    if verbose:
        print(f"Found {len(files)} text files to process")

    # Phase 2: Process each file
    for fpath in files:
        try:
            content = fpath.read_text(encoding="utf-8")
        except (UnicodeDecodeError, PermissionError) as e:
            if verbose:
                print(f"  SKIP (read error): {fpath.relative_to(project_root)}: {e}")
            continue

        # Check if file contains any old IDs
        if not regex.search(content):
            continue

        # Apply appropriate processing
        if is_contract_yaml(fpath, project_root):
            new_content = process_contract_yaml(content, mapping_dict, regex)
        else:
            new_content = process_text_file(content, mapping_dict, regex)

        if new_content != content:
            actual_changes = count_replacements(content, new_content)
            stats["files_modified"] += 1
            stats["total_replacements"] += actual_changes
            rel = str(fpath.relative_to(project_root))
            stats["modified_files"].append(rel)

            if verbose:
                print(f"  MODIFY ({actual_changes} lines changed): {rel}")

            if not dry_run:
                fpath.write_text(new_content, encoding="utf-8")

    # Phase 3: Rename contract YAML files
    contracts_dir = project_root / ".agentic" / "spec" / "contracts"
    if contracts_dir.exists():
        for old_id, new_id in replacements:
            old_file = contracts_dir / f"{old_id}.yaml"
            new_file = contracts_dir / f"{new_id}.yaml"
            if old_file.exists():
                if verbose:
                    print(f"  RENAME: {old_id}.yaml → {new_id}.yaml")
                git_mv(old_file, new_file, project_root, dry_run)
                stats["contract_files_renamed"] += 1

    return stats


def print_summary(stats: dict, dry_run: bool) -> None:
    """Print a summary of the renumber operation."""
    prefix = "[DRY RUN] " if dry_run else ""
    print(f"\n{prefix}Renumber Summary:")
    print(f"  Files scanned:         {stats['files_scanned']}")
    print(f"  Files modified:        {stats['files_modified']}")
    print(f"  Contract files renamed: {stats['contract_files_renamed']}")
    print(f"  Lines changed:         {stats['total_replacements']}")

    if stats["errors"]:
        print(f"\n  Errors ({len(stats['errors'])}):")
        for err in stats["errors"]:
            print(f"    - {err}")


def main():
    parser = argparse.ArgumentParser(
        description="F-0184 Phase 2: Clean renumber feature IDs"
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Show what would change without modifying files"
    )
    parser.add_argument(
        "--verbose", "-v", action="store_true",
        help="Print detailed output for each file"
    )
    parser.add_argument(
        "--verify", action="store_true",
        help="Check that no old IDs remain (post-renumber validation)"
    )
    parser.add_argument(
        "--project-root", type=Path, default=None,
        help="Project root directory (default: auto-detect from git)"
    )
    args = parser.parse_args()

    # Determine project root
    if args.project_root:
        project_root = args.project_root.resolve()
    else:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True,
        )
        project_root = Path(result.stdout.strip())

    mapping_path = project_root / ".agentic" / "lib" / "tools" / "renumber_mapping.json"
    mapping, cfg_exclude = load_mapping(mapping_path)
    all_exclude = set(cfg_exclude)

    if args.verify:
        ok = run_verify(project_root, mapping, all_exclude, verbose=args.verbose)
        sys.exit(0 if ok else 1)

    print(f"Project root: {project_root}")
    print(f"Mode: {'DRY RUN' if args.dry_run else 'LIVE'}")

    stats = run_renumber(project_root, dry_run=args.dry_run, verbose=args.verbose)
    print_summary(stats, dry_run=args.dry_run)

    if not args.dry_run and stats["files_modified"] > 0:
        print("\nNext steps:")
        print("  1. Review changes: git diff")
        print("  2. Verify: python3 renumber.py --verify")
        print("  3. Run validation: bash tests/validate_framework.sh")
        print("  4. Run tests: python3 -m pytest tests/ -x")


if __name__ == "__main__":
    main()
