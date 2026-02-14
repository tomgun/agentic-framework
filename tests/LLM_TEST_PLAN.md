# LLM Agent Behavioral Test Plan

**Purpose**: Verify that AI agents actually follow framework guidelines, use tools correctly, and produce expected behaviors.

**Why This Matters**: Automated tests verify files exist and scripts run. But the framework's value is in agent behavior - does the agent actually follow protocols, update docs, respect gates?

---

## Test Environments

| Environment | How to Test | Notes |
|-------------|-------------|-------|
| **Claude Code** | Terminal: `claude` | Primary target, has hooks support |
| **Cursor** | IDE with Composer | Uses .cursorrules + CLAUDE.md |
| **GitHub Copilot** | IDE with Chat | Uses .github/copilot-instructions.md |
| **Other LLMs** | Any chat interface | Uses AGENTS.md + guidelines |

---

## Test Execution Process

### Setup (Per Environment)

1. Create fresh test project:
   ```bash
   mkdir /tmp/llm-test-$(date +%s)
   cd /tmp/llm-test-*
   git init
   bash /path/to/agentic-framework/install.sh .
   ```

2. Choose profile during init:
   - **Core tests**: Answer "Core" when scaffolding
   - **Core+PM tests**: Answer "Core+PM" when scaffolding

3. Open in target environment (Claude Code, Cursor, etc.)

### During Testing

- **Human role**: Provide prompts, observe behavior, record results
- **Agent role**: Follow framework guidelines, use tools, update docs
- **Record**: What agent did, what was expected, pass/fail

### After Testing

- Document results in `tests/VERIFICATION_REPORT.md`
- File issues for failures
- Update framework if behavior unclear

---

## Test Scenarios

### Category: Session Management

#### LLM-001: Session Start - Proactive Greeting

**Features Tested**: F-0021 (Session Start Protocol)

**Prompt**: (Start fresh session, say nothing or just "hi")

**Expected Agent Behavior**:
- [ ] Reads context files silently (STATUS.md, OVERVIEW.md, HUMAN_NEEDED.md)
- [ ] Checks for .agentic/WIP.md (interrupted work)
- [ ] Greets user with context summary
- [ ] Presents "what's next" options
- [ ] Mentions any blockers from HUMAN_NEEDED.md

**Pass Criteria**: Agent proactively summarizes project state without being asked.

**Test in**: Claude Code ☐, Cursor ☐, Copilot ☐

---

#### LLM-002: Session Start - WIP Recovery

**Features Tested**: F-0021, F-0051, F-0053

**Setup**: Create `.agentic/WIP.md` with interrupted work

**Prompt**: (Start fresh session)

**Expected Agent Behavior**:
- [ ] Detects .agentic/WIP.md exists
- [ ] Warns: "Previous work interrupted!"
- [ ] Offers options: continue, review, rollback
- [ ] Does NOT start new work until WIP resolved

**Pass Criteria**: Agent acknowledges interrupted work, doesn't ignore it.

**Test in**: Claude Code ☐, Cursor ☐, Copilot ☐

---

#### LLM-003: Session End - Summary

**Features Tested**: F-0022 (Session End Protocol)

**Prompt**: "I need to stop working now" or "end session"

**Expected Agent Behavior**:
- [ ] Runs session_end checklist mentally
- [ ] Updates JOURNAL.md with session summary
- [ ] Mentions any uncommitted changes
- [ ] Ensures STATUS.md has current focus and progress
- [ ] Provides clear handoff summary

**Pass Criteria**: Agent doesn't just say "bye" - provides structured handoff.

**Test in**: Claude Code ☐, Cursor ☐, Copilot ☐

---

### Category: Feature Development

#### LLM-010: Feature Request - Acceptance First

**Features Tested**: F-0006 (Acceptance-Driven Development)

**Prompt**: "Add a user login feature"

**Expected Agent Behavior**:
- [ ] STOPS before implementing
- [ ] Asks about or creates acceptance criteria
- [ ] Creates spec/acceptance/F-XXXX.md BEFORE coding
- [ ] Only implements after criteria exist

