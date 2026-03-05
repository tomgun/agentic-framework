# Plan: Auto-resolve HUMAN_NEEDED PR entries (T-0026)

## Context

When agents create PRs, they log them to HUMAN_NEEDED.md so the human sees them at session start. After merge, these entries accumulate as resolved items — noise. This adds a sync phase that auto-detects merged/closed PRs via `gh pr view` and resolves them. Also fixes an existing bug where `ag start` counts resolved entries in the blocker total.

## Changes

### 1. sync.sh — Add Phase 8: PR cleanup

**File**: `.agentic/tools/sync.sh`

- Update header comment (line 9): "Seven check phases" → "Eight check phases", add phase 8 description
- Insert `phase_pr_cleanup()` function before `main()` (~40 lines):
  - Early return if no HUMAN_NEEDED.md or no `gh` CLI
  - Extract Active section only via `awk '/^## Active items/,/^---$/'`
  - Loop through lines matching `### HN-XXXX: ... PR #N ...` (bash `=~` regex)
  - For each: `gh pr view N --json state -q .state 2>/dev/null || echo ""`
  - If MERGED/CLOSED: in full mode call `blocker.sh resolve`, in quiet/check mode just `record_issue`
  - Use `tr '[:upper:]' '[:lower:]'` instead of `${var,,}` for bash 3.2 compatibility
- Wire into `main()`: add `phase_pr_cleanup` after `phase_periodic` in both quiet (line 653) and full (line 681) blocks

### 2. ag.sh — Fix inflated blocker count

**File**: `.agentic/tools/ag.sh` (line ~307)

Change:
```bash
blocker_count=$(grep -c "^### HN-" "$ROOT_DIR/HUMAN_NEEDED.md" 2>/dev/null || echo "0")
```
To:
```bash
blocker_count=$(awk '/^## Active items/,/^---$/' "$ROOT_DIR/HUMAN_NEEDED.md" 2>/dev/null | grep -c "^### HN-" || echo "0")
```

This scopes the count to the Active section only.

### 3. blocker.sh — Fix Resolution → Outcome field name

**File**: `.agentic/tools/blocker.sh` (line 137)

Change `**Resolution**` to `**Outcome**` to match the actual format used in resolved entries.

## Edge cases handled

- `gh` not installed → skip silently
- Network down → `gh pr view` fails, `|| echo ""` catches, entry skipped
- PR not found in GitHub → same as above
- No active entries → `record_ok`, done
- Active entry without PR number → regex doesn't match, skipped
- `blocker.sh resolve` fails → `|| true` guard, no propagation

## Verification

1. `bash tests/validate_framework.sh` — must pass
2. `bash .agentic/tools/sync.sh` — phase 8 should show OK (no active PR entries currently)
3. `bash .agentic/tools/sync.sh --quiet` — no output (clean)
4. Manual test: add a fake PR entry to HUMAN_NEEDED active section, run sync, verify it gets resolved
