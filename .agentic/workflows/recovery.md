# Recovery Protocol

**Purpose**: Structured recovery when work is interrupted, context resets, or agents fail mid-task.

**Core Principle**: Work should NEVER be lost. Always recoverable via WIP tracking + git state + documentation.

---

## When Recovery is Needed

**Detect these scenarios automatically at session start:**

1. **WIP.md exists** → Previous work interrupted (token limit, crash, etc.)
2. **Uncommitted changes in git** → Work in progress, not yet saved
3. **JOURNAL.md stale** (>24h) → Lost session continuity
4. **Features "in_progress" but no activity** → Abandoned work
5. **Context reset mid-feature** → Agent needs handoff information

---

## Recovery Protocol (Step-by-Step)

### Step 1: Detect Interrupted Work

**Run at EVERY session start** (`.agentic/checklists/session_start.md`):

```bash
bash .agentic/tools/wip.sh check
```

**Exit codes:**
- 0: No interrupted work (clean state)
- 1: Interrupted work detected (proceed to Step 2)

**If exit code 1, STOP and do NOT start new work until recovery is complete.**

---

### Step 2: Assess the Situation

**WIP.md provides:**
- Feature being worked on (e.g., F-0005: User Authentication)
- Agent/environment (claude-desktop, cursor, copilot)
- When work started
- Last checkpoint (when work was last updated)
- Files being edited
- Progress checklist

**Git provides:**
- Uncommitted changes: `git status`
- What changed: `git diff`
- Last committed state: `git log -1`

**SESSION_LOG.md provides:**
- Last checkpoint details
- What was being worked on
- Progress at last checkpoint

---

### Step 3: Determine Staleness

**Fresh WIP (<5 minutes since last checkpoint):**
- Likely an active handoff (environment switch)
- Or very recent interruption
- **Action**: Continue work (high confidence in state)

**Normal WIP (5-60 minutes):**
- Token limit reached or intentional break
- **Action**: Review git diff, then continue or rollback

**Stale WIP (>60 minutes):**
- Agent crashed or stopped abruptly
- Work state uncertain
- **Action**: Review git diff carefully, likely rollback

---

### Step 4: Recovery Decision Tree

```
Interrupted work detected
       ↓
[1] Review git diff
       ↓
    Is code complete and working?
       ├─ YES → Continue & complete
       └─ NO → Is code salvageable?
              ├─ YES → Continue & fix
              └─ NO → Rollback

git diff <files>  # Review what changed
```

**Decision factors:**
- **Code quality**: Syntax errors? Logic complete?
- **Test status**: Tests exist? Tests pass?
- **Time elapsed**: <1h (likely good), >1h (uncertain)
- **Checkpoint notes**: What was last done? Clear or vague?

---

### Step 5: Execute Recovery Action

#### Option A: Continue Work (git state looks good)

**When**:
- Git diff shows reasonable, working code
- Last checkpoint was clear about next steps
- Tests pass (or no tests broken)
- Work is >70% complete

**Actions**:
1. Acknowledge interrupted work to user:
   > "Previous work on ${FEATURE} was interrupted ${TIME_AGO}.
   > Last checkpoint: '${LAST_CHECKPOINT}'.
   > Reviewed git diff: code looks good, will continue."

2. Resume from checkpoint:
   - Read WIP.md progress checklist
   - Continue from last unchecked item
   - Update WIP checkpoint as you work:
     ```bash
     bash .agentic/tools/wip.sh checkpoint "Resuming: implementing token validation"
     ```

3. Complete work normally:
   - Finish implementation
   - Run tests
   - `bash .agentic/tools/wip.sh complete`
   - Commit

---

#### Option B: Review & Fix (git state uncertain)

**When**:
- Git diff shows partial implementation
- Code has obvious issues (syntax errors, incomplete logic)
- Tests are broken
- Work is 30-70% complete

**Actions**:
1. Acknowledge to user:
   > "Previous work interrupted. Reviewed git diff: partial implementation found.
   > Will review and fix issues before continuing."

2. Review each changed file:
   ```bash
   git diff <file>  # Review changes
   ```

3. Fix issues:
   - Syntax errors
   - Incomplete logic
   - Broken tests

4. Update WIP and continue:
   ```bash
   bash .agentic/tools/wip.sh checkpoint "Fixed issues from interruption, continuing"
   ```

---

#### Option C: Rollback (git state broken/unusable)

**When**:
- Git diff shows fundamentally broken code
- No clear path to fix
- Work is <30% complete or completely wrong direction
- Stale (>60 min) with unclear checkpoint

**Actions**:
1. Inform user:
   > "Previous work interrupted and is incomplete/broken.
   > Recommend rollback to last commit. OK to proceed?"

2. Wait for user approval

3. Rollback:
   ```bash
   git reset --hard  # Nuclear: discard all changes
   # OR
   git checkout -- <file>  # Discard specific file
   ```

4. Clean WIP:
   ```bash
   bash .agentic/tools/wip.sh complete  # Remove lock
   ```

5. Start fresh:
   - Re-plan the feature
   - Start with clean slate
   - Create new WIP:
     ```bash
     bash .agentic/tools/wip.sh start F-#### "description" "files"
     ```

---

## Recovery from Specific Scenarios

### Scenario 1: Token Limit Reached Mid-Edit

**Symptoms**:
- WIP.md exists
- Last checkpoint recent (<30 min)
- Git diff shows work in progress

**Recovery**:
- **Confidence**: HIGH (recent checkpoint)
- **Action**: Continue work (Option A)
- **Why**: Work was actively checkpointed, state is known

**Example**:
```bash
bash .agentic/tools/wip.sh check
# "Interrupted 15 minutes ago. Last: 'Login endpoint done, starting JWT'"
git diff src/auth/login.ts
# Shows partial JWT implementation
# Continue implementing JWT validation
```

