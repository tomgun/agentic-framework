# Plan: Roadmap/Backlog — Structural Work Assignment

## Context

**The Problem**: When a human assigns work, it gets lost between sessions. Agents drift. The framework has no structural mechanism for "here's what to work on, in this order."

**Key requirement** (from user): "It doesn't matter which agent I run locally or on another computer — if local git is up to date, the agents should know what to do next."

**Design insight**: No separate "focus lock." The backlog IS the focus. Position 0 = what's being worked on right now. One concept, one file, one source of truth.

---

## Design: The Backlog

### `.agentic/BACKLOG.json` — git-tracked, ordered queue

```json
[
  {
    "type": "feature",
    "id": "F-0200",
    "description": "Phase 1: State machine blast radius update",
    "added_at": "2026-03-08T14:30:00Z",
    "became_current_at": "2026-03-08T14:30:00Z",
    "added_by": "human",
    "refs": [
      ".agentic/journal/plans/2026-03-08-ADR-001-roadmap.md",
      ".agentic/spec/adr/ADR-001-multi-component-architecture.md"
    ],
    "notes": "Focus on blast radius analysis only. See ADR-001 Section 5."
  },
  {
    "type": "feature",
    "id": "F-0201",
    "description": "Phase 2: Components as metadata",
    "added_at": "2026-03-08T14:30:00Z",
    "added_by": "human",
    "refs": [".agentic/journal/plans/2026-03-08-ADR-001-roadmap.md"],
    "depends_on": ["F-0200"]
  },
  {
    "type": "task",
    "description": "Research caching strategies for API layer",
    "added_at": "2026-03-08T14:31:00Z",
    "added_by": "human",
    "notes": "Compare Redis vs in-memory. Check STACK.md constraints."
  }
]
```

- **Git-tracked** — survives across sessions, machines, agents. `git pull` → everyone knows what's next.
- **Position 0 = current work** — the first item is what you should be doing right now.
- **JSON** — machine-readable, enforced by code. Agents don't need to "remember" to read it.
- **Unified schema** — every item has `type` (`"feature"` or `"task"`). Features have `id`; tasks have only `description`. One array, one shape per type.
- **`became_current_at`** — set when an item reaches position 0 (not `added_at`, which fires false positives for batch-queued items). Used for staleness detection.
- **`refs`** (optional) — array of file paths the agent should read when starting this item. Plans, ADRs, specs, related code. Shown at `ag start` and when `ag implement` begins. Auto-populated: `backlog.sh add F-XXXX` auto-discovers plan (`plans/F-XXXX-plan.md`) and acceptance criteria (`spec/acceptance/F-XXXX.md`) if they exist.
- **`notes`** (optional) — free-text human context. Scope hints, constraints, "talk to DevOps first", etc. Shown prominently at session start.
- **`depends_on`** (optional) — array of IDs this item can't start until completed. E.g., `["F-0200"]` means "F-0200 must be done first." Only one direction stored; the reverse ("blocks") is computed dynamically by `backlog_helpers.py` when displaying. This keeps a single source of truth and prevents drift.
- **Empty array or no file = no assignment** — all commands work normally, no constraints applied. `ag implement` auto-upserts (see gates below).

### New Tool: `backlog.sh`

At `.agentic/lib/tools/backlog.sh`. Manages the queue.

