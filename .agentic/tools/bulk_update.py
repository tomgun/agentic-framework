#!/usr/bin/env python3
"""
Bulk update features matching criteria.
Safely update multiple features at once.

Usage:
    python bulk_update.py --tags=auth --set priority=high
    python bulk_update.py --status=planned --set owner=alice@example.com
    python bulk_update.py --layer=presentation --add-tag=refactor-needed
"""

import re
import sys
import argparse
from pathlib import Path
from typing import List, Dict

FEATURE_HEADER_RE = re.compile(r"^##\s+(F-\d{4}):\s*(.+?)\s*$")
KEY_RE = re.compile(r"^(\s*-\s+)([\w][\w\s/.-]*?):\s*(.*?)\s*$")
TAG_RE = re.compile(r'\[([^\]]+)\]')


def parse_features_with_positions(md_lines: List[str]) -> List[Dict]:
    """Parse features and track line positions."""
    features = []
    current = None

    for idx, line in enumerate(md_lines):
        m = FEATURE_HEADER_RE.match(line)
        if m:
            if current:
                current["end_line"] = idx - 1
                features.append(current)
            current = {
                "id": m.group(1),
                "name": m.group(2),
                "start_line": idx,
                "fields": {},
            }
            continue

        if not current:
            continue

        km = KEY_RE.match(line)
        if km:
            key = km.group(2).strip().lower()
            val = km.group(3).strip()
            current["fields"][key] = {
                "line_idx": idx,
                "indent": km.group(1),
                "value": val,
            }
    
    if current:
        current["end_line"] = len(md_lines) - 1
        features.append(current)

    return features


def match_feature(feature: Dict, args) -> bool:
    """Check if feature matches filter criteria."""
    fields = feature["fields"]
    
    # Status filter
    if args.status:
        status_val = fields.get("status", {}).get("value", "").lower()
        if status_val != args.status.lower():
            return False
    
    # Layer filter
    if args.layer:
        layer_val = fields.get("layer", {}).get("value", "").lower()
        if layer_val != args.layer.lower():
            return False
    
    # Domain filter
    if args.domain:
        domain_val = fields.get("domain", {}).get("value", "").lower()
        if domain_val != args.domain.lower():
            return False
    
    # Tags filter
    if args.tags:
        tags_val = fields.get("tags", {}).get("value", "")
        tag_match = TAG_RE.search(tags_val)
        if tag_match:
            tags_str = tag_match.group(1)
            feature_tags = [t.strip().lower() for t in tags_str.split(',') if t.strip()]
            for required_tag in args.tags:
                if required_tag.lower() not in feature_tags:
                    return False
        else:
            return False  # No tags but tags filter specified
    
    # Owner filter
    if args.owner:
        owner_val = fields.get("owner", {}).get("value", "")
        if owner_val != args.owner:
            return False
    
    return True


