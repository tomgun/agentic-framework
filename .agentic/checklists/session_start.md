# Session Start Checklist

**Purpose**: Ensure you have proper context before starting work. Prevents re-reading entire codebase.

**Token Budget**: ~2-3K tokens for essential context.

---

# 🤖 PROACTIVE START (Do This Automatically!)

**When a new session starts (first message, tokens reset, or user returns), automatically:**

## Step 1: Quick Context Scan (Silent)

```bash
# Read these silently (don't dump to user)
# IMPORTANT: Every command must have "|| true" to prevent exit code errors
cat STATUS.md 2>/dev/null || true
cat HUMAN_NEEDED.md 2>/dev/null | head -20 || true
cat .agentic-state/AGENTS_ACTIVE.md 2>/dev/null || true
ls .agentic-state/WIP.md 2>/dev/null || true
bash .agentic/tools/todo.sh list 2>/dev/null || true
```

## Step 2: Greet User with Recap

**Always start with a proactive greeting like this:**

```
👋 Welcome back! Here's where we are:

**Last session**: [Summary from JOURNAL.md or STATUS.md]
**Current focus**: [From STATUS.md "Current focus"]
**Progress**: [What's done, what's in progress]

**Next steps** (pick one or tell me something else):
1. [Next planned task from STATUS.md]
2. [Second option if exists]
3. [Review blockers in HUMAN_NEEDED.md - if any exist]

**Available workflows**: `ag plan` (plan-review before building) | `ag sync` (detect & fix drift)

💡 **Tip**: [Random framework tip — shown automatically by `ag start`]

What would you like to work on?
```

## Step 3: Handle Special Cases

**If .agentic-state/WIP.md exists** (interrupted work):
```
⚠️ Previous work was interrupted!
Feature: [from .agentic-state/WIP.md]
Files changed: [from .agentic-state/WIP.md or git diff]

Options:
1. Continue from checkpoint
2. Review changes first (git diff)
3. Roll back to last commit
```

**If HUMAN_NEEDED.md has unresolved items**:
```
📋 There are [N] items waiting for your input:
- [H-0001]: [Brief description]

Want to address these first, or continue with planned work?
```

**If upgrade pending**:
```
🔄 Framework was upgraded to v[X.Y.Z]!
I'll quickly apply the updates, then we'll continue.
[Handle upgrade, then return to normal greeting]
```

**If .agentic-state/AGENTS_ACTIVE.md shows other agents working**:
```
👥 Another agent is currently active!

Agent 1 (Claude - Main Window):
- Working on: [their task]
- Files: [their files]

To avoid conflicts, I should work on different files/features.
What would you like me to work on? (I'll register myself in .agentic-state/AGENTS_ACTIVE.md)
```

**CRITICAL - Multi-agent coordination:**
1. **Read .agentic-state/AGENTS_ACTIVE.md** to see who else is working
2. **Register yourself** by adding your entry
3. **Avoid their files** - pick different features/files
4. **Update when done** - remove your entry or mark complete

---

**Why proactive**: User shouldn't have to ask "where were we?" - you should tell them automatically.

---

## 🚨 THEN: Check for Interrupted Work (CRITICAL!)

**BEFORE doing anything else, check if previous work was interrupted:**

- [ ] **Run WIP check**:
  ```bash
  bash .agentic/tools/wip.sh check
  ```

**If interrupted work detected (exit code 1):**
- ⚠️ Previous session stopped mid-task (tokens out, crash, or abrupt close)
- .agentic-state/WIP.md shows what was in progress
- Git diff shows uncommitted changes
- **STOP and review before continuing!**

**Recovery options:**
1. **Continue work** - Resume from checkpoint (if progress looks good)
2. **Review changes** - `git diff` to see what changed, then decide
3. **Rollback** - `git reset --hard` if changes incomplete/broken

**Tell user about interrupted work:**
> "⚠️ Previous work on [Feature] was interrupted [X] minutes ago.
> I can see [Y] uncommitted changes. Would you like to:
> 1. Continue from where we left off
> 2. Review changes first (git diff)
> 3. Roll back to last commit"

**If no interrupted work (exit code 0):**
- ✅ Clean state, proceed with session start

