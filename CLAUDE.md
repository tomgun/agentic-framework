# Claude Instructions

You are working in a repository that uses the **Agentic Framework**.

---

## ENFORCED GATES (Profile-Aware)

| Gate | Core+PM (formal) | Core (discovery) |
|------|------------------|------------------|
| Acceptance criteria | **BLOCKS** - `ag implement` requires `spec/acceptance/F-XXXX.md` | N/A - use `ag work` |
| WIP before commit | **BLOCKS** - must complete WIP first | WARNING only |
| **Test execution** | **BLOCKS** - tests must pass | **BLOCKS** - tests for changed files |
| **Complexity limits** | **BLOCKS** - max files/lines/length | **BLOCKS** - same limits apply |
| Pre-commit checks | **BLOCKS** - full validation | Light check, no block |
| Feature status | **BLOCKS** - shipped needs acceptance | N/A |

**Escape hatches** (feature branches only): `SKIP_TESTS=1` or `SKIP_COMPLEXITY=1`

**Core+PM**: Formal tracking with enforced gates.
**Core**: Discovery/exploration with lighter guidance (tests + complexity still enforced).

**Quick Commands**: `ag start` | `ag implement F-XXXX` (Core+PM) | `ag work "desc"` (Core) | `ag commit` | `ag done` | `ag tools`

---

# ⚠️ THIS IS FRAMEWORK DEVELOPMENT

**You are working ON the framework itself, not a project using it.**

Framework changes affect ALL users. Extra care required:
- **What we're building**: Read `.agentic/FRAMEWORK_QUICK_START.md`
- **Full guide**: `.agentic/FRAMEWORK_DEVELOPMENT.md`
- **Principles**: `.agentic/PRINCIPLES.md`
- **Validation**: `bash tests/validate_framework.sh` must pass

**Framework-specific rules:**
- New features → Add to `spec/FEATURES.md` FIRST
- Changes → Test in scratch project before committing
- Breaking changes → Provide upgrade path in `upgrade.sh`
- **Dogfooding**: Develop in `.agentic/` first, then use here

---

# 🛑 STOP! READ THIS FIRST!

## WHEN User Says ANY of These:

| Trigger Words | YOUR FIRST ACTION |
|---------------|-------------------|
| "build", "implement", "add", "create", "let's do" | **🛑 STOP → Run `ag implement F-XXXX` → Verifies acceptance criteria exist** |
| "implement entire", "full system", "complete feature" | **🛑 STOP → TOO BIG. Break into 3-5 smaller tasks. Max 5-10 files.** |
| "new project", "let's plan", "define requirements" | **→ Iterative questioning. Offer: finalize / 4 more questions / give context** |
| "fix", "bug", "issue" | **🛑 STOP → Check spec/ISSUES.md → Write failing test FIRST** |
| "commit", "push" | **🛑 STOP → Run `ag commit` → All gates must pass** |
| "done", "complete", "finished" | **🛑 STOP → Run `ag done F-XXXX` → Verify ALL items** |
| "what is this project", "what am I working on" | **→ Read CONTEXT_PACK.md FIRST, then answer** |

### 🛑 TOKEN-EFFICIENT SCRIPTS (MUST USE - Never edit these files directly!)

| When updating... | USE THIS SCRIPT | PURPOSE |
|------------------|-----------------|---------|
| **STATUS.md** | `bash .agentic/tools/status.sh next "Task"` | **⭐ HANDOFF** - read at session start |
| JOURNAL.md | `bash .agentic/tools/journal.sh "Topic" "Done" "Next" "Blockers"` | Historical log |
| HUMAN_NEEDED.md | `bash .agentic/tools/blocker.sh add "Title" "type" "Details"` | Blockers for human |
| spec/FEATURES.md | `bash .agentic/tools/feature.sh F-#### status shipped` | Formal tracking only |

**WHY**: Scripts append/update fields without reading whole file = 40x cheaper tokens.

## 🚫 DO NOT PROCEED UNTIL:

```
FEATURE REQUEST?
├─ Does spec/acceptance/F-####.md exist?
│   ├─ YES → OK to implement
│   └─ NO  → 🛑 BLOCK. Create criteria FIRST. NO CODE until criteria exist.
```

