#!/usr/bin/env python3
"""
What Changed - shows what was implemented/changed since a date or between dates.
Parses JOURNAL.md to show features worked on, tests added, etc.
"""
from __future__ import annotations

import re
import sys
from datetime import datetime
from pathlib import Path


def parse_journal_entries(journal_path: Path) -> list[dict]:
    """Parse JOURNAL.md into structured session entries."""
    if not journal_path.exists():
        return []
    
    content = journal_path.read_text(encoding="utf-8")
    entries = []
    
    # Find all session entries
    session_pattern = r"### Session: (.+?)\n(.*?)(?=\n### Session:|$)"
    matches = re.findall(session_pattern, content, re.DOTALL)
    
    for session_date, session_content in matches:
        # Parse date
        try:
            # Try various date formats
            for fmt in ["%Y-%m-%d %H:%M", "%Y-%m-%d-%H%M", "%Y-%m-%d"]:
                try:
                    date = datetime.strptime(session_date.strip(), fmt)
                    break
                except ValueError:
                    continue
            else:
                date = None
        except:
            date = None
        
        # Extract features mentioned
        features = set(re.findall(r"\b(F-\d{4})\b", session_content))
        
        # Extract accomplished items
        accomplished = []
        if "**Accomplished**:" in session_content:
            acc_section = session_content.split("**Accomplished**:")[1].split("**")[0]
            accomplished = [line.strip("- ").strip() for line in acc_section.split("\n") if line.strip().startswith("-")]
        
        entries.append({
            "date": date,
            "date_str": session_date.strip(),
            "features": features,
            "accomplished": accomplished,
            "content": session_content
        })
    
    return entries


def main() -> int:
    repo_root = Path.cwd()
    journal_path = repo_root / ".agentic-journal" / "JOURNAL.md"
    if not journal_path.exists():
        journal_path = repo_root / "JOURNAL.md"

    if not journal_path.exists():
        print("JOURNAL.md not found")
        return 1
    
    # Parse command line args
    if len(sys.argv) > 1:
        if sys.argv[1] in ["-h", "--help"]:
            print("Usage: python3 whatchanged.py [days] [--verbose]")
            print("")
            print("Shows what changed in recent sessions from JOURNAL.md")
            print("")
            print("Examples:")
            print("  python3 whatchanged.py       # Last 7 days")
            print("  python3 whatchanged.py 14    # Last 14 days")
            print("  python3 whatchanged.py --verbose  # Show full details")
            return 0
        
        try:
            days = int(sys.argv[1])
        except ValueError:
            days = 7
    else:
        days = 7
    
    verbose = "--verbose" in sys.argv or "-v" in sys.argv
    
    entries = parse_journal_entries(journal_path)
    
    if not entries:
        print("No session entries found in JOURNAL.md")
        return 0
    
    # Filter by date if dates are available
    now = datetime.now()
    recent_entries = []
    
    for entry in entries:
        if entry["date"]:
            age_days = (now - entry["date"]).days
            if age_days <= days:
                recent_entries.append(entry)
        else:
            # Include entries without parseable dates
            recent_entries.append(entry)
    
    if not recent_entries:
        print(f"No sessions found in last {days} days")
        return 0
    
    print(f"=== Changes in last {days} days ===\n")
    
    # Collect all features worked on
    all_features = set()
    for entry in recent_entries:
        all_features.update(entry["features"])
    
    if all_features:
        print(f"Features worked on: {', '.join(sorted(all_features))}")
        print()
    
    # Show sessions
    for entry in reversed(recent_entries):  # Most recent last
        print(f"📅 Session: {entry['date_str']}")
        
        if entry["features"]:
            print(f"   Features: {', '.join(sorted(entry['features']))}")
        
        if entry["accomplished"]:
            print("   Accomplished:")
            for item in entry["accomplished"][:5]:  # Limit to 5 items
                print(f"     • {item}")
            if len(entry["accomplished"]) > 5:
                print(f"     ... and {len(entry['accomplished']) - 5} more")
        
        if verbose:
            print(f"\n{entry['content']}\n")
            print("-" * 60)
        
        print()
    
    print(f"Total sessions: {len(recent_entries)}")
    
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

