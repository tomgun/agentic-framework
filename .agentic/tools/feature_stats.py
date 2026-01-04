#!/usr/bin/env python3
"""
Feature statistics dashboard.
Shows feature distribution, velocity, health metrics.

Usage:
    python feature_stats.py
    python feature_stats.py --period=30  # Last 30 days
"""

import re
import sys
import argparse
from pathlib import Path
from datetime import datetime, timedelta
from collections import Counter, defaultdict
from typing import List, Dict

FEATURE_HEADER_RE = re.compile(r"^##\s+(F-\d{4}):\s*(.+?)\s*$")
KEY_RE = re.compile(r"^\s*-\s+([\w][\w\s/.-]*?):\s*(.*?)\s*$")
TAG_RE = re.compile(r'\[([^\]]+)\]')
DATE_RE = re.compile(r'(\d{4}-\d{2}-\d{2})')


def parse_features(md: str) -> List[Dict]:
    """Parse FEATURES.md into feature dicts."""
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
                "tags": [],
                "layer": None,
                "domain": None,
                "priority": None,
                "owner": None,
                "complexity": None,
                "accepted": False,
                "accepted_at": None,
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
            current["status"] = val.lower() if val else None
        elif key == "tags":
            tag_match = TAG_RE.search(val)
            if tag_match:
                tags_str = tag_match.group(1)
                current["tags"] = [t.strip().lower() for t in tags_str.split(',') if t.strip()]
        elif key == "layer":
            current["layer"] = val.lower() if val and val.lower() not in ["none", ""] else None
        elif key == "domain":
            current["domain"] = val.lower() if val and val.lower() not in ["none", ""] else None
        elif key == "priority":
            current["priority"] = val.lower() if val and val.lower() not in ["none", ""] else None
        elif key == "owner":
            current["owner"] = val if val and val.lower() not in ["none", ""] else None
        elif key == "complexity":
            current["complexity"] = val.upper() if val and val.upper() in ['S', 'M', 'L', 'XL'] else None
        elif key == "accepted":
            current["accepted"] = val.lower() in ["yes", "true"]
        elif key == "accepted at":
            date_match = DATE_RE.search(val)
            if date_match:
                try:
                    current["accepted_at"] = datetime.strptime(date_match.group(1), "%Y-%m-%d")
                except:
                    pass
    
    if current:
        features.append(current)

    return features