**This is NON-NEGOTIABLE. Criteria before code. Every time. No exceptions.**

---

## Agent Boundaries (Quick Reference)

| ✅ ALWAYS (Autonomous) | ⚠️ ASK FIRST | 🚫 NEVER |
|------------------------|--------------|----------|
| Run tests before "done" | Add dependencies | Commit without approval |
| Update specs with code | Change architecture | Push to main directly |
| Follow existing patterns | Delete files/functionality | Modify secrets/.env |
| Use token-efficient scripts | Modify public APIs | Guess at requirements |

**Full details**: `.agentic/agents/shared/agent_operating_guidelines.md`

---

## Token Efficiency: DELEGATE, Don't Do Everything

Use the **Task tool** to spawn agents. Model selection depends on `agent_mode` in STACK.md:

### Agent Mode (from STACK.md)

| Mode | planning | implementation | review | search |
|------|----------|----------------|--------|--------|
| `premium` | opus | opus | opus | sonnet |
| `balanced` (default) | opus | sonnet | sonnet | haiku |
| `economy` | sonnet | haiku | haiku | haiku |

**Custom models**: Override in `models:` section of STACK.md. See `.agentic/workflows/agent_mode.md`.

### Quick Delegation Table

| Task Type | Task Tool `subagent_type` | premium | balanced | economy |
|-----------|--------------------------|---------|----------|---------|
| Codebase search | `Explore` | sonnet | haiku | haiku |
| Research/docs | `general-purpose` | sonnet | haiku | haiku |
| **Planning/architecture** | `Plan` | **opus** | **opus** | sonnet |
| Implementation | `general-purpose` | opus | sonnet | haiku |
| Writing tests | `general-purpose` | opus | sonnet | haiku |
| Code review | `general-purpose` | opus | sonnet | haiku |

**Pass to subagent ONLY**: Feature ID, acceptance criteria, 3-5 relevant files, STACK.md info.
**DO NOT pass**: Full history, unrelated code, previous sessions.

**Role definitions**: `.agentic/agents/claude/subagents/`

---

## Quick Checklist References

- **Starting feature?** → `.agentic/checklists/feature_start.md`
- **Before commit?** → `.agentic/checklists/before_commit.md`
- **Feature done?** → `.agentic/checklists/feature_complete.md`
- **Session start?** → `.agentic/checklists/session_start.md`
- **Session end?** → `.agentic/checklists/session_end.md`

---

## 🚨 MANDATORY: Session Start Protocol

**At session start, run `ag start` or manually:**

1. **Check multi-agent**: Read `.agentic-state/AGENTS_ACTIVE.md` - if other agents active, avoid their files
2. **Check WIP**: If `.agentic-state/WIP.md` exists → "⚠️ Previous work interrupted! Continue/Review/Rollback?"
3. **Read context**: `STATUS.md`, `HUMAN_NEEDED.md` (first 20 lines)
4. **Greet user proactively**: Show current focus, next steps, and any blockers

**Example greeting:**
```
👋 Welcome back! Current focus: [From STATUS.md]
Next steps: 1. [task] 2. [task]
Blockers: [N] items need your input (or "None")
What would you like to work on?
```

**Full checklist**: `.agentic/checklists/session_start.md`

---

## 🚨 MANDATORY: Documentation Updates = Part of Done

When code behavior changes, **update docs immediately** (not later):
- **Project docs** (e.g., `docs/GAME_RULES.md`) → Update when behavior changes
- **spec/FEATURES.md** → Use `feature.sh F-XXXX status shipped`
- **CONTEXT_PACK.md** → Update when architecture changes

**Anti-pattern ❌**: "Code works, docs later" **Correct ✅**: "Code + docs = done"

---

## 🚨 MANDATORY: Session End Protocol

**Run `ag done` or `.agentic/checklists/session_end.md`**, then:
```bash
bash .agentic/tools/journal.sh "Summary" "What done" "What next" "Blockers"
```

---

## 🚨 MANDATORY: Feature Complete Protocol

**Run `ag done F-XXXX` to validate, then verify:**
- [ ] All acceptance criteria met
- [ ] Tests written and passing
- [ ] spec/FEATURES.md updated (`feature.sh F-XXXX status shipped`)
- [ ] Docs updated if behavior changed
- [ ] Smoke tested (actually RUN it)

