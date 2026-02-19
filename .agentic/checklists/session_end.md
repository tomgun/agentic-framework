# Session End Checklist

**Purpose**: Ensure clean session closure with clear handoff to next session (or human).

**Use**: Before ending your work session, whether continuing later or handing off.

---

## Documentation Updates (MANDATORY - WILL BE CHECKED!)

**🚨 CRITICAL**: If session ends abruptly, these documents are the ONLY record of progress. Update them BEFORE ending!

### Both Profiles (Discovery and Formal)

- [ ] **`JOURNAL.md` updated with full session summary** (NON-NEGOTIABLE!)
  - Session date/time
  - What feature/task was worked on
  - What was accomplished (concrete deliverables)
  - Important decisions made
  - Any challenges encountered
  - What's next (clear next step)
  - Any context the next session needs
  - **RULE**: Never end session without updating JOURNAL.md!

- [ ] **`STATUS.md` updated**
  - Current session state: Summarize this session
  - Completed this session: List concrete accomplishments
  - Next immediate step: Clear, actionable next step
  - Blockers: Document any blockers encountered

- [ ] **`OVERVIEW.md` updated** (optional - only if project has one)
  - Completed capabilities marked [x]
  - "What works now" is accurate
  - Skip if project uses STATUS.md only

- [ ] **`CONTEXT_PACK.md` updated** (if anything changed)
  - New modules/components documented
  - Entry points still accurate
  - Architecture snapshot current
  - Known risks updated

### Formal Profile (Additional items:)

- [ ] **`spec/FEATURES.md` updated** (if working on features)
  - Status accurate (planned/in_progress/shipped)
  - Implementation State accurate (none/partial/complete)
  - All fields current
  - No stale information

---

## Blockers Documented (CRITICAL - CHECK FIRST!)

**🚨 BEFORE anything else, check if you discovered any blockers during this session:**

- [ ] **Review what you discovered/set up**
  - Did you mention any manual installation steps?
  - Did you discover missing credentials?
  - Did you identify design decisions needed?
  - Did you mention any "you'll need to..." items?

- [ ] **Update `HUMAN_NEEDED.md`** (if any blockers found)
  - **RULE**: If you mentioned something to the user in chat that requires their action, it MUST be in HUMAN_NEEDED.md
  - Don't assume they'll remember - document it!
  - Clear description of blocker
  - Why it needs human input
  - What you've tried already
  - What information/decision is needed
  - How urgent is it
  - **Examples**:
    - Manual plugin installation (e.g., GUT for Godot)
    - API keys needed
    - Design decisions pending
    - Account creation required

- [ ] **Or verify `HUMAN_NEEDED.md` is current** (if no new blockers)
  - Remove resolved items (move to "Resolved" section)
  - Keep only active blockers
  - Leave empty if no blockers

---

## Flush Pending Ideas to TODO.md

- [ ] **Check Claude's TaskList for pending items**
  - Any ideas, tasks, or reminders captured during the session?
  - Flush remaining items to TODO.md via `ag todo "description"`
  - TODO.md is git-tracked and survives context compression; TaskList does not

---

## Code State Clean

- [ ] **No uncommitted work** (unless intentional)
  - Either: All changes committed
  - Or: Clear explanation to user why not committed
  - If mid-work: Explain state and what's next

- [ ] **No untracked files in project directories**
  - Run: `git status --short | grep '??'`
  - Check: assets/, src/, tests/, spec/, docs/ for untracked files
  - Either: `git add` new files you created
  - Or: Add to `.gitignore` if intentionally untracked
  - **WARNING**: Untracked files = missing from deployment!

- [ ] **No work-in-progress files**
  - No temp files left around
  - No test.js, debug.py, scratch files
  - Clean working directory

- [ ] **No broken state**
  - Tests still pass
  - Code still runs
  - Nothing half-implemented that breaks build

- [ ] **Drift check** (recommended after significant work)
  - Run: `bash .agentic/tools/drift.sh`
  - Checks: untracked files, feature status, template markers

---

## Handoff Information (CRITICAL)

### Tell User (in your final response):

