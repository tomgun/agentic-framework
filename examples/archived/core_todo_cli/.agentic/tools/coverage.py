#!/usr/bin/env python3
"""
Code annotation coverage tool.
Scans codebase for @feature annotations and cross-checks with spec/FEATURES.md.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path


FEATURE_ANNOTATION_RE = re.compile(r"@feature\s+(F-\d{4})")
FEATURE_HEADER_RE = re.compile(r"^##\s+(F-\d{4}):", re.MULTILINE)
CODE_EXTENSIONS = {
    ".ts", ".tsx", ".js", ".jsx",
    ".py", ".pyi",
    ".rs",
    ".go",
    ".c", ".cpp", ".cc", ".h", ".hpp",
    ".java", ".kt", ".kts",
    ".swift",
    ".rb",
    ".php",
    ".cs",
    ".m", ".mm",
}


def scan_for_annotations(root: Path) -> dict[str, list[str]]:
    """Scan codebase for @feature annotations. Returns {feature_id: [file_paths]}."""
    annotations = {}
    
    # Common directories to exclude
    exclude_dirs = {
        "node_modules", "venv", ".venv", "env", ".env",
        "dist", "build", "target", ".git",
        "__pycache__", ".next", ".nuxt",
        "vendor", "deps", "packages",
    }
    
    for file_path in root.rglob("*"):
        # Skip excluded directories
        if any(excluded in file_path.parts for excluded in exclude_dirs):
            continue
        
        # Skip non-code files
        if not file_path.is_file() or file_path.suffix not in CODE_EXTENSIONS:
            continue
        
        try:
            content = file_path.read_text(encoding="utf-8", errors="ignore")
            
            for match in FEATURE_ANNOTATION_RE.finditer(content):
                feature_id = match.group(1)
                rel_path = str(file_path.relative_to(root))
                
                if feature_id not in annotations:
                    annotations[feature_id] = []
                if rel_path not in annotations[feature_id]:
                    annotations[feature_id].append(rel_path)
        
        except Exception:
            # Skip files we can't read
            continue
    
    return annotations


def parse_features(features_path: Path) -> dict[str, dict]:
    """Parse spec/FEATURES.md. Returns {feature_id: {status, state}}."""
    if not features_path.exists():
        return {}
    
    try:
        content = features_path.read_text(encoding="utf-8")
    except Exception:
        return {}
    
    features = {}
    current_id = None
    
    for line in content.splitlines():
        # Check for feature header
        m = FEATURE_HEADER_RE.match(line)
        if m:
            current_id = m.group(1)
            features[current_id] = {"status": None, "state": None}
            continue
        
        if not current_id:
            continue
        
        # Parse status and state
        if line.strip().startswith("- Status:"):
            val = line.split(":", 1)[1].strip()
            features[current_id]["status"] = val
        elif line.strip().startswith("- State:"):
            val = line.split(":", 1)[1].strip()
            features[current_id]["state"] = val
    
    return features


def main() -> int:
    root = Path.cwd()
    features_path = root / "spec" / "FEATURES.md"
    
    print("=== Code annotation coverage ===\n")
    
    # Get features from spec
    features = parse_features(features_path)
    
    if not features:
        print("No features found in spec/FEATURES.md")
        return 1
    
    # Scan codebase for annotations
    print("Scanning codebase for @feature annotations...")
    annotations = scan_for_annotations(root)
    print(f"Found {len(annotations)} unique feature IDs in code\n")
    
    # Cross-check
    orphaned = []  # Annotations for non-existent features
    implemented = []  # Features with code annotations
    missing = []  # Features marked implemented but no annotations
    
    # Check for orphaned annotations
    for fid in annotations:
        if fid not in features:
            orphaned.append(fid)
        else:
            implemented.append(fid)
    
    # Check for features that should have annotations
    for fid, meta in features.items():
        status = (meta.get("status", "") or "").strip().lower()
        state = (meta.get("state", "") or "").strip().lower()
        
        if status in {"deprecated"}:
            continue
        
        # If feature is implemented but has no code annotations
        if state in {"partial", "complete"} or status == "shipped":
            if fid not in annotations:
                missing.append(fid)
    
    # Report
    if implemented:
        print(f"✓ Features with code annotations ({len(implemented)}):")
        for fid in sorted(implemented):
            files = annotations[fid]
            print(f"  {fid}: {len(files)} file(s)")
            for f in files[:3]:  # Show first 3 files
                print(f"    - {f}")
            if len(files) > 3:
                print(f"    ... and {len(files) - 3} more")
        print()
    
    if missing:
        print(f"⚠ Features implemented but not annotated ({len(missing)}):")
        for fid in sorted(missing):
            print(f"  {fid}")
        print("  Tip: Add @feature annotations to key implementation files")
        print()
    
    if orphaned:
        print(f"⚠ Orphaned annotations (feature doesn't exist) ({len(orphaned)}):")
        for fid in sorted(orphaned):
            files = annotations[fid]
            print(f"  {fid}:")
            for f in files:
                print(f"    - {f}")
        print("  Tip: Remove these annotations or add features to spec/FEATURES.md")
        print()
    
    # Summary
    total_implemented = len([f for f, m in features.items() 
                            if m.get("state", "").strip().lower() in {"partial", "complete"}
                            or m.get("status", "").strip().lower() == "shipped"])
    
    coverage_pct = (len(implemented) / total_implemented * 100) if total_implemented > 0 else 0
    
    print(f"Summary:")
    print(f"  Implemented features: {total_implemented}")
    print(f"  Features with annotations: {len(implemented)}")
    print(f"  Coverage: {coverage_pct:.0f}%")
    
    if missing or orphaned:
        return 1
    
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

