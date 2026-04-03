# Prioritized Framework Reliability Fix Plan

## Context

March 2026 conversation history analysis revealed systemic reliability gaps: features marked "shipped" with unchecked acceptance criteria, state machine gates that exist but are never invoked from CLI workflows, no tooling to detect instruction file staleness, and FEATURES.md status diverging from actual implementation state.

**Meta-problem**: Behavioral enforcement (instructions to agents) fails; only architectural enforcement (code) works reliably. Specifically, imperative "script A calls script B" sequences are fragile — work gets interrupted (token limits, agent death, user closes session), leaving state half-updated with no recovery path.

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
- Script: `.agentic/lib/tools/drift-check.sh`
- Compares FEATURES.md status against AC completion (count `- [x]` vs `- [ ]` lines, handle `### AC-` heading format too per gates.py lines 149-153)
- Wire into `ag sync` so it runs on session start
- Warn when: shipped feature has <50% ACs checked, BACKLOG.json diverges from FEATURES.md
- Files: new `drift-check.sh`, modify `sync.sh`

---

## Priority 2: Intent Journal + Reconciliation (High impact, replaces imperative wiring)

**Problem**: `gates.py` and `state_machine.py` exist but are never invoked from CLI workflows. The naive fix (wire `ag transition` calls into `ag.sh`) fails under interruption — if the process dies between step 2 and step 3 of a multi-step operation, state is inconsistent with no recovery.

**Architecture**: Write-ahead log + reconciliation loop (like a database WAL or Kubernetes desired-state controller).

### 2a. Create intents module: `.agentic/lib/auto/intents.py`

```python
# Intent entry structure (stored in .agentic/session/intents.json, gitignored)
{
  "feature_id": "F-0042",
  "target_state": "implementing",
  "command": "implement",
  "agent_pid": 12345,              # $PPID — identifies which agent owns this intent
  "worktree": "/abs/path/repo-f-0042",  # where this agent is working
  "created_at": "2026-03-10T12:00:00Z",
  "gates_passed": ["spec_exists", "acceptance_exists"],
  "steps_completed": ["wip_registered"],
  "steps_remaining": ["create_worktree", "transition_state", "update_status"],
  "attempt_count": 1,
  "error": null
}
```

Functions:
- `write_intent(root, feature_id, target_state, command, steps, pid, worktree)` — write-ahead, BEFORE any work
- `checkpoint_step(root, feature_id, step_name)` — mark step complete after it succeeds
- `get_pending(root, pid=None)` — list incomplete intents (optionally filter by agent PID)
- `clear_intent(root, feature_id)` — remove after all steps done
- Use `_with_lock` from `agents_helpers.py` for **all** reads and writes (fcntl exclusive lock)

**Multi-agent concurrency design:**

| Concern | Solution |
|---------|----------|
| **Storage location** | `.agentic/session/intents.json` in **main repo only** (same as AGENTS.json). Never in worktrees. All agents access via `MAIN_PROJECT_ROOT` discovered through `git rev-parse --git-common-dir`. |
| **Concurrent writes** | fcntl exclusive file lock (`_with_lock` pattern from agents_helpers.py). One writer at a time; atomic read-modify-write. |
| **Agent identity** | Each intent records `agent_pid` ($PPID) and `worktree` path. Agents only reconcile their own intents (filter by PID). |
| **No cross-agent conflicts** | Each agent works on a different feature in a different worktree. Intents are keyed by `feature_id` — no two agents should have intents for the same feature. If they do (error), the reconciler warns and escalates to HUMAN_NEEDED. |
| **FEATURES.md updates** | Each agent updates FEATURES.md on its own branch via `feature.sh`. No file-level locking needed — git merge resolves conflicts at PR time (existing pattern). `feature.sh` only changes the status line, so non-overlapping feature edits never conflict. |
| **Stale intent cleanup** | Follow agents_helpers.py stale detection: check if `agent_pid` is alive (`os.kill(pid, 0)`). Dead PID + intent older than 30 min → mark as orphaned, warn user on next `ag sync`. Don't auto-resume orphaned intents without human confirmation. |
| **Reconciler scope** | `ag sync` only reconciles intents belonging to the **current agent** (match by PID). It never touches another agent's intents. This prevents Agent A from resuming Agent B's half-done work on a different worktree. |

### 2b. Make ag.sh commands intent-driven

Refactor `cmd_implement` and `cmd_done` to:
1. **Write intent** before doing any work (write-ahead log)
2. **Execute steps**, calling `checkpoint_step` after each succeeds
3. **Clear intent** on completion

Each step must be **idempotent** (running it twice = same result as once):
- `register_wip` — AGENTS.json upsert (already idempotent via `_find_by_feature`)
- `create_worktree` — worktree.sh already checks if exists
- `transition_state` — `feature.sh` setting same status twice is a no-op
- `advance_backlog` — backlog_helpers.py `done()` checks current position

For `ag done F-XXXX` (multi-transition):
1. generate_manifest → 2. check_drift → 3. transition(verified) → 4. transition(documented) → 5. transition(committed) → 6. transition(shipped) → 7. complete_wip → 8. advance_backlog → 9. clear_intent

If process dies after step 4, feature is "documented" and the reconciler picks up from step 5.

**Worktree awareness in ag.sh**: `cmd_implement` and `cmd_done` already use `MAIN_PROJECT_ROOT` for AGENTS.json access. Intent writes go to the same location. The `checkpoint_step` calls use the main repo path, not the worktree path.

### 2c. Add reconciler to `ag sync`

New phase in sync.sh: `phase_intents()`

