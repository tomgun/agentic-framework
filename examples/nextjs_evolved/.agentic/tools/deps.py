#!/usr/bin/env python3
"""
Dependency analyzer - checks if feature dependencies are met before starting work.
Shows blockers and suggests which features can be started.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path


FEATURE_HEADER_RE = re.compile(r"^##\s+(F-\d{4}):\s*(.+?)\s*$", re.MULTILINE)
FEATURE_ID_RE = re.compile(r"\b(F-\d{4})\b")


def parse_features(md: str) -> dict[str, dict]:
    """Parse FEATURES.md and return dict of feature_id -> metadata."""
    features = {}
    current = None
    
    for line in md.splitlines():
        m = FEATURE_HEADER_RE.match(line)
        if m:
            if current:
                features[current["id"]] = current
            current = {
                "id": m.group(1),
                "name": m.group(2),
                "status": None,
                "dependencies": None,
                "state": None,
            }
            continue
        
        if not current:
            continue
        
        if line.strip().startswith("- Status:"):
            current["status"] = line.split(":", 1)[1].strip()
        elif line.strip().startswith("- Dependencies:"):
            current["dependencies"] = line.split(":", 1)[1].strip()
        elif line.strip().startswith("- State:"):
            current["state"] = line.split(":", 1)[1].strip()
    
    if current:
        features[current["id"]] = current
    
    return features


def parse_dependencies(dep_string: str) -> list[tuple[str, str]]:
    """Parse dependencies string into list of (feature_id, requirement)."""
    if not dep_string or dep_string.lower() in {"none", "n/a"}:
        return []
    
    deps = []
    for match in FEATURE_ID_RE.finditer(dep_string):
        fid = match.group(1)
        # Look for requirement (complete/partial)
        start = match.end()
        rest = dep_string[start:start+30]
        if "complete" in rest.lower():
            deps.append((fid, "complete"))
        elif "partial" in rest.lower():
            deps.append((fid, "partial"))
        else:
            deps.append((fid, "any"))
    
    return deps


def check_if_blocked(feature_id: str, feature: dict, all_features: dict[str, dict]) -> list[str]:
    """Check if a feature is blocked by unmet dependencies."""
    blockers = []
    
    deps = parse_dependencies(feature.get("dependencies", "") or "")
    
    for dep_id, requirement in deps:
        if dep_id not in all_features:
            blockers.append(f"{dep_id} (doesn't exist)")
            continue
        
        dep = all_features[dep_id]
        dep_status = (dep.get("status") or "").strip().lower()
        dep_state = (dep.get("state") or "").strip().lower()
        
        if requirement == "complete":
            if dep_state != "complete" and dep_status != "shipped":
                blockers.append(f"{dep_id} (needs complete, currently {dep_status}/{dep_state})")
        elif requirement in {"partial", "any"}:
            if dep_state == "none" and dep_status == "planned":
                blockers.append(f"{dep_id} (not started yet)")
    
    return blockers


def main() -> int:
    repo_root = Path.cwd()
    features_path = repo_root / "spec" / "FEATURES.md"
    
    if not features_path.exists():
        print("Error: spec/FEATURES.md not found")
        return 1
    
    try:
        md = features_path.read_text(encoding="utf-8")
    except Exception as e:
        print(f"Error reading spec/FEATURES.md: {e}")
        return 1
    
    features = parse_features(md)
    
    if not features:
        print("No features found in spec/FEATURES.md")
        return 0
    
    # Check if specific feature requested
    if len(sys.argv) > 1:
        target_id = sys.argv[1].upper()
        if not target_id.startswith("F-"):
            target_id = f"F-{target_id}"
        
        if target_id not in features:
            print(f"Feature {target_id} not found")
            return 1
        
        feature = features[target_id]
        blockers = check_if_blocked(target_id, feature, features)
        
        print(f"=== Dependency check for {target_id}: {feature['name']} ===\n")
        print(f"Status: {feature.get('status', 'unknown')}")
        print(f"State: {feature.get('state', 'unknown')}")
        print()
        
        deps = parse_dependencies(feature.get("dependencies", "") or "")
        if not deps:
            print("✓ No dependencies")
        else:
            print("Dependencies:")
            for dep_id, req in deps:
                dep = features.get(dep_id, {})
                dep_status = dep.get("status", "unknown")
                dep_state = dep.get("state", "unknown")
                print(f"  - {dep_id} (requires: {req}) → {dep_status}/{dep_state}")
        
        print()
        if blockers:
            print("🚫 BLOCKED BY:")
            for blocker in blockers:
                print(f"  - {blocker}")
            print("\nCannot start until dependencies are met.")
            return 1
        else:
            print("✓ All dependencies met - can proceed!")
            return 0
    
    # Full analysis
    print("=== Feature Dependency Analysis ===\n")
    
    blocked_features = []
    ready_features = []
    in_progress_features = []
    
    for fid, feature in features.items():
        status = (feature.get("status") or "").strip().lower()
        
        if status == "in_progress":
            in_progress_features.append(fid)
        elif status == "planned":
            blockers = check_if_blocked(fid, feature, features)
            if blockers:
                blocked_features.append((fid, feature, blockers))
            else:
                ready_features.append((fid, feature))
    
    # Show in-progress
    if in_progress_features:
        print(f"⚙ In Progress ({len(in_progress_features)}):")
        for fid in in_progress_features:
            feature = features[fid]
            print(f"  {fid}: {feature['name']}")
        print()
    
    # Show ready to start
    if ready_features:
        print(f"✓ Ready to Start ({len(ready_features)}):")
        for fid, feature in ready_features:
            print(f"  {fid}: {feature['name']}")
        print()
    
    # Show blocked
    if blocked_features:
        print(f"🚫 Blocked ({len(blocked_features)}):")
        for fid, feature, blockers in blocked_features:
            print(f"  {fid}: {feature['name']}")
            for blocker in blockers:
                print(f"    ↳ Needs: {blocker}")
        print()
    
    if not blocked_features:
        print("✓ No blocked features!")
    
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

