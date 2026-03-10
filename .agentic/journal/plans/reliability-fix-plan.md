# Prioritized Framework Reliability Fix Plan (REVISED)

**Status**: APPROVED
**Revision**: 3 — final, incorporates two rounds of dialectical review
**Feature ID**: TBD (register before implementation)
**Date**: 2026-03-10

## Context

March 2026 conversation history analysis revealed systemic reliability gaps: features marked "shipped" with unchecked acceptance criteria, state machine gates that exist but are never invoked from CLI workflows, no tooling to detect instruction file staleness, and FEATURES.md status diverging from actual implementation state.

**Meta-problem**: Behavioral enforcement (instructions to agents) fails; only architectural enforcement (code) works reliably. Specifically, imperative "script A calls script B" sequences are fragile — work gets interrupted (token limits, agent death, user closes session), leaving state half-updated with no recovery path.

## Design Principles

### Agent-Agnostic by Default (D7)

All core logic MUST live in `.agentic/lib/` — accessible to Claude Code, Cursor, Copilot, Codex, and any future tool. Claude `.claude/skills/` are an enhancement layer that wraps core logic, never replaces it.

**Concrete implications for this plan:**
- `drift-check.sh`, `instruction-sync.sh`, `intents.py` → `.agentic/lib/` (tool-agnostic)
- New `ag` commands (`ag intent`) → accessible from any tool via shell
- Reconciliation via `ag sync` → works in any tool (already tool-agnostic)
- No capability locked behind Claude skills
- Plan scan (P3) must check `.claude/plans/` AND `.cursor/plans/` AND any future tool plan dirs

### Instruction File Propagation

When adding new `ag` commands, ALL instruction files must be updated:
1. `.agentic/lib/agents/claude/CLAUDE.md` (quick commands)
2. `.agentic/lib/agents/cursor/cursorrules.txt` (trigger table + quick commands)
3. `.agentic/lib/agents/copilot/copilot-instructions.md` (trigger table + quick commands)
4. `.agentic/lib/agents/codex/codex-instructions.md` (trigger table + quick commands)
5. `.agentic/lib/agents/shared/auto_orchestration.md` (full workflow)
6. `.agentic/lib/init/memory-seed.md` (behavioral reinforcement)
7. `.agentic/lib/agents/shared/agent_operating_guidelines.md` (reference)
8. `.agentic/lib/DEVELOPER_GUIDE.md` (documentation)

Root files (CLAUDE.md, .cursorrules) extend templates — update those too for framework-dev.

### Separate Reliability from Behavioral Change

The review identified that wiring state transitions into `cmd_done` is NEW BEHAVIOR, not just a reliability improvement. The plan must clearly distinguish:
- **Reliability**: Crash recovery for existing operations (intent journal + reconciliation)
- **Behavioral**: Enforcing state machine transitions that `cmd_done` never ran before

Both are valuable but should be separately gated via `state_enforcement` setting.

---

## Priority 1: FEATURES.md Registry Integrity (Quick wins, high trust impact)

**Problem**: 5 features have status/implementation mismatches. FEATURES.md is the source of truth but it lies.

### 1a. Mark dead features as deprecated
- **F-0033** (AGENTS_ACTIVE.md): Mark `deprecated` — superseded by AGENTS.json (F-0194). Remove template. Close T-0017.
- **F-0098** (Generate Skills from Subagents): Mark `deprecated` — superseded by F-0143 hand-crafted skills.
- Files: `.agentic/spec/FEATURES.md`, `.agentic/spec/AGENTS_ACTIVE.template.md` (delete), `.agentic/TODO.md` (close T-0017)

