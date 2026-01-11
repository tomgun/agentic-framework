# Session Start Checklist

**Purpose**: Ensure you have proper context before starting work. Prevents re-reading entire codebase.

**Token Budget**: ~2-3K tokens for essential context.

---

# 🤖 PROACTIVE START (Do This Automatically!)

**When a new session starts (first message, tokens reset, or user returns), automatically:**

## Step 1: Quick Context Scan (Silent)

```bash
# Read these silently (don't dump to user)
cat STATUS.md 2>/dev/null || cat PRODUCT.md 2>/dev/null
cat HUMAN_NEEDED.md 2>/dev/null | head -20
ls WIP.md 2>/dev/null
```

## Step 2: Greet User with Recap

**Always start with a proactive greeting like this:**

```
👋 Welcome back! Here's where we are:

**Last session**: [Summary from JOURNAL.md or STATUS.md]
**Current focus**: [From STATUS.md "Current focus" or PRODUCT.md]
**Progress**: [What's done, what's in progress]

**Next steps** (pick one or tell me something else):
1. [Next planned task from STATUS.md]
2. [Second option if exists]
3. [Review blockers in HUMAN_NEEDED.md - if any exist]

What would you like to work on?
```

## Step 3: Handle Special Cases

**If WIP.md exists** (interrupted work):
```
⚠️ Previous work was interrupted!
Feature: [from WIP.md]
Files changed: [from WIP.md or git diff]

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
- WIP.md shows what was in progress
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

## Profile-Specific Checks

- [ ] **Check profile** in `STACK.md` (`Profile:` field)
  - Core profile → Simpler workflow
  - Core+Product profile → Additional spec tracking

## Conditional Checks

- [ ] **If Core+Product profile**: Check for active feature
  - Look at `STATUS.md` → "Current focus"
  - Read relevant `spec/acceptance/F-####.md` if working on feature
  - Check `spec/FEATURES.md` for that feature's status

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

- [ ] **Check for planned work** (Core profile: `PRODUCT.md`, Core+PM: `STATUS.md`)
  - Read "What's next" or "Next up" section
  - Identify 2-3 highest priority items
  - **Present options to user**: "I see we have [A], [B], [C] planned. Which should we tackle first?"

- [ ] **Surface blockers proactively**
  - If `HUMAN_NEEDED.md` has items, mention them BEFORE asking what to work on
  - Example: "Before we start, there are 2 items in HUMAN_NEEDED.md that need your input: [H-0001: API auth method unclear], [H-0002: UI color scheme decision]. Should we resolve these first?"

- [ ] **Check for stale work**
  - If `JOURNAL.md` shows work was in-progress but stopped mid-task, mention it
  - Example: "I notice we were implementing feature F-0042 but it's not complete. Should we finish that, or switch to something else?"

- [ ] **Check for acceptance validation**
  - If Core+PM and features are "shipped" but not "accepted", mention them
  - Example: "F-0005 and F-0007 are shipped but not accepted yet. Should we validate those?"

## Summary to User (Make Next Step Obvious)

After completing checklist, provide structured summary:

**Context Summary:**
- Current focus: [from STATUS.md or PRODUCT.md]
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

