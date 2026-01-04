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
  - Should you ask human about status?

## Development Mode Check

- [ ] **Check `development_mode`** in `STACK.md`
  - `tdd` → Follow red-green-refactor cycle (tests first)
  - `standard` → Tests alongside or after implementation
  - Affects your workflow significantly

## Summary to User

After completing checklist, tell user:
- What the current focus is (from STATUS.md)
- Any blockers found (from HUMAN_NEEDED.md)
- What you're ready to work on
- Ask: "Should I continue with [current focus], or is there something else?"

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

