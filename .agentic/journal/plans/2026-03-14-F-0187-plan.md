# F-0187: Multi-Repo Umbrella — Implementation Plan

**Status**: APPROVED (revision 2 — post-dialectical review, 2 rounds)
**Feature**: F-0187
**Created**: 2026-03-14

## Context

The framework has a shipped component registry (F-0179) that supports monorepo projects with a `## Components` table in STACK.md. F-0187 extends this to multi-repo projects via the umbrella pattern described in ADR-001 §3: an orchestrator repo coordinates components living in separate git repositories.

**Why now**: F-0187 is the current backlog item. Dependencies F-0179 (Component Registry) and F-0186 (Autonomous Scheduler) are both shipped.

**Intended outcome**: Projects with components in separate repos can use the framework's decomposition, scheduling, and contract checking across repo boundaries — while single-repo projects remain unaffected.

---

## Revision Notes (from dialectical review round 1)

Changes from v1:
1. **Extract shared `_parse_markdown_table()` helper** — both component and contract parsers use it (Critic M2)
2. **Remove standalone `check_repo_availability()`** — populate `missing_repos` during `resolve_umbrella()` instead (Critic L1)
3. **Add name collision detection** in `parse_components_table` — raise on duplicate component names (Critic L5)
4. **Clarify scheduler integration** — `resolve_umbrella` adds missing-repo error reporting + clone instructions, not different path resolution logic. Existing `project_root / comp.path` already resolves `../` correctly. The umbrella layer adds: availability checking, clone instructions for missing repos, and `.git` directory validation for `repo`-tagged components (Critic H2)
5. **Add column-reorder test** for header-aware parsing (Critic M1)
6. **`validate()` for cross-repo** — when `repo` is set, resolve path as absolute (via umbrella) rather than relative to `project_root` (Critic H5)

---

## Approach

### AC-001 + AC-005: Repo Column on Component Registry

**Extend `Component` dataclass** in `components.py` with an optional `repo` field:

```python
@dataclass
class Component:
    name: str
    path: str
    type: str
    test_command: str
    repo: str | None = None  # Git URL for cross-repo components (optional)
```

**Extract `_parse_markdown_table()` helper**: Shared logic for finding a `## Section`, skipping header/separator, parsing cells. Used by both `parse_components_table` and `parse_contracts_table` (in umbrella.py). This eliminates the duplicate parsing code flagged in review.

```python
def _parse_markdown_table(content: str, section_name: str) -> tuple[list[str], list[list[str]]]:
    """Parse a markdown table from a named ## section.

    Returns (column_names, rows) where each row is a list of cell strings.
    Returns ([], []) if section not found or table is empty.
    """
```

**Switch `parse_components_table` to header-aware parsing**: Use `_parse_markdown_table` to get column names and rows. Map columns by name (case-insensitive, `test_command`/`test command` both accepted). This handles 4-column (existing) and 5-column (with Repo) tables transparently. Column order does not matter.

**Name collision detection**: If two rows have the same `name`, `parse_components_table` logs a warning and keeps the last one. This prevents silent data loss from duplicate names across repos.

**Add helper methods on `ComponentRegistry`**:
- `is_multi_repo() -> bool` — any component has a non-None `repo`
- `get_external_components() -> list[Component]` — components with `repo` set
- `get_local_components() -> list[Component]` — components without `repo`

### AC-002: Umbrella Orchestration Pattern

**New module `umbrella.py`** with:

```python
@dataclass
class UmbrellaProject:
    project_root: Path
    registry: ComponentRegistry
    component_roots: dict[str, Path]   # component_name -> resolved abs path
    missing_repos: list[str]           # components whose paths don't exist (populated during resolve)

def resolve_umbrella(project_root: Path) -> UmbrellaProject | None
def get_component_root(umbrella: UmbrellaProject, name: str) -> Path | None
```

**Key design clarification (from review)**: `resolve_umbrella` does NOT change how paths resolve — `Path(project_root) / "../api-service"` already works via standard path resolution. The value `resolve_umbrella` adds over raw path joining:

1. **Availability checking**: Detects which component repos are missing and populates `missing_repos` with clone instructions (repo URL + expected path).
2. **Git repo validation**: When `comp.repo` is set, warns if the resolved path exists but has no `.git` directory (likely not a cloned repo).
3. **Centralized resolution**: Returns `component_roots` dict so callers don't repeat path resolution logic.

`resolve_umbrella` returns `None` for single-repo projects (no components have `repo` set). The `missing_repos` field is populated during resolution — no separate `check_repo_availability()` function needed (removed per review).

**No auto-cloning**: When a component repo path doesn't exist, the framework reports the issue with clone instructions. Auto-cloning would be a destructive side effect.

**Scheduler integration**: Update `scheduler.py:_run_feature` — when a component has `repo` set, use `resolve_umbrella()` to: (a) get the resolved `work_root`, and (b) check availability. If the repo is missing, fail the feature with a descriptive error containing clone instructions rather than a confusing path-not-found. This is ~8 lines: resolve umbrella, check missing, get root or fail.

