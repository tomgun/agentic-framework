"""
dod.py -- Definition of Done configuration per task type.

Parses dod.conf to determine which DoD checks apply for a given task type.
Task types are resolved via cascade: explicit flag > contract field > FEATURES.md > default.

Usage (CLI):
    python3 dod.py resolve-type F-XXXX [--type TYPE] [--project-root PATH]
    python3 dod.py checklist --type TYPE [--project-root PATH]
    python3 dod.py skipped-gates --type TYPE [--project-root PATH]
"""
from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import Optional

_LIB_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(_LIB_DIR))

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Alias mapping from FEATURES.md Type values to DoD types
TYPE_ALIASES: dict[str, str] = {
    "research": "spike",
    "capability": "implementation",
    "meta": "implementation",
    "infrastructure": "implementation",
}

# Human-readable labels for each check key
CHECK_LABELS: dict[str, str] = {
    "ac_met": "All acceptance criteria met",
    "tests_exist": "Tests written for feature",
    "tests_pass": "All tests passing",
    "docs_updated": "Docs updated (if behavior changed)",
    "code_reviewed": "Code reviewed (self-review at minimum)",
    "smoke_tested": "Smoke tested (actually RUN it)",
    "journal_updated": "JOURNAL.md updated",
    "features_updated": ".agentic/spec/FEATURES.md updated (status: shipped)",
}

# Checklist display order
CHECKLIST_ORDER = [
    "ac_met",
    "tests_exist",
    "tests_pass",
    "features_updated",
    "docs_updated",
    "code_reviewed",
    "smoke_tested",
    "journal_updated",
]

# Mapping from DoD check keys to gate names they control
CHECK_TO_GATES: dict[str, list[str]] = {
    "tests_exist": ["criteria_set_to_tests_written"],
    "tests_pass": ["implementing_to_verified"],
    "docs_updated": ["verified_to_documented"],
}

# ---------------------------------------------------------------------------
# Cache
# ---------------------------------------------------------------------------

_conf_cache: dict[str, dict[str, dict[str, str]]] = {}


def clear_cache() -> None:
    """Clear all module-level caches. Use in tests or after config changes."""
    _conf_cache.clear()


# ---------------------------------------------------------------------------
# Core functions
# ---------------------------------------------------------------------------

def parse_dod_conf(project_root: Path) -> dict[str, dict[str, str]]:
    """Parse dod.conf and return {type: {check_key: enforcement}}."""
    cache_key = str(project_root)
    if cache_key in _conf_cache:
        return _conf_cache[cache_key]

    conf_file = _LIB_DIR / "presets" / "dod.conf"
    result: dict[str, dict[str, str]] = {}

    if not conf_file.exists():
        _conf_cache[cache_key] = result
        return result

    for line in conf_file.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip()
        if "." not in key:
            continue
        task_type, _, check_key = key.partition(".")
        if task_type not in result:
            result[task_type] = {}
        result[task_type][check_key] = value

    _conf_cache[cache_key] = result
    return result


def resolve_task_type(
    feature_id: str,
    project_root: Path,
    explicit_type: Optional[str] = None,
) -> str:
    """Resolve task type via cascade: explicit > contract > FEATURES.md > default.

    Unknown types fall through to 'implementation'.
    """
    conf = parse_dod_conf(project_root)
    valid_types = set(conf.keys()) if conf else {"implementation"}

    def _normalize(raw: str) -> str:
        t = raw.lower().strip()
        t = TYPE_ALIASES.get(t, t)
        return t if t in valid_types else "implementation"

    # 1. Explicit CLI flag
    if explicit_type:
        return _normalize(explicit_type)

    # 2. Contract task_type field
    if feature_id:
        try:
            from paths import get_paths
            paths = get_paths(project_root)
            contract_file = paths.contracts_dir / f"{feature_id}.yaml"
            if contract_file.exists():
                from contracts import load_contract
                c = load_contract(contract_file)
                if c.task_type:
                    return _normalize(c.task_type)
        except Exception:
            pass

    # 3. FEATURES.md Type field
    if feature_id:
        try:
            features_file = project_root / ".agentic" / "spec" / "FEATURES.md"
            if features_file.exists():
                content = features_file.read_text()
                pattern = rf"(## {re.escape(feature_id)}\b.*?)(?=\n---|\n## F-|\Z)"
                match = re.search(pattern, content, re.DOTALL)
                if match:
                    block = match.group(1)
                    m = re.search(r"\*\*Type\*\*:\s*(\w+)", block)
                    if m:
                        return _normalize(m.group(1))
        except Exception:
            pass

    # 4. Default
    return "implementation"


def get_dod_items(
    task_type: str, project_root: Path
) -> list[tuple[str, str, str]]:
    """Return DoD checklist items for a task type.

    Returns list of (check_key, label, enforcement).
    """
    conf = parse_dod_conf(project_root)
    type_conf = conf.get(task_type, conf.get("implementation", {}))
    items = []
    for check_key in CHECKLIST_ORDER:
        enforcement = type_conf.get(check_key, "required")
        label = CHECK_LABELS.get(check_key, check_key)
        items.append((check_key, label, enforcement))
    return items


def get_skipped_gates(task_type: str, project_root: Path) -> set[str]:
    """Return set of gate names that should be skipped for this task type."""
    conf = parse_dod_conf(project_root)
    type_conf = conf.get(task_type, conf.get("implementation", {}))
    skipped: set[str] = set()
    for check_key, gate_names in CHECK_TO_GATES.items():
        if type_conf.get(check_key) == "skip":
            skipped.update(gate_names)
    return skipped


def format_checklist(task_type: str, project_root: Path) -> str:
    """Format DoD checklist for terminal display."""
    items = get_dod_items(task_type, project_root)
    lines = []
    for check_key, label, enforcement in items:
        if enforcement == "skip":
            lines.append(f"  [skip] {label}")
        elif enforcement == "advisory":
            lines.append(f"  [~] {label} (advisory)")
        else:
            lines.append(f"  [ ] {label}")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _cli():
    import argparse

    parser = argparse.ArgumentParser(description="Definition of Done configuration")
    sub = parser.add_subparsers(dest="command")

    # resolve-type
    rt = sub.add_parser("resolve-type", help="Resolve task type for a feature")
    rt.add_argument("feature_id", nargs="?", default="")
    rt.add_argument("--type", dest="explicit_type", default=None)
    rt.add_argument("--project-root", default=".")

    # checklist
    cl = sub.add_parser("checklist", help="Show DoD checklist for a type")
    cl.add_argument("--type", dest="task_type", default="implementation")
    cl.add_argument("--project-root", default=".")

    # skipped-gates
    sg = sub.add_parser("skipped-gates", help="Show gates skipped for a type")
    sg.add_argument("--type", dest="task_type", default="implementation")
    sg.add_argument("--project-root", default=".")

    args = parser.parse_args()
    project_root = Path(args.project_root).resolve()

    if args.command == "resolve-type":
        print(resolve_task_type(args.feature_id, project_root, args.explicit_type))
    elif args.command == "checklist":
        print(format_checklist(args.task_type, project_root))
    elif args.command == "skipped-gates":
        skipped = get_skipped_gates(args.task_type, project_root)
        for g in sorted(skipped):
            print(g)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    _cli()