### 1b. Fix implementation state for features that ARE wired
- **F-0190** (Backlog): Change "State: implementing" → "State: complete". Code is fully wired. Check off ACs that pass.
- **F-0179** (Component Registry): Change "State: none" → "State: complete". Code exists and is integrated. Check off ACs that pass.
- **F-0189** (Doc Enforcement): Keep "State: partial" — autonomode integration genuinely missing. Clarify what's done vs not.
- Files: `.agentic/spec/FEATURES.md`, acceptance files `F-0179.md`, `F-0189.md`, `F-0190.md`

### 1c. Add drift-check tool (T-0050)
- Script: `.agentic/lib/tools/drift-check.sh` (agent-agnostic — no tool-specific dependencies)
- Compares FEATURES.md status against AC completion (count `- [x]` vs `- [ ]` lines, handle `### AC-` heading format too per gates.py lines 149-153)
- Wire into `ag sync` so it runs on session start
- Warn when: shipped feature has <50% ACs checked, BACKLOG.json diverges from FEATURES.md
- Files: new `drift-check.sh`, modify `sync.sh`

---

## Priority 2: AC Verification Gate (Prevents shipping with 0% ACs checked)

_Moved up from old P5. Small, self-contained, delivers immediate value. Modifying `cmd_done` before the intent journal refactor (old P2) is cleaner than retrofitting after._

### 2a. Add AC completion gate to `ag done`
- Check acceptance file: count `- [x]` vs `- [ ]` (+ `### AC-` heading format)
- <80% checked → warn (advisory) or block (enforce), controlled by existing `acceptance_criteria` setting
- Files: `ag.sh` (`cmd_done` ~line 1072)

### 2b. Add AC summary to dashboard
- "3 shipped features with unchecked ACs" in session start
- Files: `dashboard.sh`

---

## Priority 3: Plan Durability (Low effort, real data loss prevention)

**Problem**: Plans in tool-specific directories are session-scoped. Auto-save only triggers on `ag implement`.

### 3a. Add plan scan to `ag sync`
- Scan **all known tool plan directories** for files mentioning F-XXXX IDs:
  - `~/.claude/plans/` (Claude Code)
  - `.cursor/plans/` (Cursor)
  - Future: configurable via `plan_scan_dirs` in STACK.md
- If found and no `.agentic/journal/plans/F-XXXX-plan.md` exists, auto-copy and notify
- Close T-0047
- Files: `sync.sh`

---

## Priority 4: Instruction File Sync Detection (Prevents recurring "18 stale files" pattern)

**Problem**: Every feature ships code but leaves instruction files stale. No automated detection.

### 4a. Create instruction-sync check
- Script: `.agentic/lib/tools/instruction-sync.sh`
- Parse `ag.sh` case statement for subcommands
- Check each command appears in ALL 8 instruction files (see "Instruction File Propagation" above)
- Report missing commands per file
- Files: new `instruction-sync.sh`

### 4b. Wire into validate_framework.sh and pre-commit
- validate_framework.sh: warning initially, blocking after cleanup
- pre-commit-check.sh: warn if ag.sh changed but instruction files weren't
- Files: `tests/validate_framework.sh`, `.agentic/lib/hooks/pre-commit-check.sh`

---

## Priority 5: Intent Journal + Reconciliation (High impact, replaces imperative wiring)

_Largest piece. Split into 4 PRs (PR 5a–5d) per review recommendation._

**Problem**: `gates.py` and `state_machine.py` exist but are never invoked from CLI workflows. The naive fix (wire `ag transition` calls into `ag.sh`) fails under interruption — if the process dies between step 2 and step 3 of a multi-step operation, state is inconsistent with no recovery.

**Architecture**: Write-ahead log + reconciliation loop (like a database WAL or Kubernetes desired-state controller).

### Prerequisite: Fix state_machine.py idempotency (Critical)

**Problem found in review**: `can_transition()` (state_machine.py lines 280-283) returns `(False, [error])` when already in target state. This means the reconciler would treat "step already completed" as a failure, increment `attempt_count`, and eventually escalate — exactly wrong.

**Fix (two changes in the same file):**

