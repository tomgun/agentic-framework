# Plan: Centralized TODO Tracking (F-0136)

## Context

Ideas and tasks are scattered across STATUS.md (Backlog/Next up), HUMAN_NEEDED.md, JOURNAL.md (Next steps), FEATURES.md, and ISSUES.md. There's no single inbox for quick capture. When an idea comes up mid-session, it either gets lost to context compression or ends up in the wrong file. Claude's task list disappears between sessions.

**Goal**: One durable, git-tracked inbox where ideas/tasks are captured instantly and triaged later. When items are done or dropped, the outcome is recorded (linked to journal).

## Problem: agents scatter tasks everywhere

Even with clear file purposes, agents dump development ideas into HUMAN_NEEDED.md (e.g. HN-0003 "Map FEATURES.md to Principles" — a task, not a human blocker), STATUS.md Backlog, and JOURNAL.md "Next steps." The root cause: there's no designated quick-capture target, so agents use whatever file they're already touching.

**Fix requires two things**:
1. A dedicated inbox file (TODO.md) with frictionless capture
2. Clear routing rules so agents know: task/idea → TODO.md, human blocker → HUMAN_NEEDED.md

## Design: TODO.md + todo.sh

Follows the pattern of `blocker.sh` / HUMAN_NEEDED.md: one markdown file, one bash script, T-#### IDs, append-only for adds. (Note: uses single-write insertion — see blocker.sh bug note below.)

**Key decisions**:
- **Two sections only**: Inbox and Done. No priority/status/tags — if it needs structure, triage it to FEATURES.md or ISSUES.md.
- **Both profiles**: Discovery users need it most (no FEATURES.md). Formal users use it as a triage pipeline.
- **Done = journal link**: `done` and `drop` record a resolution note in the Done section. Journal captures the work naturally via `journal.sh` when the agent commits.
- **STATUS.md Backlog removed**: TODO.md replaces it. STATUS.md keeps "Next up" as a curated short-list for the current session.
- **Routing rules enforced**: instruction files + memory-seed get a clear decision table:
  - Development idea / task / reminder → `ag todo "..."` (TODO.md)
  - Needs human action (PR review, credentials, decision) → `blocker.sh` (HUMAN_NEEDED.md)
  - Bug with root cause → `quick_issue.sh` (ISSUES.md)
  - New capability to spec → `feature.sh` (FEATURES.md)
- **Session start surfaces TODO inbox**: `ag start` dashboard shows inbox count prominently, so agents see pending items every session.

## Changes

### 0. Spec entry and acceptance criteria (framework rule)
**Files**: `spec/FEATURES.md`, `spec/acceptance/F-0136.md` (NEW)

Add F-0136 to FEATURES.md under Framework Infrastructure (F-0101+). Create `spec/acceptance/F-0136.md` with acceptance criteria derived from the Verification section below.

### 1. Create TODO.md template
**File**: `.agentic/spec/TODO.template.md` (NEW)

```markdown
# TODO

<!-- format: todo-v0.1.0 -->

Purpose: quick-capture inbox for ideas, tasks, and reminders. Triage to FEATURES.md or ISSUES.md when ready, or resolve directly.

## Inbox

<!-- Use: bash .agentic/tools/todo.sh add "description" -->

_No items_

## Done

<!-- Resolved/triaged items move here with outcome -->
```

### 2. Create todo.sh script
**File**: `.agentic/tools/todo.sh` (NEW)

Pattern: follows `blocker.sh` (`.agentic/tools/blocker.sh`) structure, but fixes the double-write bug.

**blocker.sh bug (do NOT replicate)**: `blocker.sh add` writes items twice — once via `>>` append (lines 87–96) and again via `sed -i` insertion (lines 99–107). `todo.sh` must use a **single-write pattern**: only the targeted `sed` insertion before `## Done`, no `>>` append. (Separate cleanup of blocker.sh tracked as T-0004.)