def print_dashboard(features: List[Dict], period_days: int = None):
    """Print comprehensive dashboard."""
    total = len(features)
    
    print("=" * 70)
    print(f"{'FEATURE STATISTICS DASHBOARD':^70}")
    print("=" * 70)
    print(f"\nTotal Features: {total}")
    
    if period_days:
        cutoff = datetime.now() - timedelta(days=period_days)
        recent_features = [f for f in features if f.get("accepted_at") and f["accepted_at"] >= cutoff]
        print(f"Period: Last {period_days} days ({len(recent_features)} features accepted)")
    
    print("\n" + "-" * 70)
    
    # Status distribution
    print("\n📊 STATUS DISTRIBUTION")
    print("-" * 70)
    status_counts = Counter(f.get("status", "unknown") for f in features)
    status_order = ["planned", "in_progress", "shipped", "deprecated", "unknown"]
    
    for status in status_order:
        count = status_counts.get(status, 0)
        pct = (count / total * 100) if total > 0 else 0
        bar = "█" * int(pct / 2)
        print(f"{status:15} {count:4} ({pct:5.1f}%) {bar}")
    
    # Layer distribution
    print("\n" + "-" * 70)
    print("\n🏗️  LAYER DISTRIBUTION")
    print("-" * 70)
    layer_counts = Counter(f.get("layer") or "none" for f in features)
    for layer, count in sorted(layer_counts.items(), key=lambda x: -x[1]):
        pct = (count / total * 100) if total > 0 else 0
        bar = "█" * int(pct / 2)
        print(f"{layer:20} {count:4} ({pct:5.1f}%) {bar}")
    
    # Domain distribution
    print("\n" + "-" * 70)
    print("\n🏢 DOMAIN DISTRIBUTION")
    print("-" * 70)
    domain_counts = Counter(f.get("domain") or "none" for f in features)
    for domain, count in sorted(domain_counts.items(), key=lambda x: -x[1])[:10]:
        pct = (count / total * 100) if total > 0 else 0
        bar = "█" * int(pct / 2)
        print(f"{domain:20} {count:4} ({pct:5.1f}%) {bar}")
    
    # Priority distribution
    print("\n" + "-" * 70)
    print("\n⚡ PRIORITY DISTRIBUTION")
    print("-" * 70)
    priority_counts = Counter(f.get("priority") or "none" for f in features)
    priority_order = {"critical": 1, "high": 2, "medium": 3, "low": 4, "none": 5}
    for priority, count in sorted(priority_counts.items(), key=lambda x: priority_order.get(x[0], 99)):
        pct = (count / total * 100) if total > 0 else 0
        bar = "█" * int(pct / 2)
        print(f"{priority:15} {count:4} ({pct:5.1f}%) {bar}")
    
    # Complexity distribution
    print("\n" + "-" * 70)
    print("\n📏 COMPLEXITY DISTRIBUTION")
    print("-" * 70)
    complexity_counts = Counter(f.get("complexity") or "none" for f in features)
    complexity_order = {"S": 1, "M": 2, "L": 3, "XL": 4, "none": 5}
    for complexity, count in sorted(complexity_counts.items(), key=lambda x: complexity_order.get(x[0], 99)):
        pct = (count / total * 100) if total > 0 else 0
        bar = "█" * int(pct / 2)
        label = {"S": "S (hours)", "M": "M (days)", "L": "L (weeks)", "XL": "XL (months)"}.get(complexity, complexity)
        print(f"{label:20} {count:4} ({pct:5.1f}%) {bar}")
    
    # Top tags
    all_tags = []
    for f in features:
        all_tags.extend(f.get("tags", []))
    
    if all_tags:
        print("\n" + "-" * 70)
        print("\n🏷️  TOP TAGS")
        print("-" * 70)
        tag_counts = Counter(all_tags)
        for tag, count in tag_counts.most_common(15):
            pct = (count / total * 100) if total > 0 else 0
            bar = "█" * int(pct / 2)
            print(f"{tag:20} {count:4} ({pct:5.1f}%) {bar}")
    
    # Owner distribution
    owner_counts = Counter(f.get("owner") or "unassigned" for f in features)
    if len(owner_counts) > 1 or "unassigned" not in owner_counts:
        print("\n" + "-" * 70)
        print("\n👤 OWNER DISTRIBUTION")
        print("-" * 70)
        for owner, count in sorted(owner_counts.items(), key=lambda x: -x[1])[:10]:
            pct = (count / total * 100) if total > 0 else 0
            bar = "█" * int(pct / 2)
            print(f"{owner:30} {count:4} ({pct:5.1f}%) {bar}")
    
    # Health metrics
    print("\n" + "-" * 70)
    print("\n🏥 HEALTH METRICS")
    print("-" * 70)
    
    shipped = [f for f in features if f.get("status") == "shipped"]
    accepted = [f for f in features if f.get("accepted")]
    in_progress = [f for f in features if f.get("status") == "in_progress"]
    
    print(f"Shipped features:                {len(shipped):4}")
    print(f"Accepted features:               {len(accepted):4}")
    print(f"Shipped but not accepted:        {len([f for f in shipped if not f.get('accepted')]):4} ⚠️")
    print(f"In progress:                     {len(in_progress):4}")
    
    # Velocity (if we have accepted_at dates)
    accepted_with_dates = [f for f in features if f.get("accepted_at")]
    if accepted_with_dates:
        print(f"\nFeatures with acceptance dates:  {len(accepted_with_dates):4}")
        
        # Last 30 days
        last_30 = datetime.now() - timedelta(days=30)
        recent_30 = [f for f in accepted_with_dates if f["accepted_at"] >= last_30]
        print(f"Accepted in last 30 days:        {len(recent_30):4}")
        
        # Last 7 days
        last_7 = datetime.now() - timedelta(days=7)
        recent_7 = [f for f in accepted_with_dates if f["accepted_at"] >= last_7]
        print(f"Accepted in last 7 days:         {len(recent_7):4}")
        
        if len(recent_30) > 0:
            velocity_month = len(recent_30) / 30 * 7  # Features per week
            print(f"\nVelocity (features/week):        {velocity_month:5.1f}")
    
    print("\n" + "=" * 70)


def main():
    parser = argparse.ArgumentParser(
        description="Feature statistics dashboard"
    )
    parser.add_argument("--period", type=int, help="Show stats for last N days")
    parser.add_argument("--file", default="spec/FEATURES.md", help="Path to FEATURES.md")
    
    args = parser.parse_args()
    
    features_file = Path(args.file)
    if not features_file.exists():
        print(f"ERROR: {args.file} not found", file=sys.stderr)
        return 1
    
    md = features_file.read_text(encoding="utf-8")
    features = parse_features(md)
    
    if not features:
        print(f"ERROR: No features found in {args.file}", file=sys.stderr)
        return 1
    
    print_dashboard(features, args.period)
    
    return 0


if __name__ == "__main__":
    sys.exit(main())

