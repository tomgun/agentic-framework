#!/usr/bin/env python3
"""
continue_here.py: Generate .continue-here.md for quick context recovery

This tool synthesizes information from:
- JOURNAL.md (recent work)
- STATUS.md/PRODUCT.md (current state)
- HUMAN_NEEDED.md (blockers)
- spec/FEATURES.md (active features, if PM mode)
- .agentic/pipeline/ (active pipelines, if PM mode)

Into a single, concise .continue-here.md file for the next session.

Usage:
    python3 .agentic/tools/continue_here.py
    python3 .agentic/tools/continue_here.py --output /path/to/output.md

Author: Kipinä Software Oy / Tomas Günther
License: GPL-3.0 (Part of Agentic AI Framework)
"""

import os
import sys
import json
import argparse
from datetime import datetime
from pathlib import Path


def read_file(path):
    """Read file content, return empty string if not found."""
    try:
        with open(path, 'r', encoding='utf-8') as f:
            return f.read()
    except FileNotFoundError:
        return ""


def get_recent_journal_entries(journal_content, max_entries=5):
    """Extract the last N journal entries."""
    if not journal_content:
        return ""
    
    # Split by heading markers (## )
    entries = []
    current_entry = []
    
    for line in journal_content.split('\n'):
        if line.startswith('## '):
            if current_entry:
                entries.append('\n'.join(current_entry))
            current_entry = [line]
        else:
            if current_entry:
                current_entry.append(line)
    
    if current_entry:
        entries.append('\n'.join(current_entry))
    
    # Return last N entries
    recent = entries[-max_entries:] if len(entries) > max_entries else entries
    return '\n\n'.join(recent)


def get_active_features(features_content):
    """Extract features with status 'in_progress' or 'partial'."""
    if not features_content:
        return []
    
    active = []
    current_feature = None
    
    for line in features_content.split('\n'):
        # Look for feature IDs
        if line.startswith('### F-'):
            current_feature = {'id': line.strip('#').strip()}
        elif current_feature:
            if 'Status:' in line and ('in_progress' in line or 'in-progress' in line):
                current_feature['status'] = 'in_progress'
            elif 'Title:' in line:
                current_feature['title'] = line.split('Title:', 1)[1].strip()
            elif 'Priority:' in line:
                current_feature['priority'] = line.split('Priority:', 1)[1].strip()
            
            # If we have enough info and status is in_progress, add it
            if line.startswith('### F-') and current_feature.get('status') == 'in_progress':
                if 'title' in current_feature:
                    active.append(current_feature)
                current_feature = {'id': line.strip('#').strip()}
    
    # Check last feature
    if current_feature and current_feature.get('status') == 'in_progress' and 'title' in current_feature:
        active.append(current_feature)
    
    return active


def get_active_pipelines(pipeline_dir):
    """Find active pipeline files."""
    if not os.path.isdir(pipeline_dir):
        return []
    
    pipelines = []
    for filename in os.listdir(pipeline_dir):
        if filename.startswith('F-') and filename.endswith('-pipeline.md'):
            feature_id = filename.split('-')[0] + '-' + filename.split('-')[1]
            content = read_file(os.path.join(pipeline_dir, filename))
            
            # Extract current stage
            current_stage = "unknown"
            for line in content.split('\n'):
                if '**Current:**' in line or '→' in line:
                    current_stage = line.split('**')[-1].split('→')[-1].strip()
                    break
            
            pipelines.append({'id': feature_id, 'file': filename, 'stage': current_stage})
    
    return pipelines


def detect_mode(project_root):
    """Detect if project is Core or Core+PM mode."""
    stack_file = os.path.join(project_root, '.agentic', 'STACK.md')
    stack_content = read_file(stack_file)
    
    if 'profile: core+product' in stack_content.lower() or 'profile: core+pm' in stack_content.lower():
        return 'Core+PM'
    return 'Core'


