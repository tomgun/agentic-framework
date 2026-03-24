# Plan: Hierarchical Feature System + Clean Renumber

**Status**: APPROVED
**Feature**: F-0184 (Feature Hierarchy & Decomposition)
**Date**: 2026-03-24
**Branch**: TBD (next PR after current branch ships)
**Review**: Dialectical review completed (Critic: REVISE, Advocate: APPROVE). Revision R1 addresses all Critic findings below.

## Context

The framework's feature tracking has grown to 30+ consolidated features with flat, chronologically-assigned IDs (F-0001, F-0004, F-0081...). Large features accumulate 6-12+ ACs spanning different concerns — these AC clusters are really unnamed subfeatures. The current system has basic parent-child support (DEV-0001 only) but no subfeature decomposition for user-facing features.

**Goal**: Introduce a hierarchical feature model where features compose into subfeatures with dotted IDs (F-003.1, F-003.1.1), clean-renumber all existing features, and support component metadata for multi-component projects.

## Design Decisions (Confirmed)

1. **Universal IDs with dotted children**: F-XXX (parent), F-XXX.1 (child), F-XXX.1.1 (grandchild). Children start at `.1` (never `.0`).
2. **Component as metadata, not in ID**: `component:` field in contract YAML. Distinct from `category` — category = framework classification (core-workflow, quality), component = project architecture (backend, frontend, infra). Different axes. Reconcile with existing `tags` usage in `epic.py _build_child_contract()` which already writes `tags: [component]` — `component` field replaces this pattern.
3. **4 levels max**: Component grouping (organizational) → Feature → Subfeature → Sub-subfeature. Depth computed at runtime from dotted ID (`get_depth()`), not stored.
4. **Clean renumber**: Existing features get new sequential 3-digit IDs (F-001, F-002...)
5. **Backward compatible schema**: New fields optional with defaults; both 3-digit and 4-digit IDs accepted during transition. `format_feature_id()` default width stays 4 during transition, switches to 3 after renumber completes.
6. **Parent ACs are independent of children**: Parent defines business outcome; children define implementation. "Effective ACs" = own + children's (computed at query time, never stored).
7. **Status rollup**: Existing `derive_epic_status()` logic — parent status derived from children automatically.
8. **`consolidated_from` dead IDs stay as-is**: Historical tombstones (F-0042, F-0078, etc.) are never renamed. Only live IDs change. Schema pattern for `consolidated_from` items stays `{4,}` to match historical format.
9. **NFR IDs unchanged**: NFR-0001, NFR-0003, NFR-0004 keep their current IDs. They're in a separate namespace and already short. `nfr_refs` patterns unchanged.
10. **Dotted-ID filenames**: `F-003.1.yaml` is the canonical contract filename. All `glob("*.yaml")` and path construction audited to handle dots correctly. Never use `basename -s .yaml` — always use `${file%.yaml}` or Python `stem` equivalent.

## Dialectical Review Findings

### R1 Revision (from Critic review 2026-03-24)

