# Plan: `ag sync` — Unified Framework Sync Command

## Context

The framework has many verification tools (doctor.sh, drift.sh, memory-check.sh, doc-check.sh, check-environment.sh) but no unified command that detects drift across ALL artifacts and auto-fixes what's safe. Currently:

- `ag start` shows a dashboard but doesn't fix anything
- `drift.sh` has interactive auto-fix but only covers spec/doc drift
- `memory-check.sh` detects stale memory but can't fix it
- No tool checks journal/status freshness against git activity
- No tool reconciles feature statuses against actual commit history
- Non-Claude environments especially need this — they lack auto-memory and rely entirely on file-based state

The user wants a single `ag sync` that verifies everything and auto-corrects safe errors, advertised at session start.

---

## Design

### Architecture: Separate `sync.sh` + thin `cmd_sync()` wrapper

`ag.sh` is 1670 lines. Complex sync logic goes in a new `.agentic/tools/sync.sh` (~200 lines). `cmd_sync()` in ag.sh is a thin wrapper (~10 lines), following the `cmd_verify()` → `doctor.sh` pattern.

### Five check phases

| Phase | What | Existing tool | New logic | Auto-fix? |
|-------|------|--------------|-----------|-----------|
| 1. Memory | Seed integrity | `memory-check.sh` | None | Report re-seed instruction |
| 2. State freshness | Journal + STATUS + CHANGELOG | None | ~50 lines | STATUS.md via `status.sh infer --apply` |
| 3. Feature reconciliation | FEATURES.md vs git history | None | ~50 lines (Core+PM only) | Report only (dangerous) |
| 4. Spec/doc drift | Spec ↔ code, doc coverage | `drift.sh --check`, `doc-check.sh` | None | Report only |
| 5. Tool parity | Instruction files exist + have trigger table | `check-environment.sh` | ~15 lines content check | Missing files via `check-environment.sh --fix` |

### Phase details

**Phase 1 — Memory**: Delegate to `memory-check.sh`. Non-Claude: skipped automatically.

**Phase 2 — State freshness** (new logic):
- **JOURNAL.md**: Parse last `### Session: YYYY-MM-DD` date, count git commits since. Flag if ≥3 commits since last entry.
- **STATUS.md**: Compare `(Updated: ...)` timestamp vs last git commit. Flag if ≥5 commits since.
- **CHANGELOG.md**: Compare latest version header `## [X.Y.Z]` against `VERSION` file. Flag if mismatched.
- **Auto-fix**: Run `bash status.sh infer --apply` for STATUS.md. Journal and CHANGELOG are report-only.

**Phase 3 — Feature reconciliation** (Core+PM only, new logic):
- Scan `spec/FEATURES.md` for `in_progress` features. If no git commits mention `F-XXXX` in 14+ days and no WIP.md references it → flag as stale.
- Scan last 20 git commits for feature IDs. If a feature is still `planned` but has commits → suggest `in_progress`.
- Check for acceptance files without FEATURES.md entries.
- **Report only** — all feature status changes need human judgment. Print specific `feature.sh` commands.

**Phase 4 — Spec/doc drift**: Run `drift.sh --check` (exit code signals drift). Run `doc-check.sh` for documentation coverage. Report results. Skip in `--quiet` mode (too slow).

**Phase 5 — Tool parity**:
- Run `check-environment.sh` to detect installed tools.
- For each detected tool's instruction file, grep for `User intent` (trigger table sentinel). Flag if missing.
- **Auto-fix**: `check-environment.sh --fix` for missing files. Content drift is report-only with `setup-agent.sh <tool>` remediation.

### Flags

```
ag sync              # Full sync: all phases, auto-fix safe things
ag sync --check      # Dry run: detect only, no auto-fixes
ag sync --quiet      # One-line summary (for ag start probe)
```

`--quiet` skips Phase 4 (drift.sh is slow) and outputs a single line: `Sync: 2 issues (journal stale, 1 feature drift)` or nothing if clean.

### Output format

```
=== ag sync ===

Memory:     OK (v0.25.3, 4/4 sentinels)
Journal:    STALE (last entry 2026-02-08, 5 commits since)
            Fix: bash .agentic/tools/journal.sh "Topic" "Done" "Next" "Blockers"
STATUS.md:  FIXED (auto-applied inferred state)
CHANGELOG:  OK (v0.25.3 matches VERSION)
Features:   1 issue
            F-0042: in_progress, no commits in 14 days
            Fix: bash .agentic/tools/feature.sh F-0042 status shipped
Spec drift: OK
Docs:       OK
Tool files: OK (.cursorrules, copilot-instructions.md present)

Summary: 5 OK, 1 fixed, 2 need attention
```

Exit code: always 0 (advisory).

### Integration with `ag start`

After the doctor quick check (line ~290 in cmd_start), add:

```bash
# 7. Quick sync probe
local sync_summary
sync_summary=$(bash "$SCRIPT_DIR/sync.sh" --quiet 2>/dev/null || true)
if [ -n "$sync_summary" ]; then
    echo -e "${YELLOW}${sync_summary}${NC}"
    echo -e "  Run ${BOLD}ag sync${NC} to auto-fix and see details"
fi
```

This is fast (skips drift.sh) and only shows output when issues exist.

---

## Files to modify

| # | File | Action | ~Lines |
|---|------|--------|--------|
| 1 | `.agentic/tools/sync.sh` | **NEW** | ~200 |
| 2 | `.agentic/tools/ag.sh` | cmd_sync() + dispatch + help + start probe | ~30 |
| 3 | `.agentic/checklists/session_start.md` | Add sync suggestion section | ~8 |
| 4 | `CLAUDE.md` | Add `ag sync` to Quick Commands line | ~1 |
| 5 | `.agentic/agents/claude/CLAUDE.md` | Add `ag sync` to Quick Commands line | ~1 |

## Implementation order

1. `sync.sh` — phases 1, 4, 5 (delegation to existing tools)
2. `sync.sh` — phase 2 (journal/status freshness — new logic)
3. `sync.sh` — phase 3 (feature reconciliation — new logic, Core+PM)
4. `sync.sh` — `--check`, `--quiet` flags
5. `ag.sh` — `cmd_sync()`, dispatch case, help text
6. `ag.sh` — `cmd_start()` quiet probe integration
7. `session_start.md` + CLAUDE.md updates

## Verification

1. `bash .agentic/tools/sync.sh` — runs all 5 phases, shows formatted output
2. `bash .agentic/tools/sync.sh --check` — same but no auto-fixes applied
3. `bash .agentic/tools/sync.sh --quiet` — one-line summary or empty
4. `ag sync` — same as direct invocation
5. `ag start` — should show sync probe if issues exist
6. `bash tests/validate_framework.sh` — all pass
7. `ag help` — shows `sync` in command list
