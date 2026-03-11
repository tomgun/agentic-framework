# Plan: F-0207 — Project Documentation Lifecycle

**Status**: APPROVED
**Feature**: F-0207
**Created**: 2026-03-11
**Revised**: 2026-03-11 (R4 — broad unregistered scan, design for user projects)

## Design Principle

This feature is for **projects that use the framework**, not for the framework itself. Every design decision must answer: "Does this work for a Rails app? A Python CLI? A React project?" If it only works for the agentic framework repo, it's wrong.

## Problem

The framework has doc tooling (`docs.sh`, `drift.sh`, `docs_gate`) but it's fragmented:
- **One real gate** (`docs_gate: blocking` at `ag done`) — nothing at commit time
- **`docs.sh` assembles context** but doesn't validate docs exist or are complete
- **No registry validation** — STACK.md entries can point to missing files, and new docs can be created without registration
- **No coverage tracking** — no way to see which areas have docs and which don't
- **No scaffolding** — creating a new doc requires manual file creation + manual registry entry
- **Drift detection is keyword-only** — heuristic, not precise

The "spec + code + tests + docs = done" principle exists as text but lacks structural enforcement across the full lifecycle.

## Approach

Enhance existing `docs.sh` with new subcommands rather than creating new tools. Keep the registry in STACK.md as the single source of truth. Add validation and coverage features.

### Changes

**1. `docs.sh --validate`** — Registry health check
- **Registered-but-missing**: Refactor existing `check_staleness()` logic (docs.sh lines 246-249 already detect missing files) into a shared `check_file_exists()` helper, reuse in both `--validate` and staleness modes
- **Existing-but-unregistered** (new): Broad scan of all `.md` files in the project, flag any not in the registry. Scan scope:
  - `find . -name '*.md'` with sensible exclusions: `node_modules/`, `.git/`, `vendor/`, `dist/`, `build/`, `.agentic/lib/` internals (agents, support, hooks, tools, checklists, init — framework plumbing, not project docs), `.agentic/session/`, `.claude/skills/`
  - Also exclude known config/state files by name: `STACK.md`, `CLAUDE.md`, `CONTEXT_PACK.md`, `AGENTS.md`, `SESSION_LOG.md`, `CODEX.md`, `.cursorrules` equivalents
  - Everything else is a candidate. If it's `.md` and not registered, flag it
  - This catches docs wherever they live — `docs/`, `guides/`, root, `src/`, anywhere
  - Projects with many non-doc `.md` files can add exclusion patterns in STACK.md (future: `docs_scan_exclude:` setting) or just register/ignore the noise once
- Report both categories with clear labels
- Exit code: non-zero if issues found
- Handle directory entries (e.g., `docs/adr/`) — check directory exists, don't treat as file. Individual files inside a registered directory are NOT flagged as unregistered

**2. `docs.sh --coverage`** — Area coverage report
- "Areas" = the doc type tags in the `## Docs` registry (second pipe-delimited column: architecture, lessons, runbook, tech-spec, changelog, readme, custom, etc.)
- Cross-reference: for each type tag, list which docs exist. Show types with 0 docs as gaps
- Output: simple table of type × count, with paths listed under each
- Purely registry-driven, no code scanning — works for any project regardless of structure
- Scope: P2 (nice-to-have). Core value is in `--validate` and `--create`

**3. `docs.sh --create <path> --type <type> --trigger <trigger>`** — Scaffolded doc creation
- Create new doc from inline templates defined in `.agentic/lib/agents/shared/doc_types.md` (each type has a "New file template" block under fenced code blocks). NOT `.agentic/lib/support/docs_templates/` (those are for `sync_docs.sh` project scaffolding)
- Extract template: parse `doc_types.md` for `## <type>` heading, extract content between the next triple-backtick fences
- Auto-register in STACK.md `## Docs` by appending a `- doc:` entry before the next `##` heading. Use `parse_registry()` output to detect duplicates (idempotent)
- Format the pipe-delimited entry to match existing alignment in STACK.md
- Error handling: reject if path already exists (unless `--force`), reject if type is not a `## ` heading in `doc_types.md`, require all three arguments
- Works for any project: `docs.sh --create docs/api-guide.md --type architecture --trigger feature_done`

**4. Pre-commit advisory for doc registry health**
- Add check to `.agentic/lib/hooks/pre-commit-check.sh` (the actual pre-commit quality gate file)
- **Check 19** — next available number (current checks: 1-16 sequential, plus out-of-order 17=custom gates, 18=instruction sync)
- Respect `_FAST_MODE` — skip in fast mode (add 19 to the skip list at line ~48)
- Runs `docs.sh --validate` (not full `drift.sh --docs` — registry health is fast, drift detection is slow)
- Advisory only: print warnings but exit 0. `docs_gate: off` skips entirely
- No caching needed — `--validate` is a fast file-existence check, not a git-log heuristic

**5. `ag done` enforcement improvements**
- Run `docs.sh --validate` during `ag done` (ag.sh `cmd_done()`, near existing `docs_gate` check at lines 1206-1232)
- When `docs_gate: blocking`: require both drift check AND registry validation to pass
- When `docs_gate: warning`: run both, show advisory output, don't block
- When `docs_gate: off`: skip both (existing behavior preserved)

## Prerequisites

- **`spec/acceptance/F-0207.md` must be created** before implementation begins (per framework spec-first rules). The AC section below is the draft content; the formal file is created at Step 1 of the implementing-features workflow.

## Files to Modify

