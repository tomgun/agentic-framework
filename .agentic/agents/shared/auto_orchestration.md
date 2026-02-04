# Automatic Orchestration Rules

**Purpose**: Agents automatically detect task type and follow the correct systematic process.

**🚨 CRITICAL**: These rules are NON-NEGOTIABLE. Follow them without user prompting.

---

## 🤖 Proactive Session Start (AUTOMATIC!)

**At first message, tokens reset, or user returns - DO THIS AUTOMATICALLY:**

### 1. Silently Read Context
```bash
# Every command needs || true to prevent exit code errors
cat STATUS.md 2>/dev/null || true
cat HUMAN_NEEDED.md 2>/dev/null | head -20 || true
cat .agentic-state/AGENTS_ACTIVE.md 2>/dev/null || true
ls .agentic-state/WIP.md 2>/dev/null || true
```

### 2. Greet User with Recap

```
👋 Welcome back! Here's where we are:

**Last session**: [From JOURNAL.md/STATUS.md]
**Current focus**: [From STATUS.md]

**Next steps** (pick one or tell me something else):
1. [Next planned task]
2. [Another option]
3. [Address blockers - if any]

What would you like to work on?
```

### 3. Handle Special Cases

| Situation | Response |
|-----------|----------|
| .agentic-state/WIP.md exists | "⚠️ Previous work interrupted! Continue, review, or rollback?" |
| HUMAN_NEEDED has items | "📋 [N] items need your input" |
| Upgrade pending | "🔄 Framework upgraded to vX.Y.Z, applying updates..." |

**Why proactive**: User shouldn't ask "where were we?" - you tell them automatically.

---

## Auto-Detection Triggers

### Core Workflow Triggers

| User Request Pattern | Auto-Trigger | What To Do |
|---------------------|--------------|------------|
| (first message) | **Proactive Start** | Greet with context + options |
| "implement F-####" / "build feature" / "create [feature]" | **Feature Pipeline** | Follow Feature Implementation flow |
| "fix I-####" / "fix bug" / "fix issue" | **Issue Pipeline** | Follow Issue Resolution flow |
| "commit" / "ready to commit" | **Before Commit** | Run `before_commit.md` checklist |
| "done with feature" / "feature complete" | **Feature Complete** | Run `feature_complete.md` checklist |
| "end session" / "stopping work" | **Session End** | Run `session_end.md` checklist |
| "review code" / "check this" | **Review** | Run `review_checklist.md` |

### Domain & Design Triggers

| User Request Pattern | Auto-Trigger | Agent | What To Do |
|---------------------|--------------|-------|------------|
| "game rules" / "business logic" / "domain model" / "state machine" | **Domain Logic** | domain-agent | Define rules BEFORE coding |
| "design" / "mockup" / "wireframe" / "UI for" / "layout" | **Design** | design-agent | Create visual designs |
| "usability" / "UX" / "user flow" / "accessibility" / "a11y" | **UX Review** | ux-agent | Evaluate user experience |

### Technical Triggers

| User Request Pattern | Auto-Trigger | Agent | What To Do |
|---------------------|--------------|-------|------------|
| "refactor" / "clean up" / "restructure" / "technical debt" | **Refactoring** | refactor-agent | Improve code without changing behavior |
| "performance" / "optimize" / "slow" / "profile" / "benchmark" | **Performance** | perf-agent | Profile and optimize |
| "security" / "vulnerability" / "audit" / "OWASP" | **Security Audit** | security-agent | Security review |
| "API" / "endpoint" / "schema" / "REST" / "GraphQL" | **API Design** | api-design-agent | Design API contracts |
| "database" / "schema" / "migration" / "ERD" / "SQL" | **Database** | db-agent | Database design/migration |
| "upgrade" / "migrate" / "update to" / "breaking change" | **Migration** | migration-agent | Handle upgrades safely |

### Deployment Triggers

| User Request Pattern | Auto-Trigger | Agent | What To Do |
|---------------------|--------------|-------|------------|
| "CI/CD" / "pipeline" / "deploy" / "Docker" / "Kubernetes" | **DevOps** | devops-agent | CI/CD and infrastructure |
| "App Store" / "Play Store" / "iOS submission" / "TestFlight" | **App Store** | appstore-agent | Store submissions |
| "AWS" / "Lambda" / "S3" / "EC2" / "CloudFormation" | **AWS** | aws-agent | AWS architecture |
| "Azure" / "Azure Functions" / "AKS" / "ARM template" | **Azure** | azure-agent | Azure architecture |
| "GCP" / "Cloud Run" / "BigQuery" / "Firebase" | **GCP** | gcp-agent | GCP architecture |

### Quality & Compliance Triggers

| User Request Pattern | Auto-Trigger | Agent | What To Do |
|---------------------|--------------|-------|------------|
| "check compliance" / "did I follow" / "verify process" | **Compliance** | compliance-agent | Verify framework adherence |

### Using Context Manifests

When triggering a specialized agent, use `context-for-role.sh` for minimal context:

```bash
# Get focused context for the agent
bash .agentic/tools/context-for-role.sh domain-agent F-0042 --dry-run
# Shows: Token budget: 4000, Files to load, Tokens used

# Pass assembled context to subagent (saves 60-80% tokens)
```

See `.agentic/agents/context-manifests/` for all role definitions

---

## Feature Pipeline (AUTO-INVOKED)

**Trigger**: User mentions implementing a feature (F-#### or general)

### Automatic Steps (DO ALL OF THESE)

```
1. VERIFY ACCEPTANCE CRITERIA EXIST
   ├─ Core+PM: Check spec/acceptance/F-####.md exists
   ├─ Core: Check OVERVIEW.md has criteria
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
   ├─ Core: Update OVERVIEW.md
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
| Specs Updated | FEATURES.md and STATUS.md current | Stale = cannot commit |
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
   └─ ls .agentic-state/WIP.md (resume if exists)
   
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
□ FEATURES.md/OVERVIEW.md updated with status: shipped
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
□ No .agentic-state/WIP.md exists (work is complete)
□ All tests pass
□ Smoke test passed (for user-facing changes)
□ Quality checks pass (if enabled)
□ FEATURES.md/OVERVIEW.md updated
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
❌ **Committing without updating FEATURES.md/OVERVIEW.md**
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