def generate_continue_here(project_root, output_path=None):
    """Generate .continue-here.md file."""
    
    # Detect mode
    mode = detect_mode(project_root)
    
    # Read source files
    journal_path = os.path.join(project_root, 'JOURNAL.md')
    status_path = os.path.join(project_root, 'STATUS.md')
    product_path = os.path.join(project_root, 'PRODUCT.md')
    human_needed_path = os.path.join(project_root, 'HUMAN_NEEDED.md')
    features_path = os.path.join(project_root, 'spec', 'FEATURES.md')
    pipeline_dir = os.path.join(project_root, '.agentic', 'pipeline')
    
    journal_content = read_file(journal_path)
    status_content = read_file(status_path)
    product_content = read_file(product_path)
    human_needed_content = read_file(human_needed_path)
    features_content = read_file(features_path) if mode == 'Core+PM' else ""
    
    # Extract information
    recent_work = get_recent_journal_entries(journal_content)
    active_features = get_active_features(features_content) if mode == 'Core+PM' else []
    active_pipelines = get_active_pipelines(pipeline_dir) if mode == 'Core+PM' else []
    has_blockers = len(human_needed_content.strip()) > 100  # Rough check for content beyond template
    
    # Determine primary status document
    primary_status = status_content if status_content else product_content
    
    # Extract "Current Focus" or "Next Steps" from status
    current_focus = ""
    for line in primary_status.split('\n'):
        if 'current focus' in line.lower() or 'next' in line.lower():
            # Capture this line and a few following lines
            idx = primary_status.split('\n').index(line)
            current_focus = '\n'.join(primary_status.split('\n')[idx:idx+5])
            break
    
    # Build .continue-here.md
    output = []
    output.append("# Continue Here")
    output.append("")
    output.append(f"**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    output.append(f"**Project Mode:** {mode}")
    output.append("")
    output.append("---")
    output.append("")
    
    # Section 1: Quick Summary
    output.append("## Quick Summary")
    output.append("")
    if current_focus:
        output.append(current_focus)
    else:
        output.append("*No explicit 'Current Focus' found in STATUS.md or PRODUCT.md.*")
    output.append("")
    
    # Section 2: Active Work
    if mode == 'Core+PM' and active_features:
        output.append("## Active Features")
        output.append("")
        for feature in active_features:
            priority = feature.get('priority', 'unknown')
            output.append(f"- **{feature['id']}** ({priority}): {feature.get('title', 'Unknown')}")
        output.append("")
    
    if mode == 'Core+PM' and active_pipelines:
        output.append("## Active Pipelines")
        output.append("")
        for pipeline in active_pipelines:
            output.append(f"- **{pipeline['id']}**: Currently at stage `{pipeline['stage']}`")
            output.append(f"  File: `.agentic/pipeline/{pipeline['file']}`")
        output.append("")
    
    # Section 3: Blockers
    if has_blockers:
        output.append("## ⚠️ Human Needed")
        output.append("")
        output.append("**There are items requiring human decision in `HUMAN_NEEDED.md`.**")
        output.append("")
        output.append("Please review and resolve before continuing with implementation.")
        output.append("")
    
    # Section 4: Recent Work
    output.append("## Recent Work (from JOURNAL.md)")
    output.append("")
    if recent_work:
        output.append(recent_work)
    else:
        output.append("*No recent journal entries found.*")
    output.append("")
    
    # Section 5: Next Steps
    output.append("## Recommended Next Steps")
    output.append("")
    if has_blockers:
        output.append("1. **Resolve blockers** in `HUMAN_NEEDED.md`")
    if active_pipelines:
        output.append("2. **Continue active pipelines** (see above)")
    if active_features:
        output.append("3. **Advance active features** (see above)")
    output.append("- Review `STATUS.md` or `PRODUCT.md` for overall project state")
    if mode == 'Core+PM':
        output.append("- Check `spec/FEATURES.md` for planned work")
    output.append("- Run `bash .agentic/tools/version_check.sh` to ensure framework is up-to-date")
    output.append("")
    
    # Section 6: Key Files
    output.append("## Key Files to Review")
    output.append("")
    if mode == 'Core+PM':
        output.append("- `spec/FEATURES.md` - Feature registry")
    output.append("- `STATUS.md` or `PRODUCT.md` - Current project state")
    output.append("- `JOURNAL.md` - Work history")
    output.append("- `HUMAN_NEEDED.md` - Blockers & decisions")
    if mode == 'Core+PM':
        output.append("- `.agentic/pipeline/` - Agent handoffs")
    output.append("")
    
    # Footer
    output.append("---")
    output.append("")
    output.append("*This file is auto-generated. To regenerate: `python3 .agentic/tools/continue_here.py`*")
    
    # Write output
    if output_path is None:
        output_path = os.path.join(project_root, '.continue-here.md')
    
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(output))
    
    print(f"✓ Generated: {output_path}")
    return output_path


def main():
    parser = argparse.ArgumentParser(
        description='Generate .continue-here.md for quick context recovery'
    )
    parser.add_argument(
        '--output', '-o',
        help='Output file path (default: .continue-here.md in project root)',
        default=None
    )
    parser.add_argument(
        '--project', '-p',
        help='Project root directory (default: current directory)',
        default=os.getcwd()
    )
    
    args = parser.parse_args()
    
    project_root = os.path.abspath(args.project)
    
    # Verify this is an agentic project
    if not os.path.isdir(os.path.join(project_root, '.agentic')):
        print("Error: Not an agentic project (no .agentic/ folder found)", file=sys.stderr)
        print(f"Searched in: {project_root}", file=sys.stderr)
        sys.exit(1)
    
    generate_continue_here(project_root, args.output)


if __name__ == '__main__':
    main()