| File | Change | Lines |
|------|--------|-------|
| `.agentic/lib/tools/docs.sh` | Add `--validate`, `--coverage`, `--create` subcommands; refactor `check_staleness()` file-exists into shared helper | ~150 added |
| `.agentic/lib/tools/ag.sh` | Add `docs.sh --validate` call in `cmd_done()` near docs_gate check | ~10 added |
| `.agentic/lib/hooks/pre-commit-check.sh` | Add check 19: doc registry advisory | ~20 added |
| `.agentic/lib/checklists/before_commit.md` | Update doc section to mention `--validate` | ~5 changed |
| `.claude/skills/implementing-features/SKILL.md` | Step 6: reference `--create` for new docs | ~3 changed |
| `.claude/skills/completing-work/SKILL.md` | Step 2b: reference `--validate` | ~3 changed |
| `.agentic/lib/init/memory-seed.md` | Add `docs.sh --validate` to quick-reference | ~3 changed |
| `.agentic/lib/agents/shared/auto_orchestration.md` | Document `--validate` as gate in `ag done` | ~5 changed |
| `docs/HOW_IT_WORKS.md` | Document new doc lifecycle subcommands | ~10 changed |
| `tests/test_docs_validate.sh` | New: integration tests for `--validate` | ~40 added |
| `tests/test_docs_create.sh` | New: integration tests for `--create` | ~30 added |

**Estimated: ~11 files, ~280 lines added/changed**

## Tests

- **`tests/test_docs_validate.sh`**: Integration test — create a temp project directory with a STACK.md containing known missing entries and unregistered doc files in `docs/`. Run `--validate`, verify exit code non-zero and output contains expected warnings. Also test clean state (exit 0). Test directory entry handling. Test that files outside `docs/` and root are NOT flagged as unregistered (only registered-but-missing).
- **`tests/test_docs_create.sh`**: Integration test — run `--create` with valid args in a temp project, verify file created with correct template content and STACK.md entry appended. Test idempotency (second run same path). Test invalid type rejection. Test existing path rejection.
- **Pre-commit check test**: Verify check 19 fires when `docs_gate != off` and skips when `docs_gate: off` or `_FAST_MODE=1`.
- Extend `tests/validate_framework.sh` to include `docs.sh --validate` as a framework health check.

## Acceptance Criteria

- AC-001: `docs.sh --validate` detects registered-but-missing and existing-but-unregistered docs. Unregistered scan is broad: all `.md` files with sensible exclusions (framework internals, config/state, node_modules). Works for any project.
- AC-002: `docs.sh --coverage` shows type × doc count table (types from registry tags). P2.
- AC-003: `docs.sh --create` scaffolds a new doc from `doc_types.md` templates and auto-registers in STACK.md (idempotent, validates type against `doc_types.md` headings, rejects existing paths). Works for any project path.
- AC-004: Pre-commit check 19 warns about registry issues (advisory, respects `docs_gate`, skips in `_FAST_MODE`)
- AC-005: `ag done` runs registry validation when `docs_gate` is `warning` or `blocking`

## Execution Order

### Phase 1: Foundation (do first)
- AC-001 (`--validate`) — refactor shared helper, build scan logic
- AC-003 (`--create`) — depends on `parse_registry()`, independent of AC-001 [P]
✅ CHECKPOINT: Run tests, verify both subcommands work

### Phase 2: Integration
- AC-005 (`ag done` enforcement) — depends on AC-001
- AC-004 (pre-commit advisory) — depends on AC-001 [P]
✅ CHECKPOINT: Run validate_framework.sh, verify gates fire correctly

### Phase 3: Enhanced (P2)
- AC-002 (`--coverage`) — depends on AC-001's scan logic

## Risks

- **Scope creep**: Feature description mentions "all artifacts" (specs, tests) but this plan focuses on docs — specs and tests have their own enforcement already (`spec-analyze.sh`, test requirements in AC). Keep focused.
- **Pre-commit performance**: `--validate` is file-existence checks only (fast). Full `drift.sh --docs` NOT run at commit time. No caching needed.
- **Registry format fragility**: STACK.md parsing is grep-based. All consumers go through `parse_registry()` in `docs.sh`. If the format gains a 4th column, only `parse_registry()` needs updating.
- **STACK.md write fragility**: `--create` appends entries via sed/awk. Mitigate: match existing format precisely, test with fixture files, add idempotency guard. Write STACK.md entry first, then create file — if STACK.md write fails, no orphaned file.

## Alternatives Considered

1. **New `docs-lifecycle.sh` tool**: Rejected — fragmentation. Better to extend existing `docs.sh`.
2. **Move registry to JSON**: Rejected — STACK.md is human-editable and survives `.agentic/` upgrades. Keep it.
3. **Block commits on doc staleness**: Rejected for now — too aggressive. Advisory at commit, blocking at `ag done`.
4. **Use `docs_templates/` for `--create`**: Rejected — those are for `sync_docs.sh` project scaffolding. `doc_types.md` inline templates are the right source for on-demand creation.
5. **Full `drift.sh --docs` at pre-commit**: Rejected — too slow (git-log heuristics). `--validate` (file-existence) is fast and sufficient for commit-time advisory.
6. **Hardcoded framework-specific scan paths**: Rejected — the framework exists to serve user projects. Scan all `.md` files broadly with sensible exclusions.
7. **Narrow scan (only `docs/` + root)**: Rejected after review — too conservative. A broad scan catches docs wherever they live. Noise is manageable: projects can register or ignore flagged files.