**Why this is FIRST:**
- Prevents building on top of incomplete/broken changes
- Git diff shows true state vs. what docs claim
- Uncommitted changes may conflict with new work
- Lost work can be recovered instead of overwritten

---

## 🧠 Memory Integrity Check

After the WIP check, verify that Claude Code's auto-memory still contains framework behavioral patterns from `memory-seed.md`. This runs automatically via `ag start`.

```bash
bash .agentic/tools/memory-check.sh
```

**What it checks** (Claude Code only; skips other tools):
- Memory has been seeded (MEMORY.md exists)
- Version marker matches current `memory-seed.md`
- Core sentinel patterns haven't been overwritten

**If stale or missing**: Re-read `.agentic/init/memory-seed.md` and write the patterns to your persistent memory. Preserve any other project-specific content already in memory.

**Why**: Memory-seed is a defense-in-depth layer. Scripts enforce workflow structurally; memory reinforces it behaviorally. If memory gets overwritten during development, this check catches it at session start.

---

## 🔄 Sync Check (Advertise if Issues)

`ag start` automatically runs a quick sync probe. If it reports issues:

```
Sync: 2 issue(s) (journal stale, STATUS.md stale)
  Run ag sync to auto-fix and see details
```

Suggest running `ag sync` to the user. It checks memory, journal/STATUS freshness, feature status drift, spec/doc drift, and tool file parity. Safe fixes (like STATUS.md inference) are applied automatically; everything else is report-only with suggested commands.

```bash
ag sync          # Full sync: detect + auto-fix safe things
ag sync --check  # Dry run: detect only
```

---

## 📋 Check for Active Brownfield Spec Plan

- [ ] **Check for brownfield spec plan in progress**:
  ```bash
  ls .agentic-journal/plans/*-specs-plan.md 2>/dev/null || echo "No specs plan"
  ```

**If a specs plan exists with uncompleted domains:**
```
📋 Brownfield spec generation is in progress (X/Y domains completed).
Resume with: ag specs
```

This is a **suggestion**, not a block. The user may choose to work on something else.

---

## 🔄 SECOND: Check for Framework Upgrade

**🚨 IMPORTANT: The marker file IS the upgrade notification. Don't search elsewhere!**

- [ ] **Check for upgrade marker**:
  ```bash
  cat .agentic/.upgrade_pending 2>/dev/null || echo "No upgrade pending"
  ```

**If `.agentic/.upgrade_pending` exists:**
- ⚠️ **STOP AND READ THE FILE** - it contains everything you need
- The file tells you:
  - From/to versions
  - Whether STACK.md was auto-updated
  - Complete TODO checklist
  - Changelog link
