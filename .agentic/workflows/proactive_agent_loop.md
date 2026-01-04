# Proactive Agent Operating Loop

**Purpose**: Make human-machine collaboration fluent by having agents proactively manage workflow, surface blockers, and suggest next steps.

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
2. `STATUS.md` or `PRODUCT.md` - Current focus & planned work
3. `JOURNAL.md` (last 2-3 entries) - Recent progress
4. `HUMAN_NEEDED.md` - Active blockers

### 2. Assess Project State

**Check for:**
- 🚩 **Blockers**: Items in HUMAN_NEEDED.md
- 🚩 **Stale work**: In-progress tasks from last session that weren't completed
- 🚩 **Awaiting acceptance**: Features marked "shipped" but not "accepted"
- 🚩 **Retrospective due**: If enabled and threshold met
- ✅ **Planned work**: Next items from STATUS.md or PRODUCT.md

### 3. Present Context & Options to Human

**Template**:

```
📊 **Session Context**

**Current Focus**: [from STATUS.md/PRODUCT.md]
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
- ✅ Check STATUS.md or PRODUCT.md for planned work
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
- ❌ Ignoring planned work in STATUS.md/PRODUCT.md

---

## Implementation Notes

This operating loop is enforced by:
1. **session_start.md checklist** - What to check at start
2. **agent_operating_guidelines.md** - Rules for proactive behavior
3. **JOURNAL.md** - Provides continuity across sessions
4. **STATUS.md / PRODUCT.md** - Provides planned work context
5. **HUMAN_NEEDED.md** - Makes blockers explicit and actionable

