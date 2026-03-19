---
summary: "Workflow trigger rules for Cursor, Copilot, Codex (non-Claude tools)"
tokens: ~3254
---

# Automatic Orchestration Rules

> **Claude Code users**: Workflow triggers are primarily handled by Skills in `.claude/skills/`. This file serves Cursor, Copilot, Codex, and other non-Claude tools.

**Purpose**: Agents automatically detect task type and follow the correct systematic process.

**Design basis**: Implements Principles F3 (Token & Context Optimization), D2 (Deterministic Enforcement), and D3 (Durable Artifacts). Architecture: `docs/INSTRUCTION_ARCHITECTURE.md`.

**🚨 CRITICAL**: These rules are NON-NEGOTIABLE. Follow them without user prompting.

---

## 🤖 Proactive Session Start (AUTOMATIC!)

**At first message, tokens reset, or user returns - DO THIS AUTOMATICALLY:**

### 1. Silently Read Context (NO text output before dashboard)

**Do NOT output any text before the dashboard.** No "Starting session...", no narration of tool calls. The dashboard is the first thing the user sees.

```bash
# Every command needs || true to prevent exit code errors
cat STATUS.md 2>/dev/null || true
cat HUMAN_NEEDED.md 2>/dev/null | head -20 || true
python3 .agentic/lib/tools/agents_helpers.py list 2>/dev/null || true
bash .agentic/lib/tools/backlog.sh current 2>/dev/null || true
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
| `wip.sh check` detects active WIP (AGENTS.json) | "⚠️ Previous work interrupted! Continue, review, or rollback?" |
| `ag intent list` shows orphaned intents | "⚠️ Found interrupted work from crashed session. Run `ag sync` to adopt or `ag intent clear F-XXXX` to discard." |
| HUMAN_NEEDED has items | "📋 [N] items need your input" |
| Upgrade pending | "🔄 Framework upgraded to vX.Y.Z, applying updates..." |
| Dashboard shows orphaned plans (📝) | "📝 Orphaned plan(s) detected. Saving to journal and running dialectical review before implementation." |

**Why proactive**: User shouldn't ask "where were we?" - you tell them automatically.

---

## Auto-Detection Triggers

### Core Workflow Triggers

| User Request Pattern | Auto-Trigger | What To Do |
|---------------------|--------------|------------|
| (first message) | **Proactive Start** | Greet with context + options |
| "implement F-####" / "build feature" / "create [feature]" | **Feature Pipeline** | Follow Feature Implementation flow (respects backlog order). **After plan mode**: auto-continue immediately — save plan as DRAFT → spawn Critic + Advocate → synthesize → if `convergence: auto` and converged, auto-approve; if `manual`, present to user. Then `ag implement`. Pre-commit gate (Check 21) blocks commits without APPROVED plan. |
| "backlog" / "queue" / "what's next" / "prioritize" / "reorder" | **Backlog Management** | Run `ag backlog` to show queue; `ag backlog add/done/move/list` to manage |
| "fix I-####" / "fix bug" / "fix issue" | **Issue Pipeline** | Follow Issue Resolution flow |
| "commit" / "ready to commit" | **Before Commit** | Run `before_commit.md` checklist |
| "write spec" / "create spec" / "add acceptance" / "ag spec" | **Spec-Writing Pipeline** | Follow Spec-Writing flow |
| "done with feature" / "feature complete" / "merge" / "merge PR" | **Feature Complete** | Run `feature_complete.md` checklist. After agent merges a PR (`gh pr merge`), IMMEDIATELY run `ag done F-XXXX` on main — don't wait for user. |
| "end session" / "stopping work" | **Session End** | Run `session_end.md` checklist |
| "review code" / "check this" | **Review** | Claude Code: delegate to review subagent (fresh context) via `reviewing-code` skill. Others: run `review_checklist.md` inline. |
| "review blocked" / "approve transition" / "pending review" | **Review Checkpoint** | Run `ag review` to list pending. `ag review F-XXXX <state>` to resolve. |
| "decompose" / "break down epic" / "split into children" | **Epic Decomposition** | Run `ag decompose F-XXXX`. Analyzes AC, proposes child features scoped to components, routes through review_decomposition. |
| "flush state" / "commit state files" / dirty state after `ag done` | **State Flush** | Run `ag flush` (or `ag flush --features`) to commit state-only files directly to main. No PR needed. |
| "dogfood" / "template drift" / "root vs template" / "instruction sync" | **Dogfood Sync** | Run `ag dogfood` to detect drift between root instruction files and templates. Runs automatically in `ag done` on main (framework-dev only). |
| "interrupted" / "crashed" / "stuck" / "orphaned" / "resume work" | **Intent Recovery** | Run `ag intent list` to see pending/orphaned intents. `ag intent clear F-XXXX` to discard. `ag sync` auto-adopts orphans from crashed sessions. |
| "vision" / "kickoff" / "draft epic" / "generate features from idea" | **Vision-to-Backlog Pipeline** | Run `ag kickoff "vision description"`. Generates OVERVIEW.md, FEATURES.md entries, AC stubs, and BACKLOG.json in staging. Review with `--review`, approve with `--approve`, discard with `--discard`. |
| "verify epic" / "integration tests" / "cross-component tests" | **Epic Integration Verification** | Run `ag auto verify-epic F-XXXX`. Loads integration test commands (epic AC > STACK.md > skip), runs via VerifyLoop, stores artifact. `review_integration` setting controls critical agent review. |
| "verify framework" / "test the framework" / "self-test" / "framework verification" | **Framework Self-Verification** | Run `ag auto verify-framework --project <name>` or `--all`. Spawns agents to build example projects, self-heals framework bugs, delivers accumulated fixes as PR. |
| "run" / "how to run" / "dev server" / "start the app" / "run commands" | **Project Run Info** | Run `ag run`. Shows stack summary, dev/build/test commands with source attribution (STACK.md vs auto-detected). |
| "feedback" / "tested it" / "tried it" / "after testing" / "user reported" | **Feedback Capture** | Run `ag feedback "text"`. Auto-classifies (bug/feature/ac-adjust/unclear) via keywords, persists to FEEDBACK_LOG.md. Use `--bug`/`--feature`/`--ac` for direct routing. `ag feedback log` to view, `ag feedback route FB-XXXX` to route. |
| "formalize" / "promote to formal" / "migrate to formal" / "make TODOs into features" | **Discovery-to-Formal Migration** | Run `ag formalize` to list promotable TODO items. `ag formalize T-XXXX` promotes specific items to FEATURES.md entries + AC stubs. `ag formalize --all` promotes everything. |

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
bash .agentic/lib/tools/context-for-role.sh domain-agent F-0042 --dry-run
# Shows: Token budget: 4000, Files to load, Tokens used

# Pass assembled context to subagent (saves 60-80% tokens)
```

