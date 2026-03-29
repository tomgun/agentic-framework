"""
contracts.py — Contract parser and validator for the Agentic Framework.

Usage:
    from pathlib import Path
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from contracts import load_contract, load_all_contracts, validate_contract

    contract = load_contract(Path("spec/contracts/F-002.yaml"))
    all_contracts = load_all_contracts(Path("spec/contracts"))
    errors = validate_contract(contract)
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional

from ids import get_depth, MAX_DEPTH


# ---------------------------------------------------------------------------
# YAML loading — requires PyYAML
# ---------------------------------------------------------------------------

def _load_yaml(path: Path) -> dict[str, Any]:
    """Load a YAML file. Requires PyYAML."""
    try:
        import yaml
    except ImportError:
        raise RuntimeError(
            "PyYAML is required for contract parsing. "
            "Install with: pip install pyyaml"
        )
    with open(path, "r") as f:
        data = yaml.safe_load(f)
    if not isinstance(data, dict):
        raise ValueError(f"Contract file must be a YAML mapping: {path}")
    return data


def _dump_yaml(data: dict[str, Any], path: Path) -> None:
    """Write a dict as YAML."""
    try:
        import yaml
    except ImportError:
        raise RuntimeError("PyYAML is required. Install with: pip install pyyaml")
    with open(path, "w") as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class Assertion:
    id: str
    text: str
    type: str  # "structural" | "behavioral"
    verify: Optional[str] = None
    tests: list[str] = field(default_factory=list)
    draft: bool = False

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> "Assertion":
        return cls(
            id=d["id"],
            text=d["text"],
            type=d["type"],
            verify=d.get("verify"),
            tests=d.get("tests", []),
            draft=d.get("draft", False),
        )

    def to_dict(self) -> dict[str, Any]:
        d: dict[str, Any] = {"id": self.id, "text": self.text, "type": self.type}
        if self.verify is not None:
            d["verify"] = self.verify
        if self.tests:
            d["tests"] = self.tests
        if self.draft:
            d["draft"] = self.draft
        return d


@dataclass
class Migration:
    id: str
    date: str
    trigger: str
    reason: str
    changes: list[str]
    approved_by: str = "user"

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> "Migration":
        return cls(
            id=d["id"],
            date=str(d["date"]),
            trigger=d["trigger"],
            reason=d["reason"],
            changes=d.get("changes", []),
            approved_by=d.get("approved_by", "user"),
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "date": self.date,
            "trigger": self.trigger,
            "reason": self.reason,
            "changes": self.changes,
            "approved_by": self.approved_by,
        }


@dataclass
class Scenario:
    name: str
    given: str
    when: str
    then: str

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> "Scenario":
        return cls(name=d["name"], given=d["given"], when=d["when"], then=d["then"])

    def to_dict(self) -> dict[str, Any]:
        return {"name": self.name, "given": self.given, "when": self.when, "then": self.then}


@dataclass
class Contract:
    id: str
    name: str
    lifecycle: str
    description: str
    assertions: list[Assertion]
    # Optional fields with defaults
    status: Optional[str] = None
    since: Optional[str] = None
    profile: str = "both"
    protection: str = "none"
    category: str = "uncategorized"
    component: Optional[str] = None
    consolidated_from: list[str] = field(default_factory=list)
    user_input: str = ""
    parent: Optional[str] = None
    children: list[str] = field(default_factory=list)
    tags: list[str] = field(default_factory=list)
    nfr_refs: list[str] = field(default_factory=list)
    scenarios: list[Scenario] = field(default_factory=list)
    migrations: list[Migration] = field(default_factory=list)
    notes: Optional[str] = None
    task_type: Optional[str] = None  # implementation | spike | bugfix | docs
    source_path: Optional[Path] = None

    @classmethod
    def from_dict(cls, d: dict[str, Any], source_path: Optional[Path] = None) -> "Contract":
        assertions = [Assertion.from_dict(a) for a in d.get("assertions", [])]
        scenarios = [Scenario.from_dict(s) for s in d.get("scenarios", [])]
        migrations = [Migration.from_dict(m) for m in d.get("migrations", [])]
        return cls(
            id=d["id"],
            name=d["name"],
            lifecycle=d.get("lifecycle", _status_to_lifecycle(d.get("status", "exploring"))),
            description=d.get("description", ""),
            assertions=assertions,
            status=d.get("status"),
            since=d.get("since"),
            profile=d.get("profile", "both"),
            protection=d.get("protection", "none"),
            category=d.get("category", "uncategorized"),
            component=d.get("component"),
            consolidated_from=d.get("consolidated_from", []),
            user_input=d.get("user_input", ""),
            parent=d.get("parent"),
            children=d.get("children", []),
            tags=d.get("tags", []),
            nfr_refs=d.get("nfr_refs", []),
            scenarios=scenarios,
            migrations=migrations,
            notes=d.get("notes"),
            task_type=d.get("task_type"),
            source_path=source_path,
        )

    def to_dict(self) -> dict[str, Any]:
        d: dict[str, Any] = {
            "id": self.id,
            "name": self.name,
            "lifecycle": self.lifecycle,
        }
        if self.status:
            d["status"] = self.status
        if self.since:
            d["since"] = self.since
        d["profile"] = self.profile
        d["protection"] = self.protection
        if self.category != "uncategorized":
            d["category"] = self.category
        if self.component is not None:
            d["component"] = self.component
        if self.consolidated_from:
            d["consolidated_from"] = self.consolidated_from
        d["description"] = self.description
        d["user_input"] = self.user_input
        d["assertions"] = [a.to_dict() for a in self.assertions]
        if self.parent:
            d["parent"] = self.parent
        if self.children:
            d["children"] = self.children
        if self.tags:
            d["tags"] = self.tags
        if self.nfr_refs:
            d["nfr_refs"] = self.nfr_refs
        if self.scenarios:
            d["scenarios"] = [s.to_dict() for s in self.scenarios]
        if self.migrations:
            d["migrations"] = [m.to_dict() for m in self.migrations]
        if self.notes:
            d["notes"] = self.notes
        if self.task_type:
            d["task_type"] = self.task_type
        return d

    @property
    def is_shipped(self) -> bool:
        return self.lifecycle == "shipped"

    @property
    def is_protected(self) -> bool:
        return self.protection == "contract" and self.is_shipped

    @property
    def has_pending_input(self) -> bool:
        return bool(self.user_input and self.user_input.strip())

    @property
    def structural_assertions(self) -> list[Assertion]:
        return [a for a in self.assertions if a.type == "structural" and not a.draft]

    @property
    def behavioral_assertions(self) -> list[Assertion]:
        return [a for a in self.assertions if a.type == "behavioral" and not a.draft]

    @property
    def draft_assertions(self) -> list[Assertion]:
        return [a for a in self.assertions if a.draft]


# ---------------------------------------------------------------------------
# Status ↔ lifecycle mapping
# ---------------------------------------------------------------------------

_STATUS_TO_LIFECYCLE = {
    "planned": "exploring",
    "in_progress": "implementing",
    "shipped": "shipped",
    "deprecated": "deprecated",
}

_LIFECYCLE_TO_STATUS = {
    "exploring": "planned",
    "specifying": "planned",
    "implementing": "in_progress",
    "verifying": "in_progress",
    "shipping": "in_progress",
    "shipped": "shipped",
    "deprecated": "deprecated",
}


def _status_to_lifecycle(status: str) -> str:
    return _STATUS_TO_LIFECYCLE.get(status, "exploring")


def lifecycle_to_status(lifecycle: str) -> str:
    return _LIFECYCLE_TO_STATUS.get(lifecycle, "planned")


# ---------------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------------

def load_contract(path: Path) -> Contract:
    """Load a single contract from a YAML file."""
    data = _load_yaml(path)
    return Contract.from_dict(data, source_path=path)


def load_all_contracts(contracts_dir: Path) -> list[Contract]:
    """Load all contracts from a directory."""
    if not contracts_dir.is_dir():
        return []
    contracts = []
    for yaml_file in sorted(contracts_dir.glob("*.yaml")):
        try:
            contracts.append(load_contract(yaml_file))
        except Exception as e:
            print(f"Warning: failed to load {yaml_file.name}: {e}", file=sys.stderr)
    return contracts


def save_contract(contract: Contract, path: Optional[Path] = None) -> Path:
    """Save a contract to YAML. Uses contract.source_path if path not given."""
    target = path or contract.source_path
    if target is None:
        raise ValueError("No path specified and contract has no source_path")
    target.parent.mkdir(parents=True, exist_ok=True)
    _dump_yaml(contract.to_dict(), target)
    return target


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

_ID_PATTERN = re.compile(r"^(F|DEV|E|NFR)-\d{3,}(\.[1-9]\d*)*$")
_AC_PATTERN = re.compile(r"^AC-\d{3,}$")
_MIGRATION_PATTERN = re.compile(r"^M-\d{4}-\d{2}-\d{2}-\d{3}$")
_VALID_LIFECYCLES = {"exploring", "designing", "specifying", "implementing", "verifying", "shipping", "shipped", "deprecated", "ongoing"}
_VALID_PROTECTIONS = {"contract", "advisory", "none"}
_VALID_PROFILES = {"formal", "discovery", "both"}
_VALID_ASSERTION_TYPES = {"structural", "behavioral"}
_VALID_TRIGGERS = {"external", "implementation_discovery", "user_request"}


def validate_contract(contract: Contract) -> list[str]:
    """Validate a contract. Returns list of error strings (empty = valid)."""
    errors: list[str] = []

    # Required fields
    if not contract.id:
        errors.append("Missing required field: id")
    elif not _ID_PATTERN.match(contract.id):
        errors.append(f"Invalid id format: {contract.id} (expected F-XXX[.N], DEV-XXX[.N], E-XXX[.N], or NFR-XXX)")
    else:
        depth = get_depth(contract.id)
        if depth > MAX_DEPTH:
            errors.append(f"Feature ID too deeply nested: {contract.id} (depth={depth}, max={MAX_DEPTH})")

    if not contract.name or len(contract.name) < 3:
        errors.append(f"Name too short or missing: '{contract.name}'")

    if contract.lifecycle not in _VALID_LIFECYCLES:
        errors.append(f"Invalid lifecycle: {contract.lifecycle}")

    if not contract.description or len(contract.description) < 10:
        errors.append(f"Description too short or missing (min 10 chars)")

    # Assertions
    if not contract.assertions:
        errors.append("At least one assertion required")

    seen_ac_ids: set[str] = set()
    for a in contract.assertions:
        if not _AC_PATTERN.match(a.id):
            errors.append(f"Invalid assertion id: {a.id} (expected AC-XXX)")
        if a.id in seen_ac_ids:
            errors.append(f"Duplicate assertion id: {a.id}")
        seen_ac_ids.add(a.id)

        if a.type not in _VALID_ASSERTION_TYPES:
            errors.append(f"{a.id}: invalid type '{a.type}' (expected structural|behavioral)")

        if a.type == "structural" and a.verify is None and not a.draft:
            errors.append(f"{a.id}: structural assertion should have a verify command (or set draft: true)")

    # Protection consistency
    if contract.protection not in _VALID_PROTECTIONS:
        errors.append(f"Invalid protection: {contract.protection}")

    if contract.protection == "contract" and contract.lifecycle != "shipped":
        errors.append(f"protection: contract only valid for shipped contracts (lifecycle={contract.lifecycle})")

    if contract.profile not in _VALID_PROFILES:
        errors.append(f"Invalid profile: {contract.profile}")

    # Migrations
    seen_migration_ids: set[str] = set()
    for m in contract.migrations:
        if not _MIGRATION_PATTERN.match(m.id):
            errors.append(f"Invalid migration id: {m.id} (expected M-YYYY-MM-DD-NNN)")
        if m.id in seen_migration_ids:
            errors.append(f"Duplicate migration id: {m.id}")
        seen_migration_ids.add(m.id)
        if m.trigger not in _VALID_TRIGGERS:
            errors.append(f"Migration {m.id}: invalid trigger '{m.trigger}'")

    return errors


def validate_contract_file(path: Path) -> list[str]:
    """Load and validate a contract file. Returns error list."""
    try:
        contract = load_contract(path)
    except Exception as e:
        return [f"Failed to parse {path.name}: {e}"]
    return validate_contract(contract)


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

def get_pending_user_input(contracts_dir: Path) -> list[Contract]:
    """Return contracts with non-empty user_input fields."""
    return [c for c in load_all_contracts(contracts_dir) if c.has_pending_input]


def get_contracts_by_lifecycle(contracts_dir: Path, lifecycle: str) -> list[Contract]:
    """Return contracts in a specific lifecycle state."""
    return [c for c in load_all_contracts(contracts_dir) if c.lifecycle == lifecycle]


def get_contract_by_id(contracts_dir: Path, feature_id: str) -> Optional[Contract]:
    """Find a contract by its feature/NFR ID."""
    path = contracts_dir / f"{feature_id}.yaml"
    if path.exists():
        return load_contract(path)
    # Fallback: scan all files for matching id field
    for c in load_all_contracts(contracts_dir):
        if c.id == feature_id:
            return c
    return None


# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------

@dataclass
class VerificationResult:
    assertion_id: str
    passed: bool
    output: str = ""
    skipped: bool = False
    reason: str = ""


def verify_assertion(assertion: Assertion, project_root: Path) -> VerificationResult:
    """Run a structural assertion's verify command."""
    if assertion.type != "structural":
        return VerificationResult(
            assertion_id=assertion.id, passed=True, skipped=True,
            reason="behavioral assertion — not machine-verifiable"
        )
    if assertion.draft:
        return VerificationResult(
            assertion_id=assertion.id, passed=True, skipped=True,
            reason="draft assertion — not enforced"
        )
    if not assertion.verify:
        return VerificationResult(
            assertion_id=assertion.id, passed=False, skipped=True,
            reason="no verify command"
        )

    try:
        env = {"PROJECT": str(project_root), "PROJECT_ROOT": str(project_root)}
        import os
        full_env = {**os.environ, **env}
        result = subprocess.run(
            assertion.verify,
            shell=True,
            capture_output=True,
            text=True,
            timeout=30,
            cwd=str(project_root),
            env=full_env,
        )
        return VerificationResult(
            assertion_id=assertion.id,
            passed=(result.returncode == 0),
            output=(result.stdout + result.stderr).strip(),
        )
    except subprocess.TimeoutExpired:
        return VerificationResult(
            assertion_id=assertion.id, passed=False,
            output="Verification timed out (30s)"
        )
    except Exception as e:
        return VerificationResult(
            assertion_id=assertion.id, passed=False,
            output=f"Verification error: {e}"
        )


