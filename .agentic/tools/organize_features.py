#!/usr/bin/env python3
"""
Migrate FEATURES.md from flat format to hierarchical format.
Organizes features into folders by domain or layer.

Usage:
    python organize_features.py [--by domain|layer] [--dry-run]
"""

import re
import sys
import argparse
from pathlib import Path
from collections import defaultdict
from typing import List, Dict

FEATURE_HEADER_RE = re.compile(r"^##\s+(F-\d{4}):\s*(.+?)\s*$")
KEY_RE = re.compile(r"^\s*-\s+([\w][\w\s/.-]*?):\s*(.*?)\s*$")
TAG_RE = re.compile(r'\[([^\]]+)\]')


def parse_features(md: str) -> List[Dict]:
    """Parse FEATURES.md into feature dicts with full text."""
    features = []
    current = None
    current_lines = []

    for line in md.splitlines():
        m = FEATURE_HEADER_RE.match(line)
        if m:
            if current:
                current["content"] = "\n".join(current_lines)
                features.append(current)
            current = {
                "id": m.group(1),
                "name": m.group(2),
                "domain": None,
                "layer": None,
                "tags": [],
            }
            current_lines = [line]
            continue

        if current:
            current_lines.append(line)
            
            km = KEY_RE.match(line)
            if km:
                key = km.group(1).strip().lower()
                val = km.group(2).strip()
                
                if key == "domain":
                    current["domain"] = val if val and val.lower() not in ["none", ""] else None
                elif key == "layer":
                    current["layer"] = val if val and val.lower() not in ["none", ""] else None
                elif key == "tags":
                    tag_match = TAG_RE.search(val)
                    if tag_match:
                        tags_str = tag_match.group(1)
                        current["tags"] = [t.strip() for t in tags_str.split(',') if t.strip()]
    
    if current:
        current["content"] = "\n".join(current_lines)
        features.append(current)

    return features


def organize_by_domain(features: List[Dict]) -> Dict[str, List[Dict]]:
    """Group features by domain."""
    grouped = defaultdict(list)
    for f in features:
        domain = f.get("domain") or "other"
        grouped[domain].append(f)
    return grouped


def organize_by_layer(features: List[Dict]) -> Dict[str, List[Dict]]:
    """Group features by layer."""
    grouped = defaultdict(list)
    for f in features:
        layer = f.get("layer") or "other"
        grouped[layer].append(f)
    return grouped


def sanitize_dirname(name: str) -> str:
    """Convert domain/layer name to safe directory name."""
    return name.lower().replace(" ", "-").replace("_", "-")


def create_hierarchical_structure(features: List[Dict], organize_by: str, dry_run: bool) -> None:
    """Create hierarchical directory structure."""
    root = Path.cwd()
    features_dir = root / "spec" / "features"
    
    if organize_by == "domain":
        grouped = organize_by_domain(features)
    else:  # layer
        grouped = organize_by_layer(features)
    
    print(f"\n=== Organizing {len(features)} features by {organize_by} ===\n")
    
    # Show organization plan
    for category, feats in sorted(grouped.items()):
        dirname = sanitize_dirname(category)
        print(f"{dirname}/ ({len(feats)} features)")
        for f in feats[:3]:  # Show first 3
            print(f"  - {f['id']}: {f['name']}")
        if len(feats) > 3:
            print(f"  ... and {len(feats) - 3} more")
        print()
    
    if dry_run:
        print("DRY RUN - No files created")
        return
    
    # Confirm
    response = input("Proceed with migration? (yes/no): ")
    if response.lower() != "yes":
        print("Cancelled.")
        return
    
    # Create directories and files
    features_dir.mkdir(parents=True, exist_ok=True)
    
    for category, feats in grouped.items():
        dirname = sanitize_dirname(category)
        category_dir = features_dir / dirname
        category_dir.mkdir(exist_ok=True)
        
        for f in feats:
            fid = f["id"]
            name_slug = f["name"].lower().replace(" ", "-")[:30]
            filename = f"{fid}_{name_slug}.md"
            filepath = category_dir / filename
            
            # Write feature file
            filepath.write_text(f["content"], encoding="utf-8")
            print(f"Created: {filepath}")
    
    # Create index file
    create_index(features, features_dir)
    
    # Backup original
    original = root / "spec" / "FEATURES.md"
    backup = root / "spec" / "FEATURES.md.bak"
    if original.exists():
        original.rename(backup)
        print(f"\nBacked up original to: {backup}")
    
    print(f"\n✅ Migration complete!")
    print(f"   Features organized in: {features_dir}/")
    print(f"   Index file: {features_dir}/_index.md")


def create_index(features: List[Dict], features_dir: Path) -> None:
    """Create master index file."""
    index_path = features_dir / "_index.md"
    
    lines = [
        "# Feature Index",
        "<!-- spec-format: features-index-v0.3.1 -->",
        "",
        "Auto-generated index of all features.",
        "",
        "| ID | Name | Status | Domain | Layer | Priority |",
        "|-----|------|--------|--------|-------|----------|",
    ]
    
    for f in sorted(features, key=lambda x: x["id"]):
        # Extract status from content
        status_match = re.search(r'-\s+Status:\s*(\w+)', f["content"])
        status = status_match.group(1) if status_match else "unknown"
        
        domain = f.get("domain") or "-"
        layer = f.get("layer") or "-"
        
        # Extract priority
        priority_match = re.search(r'-\s+Priority:\s*(\w+)', f["content"])
        priority = priority_match.group(1) if priority_match else "-"
        
        lines.append(f"| {f['id']} | {f['name']} | {status} | {domain} | {layer} | {priority} |")
    
    lines.append("")
    lines.append(f"**Total features**: {len(features)}")
    lines.append("")
    
    index_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"Created index: {index_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Migrate FEATURES.md to hierarchical structure",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--by", choices=["domain", "layer"], default="domain",
                       help="Organize by domain or layer (default: domain)")
    parser.add_argument("--dry-run", action="store_true",
                       help="Show plan without creating files")
    
    args = parser.parse_args()
    
    root = Path.cwd()
    features_file = root / "spec" / "FEATURES.md"
    
    if not features_file.exists():
        print(f"ERROR: {features_file} not found", file=sys.stderr)
        return 1
    
    # Check if already migrated
    features_dir = root / "spec" / "features"
    if features_dir.exists() and list(features_dir.glob("*/*.md")):
        print("ERROR: Already migrated (spec/features/ contains .md files)", file=sys.stderr)
        print("       Delete spec/features/ if you want to re-migrate", file=sys.stderr)
        return 1
    
    # Parse
    md = features_file.read_text(encoding="utf-8")
    features = parse_features(md)
    
    if not features:
        print("ERROR: No features found in FEATURES.md", file=sys.stderr)
        return 1
    
    # Organize
    create_hierarchical_structure(features, args.by, args.dry_run)
    
    return 0


if __name__ == "__main__":
    sys.exit(main())

