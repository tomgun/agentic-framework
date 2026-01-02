#!/usr/bin/env python3
"""
Format Validation Tool - validates that key files follow expected formats.
See: .agentic/workflows/format_validation.md
"""
from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import List, Tuple


def validate_features_md(path: Path) -> List[str]:
    """Validate FEATURES.md format."""
    if not path.exists():
        return []
    
    issues = []
    content = path.read_text(encoding="utf-8")
    lines = content.splitlines()
    
    # Check for feature headers
    feature_pattern = re.compile(r"^## (F-\d{4}):\s*(.+?)\s*$")
    features_found = 0
    
    for i, line in enumerate(lines, 1):
        match = feature_pattern.match(line)
        if match:
            features_found += 1
            feature_id = match.group(1)
            
            # Check for required fields in next ~30 lines
            section = "\n".join(lines[i:min(i+30, len(lines))])
            
            if "- Status:" not in section:
                issues.append(f"{feature_id} (line {i}): Missing '- Status:' field")
            else:
                # Check status value
                status_match = re.search(r"- Status:\s*(\w+)", section)
                if status_match:
                    status = status_match.group(1)
                    valid_statuses = {"shipped", "in_progress", "planned", "deprecated"}
                    if status not in valid_statuses:
                        issues.append(
                            f"{feature_id} (line {i}): Invalid status '{status}'. "
                            f"Must be one of: {', '.join(valid_statuses)}"
                        )
    
    if features_found == 0:
        issues.append("No features found. Expected format: ## F-####: Feature name")
    
    return issues


def validate_journal_md(path: Path) -> List[str]:
    """Validate JOURNAL.md format."""
    if not path.exists():
        return []
    
    issues = []
    content = path.read_text(encoding="utf-8")
    lines = content.splitlines()
    
    # Check for session headers (support both formats)
    session_pattern_a = re.compile(r"^### Session:\s*(.+?)\s*$")
    session_pattern_b = re.compile(r"^## (\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}.*?)$")
    
    sessions_found = 0
    
    for i, line in enumerate(lines, 1):
        match_a = session_pattern_a.match(line)
        match_b = session_pattern_b.match(line)
        
        if match_a or match_b:
            sessions_found += 1
            
            # Validate date format
            date_str = match_a.group(1) if match_a else match_b.group(1)
            date_str_clean = date_str.split(" - ")[0].strip()  # Remove description if present
            
            # Try common date formats
            date_formats = [
                r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$",  # YYYY-MM-DD HH:MM
                r"^\d{4}-\d{2}-\d{2}-\d{4}$",        # YYYY-MM-DD-HHMM
                r"^\d{4}-\d{2}-\d{2}$",              # YYYY-MM-DD
            ]
            
            if not any(re.match(fmt, date_str_clean) for fmt in date_formats):
                issues.append(
                    f"Line {i}: Session date '{date_str_clean}' doesn't match expected formats. "
                    f"Use: YYYY-MM-DD HH:MM or YYYY-MM-DD-HHMM or YYYY-MM-DD"
                )
    
    if sessions_found == 0:
        # Check if file has content (not just template)
        if len(content) > 500 and "Session Log" not in content:
            issues.append(
                "No session entries found. Expected format: "
                "'### Session: YYYY-MM-DD HH:MM' or '## YYYY-MM-DD HH:MM - Description'"
            )
    
    return issues


def validate_status_md(path: Path) -> List[str]:
    """Validate STATUS.md format."""
    if not path.exists():
        return []
    
    issues = []
    content = path.read_text(encoding="utf-8")
    
    # Check for required sections
    required_sections = [
        "## Current focus",
        "## In progress",
        "## Next up",
    ]
    
    for section in required_sections:
        if section not in content:
            issues.append(f"Missing required section: '{section}'")
    
    # Check section headers are level 2 (##)
    section_pattern = re.compile(r"^(#{1,6})\s+(Current focus|In progress|Next up|Roadmap)", re.MULTILINE)
    for match in section_pattern.finditer(content):
        level = len(match.group(1))
        section = match.group(2)
        if level != 2:
            hashes = "#" * level
            issues.append(
                f"Section '{section}' uses level {level} heading ({hashes}). "
                f"Should use level 2 (##)"
            )
    
    return issues


def validate_human_needed_md(path: Path) -> List[str]:
    """Validate HUMAN_NEEDED.md format."""
    if not path.exists():
        return []
    
    issues = []
    content = path.read_text(encoding="utf-8")
    lines = content.splitlines()
    
    # Check for HN-#### items
    hn_pattern = re.compile(r"^### (HN-\d{4}):\s*(.+?)\s*$")
    
    for i, line in enumerate(lines, 1):
        match = hn_pattern.match(line)
        if match:
            hn_id = match.group(1)
            
            # Check if under "Active items" section
            # Look backwards to find section
            in_active_section = False
            for prev_line in lines[max(0, i-20):i]:
                if "## Active items" in prev_line:
                    in_active_section = True
                    break
                if "## Resolved" in prev_line or "## Example" in prev_line:
                    in_active_section = False
                    break
            
            if not in_active_section:
                issues.append(
                    f"{hn_id} (line {i}): Should be under '## Active items needing attention' section"
                )
    
    return issues


def validate_nfr_md(path: Path) -> List[str]:
    """Validate NFR.md format."""
    if not path.exists():
        return []
    
    issues = []
    content = path.read_text(encoding="utf-8")
    
    # Check for NFR headers
    nfr_pattern = re.compile(r"^## (NFR-\d{4}):\s*(.+?)\s*$", re.MULTILINE)
    nfrs_found = len(nfr_pattern.findall(content))
    
    if nfrs_found == 0 and len(content) > 500:  # Not just template
        issues.append("No NFRs found. Expected format: ## NFR-####: NFR name")
    
    return issues


def main() -> int:
    """Run format validation on all key files."""
    repo_root = Path.cwd()
    
    print("=== Agentic Format Validation ===")
    print()
    
    files_to_check = [
        ("spec/FEATURES.md", validate_features_md),
        ("JOURNAL.md", validate_journal_md),
        ("STATUS.md", validate_status_md),
        ("HUMAN_NEEDED.md", validate_human_needed_md),
        ("spec/NFR.md", validate_nfr_md),
    ]
    
    total_issues = 0
    
    for file_path_str, validator in files_to_check:
        file_path = repo_root / file_path_str
        
        if not file_path.exists():
            print(f"⊘ {file_path_str} (not found, skipping)")
            continue
        
        issues = validator(file_path)
        
        if issues:
            print(f"❌ {file_path_str}")
            for issue in issues:
                print(f"   - {issue}")
            total_issues += len(issues)
        else:
            print(f"✓ {file_path_str}")
    
    print()
    
    if total_issues > 0:
        print(f"Found {total_issues} format issue(s)")
        print()
        print("See: .agentic/workflows/format_validation.md for format expectations")
        return 1
    else:
        print("✓ All format checks passed")
        return 0


if __name__ == "__main__":
    sys.exit(main())