See `.agentic/lib/agents/context-manifests/` for all role definitions

---

## Feature Pipeline (AUTO-INVOKED)

**Trigger**: User mentions implementing a feature (F-#### or general)

**CRITICAL PRE-CONDITION (feature_tracking=yes)**: If the user describes a feature without a feature ID:
1. Assign the next available F-XXXX ID in .agentic/spec/FEATURES.md
2. Create .agentic/spec/acceptance/F-XXXX.md with acceptance criteria
3. THEN proceed with the pipeline below

Do NOT proceed to step 4 (IMPLEMENT) without completing step 1 (VERIFY ACCEPTANCE CRITERIA EXIST).

### Automatic Steps (DO ALL OF THESE)

```
1. VERIFY ACCEPTANCE CRITERIA EXIST
   ├─ feature_tracking=yes: Check .agentic/spec/acceptance/F-####.md exists
   ├─ feature_tracking=no: Check OVERVIEW.md has criteria
   └─ If missing: CREATE THEM FIRST (rough is OK)

2. AC CLARITY GATE
   └─ `spec-analyze.sh F-XXXX --gate` runs
   ├─ formal/autonomous_formal: blocking (vague ACs = cannot proceed)
   ├─ discovery: advisory (warnings only, proceed regardless)
   └─ Bypass: SKIP_CLARITY=1

3. CHECK PLAN-REVIEW SETTING
   └─ Read STACK.md → plan_review_enabled (default: yes for formal/autonomous_formal profiles)
   ├─ If yes: Run `ag plan F-####` — uses dialectical review.
   │   ├─ If plan_review_convergence: auto (F-0236): convergence loop runs
   │   │   automatically — spawns all reviewers from plan_review_reviewers
   │   │   (Critic + Advocate + optional experts), synthesizes, checks
   │   │   convergence, auto-revises until converged or max_iterations
   │   │   (ENFORCED — escalates to HUMAN_NEEDED at limit).
   │   └─ If manual: Critic + Advocate in parallel (fresh context).
   │      User decides Proceed/Revise/Reject.
   │      If synthesis has actionable refinements → default is Revise (never "Proceed with caveats").
   └─ If no: Proceed directly (or run ag plan --no-review for simple plan)

4. CHECK DEVELOPMENT MODE
   └─ Read STACK.md → development_mode (default: standard)
   ├─ standard: implement first, test to verify
   └─ tdd: Per-AC red-green-refactor cycle:
      RED → GREEN → REFACTOR, checkpoint --phase at each step
      `wip.sh complete` blocks without phase checkpoints

5. IMPLEMENT
   ├─ If `worktree_mode: always` in STACK.md, `ag implement` auto-creates a worktree — `cd` to it
   ├─ Write code meeting acceptance criteria
   ├─ Add @feature annotations
   └─ Keep small, focused changes

6. TEST
   ├─ Write tests as specified in .agentic/spec/acceptance/F-####.md → ## Tests
   ├─ All tests must pass
   └─ Smoke test: RUN THE APPLICATION

7. UPDATE SPECS (MANDATORY - NOT OPTIONAL)
   ├─ feature_tracking=yes: Update .agentic/spec/FEATURES.md status
   ├─ feature_tracking=no: Update OVERVIEW.md
   └─ This is part of "done", not afterthought

8. UPDATE DOCS
   ├─ JOURNAL.md (what was accomplished)
   ├─ CONTEXT_PACK.md (if architecture changed)
   └─ STATUS.md (next steps)

9. DOC LIFECYCLE (if STACK.md ## Docs has entries)
   ├─ `ag docs F-####` or `docs.sh --trigger feature_done`
   ├─ Drafts registered docs (lessons, architecture, changelog, etc.)
   ├─ Formal/autonomous_formal profile: also drafts pr-trigger docs (changelog, readme)
   └─ Human reviews drafts in git diff, removes `<!-- draft: -->` markers

10. BEFORE COMMIT
   └─ Run before_commit.md checklist
```

### Non-Negotiable Gates

| Gate | Check | Block If |
|------|-------|----------|
| Acceptance Criteria | `.agentic/spec/acceptance/F-####.md` (feature_tracking=yes) or criteria in any form (feature_tracking=no) | acceptance_criteria=blocking: Missing = cannot proceed |
| Tests Pass | Run test suite | Any failure = cannot ship |
| Smoke Test | Actually run the app | Strongly recommended — verify manually before shipping |
| Specs Updated | FEATURES.md and STATUS.md current | Stale = cannot commit (enforced by pre-commit-check.sh when feature_tracking=yes) |
| No Untracked Files | `check-untracked.sh` clean | Untracked = warn before commit |

†Smoke testing and anti-hallucination are behavioral principles reinforced by memory seed and LLM tests. They cannot be verified by scripts.

---

## Brownfield Spec Pipeline (triggered by `ag specs`)

**Trigger**: User runs `ag specs` or asks to generate specs for an existing codebase

### Automatic Steps

```
1. CHECK: Discovery report exists → if not, run discover.py
2. CHECK: Domains detected → if only 1 small domain, use quick inline path
   - Small: 1 domain AND ≤8 clusters → quick inline spec generation
   - Large: >1 domain OR >8 clusters → systematic domain-by-domain approach
3. CREATE PLAN: Brownfield spec plan via plan-review loop
   - Domain map with boundaries, priorities, approach per domain
   - Reviewer checks: boundaries correct? anything missed? priorities sensible?
   - Plan artifact: .agentic/journal/plans/brownfield-specs-plan.md
   - Uses checkbox format: - [ ] Domain (type, ~N features)
4. PER DOMAIN (in priority order):
   a. Read key source files (1-2 per cluster, max ~10 per domain)
   b. Generate features with `- Domain:` metadata tag
   c. Generate Given/When/Then acceptance criteria
   d. Write FEATURES.md entries + .agentic/spec/acceptance/F-####.md files
   e. Ask user: "Does this look right for [Domain]? Merge/split/adjust?"
   f. Mark domain as COMPLETED in plan artifact (change - [ ] to - [x])
5. CROSS-DOMAIN REVIEW:
   - Check for duplicate features across domains
   - Check for gaps (code areas not covered)
   - Final user confirmation
6. TOKEN COST CHECK:
   - If feature count > 50: suggest `organize_features.py --by domain`
7. UPDATE: FEATURES.md, STATUS.md, JOURNAL.md
```

### Multi-Session Support

Brownfield spec generation can span multiple sessions:
- Progress tracked via checkboxes in plan artifact
- Session start detects active plan → suggests resuming with `ag specs`
- `ag specs --status` shows domain completion progress

---

## Spec-Writing Pipeline (AUTO-INVOKED)

**Triggers**: "write spec", "create spec", "add acceptance criteria", "spec for F-XXXX", "update spec", "evolve spec", "ag spec"

### Automatic Steps

```
1. IDENTIFY SCENARIO
   ├─ New feature (no F-XXXX exists)                   → go to 2
   └─ Existing feature → check Status field
       ├─ planned / in_progress                        → go to 3 (Low protection)
       └─ shipped                                      → go to 4 (HIGH protection)

2. NEW FEATURE SPEC
   a. Find next F-XXXX ID in .agentic/spec/FEATURES.md
   b. Read .agentic/spec/NFR.md → identify applicable NFRs
   c. Create FEATURES.md entry (Status: planned, Related NFRs)
   d. Create .agentic/spec/acceptance/F-XXXX.md from template
   e. Show to user for approval
   f. Run: bash .agentic/lib/tools/migration.sh create "Add F-XXXX [Name]"
   g. Run: bash .agentic/lib/tools/check-spec-health.sh F-XXXX
   h. Handoff: "ag plan F-XXXX"

3. UPDATE PLANNED/IN-PROGRESS SPEC
   a. Read current acceptance criteria
   b. Update criteria
   c. Migration if significant (adding/removing criteria, scope change)
   d. Show to user for approval

4. EVOLVE SHIPPED SPEC (CONTRACT MODIFICATION)
   a. Read current acceptance criteria + linked tests + NFR references
   b. Show current state to user
   c. NEVER delete existing criteria — additive only
   d. Use markers: [Discovered], [Revised in M-NNN: was "X" now "Y"]
   e. Require justification (captured in migration)
   f. Run: bash .agentic/lib/tools/migration.sh create "Evolve F-XXXX: [reason]"
   g. Run: bash .agentic/lib/tools/drift.sh --check (if available)
   h. Show changes to user — human MUST approve
```

### Pre-Commit Enforcement

| Gate | What | If Violated |
|------|------|-------------|
| Check 14 | Shipped spec modified without migration | BLOCKED |
| Check 15 | Test file deleted for shipped feature | BLOCKED |
| Check 16 | Shipped feature status downgraded | BLOCKED |

No escape hatch. Shipped spec protection is deterministic.

**Checklist**: `.agentic/lib/checklists/spec_writing.md`
**Full workflow**: `.agentic/lib/workflows/spec_writing.md`

---

## Issue Pipeline (AUTO-INVOKED)

**Trigger**: User mentions fixing an issue (I-#### or general bug)

### Automatic Steps

```
1. UNDERSTAND THE ISSUE
   ├─ Read .agentic/spec/ISSUES.md for I-#### details
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
   └─ bash .agentic/lib/tools/wip.sh check (resume if WIP detected in AGENTS.json)
   
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
□ Documentation updated (docs.sh --validate, drift.sh --docs, CONTEXT_PACK.md if architecture changed)
□ FEATURES.md/OVERVIEW.md updated with status: shipped
□ Backlog advanced (if completed feature was current backlog item)
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
□ No active WIP in AGENTS.json (work is complete)
□ All tests pass
□ Smoke test passed (for user-facing changes)
□ Quality checks pass (if enabled)
□ FEATURES.md/OVERVIEW.md updated
□ JOURNAL.md updated
□ State files staged (BACKLOG.json, STATUS.md, JOURNAL.md if modified)
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
| Planning | `.agentic/spec/acceptance/F-####.md` exists with testable criteria |
| Test | Tests exist and currently FAIL |
| Implementation | Tests now PASS |
| Review | No critical issues raised |
| Spec Update | FEATURES.md shows `Status: shipped` |
| Documentation | Relevant docs updated |
| Git | Commit message clear, all files tracked |

### Block If Quality Gates Fail

```bash
# Run compliance checks
bash .agentic/lib/hooks/pre-commit-check.sh

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

---

## Reference: Gates, Delegation, and Session Protocols

*(Moved from instruction files — these are structurally enforced, not constitutional rules)*

### Enforced Gates (Settings-Driven)

| Gate | Setting | Formal default | Discovery default |
|------|---------|----------------|-------------------|
| Acceptance criteria | `acceptance_criteria` | **blocking** | recommended |
| WIP before commit | `wip_before_commit` | **blocking** | warning |
| Test execution | (always enforced) | tests must pass | tests for changed files |
| Complexity limits | `max_files_per_commit` etc. | 10/500/500 | 15/1000/1000 |
| Pre-commit checks | `pre_commit_checks` | **full** | fast |
| Feature status | `feature_tracking` | **yes** (shipped needs acceptance) | no |
| Docs reviewed | `docs_gate` | **blocking** (`docs.sh --validate` at `ag done` + pre-commit check 19) | off |
| Smoke test evidence | `smoke_test_evidence` | **recommended** (warn at `ag done` if no evidence file) | off |

Override any setting: `ag set <key> <value>` | View resolved settings: `ag set --show`

Escape hatches (feature branches only): SKIP_TESTS=1, SKIP_COMPLEXITY=1, SKIP_SMOKE_EVIDENCE=1 (still shows per-file warnings)

### Agent Boundaries

| ALWAYS | ASK FIRST | NEVER |
|--------|-----------|-------|
| Run tests before "done" | Add dependencies | Commit without approval |
| Update specs with code | Change architecture | Push to main directly |
| Follow existing patterns | Delete files | Modify secrets/.env |

### Agent Mode (model selection for delegation)

Check `agent_mode` in STACK.md: `premium` | `balanced` (default) | `economy`
- premium: opus for planning/impl/review, sonnet for search
- balanced (default): opus for planning, sonnet for impl/review, haiku for search
- economy: sonnet for planning, haiku for everything else
- Custom: check `models:` section. Docs: `.agentic/lib/workflows/agent_mode.md`

### Task Tool Delegation (Claude Code)

| Task Type | subagent_type | premium | balanced | economy |
|-----------|---------------|---------|----------|---------|
| Codebase search | `Explore` | sonnet | haiku | haiku |
| Planning/architecture | `Plan` | opus | opus | sonnet |
| Implementation | `general-purpose` | opus | sonnet | haiku |
| Testing/review | `general-purpose` | opus | sonnet | haiku |

### Autonomous Workflow Modes (v0.43+)

For hands-off execution. Require test commands in STACK.md; task/crunch require acceptance criteria.

| Mode | Command | What it does |
|------|---------|-------------|
| **Verify** | `ag auto verify` | Test-fix loop: runs tests, spawns fresh Claude to fix failures, repeats until green or max iterations |
| **Verify + Visual** | `ag auto verify --visual` | Same + collects E2E screenshots + AI visual review via Anthropic API. Add `--feature F-XXXX` to save evidence for smoke test gate. |
| **Task** | `ag auto task F-XXXX` | Reads ACs, creates branch, spawns Claude per AC, tests, commits passing work, creates PR. If `review_pr: critical_agent`: auto-reviews PR, auto-fixes findings (up to `pr_fix_max_attempts`), applies verdict to GitHub (F-0235) |
| **Task + Visual** | `ag auto task F-XXXX --visual` | Same + visual review at final verification step |
| **Crunch** | `ag auto crunch` | Reads planned features from FEATURES.md, runs task mode for each, stops on max errors |
| **Epic** | `ag auto epic F-XXXX` | Reads epic's child features, schedules component-scoped workers with non-blocking reviews, executes autonomously |
| **Epic (parallel)** | `ag auto epic F-XXXX --parallel` | Same but spawns N concurrent Claude processes in separate worktrees. `--max-parallel N` (default 3), `--timeout N` (default 600s) |
| **Pipeline** | `ag auto pipeline` | End-to-end: accepts features data, creates epic, promotes to specs, schedules all children through implementation → review → ship |
| **Verify Framework** | `ag auto verify-framework` | Framework self-verification: spawns agents to build example projects using `ag` commands, self-heals framework bugs, delivers fixes as PR. `--project <name>` or `--all`, `--json` for machine output |

**Tiered test execution** (v0.44+): STACK.md `Test commands:` section defines ordered tiers (unit, integration, e2e). Each tier has its own fix loop. Fast-fail by default (tier failure stops subsequent tiers).

**Visual verification** (v0.45+): Configure `E2E screenshots:` in STACK.md. Requires `pip install anthropic` + `ANTHROPIC_API_KEY`. Visual concerns are advisory only.

**Control commands**: `ag auto pause` | `ag auto resume` | `ag auto stop` | `ag auto status` | `ag auto feedback AC-001 "text"`

**When to suggest autonomous modes to user**:
- "fix all tests" / "make tests green" → `ag auto verify`
- "implement F-XXXX hands-off" → `ag auto task F-XXXX`
- "process all planned features" → `ag auto crunch`
- "execute this epic" / "implement all children of F-XXXX" → `ag auto epic F-XXXX`
- "run epic in parallel" / "parallel execution" / "concurrent agents" → `ag auto epic F-XXXX --parallel`
- "run full pipeline" / "vision to shipped" / "end-to-end autonomous" → `ag auto pipeline`
- "verify framework" / "test the framework itself" / "self-test" / "framework verification" → `ag auto verify-framework`
- "start coordination server" / "parallel agents" / "remote control" → `ag coord start`
- Project has E2E + screenshots → suggest `--visual`

### Session Protocols

- **START**: Run `ag start`. Use `dashboard.sh` — one tool call, output verbatim. Script renders the full dashboard. If WIP exists: dashboard shows interrupted work warning.
- **END**: Run `.agentic/lib/checklists/session_end.md`, update JOURNAL.md.
- **DONE**: Run `.agentic/lib/checklists/feature_complete.md` before claiming done.

