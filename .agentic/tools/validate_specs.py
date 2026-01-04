#!/usr/bin/env python3
"""
Validate spec files with YAML frontmatter against JSON schemas.
Also validates circular dependencies and cross-references.
Supports both flat (FEATURES.md) and hierarchical (features/*.md) layouts.

Single source of truth: All data in one .md file with frontmatter.
Automatic validation: Catches typos, wrong values, missing fields.
"""

import sys
import yaml
import json
import re
from pathlib import Path
from typing import Any, Optional, List, Dict, Set

try:
    import frontmatter
    from jsonschema import validate, ValidationError, Draft7Validator
except ImportError:
    print("ERROR: Missing dependencies. Install with:")
    print("  pip install python-frontmatter jsonschema pyyaml")
    sys.exit(1)


# Regex for parsing markdown-format FEATURES.md
FEATURE_HEADER_RE = re.compile(r"^##\s+(F-\d{4}):\s*(.+?)\s*$")
FEATURE_ID_RE = re.compile(r"\b(F-\d{4})\b")
KEY_RE = re.compile(r"^\s*-\s+([\w][\w\s/.-]*?):\s*(.*?)\s*$")
FORMAT_VERSION_RE = re.compile(r'<!--\s*spec-format:\s*([a-z0-9-]+)-v([\d.]+)\s*-->')


def detect_layout(spec_dir: Path) -> str:
    """Detect if using flat or hierarchical layout."""
    features_dir = spec_dir / "features"
    features_file = spec_dir / "FEATURES.md"
    
    if features_dir.exists() and list(features_dir.glob("*/*.md")):
        return "hierarchical"
    elif features_file.exists():
        return "flat"
    else:
        return "none"


def load_features_flat(features_file: Path) -> List[Dict]:
    """Load features from flat FEATURES.md file."""
    if not features_file.exists():
        return []
    return parse_markdown_features(features_file)


def load_features_hierarchical(features_dir: Path) -> List[Dict]:
    """Load features from hierarchical features/*/*.md files."""
    features = []
    for md_file in features_dir.glob("*/*.md"):
        if md_file.name == "_index.md":
            continue
        features.extend(parse_markdown_features(md_file))
    return features


def parse_markdown_features(features_file: Path) -> List[Dict]:
    """Parse markdown-format FEATURES.md into feature dicts."""
    if not features_file.exists():
        return []
    
    with open(features_file, 'r') as f:
        md = f.read()
    
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
                "dependencies": [],
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

        if key == "dependencies":
            if val and val.lower() not in {"none", "n/a", ""}:
                current["dependencies"] = FEATURE_ID_RE.findall(val)
        elif key == "parent":
            if val and val.lower() not in {"none", "n/a", ""}:
                parent_ids = FEATURE_ID_RE.findall(val)
                current["parent"] = parent_ids[0] if parent_ids else None
    
    if current:
        features.append(current)

    return features


def detect_circular_dependencies(features: List[Dict]) -> List[str]:
    """
    Detect circular dependencies using DFS.
    Returns list of error messages describing cycles found.
    """
    errors = []
    
    # Build adjacency list
    graph = {}
    for f in features:
        fid = f["id"]
        graph[fid] = f.get("dependencies", [])
    
    # DFS to detect cycles
    def has_cycle(node: str, visited: Set[str], rec_stack: Set[str], path: List[str]) -> Optional[List[str]]:
        visited.add(node)
        rec_stack.add(node)
        path.append(node)
        
        for neighbor in graph.get(node, []):
            if neighbor not in visited:
                cycle = has_cycle(neighbor, visited, rec_stack, path.copy())
                if cycle:
                    return cycle
            elif neighbor in rec_stack:
                # Found cycle
                cycle_start = path.index(neighbor)
                return path[cycle_start:] + [neighbor]
        
        rec_stack.remove(node)
        return None
    
    visited = set()
    for fid in graph:
        if fid not in visited:
            cycle = has_cycle(fid, visited, set(), [])
            if cycle:
                cycle_str = " -> ".join(cycle)
                errors.append(f"Circular dependency detected: {cycle_str}")
    
    return errors


def validate_cross_references(features: List[Dict]) -> List[str]:
    """
    Validate that parent and dependency references point to existing features.
    """
    errors = []
    feature_ids = {f["id"] for f in features}
    
    for f in features:
        fid = f["id"]
        
        # Check parent exists
        parent = f.get("parent")
        if parent and parent not in feature_ids:
            errors.append(f"{fid}: Parent {parent} does not exist")
        
        # Check dependencies exist
        for dep in f.get("dependencies", []):
            if dep not in feature_ids:
                errors.append(f"{fid}: Dependency {dep} does not exist")
    
    return errors


def load_schema(schema_path: Path) -> Optional[dict]:
    """Load JSON schema file."""
    if not schema_path.exists():
        return None
    
    with open(schema_path, 'r') as f:
        return json.load(f)


