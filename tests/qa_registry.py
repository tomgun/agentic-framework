#!/usr/bin/env python3
"""QA Registry Generator — Central catalog of all QA methods, feature-to-test mapping, and gap analysis.

Scans the framework's test infrastructure and generates docs/QA_REGISTRY.md.

Usage:
    python3 tests/qa_registry.py              # Generate/regenerate QA_REGISTRY.md
    python3 tests/qa_registry.py --check      # Exit non-zero if stale
    python3 tests/qa_registry.py --json       # Output raw data as JSON
"""

import argparse
import glob
import hashlib
import json
import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional


@dataclass
class Feature:
    fid: str  # e.g. "F-0001"
    title: str
    status: str  # planned, implementing, shipped, etc.


@dataclass
class TestCategory:
    name: str
    description: str
    directory: str
    file_pattern: str
    run_command: str
    file_count: int = 0
    feature_ids: set = field(default_factory=set)


@dataclass
class RegistryData:
    features: list  # list[Feature]
    categories: list  # list[TestCategory]
    feature_to_tests: dict  # {fid: {category_name: [file_paths]}}
    untagged_test_files: dict  # {category_name: [file_paths]}


def find_framework_root() -> Path:
    """Find framework root by walking up from this script."""
    p = Path(__file__).resolve().parent
    while p != p.parent:
        if (p / ".agentic" / "spec" / "FEATURES.md").exists():
            return p
        p = p.parent
    raise RuntimeError("Cannot find framework root (no .agentic/spec/FEATURES.md)")


def parse_features(root: Path) -> list:
    """Parse FEATURES.md to get all feature IDs, titles, and statuses."""
    features_file = root / ".agentic" / "spec" / "FEATURES.md"
    if not features_file.exists():
        return []

    features = []
    text = features_file.read_text(errors="replace")

    # Pattern: ## F-XXXX: Title
    header_re = re.compile(r"^## ((?:F|DEV|E)-\d{3,}(?:\.[1-9]\d*)*):\s*(.+)$", re.MULTILINE)
    status_re = re.compile(r"^\*\*Status\*\*:\s*(\S+)", re.MULTILINE)

    headers = list(header_re.finditer(text))
    for i, m in enumerate(headers):
        fid = m.group(1)
        title = m.group(2).strip()
        # Find status between this header and next header (or end)
        start = m.end()
        end = headers[i + 1].start() if i + 1 < len(headers) else len(text)
        section = text[start:end]
        sm = status_re.search(section)
        status = sm.group(1) if sm else "unknown"
        features.append(Feature(fid=fid, title=title, status=status))

    return features


def scan_validate_framework(root: Path) -> dict:
    """Scan validate_framework.sh for # F-XXXX: section headers.

    Returns {fid: [check_descriptions]}.
    """
    vf = root / "tests" / "validate_framework.sh"
    if not vf.exists():
        return {}

    mapping = {}
    text = vf.read_text(errors="replace")

    # Pattern: # F-XXXX: Description  or  # ============... followed by # F-XXXX:
    section_re = re.compile(r"^# ((?:F|DEV|E)-\d{3,}(?:\.[1-9]\d*)*):\s*(.+)$", re.MULTILINE)
    for m in section_re.finditer(text):
        fid = m.group(1)
        desc = m.group(2).strip()
        mapping.setdefault(fid, []).append(desc)

    return mapping


def scan_pytest_files(root: Path) -> tuple:
    """Scan test_*.py files for @feature annotations.

    Returns (tagged: {fid: [file_paths]}, untagged: [file_paths]).
    """
    test_dir = root / "tests"
    tagged = {}
    untagged = []

    pattern = re.compile(r"@feature\s+((?:F|DEV|E)-\d{3,}(?:\.[1-9]\d*)*(?:\s*,\s*(?:F|DEV|E)-\d{3,}(?:\.[1-9]\d*)*)*)", re.IGNORECASE)

    for f in sorted(test_dir.glob("test_*.py")):
        text = f.read_text(errors="replace")
        matches = pattern.findall(text)
        if matches:
            for match in matches:
                for fid in re.findall(r"(?:F|DEV|E)-\d{3,}(?:\.[1-9]\d*)*", match):
                    tagged.setdefault(fid, []).append(str(f.relative_to(root)))
        else:
            untagged.append(str(f.relative_to(root)))

    return tagged, untagged