```
bash .agentic/tools/todo.sh add "Description" ["context"]
bash .agentic/tools/todo.sh done T-0001 ["resolution"]
bash .agentic/tools/todo.sh drop T-0001 ["reason"]
bash .agentic/tools/todo.sh triage T-0001 feature|issue ["notes"]
bash .agentic/tools/todo.sh list
```

| Command | Action | Token cost |
|---------|--------|-----------|
| `add` | Insert `### T-####` entry before `## Done` (single write) | Targeted sed |
| `done` | Move from Inbox to Done with "Resolved:" note | Targeted awk |
| `drop` | Move from Inbox to Done with "Dropped:" note | Targeted awk |
| `triage` | Move to Done with "Promoted to F-XXXX / I-XXXX" note (records move only — agent creates F-XXXX/I-XXXX separately) | Targeted awk |
| `list` | Print Inbox-only items (section-aware: between `## Inbox` and `## Done`) | awk + grep |

Item format:
```markdown
### T-0001: Try context7 MCP integration
- **Added**: 2026-02-18
- **Context**: Session discussion about MCP tooling
```

### 3. Add `ag todo` command
**File**: `.agentic/tools/ag.sh`

- Add `cmd_todo()` — thin wrapper delegating to `todo.sh`
- Add `todo` case in dispatch switch
- Add to both help texts (Discovery + Formal)
- In `cmd_start()`, after HUMAN_NEEDED count (~line 276), add inbox count display
- **Bug fix**: `cmd_start()` line ~279 uses `grep -c "^## HN-"` but blocker.sh writes `### HN-####:` (3 hashes). Fix to `^### HN-` while adding the TODO count. Use section-aware count for TODO inbox items (only between `## Inbox` and `## Done`, not items in the Done section)

```
ag todo "Quick idea"              # add
ag todo list                      # show inbox
ag todo done T-0001 "shipped"     # resolve
ag todo drop T-0001 "not needed"  # drop with reason
ag todo triage T-0001 feature     # promote to FEATURES.md
```

### 4. Update scaffold.sh
**File**: `.agentic/init/scaffold.sh`

Add `copy_if_missing` for TODO.md — **both profiles** (after HUMAN_NEEDED.md creation).

### 5. Create framework's own TODO.md (dogfooding)
**File**: `TODO.md` (NEW, project root)

Seed with the 3 items currently in STATUS.md Backlog:
- T-0001: Progressive disclosure of complexity
- T-0002: Context7 MCP integration — test in real project
- T-0003: Automated CI for LLM tests via Claude CLI

### 6. Remove Backlog from STATUS.md template
**File**: `.agentic/init/STATUS.template.md`

Remove `## Backlog` section. Keep `## Next up` (curated session priorities, distinct from the raw inbox).

Clean up framework's own STATUS.md: remove Backlog items (now in TODO.md).

### 7. Update instruction files — trigger + routing + token-efficient script
**Files**: `CLAUDE.md`, `.agentic/agents/claude/CLAUDE.md`, codex, copilot, cursor (5 files)

Trigger table row:
```
| Idea / remember / todo / tasklist / note for later | STOP -> `ag todo "description"` for persistent capture (git-tracked). |
```

Update "Done / complete" trigger action — append: "Before ending, check TaskList for pending items and flush to TODO.md via `ag todo`."

Token-efficient scripts — add line:
```
- TODO.md: `bash .agentic/tools/todo.sh add "Idea"` or `ag todo "Idea"`
```

Routing rule (add to Rules section in claude/CLAUDE.md template and framework CLAUDE.md):
```
- **Where to log**: Task/idea → `ag todo`; human blocker (PR, credential, decision) → `blocker.sh`; bug → `quick_issue.sh`; new capability → `feature.sh`. Do NOT put development tasks in HUMAN_NEEDED.md.
```

### 8. Update memory-seed
**File**: `.agentic/init/memory-seed.md`

