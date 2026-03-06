# Plan: Eliminate status.json — Direct STATUS.md Updates

## Context

`status.json` was added in v0.12.0 as a "JSON backend for token-efficient status updates." The intent: update JSON fast, sync to markdown on demand. In practice, every `status.sh focus "..."` call immediately writes JSON then immediately syncs to STATUS.md — the JSON is never used independently. Meanwhile:

- Pre-commit and session-start staleness checks already use **STATUS.md mtime**, not status.json
- STATUS.md is already git-tracked (syncs across machines) — no need for a separate JSON file
- status.json tracks 4 fields; STATUS.md has ~11 sections — the JSON only manages a subset
- `.agentic/state/` directory exists solely for this one file

**Goal**: Remove the JSON intermediary. Have status.sh update STATUS.md directly using the existing awk logic.

## Changes

### 1. Refactor `.agentic/tools/status.sh`

**Remove** (JSON layer — ~90 lines):
- `STATE_DIR` / `STATE_FILE` path definitions and `mkdir -p`
- `init_state()` — creates JSON from STATUS.md
- `read_state()` — reads field from JSON (jq/grep)
- `update_state()` — writes field to JSON (jq/sed)
- `sync` command handler
- `show` command handler
- Usage text entries for `sync` and `show`

**Keep verbatim**: The awk block in `sync_to_md()` (lines 100-142) — proven, well-tested section replacement.

**Refactor into**:
- `_read_current()` — extract current values from STATUS.md using awk (adapted from existing `init_state()` extraction logic on lines 32-36)
- `_apply_to_md()` — the existing awk replacement block, taking `focus`, `progress`, `next_step`, `blocker`, `timestamp` as parameters
- `update_md()` — calls `_read_current()`, overrides the target field, calls `_apply_to_md()`

**Update `infer --apply`** (lines 277-284): Replace `init_state` + multiple `update_state` + `sync_to_md` calls with a single `_apply_to_md()` call passing all inferred values directly.

**Main case statement**: Replace `update_state` + `sync_to_md` with single `update_md` call.

**Net result**: ~280 lines (down from 367), no jq dependency, no sed-based JSON manipulation.

### 2. Delete `.agentic/state/`

- Delete `.agentic/state/status.json`
- Delete `.agentic/state/` directory (nothing else lives there)

### 3. Add upgrade.sh cleanup

Add after the STATUS.md migration step (~line 299):
```bash
# Cleanup: Remove deprecated status.json backend (removed in v0.25.0)
rm -f "$TARGET_PROJECT_DIR/.agentic/state/status.json" 2>/dev/null
rmdir "$TARGET_PROJECT_DIR/.agentic/state" 2>/dev/null || true
```

### 4. Update documentation

**`CONTEXT_PACK.md`** (2 changes):
- Line 59: `status.sh - JSON backend...` → `status.sh - Direct STATUS.md section updates (focus, progress, next, blocker)`
- Line 75: Remove `.agentic/state/status.json` entry entirely

**`docs/INSTRUCTION_ARCHITECTURE.md`** (4 changes):
- Line 74: Remove status.json from Layer 3 state list; note STATUS.md holds all runtime state
- Line 110: Remove status.json from "git-tracked vs gitignored" split description
- Line 162: Update "State = machine-readable" — STATUS.md sections parsed by status.sh (not status.json)
- Line 205: Mark assumption A10 as RESOLVED — STATUS.md is the cross-machine state file

**Do NOT edit** (historical records): CHANGELOG.md, CONTRIBUTIONS.md, lessons, manifests.

## Files

| File | Action | Scope |
|------|--------|-------|
| `.agentic/tools/status.sh` | Refactor | ~90 lines removed, ~20 added |
| `.agentic/state/status.json` | Delete | entire file |
| `.agentic/state/` | Delete | directory |
| `CONTEXT_PACK.md` | Update | 2 lines |
| `docs/INSTRUCTION_ARCHITECTURE.md` | Update | 4 references |
| `.agentic/tools/upgrade.sh` | Add cleanup | ~3 lines |

## What Does NOT Change

- **Public API**: `status.sh focus|progress|next|blocker "value"` — identical behavior
- **`status.sh infer` / `infer --apply`** — already reads git/journal/features, not JSON
- **Pre-commit hook** — already checks STATUS.md mtime
- **Session-start hook** — already checks STATUS.md mtime
- **LLM tests** — test agent awareness of status.sh, not internals
- **Framework validation tests** — check status.sh exists and uses awk

## Pre-existing Issue (out of scope)

The awk targets `## Next immediate step` and `## Blockers` as top-level sections, but STATUS.template.md has these as sub-bullets under `## Current session state`. This means `status.sh next` and `status.sh blocker` only work if users manually add those as top-level sections. Pre-existing, not caused by this refactor.

## Verification

1. `bash tests/validate_framework.sh` — all 184+ checks pass
2. Manual test in scratch project: `status.sh focus/progress/next/blocker/infer` all work
3. No `.agentic/state/` directory or `status.json` file created
4. Pre-commit hook still blocks on stale STATUS.md