- [ ] **What changed (1-5 bullets)**
  - Concrete accomplishments
  - Files modified
  - Features implemented
  - Tests added
  - Example: "✅ Implemented F-0003: User login with JWT tokens"

- [ ] **What's next (1-5 bullets)**
  - Clear next steps
  - Priority order if multiple items
  - Dependencies if any
  - Example: "Next: Implement F-0004: Password reset flow"

- [ ] **What you need from user (if anything)**
  - Questions requiring decisions
  - Blockers needing resolution
  - Validation/approval needed
  - Example: "Need your decision: Should we use email or username for login?"

### Make Next Step Obvious

- [ ] **Next action is crystal clear**
  - Not vague ("work on features")
  - Specific ("implement password reset - F-0004")
  - Actionable (agent or human knows exactly what to do)

- [ ] **Context for next session is captured**
  - Why are we doing next step?
  - What's the goal?
  - Any important context to remember

---

## Quality State Verified

- [ ] **Tests pass**
  - If you committed code, tests pass
  - If mid-work, note test state clearly

- [ ] **No obvious issues**
  - No linter errors (if linter enabled)
  - No syntax errors
  - Code can at least build/run

- [ ] **Quality checks pass** (if enabled and committed)
  - If `quality_validation_enabled: yes`
  - And you committed code
  - Then quality checks should pass

---

## Suggested Tools (User Might Run)

Include in your response if relevant:

- [ ] **Suggest project health check**
  - `bash .agentic/tools/doctor.sh` - if structure might have issues
  - `bash .agentic/tools/verify.sh` - for comprehensive verification

- [ ] **Suggest status check**
  - `cat STATUS.md` - if user wants quick overview
  - `tail -30 JOURNAL.md` - to review recent work

- [ ] **Suggest feature status**
  - `bash .agentic/tools/report.sh` - if working on features
  - `bash .agentic/tools/feature_graph.sh` - if dependencies matter

**Don't force them to run scripts**, just suggest relevant ones.

---

## Commit Status Clear

- [ ] **User knows if changes are committed**
  - Explicitly state: "Changes committed" or "Changes not yet committed"
  - If not committed, explain why
  - If committed, provide commit hash/message

- [ ] **User knows if changes are pushed**
  - Explicitly state: "Pushed to GitHub" or "Not yet pushed"
  - If not pushed and should be, ask if they want to push

---

## Final Message to User

Your final message should include:

### 1. Summary Section
```
## Session Summary

**Accomplished:**
- [bullet points of what was done]

**Next Steps:**
- [clear next actions]

**Blockers/Questions:**
- [anything you need from user, or "None"]
```

### 2. Commit Status
```
**Changes:** [Committed and pushed / Committed but not pushed / Not yet committed - waiting for approval]
```

### 3. Current State
```
**Project State:** [Tests pass / Feature complete / In progress - tests passing / etc.]
```

### 4. Suggested Actions (if any)
```
**Suggested:** 
- Run `bash .agentic/tools/doctor.sh` to verify project health
- Review HUMAN_NEEDED.md - there's a blocker requiring your input
```

### 5. Ready for Next Session
```
**Next Session:** Can pick up from STATUS.md → "Next immediate step"
```

---

## Anti-Patterns

❌ **Don't** end session without updating JOURNAL.md  
❌ **Don't** leave vague "what's next" (be specific)  
❌ **Don't** leave uncommitted work without explanation  
❌ **Don't** end with broken tests/build  
❌ **Don't** forget to tell user what you need from them  
❌ **Don't** assume user remembers context (spell it out)  

✅ **Do** provide clear summary  
✅ **Do** make next step obvious  
✅ **Do** update all documentation  
✅ **Do** leave clean state  
✅ **Do** communicate what you need  

---

## Session End Complete

**After all items checked:**

1. Provide complete summary to user (as outlined above)
2. Answer any questions they might have
3. Confirm they know:
   - What was accomplished
   - What's next
   - What you need from them (if anything)
   - State of commits/pushes
4. Wait for any final instructions before truly ending

**Remember**: The next agent (or you in a fresh context) will rely on what you documented. Make it easy for them.

**Quality bar**: Could a fresh agent with NO context read JOURNAL.md and STATUS.md and know exactly what to do next? If not, add more detail.


