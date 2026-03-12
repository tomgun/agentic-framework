# Plan: F-0208 — Deferred Documentation Mode

**Status: APPROVED**
**Created: 2026-03-12**
**Revised: 2026-03-12** (post-dialectical review)

## Context

The framework enforces "spec + code + tests + docs = done" — agents update project docs alongside code. This works well for thorough feature work but creates friction during fast iteration, spikes, or time pressure. F-0208 adds `docs_mode: inline | deferred` so agents can skip doc updates during implementation, logging what was skipped for later generation via `ag docs generate`.

Dependency F-0207 (doc registry validation) shipped in v0.53.10.

## Problem

No way to opt out of inline doc updates without setting `docs_gate: off` (which disables all doc checks). Users want to move fast AND eventually get docs — just not synchronously.

## Design Decisions

- **Deferred log location**: `.agentic/deferred-docs.json` (git-tracked, survives sessions). Session-scoped would defeat the purpose.
- **Log format**: JSON array. Each entry has `feature_id`, `timestamp`, `files_changed`, `description`, `stale_docs` (path + type), `commit_sha`. Self-contained — a future session can generate docs without remembering the original.
- **Generate command**: `ag docs generate` (all pending) or `ag docs generate F-XXXX` (one feature). Reads log, calls existing `docs.sh --trigger`/`--draft` per entry, removes completed entries.
- **Interaction with docs_gate**: `docs_gate` controls *whether* to check; `docs_mode` controls *when* to act. `docs_gate: off` = no doc work regardless. `docs_gate: warning|blocking` + `docs_mode: deferred` = check runs but logs instead of blocking. **Note**: the doc lifecycle section (line 1248) currently does NOT check `docs_gate` — `_defer_docs()` must add its own `docs_gate != off` guard to match the stated semantics.
- **Worktree safety**: Deferred log always writes to `$MAIN_PROJECT_ROOT/.agentic/deferred-docs.json` (using `MAIN_PROJECT_ROOT` from `paths.sh`), not `$ROOT_DIR`. This ensures a single log across worktrees.
- **JSON operations**: Use `jq` for all deferred log reads/writes (append, filter, remove). `jq` is widely available and the framework already benefits from it in other areas. Fallback: error with "jq required for deferred docs mode".

## Changes

### 1. STACK.template.md — Add setting (~line 35)

After `docs_gate` line, add:
```
- docs_mode: inline
# inline: update docs with code (default). deferred: log what's needed, generate later via `ag docs generate`.
```

**File**: `.agentic/lib/init/STACK.template.md`

### 2. profiles.conf — Profile defaults (~lines 15, 48, 84)

Add `docs_mode=inline` after each `docs_gate` line (discovery, formal, autonomous_formal). All default to inline — deferred is opt-in.

**File**: `.agentic/lib/presets/profiles.conf`

### 3. settings.sh — Add to settings list (~line 347)

Add `"docs_mode"` after `"docs_gate"` in the `show_all_settings()` array.

**File**: `.agentic/lib/settings.sh`

### 4. ag.sh — Core logic (3 sections)

**4a. cmd_set() validation (~line 2876)**: Add case after `docs_gate`:
```bash
docs_mode)
    if [[ ! "$value" =~ ^(inline|deferred)$ ]]; then
        echo -e "${RED}Error: docs_mode must be 'inline' or 'deferred', got '$value'${NC}"
        exit 1
    fi
    ;;
```

**4b. cmd_done() deferred branch (~line 1206-1272)**: Read `docs_mode` setting. When `deferred`:
- Drift check still runs (awareness) but blocking prompt is suppressed
- Doc lifecycle section (lines 1248-1272): guard with `docs_gate != off` first (fixing existing bug where lifecycle runs regardless of docs_gate). Then, instead of calling `docs.sh --trigger`, call new `_defer_docs()` helper that:
  1. Calls `parse_registry` (sourced from docs.sh) with `feature_done` trigger filter to get structured `path|type|trigger` data — NOT by parsing `--check` human-readable output
  2. Gets changed files from manifest or `git diff --name-only`
  3. Uses `jq` to append entry to `$MAIN_PROJECT_ROOT/.agentic/deferred-docs.json` (worktree-safe path)
  4. Prints: "Deferred doc updates for N doc(s). Run `ag docs generate` later."
  5. Removes entries one-by-one after each successful generation (not batch), so interruptions leave consistent state

**4c. cmd_docs() — Add `generate` subcommand (~line 1760)**: New case in the dispatch:
```bash
--generate|generate)
    _docs_generate "${feature_id:-}"
    ;;
```
`_docs_generate()` reads deferred log via `jq`, filters by feature if given, calls `docs.sh --trigger feature_done --manifest <fid>` for each entry, removes each entry from the log after successful processing (one-by-one, not batch). Bypasses WIP/feature-ID requirement since it reads IDs from the log.