---

### Scenario 2: Tool Crash / Computer Restart

**Symptoms**:
- WIP.md exists
- Last checkpoint 15-60 min ago
- Git diff shows partial work
- Uncertainty about work state

**Recovery**:
- **Confidence**: MEDIUM (depends on git diff)
- **Action**: Review & Fix (Option B) or Rollback (Option C)
- **Why**: Crash may have interrupted mid-thought, code may be incomplete

**Example**:
```bash
bash .agentic/tools/wip.sh check
# "STALE: 45 minutes ago. Last: 'Implementing token validation'"
git diff src/auth/login.ts
# Shows incomplete function, syntax error
# Option B: Fix syntax, complete function
# OR Option C: Rollback if too broken
```

---

### Scenario 3: Context Compaction (Claude)

**Symptoms**:
- WIP.md updated by PreCompact hook
- Checkpoint says "Context compaction triggered"
- Git diff shows work in progress

**Recovery**:
- **Confidence**: HIGH (automatic checkpoint)
- **Action**: Continue work (Option A)
- **Why**: PreCompact hook ensures clean state before reset

**Example**:
```bash
bash .agentic/tools/wip.sh check
# "5 minutes ago. Last: 'Context compaction triggered'"
# PreCompact hook updated WIP automatically
# Continue seamlessly from checkpoint
```

---

### Scenario 4: Environment Switch (Multi-Agent)

**Symptoms**:
- WIP.md exists
- Last checkpoint says "Switching to [tool]"
- Checkpoint very recent (<5 min)
- Git diff shows active work

**Recovery**:
- **Confidence**: HIGH (explicit handoff)
- **Action**: Continue work (Option A)
- **Why**: Intentional handoff, state is known

**Example**:
```bash
bash .agentic/tools/wip.sh check
# "3 minutes ago. Last: 'Switching from Claude to Cursor'"
# Explicit handoff, continue work
```

---

### Scenario 5: Abandoned Work (Stale)

**Symptoms**:
- WIP.md exists
- Last checkpoint >24 hours ago
- Git diff shows old changes
- Unclear what was being done

**Recovery**:
- **Confidence**: LOW (very stale)
- **Action**: Rollback (Option C) or Escalate to Human
- **Why**: Too old to trust, likely abandoned

**Example**:
```bash
bash .agentic/tools/wip.sh check
# "STALE: 2 days ago. Last: 'Working on auth'"
# Add to HUMAN_NEEDED.md for review
# Likely rollback and restart
```

---

## Integration with HUMAN_NEEDED.md

**When recovery is ambiguous or impossible, escalate:**

```markdown
### HN-####: Interrupted Work Requires Human Review

**Type**: Recovery Decision
**Blocker**: Yes

**Context**:
- Feature F-0005: User Authentication was interrupted 2 days ago
- Last checkpoint: "Working on JWT validation"
- Git diff shows partial implementation with unclear intent
- Agent unable to determine if work is salvageable

**Options**:
1. Review git diff and provide guidance on continuing
2. Approve rollback to last commit and restart
3. Provide context on what was being implemented

**Files affected**:
- src/auth/login.ts (45 lines changed)
- src/auth/types.ts (new file, 23 lines)
- tests/auth/login.test.ts (12 lines changed)

**Requested**: Please review git diff and decide recovery action.
```

---

## Recovery Best Practices

### 1. Checkpoint Frequently

**Good** ✅:
```bash
# Every ~15 minutes or after significant step
bash .agentic/tools/wip.sh checkpoint "Login endpoint complete"
bash .agentic/tools/wip.sh checkpoint "JWT validation added"
bash .agentic/tools/wip.sh checkpoint "Unit tests passing"
```

**Bad** ❌:
```bash
# Only at start, then nothing for 2 hours
bash .agentic/tools/wip.sh start F-0005 "Auth"
# (work for 2 hours, no checkpoints)
# (crash - no idea what was done)
```

### 2. Use Descriptive Checkpoint Messages

**Good** ✅:
- "Login endpoint complete, starting JWT validation"
- "JWT validation done, 3/5 tests passing, fixing test 4"
- "All tests green, refactoring for clarity"

**Bad** ❌:
- "Working"
- "Progress"
- "Stuff"

### 3. Commit Often

**Reduce risk by committing working increments:**
- Small working feature → Commit
- Tests passing → Commit
- Refactoring complete → Commit

**WIP is for interruptions, not long-running work.**

### 4. Trust Git Diff

**Always review `git diff` before continuing interrupted work:**
```bash
git diff                    # All changes
git diff <file>             # Specific file
git diff --stat             # Summary only
git log -1 --stat          # Last commit for reference
```

---

## Summary

**Recovery Protocol Steps:**
1. **Detect**: `wip.sh check` at session start
2. **Assess**: Review WIP.md + git diff + SESSION_LOG.md
3. **Determine**: Fresh (<5min) | Normal (5-60min) | Stale (>60min)
4. **Decide**: Continue | Review & Fix | Rollback
5. **Execute**: Follow decision tree, update WIP, resume work
6. **Escalate**: Add to HUMAN_NEEDED.md if uncertain

**Key Tools:**
- `wip.sh check` - Detect interrupted work
- `git diff` - See what changed
- `git status` - See which files affected
- `SESSION_LOG.md` - Last checkpoint details
- `HUMAN_NEEDED.md` - Escalate ambiguous cases

**Confidence Levels:**
- HIGH: Fresh checkpoint, clear next steps, working code → Continue
- MEDIUM: Partial code, some issues → Review & Fix
- LOW: Stale, broken, or unclear → Rollback

**Never guess.** When uncertain, escalate to human via HUMAN_NEEDED.md.

