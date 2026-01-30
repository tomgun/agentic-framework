# Codex Instructions

This repo uses the **Agentic Framework**.

---

## ENFORCED GATES (Profile-Aware)

| Gate | Core+PM (formal) | Core (discovery) |
|------|------------------|------------------|
| Acceptance criteria | **BLOCKS** - `ag implement` requires acceptance | N/A - use `ag work` |
| WIP before commit | **BLOCKS** - must complete WIP first | WARNING only |
| Pre-commit checks | **BLOCKS** - full validation | Light check, no block |

**Core+PM**: Formal tracking with enforced gates. **Core**: Discovery with lighter guidance.

**Quick Commands**: `ag start` | `ag implement F-XXXX` (Core+PM) | `ag work "desc"` (Core) | `ag commit` | `ag done` | `ag tools`

---

# STOP! READ THIS FIRST!

## WHEN User Says ANY of These:

| Trigger Words | YOUR FIRST ACTION |
|---------------|-------------------|
| "build", "implement", "add", "create", "let's do" | **STOP -> Run `ag implement F-XXXX` (verifies acceptance criteria)** |
| "fix", "bug", "issue" | **STOP -> Write failing test FIRST** |
| "commit", "push" | **STOP -> Run `ag commit` (all gates must pass)** |
| "done", "complete" | **STOP -> Run `ag done F-XXXX` (verifies completion)** |

## DO NOT PROCEED UNTIL:

```
FEATURE REQUEST?
|- Does spec/acceptance/F-####.md exist?
|   |- YES -> OK to implement
|   |- NO  -> BLOCK. Create criteria FIRST.
```

**Criteria before code. Every time. No exceptions.**

---

## Quick Checklists

- **Starting feature?** -> `.agentic/checklists/feature_start.md`
- **Before commit?** -> `.agentic/checklists/before_commit.md`
- **Feature done?** -> `.agentic/checklists/feature_complete.md`

---

## MANDATORY Protocols

### 1. Session Start (BE PROACTIVE!)

**At session start, automatically greet user with context:**

Read these files silently:
```bash
cat STATUS.md 2>/dev/null
cat HUMAN_NEEDED.md 2>/dev/null | head -20
ls .agentic/WIP.md 2>/dev/null || true
```

Then greet:
```
Welcome back! Here's where we are:
Current focus: [From STATUS.md]
Next steps:
1. [Planned task]
2. [Another option]
What would you like to work on?
```

**Full checklist**: `.agentic/checklists/session_start.md`

### 2. Documentation Updates = Part of Done

**When code changes, docs MUST update** (not optional!):

- **Project docs** (e.g., `docs/GAME_RULES.md`) -> Update immediately when behavior changes
- **spec/FEATURES.md** -> Update after completing ANY feature:
  ```bash
  bash .agentic/tools/feature.sh F-0003 status shipped
  bash .agentic/tools/feature.sh F-0003 impl-state complete
  ```
- **CONTEXT_PACK.md** -> Update when architecture changes

### 3. Feature Complete Check

**Before claiming "done", run `.agentic/checklists/feature_complete.md`**

Definition of done:
- All acceptance criteria met
- Tests written and passing
- spec/FEATURES.md updated (use `feature.sh`)
- Docs updated
- Smoke tested (actually RUN it)
- JOURNAL.md updated (use `journal.sh`)

### 4. Session End

**Run `.agentic/checklists/session_end.md`** before ending.

Use token-efficient logging:
```bash
bash .agentic/tools/journal.sh \
  "Session summary" \
  "What done" \
  "What next" \
  "Blockers"
```

---

## Token-Efficient Scripts (USE THESE!)

**Located in `.agentic/tools/`** - save tokens by avoiding full file reads:

```bash
# JOURNAL.md - Append entry
bash .agentic/tools/journal.sh "Topic" "Done" "Next" "Blockers"

# SESSION_LOG.md - Quick checkpoint (40x cheaper!)
bash .agentic/tools/session_log.sh "Description" "Details" "key=value"

# STATUS.md - Update section
bash .agentic/tools/status.sh focus "Task"
bash .agentic/tools/status.sh progress "60%"
bash .agentic/tools/status.sh next "Next step"

# FEATURES.md - Update feature field
bash .agentic/tools/feature.sh F-0003 status shipped
bash .agentic/tools/feature.sh F-0003 impl-state complete
bash .agentic/tools/feature.sh F-0003 tests complete

# HUMAN_NEEDED.md - Add/resolve blockers
bash .agentic/tools/blocker.sh add "Description" "Type" "Details"
bash .agentic/tools/blocker.sh resolve HN-0001 "Resolution"
```

**Use scripts, not direct file edits!**

---

## Source of Truth (Read First)

- `AGENTS.md` (if present)
- `.agentic/agents/shared/agent_operating_guidelines.md` (mandatory)
- `CONTEXT_PACK.md` (where things are, how to run)
- `STATUS.md` (current focus, next steps)
- `spec/FEATURES.md` (feature tracking)
- `spec/acceptance/F-####.md` (acceptance criteria)

---

## Agent Mode (Model Selection)

Check `agent_mode` in STACK.md:

| Mode | planning | implementation | review | search |
|------|----------|----------------|--------|--------|
| `premium` | best | best | best | mid-tier |
| `balanced` (default) | best | mid-tier | mid-tier | cheap |
| `economy` | mid-tier | cheap | cheap | cheap |

**Custom models**: Override in `models:` section. **Docs**: `.agentic/workflows/agent_mode.md`

---

## Standards

**Programming** (`.agentic/quality/programming_standards.md`):
- Security first, clear naming, small functions, explicit errors

**Testing** (`.agentic/quality/test_strategy.md`):
- Happy path + edge cases + invalid input + time-based behavior

**Development** (`STACK.md`):
- Check `development_mode` (tdd recommended)
- TDD: Write tests FIRST (`.agentic/workflows/tdd_mode.md`)

**Git** (`.agentic/workflows/git_workflow.md`):
- Never auto-commit. Show changes to human first.
- PR workflow default for Core+PM profile

---

## Automatic Journaling

Log at natural checkpoints (don't wait for session end!):
- After completing feature -> `session_log.sh`
- After fixing bug -> `session_log.sh`
- Every ~30 min work -> `session_log.sh`
- At milestones -> `journal.sh`

**See `.agentic/workflows/automatic_journaling.md`**

---

## Checklists

- **[`checklists/session_start.md`]** - START every session
- **[`checklists/session_end.md`]** - END every session
- **[`checklists/feature_complete.md`]** - BEFORE claiming "done"
- **[`checklists/before_commit.md`]** - BEFORE every commit
- **[`checklists/smoke_testing.md`]** - RUN the app, verify it works

---

## Summary

**Three mandatory protocols:**
1. **Session START**: Read `session_start.md`, load context
2. **During work**: Update docs alongside code, use scripts
3. **Session END**: Run `session_end.md`, update JOURNAL.md

**Use scripts** - 40x cheaper than reading/rewriting files.

**Follow checklists** - systematic, nothing forgotten.