def scan_llm_tests(root: Path) -> tuple:
    """Scan LLM test scripts for feature references.

    Returns (tagged: {fid: [file_paths]}, untagged: [file_paths], total_count: int).
    """
    llm_dir = root / "tests" / "llm" / "tests"
    if not llm_dir.exists():
        return {}, [], 0

    tagged = {}
    untagged = []
    total = 0
    fid_re = re.compile(r"\b((?:F|DEV|E)-\d{3,}(?:\.[1-9]\d*)*)\b")

    for f in sorted(llm_dir.glob("*.sh")):
        total += 1
        try:
            text = f.read_text(errors="replace")
        except OSError:
            untagged.append(str(f.relative_to(root)))
            continue
        # Only scan comment lines (# prefix) to avoid false positives from
        # heredoc fixture data that often contains F-XXXX in test content
        fids_found = set()
        for line in text.split("\n"):
            stripped = line.strip()
            if stripped.startswith("#"):
                for m in fid_re.finditer(line):
                    fids_found.add(m.group(1))

        rel = str(f.relative_to(root))
        if fids_found:
            for fid in fids_found:
                tagged.setdefault(fid, []).append(rel)
        else:
            untagged.append(rel)

    return tagged, untagged, total


def scan_scenarios(root: Path) -> dict:
    """Scan scenario YAML files. Returns {scenario_name: file_path}."""
    scenario_dir = root / ".agentic" / "lib" / "auto" / "scenarios"
    if not scenario_dir.exists():
        return {}

    scenarios = {}
    for f in sorted(scenario_dir.glob("*.yaml")):
        name = f.stem
        scenarios[name] = str(f.relative_to(root))
    return scenarios


def scan_precommit_gates(root: Path) -> list:
    """Parse pre-commit-check.sh for check catalog.

    Returns list of {number, description, mode}.
    """
    pc = root / ".agentic" / "lib" / "hooks" / "pre-commit-check.sh"
    if not pc.exists():
        return []

    gates = []
    text = pc.read_text(errors="replace")
    # Pattern: # Check N: Description or # Check Na: Description
    check_re = re.compile(
        r"^#\s+Check\s+(\d+\w?):\s*(.+?)(?:\s*\((BLOCKING|advisory|warning)[^)]*\))?$",
        re.MULTILINE,
    )
    for m in check_re.finditer(text):
        num = m.group(1)
        desc = m.group(2).strip()
        mode = m.group(3) or "unknown"
        gates.append({"number": num, "description": desc, "mode": mode})

    return gates


def scan_checklists(root: Path) -> list:
    """Scan checklist files. Returns list of {name, file_path, item_count}."""
    cl_dir = root / ".agentic" / "lib" / "checklists"
    if not cl_dir.exists():
        return []

    checklists = []
    for f in sorted(cl_dir.glob("*.md")):
        text = f.read_text(errors="replace")
        item_count = len(re.findall(r"^- \[", text, re.MULTILINE))
        checklists.append(
            {
                "name": f.stem.replace("_", " ").title(),
                "file": str(f.relative_to(root)),
                "items": item_count,
            }
        )
    return checklists


def scan_infrastructure_tests(root: Path) -> dict:
    """Scan tests/infrastructure/ for structural, mutation, and LLM-mutation tests.

    Returns {subcategory: [file_paths]}.
    """
    infra_dir = root / "tests" / "infrastructure"
    if not infra_dir.exists():
        return {}

    result = {}
    for subdir in ["structural", "mutations", "llm-mutations"]:
        d = infra_dir / subdir
        if d.exists():
            files = sorted(str(f.relative_to(root)) for f in d.glob("*.sh"))
            result[subdir] = files
    return result


