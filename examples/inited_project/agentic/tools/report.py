#!/usr/bin/env python3
import re
import sys
from pathlib import Path


FEATURE_HEADER_RE = re.compile(r"^##\s+(F-\d{4}):\s*(.+?)\s*$")
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
        elif key == "acceptance":
            current["acceptance"] = val
        elif key == "state":
            current["implementation_state"] = val
        elif key == "accepted":
            current["accepted"] = val

    return features


def main() -> int:
    repo_root = Path.cwd()
    features_path = repo_root / "spec" / "FEATURES.md"

    if not features_path.exists():
        print("Missing spec/FEATURES.md (run: bash agentic/init/scaffold.sh)")
        return 1

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

    print("\nTip: Keep STATUS.md items referencing feature IDs (F-####) for easy tracking.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


