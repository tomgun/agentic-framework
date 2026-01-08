# Automatic Journaling Workflow

**Purpose**: Log progress automatically at natural checkpoints WITHOUT waiting for session end or user reminders.

**Why**: If session crashes, loses context, or ends abruptly, logs preserve what was done.

**Token efficiency**: Use append-only SESSION_LOG.md for quick updates, full JOURNAL.md for meaningful milestones.

---

## When to Auto-Journal (Natural Checkpoints)

**⚡ IMMEDIATE (append to SESSION_LOG.md):**
- After completing a feature
- After fixing a bug
- After making an architectural decision
- After discovering a blocker
- After significant refactoring
- Every ~30 minutes of focused work

**📝 MILESTONE (update JOURNAL.md):**
- After completing a major feature (F-####)
- After init/setup sessions
- After retrospectives
- Before context window compaction
- Before ending session

---

## Quick Logging (SESSION_LOG.md)

**Use the append-only tool** (no file reads, token-efficient):

```bash
bash .agentic/tools/session_log.sh \
  "Feature F-0003 complete" \
  "Implemented user login with JWT tokens. Tests passing. Ready for review." \
  "files=auth.ts+login.test.ts,tests=8 passing"
```

**From code (agents can call this)**:

```python
import subprocess
subprocess.run([
    "bash", ".agentic/tools/session_log.sh",
    "Bug fix: Memory leak in WebSocket",
    "Fixed leak by properly closing connections. Added test. Memory stable.",
    "files=ws-client.ts,tests=added"
])
```

**What gets logged** (appended, not rewritten):

```markdown
## 2026-01-06 14:30 - Feature F-0003 complete

Implemented user login with JWT tokens. Tests passing. Ready for review.

- **files**: auth.ts, login.test.ts
- **tests**: 8 passing
---
```

---

## Milestone Logging (JOURNAL.md)

**When milestone reached, update JOURNAL.md** (format from `.agentic/spec/JOURNAL.reference.md`):

```markdown
### Session: 2026-01-06 14:00

**Feature**: F-0003 (User Authentication)

**Accomplished**:
- Implemented JWT token generation and validation
- Added bcrypt password hashing
- Created login and signup endpoints
- 8 unit tests, all passing

**Next steps**:
- Implement refresh token mechanism
- Add email verification
- Update FEATURES.md

**Blockers**: None
```

---

## Automatic Triggers (For Agents)

### 1. After Tool Use (Natural Checkpoint)

**If you just:**
- Ran tests successfully → Quick log
- Fixed linting errors → Quick log
- Completed a file → Quick log
- Made a commit → Quick log

**Quick log command:**
```bash
bash .agentic/tools/session_log.sh \
  "Tests passing" \
  "All 23 tests now passing after bug fix" \
  "tests=23 passing"
```

### 2. After Significant Work Block (~30-60 min)

**Mental checklist:**
- Have I made meaningful progress?
- Would I lose important context if session ended now?

**If yes → Quick log:**
```bash
bash .agentic/tools/session_log.sh \
  "Progress on F-0005" \
  "Implemented 3 of 5 acceptance criteria. Database schema created. API endpoints stubbed." \
  "feature=F-0005,progress=60%"
```

### 3. Before Context Window Compaction (Claude)

**Claude hook already exists** (`.agentic/claude-hooks/PreCompact.sh`), enhance it:

```bash
# Add to PreCompact.sh:
bash .agentic/tools/session_log.sh \
  "Context compaction" \
  "Saving state before context reset. Last worked on: ${CURRENT_TASK}" \
  "checkpoint=pre-compact"
```

### 4. On Discovery (Blocker/Decision)

**As soon as you identify:**
- Blocker → Add to HUMAN_NEEDED.md AND quick log
- Decision → Add to ADR AND quick log
- Insight → Quick log

**Example:**
```bash
# After adding HN-0001 to HUMAN_NEEDED.md:
bash .agentic/tools/session_log.sh \
  "Blocker discovered" \
  "GUT plugin needs manual install. Added HN-0001." \
  "blocker=HN-0001,severity=high"
```

---

## Integration with Existing Workflows

### In `feature_implementation.md` (add):

**After each acceptance criterion satisfied:**
```bash
bash .agentic/tools/session_log.sh \
  "F-${FEATURE_ID}: Criterion ${N} done" \
  "$(describe what was done)" \
  "feature=F-${FEATURE_ID},criteria=${N}/${TOTAL}"
```

### In `before_commit.md` (add):

**After tests pass, before committing:**
```bash
bash .agentic/tools/session_log.sh \
  "Ready to commit" \
  "$(git diff --stat)" \
  "files=$(git diff --name-only | wc -l),tests=passing"
```

### In `session_end.md` (enhance):

**Before ending, consolidate SESSION_LOG.md → JOURNAL.md:**
1. Read recent SESSION_LOG.md entries (since last JOURNAL update)
2. Synthesize into JOURNAL.md milestone entry
3. Note: SESSION_LOG.md stays append-only (never trim it)

---

## Token Economics

**SESSION_LOG.md:**
- ✅ Append-only (no full file reads)
- ✅ Quick updates (1-2 lines)
- ✅ Cheap to write
- ⚠️ Grows forever (periodically archive old entries to `docs/session_log_archive/`)

**JOURNAL.md:**
- ⚠️ Requires full file read/write
- ✅ Structured, meaningful entries
- ✅ Synced with feature milestones
- ✅ Used for session continuity

**Rule of thumb:**
- Quick update (< 30 sec) → SESSION_LOG.md
- Milestone (feature complete) → JOURNAL.md
- Session end → Consolidate both

---

## Example Session Flow

```
14:00 - Start work on F-0003 (User Auth)
      - session_start.md checklist
      
14:15 - Implement JWT token generation
      → bash session_log.sh "JWT tokens implemented" "..."
      
14:35 - Add password hashing
      → bash session_log.sh "Password hashing added" "..."
      
14:50 - Tests passing
      → bash session_log.sh "Tests passing (8/8)" "..."
      
15:00 - Feature complete
      → Update JOURNAL.md (milestone)
      → Update FEATURES.md (State: complete)
      
15:10 - Ready to commit
      → bash session_log.sh "Ready to commit" "..."
      → before_commit.md checklist
      
15:15 - Session end
      - session_end.md checklist
      - Review SESSION_LOG.md entries
      - Ensure JOURNAL.md has final summary
```

**Result**: If session crashes at any point, SESSION_LOG.md has record of progress. JOURNAL.md has milestone entries.

---

## For Agents: Quick Reference

**Checkpoint Rule**: After ANY significant action, ask yourself:
1. Would I lose important context if session ended now?
2. Is this a natural milestone (feature done, bug fixed, decision made)?

**If yes:**
```bash
bash .agentic/tools/session_log.sh "What I did" "Details" "key=value,key2=value2"
```

**Don't wait for:**
- User reminder
- Session end
- TODO item

**Just do it automatically at natural checkpoints.**

---

## Anti-Patterns

❌ **Don't** wait until session end to log everything  
❌ **Don't** rewrite JOURNAL.md constantly (expensive)  
❌ **Don't** log every tiny action (too noisy)  
❌ **Don't** forget to log if session is going well (that's when crashes happen!)  

✅ **Do** log at natural checkpoints  
✅ **Do** use append-only SESSION_LOG.md for quick updates  
✅ **Do** consolidate to JOURNAL.md at milestones  
✅ **Do** log discoveries (blockers, decisions, insights) immediately  

---

## Summary

**Automatic journaling = resilience**

- SESSION_LOG.md: Quick, append-only, cheap
- JOURNAL.md: Milestone-based, structured, meaningful
- Trigger: Natural checkpoints, not reminders
- Token-efficient: Append don't rewrite

**If you're doing meaningful work, log it. Don't wait.**