- **Follow the TODO list in the file (it's 5-6 items)**
- **Delete the file when done**: `rm .agentic/.upgrade_pending`

**CRITICAL - DON'T WASTE TOKENS:**
- ❌ Don't search through `.agentic/` randomly for upgrade info
- ❌ Don't read multiple files looking for version info
- ✅ Just read `.upgrade_pending` - it has everything
- ✅ The file tells you exactly what to do

**If no marker exists:**
- ✅ No recent upgrade, proceed to next check

**Why this design:**
- ONE file = complete upgrade context
- No version comparison needed every session
- Agent handles it once → deletes → done

---

## Essential Reads (Always)

- [ ] **Read `OVERVIEW.md`** (if exists, ≈300-500 tokens)
  - Product vision and goals
  - Why we're building this
  - Core capabilities and scope
  - Guiding principles

- [ ] **Read `CONTEXT_PACK.md`** (≈500-1000 tokens)
  - Where to look for code
  - How to run/test
  - Architecture snapshot
  - Known risks/constraints

- [ ] **Read `STATUS.md`** (≈300-800 tokens)
  - Current focus
  - What's in progress
  - Next steps
  - Known blockers

- [ ] **Read `JOURNAL.md`** - Last 2-3 session entries (≈500-1000 tokens)
  - Recent progress
  - What worked/didn't work
  - Avoid repeating failed approaches

## Settings-Aware Checks

- [ ] **Check settings** in `STACK.md` `## Settings` section
  - `feature_tracking=yes` → Full spec tracking (feature IDs, acceptance criteria)
  - `feature_tracking=no` → Lightweight workflow

## Conditional Checks

- [ ] **If `feature_tracking=yes`**: Check for active feature
  - Look at `STATUS.md` → "Current focus"
  - Read relevant `spec/acceptance/F-####.md` if working on feature
  - Check `spec/FEATURES.md` for that feature's status
  - **If in-progress work exists** (WIP.md or active branch): verify it has an F-XXXX in FEATURES.md with acceptance criteria. If missing, create them before continuing.

- [ ] **If `pipeline_enabled: yes`**: Check for active pipeline
  - Look for `.agentic/pipeline/F-####-pipeline.md`
  - If exists, read to determine your role
  - Load role-specific context (see sequential_agent_specialization.md)

- [ ] **If `retrospective_enabled: yes`**: Check if retrospective is due
  - Run `bash .agentic/tools/retro_check.sh` or check manually
  - If due, suggest to human (wait for approval before running)

- [ ] **If `quality_validation_enabled: yes`**: Verify quality checks exist
  - Check if `quality_checks.sh` exists at repo root
  - If missing, offer to create based on tech stack

## Agent Delegation Check

- [ ] **Review available agents** (for delegation opportunities)
  ```bash
  ls .agentic/agents/claude/subagents/ 2>/dev/null || echo "No subagents defined"
  ```
  - Consider if subtasks can be delegated to specialized agents
  - Use `explore-agent` (haiku) for codebase searches
  - Use `research-agent` (haiku) for documentation lookups
  - See Agent Delegation Guidelines in operating guidelines

## Blockers Check

- [ ] **Read `HUMAN_NEEDED.md`** (if exists and not empty)
  - Are there unresolved blockers?
  - Do you need to address them before starting new work?
  - **IMPORTANT**: Proactively surface blockers to user at session start
  - Ask: "There are N items in HUMAN_NEEDED.md. Should we address these first?"

## Development Mode Check

- [ ] **Check `development_mode`** in `STACK.md`
  - `tdd` → Follow red-green-refactor cycle (tests first)
  - `standard` → Tests alongside or after implementation
  - Affects your workflow significantly

## Proactive Context Setting (Make Collaboration Fluent)

- [ ] **Check for planned work** (from `STATUS.md`)
  - Read "Next up" or "Next immediate step" section
  - Identify 2-3 highest priority items
  - **Present options to user**: "I see we have [A], [B], [C] planned. Which should we tackle first?"

- [ ] **Surface blockers proactively**
  - If `HUMAN_NEEDED.md` has items, mention them BEFORE asking what to work on
  - Example: "Before we start, there are 2 items in HUMAN_NEEDED.md that need your input: [H-0001: API auth method unclear], [H-0002: UI color scheme decision]. Should we resolve these first?"

- [ ] **Check for stale work**
  - If `JOURNAL.md` shows work was in-progress but stopped mid-task, mention it
  - Example: "I notice we were implementing feature F-0042 but it's not complete. Should we finish that, or switch to something else?"

- [ ] **Check for acceptance validation**
  - If Formal and features are "shipped" but not "accepted", mention them
  - Example: "F-0005 and F-0007 are shipped but not accepted yet. Should we validate those?"

## Summary to User (Make Next Step Obvious)

After completing checklist, provide structured summary:

**Context Summary:**
- Current focus: [from STATUS.md]
- Recent progress: [1-2 sentences from JOURNAL.md]
- Active blockers: [list from HUMAN_NEEDED.md or "None"]

**Options for this session:**
1. [Highest priority planned work]
2. [Second priority or blocker resolution]
3. [Alternative based on project state]

**Question**: "Which would you like to tackle? Or is there something else on your mind?"

---

## Anti-Patterns

❌ **Don't** read entire codebase at session start  
❌ **Don't** skip JOURNAL.md (you'll repeat mistakes)  
❌ **Don't** assume you know the status (check STATUS.md)  
❌ **Don't** start coding without this checklist  

✅ **Do** follow token budget strictly  
✅ **Do** read only what's needed for current task  
✅ **Do** summarize context in response to user  
✅ **Do** ask for clarification if STATUS.md is unclear

