# Proactive Agent Operating Loop

**Purpose**: Make human-machine collaboration fluent by having agents proactively manage workflow, surface blockers, and suggest next steps.

---

## Preconditions

Before starting a proactive agent session, verify:

- [ ] **Project has essential context files**: CONTEXT_PACK.md, STATUS.md exist
- [ ] **Recent activity visible**: JOURNAL.md has entries (or this is first session)
- [ ] **Git is clean or understood**: No mysterious uncommitted changes (or you know why they exist)
- [ ] **Can access project state**: Tools like `doctor.sh`, `brief.sh` are accessible

**If any precondition fails:**
- Missing context files → Run `doctor.sh` to identify issues, or initialize project if not yet set up
- No JOURNAL.md entries → This might be first session (OK), or agent should create initial entry
- Mysterious git changes → Ask human about uncommitted work before proceeding
- Tools not accessible → Check `.agentic/` folder exists and is not corrupted

---

## Progress Tracking

Copy this checklist to track your session progress:

```
Proactive Agent Session Progress:
- [ ] Step 1: Loaded essential context (CONTEXT_PACK, STATUS/PRODUCT, JOURNAL, HUMAN_NEEDED)
- [ ] Step 2: Assessed project state (blockers, stale work, planned work)
- [ ] Step 3: Presented context & options to human
- [ ] Step 4: Worked on chosen task(s)
- [ ] Step 5: Provided mid-session updates (if session >30 min)
- [ ] Step 6: Updated documentation (JOURNAL, STATUS/PRODUCT, specs)
- [ ] Step 7: Prepared session summary with clear next steps
- [ ] Step 8: Committed changes (or prepared for commit)
```

**Self-check**: Before ending session, verify all 8 steps completed. Don't skip documentation updates.

---

## State Contracts

**This workflow READS**:
- `CONTEXT_PACK.md` - Architecture & constraints
- `STATUS.md` - Current focus & planned work
- `JOURNAL.md` - Recent progress and decisions
- `HUMAN_NEEDED.md` - Active blockers
- `spec/FEATURES.md` - Feature status (if Core+PM mode)
- Git status - Uncommitted changes

**This workflow WRITES**:
- `JOURNAL.md` - Session summaries and decisions
- `STATUS.md` - Updated progress and next steps
- `HUMAN_NEEDED.md` - New blockers or decisions needed
- `spec/FEATURES.md` - Updated feature status (if Core+PM mode)
- Source code, tests, other implementation files

**Side effects**:
- Git commits (with human approval)
- May trigger retrospectives (if configured)
- May invoke other workflows (TDD, research, etc.)

---

## Core Principle: Agent as Collaborative Partner

**The agent should:**
- ✅ Proactively surface blockers and decisions needed
- ✅ Suggest next steps based on project state
- ✅ Check for stale/incomplete work
- ✅ Keep human informed of project health
- ✅ Ask clarifying questions early
- ✅ Make the "what's next" obvious

**The agent should NOT:**
- ❌ Wait passively for instructions
- ❌ Assume what to work on without context
- ❌ Ignore blockers in HUMAN_NEEDED.md
- ❌ Start random tasks without checking planned work
- ❌ Leave human wondering what happened last session

---

## Session Start Operating Loop

### 1. Load Essential Context (Token-Efficient)

**Read in order** (~2-3K tokens):
1. `CONTEXT_PACK.md` - Architecture & constraints
2. `STATUS.md` - Current focus & planned work
3. `JOURNAL.md` (last 2-3 entries) - Recent progress
4. `HUMAN_NEEDED.md` - Active blockers

### 2. Assess Project State

**Check for:**
- 🚩 **Blockers**: Items in HUMAN_NEEDED.md
- 🚩 **Stale work**: In-progress tasks from last session that weren't completed
- 🚩 **Awaiting acceptance**: Features marked "shipped" but not "accepted"
- 🚩 **Retrospective due**: If enabled and threshold met
- ✅ **Planned work**: Next items from STATUS.md

### 3. Present Context & Options to Human

**Template**:

```
📊 **Session Context**

**Current Focus**: [from STATUS.md]
**Recent Progress**: [1-2 sentences from JOURNAL.md]

[If blockers exist:]
⚠️ **Blockers Needing Attention** (from HUMAN_NEEDED.md):
- H-0042: API authentication method unclear (blocks F-0010)
- H-0043: UI color scheme decision needed

[If stale work exists:]
🔄 **Incomplete Work**:
- F-0010: Login UI (in_progress, 60% complete, last worked 3 days ago)

[If acceptance needed:]
✅ **Ready for Validation**:
- F-0005: Dashboard (shipped, not accepted)
- F-0007: Settings (shipped, not accepted)

**Planned Next** (from STATUS.md):
1. F-0012: Password reset feature
2. F-0015: User profile page
3. Refactor authentication module

**What would you like to tackle?**
a) Resolve blockers first (H-0042, H-0043)
b) Complete in-progress work (F-0010)
c) Validate shipped features (F-0005, F-0007)
d) Start planned work (F-0012)
e) Something else?
```