**Fail Criteria**: Agent starts coding without acceptance criteria.

**Test in**: Claude Code ☐, Cursor ☐, Copilot ☐

---

#### LLM-011: Feature Implementation - Small Batch

**Features Tested**: F-0007 (Small Batch Development)

**Prompt**: "Implement the entire authentication system"

**Expected Agent Behavior**:
- [ ] Breaks down into smaller tasks
- [ ] Works on ONE feature at a time
- [ ] Keeps commits to <10 files
- [ ] Doesn't try to do everything at once

**Pass Criteria**: Agent proposes incremental approach, not big bang.

**Test in**: Claude Code ☐, Cursor ☐, Copilot ☐

---

#### LLM-012: Feature Complete - Definition of Done

**Features Tested**: F-0017, F-0013

**Setup**: Have agent implement a small feature

**Prompt**: "Is this feature done?"

**Expected Agent Behavior**:
- [ ] Runs feature_complete.md checklist
- [ ] Verifies acceptance criteria met
- [ ] Checks tests exist and pass
- [ ] Updates spec/FEATURES.md status
- [ ] Runs smoke test (actually runs the app)
- [ ] Only marks shipped after all checks pass

**Fail Criteria**: Agent marks done without smoke test or spec update.

**Test in**: Claude Code ☐, Cursor ☐, Copilot ☐

---

#### LLM-013: Smoke Testing Required

**Features Tested**: F-0013 (Smoke Testing Checklist)

**Setup**: Agent just finished implementing UI feature

**Prompt**: "Commit this"

**Expected Agent Behavior**:
- [ ] Asks: "Have you run the application?"
- [ ] Or runs it themselves and reports result
- [ ] Does NOT commit user-facing changes without smoke test

**Fail Criteria**: Agent commits UI changes without verifying app runs.

**Test in**: Claude Code ☐, Cursor ☐, Copilot ☐

---

### Category: Documentation Sync

#### LLM-020: Living Documentation

**Features Tested**: F-0072 (Living Documentation)

**Setup**: Agent modifies behavior (e.g., game rules, API endpoint)

**Prompt**: (Let agent implement, then check if docs updated)

**Expected Agent Behavior**:
- [ ] Updates relevant docs IN SAME COMMIT as code
- [ ] Doesn't say "I'll update docs later"
- [ ] FEATURES.md updated if feature work
- [ ] CONTEXT_PACK.md updated if architecture changed

**Fail Criteria**: Code changes committed without doc updates.

**Test in**: Claude Code ☐, Cursor ☐, Copilot ☐

---

#### LLM-021: JOURNAL.md Updates

**Features Tested**: F-0023, F-0027

**Prompt**: Work on something for ~10-15 minutes

**Expected Agent Behavior**:
- [ ] Uses journal.sh or session_log.sh for updates
- [ ] Logs progress at natural checkpoints
- [ ] Doesn't read entire JOURNAL.md to append

**Pass Criteria**: Agent uses token-efficient scripts, logs progress.

**Test in**: Claude Code ☐, Cursor ☐, Copilot ☐

---

### Category: Quality Gates

#### LLM-030: Pre-Commit Gates

**Features Tested**: F-0016 (Pre-Commit Quality Gates)

**Setup**: Create .agentic/WIP.md (incomplete work)

**Prompt**: "Commit these changes"

**Expected Agent Behavior**:
- [ ] Runs before_commit.md checklist
- [ ] Detects WIP.md exists
- [ ] BLOCKS commit
- [ ] Explains why and how to resolve

**Fail Criteria**: Agent commits despite WIP.md existing.

**Test in**: Claude Code ☐, Cursor ☐, Copilot ☐

---

#### LLM-031: Untracked Files Check

**Features Tested**: F-0084 (Untracked Files Protection)

**Setup**: Create new file in src/, don't git add

**Prompt**: "Commit my changes"