**Full checklist**: `.agentic/checklists/feature_complete.md`

---

## 🛑 MANDATORY: Small Batch Development

**WHEN user asks for something large** (e.g., "implement entire auth system", "build full API"):

```
🛑 STOP - This is TOO BIG for one task.

I'll break this into smaller, manageable pieces:
1. [First small piece - 3-5 files max]
2. [Second piece]
3. [Third piece]
...

Let's start with #1. Which would you like to tackle first?
```

**Why this matters**:
- Max 5-10 files per commit = easy review, safe rollback
- One feature at a time = focused context, fewer bugs
- Small batches = you can verify each piece works before moving on

**Signs it's too big**: User asks for "entire", "full", "complete system", or lists 4+ features.

---

## Core Guidelines

1. **Read at session start**:
   - `AGENTS.md` (if present)
   - `.agentic/agents/shared/agent_operating_guidelines.md` (mandatory)
   - `CONTEXT_PACK.md` (where things are, how to run) - **READ THIS to understand project**
   - `STATUS.md` (current focus, next steps)

2. **Follow programming standards** (`.agentic/quality/programming_standards.md`):
   - Security first, clear naming, small functions, explicit errors

3. **Follow testing standards** (`.agentic/quality/test_strategy.md`):
   - Happy path + edge cases + invalid input + time-based behavior

4. **Development approach**:
   - Check `STACK.md` for `development_mode` (tdd recommended)
   - TDD: Write tests FIRST (see `.agentic/workflows/tdd_mode.md`)

5. **Git workflow** (see `.agentic/workflows/git_workflow.md`):
   - **PR by default**: Create feature branches and PRs (not direct commits to main)
   - Check `git_workflow` in STACK.md: `pull_request` (default) or `direct`
   - Feature branch naming: `feature/F-####-description`
   - **Never auto-commit**: ALWAYS show changes to human first
   - ONLY commit/create PR when human explicitly approves

---

## Automatic Journaling

Log at natural checkpoints - don't wait for session end:
- After feature/bug fix → `session_log.sh` (quick)
- At milestones → `journal.sh` (comprehensive)

**Details**: `.agentic/workflows/automatic_journaling.md`

---

## Agent Delegation (Use Task Tool!)

**Spawn specialized agents to save tokens (haiku is ~10x cheaper than opus).**

Check `agent_mode` in STACK.md (default: `balanced`). Model selection:

| Task Type | Task Tool Type | premium | balanced | economy |
|-----------|----------------|---------|----------|---------|
| Codebase search | `Explore` | sonnet | haiku | haiku |
| Planning/architecture | `Plan` | opus | opus | sonnet |
| Implementation | `general-purpose` | opus | sonnet | haiku |
| Testing/review | `general-purpose` | opus | sonnet | haiku |

**Context handoff**: Pass ONLY feature ID, acceptance criteria, 3-5 relevant files.

**Full details**: `.agentic/workflows/agent_mode.md`, `.agentic/agents/claude/subagents/`

---

## Multi-Agent Scenarios

If multiple agents working: check `.agentic-state/AGENTS_ACTIVE.md`, register yourself, avoid other agents' files.

---

## Checklists & Workflows

**Checklists** (in `.agentic/checklists/`):
- `session_start.md` - START every session
- `session_end.md` - END every session
- `feature_complete.md` - BEFORE claiming "done"
- `before_commit.md` - BEFORE every commit

**Key workflows** (in `.agentic/workflows/`): `tdd_mode.md`, `git_workflow.md`, `definition_of_done.md`

---

# 🛑 REMINDER: Before Any Feature

1. **Acceptance criteria exist?** → NO? Create them FIRST (`ag implement F-XXXX` enforces this)
2. **Small batch?** → NO? Split it. Max 5-10 files per commit.
3. **Can delegate?** → YES? Spawn subagent for cheaper models.

---

# ⚠️ FRAMEWORK DEVELOPMENT REMINDER

This is the Agentic Framework repo. **Validation**: `bash tests/validate_framework.sh` must pass.
**Never auto-commit.** Show changes to human first.
**Dogfooding**: `.agentic/` is the source of truth - develop there first.