1. Change `can_transition()` lines 280-283 to return `(True, [info])` when `current == target`:

```python
# Before (BROKEN for reconciliation):
if current == target:
    return False, [f"Feature {feature_id} is already in state '{target.value}'"]

# After (idempotent):
if current == target:
    return True, [f"Feature {feature_id} already in state '{target.value}' (no-op)"]
```

2. Add short-circuit in `transition()` itself — without this, the method still calls `check_review()`, `has_pending_review()`, and `feature.sh` for no-ops, producing misleading "Transitioned X: shipped → shipped" log messages:

```python
# In transition(), after can_transition() returns:
if current == target:
    return True, [f"Feature {feature_id} already in state '{target.value}' (no-op)"]
# Skip review checkpoint, file write, and parent recomputation
```

Files: `.agentic/lib/auto/state_machine.py` (two changes, ~6 lines total)

### PR 5a: intents.py module + unit tests (standalone, no wiring)

```python
# Intent entry structure (stored in .agentic/session/intents.json, gitignored)
{
  "feature_id": "F-0042",
  "previous_state": "planned",                    # Captured at write time — enables rollback
  "target_state": "implementing",
  "command": "implement",
  "session_id": "uuid-generated-on-first-write",  # NOT $PPID — see Agent Identity below
  "agent_pid": 12345,                             # $PPID — for orphan detection only
  "worktree": "/abs/path/repo-f-0042",
  "created_at": "2026-03-10T12:00:00Z",
  "gates_passed": ["spec_exists", "acceptance_exists"],
  "steps_completed": ["wip_registered"],
  "steps_remaining": ["create_worktree", "transition_state", "update_status"],
  "attempt_count": 1,
  "error": null
}
```

Functions:
- `write_intent(root, feature_id, target_state, command, steps, session_id, pid, worktree)` — write-ahead, BEFORE any work
- `checkpoint_step(root, feature_id, step_name)` — mark step complete after it succeeds
- `get_pending(root, session_id=None)` — list incomplete intents (filter by session)
- `get_orphaned(root)` — intents where `agent_pid` is dead AND older than 5 minutes
- `clear_intent(root, feature_id)` — remove after all steps done
- `cancel_intent(root, feature_id)` — explicit abort: rolls back `transition_state` steps using `previous_state`, undoes WIP registration and worktree creation, clears intent, logs cancellation
- `adopt_orphans(root, session_id, pid)` — find intents with dead PIDs, update their `session_id` + `agent_pid` to current values
- Use `_with_lock` from `agents_helpers.py` for **all** reads and writes
- Handle corrupt JSON gracefully (follow agents_helpers.py `try/except json.JSONDecodeError` pattern)
- `mkdir -p` on `.agentic/session/` before writing (may not exist in fresh clone)

**Agent Identity** (revised from review):
- Primary identity: `session_id` — a UUID generated on first `write_intent()` call per session, stored in the intent AND in `.agentic/session/.current-session-id`
- `agent_pid` ($PPID) is recorded for **orphan detection only** (is the process still alive?)
- Why: bare `$PPID` fails for manual CLI usage (terminal PID is shared across invocations). UUID is unique per logical session.

