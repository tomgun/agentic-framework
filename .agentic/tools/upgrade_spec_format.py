#!/usr/bin/env python3
"""
Upgrade spec format from older versions to current version.
Detects format version and applies necessary migrations.

Usage:
    python upgrade_spec_format.py [--dry-run]
"""

import re
import sys
import argparse
from pathlib import Path
from typing import Optional

FORMAT_VERSION_RE = re.compile(r'<!--\s*spec-format:\s*([a-z0-9-]+)-v([\d.]+)\s*-->')


def detect_format_version(file_path: Path) -> Optional[tuple]:
    """Detect spec format version from file."""
    if not file_path.exists():
        return None
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    match = FORMAT_VERSION_RE.search(content)
    if match:
        return (match.group(1), match.group(2))  # (format_name, version)
    return None


def add_format_marker(file_path: Path, format_name: str, version: str, dry_run: bool = False):
    """Add format version marker to file if missing."""
    with open(file_path, 'r') as f:
        lines = f.readlines()
    
    # Find first heading
    for idx, line in enumerate(lines):
        if line.startswith('#'):
            # Insert format marker after heading
            marker = f"<!-- spec-format: {format_name}-v{version} -->\n\n"
            lines.insert(idx + 1, marker)
            break
    
    if dry_run:
        print(f"Would add format marker to {file_path}")
        return
    
    with open(file_path, 'w') as f:
        f.writelines(lines)
    
    print(f"✅ Added format marker to {file_path}")


def upgrade_features_to_v031(file_path: Path, dry_run: bool = False):
    """Upgrade FEATURES.md to v0.3.1 format (adds new optional fields)."""
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Check if already has new fields
    if "- Tags:" in content or "- Layer:" in content:
        print(f"  Already has v0.3.1 fields")
        return
    
    if dry_run:
        print(f"  Would upgrade {file_path} to v0.3.1")
        return
    
    # Add format marker if missing
    if not FORMAT_VERSION_RE.search(content):
        add_format_marker(file_path, "features", "0.3.1", dry_run)
    
    print(f"✅ {file_path} is v0.3.1 compatible (new fields are optional)")


def main():
    parser = argparse.ArgumentParser(
        description="Upgrade spec format to latest version"
    )
    parser.add_argument("--dry-run", action="store_true",
                       help="Show what would be done without making changes")
    
    args = parser.parse_args()
    
    root = Path.cwd()
    spec_dir = root / "spec"
    
    print("=== Spec Format Upgrade ===")
    print()
    
    # Check FEATURES.md
    features_file = spec_dir / "FEATURES.md"
    if features_file.exists():
        print(f"Checking {features_file}...")
        
        version_info = detect_format_version(features_file)
        if version_info:
            format_name, version = version_info
            print(f"  Current version: {format_name}-v{version}")
            
            if version == "0.3.1":
                print(f"  ✅ Already at latest version")
            else:
                print(f"  Upgrading to v0.3.1...")
                upgrade_features_to_v031(features_file, args.dry_run)
        else:
            print(f"  No version marker found")
            print(f"  Adding v0.3.1 marker...")
            if not args.dry_run:
                add_format_marker(features_file, "features", "0.3.1", args.dry_run)
            upgrade_features_to_v031(features_file, args.dry_run)
    
    # Check hierarchical features
    features_dir = spec_dir / "features"
    if features_dir.exists():
        md_files = list(features_dir.glob("*/*.md"))
        if md_files:
            print(f"\nChecking {len(md_files)} feature files in {features_dir}/...")
            for md_file in md_files:
                if md_file.name == "_index.md":
                    continue
                version_info = detect_format_version(md_file)
                if not version_info:
                    if not args.dry_run:
                        add_format_marker(md_file, "feature", "0.3.1", args.dry_run)
    
    print()
    if args.dry_run:
        print("DRY RUN - No changes made")
    else:
        print("✅ Upgrade complete!")
    
    return 0


if __name__ == "__main__":
    sys.exit(main())

