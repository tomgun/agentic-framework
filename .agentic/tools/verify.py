#!/usr/bin/env python3
"""
Verification tool: validates spec consistency and optionally runs tests.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path


FEATURE_ID_RE = re.compile(r"\b(F-\d{4})\b")
NFR_ID_RE = re.compile(r"\b(NFR-\d{4})\b")
ADR_ID_RE = re.compile(r"\b(ADR-\d{4})\b")


def read_profile(root: Path) -> str:
    """
    Determine profile.

    - Prefer explicit `Profile:` in STACK.md.
    - If not present, infer:
      - If spec/ exists -> core+product
      - else -> core
    """
    stack = root / "STACK.md"
    if stack.exists():
        try:
            md = stack.read_text(encoding="utf-8")
            m = re.search(r"(?m)^\s*-\s*Profile:\s*([a-z+_-]+)\s*$", md)
            if m:
                val = m.group(1).strip()
                if val in {"core", "core+product"}:
                    return val
        except Exception:
            pass

    if (root / "spec").is_dir():
        return "core+product"
    return "core"


def core_checks(root: Path) -> list[str]:
    required = ["STACK.md", "CONTEXT_PACK.md", "STATUS.md", "JOURNAL.md", "HUMAN_NEEDED.md", "AGENTS.md"]
    issues: list[str] = []
    for p in required:
        if not (root / p).exists():
            issues.append(f"Missing {p} (run: bash .agentic/init/scaffold.sh --profile core)")
    return issues


def find_broken_links(root: Path) -> list[str]:
    """Find broken cross-references in spec files."""
    issues = []
    spec_dir = root / "spec"
    
    if not spec_dir.exists():
        return ["spec/ directory not found"]
    
    # Collect all valid IDs
    valid_features = set()
    valid_nfrs = set()
    valid_adrs = set()
    
    # Parse FEATURES.md
    features_path = spec_dir / "FEATURES.md"
    if features_path.exists():
        try:
            content = features_path.read_text(encoding="utf-8")
            valid_features = set(re.findall(r"^##\s+(F-\d{4}):", content, re.MULTILINE))
        except Exception:
            pass
    
    # Parse NFR.md
    nfr_path = spec_dir / "NFR.md"
    if nfr_path.exists():
        try:
            content = nfr_path.read_text(encoding="utf-8")
            valid_nfrs = set(re.findall(r"^##\s+(NFR-\d{4}):", content, re.MULTILINE))
        except Exception:
            pass
    
    # Parse ADR files
    adr_dir = spec_dir / "adr"
    if adr_dir.exists():
        for adr_file in adr_dir.glob("ADR-*.md"):
            match = re.match(r"ADR-(\d{4})", adr_file.stem)
            if match:
                valid_adrs.add(adr_file.stem[:8])  # ADR-0001
    
    # Check all spec files for references
    spec_files = [
        spec_dir / "PRD.md",
        spec_dir / "TECH_SPEC.md",
        spec_dir / "OVERVIEW.md",
        spec_dir / "FEATURES.md",
        spec_dir / "NFR.md",
        spec_dir / "LESSONS.md",
        root / "STATUS.md",
        root / "CONTEXT_PACK.md",
    ]
    
    for spec_file in spec_files:
        if not spec_file.exists():
            continue
        
        try:
            content = spec_file.read_text(encoding="utf-8")
            rel_path = spec_file.relative_to(root)
            
            # Check feature references
            for fid in FEATURE_ID_RE.findall(content):
                if fid not in valid_features:
                    issues.append(f"{rel_path}: references {fid} which doesn't exist")
            
            # Check NFR references
            for nfr_id in NFR_ID_RE.findall(content):
                if nfr_id not in valid_nfrs:
                    issues.append(f"{rel_path}: references {nfr_id} which doesn't exist")
            
            # Check ADR references
            for adr_id in ADR_ID_RE.findall(content):
                if adr_id not in valid_adrs:
                    issues.append(f"{rel_path}: references {adr_id} which doesn't exist")
        
        except Exception:
            pass
    
    return issues


def check_acceptance_files(root: Path) -> list[str]:
    """Check that all non-deprecated features have acceptance files."""
    issues = []
    features_path = root / "spec" / "FEATURES.md"
    
    if not features_path.exists():
        return []
    
    try:
        content = features_path.read_text(encoding="utf-8")
    except Exception:
        return []
    
    # Find all features
    feature_blocks = re.findall(
        r"^##\s+(F-\d{4}):\s*(.+?)$.*?^- Status:\s*(\w+)",
        content,
        re.MULTILINE | re.DOTALL
    )
    
    acceptance_dir = root / "spec" / "acceptance"
    
    for fid, name, status in feature_blocks:
        if status.strip().lower() in {"deprecated"}:
            continue
        
        acc_file = acceptance_dir / f"{fid}.md"
        if not acc_file.exists():
            issues.append(f"{fid}: no acceptance file at spec/acceptance/{fid}.md")
    
    return issues


def read_test_command(root: Path) -> str | None:
    """Read test command from STACK.md if present."""
    stack_path = root / "STACK.md"
    
    if not stack_path.exists():
        return None
    
    try:
        content = stack_path.read_text(encoding="utf-8")
        
        # Look for test command patterns
        patterns = [
            r"(?:^|\n)[\s-]*[Tt]est[:\s]+[`\"]?([^\n`\"]+)[`\"]?",
            r"(?:^|\n)[\s-]*[Tt]est command[:\s]+[`\"]?([^\n`\"]+)[`\"]?",
            r"(?:^|\n)[\s-]*[Rr]un tests?[:\s]+[`\"]?([^\n`\"]+)[`\"]?",
        ]
        
        for pattern in patterns:
            match = re.search(pattern, content)
            if match:
                return match.group(1).strip()
    
    except Exception:
        pass
    
    return None


def main() -> int:
    root = Path.cwd()
    profile = read_profile(root)
    all_issues = []
    
    print("=== agentic verify ===\n")
    print(f"Profile: {profile}\n")

    if profile == "core":
        print("Core profile: skipping Product Management validations (spec/).\n")
        core_issues = core_checks(root)
        if core_issues:
            print(f"Found {len(core_issues)} issue(s):")
            for issue in core_issues:
                print(f"  - {issue}")
            return 1
        print("✓ Core checks passed")
        return 0
    
    # Check for broken cross-references
    print("Checking cross-references...")
    link_issues = find_broken_links(root)
    all_issues.extend(link_issues)
    
    if link_issues:
        print(f"Found {len(link_issues)} broken reference(s)")
        for issue in link_issues:
            print(f"  - {issue}")
    else:
        print("  ✓ No broken references")
    
    print()
    
    # Check acceptance files
    print("Checking acceptance files...")
    acc_issues = check_acceptance_files(root)
    all_issues.extend(acc_issues)
    
    if acc_issues:
        print(f"Found {len(acc_issues)} missing acceptance file(s)")
        for issue in acc_issues:
            print(f"  - {issue}")
    else:
        print("  ✓ All features have acceptance files")
    
    print()
    
    # Test command info
    test_cmd = read_test_command(root)
    if test_cmd:
        print(f"Test command from STACK.md: {test_cmd}")
        print("  (run verify.sh to execute tests)")
    else:
        print("No test command found in STACK.md")
    
    print()
    
    if all_issues:
        print(f"Total issues: {len(all_issues)}")
        return 1
    else:
        print("✓ All checks passed")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())