### 4. During Work - Proactive Updates

**Every 30-60 minutes or at natural breakpoints:**
- Update human on progress
- Surface any new blockers immediately
- Ask clarifying questions as soon as they arise (don't accumulate them)
- Check if direction still makes sense

**Example mid-session update**:
```
📍 **Progress Update**

✅ Completed:
- Login form component
- Form validation logic
- Unit tests for validation

🚧 In Progress:
- API integration (50%)

⚠️ Question:
Should the login redirect to /dashboard or /home after success?
(Can't proceed until decided - adding to HUMAN_NEEDED.md)
```

### 5. Session End - Clear Handoff

**Always end with**:

```
📝 **Session Summary**

**Completed**:
- [List what was done]

**Next Steps**:
1. [Most logical next step]
2. [Alternative next step]
3. [Optional: longer-term goal]

**Blockers Added**:
- [New items in HUMAN_NEEDED.md]

**Updated**:
- JOURNAL.md (session summary)
- STATUS.md (progress on F-0010)
- FEATURES.md (F-0010 state: partial → complete)

**Ready to commit?** (yes/no/show diff)
```

---

## Handling HUMAN_NEEDED Items

### At Session Start

**ALWAYS surface HUMAN_NEEDED items proactively**:

```
⚠️ **Before we start**: There are 3 items in HUMAN_NEEDED.md needing your input:

1. **H-0042: API Auth Method** (blocks F-0010)
   - Need to choose between JWT vs OAuth2
   - Affects: Login, API client, all authenticated routes
   - Urgency: High (blocks current work)

2. **H-0043: UI Color Scheme** (blocks F-0015)
   - Need brand colors for buttons, links, backgrounds
   - Urgency: Medium (can work on other things first)

3. **H-0044: Database Migration Strategy** (future work)
   - Need to decide on migration tool (Alembic vs custom)
   - Urgency: Low (not blocking current work)

**Should we address any of these before starting new work?**
```

### During Session

**When adding new blocker**:
- Tell human immediately, don't wait until session end
- Explain what you tried before escalating
- Provide context and options

**Example**:
```
⚠️ **Blocker Encountered**

I need to implement error handling for the API client, but I'm uncertain
about the error response format from the API.

**What I've tried:**
- Checked API documentation (no error format specified)
- Looked at source code (no examples found)

**What I need:**
- Example error response from the API
- Preferred error handling pattern (throw exceptions vs return Result)

**Impact:**
- Blocks completion of F-0010 (Login UI)
- Can continue with UI rendering, but can't finish API integration

**Added to HUMAN_NEEDED.md as H-0045**

**Should I**:
a) Work on something else while waiting
b) Implement basic error handling and refine later
c) You have the error format info now?
```

---

## Suggesting Next Work

### When User Says "What should we do next?"

**DON'T**:
- ❌ "What would you like to work on?"
- ❌ "I'm ready for your instructions"
- ❌ Pick random task without context

**DO**:
- ✅ Check STATUS.md for planned work
- ✅ Prioritize by: blockers > incomplete work > planned > new ideas
- ✅ Provide 3-4 concrete options with context

**Example**:
```
Based on STATUS.md and current project state, here are the top priorities:

**1. Finish In-Progress Work** (RECOMMENDED)
   - F-0010: Login UI (80% complete, just needs API integration)
   - Est: 30 minutes
   - Blockers: H-0042 (API auth method) needs resolution first

**2. Validate Shipped Features**
   - F-0005: Dashboard (shipped 3 days ago, not accepted)
   - F-0007: Settings (shipped 5 days ago, not accepted)
   - Est: 15 minutes to test both

**3. Start Next Planned Feature**
   - F-0012: Password reset (from STATUS.md "Next up")
   - Dependencies: F-0001 (Auth system) is complete
   - Est: 2-3 hours

**4. Technical Debt** (if time permits)
   - Refactor authentication module (noted in LESSONS.md)
   - Can improve before adding more auth features

**Which makes most sense to you?**
```

---

## Retrospective Prompting

**If `retrospective_enabled: yes` and threshold met**:

```
📊 **Retrospective Due**

It's been 15 days and 12 features since our last retrospective.
Would you like to run one now?

**What we'd review:**
- What's working well (process, tools, workflow)
- What's not working (pain points, bottlenecks)
- Lessons learned from recent features
- Process improvements

**Takes**: 15-20 minutes

**Run retrospective now?** (yes/later/skip)
```

---

## Fluency Enhancements

### 1. Check for Unfinished Work

**At session start, if JOURNAL.md shows mid-task stop**:

```
🔄 **Resuming Previous Work**

Last session (3 days ago) you were working on F-0010 (Login UI).
Progress was:
- ✅ Form component done
- ✅ Validation logic done
- 🚧 API integration started but not finished

**Should we**:
a) Continue with F-0010 (finish API integration)
b) Start something fresh
c) Review what was done first
```

### 2. Dependency Awareness

**When suggesting work, check dependencies**:

```
**Option**: F-0015 (User Profile Page)

⚠️ **Note**: This depends on F-0010 (Login UI) which is still in_progress.
We could:
- Work on non-auth parts first (layout, styling)
- Finish F-0010 first (15 min remaining)
- Pick something without dependencies

**Recommendation**: Finish F-0010 first (almost done).
```

### 3. Context Continuity Across Sessions

**When user returns after gap**:

```
👋 **Welcome back!**

It's been 5 days since last session. Quick recap:

**Last Session** (Jan 4):
- Completed F-0010 (Login UI)
- Started F-0012 (Password Reset)
- Added H-0045 (Error handling format needed)

**Current State**:
- F-0012 is in_progress (50% done)
- H-0045 still unresolved

**Should we**:
a) Resolve H-0045 first (blockers)
b) Continue F-0012 (might hit blocker)
c) Start something new
```

### 4. Token-Saving Suggestions

**When appropriate**:

```
💡 **Tip**: You can check project status anytime with:
- `bash .agentic/tools/brief.sh` (quick summary)
- `python .agentic/tools/query_features.py --count` (feature stats)

This saves agent tokens for actual development!
```

---

## Success Criteria

**Collaboration is fluent when:**
- ✅ Human always knows what happened last session
- ✅ Blockers are surfaced immediately, not discovered later
- ✅ "What's next?" always has concrete, prioritized options
- ✅ Agent suggests work based on project plan, not randomly
- ✅ Human doesn't have to remember context (agent provides it)
- ✅ Decisions are escalated early, not after getting stuck
- ✅ Session handoffs are clear and actionable

**Anti-patterns to avoid:**
- ❌ "I'm ready, what should I do?" (passive, no context)
- ❌ Starting work without checking HUMAN_NEEDED.md
- ❌ Discovering blocker at end of session (too late)
- ❌ "Continue with current task?" (what task? what's the state?)
- ❌ Ignoring planned work in STATUS.md

---

## Error Recovery

**Common problems in proactive agent workflow and solutions:**

### Problem: Can't find planned work

**Symptoms**: STATUS.md is vague, no clear next steps

**Solutions**:
1. Check JOURNAL.md for what was discussed last session
2. Check HUMAN_NEEDED.md - maybe blockers exist that should be resolved first
3. Check spec/FEATURES.md (if Core+PM) for 'planned' features
4. If still unclear: Ask human directly what they'd like to focus on
5. Document the answer in STATUS.md so it's clear for next session

**Prevention**: Always update STATUS.md with clear "Next Up" section before ending session

---

### Problem: HUMAN_NEEDED items are stale or unclear

**Symptoms**: Blocker items exist but no longer relevant, or too vague to act on

**Solutions**:
1. Ask human: "Is H-0042 still relevant? Can we close it?"
2. If vague, ask for clarification: "H-0043 says 'need decision' - what specifically?"
3. Clean up HUMAN_NEEDED.md with human approval (move resolved items to JOURNAL.md)
4. Add context to new items: what's blocked, why it's needed, what info is required

**Prevention**: When adding to HUMAN_NEEDED.md, always include:
- Clear ID (H-####)
- What decision/input is needed
- What it blocks
- Urgency level
- Options/context to help human decide

---

### Problem: Unclear what state features are in

**Symptoms**: FEATURES.md says "in_progress" but no code exists, or "shipped" but not actually working

**Solutions**:
1. Run `doctor.sh` to check for inconsistencies
2. Check git history for recent changes to those features
3. Ask human: "F-0010 shows 'in_progress' - is this accurate?"
4. Update FEATURES.md to match reality
5. Add JOURNAL.md entry explaining the correction

**Prevention**: Update FEATURES.md in the SAME COMMIT as code changes

---

### Problem: Session ended abruptly last time (incomplete work)

**Symptoms**: JOURNAL.md shows work started but not finished, git has uncommitted changes

**Solutions**:
1. Present state clearly: "Last session was interrupted. Work on F-0010 was partial."
2. Ask human: "Should we continue F-0010, commit as-is, or start fresh?"
3. If continuing: Resume from last known good state
4. If starting fresh: Create backup branch first, then reset or commit incomplete work

**Template**:
```
🔄 **Interrupted Session Detected**

Last session (3 days ago) ended mid-work on F-0010:
- Form component: Complete
- Validation logic: Incomplete (has failing tests)
- Git: 5 uncommitted files

**Options**:
a) Continue F-0010 (fix failing tests, complete validation)
b) Commit incomplete work with note, start something else
c) Discard changes, start fresh
d) Review the code first

**What would you prefer?**
```

---

### Problem: Agent is unsure if change requires human decision

**Symptoms**: Hesitating between implementing or escalating

**Guidelines for when to escalate**:

**ESCALATE (add to HUMAN_NEEDED.md)** when:
- ✅ Business logic decision (what should happen?)
- ✅ Product direction (which feature is more important?)
- ✅ Breaking changes (affects existing users?)
- ✅ Security/privacy decisions
- ✅ External dependencies (which library/service?)
- ✅ Cost implications (cloud resources, paid APIs)
- ✅ Multiple valid approaches with tradeoffs
- ✅ Unclear requirements (what does "user-friendly" mean specifically?)

**DON'T ESCALATE (just implement)** when:
- ❌ Implementation details (how to structure code)
- ❌ Naming variables/functions (use conventions)
- ❌ Technical patterns (follow established patterns in codebase)
- ❌ Testing approach (follow test_strategy.md)
- ❌ Formatting/style (follow linter)
- ❌ Refactoring (if behavior stays same and tests pass)

**When in doubt**: Escalate with context, but also suggest your recommended approach

**Example**:
```
⚠️ **Decision Needed** (H-0046)

I need to implement error messages for the login form.

**Question**: What tone should error messages have?

**Options**:
a) Formal: "Authentication credentials are invalid"
b) Friendly: "Hmm, that password doesn't look right"
c) Technical: "401 Unauthorized: Invalid password"

**My recommendation**: (b) Friendly - matches the casual tone in other UI text

**Impact**: Low urgency, can continue with other parts of login feature

**Should I proceed with (b) or do you prefer a different tone?**
```

---

### Problem: Context window approaching limit

**Symptoms**: Long conversation, many file reads, approaching token limit

**Solutions**:
1. **Generate .continue-here.md immediately**:
   ```bash
   python3 .agentic/tools/continue_here.py
   ```
2. **Summarize key decisions** in JOURNAL.md before compaction
3. **Commit current work** (even if incomplete) to preserve state in git
4. **Tell human**: "Context window getting full. Should we wrap up this session and continue in a new one?"
5. **Claude Code users**: If hooks enabled, PreCompact hook will handle this automatically

**Prevention**: For long features, commit incrementally. Don't try to implement everything in one giant session.

---

### Problem: Lost track of what the human asked for

**Symptoms**: Mid-session, forgot the original request or changed direction

**Solutions**:
1. Scroll back in conversation to re-read original request
2. Check JOURNAL.md for what was agreed
3. Check STATUS.md for documented current focus
4. Ask human: "Just to confirm - we're working on F-0010 (Login UI), correct?"

**Prevention**: At start of work, explicitly restate what you're doing:
```
✅ **Starting Work**

Task: Implement F-0010 (Login UI)
Acceptance criteria: spec/acceptance/F-0010.md
Approach: TDD mode (tests first)
Est. time: 1-2 hours

Beginning now...
```

---

### Problem: Human is non-responsive mid-session

**Symptoms**: Asked question, waiting for answer, session is idle

**Solutions**:
1. **Don't block**: Find something else to work on that doesn't need the answer
2. **Document the question**: Add to HUMAN_NEEDED.md with context
3. **Suggest alternatives**: "While waiting for answer to H-0046, I can work on F-0012. Sound good?"
4. **Set a note**: Add JOURNAL.md entry explaining why you pivoted

**Template**:
```
⚠️ **Awaiting Input**

I asked about error message tone (H-0046) 20 minutes ago.

While waiting, I can:
a) Work on F-0012 (Password Reset - independent of H-0046)
b) Refactor existing code (doesn't need decisions)
c) Write more tests for existing features
d) Continue waiting

**I'll proceed with (a) unless you object.**
(Will resume login form once H-0046 is resolved)
```

---

## Implementation Notes

This operating loop is enforced by:
1. **session_start.md checklist** - What to check at start
2. **agent_operating_guidelines.md** - Rules for proactive behavior
3. **JOURNAL.md** - Provides continuity across sessions
4. **STATUS.md** - Provides planned work context
5. **HUMAN_NEEDED.md** - Makes blockers explicit and actionable

