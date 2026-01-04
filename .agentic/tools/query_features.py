#!/usr/bin/env python3
"""
Query features by status, tags, layer, domain, priority, or owner.
Fast filtering for large feature sets (200+ features).

Usage:
    python query_features.py --status=in_progress
    python query_features.py --tags=auth --tags=ui
    python query_features.py --layer=presentation --priority=critical
    python query_features.py --owner=alice@example.com
    python query_features.py --count  # Show counts by category
"""

import re
import sys
import argparse
from pathlib import Path
from typing import List, Dict, Optional

# Regex patterns
FEATURE_HEADER_RE = re.compile(r"^##\s+(F-\d{4}):\s*(.+?)\s*$")
KEY_RE = re.compile(r"^\s*-\s+([\w][\w\s/.-]*?):\s*(.*?)\s*$")
TAG_RE = re.compile(r'\[([^\]]+)\]')


def parse_features(md: str) -> List[Dict]:
    """Parse FEATURES.md and return list of feature dicts."""
    features = []
    current = None

    for line in md.splitlines():
        # Feature header
        m = FEATURE_HEADER_RE.match(line)
        if m:
            if current:
                features.append(current)
            current = {
                "id": m.group(1),
                "name": m.group(2),
                "status": None,
                "tags": [],
                "layer": None,
                "domain": None,
                "priority": None,
                "owner": None,
                "parent": None,
                "complexity": None,
            }
            continue

        if not current:
            continue

        # Key-value pairs
        km = KEY_RE.match(line)
        if not km:
            continue
        
        key = km.group(1).strip().lower()
        val = km.group(2).strip()

        if key == "status":
            current["status"] = val.lower() if val else None
        elif key == "tags":
            # Parse [tag1, tag2, tag3]
            tag_match = TAG_RE.search(val)
            if tag_match:
                tags_str = tag_match.group(1)
                current["tags"] = [t.strip().lower() for t in tags_str.split(',') if t.strip()]
        elif key == "layer":
            current["layer"] = val.lower() if val and val.lower() != "none" else None
        elif key == "domain":
            current["domain"] = val.lower() if val and val.lower() != "none" else None
        elif key == "priority":
            current["priority"] = val.lower() if val and val.lower() != "none" else None
        elif key == "owner":
            current["owner"] = val if val and val.lower() != "none" else None
        elif key == "parent":
            current["parent"] = val if val and val.lower() != "none" else None
        elif key == "complexity":
            current["complexity"] = val.upper() if val and val.upper() in ['S', 'M', 'L', 'XL'] else None
    
    if current:
        features.append(current)

    return features


def load_features_flat(features_file: Path) -> List[Dict]:
    """Load features from flat FEATURES.md."""
    with open(features_file, 'r') as f:
        md = f.read()
    return parse_features(md)


def load_features_hierarchical(features_dir: Path) -> List[Dict]:
    """Load features from hierarchical features/*/*.md."""
    features = []
    for md_file in features_dir.glob("*/*.md"):
        if md_file.name == "_index.md":
            continue
        with open(md_file, 'r') as f:
            md = f.read()
        features.extend(parse_features(md))
    return features


def filter_features(features: List[Dict], args) -> List[Dict]:
    """Filter features based on query criteria."""
    filtered = features

    if args.status:
        filtered = [f for f in filtered if f.get("status") == args.status.lower()]
    
    if args.tags:
        # Must have ALL specified tags
        tags_lower = [t.lower() for t in args.tags]
        filtered = [f for f in filtered if all(tag in f.get("tags", []) for tag in tags_lower)]
    
    if args.layer:
        filtered = [f for f in filtered if f.get("layer") == args.layer.lower()]
    
    if args.domain:
        filtered = [f for f in filtered if f.get("domain") == args.domain.lower()]
    
    if args.priority:
        filtered = [f for f in filtered if f.get("priority") == args.priority.lower()]
    
    if args.owner:
        filtered = [f for f in filtered if f.get("owner") == args.owner]
    
    if args.complexity:
        filtered = [f for f in filtered if f.get("complexity") == args.complexity.upper()]
    
    if args.parent:
        filtered = [f for f in filtered if f.get("parent") == args.parent]

    return filtered


def print_features(features: List[Dict], show_details: bool = True):
    """Print filtered features."""
    if not features:
        print("No features found matching criteria.")
        return

    for f in features:
        fid = f["id"]
        name = f["name"]
        status = f.get("status", "unknown")
        
        if show_details:
            # Build detail string
            details = []
            if f.get("tags"):
                details.append(f"tags:{','.join(f['tags'])}")
            if f.get("layer"):
                details.append(f"layer:{f['layer']}")
            if f.get("domain"):
                details.append(f"domain:{f['domain']}")
            if f.get("priority"):
                details.append(f"priority:{f['priority']}")
            if f.get("owner"):
                details.append(f"owner:{f['owner']}")
            if f.get("complexity"):
                details.append(f"complexity:{f['complexity']}")
            
            detail_str = f" ({', '.join(details)})" if details else ""
            print(f"{fid}: {name} [{status}]{detail_str}")
        else:
            print(f"{fid}: {name} [{status}]")