Add trigger: user mentions idea/todo/remember/later → `ag todo "description"`.

Add routing rule (new section "Where to log things"):
```
- Development idea or task → `ag todo "description"` (TODO.md)
- Needs human action (PR review, credentials, decision) → `blocker.sh` (HUMAN_NEEDED.md)
- Bug or technical debt → ISSUES.md
- New capability to spec → FEATURES.md
Do NOT put development tasks in HUMAN_NEEDED.md.
```

### 9. Update session_start and session_end checklists
**File**: `.agentic/checklists/session_start.md`

Add: `bash .agentic/tools/todo.sh list 2>/dev/null || true` to surface inbox in dashboard.

**File**: `.agentic/checklists/session_end.md`

Add step: "Check Claude's TaskList for pending items. Flush any remaining to TODO.md via `ag todo` before ending."

### 10. Update S07 structural test
**File**: `tests/infrastructure/structural/S07_memory_seed_consistency.sh`

Add two new checks (to reach 24/24 total):
1. **7th trigger check**: todo/idea → `ag todo` present in both memory-seed and CLAUDE.md template (+2 checks)
2. **5th script reference check**: `todo.sh` referenced in both memory-seed and CLAUDE.md template (+2 checks)

Math: current 6 triggers × 2 files (12) + 4 scripts × 2 files (8) = 20. Adding 1 trigger (×2) + 1 script (×2) = 24.

## Files Summary

| File | Change |
|------|--------|
| `spec/FEATURES.md` | Add F-0136 entry |
| `spec/acceptance/F-0136.md` | NEW — acceptance criteria |
| `.agentic/spec/TODO.template.md` | NEW — template |
| `.agentic/tools/todo.sh` | NEW — CRUD script (single-write, not double-write) |
| `TODO.md` | NEW — framework dogfooding, seeded with 3 items (+T-0004 blocker.sh fix) |
| `.agentic/tools/ag.sh` | Add cmd_todo(), dispatch, help, start integration; fix HN count bug |
| `.agentic/init/scaffold.sh` | Add TODO.md for both profiles |
| `.agentic/init/STATUS.template.md` | Remove Backlog section |
| `STATUS.md` | Remove Backlog items (moved to TODO.md) |
| `CLAUDE.md` | Trigger row + token-efficient script line + routing rule |
| `.agentic/agents/claude/CLAUDE.md` | Same |
| `.agentic/agents/codex/codex-instructions.md` | Same (trigger only) |
| `.agentic/agents/copilot/copilot-instructions.md` | Same (trigger only) |
| `.agentic/agents/cursor/cursorrules.txt` | Same (trigger only) |
| `.agentic/init/memory-seed.md` | Add todo trigger + routing rules + todo.sh script ref |
| `.agentic/checklists/session_start.md` | Add inbox check |
| `.agentic/checklists/session_end.md` | Add TaskList flush step |
| `tests/infrastructure/structural/S07_memory_seed_consistency.sh` | 7th trigger + 5th script check |

18 files (4 new, 14 modified). Split into 2 commits:
- Commit 1: specs + template + script + ag.sh + scaffold + dogfooding TODO.md (core)
- Commit 2: instruction files + memory-seed + test + STATUS.md cleanup (integration)

## Verification

1. `bash .agentic/tools/todo.sh add "Test item"` — creates T-0001 in TODO.md
2. `bash .agentic/tools/todo.sh list` — shows inbox count + items
3. `bash .agentic/tools/todo.sh done T-0001 "tested"` — moves to Done
4. `ag todo "Another test"` — works via ag.sh
5. `ag start` — shows inbox count in dashboard
6. `bash tests/infrastructure/structural/S07_memory_seed_consistency.sh` — 24/24 pass
7. `bash tests/validate_framework.sh` — all pass
8. New project scaffold includes TODO.md for both Discovery and Formal profiles