```bash
phase_intents() {
    local my_pid=$PPID
    # Get pending intents for THIS agent only
    local pending=$(python3 "$LIB_DIR/auto/intents.py" \
        --project-root "$MAIN_PROJECT_ROOT" \
        get-pending --pid "$my_pid" 2>/dev/null)

    if [ -n "$pending" ]; then
        echo "⚠️  Found interrupted work from previous session:"
        echo "$pending"
        # Re-validate gates before resuming
        # Execute remaining steps
        # On failure: increment attempt_count, escalate after 3
    fi

    # Also check for orphaned intents (dead PIDs, not ours)
    local orphans=$(python3 "$LIB_DIR/auto/intents.py" \
        --project-root "$MAIN_PROJECT_ROOT" \
        get-orphaned 2>/dev/null)

    if [ -n "$orphans" ]; then
        echo "⚠️  Found orphaned intents from dead agents:"
        echo "$orphans"
        echo "   Run 'ag intent cleanup' to clear, or investigate first."
    fi
}
```

- Retry budget: after 3 failures, escalate to HUMAN_NEEDED.md
- Staleness: intents older than 7 days → warn user
- Orphan detection: PID dead + heartbeat expired → show but don't auto-resume
- Files: `sync.sh`, new `intents.py`

### 2d. Advisory vs blocking mode decision
- **Advisory**: `ag plan` → specced, `ag implement` → implementing (low-risk state updates)
- **Blocking**: `ag done` → shipped chain (critical path where skipping gates caused the problems we found)
- Configurable via `state_enforcement` setting in STACK.md: `advisory` (default) | `blocking`

### 2e. Integration tests
- Test that incomplete intents survive process death (write intent, skip steps, run reconciler)
- Test that gate re-validation catches changed conditions
- Test retry budget and HUMAN_NEEDED escalation
- Test concurrent agents: two agents write intents for different features simultaneously (lock contention)
- Test orphan detection: write intent with dead PID, verify reconciler flags it
- Test worktree isolation: agent in worktree A can't reconcile agent B's intents
- Files: `tests/test_intents.py`, `tests/validate_framework.sh`

Key files:
- `.agentic/lib/auto/intents.py` (new — follow `agents_helpers.py` patterns for locking, PID, paths)
- `.agentic/lib/auto/state_machine.py` (existing, `transition()` method called by reconciler)
- `.agentic/lib/auto/gates.py` (existing, gate functions called by reconciler)
- `.agentic/lib/tools/ag.sh` (modify `cmd_implement` ~line 772, `cmd_done` ~line 1065)
- `.agentic/lib/tools/sync.sh` (add `phase_intents()`)
- `.agentic/lib/tools/agents_helpers.py` (reuse `_with_lock`, `_is_pid_alive`, path discovery patterns)
- `.agentic/lib/paths.sh` (existing `MAIN_PROJECT_ROOT` discovery — all intent access goes through this)

---

## Priority 3: Plan Durability (Low effort, real data loss prevention)

**Problem**: Plans in `~/.claude/plans/` are session-scoped. Auto-save only triggers on `ag implement`.

### 3a. Add plan scan to `ag sync`
- Scan `.claude/plans/` and `.cursor/plans/` for files mentioning F-XXXX IDs
- If found and no `.agentic/journal/plans/F-XXXX-plan.md` exists, auto-copy and notify
- Close T-0047
- Files: `sync.sh`

---

## Priority 4: Instruction File Sync Detection (Prevents recurring "18 stale files" pattern)

**Problem**: Every feature ships code but leaves instruction files stale. No automated detection.

### 4a. Create instruction-sync check
- Script: `.agentic/lib/tools/instruction-sync.sh`
- Parse `ag.sh` case statement for subcommands
- Check each command appears in: CLAUDE.md template, .cursorrules template, copilot-instructions, codex instructions, memory-seed.md, auto_orchestration.md
- Report missing commands per file
- Files: new `instruction-sync.sh`

### 4b. Wire into validate_framework.sh and pre-commit
- validate_framework.sh: warning initially, blocking after cleanup
- pre-commit-check.sh: warn if ag.sh changed but instruction files weren't
- Files: `tests/validate_framework.sh`, `.agentic/lib/hooks/pre-commit-check.sh`

---

## Priority 5: AC Verification Gate (Prevents shipping with 0% ACs checked)

### 5a. Add AC completion gate to `ag done`
- Check acceptance file: count `- [x]` vs `- [ ]` (+ `### AC-` heading format)
- <80% checked → warn (advisory) or block (enforce)
- Files: `ag.sh` (done command ~line 1065)

### 5b. Add AC summary to dashboard
- "3 shipped features with unchecked ACs" in session start
- Files: `dashboard.sh`

---

## Priority 6: Backlog (Track for later)

| Item | Issue | Action |
|------|-------|--------|
| T-0023 | memory-check.sh broken in worktrees | Fix path resolution |
| T-0045 | Feature ID collisions | Add collision detection to feature.sh |
| ag.sh >2100 lines | Maintainability | Split into subcommand files |
| F-0189 autonomode | Doc enforcement incomplete | Complete when autonomode ships |

---

## Verification

After implementing priorities 1-5:
1. `bash tests/validate_framework.sh` — must pass
2. `ag sync` — drift-check and plan scan produce output
3. Simulate interruption: write intent, kill process, run `ag sync` — reconciler resumes
4. `ag done` on feature with unchecked ACs — warns/blocks
5. Add new `ag` subcommand, run instruction-sync — reports missing entries
6. `ag transition F-XXXX shipped` on planned feature — rejected by gates

## Implementation Order

**P1** (registry cleanup) → **P2** (intent journal) → **P3** (plan durability) → **P4** (instruction sync) → **P5** (AC gate)

Each priority = one PR. P2 is the largest; consider splitting into 2a-2c (core module + sync wiring) and 2d-2e (mode config + tests). Every PR bumps VERSION and updates CONTRIBUTIONS.md.