def build_registry(root: Path) -> RegistryData:
    """Build complete registry data from all sources."""
    features = parse_features(root)

    # Initialize feature_to_tests for all features
    feature_to_tests = {f.fid: {} for f in features}
    untagged = {}

    # 1. validate_framework.sh (static tests)
    vf_mapping = scan_validate_framework(root)
    for fid, checks in vf_mapping.items():
        if fid in feature_to_tests:
            feature_to_tests[fid]["static"] = checks

    # 2. pytest files
    pytest_tagged, pytest_untagged = scan_pytest_files(root)
    for fid, files in pytest_tagged.items():
        if fid in feature_to_tests:
            feature_to_tests[fid]["pytest"] = files
    untagged["pytest"] = pytest_untagged

    # 3. LLM tests
    llm_tagged, llm_untagged, llm_total = scan_llm_tests(root)
    for fid, files in llm_tagged.items():
        if fid in feature_to_tests:
            feature_to_tests[fid]["llm"] = files
    untagged["llm"] = llm_untagged

    # 4. Scenarios
    scenarios = scan_scenarios(root)

    # 5. Pre-commit gates
    gates = scan_precommit_gates(root)

    # 6. Checklists
    checklists = scan_checklists(root)

    # 7. Infrastructure tests
    infra = scan_infrastructure_tests(root)

    # Build categories
    pytest_dir = root / "tests"
    pytest_count = len(list(pytest_dir.glob("test_*.py")))

    categories = [
        TestCategory(
            name="Static Validation",
            description="Shell-based acceptance criteria checks in validate_framework.sh",
            directory="tests/validate_framework.sh",
            file_pattern="# F-XXXX: sections",
            run_command="bash tests/validate_framework.sh",
            file_count=1,
            feature_ids=set(vf_mapping.keys()),
        ),
        TestCategory(
            name="Pytest",
            description="Python unit and integration tests",
            directory="tests/",
            file_pattern="test_*.py",
            run_command="python3 -m pytest tests/ -v",
            file_count=pytest_count,
            feature_ids=set(pytest_tagged.keys()),
        ),
        TestCategory(
            name="LLM Behavioral",
            description="Tests verifying agent behavior via Claude Code --print mode",
            directory="tests/llm/tests/",
            file_pattern="*.sh",
            run_command="bash tests/llm/run.sh",
            file_count=llm_total,
            feature_ids=set(llm_tagged.keys()),
        ),
        TestCategory(
            name="Scenarios",
            description="End-to-end project build scenarios via framework_verify.py",
            directory=".agentic/lib/auto/scenarios/",
            file_pattern="*.yaml",
            run_command="python3 .agentic/lib/auto/framework_verify.py --scenario todo_app",
            file_count=len(scenarios),
        ),
        TestCategory(
            name="Infrastructure (Structural)",
            description="Structural integrity tests for hooks, gates, and enforcement",
            directory="tests/infrastructure/structural/",
            file_pattern="S*.sh",
            run_command="bash tests/infrastructure/run.sh structural",
            file_count=len(infra.get("structural", [])),
        ),
        TestCategory(
            name="Infrastructure (Mutations)",
            description="Mutation tests — break things and verify detection",
            directory="tests/infrastructure/mutations/",
            file_pattern="M*.sh",
            run_command="bash tests/infrastructure/run.sh mutations",
            file_count=len(infra.get("mutations", [])),
        ),
        TestCategory(
            name="Infrastructure (LLM Mutations)",
            description="LLM-level mutation tests — verify agent behavior under adversarial conditions",
            directory="tests/infrastructure/llm-mutations/",
            file_pattern="M*.sh",
            run_command="bash tests/infrastructure/run.sh llm-mutations",
            file_count=len(infra.get("llm-mutations", [])),
        ),
        TestCategory(
            name="Pre-Commit Gates",
            description=f"{len(gates)} checks enforced before every commit",
            directory=".agentic/lib/hooks/pre-commit-check.sh",
            file_pattern="# Check N:",
            run_command="bash .agentic/lib/hooks/pre-commit-check.sh",
            file_count=len(gates),
        ),
        *(
            [
                TestCategory(
                    name="Checklists",
                    description="Manual/agent-verified checklists for workflow phases",
                    directory=".agentic/lib/checklists/",
                    file_pattern="*.md",
                    run_command="(verified during workflow execution)",
                    file_count=len(checklists),
                ),
            ]
            if checklists
            else []
        ),
    ]

    return RegistryData(
        features=features,
        categories=categories,
        feature_to_tests=feature_to_tests,
        untagged_test_files=untagged,
    )


