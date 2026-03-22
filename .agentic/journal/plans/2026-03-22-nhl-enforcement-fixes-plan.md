**Status**: APPROVED

# Plan: Fix Enforcement Gaps Exposed by NHL Hockey Game Test

**Date**: 2026-03-22
**Trigger**: NHL Hockey Game test project (v0.70.0) — complete framework bypass under `autonomous_formal` + `state_enforcement: blocking`
**Analysis**: `.agentic/journal/reviews/2026-03-22-nhl-hockey-game-enforcement-review.md`
**Evidence**: `agentic-tests/nhl-hockey-game/to_agentic_af/`

---

## Scope

Fix 4 enforcement gaps (P0–P1) and 1 init issue that allowed an agent to bypass all framework gates and build 10 features simultaneously without entering the workflow.

## Changes

### 1. P0: PreToolUse.sh — Fail-Closed Gate Error Handling

**File**: `.agentic/lib/claude-hooks/PreToolUse.sh`
**Problem**: Only checks `$GATE_RC -eq 2` (deny). Exit code 1 (Python crash/import error) silently allows.
**Fix**: After the exit-2 deny block, add fail-closed handling for any non-zero exit when `state_enforcement: blocking`. Use fast `grep` on STACK.md (not Python) to check enforcement level — avoids shared failure mode.

```bash
if [[ "$GATE_RC" -ne 0 ]]; then
  if grep -q 'state_enforcement:.*blocking' "$PROJECT_ROOT/.agentic/STACK.md" 2>/dev/null; then
    _deny "Gate error (exit $GATE_RC). state_enforcement=blocking requires fail-closed."
  fi
fi
```

**Impact**: Would have prevented the entire incident. All 16 `.ts` file writes blocked.

### 2. P0: UserPromptSubmit.sh — Expand Batch-Work Regex

**File**: `.agentic/lib/claude-hooks/UserPromptSubmit.sh` (line 81)
**Problem**: Regex catches "build everything" but misses "work autonomously and come back with the working game."
**Fix**: Add 8 semantic patterns:
- `work autonomously.*(game|app|project|system|working)`
- `come back with.*(working|finished|complete|done)`
- `build.*(whole|entire|full)\s+(game|app|project|system)`
- `finish everything`
- `do it all`
- `complete the (project|app|game)`
- `implement the (whole|entire|full)`
- `ship (it all|everything)`
- `create.*(entire|whole|full).*(app|game|project)`

**Validation**: Tested — all 6 batch patterns match, zero false positives on "implement F-0001" / "fix this bug".

### 3. P1: on-code-edit.sh — Add "No Features Implementing" Warning

**File**: `.agentic/lib/hooks/shared/on-code-edit.sh`
**Problem**: Only checks for DRAFT plans. Silent when zero features are implementing.
**Fix**: Add CHECK 1 (before DRAFT plan check): grep FEATURES.md for `status: implementing|in.review|testing`. If none found and file is production code (not spec/test/config), warn:

```
🚨 NO ACTIVE WORK ITEM — code edit without any feature in 'implementing' state.
   All features are still planned. Run `ag start F-XXXX` then `ag implement F-XXXX`.
```

**Also**: Restructure to read stdin once at the top (fix bug where DRAFT check couldn't read stdin after no-WIP check consumed it). Add unified allowlist function.

### 4. P1: Anti-Rationalization Callouts

**Files**: `CLAUDE.md` (root), `.agentic/lib/agents/claude/CLAUDE.md` (template), `.agentic/lib/init/memory-seed.md`
**Problem**: Batch-work rule has no named rationalizations (unlike plan-review rule which has 4).
**Fix**: Add after the batch-work rule:

> **Wrong rationalizations:** "I can implement it directly faster" — NO. "ag auto crunch spawns subprocesses, I have full context" — NO. "The user said autonomous = skip ceremony" — NO.

**Also**: Expand memory-seed trigger words to include "work autonomously", "come back with working", "finish everything", "do it all".

### 5. P2: PreToolUse Timeout Increase

**File**: `.agentic/lib/claude-hooks/hooks.json`
**Problem**: 2000ms timeout may be too tight for cold Python startup.
**Fix**: Increase to 3000ms. Update header comment in PreToolUse.sh.

### 6. Documentation (Internal Only)

- **FRAMEWORK_DEVELOPMENT.md**: Lessons Learned entry with enforcement chain diagram, 3 failure modes, 5 design principles
- **docs/INSTRUCTION_ARCHITECTURE.md**: Design principles #9 (fail-closed enforcement) and #10 (silence is permission)
- **CONTRIBUTIONS.md**: User's test methodology, evidence package creation, git interview finding
- **docs/KEY_INSIGHTS.md**: Concise outward-facing entry (§21)

### 7. (Deferred) Git Interview for autonomous_formal

scaffold.sh auto-runs `git init` for autonomous_formal before the playbook interview asks. Fix is to defer git init to the playbook Step 1b for all profiles. Tracked separately — not blocking for this PR.

## Files Changed

| File | Type |
|------|------|
| `.agentic/lib/claude-hooks/PreToolUse.sh` | Code fix (P0) |
| `.agentic/lib/claude-hooks/UserPromptSubmit.sh` | Code fix (P0) |
| `.agentic/lib/hooks/shared/on-code-edit.sh` | Code fix (P1) |
| `.agentic/lib/claude-hooks/hooks.json` | Config (P2) |
| `CLAUDE.md` | Behavioral rule (P1) |
| `.agentic/lib/agents/claude/CLAUDE.md` | Behavioral rule (P1) |
| `.agentic/lib/init/memory-seed.md` | Behavioral rule (P1) |
| `FRAMEWORK_DEVELOPMENT.md` | Documentation |
| `docs/INSTRUCTION_ARCHITECTURE.md` | Documentation |
| `.agentic/CONTRIBUTIONS.md` | Documentation |

## Verification

- `bash -n` syntax check on all modified shell scripts
- Regex tested against 8 prompts (6 match, 2 correct non-match)
- `validate_framework.sh` passes (same 3 pre-existing failures)
- No new test files needed — enforcement is verified by test projects, not unit tests

## Design Principles Applied

1. **Fail-closed for blocking mode**: Gate errors → deny (not allow)
2. **Check enforcement level without shared failure mode**: grep on STACK.md, not Python
3. **Defense-in-depth with independent mechanisms**: PreToolUse (bash+grep), on-code-edit (bash+grep), UserPromptSubmit (bash regex) — no shared Python dependency
4. **Named rationalizations**: Harder to bypass than generic prohibitions
5. **Silence is permission**: Every defense layer should produce visible output, not fail silently
