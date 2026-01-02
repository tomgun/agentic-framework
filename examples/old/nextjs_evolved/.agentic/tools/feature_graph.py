#!/usr/bin/env python3
"""
Feature dependency graph generator.
Outputs mermaid diagram showing feature dependencies and status.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path


FEATURE_HEADER_RE = re.compile(r"^##\s+(F-\d{4}):\s*(.+?)\s*$")
FEATURE_ID_RE = re.compile(r"\b(F-\d{4})\b")
KEY_RE = re.compile(r"^\s*-\s+([\w][\w\s/.-]*?):\s*(.*?)\s*$")


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
    
    if current:
        features.append(current)

    return features


def parse_dependencies(dep_string: str) -> list[str]:
    """Extract feature IDs from dependency string."""
    if not dep_string or dep_string.lower() in {"none", "n/a"}:
        return []
    return FEATURE_ID_RE.findall(dep_string)


def generate_mermaid(features: list[dict]) -> str:
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
    
    # Add dependency edges
    for f in features:
        fid = f["id"]
        deps = parse_dependencies(f.get("dependencies", "") or "")
        
        for dep_id in deps:
            lines.append(f"    {dep_id} --> {fid}")
        
        # Also show parent relationships if no dependencies shown
        if not deps:
            parent = f.get("parent", "").strip()
            if parent and parent.lower() not in {"none", "n/a"}:
                parent_ids = FEATURE_ID_RE.findall(parent)
                for parent_id in parent_ids:
                    lines.append(f"    {parent_id} -.-> {fid}")
    
    return "\n".join(lines)


def main() -> int:
    repo_root = Path.cwd()
    features_path = repo_root / "spec" / "FEATURES.md"
    
    if not features_path.exists():
        print("Error: spec/FEATURES.md not found", file=sys.stderr)
        return 1
    
    try:
        md = features_path.read_text(encoding="utf-8")
    except Exception as e:
        print(f"Error reading spec/FEATURES.md: {e}", file=sys.stderr)
        return 1
    
    features = parse_features(md)
    
    if not features:
        print("No features found in spec/FEATURES.md", file=sys.stderr)
        return 1
    
    mermaid = generate_mermaid(features)
    
    # Check if we should save to file
    if len(sys.argv) > 1 and sys.argv[1] == "--save":
        output_path = repo_root / "docs" / "feature_graph.md"
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        content = f"""# Feature Dependency Graph

Generated from `spec/FEATURES.md`.

Legend:
- ✓ = shipped
- ⚙ = in progress
- ✗ = deprecated
- Solid arrows (-->) = dependencies
- Dotted arrows (-..->) = parent relationships

```mermaid
{mermaid}
```
"""
        output_path.write_text(content, encoding="utf-8")
        print(f"Saved to {output_path}")
    else:
        # Output to stdout
        print("```mermaid")
        print(mermaid)
        print("```")
    
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

