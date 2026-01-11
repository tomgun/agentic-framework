# Automatic Orchestration Rules

**Purpose**: Agents automatically detect task type and follow the correct systematic process.

**🚨 CRITICAL**: These rules are NON-NEGOTIABLE. Follow them without user prompting.

---

## Auto-Detection Triggers

| User Request Pattern | Auto-Trigger | What To Do |
|---------------------|--------------|------------|
| "implement F-####" / "build feature" / "create [feature]" | **Feature Pipeline** | Follow Feature Implementation flow |
| "fix I-####" / "fix bug" / "fix issue" | **Issue Pipeline** | Follow Issue Resolution flow |
| "start session" / (first message) | **Session Start** | Run `session_start.md` checklist |
| "commit" / "ready to commit" | **Before Commit** | Run `before_commit.md` checklist |
| "done with feature" / "feature complete" | **Feature Complete** | Run `feature_complete.md` checklist |
| "end session" / "stopping work" | **Session End** | Run `session_end.md` checklist |
| "review code" / "check this" | **Review** | Run `review_checklist.md` |

---

## Feature Pipeline (AUTO-INVOKED)

**Trigger**: User mentions implementing a feature (F-#### or general)

### Automatic Steps (DO ALL OF THESE)

```
1. VERIFY ACCEPTANCE CRITERIA EXIST
   ├─ Core+PM: Check spec/acceptance/F-####.md exists
   ├─ Core: Check PRODUCT.md has criteria
   └─ If missing: CREATE THEM FIRST (rough is OK)
   
2. CHECK DEVELOPMENT MODE
   └─ Read STACK.md → development_mode (default: standard)
   
3. IMPLEMENT
   ├─ Write code meeting acceptance criteria
   ├─ Add @feature annotations
   └─ Keep small, focused changes
   
4. TEST
   ├─ Write/run tests verifying acceptance criteria
   ├─ All tests must pass
   └─ Smoke test: RUN THE APPLICATION
   
5. UPDATE SPECS (MANDATORY - NOT OPTIONAL)
   ├─ Core+PM: Update spec/FEATURES.md status
   ├─ Core: Update PRODUCT.md
   └─ This is part of "done", not afterthought
   
6. UPDATE DOCS
   ├─ JOURNAL.md (what was accomplished)
   ├─ CONTEXT_PACK.md (if architecture changed)
   └─ STATUS.md (next steps)
   
7. BEFORE COMMIT
   └─ Run before_commit.md checklist
```

### Non-Negotiable Gates

| Gate | Check | Block If |
|------|-------|----------|
| Acceptance Criteria | `spec/acceptance/F-####.md` exists | Missing = cannot proceed |
| Tests Pass | Run test suite | Any failure = cannot ship |
| Smoke Test | Actually run the app | Doesn't work = cannot ship |
| Specs Updated | FEATURES.md or PRODUCT.md current | Stale = cannot commit |
| No Untracked Files | `check-untracked.sh` clean | Untracked = warn before commit |

---

## Issue Pipeline (AUTO-INVOKED)

**Trigger**: User mentions fixing an issue (I-#### or general bug)

### Automatic Steps

```
1. UNDERSTAND THE ISSUE
   ├─ Read spec/ISSUES.md for I-#### details
   ├─ Or understand user's bug description
   └─ Identify reproduction steps
   
2. WRITE FAILING TEST
   └─ Test that proves the bug exists
   
3. FIX THE BUG
   └─ Minimal code change to fix
   
4. VERIFY TEST PASSES
   └─ The bug test now passes
   
5. SMOKE TEST
   └─ Actually run the app, verify fix works
   
6. UPDATE ISSUES.MD
   └─ Status: closed, Resolution: fixed
   
7. BEFORE COMMIT
   └─ Run before_commit.md checklist
```

---

## Session Start (AUTO-INVOKED)

**Trigger**: First message of a session, or user says "start session"

### Automatic Steps

```
1. CHECK FOR UPGRADE
   └─ cat .agentic/.upgrade_pending (follow if exists)
   
2. CHECK FOR WIP
   └─ ls WIP.md (resume if exists)
   
3. READ CONTEXT
   ├─ STATUS.md (what's current focus)
   ├─ HUMAN_NEEDED.md (any blockers resolved?)
   └─ JOURNAL.md (last session summary)
   
4. CONFIRM WITH USER
   └─ "Continuing from [X]. Should I proceed or change focus?"
```

---

## Feature Complete (AUTO-INVOKED)

**Trigger**: User says "feature done" or agent believes feature is complete

### Automatic Checks (ALL MUST PASS)

```
□ All acceptance criteria met
□ Smoke test passed (actually ran the app)
□ All tests pass
□ FEATURES.md/PRODUCT.md updated with status: shipped
□ Code annotations added (@feature, @acceptance)
□ JOURNAL.md updated
□ No untracked files
□ Ready for human validation
```

**If any fail**: Do NOT mark as shipped. Complete the missing item first.

---

## Before Commit (AUTO-INVOKED)

**Trigger**: User says "commit" or agent is about to commit

### Automatic Checks (ALL MUST PASS)

```
□ No WIP.md exists (work is complete)
□ All tests pass
□ Smoke test passed (for user-facing changes)
□ Quality checks pass (if enabled)
□ FEATURES.md/PRODUCT.md updated
□ JOURNAL.md updated
□ No untracked files in project directories
□ Human approval obtained
```

**If any fail**: Do NOT commit. Fix first.

---

## Agent Delegation (When Using Sub-Agents)

If you're the **Orchestrator Agent** or coordinating multiple agents:

### Verify Each Agent's Work

| Agent | Verify Before Moving On |
|-------|-------------------------|
| Planning | `spec/acceptance/F-####.md` exists with testable criteria |
| Test | Tests exist and currently FAIL |
| Implementation | Tests now PASS |
| Review | No critical issues raised |
| Spec Update | FEATURES.md shows `Status: shipped` |
| Documentation | Relevant docs updated |
| Git | Commit message clear, all files tracked |

### Block If Quality Gates Fail

```bash
# Run compliance checks
bash .agentic/hooks/pre-commit-check.sh

# If exit code != 0, STOP and fix
```

---

## Framework Promises (MUST BE KEPT)

The framework promises these things. Agents MUST enforce them:

| Promise | Enforcement |
|---------|-------------|
| "Specs drive development" | Cannot implement without acceptance criteria |
| "Tests verify correctness" | Cannot ship without passing tests |
| "Documentation stays current" | Cannot commit without updating docs |
| "Small batch development" | One feature at a time, small commits |
| "Quality gates block bad code" | pre-commit-check.sh must pass |
| "Nothing gets forgotten" | Checklists are mandatory, not optional |

---

## Anti-Patterns (NEVER DO THESE)

❌ **Implementing without acceptance criteria first**
❌ **Marking shipped without running the application**
❌ **Committing without updating FEATURES.md/PRODUCT.md**
❌ **Skipping smoke tests ("tests pass" is not enough)**
❌ **Treating checklists as optional**
❌ **Waiting for user to remind you about specs**

---

## How To Use This Document

**You don't need to read this every time.** Instead:

1. **Recognize the trigger** from user's message
2. **Follow the appropriate pipeline** automatically
3. **Verify gates at each step** before proceeding
4. **Show progress** to user (completed checklist items)

**The user should never need to remind you to:**
- Update specs
- Run smoke tests
- Check for untracked files
- Follow the definition of done

These are YOUR responsibility as an agent following this framework.