| Command | What It Does |
|---------|-------------|
| `backlog.sh add F-XXXX [--desc "text"] [--position N] [--ref path] [--note "text"]` | Add feature item. Default: append. `--position 0` = current. Auto-discovers plan + acceptance criteria files. `--ref` adds extra refs. Validates feature exists in FEATURES.md. |
| `backlog.sh add --task "Research X" [--position N] [--ref path] [--note "text"]` | Add non-feature task item. Same positioning/ref rules. |
| `backlog.sh current` | Print position 0 (current work item). Exit 1 if empty. |
| `backlog.sh next` | Print position 1 (what's after current). |
| `backlog.sh done` | Remove position 0. Position 1 becomes new current. |
| `backlog.sh list` | Print full backlog with positions. |
| `backlog.sh remove F-XXXX` | Remove specific item by ID. |
| `backlog.sh move F-XXXX N` | Move item to position N. |
| `backlog.sh clear` | Empty the backlog. |

### Structural Gates

**`ag start` (cmd_start)** — Shows position 0 PROMINENTLY with context:
```
═══════════════════════════════════════
  CURRENT: F-0200 — Phase 1: State machine blast radius
  NOTE:    Focus on blast radius analysis only. See ADR-001 Section 5.
  REFS:    .agentic/journal/plans/2026-03-08-ADR-001-roadmap.md
           .agentic/spec/adr/ADR-001-multi-component-architecture.md
  NEXT:    F-0201 — Phase 2: Components as metadata
  Queue:   3 items total
  Resume:  ag implement F-0200
═══════════════════════════════════════
```
Notes and refs give the agent immediate context — no hunting through the repo to find the relevant plan or understand scope constraints.

**`ag implement F-XXXX` (cmd_implement)** — Checks AND auto-upserts backlog:
- If backlog empty or F-XXXX not in backlog: **auto-adds F-XXXX at position 0** with auto-discovered refs (plan file, acceptance criteria). The backlog IS the focus — implementing a feature means it's your current work.
- If F-XXXX = position 0: proceeds (correct work)
- If F-XXXX ≠ position 0: **HARD BLOCK** (exit 1)
```
BLOCKED: Backlog says current work is F-0200.
  Work on it:  ag implement F-0200
  Reprioritize: ag backlog move F-XXXX 0
  Override:     SKIP_BACKLOG=1 ag implement F-XXXX
```
Also validates:
- **State machine**: if F-XXXX is `shipped`/`deprecated`, warns and blocks.
- **Dependencies**: if F-XXXX has `depends_on` items still in the backlog (not yet done), **ADVISORY WARNING** (not hard block — human may know better):
```
WARNING: F-0201 depends on F-0200 (still in backlog).
  Work on dependency first: ag implement F-0200
  Proceed anyway:           (continue)
```

**`ag work "desc"` (cmd_work)** — **HARD BLOCK** only if backlog has feature items AND project uses `feature_tracking=yes` (from STACK.md). Discovery-profile projects or backlogs with only task items are not blocked:
```
BLOCKED: Backlog has feature work queued (current: F-0200).
  Work on it: ag implement F-0200
  Clear:      ag backlog clear
```

**`ag done F-XXXX` (cmd_done)** — After completion, auto-advances backlog:
```
F-0200 complete.
Backlog advanced — next up: F-0201 (Phase 2: Components as metadata)
  Start: ag implement F-0201
```

**`ag plan F-YYYY` / `ag spec F-YYYY`** — **ADVISORY WARNING** if F-YYYY ≠ position 0.

**`ag auto crunch`** — Processes backlog items in order (not FEATURES.md scan).

**`ag auto task`** — Works on position 0.

### Escape Hatch

`SKIP_BACKLOG=1` env var overrides the hard block. Logged to stderr.

### Backlog + WIP Relationship

- **Backlog**: "What should I work on?" (project-level, git-tracked, ordered queue)
- **WIP**: "Am I in the middle of writing code?" (session-level, gitignored, crash recovery)

`ag implement F-XXXX` creates WIP (as it does today). The backlog is the WHY (human intent), WIP is the HOW (code-in-progress state).

### `ag backlog` Command

New top-level command in ag.sh:

```
ag backlog                    # Show current + next (with notes/refs/deps)
ag backlog list               # Show full queue with dependency graph
ag backlog add F-XXXX         # Append to queue (auto-discovers refs)
ag backlog add F-XXXX -p 0    # Make it current (top of queue)
ag backlog add F-XXXX --dep F-0200  # Add with dependency
ag backlog done               # Remove position 0, advance (skips items with unmet deps)
ag backlog move F-XXXX 0      # Reprioritize to top
ag backlog remove F-XXXX      # Remove from queue
ag backlog clear              # Empty queue
```

`backlog list` shows dependencies inline:
```
[0] F-0200 — Phase 1: State machine blast radius  ← CURRENT
[1] F-0201 — Phase 2: Components as metadata  (depends: F-0200)
[2] Research caching strategies  (task)
```

### Cross-Machine Flow

```
Machine A (human):
  $ ag backlog add F-0200 --desc "Phase 1: State machine" -p 0
  $ ag backlog add F-0201 --desc "Phase 2: Components"
  $ ag backlog add F-0202 --desc "Phase 3: Review checkpoints"
  $ git add .agentic/BACKLOG.json && git commit && git push

Machine B (any agent):
  $ git pull
  $ ag start
    CURRENT: F-0200 — Phase 1: State machine
    NEXT:    F-0201 — Phase 2: Components
    Queue:   3 items total
  $ ag implement F-0200   # proceeds
  $ ag implement F-0201   # BLOCKED
```

### Multi-Agent Safety

- **Same machine**: WIP.md prevents concurrent implementation. Backlog is read-only during work.
- **Worktrees**: Each worktree sees the same BACKLOG.json (git-tracked = shared). This is CORRECT — the backlog is project-level intent. WIP.md (gitignored) provides per-worktree session isolation.
- **MCP (future)**: MCP server wraps backlog with atomic claim/release operations.

### Staleness Detection

At `ag start`, if position 0's `became_current_at` > 7 days old:
```
WARNING: Current backlog item has been active for 12 days (F-0200)
  Still relevant? Or: ag backlog done | ag backlog clear
```
Uses `became_current_at` (not `added_at`) — items batch-queued weeks ago shouldn't trigger warnings until they actually become current work.

### Worktree Concurrency Limitation

**Phase 1 limitation**: Two agents in separate worktrees can both read BACKLOG[0] and attempt the same feature. WIP.md (gitignored, per-worktree) prevents concurrent code edits, but both agents see themselves as "assigned" to the same item. This is a known limitation.

**Mitigation**: Document that single-agent-per-backlog is the supported model in Phase 1. Phase 6 (MCP server) adds atomic claim/release to support true multi-agent dispatch.

---

## Files to Modify/Create

### Core (Phase 1)

| Action | File | Change |
|--------|------|--------|
| NEW | `.agentic/lib/tools/backlog.sh` | Backlog shell wrapper (dispatches to backlog_helpers.py) |
| NEW | `.agentic/lib/tools/backlog_helpers.py` | Python JSON manipulation (add/remove/move/list/current/done). Bash does CLI + output formatting; Python does JSON read/write. Avoids fragile jq expressions. |
| MODIFY | `.agentic/lib/paths.sh` | Add `BACKLOG_FILE` path |
| MODIFY | `.agentic/lib/tools/ag.sh` | Add `ag backlog` dispatch; add backlog gates to `cmd_start`, `cmd_implement`, `cmd_work`, `cmd_done`, `cmd_auto`; advisory warnings on `cmd_plan`, `cmd_spec` |

### Integration (Phase 2)

| Action | File | Change |
|--------|------|--------|
| MODIFY | `.agentic/lib/auto/crunch.py` | Use backlog order in `_read_planned_features()` |
| MODIFY | `.agentic/lib/auto/task.py` | Validate against backlog position 0 |
| MODIFY | `.agentic/lib/tools/journal.sh` | Update "Next steps" hint to reference backlog |
| MODIFY | Instruction files (routing rules) | Add `ag backlog add` to "Where to log things" table |

**Phase 1: 4 files. Phase 2: 4+ files. Two commits.**

### Follow-Up (Separate PRs — NOT in this PR)

| Action | File | Change |
|--------|------|--------|
| MODIFY | `.agentic/lib/init/STATUS.template.md` | Simplify "Current focus"/"Next up" — reference backlog |
| MODIFY | `.agentic/lib/tools/status.sh` | Sync `status.sh focus` with BACKLOG[0] or deprecate |

---

## Execution Order

### Phase 0: Spec First (before any code)
0. Add FEATURES.md entry for this feature + create acceptance criteria file in `spec/acceptance/`

### Phase 1: Core
1. Add `BACKLOG_FILE` to `paths.sh`
2. Create `backlog_helpers.py` — Python JSON manipulation (add/remove/move/list/current/done/clear)
3. Create `backlog.sh` — shell wrapper calling backlog_helpers.py, handles CLI parsing + output formatting
4. Add `ag backlog` dispatch in ag.sh
5. Add backlog display to `cmd_start()` — show current + next prominently
6. Add backlog gate to `cmd_implement()` — hard block if wrong item, auto-upsert if not in backlog
7. Add backlog gate to `cmd_work()` — hard block if backlog has feature items (only when `feature_tracking=yes`)
8. Add `backlog.sh done` call to `cmd_done()` — auto-advance (sets `became_current_at` on new position 0)

**CHECKPOINT**: `ag backlog add F-0200 -p 0` → `ag implement F-0201` → BLOCKED.

### Phase 2: Integration + Tests
9. Add advisory warnings to `cmd_plan()`, `cmd_spec()`
10. Modify `crunch.py._read_planned_features()` — use backlog order
11. Modify `task.py` — validate against position 0
12. Add backlog gate to `cmd_auto()`
13. Add staleness detection (using `became_current_at`)
14. Add structural tests to `validate_framework.sh`
15. Update session_start.md, session-start SKILL.md
16. Update memory-seed.md: "backlog/queue/next" triggers → `ag backlog`
17. Update CLAUDE.md template

---

## Verification

1. **Add test**: `ag backlog add F-0200 -p 0` → BACKLOG.json created with F-0200 at position 0
2. **Block test**: `ag implement F-0201` with F-0200 at position 0 → BLOCKED (exit 1)
3. **Correct item test**: `ag implement F-0200` → proceeds normally
4. **Display test**: `ag start` → shows current + next from backlog
5. **Done + advance test**: `ag done F-0200` → backlog advances, shows F-0201 as new current
6. **Escape hatch**: `SKIP_BACKLOG=1 ag implement F-0201` → proceeds with warning
7. **Empty backlog**: No BACKLOG.json → all commands work normally (no constraint)
8. **Cross-machine**: Create backlog → commit → clone elsewhere → `ag start` shows same backlog
9. **Autonomous**: `crunch.py` with backlog → processes items in backlog order
10. **Advisory**: `ag plan F-0201` with F-0200 current → warning (not block)
11. **Staleness**: Old `became_current_at` → warning at `ag start`
12. **Profile-aware work gate**: `ag work "desc"` with backlog containing only task items → NOT blocked (task items don't prevent ad-hoc work)
13. **Auto-upsert test**: `ag implement F-0300` with empty backlog → F-0300 auto-added at position 0, then proceeds
14. **State machine cross-check**: `ag implement F-XXXX` where F-XXXX is `shipped` → BLOCKED with lifecycle warning
15. **Dependency warning**: `ag implement F-0201` (depends on F-0200 still in backlog) → advisory warning shown
16. **Done with deps**: `ag backlog done` when next item has unmet deps → skips to first item without unmet deps, or warns if all remaining have unmet deps
17. `bash tests/validate_framework.sh` passes
18. `python3 -m pytest tests/ -x --ignore=tests/llm` passes

---

## Relationship to ADR-001

The backlog is the **foundation** the ADR roadmap builds on:
- **Phase 5 (Epics)**: `ag decompose F-XXXX` populates the backlog with child features
- **Phase 6 (MCP)**: MCP wraps backlog with atomic operations (claim/release/reorder)
- **Phase 7 (Scheduler)**: Scheduler reads backlog to dispatch work to agents
- **State machine**: Backlog tracks ORDER; state machine tracks LIFECYCLE. Orthogonal concerns that integrate cleanly — `get_unblocked()` filtered by backlog order.

The backlog is designed to be the minimal primitive that the full autonomous flow builds on.

---

## How Backlog Relates to Existing Files

### Becomes Redundant (deferred to follow-up PR except journal hint)

| File/Section | Why Redundant | What Changes | When |
|-------------|--------------|-------------|------|
| STATUS.md "Current focus" | BACKLOG[0] = current work | Eventually: `status.sh focus` syncs with BACKLOG[0]. STATUS.md keeps "Known issues/risks" and "Decisions needed". | Follow-up PR |
| STATUS.md "Next up" | BACKLOG[1:N] = ordered next steps | Eventually: section marked "see `ag backlog list`" | Follow-up PR |
| JOURNAL.md "Next steps" | BACKLOG has authoritative queue | `journal.sh` hint updated to say "reference backlog, don't duplicate queue" | **This PR** (Phase 2) |

### Overlaps But Coexists (clear boundary)

| File | Boundary |
|------|----------|
| **TODO.md** | TODO = unfiltered idea inbox (raw capture). BACKLOG = committed, ordered work queue. Flow: idea → `ag todo` → triage → `ag backlog add`. They're different pipeline stages. |
| **FEATURES.md** | FEATURES = feature registry + lifecycle state (planned→shipped). BACKLOG = execution ORDER across features. BACKLOG orders FEATURES entries. A feature can be `planned` in FEATURES.md but not yet in the backlog (not prioritized). |
| **plans/** | Plans = design documents (scope, phasing, risks). BACKLOG = execution order. Orthogonal. A backlog item may reference a plan but they serve different purposes. |

### NOT Redundant (unchanged)

| File | Why |
|------|-----|
| **HUMAN_NEEDED.md** | Blocking items requiring human input — complementary to backlog, not overlapping |
| **Acceptance criteria** | Definition of done — separate concern from execution order |
| **WIP.md** | Session-level crash recovery — different scope (session vs project) |
| **CONTRIBUTIONS.md** | Design decision history — permanent record, no overlap |
| **ISSUES.md** | Bug tracker — separate concern |

### Streamlining Actions (in this PR — minimal, low-risk)

1. **`journal.sh`**: Update "Next steps" hint text to say "reference backlog, don't duplicate the queue"
2. **Routing rules**: Update "Where to log things" in agent instruction files:
   - Prioritized work item → `ag backlog add`
   - Raw idea/task → `ag todo`
   - Human blocker → `blocker.sh`
   - Bug/tech debt → ISSUES.md

### Streamlining Actions (follow-up PR — separate scope)

3. **STATUS.md template** (`.agentic/lib/init/STATUS.template.md`): Simplify "Current focus" and "Next up" sections. Add note: "Current work tracked in BACKLOG.json — run `ag backlog`"
4. **`status.sh`**: Sync `status.sh focus` with BACKLOG[0] description, or deprecate in favor of `backlog.sh`.

---

## Follow-Up Features (Separate PRs)

1. **Session Start Context** — show blocker content, TODO titles, journal summary (not counts)
2. **Agent Decomposition** — `ag decompose F-XXXX` breaks epics into backlog items (ADR Phase 5)
3. **Backlog from Plan** — `ag backlog from-plan path/to/plan.md` populates queue from plan features
4. **STATUS.md Simplification** — deeper cleanup of STATUS.md sections that are now derivable from backlog + state machine