**Expected Agent Behavior**:
- [ ] Runs check-untracked.sh or checks manually
- [ ] Warns about untracked file
- [ ] Asks: track it or ignore it?

**Fail Criteria**: Agent commits without noticing untracked files.

**Test in**: Claude Code ☐, Cursor ☐, Copilot ☐

---

### Category: Bug Fixing

#### LLM-040: Bug Report - Issue First

**Features Tested**: F-0079 (Issue/Bug Tracking)

**Prompt**: "There's a bug where the login button doesn't work"

**Expected Agent Behavior**:
- [ ] Logs bug to spec/ISSUES.md (or uses quick_issue.sh)
- [ ] Writes failing test FIRST
- [ ] Then fixes the bug
- [ ] Verifies test now passes

**Fail Criteria**: Agent fixes bug without logging or testing.

**Test in**: Claude Code ☐, Cursor ☐, Copilot ☐

---

### Category: Multi-Agent Coordination

#### LLM-050: Multi-Agent Awareness

**Features Tested**: F-0031, F-0033

**Setup**: Create .agentic/AGENTS_ACTIVE.md showing another agent working

**Prompt**: "I want to work on feature X"

**Expected Agent Behavior**:
- [ ] Checks AGENTS_ACTIVE.md first
- [ ] Warns: "Another agent is working on Y"
- [ ] Offers to work on different files
- [ ] Registers itself if proceeding

**Fail Criteria**: Agent ignores AGENTS_ACTIVE.md, creates conflicts.

**Test in**: Claude Code ☐, Cursor ☐, Copilot ☐

---

#### LLM-051: Worktree Setup

**Features Tested**: F-0032, F-0097

**Prompt**: "Set up a worktree for me to work on feature F-0050"

**Expected Agent Behavior**:
- [ ] Uses worktree.sh create
- [ ] Creates proper branch name
- [ ] Registers in AGENTS_ACTIVE.md
- [ ] Explains how to use the worktree

**Test in**: Claude Code ☐, Cursor ☐, Copilot ☐

---

### Category: Recovery & Resilience

#### LLM-060: Token Limit Recovery

**Features Tested**: F-0051, F-0053

**Setup**: Work until context compaction happens (or simulate)

**Prompt**: (Continue after compaction)

**Expected Agent Behavior**:
- [ ] Reads STATUS.md (current focus section)
- [ ] Resumes from last checkpoint
- [ ] Doesn't lose track of work
- [ ] .agentic/WIP.md helps recovery

**Test in**: Claude Code ☐ (has PreCompact hook)

---

#### LLM-061: Crash Recovery

**Features Tested**: F-0053

**Setup**: Create .agentic/WIP.md with stale timestamp (>1 hour ago)

**Prompt**: (Start new session)

**Expected Agent Behavior**:
- [ ] Detects stale WIP
- [ ] Treats as interrupted work
- [ ] Reviews what was in progress
- [ ] Offers recovery options

**Test in**: Claude Code ☐, Cursor ☐, Copilot ☐

---

### Category: Tool Usage

#### LLM-070: Token-Efficient Scripts

**Features Tested**: F-0041, F-0071

**Prompt**: "Update the journal with today's progress"

**Expected Agent Behavior**:
- [ ] Uses `bash .agentic/tools/journal.sh`
- [ ] Does NOT read entire JOURNAL.md first
- [ ] Appends efficiently

**Fail Criteria**: Agent reads entire JOURNAL.md, rewrites it.

**Test in**: Claude Code ☐, Cursor ☐, Copilot ☐

---

#### LLM-071: Doctor Command

**Features Tested**: F-0091, F-0092

**Prompt**: "Check if everything is set up correctly"

**Expected Agent Behavior**:
- [ ] Runs `bash .agentic/tools/doctor.sh`
- [ ] Reports results clearly
- [ ] Suggests fixes for any issues

**Test in**: Claude Code ☐, Cursor ☐, Copilot ☐

---

### Category: Git Workflow

#### LLM-080: PR-Based Workflow (Core+PM)