def verify_contract(contract: Contract, project_root: Path) -> dict[str, Any]:
    """Verify all structural assertions in a contract."""
    results = []
    passed = 0
    failed = 0
    skipped = 0

    for assertion in contract.assertions:
        result = verify_assertion(assertion, project_root)
        results.append({
            "id": result.assertion_id,
            "passed": result.passed,
            "skipped": result.skipped,
            "output": result.output,
            "reason": result.reason,
        })
        if result.skipped:
            skipped += 1
        elif result.passed:
            passed += 1
        else:
            failed += 1

    return {
        "contract_id": contract.id,
        "contract_name": contract.name,
        "lifecycle": contract.lifecycle,
        "passed": passed,
        "failed": failed,
        "skipped": skipped,
        "total": len(contract.assertions),
        "results": results,
    }


# ---------------------------------------------------------------------------
# Coverage analysis
# ---------------------------------------------------------------------------

def coverage_report(contracts_dir: Path) -> dict[str, Any]:
    """Analyze test coverage across all contracts."""
    contracts = load_all_contracts(contracts_dir)
    total_assertions = 0
    with_tests = 0
    with_verify = 0
    gaps: list[dict[str, str]] = []

    for c in contracts:
        for a in c.assertions:
            if a.draft:
                continue
            total_assertions += 1
            has_tests = bool(a.tests)
            has_verify = bool(a.verify)
            if has_tests:
                with_tests += 1
            if has_verify:
                with_verify += 1
            if not has_tests and not has_verify:
                gaps.append({
                    "contract": c.id,
                    "assertion": a.id,
                    "text": a.text,
                    "type": a.type,
                })

    return {
        "total_assertions": total_assertions,
        "with_tests": with_tests,
        "with_verify": with_verify,
        "gaps": gaps,
        "coverage_pct": round(with_tests / total_assertions * 100, 1) if total_assertions else 0,
    }


