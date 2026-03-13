# Plan: Fix DRAFT Plan Bypass at Session Start

**Status**: APPROVED (revised per dialectical review — Critic REVISE + Advocate APPROVE)
**Type**: Process fix (no feature ID — this is framework infrastructure)
**Root cause**: Post-mortem documents the F-0204 incident where a DRAFT plan was implemented without review

## Context

When a session ends mid-workflow (after plan creation but before review), the next session starts with an unsaved plan in `~/.claude/plans/`. The dashboard runs, but nothing in the session-start flow detects the orphaned plan or directs the agent to continue the review loop. The agent sees the plan as context and may jump straight to implementation, bypassing the mandatory dialectical review gate.

## Implementation Plan

### File 1: `.agentic/lib/tools/dashboard.sh` (~10 lines)

**Where**: After the STALE check (L202), before the output section (L207). Reuse existing `plan-scan.sh`:

```bash
# ORPHANED PLANS (unsaved session-scoped plans needing review)
# Note: This is distinct from periodic-checks.sh check_orphaned_plans() which uses
# fingerprint matching and a 2+ feature ID threshold. dashboard uses plan-scan.sh
# because it's the action tool (saves plans), while periodic-checks is advisory.
D_ORPHAN_PLANS=0
D_ORPHAN_PLAN_SUMMARY=""
if [[ -f "$TOOLS_DIR/plan-scan.sh" ]]; then
    _ps_out=$(bash "$TOOLS_DIR/plan-scan.sh" --check --quiet 2>/dev/null) || true
    if [[ -n "$_ps_out" ]]; then
        D_ORPHAN_PLANS=$(echo "$_ps_out" | grep -oE '[0-9]+' | head -1)
        D_ORPHAN_PLANS="${D_ORPHAN_PLANS:-0}"
        D_ORPHAN_PLAN_SUMMARY="$_ps_out"
    fi
fi
```

**Where**: In the rendered dashboard section, after the AC Drift conditional (L332), before the Health line:

```bash
if [[ "$D_ORPHAN_PLANS" -gt 0 ]]; then
    echo "📝 Orphan plans   $D_ORPHAN_PLAN_SUMMARY"
fi
```

**Where**: In the "Next steps" section (L350-374), before the existing `if [[ "$D_WIP" == "interrupted" ]]` block:

```bash
if [[ "$D_ORPHAN_PLANS" -gt 0 ]]; then
    echo "   $step. Save orphaned plan(s) and run dialectical review before implementing"
    step=$((step + 1))
fi
```

**Where**: In the `--raw` output section, before `===TIP===` (L239):

```bash
echo "===ORPHAN_PLANS==="
echo "$D_ORPHAN_PLANS"
```

### File 2: `.claude/skills/session-start/SKILL.md` (~3 lines)

**Where**: Step 3 "Handle Critical Special Cases" (L37), add a new bullet:

```markdown
- **Orphaned plan detected** (📝 line present): A plan from a previous session was never saved
  or reviewed. Run `plan-scan.sh` to save it to `.agentic/journal/plans/`, then run the
  dialectical review loop (Critic + Advocate). Do NOT proceed to implementation until APPROVED.
```

### File 3: `.agentic/lib/checklists/session_start.md` (~5 lines)

**Where**: Step 3 "Handle Special Cases" section (L59), add a new entry after the upgrade case:

```markdown
**If dashboard shows orphaned plan(s)** (📝 line present):
- Previous session created a plan but it was never saved/reviewed
- FIRST: Run `bash .agentic/lib/tools/plan-scan.sh` to save to durable storage
- THEN: If `plan_review_enabled: yes`, run dialectical review (Critic + Advocate → synthesis → user approval)
- Do NOT start implementation — unsaved plan + review enabled = hard gate
```

### File 4: `.agentic/lib/init/memory-seed.md` (~3 lines)

**Where**: In the "Session start" section (~L173-181), after the existing `dashboard.sh` instruction, add:

```markdown
**At session start with orphaned plans**: If the dashboard shows orphaned plans (📝 line), saving and reviewing them is your FIRST action — not implementation, not exploration. Run `plan-scan.sh` to save, then run dialectical review if `plan_review_enabled: yes`. This takes priority over backlog items, interrupted work, or any other next step.
```

Note: This is a session-start behavior (triggered by the dashboard), NOT a plan-saving behavior. It belongs with the other session-start rules, not with the "Plans must be saved" section.

### File 5: `.agentic/lib/agents/shared/auto_orchestration.md` (~2 lines)

**Where**: In the "Handle Special Cases" table (L52-58), add a new row:

```markdown
| Dashboard shows orphaned plans (📝) | "📝 Orphaned plan(s) detected. Saving to journal and running dialectical review before implementation." |
```

## Files Changed Summary

| File | Change | Lines |
|------|--------|-------|
| `.agentic/lib/tools/dashboard.sh` | Orphaned plan detection via `plan-scan.sh` + display + next step + raw | ~10 |
| `.claude/skills/session-start/SKILL.md` | New bullet in Step 3 special cases | ~3 |
| `.agentic/lib/checklists/session_start.md` | New special case block | ~5 |
| `.agentic/lib/init/memory-seed.md` | Session-start orphaned plan rule | ~3 |
| `.agentic/lib/agents/shared/auto_orchestration.md` | New table row | ~2 |
| **Total** | | **~23 lines across 5 files** |

## What This Does NOT Change

- `plan-scan.sh` itself (already correct and feature-complete)
- The `ag implement` Step 0.5 safety net (already works if reached)
- The plan-review workflow itself (Critic + Advocate + synthesis)
- Memory feedback entries (already correct, just not surfaced at session start)

## Verification

1. **Dashboard test**: Create a test plan in `~/.claude/plans/` referencing a known F-XXXX, run `dashboard.sh`, verify 📝 line appears
2. **Cross-project filter**: Create a plan referencing F-9999 (not in FEATURES.md), verify it does NOT appear
3. **Already saved**: Save the plan to `journal/plans/`, re-run, verify 📝 disappears
4. **Raw mode**: Run `dashboard.sh --raw`, verify `===ORPHAN_PLANS===` section
5. **`periodic_orphaned_plans: off` behavior**: Set the STACK.md setting to `off`, verify dashboard STILL shows orphaned plans. This is correct — the setting controls `periodic-checks.sh`, not `dashboard.sh`. The dashboard always surfaces orphaned plans because it's the session-start safety net.
6. **Framework validation**: `bash tests/validate_framework.sh` passes
7. **End-to-end**: Start new session with orphaned plan → dashboard shows it → agent runs plan-scan → saves → reviews

## Design Notes

**Why `plan-scan.sh` and not `periodic-checks.sh`?** Both detect orphaned plans but serve different purposes:
- `plan-scan.sh` is the **action tool** — it finds plans, filters by project, and copies them to durable storage. Used by the dashboard because the next step is "run plan-scan.sh to save."
- `periodic-checks.sh check_orphaned_plans()` is the **advisory system** — it uses fingerprint matching and a 2+ feature ID threshold for broader detection. It runs on a schedule (`periodic_orphaned_plans` setting) and produces advisory warnings.
- The dashboard uses `plan-scan.sh --check --quiet` (dry-run mode) to detect without saving — the agent then runs `plan-scan.sh` (without `--check`) as its first action to actually save.