**4d. Help text (~lines 177, 287)**: Add `ag docs generate` to help.

**File**: `.agentic/lib/tools/ag.sh`

### 5. implementing-features/SKILL.md — Step 6 deferred branch (~line 114)

Add at top of Step 6:
```markdown
**Check `docs_mode` in STACK.md first:**
- If `deferred`: skip inline doc updates. `ag done` will log what's needed. Focus on code + tests.
  Note: framework instruction file updates (framework dev only) are NOT deferred — always inline.
- If `inline` (default): proceed with the doc update steps below.
```

**File**: `.claude/skills/implementing-features/SKILL.md`

### 6. completing-work/SKILL.md — Step 2b deferred branch (~line 56)

Add at top of Step 2b:
```markdown
If `docs_mode: deferred` in STACK.md: skip doc verification — `ag done` logs deferred items automatically. Proceed to Step 3.
```

**File**: `.claude/skills/completing-work/SKILL.md`

### 7. memory-seed.md — Deferred docs rules

In "When committing or pushing" section (~line 63), add note about deferred mode skipping inline doc updates. In "When work is done (doc lifecycle)" section (~line 113), add: "If `docs_mode: deferred`, `ag done` logs deferred items instead of triggering immediate drafting. Run `ag docs generate` later." Update sentinels.

**File**: `.agentic/lib/init/memory-seed.md`

## Files NOT Changed (and why)

- **pre-commit-check.sh**: Check 19 is already advisory-only. No behavior change needed — it reports health, doesn't trigger doc writing.
- **docs.sh**: Stays a pure context assembler. `_defer_docs()` sources `parse_registry` from docs.sh for structured data, but all deferred log I/O lives in ag.sh.
- **committing-changes/SKILL.md**: Doc update responsibility is in implementing-features Step 6 and completing-work Step 2b, not in the commit skill.
- **auto_orchestration.md**: `ag done` changes are picked up automatically regardless of which tool drives the session.
- **upgrade.sh**: No migration needed. Existing projects without `docs_mode` in STACK.md get `inline` via profile default fallback in `get_setting`. The setting is opt-in.
- **ag flush / state-commit.sh**: `deferred-docs.json` is NOT a state file — it's a work tracking artifact. It gets committed via normal git workflow, not via `ag flush`.

## Deferred Log Format

`.agentic/deferred-docs.json`:
```json
[
  {
    "feature_id": "F-0208",
    "timestamp": "2026-03-12T10:30:00Z",
    "files_changed": ["ag.sh", "docs.sh"],
    "description": "Added deferred docs_mode setting",
    "stale_docs": [
      {"path": "CHANGELOG.md", "type": "changelog"},
      {"path": "README.md", "type": "readme"}
    ],
    "commit_sha": "abc1234"
  }
]
```

## Review Revisions (from dialectical review 2026-03-12)

Issues addressed from Critic review:
1. **JSON-in-bash fragility** → Use `jq` for all deferred log operations. Error if `jq` not available.
2. **Worktree path resolution** → Use `$MAIN_PROJECT_ROOT` (from `paths.sh`) for deferred log path. Single log across all worktrees.
3. **Parsing docs.sh output** → Source `parse_registry` directly for structured `path|type|trigger` data. No human-readable output parsing.
4. **`docs_gate: off` interaction** → Guard doc lifecycle section (and `_defer_docs()`) behind `docs_gate != off`. Fixes existing bug where lifecycle ran regardless.
5. **Entry removal strategy** → Remove entries one-by-one after each successful generation, not batch. Interruption-safe.

Deferred to follow-up (non-blocking for v1):
- `ag sync` surfacing of pending deferred docs (low priority — dashboard can do this)
- Staleness warning for old deferred entries (nice-to-have)
- `ag auto epic` auto-generating at end of epic run (edge case)

## Verification

1. `bash tests/validate_framework.sh` — no regressions
2. Set `docs_mode: deferred` in STACK.md, run `ag done` — verify deferred log created, no blocking
3. Run `ag docs generate` — verify context assembled for deferred items, log cleared
4. Set `docs_mode: inline` — verify current behavior unchanged
5. `ag set docs_mode deferred` works; `ag set docs_mode invalid` fails
6. Read skill files — deferred branch is clearly scoped, doesn't affect inline behavior
7. Verify `docs_gate: off` + `docs_mode: deferred` does NOT create deferred entries
8. Verify in worktree: deferred log written to main repo, not worktree root