def print_counts(features: List[Dict]):
    """Print feature counts by various dimensions."""
    from collections import Counter
    
    total = len(features)
    print(f"\n=== Feature Counts (Total: {total}) ===\n")
    
    # By status
    print("By Status:")
    status_counts = Counter(f.get("status", "unknown") for f in features)
    for status, count in sorted(status_counts.items()):
        print(f"  {status}: {count}")
    
    # By layer
    print("\nBy Layer:")
    layer_counts = Counter(f.get("layer") or "none" for f in features)
    for layer, count in sorted(layer_counts.items()):
        print(f"  {layer}: {count}")
    
    # By domain
    print("\nBy Domain:")
    domain_counts = Counter(f.get("domain") or "none" for f in features)
    for domain, count in sorted(domain_counts.items()):
        print(f"  {domain}: {count}")
    
    # By priority
    print("\nBy Priority:")
    priority_counts = Counter(f.get("priority") or "none" for f in features)
    priority_order = {"critical": 1, "high": 2, "medium": 3, "low": 4, "none": 5}
    for priority, count in sorted(priority_counts.items(), key=lambda x: priority_order.get(x[0], 99)):
        print(f"  {priority}: {count}")
    
    # By complexity
    print("\nBy Complexity:")
    complexity_counts = Counter(f.get("complexity") or "none" for f in features)
    complexity_order = {"S": 1, "M": 2, "L": 3, "XL": 4, "none": 5}
    for complexity, count in sorted(complexity_counts.items(), key=lambda x: complexity_order.get(x[0], 99)):
        print(f"  {complexity}: {count}")
    
    # Top tags
    all_tags = []
    for f in features:
        all_tags.extend(f.get("tags", []))
    if all_tags:
        print("\nTop Tags:")
        tag_counts = Counter(all_tags)
        for tag, count in tag_counts.most_common(10):
            print(f"  {tag}: {count}")


def main():
    parser = argparse.ArgumentParser(
        description="Query features by status, tags, layer, domain, priority, or owner",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --status=in_progress
  %(prog)s --tags=auth --tags=ui
  %(prog)s --layer=presentation --priority=critical
  %(prog)s --domain=payments --status=planned
  %(prog)s --owner=alice@example.com
  %(prog)s --count  # Show counts by category
  %(prog)s --tags=auth --count
"""
    )
    
    parser.add_argument("--status", help="Filter by status (planned|in_progress|shipped|deprecated)")
    parser.add_argument("--tags", action="append", help="Filter by tags (can specify multiple)")
    parser.add_argument("--layer", help="Filter by layer (presentation|business-logic|data|infrastructure|other)")
    parser.add_argument("--domain", help="Filter by domain (auth, payments, etc.)")
    parser.add_argument("--priority", help="Filter by priority (critical|high|medium|low)")
    parser.add_argument("--owner", help="Filter by owner (email or username)")
    parser.add_argument("--complexity", help="Filter by complexity (S|M|L|XL)")
    parser.add_argument("--parent", help="Filter by parent feature ID")
    parser.add_argument("--count", action="store_true", help="Show counts by category instead of listing features")
    parser.add_argument("--simple", action="store_true", help="Simple output (no details)")
    parser.add_argument("--file", default="spec/FEATURES.md", help="Path to FEATURES.md (default: spec/FEATURES.md)")
    
    args = parser.parse_args()
    
    # Detect layout: flat or hierarchical
    if args.file != "spec/FEATURES.md":
        # Explicit file specified
        features_file = Path(args.file)
        if not features_file.exists():
            print(f"ERROR: {features_file} not found", file=sys.stderr)
            sys.exit(1)
        features = load_features_flat(features_file)
    else:
        # Auto-detect
        features_file = Path("spec/FEATURES.md")
        features_dir = Path("spec/features")
        
        if features_dir.exists() and list(features_dir.glob("*/*.md")):
            # Hierarchical layout
            features = load_features_hierarchical(features_dir)
        elif features_file.exists():
            # Flat layout
            features = load_features_flat(features_file)
        else:
            print(f"ERROR: No features found (no spec/FEATURES.md or spec/features/)", file=sys.stderr)
            sys.exit(1)
    
    if not features:
        print(f"No features found in {features_file}", file=sys.stderr)
        sys.exit(1)
    
    # Filter
    filtered = filter_features(features, args)
    
    # Output
    if args.count:
        print_counts(filtered)
    else:
        print_features(filtered, show_details=not args.simple)
        print(f"\nTotal: {len(filtered)} features")


if __name__ == "__main__":
    main()