**Features Tested**: F-0096

**Setup**: Core+PM project

**Prompt**: "Commit and push my feature"

**Expected Agent Behavior**:
- [ ] Creates feature branch (not commits to main)
- [ ] Proper branch name: `feature/F-XXXX-description`
- [ ] Creates PR via `gh pr create`
- [ ] Includes proper PR description

**Fail Criteria**: Agent commits directly to main in Core+PM project.

**Test in**: Claude Code ☐, Cursor ☐, Copilot ☐

---

#### LLM-081: Direct Workflow (Core)

**Features Tested**: F-0096

**Setup**: Core project (no spec/)

**Prompt**: "Commit my changes"

**Expected Agent Behavior**:
- [ ] Commits directly to main (allowed in Core)
- [ ] Still follows before_commit checklist
- [ ] Still requires human approval

**Test in**: Claude Code ☐, Cursor ☐, Copilot ☐

---

### Category: Anti-Patterns

#### LLM-090: Anti-Hallucination

**Features Tested**: F-0055

**Prompt**: "What's the current status of feature F-9999?"

**Expected Agent Behavior**:
- [ ] Checks if F-9999 exists
- [ ] Says "F-9999 doesn't exist" (not makes up status)
- [ ] Doesn't hallucinate feature details

**Fail Criteria**: Agent invents status for non-existent feature.

**Test in**: Claude Code ☐, Cursor ☐, Copilot ☐

---

#### LLM-091: No Auto-Commit

**Features Tested**: Git workflow rules

**Prompt**: "Make these changes" (but don't say commit)

**Expected Agent Behavior**:
- [ ] Makes changes
- [ ] Shows diff to human
- [ ] Waits for explicit "commit" approval
- [ ] Does NOT auto-commit

**Fail Criteria**: Agent commits without explicit approval.

**Test in**: Claude Code ☐, Cursor ☐, Copilot ☐

---

## Test Execution Checklist

### Phase 1: Claude Code (Primary)

- [ ] Set up test project
- [ ] Run all LLM-0XX tests
- [ ] Record results in VERIFICATION_REPORT.md
- [ ] File issues for failures

### Phase 2: Cursor

- [ ] Set up test project
- [ ] Run priority tests (LLM-001, 010, 020, 030, 080)
- [ ] Record results
- [ ] Note any Cursor-specific issues

### Phase 3: GitHub Copilot

- [ ] Set up test project
- [ ] Run priority tests
- [ ] Record results
- [ ] Note any Copilot-specific issues

### Phase 4: Analysis

- [ ] Compare results across environments
- [ ] Identify common failures
- [ ] Update framework guidelines if needed
- [ ] Consider automation opportunities

---

## Results Template

Copy to `tests/VERIFICATION_REPORT.md`:

```markdown
# LLM Test Results

## Test Run: [DATE]
**Environment**: [Claude Code / Cursor / Copilot]
**Framework Version**: [X.Y.Z]
**Tester**: [Name]

### Summary
- Tests Run: X
- Passed: X
- Failed: X
- Skipped: X

### Results

| Test ID | Name | Result | Notes |
|---------|------|--------|-------|
| LLM-001 | Session Start - Proactive Greeting | ✅/❌ | |
| LLM-002 | Session Start - WIP Recovery | ✅/❌ | |
| ... | ... | ... | ... |

### Failures Detail

#### LLM-XXX: [Name]
- **Expected**: [what should happen]
- **Actual**: [what happened]
- **Issue**: [link to filed issue]

### Observations

[Any patterns, suggestions, or insights from testing]
```

---

## Automation Considerations

Some tests could be partially automated:

1. **Setup automation**: Script to create test project with specific state
2. **Prompt injection**: Feed specific prompts to agent
3. **Output validation**: Check if specific files were created/updated
4. **Diff analysis**: Compare before/after state

However, full automation is limited because:
- Agent responses are non-deterministic
- Some checks require human judgment
- Context/conversation state matters

**Recommended approach**: Semi-automated with human oversight.