def validate_features_file(features_file: Path, schema: dict) -> list[str]:
    """Validate FEATURES.md frontmatter against schema."""
    errors = []
    
    if not features_file.exists():
        return errors
    
    # Parse frontmatter
    with open(features_file, 'r') as f:
        try:
            post = frontmatter.load(f)
        except yaml.YAMLError as e:
            return [f"YAML parsing error: {e}"]
    
    # Get features array
    features = post.metadata.get('features', [])
    
    if not features:
        # No frontmatter yet - this is OK, just warn
        return []
    
    # Validate each feature
    validator = Draft7Validator(schema)
    
    for idx, feature in enumerate(features):
        feature_id = feature.get('id', f'feature-{idx}')
        
        for error in validator.iter_errors(feature):
            # Format error nicely
            field_path = '.'.join(str(p) for p in error.path) if error.path else 'root'
            errors.append(f"{feature_id}: {field_path} - {error.message}")
    
    return errors


def validate_nfr_file(nfr_file: Path, schema: dict) -> list[str]:
    """Validate NFR.md frontmatter against schema."""
    errors = []
    
    if not nfr_file.exists():
        return errors
    
    with open(nfr_file, 'r') as f:
        try:
            post = frontmatter.load(f)
        except yaml.YAMLError as e:
            return [f"YAML parsing error: {e}"]
    
    nfrs = post.metadata.get('nfrs', [])
    
    if not nfrs:
        return []
    
    validator = Draft7Validator(schema)
    
    for idx, nfr in enumerate(nfrs):
        nfr_id = nfr.get('id', f'nfr-{idx}')
        
        for error in validator.iter_errors(nfr):
            field_path = '.'.join(str(p) for p in error.path) if error.path else 'root'
            errors.append(f"{nfr_id}: {field_path} - {error.message}")
    
    return errors


def main() -> int:
    """Main validation routine."""
    root = Path.cwd()
    schema_dir = root / ".agentic" / "schemas"
    spec_dir = root / "spec"
    
    print("=== Spec Validation ===")
    print()
    
    all_errors = []
    
    # Detect layout
    layout = detect_layout(spec_dir)
    
    if layout == "none":
        print("⚠️  No features found (no spec/FEATURES.md or spec/features/)")
        print("   Run scaffold.sh if you're using Core+PM mode")
        return 0
    
    print(f"Layout: {layout}")
    print()
    
    # Load features based on layout
    if layout == "flat":
        features_file = spec_dir / "FEATURES.md"
        print("Validating spec/FEATURES.md...")
        features = load_features_flat(features_file)
    else:  # hierarchical
        features_dir = spec_dir / "features"
        print("Validating spec/features/*/*.md...")
        features = load_features_hierarchical(features_dir)
    
    if features:
        print(f"  Found {len(features)} features")
        
        # Check for circular dependencies
        print("  Checking for circular dependencies...")
        cycle_errors = detect_circular_dependencies(features)
        if cycle_errors:
            print(f"  ❌ {len(cycle_errors)} circular dependency error(s):")
            for error in cycle_errors:
                print(f"     - {error}")
                all_errors.append(error)
        else:
            print("  ✅ No circular dependencies")
        
        # Check cross-references
        print("  Checking cross-references...")
        ref_errors = validate_cross_references(features)
        if ref_errors:
            print(f"  ❌ {len(ref_errors)} cross-reference error(s):")
            for error in ref_errors:
                print(f"     - {error}")
                all_errors.append(error)
        else:
            print("  ✅ All references valid")
    
    # Schema validation (if using frontmatter) - only for flat layout
    if layout == "flat":
        features_file = spec_dir / "FEATURES.md"
        feature_schema_file = schema_dir / "feature.schema.json"
        
        if not feature_schema_file.exists():
            print("  ⚠️  No schema found (.agentic/schemas/feature.schema.json)")
            print("     Skipping schema validation.")
        else:
            schema = load_schema(feature_schema_file)
            errors = validate_features_file(features_file, schema)
            
            if errors:
                print(f"  ❌ {len(errors)} schema error(s) found:")
                for error in errors:
                    print(f"     - {error}")
                    all_errors.append(error)
            else:
                print("  ✅ Schema valid (if using frontmatter)")
    
    # Validate NFR.md
    nfr_file = spec_dir / "NFR.md"
    nfr_schema_file = schema_dir / "nfr.schema.json"
    
    if nfr_file.exists():
        print()
        print("Validating spec/NFR.md...")
        
        if not nfr_schema_file.exists():
            print("  ⚠️  No schema found (.agentic/schemas/nfr.schema.json)")
            print("     Skipping validation.")
        else:
            schema = load_schema(nfr_schema_file)
            errors = validate_nfr_file(nfr_file, schema)
            
            if errors:
                print(f"  ❌ {len(errors)} error(s) found:")
                for error in errors:
                    print(f"     - {error}")
                    all_errors.append(error)
            else:
                print("  ✅ Valid")
    
    print()
    
    if all_errors:
        print(f"❌ Total errors: {len(all_errors)}")
        print()
        print("Fix errors in spec files and run again.")
        return 1
    else:
        print("✅ All validations passed!")
        return 0


if __name__ == "__main__":
    sys.exit(main())

