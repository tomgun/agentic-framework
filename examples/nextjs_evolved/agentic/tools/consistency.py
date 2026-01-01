#!/usr/bin/env python3
"""
Spec consistency checker - verifies alignment between FEATURES.md, code, and tests.
Catches common inconsistencies that indicate stale documentation.
"""
from __future__ import annotations

import re
from pathlib import Path


FEATURE_HEADER_RE = re.compile(r"^##\s+(F-\d{4}):", re.MULTILINE)


def parse_features(md: str) -> dict[str, dict]:
    """Parse FEATURES.md."""
    features = {}
    current = None
    
    for line in md.splitlines():
        m = FEATURE_HEADER_RE.match(line)
        if m:
            if current:
                features[current["id"]] = current
            current = {
                "id": m.group(1),
                "status": None,
                "state": None,
                "code": None,
                "tests_unit": None,
                "accepted": None,
            }
            continue
        
        if not current:
            continue
        
        line_lower = line.strip().lower()
        if line.strip().startswith("- Status:"):
            current["status"] = line.split(":", 1)[1].strip()
        elif line.strip().startswith("- State:"):
            current["state"] = line.split(":", 1)[1].strip()
        elif line.strip().startswith("- Code:"):
            current["code"] = line.split(":", 1)[1].strip()
        elif line.strip().startswith("- Unit:"):
            current["tests_unit"] = line.split(":", 1)[1].strip()
        elif line.strip().startswith("- Accepted:"):
            current["accepted"] = line.split(":", 1)[1].strip()
    
    if current:
        features[current["id"]] = current
    
    return features


def check_consistency(features: dict[str, dict], repo_root: Path) -> list[str]:
    """Check for consistency issues."""
    issues = []
    
    for fid, meta in features.items():
        status = (meta.get("status") or "").strip().lower()
        state = (meta.get("state") or "").strip().lower()
        code = (meta.get("code") or "").strip()
        tests = (meta.get("tests_unit") or "").strip().lower()
        accepted = (meta.get("accepted") or "").strip().lower()
        
        # Issue: Shipped but not complete
        if status == "shipped" and state != "complete":
            issues.append(f"{fid}: Status is 'shipped' but State is '{state}' (should be 'complete')")
        
        # Issue: Shipped but not accepted
        if status == "shipped" and accepted != "yes":
            issues.append(f"{fid}: Status is 'shipped' but Accepted is '{accepted}' (should be 'yes')")
        
        # Issue: Complete but no code paths
        if state == "complete" and (not code or code in {"<!-- paths/modules -->", "(to be filled)", "none"}):
            issues.append(f"{fid}: State is 'complete' but Code field is empty/placeholder")
        
        # Issue: Complete but tests are todo
        if state == "complete" and tests in {"todo", "tbd"}:
            issues.append(f"{fid}: State is 'complete' but tests are marked 'todo'")
        
        # Issue: In progress but state is none
        if status == "in_progress" and state == "none":
            issues.append(f"{fid}: Status is 'in_progress' but State is 'none' (should be at least 'partial')")
        
        # Issue: Code paths don't exist
        if code and code not in {"<!-- paths/modules -->", "(to be filled)", "none", "n/a"}:
            code_paths = [p.strip() for p in code.split(",")]
            for code_path in code_paths:
                if code_path and not (repo_root / code_path).exists():
                    issues.append(f"{fid}: Code path '{code_path}' doesn't exist")
        
        # Issue: Acceptance file missing for non-deprecated features
        if status not in {"deprecated"} and state not in {"none"}:
            acc_file = repo_root / "spec" / "acceptance" / f"{fid}.md"
            if not acc_file.exists():
                issues.append(f"{fid}: Missing acceptance file spec/acceptance/{fid}.md")
    
    return issues


def check_context_pack_staleness(repo_root: Path) -> list[str]:
    """Check for stale placeholders in CONTEXT_PACK.md."""
    issues = []
    context_path = repo_root / "CONTEXT_PACK.md"
    
    if not context_path.exists():
        return []
    
    try:
        content = context_path.read_text(encoding="utf-8")
        
        # Check for common placeholder patterns
        placeholders = [
            "(Not yet created)",
            "(To be created)",
            "(TBD)",
            "(TODO)",
        ]
        
        for placeholder in placeholders:
            if placeholder in content:
                count = content.count(placeholder)
                issues.append(f"CONTEXT_PACK.md contains '{placeholder}' ({count} occurrence(s))")
    
    except Exception:
        pass
    
    return issues


def check_status_staleness(repo_root: Path, features: dict[str, dict]) -> list[str]:
    """Check for completed items still in 'In progress' section of STATUS.md."""
    issues = []
    status_path = repo_root / "STATUS.md"
    
    if not status_path.exists():
        return []
    
    try:
        content = status_path.read_text(encoding="utf-8")
        
        # Find "In progress" section
        in_progress_match = re.search(r"## In progress\n(.*?)(?=\n##|$)", content, re.DOTALL)
        if in_progress_match:
            in_progress_section = in_progress_match.group(1)
            
            # Find feature IDs mentioned
            feature_ids = re.findall(r"\b(F-\d{4})\b", in_progress_section)
            
            for fid in feature_ids:
                if fid in features:
                    status = (features[fid].get("status") or "").strip().lower()
                    if status in {"shipped", "deprecated"}:
                        issues.append(f"STATUS.md 'In progress' mentions {fid} but it's '{status}'")
    
    except Exception:
        pass
    
    return issues


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
    
    print("=== Spec Consistency Check ===\n")
    
    # Check feature consistency
    feature_issues = check_consistency(features, repo_root)
    
    # Check CONTEXT_PACK staleness
    context_issues = check_context_pack_staleness(repo_root)
    
    # Check STATUS staleness
    status_issues = check_status_staleness(repo_root, features)
    
    all_issues = feature_issues + context_issues + status_issues
    
    if not all_issues:
        print("✓ No consistency issues found!")
        return 0
    
    print(f"Found {len(all_issues)} issue(s):\n")
    
    for issue in all_issues:
        print(f"⚠ {issue}")
    
    print("\nThese indicate documentation is out of sync with implementation.")
    print("Update docs to match reality.")
    
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

