#!/usr/bin/env python3
"""
Feature dependency graph generator with filtering.
Outputs mermaid diagram showing feature dependencies and status.

Filters:
  --status=<status>     Filter by status (planned|in_progress|shipped|deprecated)
  --layer=<layer>       Filter by layer (presentation|business-logic|data|infrastructure)
  --tags=<tag>          Filter by tag (can specify multiple times)
  --focus=<F-####>      Focus on single feature + immediate neighbors
  --depth=<N>           When using --focus, how many hops to include (default: 1)
  --hierarchy-only      Show parent-child only, ignore dependencies
"""
from __future__ import annotations

import re
import sys
import argparse
from pathlib import Path
from typing import Set


FEATURE_HEADER_RE = re.compile(r"^##\s+(F-\d{4}):\s*(.+?)\s*$")
FEATURE_ID_RE = re.compile(r"\b(F-\d{4})\b")
KEY_RE = re.compile(r"^\s*-\s+([\w][\w\s/.-]*?):\s*(.*?)\s*$")
TAG_RE = re.compile(r'\[([^\]]+)\]')


def parse_features(md: str) -> list[dict]:
    """Parse FEATURES.md and return list of feature dicts."""
    features = []
    current = None

    for line in md.splitlines():
        m = FEATURE_HEADER_RE.match(line)
        if m:
            if current:
                features.append(current)
            current = {
                "id": m.group(1),
                "name": m.group(2),
                "status": None,
                "dependencies": None,
                "parent": None,
                "tags": [],
                "layer": None,
            }
            continue

        if not current:
            continue

        km = KEY_RE.match(line)
        if not km:
            continue
        key = km.group(1).strip().lower()
        val = km.group(2).strip()

        if key == "status":
            current["status"] = val
        elif key == "dependencies":
            current["dependencies"] = val
        elif key == "parent":
            current["parent"] = val
        elif key == "tags":
            # Parse [tag1, tag2, tag3]
            tag_match = TAG_RE.search(val)
            if tag_match:
                tags_str = tag_match.group(1)
                current["tags"] = [t.strip().lower() for t in tags_str.split(',') if t.strip()]
        elif key == "layer":
            current["layer"] = val.lower() if val and val.lower() != "none" else None
    
    if current:
        features.append(current)

    return features


def load_features_flat(features_file: Path) -> list[dict]:
    """Load features from flat FEATURES.md."""
    try:
        md = features_file.read_text(encoding="utf-8")
    except Exception as e:
        print(f"Error reading {features_file}: {e}", file=sys.stderr)
        sys.exit(1)
    return parse_features(md)


def load_features_hierarchical(features_dir: Path) -> list[dict]:
    """Load features from hierarchical features/*/*.md."""
    features = []
    for md_file in features_dir.glob("*/*.md"):
        if md_file.name == "_index.md":
            continue
        try:
            md = md_file.read_text(encoding="utf-8")
            features.extend(parse_features(md))
        except Exception as e:
            print(f"Warning: Error reading {md_file}: {e}", file=sys.stderr)
    return features


def filter_features(features: list[dict], args) -> list[dict]:
    """Filter features based on command-line arguments."""
    filtered = features

    if args.status:
        filtered = [f for f in filtered if f.get("status", "").lower() == args.status.lower()]
    
    if args.layer:
        filtered = [f for f in filtered if f.get("layer") == args.layer.lower()]
    
    if args.tags:
        tags_lower = [t.lower() for t in args.tags]
        filtered = [f for f in filtered if all(tag in f.get("tags", []) for tag in tags_lower)]
    
    if args.focus:
        # Get focus feature + neighbors at specified depth
        filtered = get_focus_subgraph(features, args.focus, args.depth)
    
    return filtered


def get_focus_subgraph(all_features: list[dict], focus_id: str, depth: int) -> list[dict]:
    """Get feature and its neighbors up to N hops away."""
    # Build adjacency map
    adjacency = {}
    for f in all_features:
        fid = f["id"]
        adjacency[fid] = set()
        
        # Dependencies
        deps = parse_dependencies(f.get("dependencies", "") or "")
        adjacency[fid].update(deps)
        
        # Parent
        parent = f.get("parent", "").strip()
        if parent and parent.lower() not in {"none", "n/a"}:
            parent_ids = FEATURE_ID_RE.findall(parent)
            adjacency[fid].update(parent_ids)
    
    # BFS from focus feature
    visited = set()
    queue = [(focus_id, 0)]  # (feature_id, current_depth)
    
    while queue:
        fid, curr_depth = queue.pop(0)
        if fid in visited or curr_depth > depth:
            continue
        
        visited.add(fid)
        
        if curr_depth < depth:
            # Add neighbors
            for neighbor in adjacency.get(fid, []):
                if neighbor not in visited:
                    queue.append((neighbor, curr_depth + 1))
            
            # Also add reverse neighbors (things that depend on this)
            for other_fid, other_neighbors in adjacency.items():
                if fid in other_neighbors and other_fid not in visited:
                    queue.append((other_fid, curr_depth + 1))
    
    # Return features that are in visited set
    return [f for f in all_features if f["id"] in visited]


def parse_dependencies(dep_string: str) -> list[str]:
    """Extract feature IDs from dependency string."""
    if not dep_string or dep_string.lower() in {"none", "n/a"}:
        return []
    return FEATURE_ID_RE.findall(dep_string)