def generate_markdown(data: RegistryData, root: Path) -> str:
    """Generate QA_REGISTRY.md content."""
    lines = []
    lines.append("# QA Registry")
    lines.append("")
    lines.append("<!-- AUTO-GENERATED by tests/qa_registry.py — do not edit manually -->")
    lines.append("")

    # Summary
    total_features = len(data.features)
    shipped = sum(1 for f in data.features if f.status == "shipped")
    features_with_tests = sum(
        1 for fid, tests in data.feature_to_tests.items() if tests
    )
    lines.append(f"**{total_features}** features tracked, **{shipped}** shipped, "
                 f"**{features_with_tests}** with at least one test mapping.")
    lines.append("")

    # Section 1: Test Methods Catalog
    lines.append("## 1. Test Methods Catalog")
    lines.append("")
    lines.append("| Category | Files | Features Tagged | Run Command |")
    lines.append("|----------|-------|-----------------|-------------|")
    for cat in data.categories:
        feat_count = len(cat.feature_ids) if cat.feature_ids else "—"
        lines.append(
            f"| {cat.name} | {cat.file_count} | {feat_count} | `{cat.run_command}` |"
        )
    lines.append("")

    for cat in data.categories:
        lines.append(f"### {cat.name}")
        lines.append("")
        lines.append(f"{cat.description}")
        lines.append("")
        lines.append(f"- **Location**: `{cat.directory}`")
        lines.append(f"- **Pattern**: `{cat.file_pattern}`")
        lines.append(f"- **Count**: {cat.file_count}")
        lines.append(f"- **Run**: `{cat.run_command}`")
        lines.append("")

    # Section 2: Feature-to-Test Matrix
    lines.append("## 2. Feature-to-Test Matrix")
    lines.append("")
    lines.append("Coverage mapping for each feature. Sparse entries indicate gaps — "
                 "that's the point of this registry.")
    lines.append("")

    lines.append("| Feature | Status | Static | Pytest | LLM | Scenario | Infra | Gate | Checklist |")
    lines.append("|---------|--------|--------|--------|-----|----------|-------|------|-----------|")

    for feat in data.features:
        tests = data.feature_to_tests.get(feat.fid, {})
        static_mark = "x" if tests.get("static") else ""
        pytest_mark = "x" if tests.get("pytest") else ""
        llm_mark = "x" if tests.get("llm") else ""
        # scenarios, infra, gates, checklists don't have per-feature tagging yet
        lines.append(
            f"| {feat.fid} | {feat.status} | {static_mark} | {pytest_mark} | "
            f"{llm_mark} |  |  |  |  |"
        )

    lines.append("")

    # Section 3: Gap Analysis
    lines.append("## 3. Gap Analysis")
    lines.append("")

    # Features with zero test mapping
    untested = [
        f for f in data.features
        if not data.feature_to_tests.get(f.fid)
        and f.status not in ("planned", "deprecated")
    ]
    lines.append(f"### Features with no test mapping ({len(untested)})")
    lines.append("")
    if untested:
        for f in untested:
            lines.append(f"- **{f.fid}**: {f.title} ({f.status})")
    else:
        lines.append("All non-planned features have at least one test mapping.")
    lines.append("")

    # Untagged test files
    lines.append("### Untagged test files")
    lines.append("")
    lines.append("Test files without `@feature F-XXXX` annotations — "
                 "their coverage cannot be mapped to specific features.")
    lines.append("")
    for cat_name, files in data.untagged_test_files.items():
        if files:
            lines.append(f"**{cat_name}** ({len(files)} untagged):")
            for fp in files:
                lines.append(f"- `{fp}`")
            lines.append("")

    # Annotation density
    pytest_tagged_count = len(data.untagged_test_files.get("pytest", []))
    pytest_total = next(
        (c.file_count for c in data.categories if c.name == "Pytest"), 0
    )
    pytest_annotated = pytest_total - pytest_tagged_count
    lines.append("### Annotation density")
    lines.append("")
    static_cat = next((c for c in data.categories if c.name == "Static Validation"), None)
    static_tagged = len(static_cat.feature_ids) if static_cat and static_cat.feature_ids else 0
    lines.append(f"- **validate_framework.sh**: {static_tagged} features tagged (primary mapping source)")
    lines.append(f"- **pytest**: {pytest_annotated}/{pytest_total} files annotated with `@feature`")

    llm_untagged_count = len(data.untagged_test_files.get("llm", []))
    llm_total = next(
        (c.file_count for c in data.categories if c.name == "LLM Behavioral"), 0
    )
    llm_annotated = llm_total - llm_untagged_count
    lines.append(f"- **LLM tests**: {llm_annotated}/{llm_total} files with feature references")
    lines.append("")

    # Section 4: Quick Run Guide
    lines.append("## 4. Quick Run Guide")
    lines.append("")
    lines.append("### Fast (~2 min) — static + unit")
    lines.append("```bash")
    lines.append("bash tests/validate_framework.sh")
    lines.append("python3 -m pytest tests/ -x -q")
    lines.append("```")
    lines.append("")
    lines.append("### Medium (~30 min) — + LLM behavioral")
    lines.append("```bash")
    lines.append("bash tests/validate_framework.sh")
    lines.append("python3 -m pytest tests/ -v")
    lines.append("bash tests/llm/run.sh")
    lines.append("bash tests/infrastructure/run.sh")
    lines.append("```")
    lines.append("")
    lines.append("### Full (~2 hr) — + scenarios")
    lines.append("```bash")
    lines.append("bash tests/validate_framework.sh")
    lines.append("python3 -m pytest tests/ -v")
    lines.append("bash tests/llm/run.sh")
    lines.append("bash tests/infrastructure/run.sh")
    lines.append("python3 .agentic/lib/auto/framework_verify.py --all")
    lines.append("```")
    lines.append("")

    return "\n".join(lines)