**Addressed:**
- **F-0007 missing from mapping** → Added to Quality group (shifts subsequent IDs by 1)
- **NFR contracts** → Explicitly excluded from renumber (Decision #9)
- **Dotted-ID filename convention** → Documented (Decision #10)
- **Regex `.0` children** → Updated to `(\.[1-9][0-9]*)*` in all patterns
- **NFR missing from `_ID_PATTERN`** → Kept in pattern: `(F|DEV|E|NFR)-\d{3,}(\.[1-9][0-9]*)*`
- **`get_next_feature_id` needs update** → Added to Phase 1b
- **`format_feature_id` default width** → Stays 4 during transition (Decision #5)
- **Blast radius inventory** → Expanded (see Phase 2 section)
- **Renumber algorithm precision** → Added (word-boundary matching, ordering, exclusion logic)
- **Schema patterns** → Clarified: `consolidated_from` stays `{4,}`, `id`/`parent`/`children` get `{3,}` with dots
- **Phase 1 too large** → Split into PR 1a (schema+core) and PR 1b (epic+commands)
- **Machine-readable mapping** → Added JSON mapping file to Phase 2
- **Batch migration** → Individual `M-` entry per contract (fits existing schema)
- **Component vs tags reconciliation** → Documented (Decision #2)
- **Journal/plan files** → Added to "What NOT to rename" (historical)

### R0 Findings (original review)
- ~~`subfeature` annotation on ACs~~ → **Dropped**. Go straight to decomposition — simpler, no schema pollution.
- ~~`depth` field in contract~~ → **Dropped**. Compute from dotted ID at runtime via `get_depth()`.
- **`component` vs `category` overlap** → Clarified: different axes (see decision #2 above).
- **Protected contract migrations** → Individual M- entry per contract (28 entries total).
- **`consolidated_from` dead IDs** → Explicitly excluded from rename. The mapping script distinguishes live IDs (in `id:`, `parent:`, `children:` fields) from dead IDs (in `consolidated_from:`).
- **Dotted IDs break shell parsing** → Phase 1 includes a thorough shell audit (see section below).
- **Transition compatibility** → ID regex accepts `\d{3,}` (both 3-digit and 4-digit) throughout the transition. `format_feature_id()` default stays 4 during transition.
- **Renumber scope** → Acknowledged as multi-session work. Phase 2 split into sub-phases with a scripted rename tool.
- **Planned features missing from mapping** → Added (F-0211, F-0212, F-0220, F-0228, F-0230, F-0231, F-0232).

### Preserved from Advocate
- System is ~70% built (parent/children/derive_epic_status all exist)
- Component-as-metadata is correct (cross-cutting features prove it)
- Post-consolidation is the right moment to renumber
- Dotted notation is information-dense and sort-stable
- Phase sequencing is right
- ID centralization (F-0193) makes renumber safe — most shell scripts use ids.sh already

---

## Phase 1a: Schema + Core Code (PR 1)

### Contract Schema (`contract.schema.json`)

Add to **contract** root:
```yaml
"component": {
  "type": ["string", "null"],
  "default": null,
  "description": "Project component (backend, frontend, infra). Distinct from category."
}
```

Update **ID patterns** to support dotted notation + 3-digit minimum:
- `id` pattern: `^(F|DEV|E|NFR)-[0-9]{3,}(\.[1-9][0-9]*)*$`
- `parent` pattern: `^(F|DEV|E)-[0-9]{3,}(\.[1-9][0-9]*)*$`
- `children` items pattern: `^(F|DEV)-[0-9]{3,}(\.[1-9][0-9]*)*$`
- `consolidated_from` items pattern: **unchanged** (`^F-[0-9]{4,}$`) — dead IDs keep historical format
- `nfr_refs` items pattern: **unchanged** (`^NFR-[0-9]{4,}$`)

No `subfeature` annotation. No `depth` field.

### IDs Module (`ids.py`, `ids.sh`)

```python
# ids.py — new/changed functions
FEATURE_ID_RE = re.compile(r"(F|DEV|E|NFR)-\d{3,}(\.[1-9]\d*)*")
FEATURE_ID_STRICT_RE = re.compile(r"^(F|DEV|E|NFR)-\d{3,}(\.[1-9]\d*)*$")

def get_parent_id(feature_id: str) -> str | None:
    """F-003.1.2 → F-003.1, F-003.1 → F-003, F-003 → None"""

def get_depth(feature_id: str) -> int:
    """F-003 → 0, F-003.1 → 1, F-003.1.2 → 2"""

def get_root_id(feature_id: str) -> str:
    """F-003.1.2 → F-003"""

def get_next_child_id(parent_id: str, existing_children: list[str]) -> str:
    """F-003 with children [F-003.1, F-003.2] → F-003.3"""

def get_next_feature_id(features_content: str, prefix: str = "F") -> str:
    """Updated to handle dotted IDs — only counts root-level IDs for next allocation.
    F-003, F-003.1, F-004 → next is F-005 (ignores children)."""

def format_feature_id(num: int, prefix: str = "F", width: int = 4) -> str:
    """(3, "F", 4) → F-0003. Default width stays 4 during transition.
    After renumber completes, callers can pass width=3."""
```

### Shell Audit — Dotted ID Compatibility

The critic identified 52+ files with shell patterns that assume no dots in IDs. Must audit and fix:

| Pattern | Problem | Fix |
|---------|---------|-----|
| `cut -d'-' -f2` | Extracts "003.1" as one token | OK — this actually works (dot is after the dash split) |
| `basename -s .yaml` | Strips `.yaml` but `.1.yaml` strips wrong | Use `${file%.yaml}` instead of basename |
| `[[ $id =~ ^F-[0-9]{4,}$ ]]` | Rejects dotted IDs | Import from ids.sh `$FEATURE_ID_ERE` |
| `FEATURE_HEADER_RE` in FEATURES.md parsing | `## F-XXXX:` won't match `## F-003.1:` | Update regex to allow dots |
| `grep -E "F-[0-9]{4}"` in various scripts | Won't match 3-digit or dotted | Import from ids.sh centralized patterns |

**Action**: Grep for all hardcoded ID patterns in `.agentic/lib/` and `tests/`, replace with imports from `ids.sh`/`ids.py`. This was supposed to be done in F-0193 but some stragglers remain.

### Contracts Module (`contracts.py`)

- Add `component: str | None` to `Contract` dataclass
- Add `get_effective_assertions(feature_id)` → own + all descendants' ACs, grouped by child
- Depth validation at runtime: `get_depth(contract.id) <= 3`
- `_ID_PATTERN` updated: `r"^(F|DEV|E|NFR)-\d{3,}(\.[1-9]\d*)*$"` (adds NFR, dotted support, 3-digit minimum)

### Critical files to modify (PR 1)

- `.agentic/lib/schemas/contract.schema.json` — component field, ID pattern updates (except consolidated_from)
- `.agentic/lib/ids.py` + `.agentic/lib/ids.sh` — new regex, helper functions, get_next_feature_id update
- `.agentic/lib/contracts.py` — component field, effective ACs, depth validation, _ID_PATTERN fix
- `tests/test_ids.py` — dotted pattern tests, depth tests, parent/child ID tests
- `tests/validate_framework.sh` — update ID regex patterns (import from ids.sh)
- Shell files with hardcoded ID patterns → import from ids.sh

---

## Phase 1b: Epic + Commands (PR 2)

### Epic Module (`epic.py`)

- Add depth guard to `decompose()`: `get_depth(parent_id) < 3`
- `get_next_child_id()` used for auto-assigning dotted IDs to new children
- `extract_subfeature(parent_id, ac_ids)`: move selected ACs from parent to a new child contract
- Replace `tags: [component]` pattern in `_build_child_contract()` with `component:` field

### Commands

| Command | Change |
|---------|--------|
| `ag contract check F-XXX --recursive` | Check own + children ACs |
| `ag contract tree F-XXX` | Scoped tree view for one feature |
| `ag decompose F-XXX --extract AC-001,AC-002,AC-003` | Extract selected ACs as named child |
| `ag list --component backend` | Filter features by component |
| `ag contract create --parent F-XXX` | Create child with auto-assigned dotted ID |

### Critical files to modify (PR 2)

- `.agentic/lib/auto/epic.py` — extract_subfeature, depth guard, dotted ID allocation, component field
- `.agentic/lib/tools/commands/contract.sh` — --recursive, --component flags
- `.agentic/lib/tools/query_features.py` — component filtering, dotted ID support
- `tests/test_epic.py` — dotted ID decomposition tests

---

## Phase 2: Clean Renumber (multi-session, scripted)

### Blast Radius Inventory

The renumber touches significantly more than a handful of files:
- **`.agentic/lib/`**: ~125 files, ~580 occurrences (scripts, Python, schemas)
- **`.agentic/spec/`**: ~35 contract YAML files + FEATURES.md + NFR.md + ISSUES.md
- **`tests/`**: ~111 files, ~2,500 occurrences (test fixtures, definitions, assertions)
- **`docs/`**: ~50 files with live ID cross-references (exclude archive/)
- **`.agentic/journal/`**: historical — see "What NOT to rename"
- **State files**: BACKLOG.json (~16 refs), STATUS.md (~8 refs), HUMAN_NEEDED.md
- **`.claude/`**: settings.local.json (~7 refs), skills with ID references
- **`tests/llm/test_definitions.json`**: ~85 occurrences
- **`@feature` annotations**: ~28 files across `.agentic/lib/`
- **Root files**: CLAUDE.md, CHANGELOG.md, README.md

Total estimate: ~500+ files, ~5,000+ occurrences.

### Renumber Algorithm

The script (`tools/renumber.py`) uses this precise algorithm:

1. **Load mapping** from JSON file (`tools/renumber_mapping.json`)
2. **Sort replacements longest-first** (F-0302 before F-0003) to prevent substring collisions
3. **Word-boundary matching**: Use `\bF-0004\b` (or `(?<![0-9.])F-0004(?![0-9.])`) so F-0004 in "F-00042" is not matched
4. **Structured YAML fields**: For contract files, parse YAML and update `id:`, `parent:`, `children:` fields directly (not regex). Leave `consolidated_from:` untouched.
5. **Free-text replacement**: For `.md`, `.sh`, `.py`, `.json` files, use word-boundary regex
6. **Exclusion rules**:
   - Skip `consolidated_from:` arrays in YAML (dead IDs)
   - Skip `docs/archive/` entirely (historical snapshots)
   - Skip `.agentic/journal/` entries (historical — see below)
   - Skip git commit messages (can't change)
   - Skip `nfr_refs:` arrays (NFR IDs unchanged)
7. **Contract file rename**: `git mv F-0004.yaml F-003.yaml` (preserves history better than delete+create)
8. **Post-check**: Run `validate_framework.sh` + `python3 -m pytest tests/ -x`
9. **Output**: Machine-readable `tools/renumber_mapping.json` + human-readable `docs/archive/ID_MIGRATION.md`

### Renumber Mapping (to be finalized)

Assign sequential within category groups. **Machine-readable mapping** stored as `tools/renumber_mapping.json`:

**Core Workflow** (F-001 — F-006):
| Old | New | Name |
|-----|-----|------|
| F-0001 | F-001 | Project Init & Profiles |
| F-0003 | F-002 | Spec-Driven Development |
| F-0004 | F-003 | Feature Tracking & Lifecycle |
| F-0120 | F-004 | Plan & Design Review |
| F-0184 | F-005 | Feature Hierarchy & Decomposition |
| F-0190 | F-006 | Backlog & Work Queue |

**Quality** (F-007 — F-014):
| Old | New | Name |
|-----|-----|------|
| F-0007 | F-007 | Development Constraints & Principles |
| F-0011 | F-008 | Code Quality Standards |
| F-0016 | F-009 | Pre-Commit Quality Gates |
| F-0079 | F-010 | Issue & Feedback Tracking |
| F-0101 | F-011 | Architecture Decision Records |
| F-0118 | F-012 | Documentation Drift & Lifecycle |
| F-0169 | F-013 | Non-Functional Requirements |
| F-0180 | F-014 | Review Checkpoint Framework |

**Session & Recovery** (F-015 — F-016):
| Old | New | Name |
|-----|-----|------|
| F-0021 | F-015 | Session Management |
| F-0051 | F-016 | Crash Recovery & Work Tracking |

**Multi-Agent** (F-017 — F-018):
| Old | New | Name |
|-----|-----|------|
| F-0031 | F-017 | Multi-Agent Coordination |
| F-0185 | F-018 | Coordination Server |

**Tooling & Architecture** (F-019 — F-024):
| Old | New | Name |
|-----|-----|------|
| F-0041 | F-019 | Token & Resource Efficiency |
| F-0056 | F-020 | Framework Upgrade & Versioning |
| F-0095 | F-021 | Cross-Platform Compatibility |
| F-0157 | F-022 | Framework Architecture & Paths |
| F-0245 | F-023 | Hook-Based Enforcement |
| F-0096 | F-024 | Git Workflow & PR Management |

**Agent & Developer Experience** (F-025 — F-029):
| Old | New | Name |
|-----|-----|------|
| F-0081 | F-025 | Agent System & Instructions |
| F-0061 | F-026 | Developer Documentation |
| F-0077 | F-027 | Emergency Quick Reference |
| F-0151 | F-028 | User Extensions & Customization |
| F-0181 | F-029 | Autonomous Formal Profile |

**Autonomous & Spec** (F-030 — F-032):
| Old | New | Name |
|-----|-----|------|
| F-0160 | F-030 | Autonomous Execution Engine |
| F-0302 | F-031 | Spec System Overhaul — YAML Contracts |
| F-0303 | F-032 | Plan-Derived Work Items |

**Planned** (F-033 — F-039):
| Old | New | Name |
|-----|-----|------|
| F-0211 | F-033 | Project-Specific Customization Layer |
| F-0212 | F-034 | Project Customization Auto-Sync |
| F-0220 | F-035 | Protected Main Branch Support |
| F-0228 | F-036 | Workflow Definition File |
| F-0230 | F-037 | MCP Coordination Server |
| F-0231 | F-038 | Multi-Repo Umbrella |
| F-0232 | F-039 | Full Autonomous Scheduling |

**Dev Infrastructure** (DEV-001 — DEV-004):
| Old | New | Name |
|-----|-----|------|
| DEV-0001 | DEV-001 | Framework Development Infrastructure |
| DEV-0122 | DEV-002 | Testing Infrastructure |
| DEV-0199 | DEV-003 | Instruction File Integrity |
| DEV-0243 | DEV-004 | Complexity Tier Experiments |

**NFR IDs**: No change (NFR-0001, NFR-0003, NFR-0004 keep current IDs).

### Migration Records

Each of the 28+ protected contracts gets an individual migration entry:
```yaml
migrations:
  - id: M-2026-03-24-001
    date: 2026-03-24
    description: "Renumbered from F-XXXX to F-XXX as part of F-0184 hierarchy renumber"
    breaking: false
```

The migration IDs are sequential: `M-2026-03-24-001` through `M-2026-03-24-028` (or however many). This fits the existing schema without inventing a new batch concept.

### Renumber Sub-Phases

**Phase 2a**: Build `tools/renumber.py` script + `tools/renumber_mapping.json`. Test on a worktree copy.
**Phase 2b**: Run script on main. One big PR. Create `docs/archive/ID_MIGRATION.md` with the old→new lookup.
**Phase 2c**: Add migration entries to each protected contract.

### What NOT to rename
- `consolidated_from` entries (dead IDs — historical tombstones)
- Git commit messages (can't change history)
- Closed GitHub PR/issue references (external, read-only)
- `docs/archive/` entirely (historical snapshots)
- `.agentic/journal/` plan and journal entries (historical references should remain as-written)
- `nfr_refs` values (NFR IDs unchanged)

---

## Phase 3: Decompose Selected Features (optional, demonstrates the system)

After Phase 1+2, decompose 1-2 large features to demonstrate the hierarchy:

Example: **F-025 Agent System & Instructions** (currently 12 consolidated, covers instruction arch + skills + memory seed + multi-tool):
```
F-025       Agent System & Instructions
  F-025.1   Instruction Architecture (3-layer: Constitution → Playbooks → State)
  F-025.2   Skills System (just-in-time guidance)
  F-025.3   Memory Seed (bootstrap agent knowledge)
  F-025.4   Multi-Tool Support (Claude, Cursor, Copilot, Codex)
```

Each child gets its own contract YAML with 2-3 focused ACs extracted from the parent.

---

## What stays the same

- State machine (9 states, transition rules)
- `derive_epic_status()` — already handles parent-child status derivation recursively
- `_recompute_parent_if_needed()` — already cascades upward
- `consolidated_from` semantics — historical, separate from live hierarchy
- Contract protection model — shipped contracts require migrations
- FEATURES.md uses flat `## F-XXX:` headers (no nested markdown)
- Profile handling (discovery/formal/autonomous_formal)

## Verification

1. `python3 -m pytest tests/test_ids.py` — dotted ID patterns, depth, parent/child
2. `bash tests/validate_framework.sh` — all features pass with new IDs
3. `ag contract check F-025 --recursive` — verifies parent + children ACs
4. `ag contract tree` — shows hierarchy
5. `ag decompose F-025 --extract AC-001,AC-002` — creates F-025.1
6. Renumber script: run on worktree, diff review, validate_framework.sh passes

## Sequencing (PRs)

1. **PR 1 (Phase 1a)**: Schema + ids.py/ids.sh + contracts.py + shell audit (~8-10 files)
2. **PR 2 (Phase 1b)**: epic.py + new commands + query_features.py (~5-8 files)
3. **PR 3 (Phase 2a)**: Build renumber.py script + mapping JSON + test on worktree
4. **PR 4 (Phase 2b+c)**: Execute renumber + migration entries + ID_MIGRATION.md
5. **PR 5 (Phase 3, optional)**: Decompose 1-2 features as demonstration