**Session ID lifecycle** (addresses recovery paradox from round 2 review):
- **Creation**: First `write_intent()` call generates UUID if `.current-session-id` doesn't exist. Subsequent calls in the same session reuse it.
- **Persistence**: File survives session crashes (that's the point).
- **New session**: Generates a fresh UUID unconditionally (`ag sync` or first `write_intent()`).
- **Recovery via adopt-orphan mechanism**: `ag sync` reconciler detects intents where PID is dead AND `session_id` ≠ current. These are "adoptable orphans." The reconciler **auto-adopts** them into the current session (updates `session_id` + `agent_pid` in the intent), then resumes from `steps_remaining`. This solves the recovery paradox: fresh UUID per session for multi-agent isolation + adoption for crash recovery.
- **Multi-agent safety**: Adoption only happens for intents with dead PIDs. Live agents' intents are never touched.
- **`.gitignore`**: Both `intents.json` and `.current-session-id` must be added to `.agentic/.gitignore` (session-scoped, not tracked).

**Bash→Python handoff**: Bash generates UUID (`uuidgen` or `/proc/sys/kernel/random/uuid`), writes to `.current-session-id`, passes to `intents.py` via `--session-id` flag. Python reads the file as fallback.

**Multi-agent concurrency design:**

| Concern | Solution |
|---------|----------|
| **Storage location** | `.agentic/session/intents.json` in **main repo only** (same as AGENTS.json). Never in worktrees. All agents access via `MAIN_PROJECT_ROOT` discovered through `git rev-parse --git-common-dir`. Session-scoped (lost on fresh clone — correct behavior). |
| **Concurrent writes** | fcntl exclusive file lock (`_with_lock` pattern from agents_helpers.py). One writer at a time; atomic read-modify-write. Note: fcntl locks are per-process, not per-thread — fine for current arch (one agent = one process). |
| **Agent identity** | `session_id` (UUID) for ownership, `agent_pid` for liveness checks. |
| **No cross-agent conflicts** | Each agent works on a different feature in a different worktree. Intents keyed by `feature_id`. Duplicate feature intents → warn + escalate to HUMAN_NEEDED. |
| **FEATURES.md updates** | Each agent updates via `feature.sh` on its own branch. Git merge resolves at PR time. |
| **Stale intent cleanup** | Dead PID + intent older than **5 minutes** → mark orphaned. |
| **Orphan recovery** | `ag sync` auto-adopts orphaned intents into the current session (updates `session_id` + `agent_pid`), then resumes. `ag intent clear F-XXXX` for manual cleanup. `ag implement F-XXXX --force` overrides. |
| **Reconciler scope** | `ag sync` reconciles: (1) intents matching current `session_id`, (2) orphaned intents via adoption. Never touches live agents' intents. |

Files: `.agentic/lib/auto/intents.py`, `tests/test_intents.py`

### PR 5b: Refactor `cmd_implement` to be intent-driven

Extract intent logic into `.agentic/lib/tools/intent-helpers.sh` (sourced by ag.sh, NOT inlined — ag.sh is already 3015 lines).

Refactor `cmd_implement` to:
1. **Write intent** before doing any work
2. **Execute steps**, calling `checkpoint_step` after each succeeds
3. **Clear intent** on completion

Steps for `ag implement F-XXXX`:
1. `write_intent` → 2. `register_wip` → 3. `create_worktree` → 4. `transition_state` → 5. `update_status` → 6. `clear_intent`

**Step granularity note** (from review): For `cmd_implement`, a coarser intent ("mark as implementing") would suffice since most steps are already idempotent. However, using the same fine-grained pattern as `cmd_done` keeps the system uniform and the reconciler simple.

Each step is idempotent:
- `register_wip` — AGENTS.json upsert (via `_find_by_feature`)
- `create_worktree` — worktree.sh checks `if [[ -d "$worktree_path" ]]` and returns 0
- `transition_state` — idempotent after the state_machine.py fix above
- `advance_backlog` — backlog_helpers.py `done()` checks current position

**`state_enforcement` modes** (controlled by STACK.md setting):
- `off` (discovery default): Intent journal provides crash recovery for existing operations (WIP registration, worktree creation, etc.). State machine transitions are **completely skipped** — no `transition()` calls at all.
- `advisory` (formal default): Intent journal + state machine transitions run, but gate failures produce **warnings** (logged, don't block). Feature status is updated regardless.
- `blocking`: Intent journal + state machine transitions run, gate failures **block** the operation. Feature cannot advance without passing all gates.

Files: `.agentic/lib/tools/intent-helpers.sh` (new), `.agentic/lib/tools/ag.sh` (modify `cmd_implement`)

### PR 5c: Refactor `cmd_done` to be intent-driven

**Important distinction**: This PR separates TWO concerns:
1. **Reliability** (crash recovery): Wrapping existing `cmd_done` steps in intent checkpoints so interrupted work can resume
2. **Behavioral change** (state enforcement): Wiring `state_machine.transition()` calls that `cmd_done` never had before

Concern 1 ships unconditionally. Concern 2 is gated behind `state_enforcement: blocking` — advisory mode skips state transitions but still uses the intent journal for crash recovery.

Steps for `ag done F-XXXX`:
1. `write_intent` → 2. `generate_manifest` → 3. `check_drift` → 4. `check_ac_completion` (P2 gate) → 5. `transition(verified)` [if blocking] → 6. `transition(documented)` [if blocking] → 7. `transition(committed)` [if blocking] → 8. `transition(shipped)` [if blocking] → 9. `complete_wip` → 10. `advance_backlog` → 11. `clear_intent`

If process dies after step 6, feature is "documented" and the reconciler picks up from step 7.

**Reconciler re-validation**: Before resuming, the reconciler must:
1. Re-read current feature state (may have changed since intent was written)
2. Validate the intended transition is still valid (e.g., feature wasn't manually deprecated)
3. If current state has advanced past the intended step, skip it (don't regress)

Files: `.agentic/lib/tools/intent-helpers.sh`, `.agentic/lib/tools/ag.sh` (modify `cmd_done`)

### PR 5d: Reconciler in `ag sync` + abort path + integration tests

New phase in sync.sh: `phase_intents()`

```bash
phase_intents() {
    local session_id
    session_id=$(cat "$MAIN_PROJECT_ROOT/.agentic/session/.current-session-id" 2>/dev/null)

    # Phase 1: Adopt orphaned intents (dead PID, different session)
    # This is the crash recovery mechanism — previous session's work gets adopted
    local orphans=$(python3 "$LIB_DIR/auto/intents.py" \
        --project-root "$MAIN_PROJECT_ROOT" \
        get-orphaned 2>/dev/null)

    if [ -n "$orphans" ]; then
        echo "⚠️  Found interrupted work from crashed session:"
        echo "$orphans"
        # Auto-adopt: update session_id + agent_pid in orphaned intents
        python3 "$LIB_DIR/auto/intents.py" \
            --project-root "$MAIN_PROJECT_ROOT" \
            adopt-orphans --session-id "${session_id:-$(uuidgen)}" --pid "$PPID"
        # Refresh session_id after potential generation
        session_id=$(cat "$MAIN_PROJECT_ROOT/.agentic/session/.current-session-id" 2>/dev/null)
    fi

    [ -z "$session_id" ] && return 0  # No session ID = nothing to reconcile

    # Phase 2: Reconcile current session's pending intents
    local pending=$(python3 "$LIB_DIR/auto/intents.py" \
        --project-root "$MAIN_PROJECT_ROOT" \
        get-pending --session-id "$session_id" 2>/dev/null)

    if [ -n "$pending" ]; then
        echo "⚠️  Resuming interrupted work:"
        echo "$pending"
        # Re-read current feature state (may have changed)
        # Validate intended transition is still valid
        # Skip steps where state already advanced past target
        # Execute remaining steps
        # On failure: increment attempt_count, escalate after 3
    fi
}
```

**Abort path** (new `ag intent` subcommand):
- `ag intent list` — show all intents (current session + orphaned)
- `ag intent clear F-XXXX` — cancel intent and undo completed steps (delete worktree, unregister WIP)
- `ag intent clear --all` — clear all orphaned intents
- These commands are agent-agnostic (shell scripts, work in any tool)

**Retry & escalation:**
- Retry budget: 3 failures → escalate to HUMAN_NEEDED.md
- Staleness: intents older than 7 days → warn user
- Orphan threshold: PID dead + 5 minutes → show but don't auto-resume
- Gate failure types: retryable (transient — file not found, lock contention) vs permanent (state changed, feature deprecated). Permanent failures escalate immediately.

**Error surfacing:**
- Warnings printed to stdout during `ag sync` (visible in any tool)
- Persistent escalations written to HUMAN_NEEDED.md (survives across sessions)
- No tool-specific error channels

**Integration tests:**
- Test that incomplete intents survive process death (write intent, skip steps, run reconciler)
- Test that gate re-validation catches changed conditions (feature deprecated between intent write and resume)
- Test retry budget and HUMAN_NEEDED escalation
- Test concurrent agents: two agents write intents for different features simultaneously (lock contention)
- Test orphan detection: write intent with dead PID, verify reconciler flags it after 5 min
- Test session isolation: agent with session A can't reconcile session B's intents
- Test `ag intent clear` undoes completed steps correctly
- Test corrupt intents.json (malformed JSON) doesn't crash — falls back to empty
- Test intents.json directory auto-creation (`.agentic/session/` may not exist)
- Unit tests for `intents.py` functions in isolation (write, checkpoint, clear, get_pending)

Files: `sync.sh`, `ag.sh` (add `cmd_intent`), `.agentic/lib/tools/intent-helpers.sh`, `tests/test_intents.py`, `tests/validate_framework.sh`

### PR 5e: STACK.md setting + instruction file updates + migration

- Add `state_enforcement: off` setting to STACK.md (with profile defaults: discovery=off, formal=advisory)
- Update ALL instruction files per "Instruction File Propagation" list above:
  - Add `ag intent` to quick commands in all 4 templates (CLAUDE.md, cursorrules, copilot, codex)
  - Add intent/reconciliation workflow to auto_orchestration.md
  - Add recovery trigger words to memory-seed.md
  - Update DEVELOPER_GUIDE.md with intent system documentation
  - Update agent_operating_guidelines.md
  - Update HOW_IT_WORKS.md
  - Update `session-start` and `completing-work` skills to reference `ag intent`

**Migration path for existing projects** (add to `upgrade.sh`):
- Add `intents.json` and `.current-session-id` to `.agentic/.gitignore`
- Add `state_enforcement` setting to STACK.md (default based on profile)
- `mkdir -p .agentic/session` if not exists
- No data migration needed — intents.json starts empty

Files: STACK.md template, all instruction file templates, DEVELOPER_GUIDE.md, HOW_IT_WORKS.md, upgrade.sh, `.agentic/.gitignore`

---

## Priority 6: Backlog (Track for later)

| Item | Issue | Action |
|------|-------|--------|
| T-0023 | memory-check.sh broken in worktrees | Fix path resolution |
| T-0045 | Feature ID collisions | Add collision detection to feature.sh |
| ag.sh >3015 lines | Maintainability | Split into subcommand files (partially addressed by intent-helpers.sh extraction) |
| F-0189 autonomode | Doc enforcement incomplete | Complete when autonomode ships |
| intents.json growth | Performance | Add compaction if >50 intents (purge cleared/orphaned older than 30 days) |

---

## Implementation Order

**P1** (registry cleanup) → **P2** (AC gate) → **P3** (plan durability) → **P4** (instruction sync) → **P5a-e** (intent journal, 5 PRs)

```
PR 1:  P1 + P2 — Registry cleanup + AC verification gate (small, no overlap)
PR 2:  P3 — Plan scan in ag sync (tiny, closes T-0047)
PR 3:  P4 — instruction-sync.sh + validate_framework wiring
PR 4:  P5-prereq + P5a — state_machine.py idempotency fix + intents.py module + unit tests
PR 5:  P5b — cmd_implement intent-driven + intent-helpers.sh
PR 6:  P5c — cmd_done intent-driven (reliability + gated behavioral change)
PR 7:  P5d + P5e — Reconciler + ag intent commands + integration tests + instruction file updates + migration
```

**Rationale** (from two review rounds):
- PRs 1+2 merged: Both small, different files, no overlap. Saves a review cycle.
- PRs 5-prereq+5a merged: 6-line fix + new module that depends on it. Natural unit.
- PRs 5d+5e merged: Reconciler + instruction updates are the "wiring" phase — shipping them together ensures `ag intent` is documented the moment it's available.
- P2 (AC gate) before P5 (intent journal): P2 prevents the most common failure mode immediately. Modifying `cmd_done` before P5's refactor is cleaner than retrofitting after.
- P5 core split (module → cmd_implement → cmd_done → reconciler) preserved: each is independently testable.
- Each PR: bumps VERSION (post-merge via `ag done`), updates CONTRIBUTIONS.md

---

## Verification

After implementing all priorities:
1. `bash tests/validate_framework.sh` — must pass
2. `ag sync` — drift-check, plan scan, and phase_intents produce output
3. Simulate interruption: write intent, kill process, run `ag sync` — reconciler resumes
4. `ag done` on feature with unchecked ACs — warns/blocks
5. Add new `ag` subcommand, run instruction-sync — reports missing entries
6. `ag transition F-XXXX shipped` on planned feature — rejected by gates
7. `ag intent list` — shows current and orphaned intents
8. `ag intent clear F-XXXX` — cleans up and undoes partial work
9. All `ag` commands work from Cursor/Copilot/Codex (no Claude-specific dependency)

---

## Review Findings Addressed

### Round 1

| Finding | Resolution | Section |
|---------|------------|---------|
| state_machine.transition() not idempotent | Fix in can_transition() + short-circuit in transition() | P5-prereq |
| P2 conflates reliability + behavioral change | Separated: reliability unconditional, transitions gated by state_enforcement (off/advisory/blocking) | P5c |
| ag.sh 3015 lines + P2 adds more | Extract to intent-helpers.sh (sourced, not inlined) | P5b |
| No abort/cancel path | `ag intent clear F-XXXX` + undo via `previous_state` | P5d |
| PID-based identity fails for manual CLI | UUID session_id for ownership, PID for liveness only | P5a |
| 30 min orphan timeout too long | Reduced to 5 min + `--force` override | P5a |
| Priority reordering | P1→P2(AC)→P3→P4→P5(intents) | Implementation Order |
| P2 split | 5 PRs (consolidated to 7 total) | P5a–P5e |
| Agent-agnostic design | All logic in .agentic/lib/, instruction propagation checklist, multi-tool plan scan | Design Principles |
| Instruction file updates | Explicit list of 8+ files, dedicated PR | Design Principles + P5e |

### Round 2

| Finding | Resolution | Section |
|---------|------------|---------|
| Session ID recovery paradox (new session can't find old intents) | Adopt-orphan mechanism: `ag sync` auto-adopts dead-PID intents into current session | P5d reconciler |
| `transition()` still logs misleading messages after `can_transition()` fix | Added short-circuit in `transition()` before review checkpoint | P5-prereq |
| No `previous_state` in intent schema (can't rollback) | Added `previous_state` field, captured at write time | P5a schema |
| `.gitignore` missing entries | Added to P5e migration path | P5e |
| UUID gen + bash→python handoff unspecified | Bash generates, writes file, passes via `--session-id` flag | P5a identity |
| No migration path for existing projects | Added to upgrade.sh in P5e | P5e |
| Three-mode distinction conflated (off/advisory/blocking) | Clarified: off=skip transitions, advisory=warn, blocking=block | P5b |
| PR count (10 → 7) | Merged: P1+P2, prereq+5a, 5d+5e | Implementation Order |
| `ag flush --features` may capture partial transitions | Documented as known behavior (idempotent steps handle it) | Noted |
| `ag intent clear` fails if CD'd in worktree | Warn user + ask to cd out | P5d |
