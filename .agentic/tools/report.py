#!/usr/bin/env python3
import re
import sys
from pathlib import Path


FEATURE_HEADER_RE = re.compile(r"^##\s+(F-\d{4}):\s*(.+?)\s*$")
FEATURE_ID_RE = re.compile(r"\b(F-\d{4})\b")
# Match both top-level and nested list items (e.g. "  - Accepted: yes")
KEY_RE = re.compile(r"^\s*-\s+([\w][\w\s/.-]*?):\s*(.*?)\s*$")


def parse_features(md: str):
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
                "acceptance": None,
                "implementation_state": None,
                "accepted": None,
                "tests_unit": None,
                "tests_acceptance": None,
                "tests_integration": None,
                "tests_perf": None,
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
        elif key == "acceptance":
            current["acceptance"] = val
        elif key == "state":
            current["implementation_state"] = val
        elif key == "accepted":
            current["accepted"] = val
    
    if current:
        features.append(current)

    return features


def parse_dependencies(dep_string: str) -> list[tuple[str, str]]:
    """Parse dependencies string into list of (feature_id, requirement)."""
    if not dep_string or dep_string.lower() in {"none", "n/a"}:
        return []
    
    deps = []
    for match in FEATURE_ID_RE.finditer(dep_string):
        fid = match.group(1)
        # Try to extract requirement (complete/partial)
        # Look for text after the feature ID
        start = match.end()
        rest = dep_string[start:start+30]  # Look ahead a bit
        if "complete" in rest.lower():
            deps.append((fid, "complete"))
        elif "partial" in rest.lower():
            deps.append((fid, "partial"))
        else:
            deps.append((fid, "any"))
    
    return deps


def check_dependency_issues(features: list[dict]) -> list[str]:
    """Check for dependency problems."""
    issues = []
    feature_map = {f["id"]: f for f in features}
    
    for f in features:
        fid = f["id"]
        status = (f["status"] or "").strip().lower()
        dep_string = f.get("dependencies", "") or ""
        
        if not dep_string or dep_string.lower() in {"none", "n/a"}:
            continue
        
        deps = parse_dependencies(dep_string)
        
        for dep_id, requirement in deps:
            # Check if dependency exists
            if dep_id not in feature_map:
                issues.append(f"{fid}: depends on {dep_id} which doesn't exist")
                continue
            
            dep_feature = feature_map[dep_id]
            dep_status = (dep_feature["status"] or "").strip().lower()
            dep_state = (dep_feature["implementation_state"] or "").strip().lower()
            
            # Check if dependency is met based on current feature status
            if status in {"in_progress", "shipped"}:
                if requirement == "complete":
                    if dep_state != "complete" and dep_status != "shipped":
                        issues.append(
                            f"{fid}: requires {dep_id} complete, but {dep_id} is {dep_status}/{dep_state}"
                        )
                elif requirement in {"partial", "any"}:
                    if dep_state == "none" and dep_status == "planned":
                        issues.append(
                            f"{fid}: depends on {dep_id}, but {dep_id} not started"
                        )
    
    # Check for circular dependencies (simple two-level check)
    for f in features:
        fid = f["id"]
        deps = parse_dependencies(f.get("dependencies", "") or "")
        
        for dep_id, _ in deps:
            if dep_id in feature_map:
                dep_deps = parse_dependencies(feature_map[dep_id].get("dependencies", "") or "")
                for dep_dep_id, _ in dep_deps:
                    if dep_dep_id == fid:
                        issues.append(f"Circular dependency: {fid} <-> {dep_id}")
    
    return issues


def main() -> int:
    repo_root = Path.cwd()
    features_path = repo_root / "spec" / "FEATURES.md"

    if not features_path.exists():
        print("Product Management not enabled (spec/FEATURES.md missing).")
        print("Enable it with: bash .agentic/tools/enable-product-management.sh")
        return 0

    md = features_path.read_text(encoding="utf-8")
    features = parse_features(md)

    if not features:
        print("No features found. Add sections like: '## F-0001: Name' in spec/FEATURES.md")
        return 0

    counts = {}
    missing_acceptance = []
    missing_status = []
    pending_acceptance = []

    for f in features:
        status = (f["status"] or "").strip().lower()
        if not status:
            missing_status.append(f["id"])
            status = "unknown"
        counts[status] = counts.get(status, 0) + 1

        acc = (f["acceptance"] or "").strip()
        if not acc or acc.lower() in {"todo", "tbd"}:
            missing_acceptance.append(f["id"])

        acc_flag = (f["accepted"] or "").strip().lower()
        impl_state = (f["implementation_state"] or "").strip().lower()

        # If something is implemented/shipped but not marked accepted, flag it.
        if (status in {"in_progress", "shipped"} or impl_state in {"partial", "complete"}) and acc_flag not in {"yes"}:
            pending_acceptance.append(f["id"])

    print("=== Feature status summary ===")
    for k in sorted(counts.keys()):
        print(f"- {k}: {counts[k]}")

    if missing_status:
        print("\nMissing Status:")
        for fid in missing_status:
            print(f"- {fid}")

    if missing_acceptance:
        print("\nMissing Acceptance link:")
        for fid in missing_acceptance:
            print(f"- {fid} (expected: spec/acceptance/{fid}.md)")

    if pending_acceptance:
        print("\nNeeds acceptance (verify feature works + update spec/FEATURES.md -> Accepted: yes/no):")
        for fid in pending_acceptance:
            print(f"- {fid}")
    
    # Check dependencies
    dep_issues = check_dependency_issues(features)
    if dep_issues:
        print("\nDependency issues:")
        for issue in dep_issues:
            print(f"- {issue}")

    print("\nTip: Keep STATUS.md items referencing feature IDs (F-####) for easy tracking.")
    print("Tip: Run 'bash .agentic/tools/feature_graph.sh' to visualize feature dependencies.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
