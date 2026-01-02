#!/usr/bin/env python3
from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path


@dataclass
class Check:
    path: str
    kind: str  # "file" | "dir"
    purpose: str


def read_profile(root: Path) -> str:
    """
    Determine profile.

    - Prefer explicit `Profile:` in STACK.md.
    - If not present, infer:
      - If spec/ exists OR STATUS.md exists -> core+product (legacy default)
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

    if (root / "spec").is_dir() or (root / "STATUS.md").is_file():
        return "core+product"
    return "core"


def checks_for_profile(profile: str) -> list[Check]:
    core = [
        Check("AGENTS.md", "file", "agent entrypoint (rules + read-first)"),
        Check("CONTEXT_PACK.md", "file", "durable starting context"),
        Check("PRODUCT.md", "file", "what we're building + current state"),
        Check("STACK.md", "file", "how to run/test + constraints"),
        Check("JOURNAL.md", "file", "session-by-session progress log"),
        Check("HUMAN_NEEDED.md", "file", "escalation protocol"),
        Check("docs", "dir", "system docs (long-lived)"),
    ]
    if profile == "core":
        return core

    # core+product
    return core + [
        Check("STATUS.md", "file", "current focus + next steps"),
        Check("spec", "dir", "project truth folder"),
        Check("spec/OVERVIEW.md", "file", "vision + current state + pointers"),
        Check("spec/FEATURES.md", "file", "feature registry + acceptance + tests"),
        Check("spec/NFR.md", "file", "non-functional constraints"),
        Check("spec/acceptance", "dir", "per-feature acceptance criteria"),
        Check("spec/LESSONS.md", "file", "lessons/caveats"),
        Check("spec/adr", "dir", "architecture decisions"),
    ]

FEATURE_ID_RE = re.compile(r"\b(F-\d{4})\b")
NFR_ID_RE = re.compile(r"\b(NFR-\d{4})\b")
FEATURE_HEADER_RE = re.compile(r"^##\s+(F-\d{4}):\s*(.+?)\s*$", re.MULTILINE)
STATUS_VALUES = {"planned", "in_progress", "shipped", "deprecated"}


def looks_like_template(text: str) -> bool:
    first_lines = "\n".join(text.splitlines()[:3]).lower()
    return "(template)" in first_lines or first_lines.strip().endswith("template")


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
                "acceptance": None,
                "state": None,
                "accepted": None,
                "nfrs": [],
            }
            continue
        
        if not current:
            continue
        
        # Parse key-value lines
        if line.strip().startswith("- Status:"):
            val = line.split(":", 1)[1].strip()
            current["status"] = val
        elif line.strip().startswith("- Acceptance:"):
            val = line.split(":", 1)[1].strip()
            current["acceptance"] = val
        elif line.strip().startswith("- State:"):
            val = line.split(":", 1)[1].strip()
            current["state"] = val
        elif line.strip().startswith("- Accepted:"):
            val = line.split(":", 1)[1].strip()
            current["accepted"] = val
        elif line.strip().startswith("- NFRs:"):
            val = line.split(":", 1)[1].strip()
            if val and val.lower() not in {"none", "n/a"}:
                current["nfrs"] = NFR_ID_RE.findall(val)
    
    if current:
        features[current["id"]] = current
    
    return features


def parse_nfr_ids(md: str) -> set[str]:
    """Parse NFR.md and return set of NFR IDs."""
    nfr_header_re = re.compile(r"^##\s+(NFR-\d{4}):", re.MULTILINE)
    return set(nfr_header_re.findall(md))


def validate_features(root: Path) -> list[str]:
    """Validate FEATURES.md structure and cross-references."""
    issues = []
    features_path = root / "spec" / "FEATURES.md"
    
    if not features_path.exists():
        return ["spec/FEATURES.md does not exist"]
    
    try:
        features_md = features_path.read_text(encoding="utf-8")
    except Exception as e:
        return [f"Could not read spec/FEATURES.md: {e}"]
    
    features = parse_features(features_md)
    
    if not features:
        issues.append("No features found in spec/FEATURES.md")
        return issues
    
    # Check acceptance files
    acceptance_dir = root / "spec" / "acceptance"
    for fid, meta in features.items():
        if meta["status"] in {"deprecated"}:
            continue
        
        # Check acceptance file exists
        acceptance_file = acceptance_dir / f"{fid}.md"
        acc_val = meta.get("acceptance", "").strip()
        if acc_val and not acc_val.lower() in {"todo", "tbd", "none", "n/a"}:
            if not acceptance_file.exists():
                issues.append(f"{fid}: acceptance file spec/acceptance/{fid}.md not found")
        
        # Check status validity
        status = meta.get("status", "").strip().lower()
        if status and status not in STATUS_VALUES:
            issues.append(f"{fid}: invalid status '{status}' (expected: {', '.join(STATUS_VALUES)})")
        
        # Check for inconsistencies
        if status == "shipped" and meta.get("accepted") != "yes":
            issues.append(f"{fid}: status is 'shipped' but Accepted is not 'yes'")
        
        state = meta.get("state", "").strip().lower()
        if state == "complete" and "todo" in str(meta).lower():
            # Check if any test fields say "todo"
            if "Tests:" in features_md:
                # Simple heuristic check
                issues.append(f"{fid}: state is 'complete' but some tests may be marked 'todo'")
    
    return issues


def validate_status_refs(root: Path, features: set[str]) -> list[str]:
    """Validate that STATUS.md references valid feature IDs."""
    issues = []
    status_path = root / "STATUS.md"
    
    if not status_path.exists():
        return []
    
    try:
        status_md = status_path.read_text(encoding="utf-8")
    except Exception:
        return []
    
    referenced_features = set(FEATURE_ID_RE.findall(status_md))
    
    for fid in referenced_features:
        if fid not in features:
            issues.append(f"STATUS.md references {fid} but it doesn't exist in spec/FEATURES.md")
    
    return issues


def validate_nfr_refs(root: Path) -> list[str]:
    """Validate NFR cross-references."""
    issues = []
    
    nfr_path = root / "spec" / "NFR.md"
    if not nfr_path.exists():
        return []
    
    try:
        nfr_md = nfr_path.read_text(encoding="utf-8")
    except Exception:
        return []
    
    nfr_ids = parse_nfr_ids(nfr_md)
    
    # Check if FEATURES.md references non-existent NFRs
    features_path = root / "spec" / "FEATURES.md"
    if features_path.exists():
        try:
            features_md = features_path.read_text(encoding="utf-8")
            features = parse_features(features_md)
            
            for fid, meta in features.items():
                for nfr_id in meta.get("nfrs", []):
                    if nfr_id not in nfr_ids:
                        issues.append(f"{fid} references {nfr_id} but it doesn't exist in spec/NFR.md")
        except Exception:
            pass
    
    return issues


def main() -> int:
    root = Path.cwd()
    profile = read_profile(root)
    missing: list[Check] = []
    empty_files: list[Check] = []
    template_like: list[Check] = []

    checks = checks_for_profile(profile)
    for c in checks:
        p = root / c.path
        if c.kind == "dir":
            if not p.is_dir():
                missing.append(c)
            continue

        # file
        if not p.is_file():
            missing.append(c)
            continue

        try:
            data = p.read_text(encoding="utf-8")
        except Exception:
            data = ""

        if len(data.strip()) == 0:
            empty_files.append(c)
        elif looks_like_template(data) and p.name not in {"FEATURES.md"}:
            template_like.append(c)

    print("=== agentic doctor ===")
    print(f"\nProfile: {profile}")

    if missing:
        print("\nMissing (run scaffold):")
        for c in missing:
            print(f"- {c.path} ({c.purpose})")

    if empty_files:
        print("\nEmpty (fill in):")
        for c in empty_files:
            print(f"- {c.path} ({c.purpose})")

    if template_like:
        print("\nLooks like template content (consider filling/renaming):")
        for c in template_like:
            print(f"- {c.path} ({c.purpose})")

    print(f"\nProfile: {profile}")

    # Enhanced validations (core+product only)
    validation_issues = []
    if profile == "core+product":
        features_issues = validate_features(root)
        validation_issues.extend(features_issues)

        # Get feature IDs for cross-reference checks
        features_path = root / "spec" / "FEATURES.md"
        if features_path.exists():
            try:
                features_md = features_path.read_text(encoding="utf-8")
                features = parse_features(features_md)
                feature_ids = set(features.keys())

                status_issues = validate_status_refs(root, feature_ids)
                validation_issues.extend(status_issues)
            except Exception:
                pass

        nfr_issues = validate_nfr_refs(root)
        validation_issues.extend(nfr_issues)
    else:
        print("\nNote: Core profile detected — skipping Product Management validations (spec/ + STATUS.md).")
    
    if validation_issues:
        print("\nValidation issues:")
        for issue in validation_issues:
            print(f"- {issue}")

    if not (missing or empty_files or template_like or validation_issues):
        print("\nOK: baseline project artifacts present and valid")

    print("\nNext commands:")
    print("- bash .agentic/tools/brief.sh")
    if profile == "core+product":
        print("- bash .agentic/tools/report.sh")
    print("- bash .agentic/tools/verify.sh")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
