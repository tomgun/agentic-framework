#!/usr/bin/env python3
"""
Code annotation coverage tool.
Scans codebase for @feature annotations and cross-checks with spec/FEATURES.md.

Usage:
  coverage.py              # Human-readable report
  coverage.py --json       # JSON output (machine-readable)
  coverage.py --reverse FILE  # What features does FILE implement?
  coverage.py --test-mapping  # Infer test→feature mapping
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path


FEATURE_ANNOTATION_RE = re.compile(r"@feature\s+(F-\d{4})")
FEATURE_HEADER_RE = re.compile(r"^##\s+(F-\d{4}):", re.MULTILINE)
# Test file naming pattern: test_F0003_*.py or test_F-0003_*.py
TEST_FEATURE_RE = re.compile(r"test[_-]?F[-_]?(\d{4})", re.IGNORECASE)
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
TEST_EXTENSIONS = {".py", ".ts", ".js", ".tsx", ".jsx"}


def scan_for_annotations(root: Path, target_file: str | None = None) -> dict[str, list[str]]:
    """Scan codebase for @feature annotations. Returns {feature_id: [file_paths]}.

    If target_file is provided, only scan that file (for reverse lookup).
    """
    annotations = {}

    # Common directories to exclude
    exclude_dirs = {
        "node_modules", "venv", ".venv", "env", ".env",
        "dist", "build", "target", ".git",
        "__pycache__", ".next", ".nuxt",
        "vendor", "deps", "packages",
    }

    if target_file:
        # Reverse lookup mode - only scan the specified file
        file_path = Path(target_file)
        if not file_path.is_absolute():
            file_path = root / file_path
        files_to_scan = [file_path] if file_path.exists() else []
    else:
        files_to_scan = root.rglob("*")

    for file_path in files_to_scan:
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


def reverse_lookup(root: Path, target_file: str, features: dict[str, dict]) -> dict:
    """Find what features a specific file implements."""
    annotations = scan_for_annotations(root, target_file)

    result = {
        "file": target_file,
        "features": [],
    }

    for fid in sorted(annotations.keys()):
        feature_info = {"id": fid}
        if fid in features:
            feature_info["name"] = features[fid].get("name", "")
            feature_info["status"] = features[fid].get("status", "")
        else:
            feature_info["name"] = "(not in FEATURES.md)"
            feature_info["status"] = "orphaned"
        result["features"].append(feature_info)

    return result


def scan_test_feature_mapping(root: Path, annotations: dict[str, list[str]]) -> dict[str, list[dict]]:
    """Infer test→feature mapping using conventions.

    Methods (in priority order):
    1. Explicit naming: test_F0003_*.py → F-0003
    2. Import tracing: test imports file that has @feature annotation
    3. Name heuristics: feature mentions "login", test file mentions "login" (low confidence)

    Returns {feature_id: [{test_file, method, confidence}]}
    """
    test_mapping = {}

    # Find test directories
    test_dirs = []
    for name in ["tests", "test", "spec", "__tests__"]:
        test_dir = root / name
        if test_dir.exists():
            test_dirs.append(test_dir)

    if not test_dirs:
        return test_mapping

    # Build file→features reverse index for import tracing
    file_to_features = {}
    for fid, files in annotations.items():
        for f in files:
            if f not in file_to_features:
                file_to_features[f] = []
            file_to_features[f].append(fid)

    for test_dir in test_dirs:
        for test_file in test_dir.rglob("*"):
            if not test_file.is_file():
                continue
            if test_file.suffix not in TEST_EXTENSIONS:
                continue
            if "__pycache__" in test_file.parts:
                continue

            rel_path = str(test_file.relative_to(root))
            test_name = test_file.stem

            # Method 1: Explicit naming (test_F0003_*.py)
            m = TEST_FEATURE_RE.search(test_name)
            if m:
                fid = f"F-{m.group(1)}"
                if fid not in test_mapping:
                    test_mapping[fid] = []
                test_mapping[fid].append({
                    "test_file": rel_path,
                    "method": "explicit_naming",
                    "confidence": "high",
                })
                continue

            # Method 2: Import tracing
            try:
                content = test_file.read_text(encoding="utf-8", errors="ignore")

                # Simple import detection (Python)
                imports = re.findall(r"^(?:from|import)\s+([.\w]+)", content, re.MULTILINE)
                for imp in imports:
                    # Convert import to possible file path
                    possible_paths = [
                        imp.replace(".", "/") + ".py",
                        imp.replace(".", "/") + "/__init__.py",
                        "src/" + imp.replace(".", "/") + ".py",
                    ]
                    for ppath in possible_paths:
                        if ppath in file_to_features:
                            for fid in file_to_features[ppath]:
                                if fid not in test_mapping:
                                    test_mapping[fid] = []
                                # Avoid duplicates
                                existing = [t for t in test_mapping[fid] if t["test_file"] == rel_path]
                                if not existing:
                                    test_mapping[fid].append({
                                        "test_file": rel_path,
                                        "method": "import_tracing",
                                        "confidence": "medium",
                                    })

            except Exception:
                continue

    return test_mapping


def parse_features(features_path: Path) -> dict[str, dict]:
    """Parse spec/FEATURES.md. Returns {feature_id: {status, state, name}}."""
    if not features_path.exists():
        return {}

    try:
        content = features_path.read_text(encoding="utf-8")
    except Exception:
        return {}

    features = {}
    current_id = None

    # Check for table format first (unused for now, but reserved for future)
    table_format = bool(re.search(r"^\|\s*F-\d{4}", content, re.MULTILINE))

    for line in content.splitlines():
        # Check for feature header (markdown heading format)
        m = FEATURE_HEADER_RE.match(line)
        if m:
            current_id = m.group(1)
            # Extract name from header line
            name_match = re.search(r"^##\s+F-\d{4}:\s*(.+)$", line)
            name = name_match.group(1).strip() if name_match else ""
            features[current_id] = {"status": None, "state": None, "name": name}
            continue

        if current_id:
            # Parse status and state from markdown format
            if line.strip().startswith("- Status:") or line.strip().startswith("**Status**:"):
                val = line.split(":", 1)[1].strip().rstrip("*")
                features[current_id]["status"] = val
            elif line.strip().startswith("- State:") or line.strip().startswith("**State**:"):
                val = line.split(":", 1)[1].strip().rstrip("*")
                features[current_id]["state"] = val

    return features


def output_json(
    root: Path,
    features: dict,
    annotations: dict,
    implemented: list,
    missing: list,
    orphaned: list,
    test_mapping: dict | None = None,
) -> dict:
    """Generate JSON output."""
    timestamp = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

    issues = []

    # Orphaned annotations
    for fid in orphaned:
        for f in annotations.get(fid, []):
            issues.append({
                "type": "orphaned_annotation",
                "feature": fid,
                "file": f,
                "description": f"@feature {fid} annotation but feature not in FEATURES.md",
            })

    # Missing annotations
    for fid in missing:
        issues.append({
            "type": "missing_annotation",
            "feature": fid,
            "status": features[fid].get("status", ""),
            "description": f"{fid} is shipped/implemented but has no @feature annotations",
        })

    result = {
        "tool": "coverage",
        "timestamp": timestamp,
        "root": str(root),
        "issues": issues,
        "summary": {
            "total_features": len(features),
            "implemented_features": len([f for f, m in features.items()
                                         if m.get("state", "").strip().lower() in {"partial", "complete"}
                                         or m.get("status", "").strip().lower() == "shipped"]),
            "annotated_features": len(implemented),
            "orphaned_annotations": len(orphaned),
            "missing_annotations": len(missing),
        },
    }

    if test_mapping is not None:
        result["test_mapping"] = test_mapping

    return result


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Code annotation coverage tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  coverage.py              # Human-readable report
  coverage.py --json       # JSON output (machine-readable)
  coverage.py --reverse src/auth.py    # What features does auth.py implement?
  coverage.py --test-mapping           # Infer test→feature mapping
""",
    )
    parser.add_argument("--json", action="store_true", help="Output JSON format")
    parser.add_argument("--reverse", metavar="FILE", help="Find features for a specific file")
    parser.add_argument("--test-mapping", action="store_true", help="Infer test→feature mapping")

    args = parser.parse_args()

    root = Path.cwd()
    features_path = root / "spec" / "FEATURES.md"

    # Get features from spec
    features = parse_features(features_path)

    # Handle --reverse mode
    if args.reverse:
        result = reverse_lookup(root, args.reverse, features)
        if args.json:
            print(json.dumps(result, indent=2))
        else:
            print(f"File: {result['file']}")
            if result["features"]:
                print(f"\nImplements {len(result['features'])} feature(s):")
                for f in result["features"]:
                    status = f"[{f['status']}]" if f.get("status") else ""
                    name = f.get("name", "")
                    print(f"  {f['id']}: {name} {status}")
            else:
                print("\nNo @feature annotations found in this file.")
        return 0

    # Regular coverage check
    if not args.json:
        print("=== Code annotation coverage ===\n")

    if not features:
        if args.json:
            print(json.dumps({"error": "No features found in spec/FEATURES.md"}))
        else:
            print("No features found in spec/FEATURES.md")
        return 1

    # Scan codebase for annotations
    if not args.json:
        print("Scanning codebase for @feature annotations...")
    annotations = scan_for_annotations(root)
    if not args.json:
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

    # Handle --test-mapping mode
    test_mapping = None
    if args.test_mapping:
        test_mapping = scan_test_feature_mapping(root, annotations)

    # Output
    if args.json:
        result = output_json(root, features, annotations, implemented, missing, orphaned, test_mapping)
        print(json.dumps(result, indent=2))
        return 1 if (missing or orphaned) else 0

    # Human-readable output
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

    # Test mapping output
    if test_mapping:
        print(f"Test→Feature Mapping ({len(test_mapping)} features with tests):")
        for fid in sorted(test_mapping.keys()):
            tests = test_mapping[fid]
            print(f"  {fid}:")
            for t in tests[:5]:
                conf = f"[{t['confidence']}]"
                method = t["method"]
                print(f"    - {t['test_file']} ({method}) {conf}")
            if len(tests) > 5:
                print(f"    ... and {len(tests) - 5} more")
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