def content_hash(content: str) -> str:
    """Hash content for staleness checking (ignoring whitespace variations)."""
    normalized = re.sub(r"\s+", " ", content.strip())
    return hashlib.sha256(normalized.encode()).hexdigest()[:16]


def main():
    parser = argparse.ArgumentParser(description="QA Registry Generator")
    parser.add_argument("--check", action="store_true", help="Check if registry is stale")
    parser.add_argument("--json", action="store_true", help="Output raw data as JSON")
    args = parser.parse_args()

    root = find_framework_root()
    data = build_registry(root)

    if args.json:
        # JSON output for programmatic consumption
        output = {
            "features": [
                {"fid": f.fid, "title": f.title, "status": f.status}
                for f in data.features
            ],
            "categories": [
                {
                    "name": c.name,
                    "file_count": c.file_count,
                    "feature_ids": sorted(c.feature_ids) if c.feature_ids else [],
                }
                for c in data.categories
            ],
            "feature_to_tests": {
                fid: {k: v for k, v in tests.items()}
                for fid, tests in data.feature_to_tests.items()
                if tests
            },
            "untagged": {k: v for k, v in data.untagged_test_files.items()},
        }
        print(json.dumps(output, indent=2))
        return 0

    new_content = generate_markdown(data, root)

    if args.check:
        registry_path = root / "docs" / "QA_REGISTRY.md"
        if not registry_path.exists():
            print("STALE: docs/QA_REGISTRY.md does not exist. Run: python3 tests/qa_registry.py")
            return 1

        existing = registry_path.read_text(errors="replace")
        if content_hash(existing) != content_hash(new_content):
            print("STALE: docs/QA_REGISTRY.md differs from generated content. Run: python3 tests/qa_registry.py")
            return 1

        print("OK: docs/QA_REGISTRY.md is up to date.")
        return 0

    # Generate/regenerate
    output_path = root / "docs" / "QA_REGISTRY.md"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(new_content)
    print(f"Generated {output_path.relative_to(root)}")

    # Print summary
    total = len(data.features)
    with_tests = sum(1 for fid, t in data.feature_to_tests.items() if t)
    print(f"  {total} features, {with_tests} with test mappings, "
          f"{total - with_tests} unmapped")

    return 0


if __name__ == "__main__":
    sys.exit(main())