def generate_mermaid(features: list[dict], hierarchy_only: bool = False) -> str:
    """Generate mermaid flowchart showing feature dependencies."""
    lines = ["graph TD"]
    
    # Define nodes with status-based styling
    for f in features:
        fid = f["id"]
        name = f["name"][:30]  # Truncate long names
        status = (f["status"] or "planned").strip().lower()
        
        # Escape special chars in names
        safe_name = name.replace('"', "'")
        
        # Node definition with status indicator
        if status == "shipped":
            lines.append(f'    {fid}["{fid}: {safe_name} ✓"]')
        elif status == "in_progress":
            lines.append(f'    {fid}["{fid}: {safe_name} ⚙"]')
        elif status == "deprecated":
            lines.append(f'    {fid}["{fid}: {safe_name} ✗"]')
        else:  # planned
            lines.append(f'    {fid}["{fid}: {safe_name}"]')
    
    lines.append("")
    
    # Build set of feature IDs for validation
    feature_ids = {f["id"] for f in features}
    
    # Add edges
    for f in features:
        fid = f["id"]
        
        if not hierarchy_only:
            # Add dependency edges
            deps = parse_dependencies(f.get("dependencies", "") or "")
            for dep_id in deps:
                # Only show edge if both nodes are in filtered set
                if dep_id in feature_ids:
                    lines.append(f"    {dep_id} --> {fid}")
        
        # Parent relationships (always shown, or exclusively if hierarchy_only)
        parent = f.get("parent", "").strip()
        if parent and parent.lower() not in {"none", "n/a"}:
            parent_ids = FEATURE_ID_RE.findall(parent)
            for parent_id in parent_ids:
                # Only show edge if both nodes are in filtered set
                if parent_id in feature_ids:
                    if hierarchy_only:
                        lines.append(f"    {parent_id} --> {fid}")
                    else:
                        lines.append(f"    {parent_id} -.-> {fid}")
    
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate feature dependency graph with filtering",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                                    # All features
  %(prog)s --status=in_progress               # Only in-progress features
  %(prog)s --layer=presentation               # Only presentation layer
  %(prog)s --tags=auth --tags=ui              # Features with both tags
  %(prog)s --focus=F-0042 --depth=1           # Feature F-0042 + immediate neighbors
  %(prog)s --hierarchy-only                   # Parent-child only, no dependencies
  %(prog)s --save                             # Save to docs/feature_graph.md
"""
    )
    
    parser.add_argument("--status", help="Filter by status")
    parser.add_argument("--layer", help="Filter by layer")
    parser.add_argument("--tags", action="append", help="Filter by tags (can specify multiple)")
    parser.add_argument("--focus", help="Focus on single feature (F-####)")
    parser.add_argument("--depth", type=int, default=1, help="Depth for --focus (default: 1)")
    parser.add_argument("--hierarchy-only", action="store_true", help="Show parent-child only")
    parser.add_argument("--save", action="store_true", help="Save to docs/feature_graph.md")
    parser.add_argument("--file", default="spec/FEATURES.md", help="Path to FEATURES.md")
    
    args = parser.parse_args()
    
    repo_root = Path.cwd()
    
    # Detect layout: flat or hierarchical
    if args.file != "spec/FEATURES.md":
        # Explicit file specified
        features_path = repo_root / args.file
        if not features_path.exists():
            print(f"Error: {args.file} not found", file=sys.stderr)
            return 1
        features = load_features_flat(features_path)
    else:
        # Auto-detect
        features_file = repo_root / "spec" / "FEATURES.md"
        features_dir = repo_root / "spec" / "features"
        
        if features_dir.exists() and list(features_dir.glob("*/*.md")):
            # Hierarchical layout
            features = load_features_hierarchical(features_dir)
        elif features_file.exists():
            # Flat layout
            features = load_features_flat(features_file)
        else:
            print("Error: No features found (no spec/FEATURES.md or spec/features/)", file=sys.stderr)
            return 1
    
    if not features:
        print(f"No features found in {args.file}", file=sys.stderr)
        return 1
    
    # Apply filters
    filtered_features = filter_features(features, args)
    
    if not filtered_features:
        print("No features match the specified filters", file=sys.stderr)
        return 1
    
    print(f"Showing {len(filtered_features)} of {len(features)} features", file=sys.stderr)
    
    mermaid = generate_mermaid(filtered_features, args.hierarchy_only)
    
    # Save or output
    if args.save:
        output_path = repo_root / "docs" / "feature_graph.md"
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Build filter description
        filter_desc = []
        if args.status:
            filter_desc.append(f"status={args.status}")
        if args.layer:
            filter_desc.append(f"layer={args.layer}")
        if args.tags:
            filter_desc.append(f"tags={','.join(args.tags)}")
        if args.focus:
            filter_desc.append(f"focus={args.focus} (depth={args.depth})")
        if args.hierarchy_only:
            filter_desc.append("hierarchy-only")
        
        filter_str = f" (Filtered: {', '.join(filter_desc)})" if filter_desc else ""
        
        content = f"""# Feature Dependency Graph{filter_str}

Generated from `spec/FEATURES.md`.

Showing {len(filtered_features)} of {len(features)} features.

Legend:
- ✓ = shipped
- ⚙ = in progress
- ✗ = deprecated
- Solid arrows (-->) = dependencies{' (or parent if hierarchy-only)' if args.hierarchy_only else ''}
- Dotted arrows (-..->) = parent relationships

```mermaid
{mermaid}
```
"""
        output_path.write_text(content, encoding="utf-8")
        print(f"Saved to {output_path}", file=sys.stderr)
    else:
        # Output to stdout
        print("```mermaid")
        print(mermaid)
        print("```")
    
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

