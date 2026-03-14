"""
umbrella.py -- Multi-repo umbrella orchestration for the Agentic Framework.

Implements F-0187 (ADR-001 §3): resolves cross-repo component paths,
validates contract topology, and collects structured inputs for
decomposition pipelines.

Usage:
    from auto.umbrella import resolve_umbrella
    umbrella = resolve_umbrella(Path("/orchestrator-repo"))
    if umbrella:
        root = get_component_root(umbrella, "api")
"""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

from auto.components import (
    ComponentRegistry,
    load_registry,
    parse_markdown_table,
)


# ---------------------------------------------------------------------------
# Umbrella resolution (AC-002)
# ---------------------------------------------------------------------------

@dataclass
class UmbrellaProject:
    """Resolved multi-repo umbrella project."""
    project_root: Path
    registry: ComponentRegistry
    component_roots: dict[str, Path] = field(default_factory=dict)
    missing_repos: list[str] = field(default_factory=list)


def resolve_umbrella(project_root: Path) -> UmbrellaProject | None:
    """Resolve an umbrella project from a project root.

    Returns ``None`` for single-repo projects (no components have ``repo``
    set).  For multi-repo projects, resolves each component's path relative
    to the project root, checks availability, and validates that
    repo-tagged paths contain a ``.git`` directory.
    """
    registry = load_registry(project_root)
    if not registry.is_multi_repo():
        return None

    root = project_root.resolve()
    umbrella = UmbrellaProject(project_root=root, registry=registry)

    for comp in registry.list_all():
        resolved = (root / comp.path).resolve()

        if not resolved.is_dir():
            clone_hint = f"git clone {comp.repo} {comp.path}" if comp.repo else ""
            umbrella.missing_repos.append(
                f"Component '{comp.name}': path '{comp.path}' does not exist. "
                + (f"Clone with: {clone_hint}" if clone_hint else "Create the directory.")
            )
            continue

        if comp.repo and not (resolved / ".git").is_dir():
            umbrella.missing_repos.append(
                f"Component '{comp.name}': path '{comp.path}' exists but "
                f"is not a git repository (no .git directory). "
                f"Expected clone of {comp.repo}"
            )
            continue

        umbrella.component_roots[comp.name] = resolved

    return umbrella


def get_component_root(
    umbrella: UmbrellaProject, name: str,
) -> Path | None:
    """Get the resolved absolute path for a component in the umbrella."""
    return umbrella.component_roots.get(name)


# ---------------------------------------------------------------------------
# Contract checking (AC-003)
# ---------------------------------------------------------------------------

@dataclass
class Contract:
    """A declared interface contract between components."""
    name: str
    path: str          # Relative path to contract file
    format: str        # json-schema | openapi | protobuf | custom
    producer: str | None = None   # Component name that produces the contract
    consumers: list[str] = field(default_factory=list)  # Component names that consume


@dataclass
class ContractResult:
    """Result of validating a single contract."""
    contract_name: str
    exists: bool
    warnings: list[str] = field(default_factory=list)


_CONTRACT_COLUMN_MAP = {
    "name": "name",
    "path": "path",
    "format": "format",
    "producer": "producer",
    "consumers": "consumers",
}


def parse_contracts_table(content: str) -> list[Contract]:
    """Parse a ``## Contracts`` markdown table from STACK.md content."""
    column_names, rows = parse_markdown_table(content, "Contracts")
    if not column_names or not rows:
        return []

    col_map: dict[int, str] = {}
    for i, col in enumerate(column_names):
        field_name = _CONTRACT_COLUMN_MAP.get(col)
        if field_name:
            col_map[i] = field_name

    field_set = set(col_map.values())
    if "name" not in field_set or "path" not in field_set:
        return []

    contracts: list[Contract] = []
    for row in rows:
        fields: dict[str, str] = {}
        for i, cell in enumerate(row):
            if i in col_map:
                fields[col_map[i]] = cell.strip()

        name = fields.get("name", "")
        path = fields.get("path", "")
        if not name or not path:
            continue

        consumers_raw = fields.get("consumers", "")
        consumers = [
            c.strip() for c in consumers_raw.split(",") if c.strip()
        ]
        producer = fields.get("producer") or None

        contracts.append(Contract(
            name=name,
            path=path,
            format=fields.get("format", "custom"),
            producer=producer,
            consumers=consumers,
        ))

    return contracts


def validate_contracts(
    project_root: Path,
    registry: ComponentRegistry,
) -> list[ContractResult]:
    """Validate contracts declared in STACK.md.

    Checks:
    1. Contract files exist at declared paths.
    2. Producer/consumer names exist in the component registry.
    """
    stack_file = project_root / "STACK.md"
    if not stack_file.exists():
        stack_file = project_root / ".agentic" / "STACK.md"
    if not stack_file.exists():
        return []

    content = stack_file.read_text(errors="ignore")
    contracts = parse_contracts_table(content)
    if not contracts:
        return []

    component_names = {c.name for c in registry.list_all()}
    results: list[ContractResult] = []

    for contract in contracts:
        contract_path = (project_root / contract.path).resolve()
        exists = contract_path.exists()
        warnings: list[str] = []

        if not exists:
            warnings.append(
                f"Contract file '{contract.path}' does not exist"
            )

        if contract.producer and contract.producer not in component_names:
            warnings.append(
                f"Producer '{contract.producer}' is not a registered component"
            )

        for consumer in contract.consumers:
            if consumer not in component_names:
                warnings.append(
                    f"Consumer '{consumer}' is not a registered component"
                )

        results.append(ContractResult(
            contract_name=contract.name,
            exists=exists,
            warnings=warnings,
        ))

    return results


# ---------------------------------------------------------------------------
# Input collection (AC-004)
# ---------------------------------------------------------------------------

@dataclass
class UmbrellaInputs:
    """Structured inputs for umbrella decomposition."""
    vision: str
    style_refs: list[Path] = field(default_factory=list)
    research_refs: list[Path] = field(default_factory=list)
    contract_dir: Path | None = None


def collect_inputs(
    project_root: Path,
    vision: str,
    style_refs: list[str] | None = None,
    research_refs: list[str] | None = None,
    contract_dir: str | None = None,
) -> UmbrellaInputs:
    """Validate and resolve input references for umbrella decomposition.

    Raises ``FileNotFoundError`` with a descriptive message if any
    referenced file or directory does not exist.
    """
    root = project_root.resolve()

    resolved_style: list[Path] = []
    for ref in style_refs or []:
        p = (root / ref).resolve()
        if not p.exists():
            raise FileNotFoundError(
                f"Style reference not found: {ref} (resolved to {p})"
            )
        resolved_style.append(p)

    resolved_research: list[Path] = []
    for ref in research_refs or []:
        p = (root / ref).resolve()
        if not p.exists():
            raise FileNotFoundError(
                f"Research reference not found: {ref} (resolved to {p})"
            )
        resolved_research.append(p)

    resolved_contract_dir: Path | None = None
    if contract_dir:
        p = (root / contract_dir).resolve()
        if not p.is_dir():
            raise FileNotFoundError(
                f"Contract directory not found: {contract_dir} (resolved to {p})"
            )
        resolved_contract_dir = p

    return UmbrellaInputs(
        vision=vision,
        style_refs=resolved_style,
        research_refs=resolved_research,
        contract_dir=resolved_contract_dir,
    )
