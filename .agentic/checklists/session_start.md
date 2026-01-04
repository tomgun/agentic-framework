# Session Start Checklist

**Purpose**: Ensure you have proper context before starting work. Prevents re-reading entire codebase.

**Token Budget**: ~2-3K tokens for essential context.

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