### AC-003: Cross-Repo Contract Checking

**Metadata-level checking, not content-level**: The framework validates the structural integrity of the declared contract topology — file existence and producer/consumer references. Deep schema validation (OpenAPI compatibility, protobuf breaking changes) belongs in CI pipelines and user-defined test commands, not the framework's metadata layer.

**Add optional `## Contracts` table to STACK.md**:

```markdown
## Contracts
| name | path | format | producer | consumers |
|------|------|--------|----------|-----------|
| user-api | contracts/user-api.yaml | openapi | api | web, mobile |
```

**Data model and functions in `umbrella.py`** (uses shared `_parse_markdown_table` from components.py):

```python
@dataclass
class Contract:
    name: str
    path: str
    format: str            # json-schema | openapi | protobuf | custom
    producer: str | None   # component name
    consumers: list[str]   # component names

@dataclass
class ContractResult:
    contract_name: str
    exists: bool
    warnings: list[str]    # e.g., "producer 'billing' not in component registry"

def parse_contracts_table(content: str) -> list[Contract]
def validate_contracts(project_root: Path, registry: ComponentRegistry) -> list[ContractResult]
```

Validation checks: (1) contract files exist at declared paths, (2) producer/consumer component names exist in the registry. `validate_contracts` takes a `registry` parameter explicitly rather than loading it internally — keeps the dependency direction clean.

### AC-004: User Input Collection

**Reuse kickoff pattern**: Python handles validation/structuring; LLM interaction stays at the shell/skill layer. This matches the framework's established boundary (same as `ag kickoff`).

**Add to `umbrella.py`**:

```python
@dataclass
class UmbrellaInputs:
    vision: str
    style_refs: list[Path]      # Local file paths only (URL support deferred)
    research_refs: list[Path]   # Local file paths only
    contract_dir: Path | None

def collect_inputs(
    project_root: Path,
    vision: str,
    style_refs: list[str] | None = None,
    research_refs: list[str] | None = None,
    contract_dir: str | None = None,
) -> UmbrellaInputs
```

Validates referenced files/directories exist, resolves paths to absolute, returns structured object for the decomposition pipeline. Raises `FileNotFoundError` with a clear message for missing references.

---

## Files to Modify

| File | Changes |
|------|---------|
| `.agentic/lib/auto/components.py` | Add `repo` field, extract `_parse_markdown_table()`, header-aware parsing, name collision detection, registry helpers |
| `tests/test_components.py` | Tests for 5-col table, backward compat with 4-col, column reorder, `is_multi_repo()`, name collision warning |
| `.agentic/lib/auto/umbrella.py` | **NEW**: UmbrellaProject, contract checking, input collection |
| `tests/test_umbrella.py` | **NEW**: Full test coverage for umbrella module |
| `.agentic/lib/auto/scheduler.py` | Update `_run_feature` for cross-repo work_root resolution with error reporting |
| `.agentic/lib/init/STACK.template.md` | Add multi-repo component example, `## Contracts` section |

**Total**: 4 modified + 2 new = 6 files (within 5-10 file budget)

---

## Execution Order

### Phase 1: Foundation (AC-001, AC-005) — blocks everything
- `components.py`: Add `repo` field, extract `_parse_markdown_table()`, header-aware parsing, name collision detection, registry helpers (`is_multi_repo`, `get_external_components`, `get_local_components`)
- `tests/test_components.py`: Backward compatibility (4-col tables), 5-col tables, column reorder, name collision, `is_multi_repo()` helpers

### Phase 2: Umbrella Core (AC-002)
- `umbrella.py`: `UmbrellaProject`, `resolve_umbrella` (with missing_repos population + .git validation), `get_component_root`
- `tests/test_umbrella.py`: Multi-repo resolution, missing repo detection, .git validation, single-repo returns None

### Phase 3: Contract Checking (AC-003) [P]
- `umbrella.py`: `Contract`, `parse_contracts_table` (using shared `_parse_markdown_table`), `validate_contracts`
- `tests/test_umbrella.py`: Contract parsing, validation (file existence, producer/consumer reference checks)

### Phase 4: Input Collection + Integration (AC-004) [P]
- `umbrella.py`: `UmbrellaInputs`, `collect_inputs`
- `scheduler.py`: Update `_run_feature` — use `resolve_umbrella` for error reporting + clone instructions when repo missing
- `STACK.template.md`: Multi-repo component example (with Repo column), `## Contracts` section
- `tests/test_umbrella.py`: Input collection tests, scheduler integration test

`[P]` = Phases 3 and 4 are parallelizable (independent concerns).

CHECKPOINT after Phase 4: Run `pytest tests/test_components.py tests/test_umbrella.py` + `bash tests/validate_framework.sh`

---

## Verification

1. `pytest tests/test_components.py` — backward compat (4-col tables still work, auto_detect still works)
2. `pytest tests/test_umbrella.py` — all new multi-repo, contract, input collection tests
3. `bash tests/validate_framework.sh` — framework validation
4. Manual check: existing STACK.md in this repo (no Components section) → empty registry, `resolve_umbrella` returns None