def apply_updates(md_lines: List[str], features: List[Dict], args) -> List[str]:
    """Apply updates to matched features."""
    modified_lines = md_lines.copy()
    matched_features = []
    
    for feature in features:
        if match_feature(feature, args):
            matched_features.append(feature)
    
    if not matched_features:
        print("No features match the specified criteria.")
        return modified_lines
    
    print(f"\nMatched {len(matched_features)} feature(s):")
    for f in matched_features:
        print(f"  - {f['id']}: {f['name']}")
    
    # Show what will change
    print(f"\nChanges to apply:")
    if args.set_field:
        for field_val in args.set_field:
            field, value = field_val.split('=', 1)
            print(f"  Set {field} = {value}")
    if args.add_tag:
        print(f"  Add tags: {', '.join(args.add_tag)}")
    if args.remove_tag:
        print(f"  Remove tags: {', '.join(args.remove_tag)}")
    
    if not args.yes:
        response = input("\nProceed? (yes/no): ")
        if response.lower() != "yes":
            print("Cancelled.")
            sys.exit(0)
    
    # Apply changes
    for feature in matched_features:
        fields = feature["fields"]
        
        # Set fields
        if args.set_field:
            for field_val in args.set_field:
                field, value = field_val.split('=', 1)
                field_lower = field.lower()
                
                if field_lower in fields:
                    # Update existing field
                    line_idx = fields[field_lower]["line_idx"]
                    indent = fields[field_lower]["indent"]
                    modified_lines[line_idx] = f"{indent}{field}: {value}"
                else:
                    # Insert new field after header
                    insert_idx = feature["start_line"] + 1
                    modified_lines.insert(insert_idx, f"- {field}: {value}")
                    # Update line indices for subsequent features
                    for other_f in features:
                        if other_f["start_line"] > insert_idx:
                            other_f["start_line"] += 1
                            other_f["end_line"] += 1
                            for field_info in other_f["fields"].values():
                                if field_info["line_idx"] > insert_idx:
                                    field_info["line_idx"] += 1
        
        # Add/remove tags
        if args.add_tag or args.remove_tag:
            if "tags" in fields:
                line_idx = fields["tags"]["line_idx"]
                indent = fields["tags"]["indent"]
                tags_val = fields["tags"]["value"]
                
                # Parse existing tags
                tag_match = TAG_RE.search(tags_val)
                if tag_match:
                    tags_str = tag_match.group(1)
                    tags = [t.strip() for t in tags_str.split(',') if t.strip()]
                else:
                    tags = []
                
                # Add tags
                if args.add_tag:
                    for tag in args.add_tag:
                        if tag not in tags:
                            tags.append(tag)
                
                # Remove tags
                if args.remove_tag:
                    for tag in args.remove_tag:
                        if tag in tags:
                            tags.remove(tag)
                
                # Update line
                tags_str = ", ".join(tags)
                modified_lines[line_idx] = f"{indent}Tags: [{tags_str}]"
    
    return modified_lines


def main():
    parser = argparse.ArgumentParser(
        description="Bulk update features matching criteria",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Set priority for all auth features
  %(prog)s --tags=auth --set priority=high
  
  # Assign owner to all planned features
  %(prog)s --status=planned --set owner=alice@example.com
  
  # Add tag to presentation layer
  %(prog)s --layer=presentation --add-tag=refactor-needed
  
  # Update domain for specific features
  %(prog)s --tags=login --tags=auth --set domain=authentication
"""
    )
    
    # Filters
    parser.add_argument("--status", help="Filter by status")
    parser.add_argument("--tags", action="append", help="Filter by tags (can specify multiple)")
    parser.add_argument("--layer", help="Filter by layer")
    parser.add_argument("--domain", help="Filter by domain")
    parser.add_argument("--owner", help="Filter by owner")
    
    # Updates
    parser.add_argument("--set", dest="set_field", action="append",
                       help="Set field value (format: field=value)")
    parser.add_argument("--add-tag", action="append", help="Add tag")
    parser.add_argument("--remove-tag", action="append", help="Remove tag")
    
    # Options
    parser.add_argument("--yes", "-y", action="store_true", help="Skip confirmation")
    parser.add_argument("--file", default="spec/FEATURES.md", help="Path to FEATURES.md")
    
    args = parser.parse_args()
    
    # Validate
    if not (args.set_field or args.add_tag or args.remove_tag):
        print("ERROR: Must specify at least one update operation (--set, --add-tag, --remove-tag)",
              file=sys.stderr)
        return 1
    
    # Load file
    features_file = Path(args.file)
    if not features_file.exists():
        print(f"ERROR: {args.file} not found", file=sys.stderr)
        return 1
    
    md_lines = features_file.read_text(encoding="utf-8").splitlines()
    
    # Parse
    features = parse_features_with_positions(md_lines)
    if not features:
        print(f"ERROR: No features found in {args.file}", file=sys.stderr)
        return 1
    
    # Apply updates
    modified_lines = apply_updates(md_lines, features, args)
    
    # Write back
    features_file.write_text("\n".join(modified_lines) + "\n", encoding="utf-8")
    
    print(f"\n✅ Updated {args.file}")
    
    return 0


if __name__ == "__main__":
    sys.exit(main())