# ---------------------------------------------------------------------------
# Hierarchy queries
# ---------------------------------------------------------------------------

def get_effective_assertions(
    feature_id: str, contracts_dir: Path, _seen: set[str] | None = None
) -> dict[str, list[Assertion]]:
    """Get own + all descendants' assertions, grouped by contract ID.

    Returns {feature_id: [assertions], child_id: [assertions], ...}.
    "Effective ACs" = own + children's, computed at query time.
    Cycle-safe: tracks visited IDs to prevent infinite recursion.
    """
    if _seen is None:
        _seen = set()

    if feature_id in _seen:
        return {}
    _seen.add(feature_id)

    result: dict[str, list[Assertion]] = {}
    contract = get_contract_by_id(contracts_dir, feature_id)
    if contract is None:
        return result

    result[contract.id] = list(contract.assertions)

    for child_id in contract.children:
        child_result = get_effective_assertions(child_id, contracts_dir, _seen)
        result.update(child_result)

    return result


def get_contracts_by_component(
    contracts_dir: Path, component: str
) -> list[Contract]:
    """Return contracts matching a specific component."""
    return [
        c for c in load_all_contracts(contracts_dir)
        if c.component == component
    ]


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def _cli():
    """Simple CLI for contract operations."""
    import sys
    args = sys.argv[1:]
    if not args:
        print("Usage: python3 contracts.py <command> [args]")
        print("Commands: validate <file>, validate-all <dir>, verify <file> <project-root>")
        print("          coverage <dir>, pending <dir>, list <dir>")
        sys.exit(1)

    cmd = args[0]

    if cmd == "validate" and len(args) >= 2:
        errors = validate_contract_file(Path(args[1]))
        if errors:
            for e in errors:
                print(f"  ERROR: {e}")
            sys.exit(1)
        else:
            print(f"  OK: {args[1]}")

    elif cmd == "validate-all" and len(args) >= 2:
        contracts_dir = Path(args[1])
        all_ok = True
        count = 0
        for yaml_file in sorted(contracts_dir.glob("*.yaml")):
            count += 1
            errors = validate_contract_file(yaml_file)
            if errors:
                all_ok = False
                print(f"FAIL: {yaml_file.name}")
                for e in errors:
                    print(f"  {e}")
            else:
                print(f"  OK: {yaml_file.name}")
        print(f"\n{count} contract(s) checked")
        sys.exit(0 if all_ok else 1)

    elif cmd == "verify" and len(args) >= 3:
        contract = load_contract(Path(args[1]))
        result = verify_contract(contract, Path(args[2]))
        print(json.dumps(result, indent=2))
        sys.exit(0 if result["failed"] == 0 else 1)

    elif cmd == "coverage" and len(args) >= 2:
        report = coverage_report(Path(args[1]))
        print(json.dumps(report, indent=2))

    elif cmd == "pending" and len(args) >= 2:
        pending = get_pending_user_input(Path(args[1]))
        if not pending:
            print("No pending user input")
        else:
            for c in pending:
                print(f"  {c.id}: {c.name}")
                print(f"    Input: {c.user_input.strip()[:100]}")

    elif cmd == "list" and len(args) >= 2:
        contracts = load_all_contracts(Path(args[1]))
        if not contracts:
            print("No contracts found")
        else:
            for c in contracts:
                prot = f" [{c.protection}]" if c.protection != "none" else ""
                print(f"  {c.id}  {c.lifecycle:<14} {c.name}{prot}")
            print(f"\n{len(contracts)} contract(s)")

    else:
        print(f"Unknown command or missing args: {cmd}")
        sys.exit(1)


if __name__ == "__main__":
    _cli()
