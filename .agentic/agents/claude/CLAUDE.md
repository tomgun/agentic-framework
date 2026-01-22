# Claude Instructions

You are working in a repository that uses the **Agentic Framework**.

---

# 🛑 STOP! READ THIS FIRST!

## WHEN User Says ANY of These:

| Trigger Words | YOUR FIRST ACTION |
|---------------|-------------------|
| "build", "implement", "add", "create", "let's do" | **🛑 STOP → Read `feature_start.md` → Check acceptance criteria EXIST** |
| "implement entire", "full system", "complete feature" | **🛑 STOP → TOO BIG. Break into 3-5 smaller tasks. Max 5-10 files.** |
| "new project", "let's plan", "define requirements" | **→ Iterative questioning. Offer: finalize / 4 more questions / give context** |
| "fix", "bug", "issue" | **🛑 STOP → Check spec/ISSUES.md → Write failing test FIRST** |
| "commit", "push" | **🛑 STOP → Read `before_commit.md` → All gates must pass** |
| "done", "complete", "finished" | **🛑 STOP → Read `feature_complete.md` → Verify ALL items** |
| "what is this project", "what am I working on" | **→ Read CONTEXT_PACK.md FIRST, then answer** |

### 🛑 TOKEN-EFFICIENT SCRIPTS (MUST USE - Never edit these files directly!)

| When updating... | USE THIS SCRIPT | NOT direct file edit |
|------------------|-----------------|----------------------|
| JOURNAL.md | `bash .agentic/tools/journal.sh "Topic" "Done" "Next" "Blockers"` | ❌ Read/Edit |
| STATUS.md (focus, progress) | `bash .agentic/tools/status.sh focus "Task"` | ❌ Read/Edit |
| HUMAN_NEEDED.md (blockers) | `bash .agentic/tools/blocker.sh add "Title" "type" "Details"` | ❌ Read/Edit |
| spec/FEATURES.md | `bash .agentic/tools/feature.sh F-#### status shipped` | ❌ Read/Edit |

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

## Token Efficiency: DELEGATE, Don't Do Everything

| Task Type | Spawn This Agent | Model Tier | Why |
|-----------|------------------|------------|-----|
| Codebase search | `explore-agent` | Cheap/fast | 83% cheaper |
| Research/docs | `research-agent` | Cheap/fast | Fresh small context |
| Implementation | `implementation-agent` | Mid-tier | Focused context |
| Writing tests | `test-agent` | Mid-tier | Isolated work |
| Code review | `review-agent` | Mid-tier | Fresh perspective |

**Pass to subagent ONLY**: Feature ID, acceptance criteria, 3-5 relevant files, STACK.md info.
**DO NOT pass**: Full history, unrelated code, previous sessions.

**Subagent definitions**: `.agentic/agents/claude/subagents/`

---

## Quick Checklist References

- **Starting feature?** → `.agentic/checklists/feature_start.md`
- **Before commit?** → `.agentic/checklists/before_commit.md`
- **Feature done?** → `.agentic/checklists/feature_complete.md`
- **Session start?** → `.agentic/checklists/session_start.md`
- **Session end?** → `.agentic/checklists/session_end.md`

---

## 🚨 MANDATORY: Session Start Protocol

**At session start (first message, tokens reset, user returns), BE PROACTIVE:**

### 0. FIRST: Check for Other Active Agents (Multi-Window Conflict Prevention)

**IMMEDIATELY read `.agentic/AGENTS_ACTIVE.md`** before doing anything else:

```bash
cat .agentic/AGENTS_ACTIVE.md 2>/dev/null
```

**If file exists and shows other agents:**
- ⚠️ **TELL USER IMMEDIATELY**: "👥 Another agent is already working on [X]. I'll avoid those files."
- **Add yourself** to `.agentic/AGENTS_ACTIVE.md`
- **Work on different files/features** to prevent merge conflicts

### 1. Silently Read Context

```bash
cat STATUS.md 2>/dev/null
cat HUMAN_NEEDED.md 2>/dev/null | head -20
ls .agentic/WIP.md 2>/dev/null
```

### 2. Greet User with Recap (DO THIS AUTOMATICALLY!)

**Don't wait for user to ask "where were we?" - TELL THEM:**

```
👋 Welcome back! Here's where we are:

**Last session**: [Summary from JOURNAL.md/STATUS.md]
**Current focus**: [From STATUS.md]

**Next steps** (pick one or tell me something else):
1. [Next planned task]
2. [Another option if exists]
3. [Address blockers - if any in HUMAN_NEEDED.md]

What would you like to work on?
```

### 3. Handle Special Cases

- **.agentic/AGENTS_ACTIVE.md shows other agents?** → "👥 Another agent is working on [X]. I'll work on different files."
  - **Register yourself** in .agentic/AGENTS_ACTIVE.md
  - **Avoid their files** to prevent conflicts
- **.agentic/WIP.md exists?** → "⚠️ Previous work interrupted! [options]"
- **HUMAN_NEEDED.md has items?** → "📋 [N] items need your input"
- **Upgrade pending?** → Handle it, then greet

### 4. Token-Efficient Updates (Later in Session)

```bash
bash .agentic/tools/journal.sh "Topic" "Done" "Next" "Blockers"
bash .agentic/tools/status.sh focus "Current task"
```

**Why proactive**: User shouldn't have to remember context. You help them immediately.

---

## 🚨 MANDATORY: Documentation Updates = Part of Done

**CRITICAL RULE**: When you change code behavior, **updating docs is NOT optional - it's part of "done"**.

### When Code Changes, Update These:

**1. Project-specific docs** (e.g., `docs/GAME_RULES.md`, `docs/ARCHITECTURE.md`):
```bash
# If you change game rules, update docs IMMEDIATELY
# Example: Changed piece rotation → Update GAME_RULES.md rotation section
# NOT OPTIONAL - this is part of the task
```

**2. spec/FEATURES.md** (after completing ANY feature):
```bash
# Use token-efficient script (no full file read!)
bash .agentic/tools/feature.sh F-0003 status shipped
bash .agentic/tools/feature.sh F-0003 impl-state complete
bash .agentic/tools/feature.sh F-0003 tests complete
```

**3. CONTEXT_PACK.md** (when architecture changes):
- New module added → Document in CONTEXT_PACK.md
- Entry point changed → Update CONTEXT_PACK.md
- Major refactor → Update architecture section

**Anti-pattern ❌**: "Code works, I'll update docs later"  
**Correct pattern ✅**: "Code works AND docs updated = task done"

**Checkpoint**: Before marking work "complete", verify docs updated. Use `.agentic/checklists/feature_complete.md`.

---

## 🚨 MANDATORY: Session End Protocol

**BEFORE ending session, run `.agentic/checklists/session_end.md`** (5-minute checklist)

**Token-efficient logging:**
```bash
# Append to JOURNAL.md (cheap!)
bash .agentic/tools/journal.sh \
  "Session summary" \
  "- Implemented X\n- Fixed Y\n- Added tests for Z" \
  "- Deploy to staging\n- Get design review" \
  "None"

# Update SESSION_LOG.md (automatic checkpoints)
bash .agentic/tools/session_log.sh \
  "Session complete" \
  "Completed F-0003. All tests passing. Docs updated." \
  "feature=F-0003,status=done"
```

**Checkpoint**: Tell user: "✓ Session ending. Summary: [what done]. Next: [what next]. Blockers: [none/list]"

---

## 🚨 MANDATORY: Feature Complete Protocol

**BEFORE marking feature as "done", run `.agentic/checklists/feature_complete.md`**

**Definition of Done** (`.agentic/workflows/definition_of_done.md`):
- [ ] **All acceptance criteria met**
- [ ] **Tests written and passing** (unit + integration + acceptance)
- [ ] **spec/FEATURES.md updated** (use `feature.sh` script)
- [ ] **Docs updated** (game rules, architecture, etc.)
- [ ] **Code reviewed** (self-review checklist)
- [ ] **Smoke tested** (actually RUN the app, verify it works)
- [ ] **JOURNAL.md updated** (use `journal.sh` script)

**Use token-efficient scripts:**
```bash
# Update FEATURES.md status
bash .agentic/tools/feature.sh F-0003 status shipped
bash .agentic/tools/feature.sh F-0003 impl-state complete
bash .agentic/tools/feature.sh F-0003 tests complete
bash .agentic/tools/feature.sh F-0003 accepted yes

# Log completion
bash .agentic/tools/journal.sh \
  "F-0003 complete" \
  "Feature fully implemented, tested, documented" \
  "Move to F-0004" \
  "None"
```

**Checkpoint**: Show user the `feature_complete.md` checklist with all ✓ before claiming "done".

---

## Token-Efficient Scripts (USE THESE, Don't Edit Files Directly!)

**🛑 MANDATORY**: For JOURNAL.md, FEATURES.md, STATUS.md, HUMAN_NEEDED.md - **ALWAYS use scripts, NEVER edit directly**.

**Located in `.agentic/tools/`** - these save massive tokens by avoiding full file reads:

### 1. `journal.sh` - Append to JOURNAL.md (🛑 ALWAYS USE THIS)
```bash
bash .agentic/tools/journal.sh \
  "Session topic" \
  "What was accomplished" \
  "What's next" \
  "Blockers (or 'None')"

# Appends to JOURNAL.md (no read, very cheap!)
```

### 2. `session_log.sh` - Quick checkpoints
```bash
bash .agentic/tools/session_log.sh \
  "Checkpoint description" \
  "Details of what happened" \
  "metadata=key:value,key2:value2"

# Appends to SESSION_LOG.md (40x cheaper than JOURNAL.md!)
```

### 3. `status.sh` - Update STATUS.md sections
```bash
bash .agentic/tools/status.sh focus "Current task"
bash .agentic/tools/status.sh progress "60% - 3 of 5 criteria done"
bash .agentic/tools/status.sh next "Deploy to staging"
bash .agentic/tools/status.sh blocker "Waiting for API key"

# Updates specific fields (no full file rewrite!)
```

### 4. `feature.sh` - Update FEATURES.md
```bash
bash .agentic/tools/feature.sh F-0003 status in_progress
bash .agentic/tools/feature.sh F-0003 status shipped
bash .agentic/tools/feature.sh F-0003 impl-state partial
bash .agentic/tools/feature.sh F-0003 impl-state complete
bash .agentic/tools/feature.sh F-0003 tests complete
bash .agentic/tools/feature.sh F-0003 accepted yes

# Updates single field (no full file read/write!)
```

### 5. `blocker.sh` - Manage HUMAN_NEEDED.md
```bash
bash .agentic/tools/blocker.sh add \
  "Install GUT plugin" \
  "dependency" \
  "GUT plugin needs manual install via Godot Asset Library"

bash .agentic/tools/blocker.sh resolve HN-0001 \
  "Installed GUT plugin successfully"

# Appends/updates (no full file operations)
```

**Rule**: Use scripts for all document updates. Only edit files directly for NEW documents or major restructuring.

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

## Core Guidelines (Unchanged)

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

## Automatic Journaling (Use This!)

**See `.agentic/workflows/automatic_journaling.md`** for full details.

**Natural checkpoints** (log automatically):
- After completing a feature → `session_log.sh`
- After fixing a bug → `session_log.sh`
- After significant work (~30 min) → `session_log.sh`
- At milestones → `journal.sh` (JOURNAL.md)

**Don't wait for session end or user reminders - log as you go!**

---

## Agent Delegation (Use Task Tool!)

**Spawn specialized agents to save tokens and improve quality.**

**Why this saves tokens** (see `.agentic/token_efficiency/agent_delegation_savings.md`):
- **haiku is ~10x cheaper** than opus - use it for exploration/search
- **Fresh context** - subagents don't carry your entire conversation history
- **Parallel execution** - multiple subagents work simultaneously

### Available Agents

Check `.agentic/agents/claude/subagents/` for agent definitions:

| Agent | Use For | Model Tier |
|-------|---------|------------|
| `explore-agent` | Finding code, searching patterns | Cheap/Fast |
| `implementation-agent` | Writing production code (>20 lines) | Mid-tier |
| `test-agent` | Writing and running tests | Mid-tier |
| `review-agent` | Code review before commit | Mid-tier |
| `research-agent` | Documentation lookup, web search | Cheap/Fast |

### When to Delegate

- **Exploration/search tasks**: Use explore-agent with cheap/fast model
- **Implementation >50 lines**: Use implementation-agent with mid-tier model
- **Test writing**: Use test-agent after implementation
- **Multi-file changes**: Consider parallel agents
- **Documentation lookup**: Use research-agent with cheap/fast model

### Model Selection (Tier-Based)

**Note**: Model names evolve. Focus on the tier, not specific names.

- **Cheap/Fast**: Exploration, lookups (e.g., haiku, gpt-4o-mini)
- **Mid-tier**: Implementation, testing, reviews (e.g., sonnet, gpt-4o)
- **Powerful**: Complex architecture, difficult bugs (e.g., opus, o1)

### Example Delegation

```
# For quick codebase exploration
Task tool:
  subagent_type: explore
  model: haiku
  prompt: "Find where user authentication is implemented"

# For implementation
Task tool:
  subagent_type: implementation
  model: sonnet
  prompt: "Implement password reset per spec/acceptance/F-0005.md"
```

### Project-Specific Agents

Review available custom agents at session start:
```bash
ls .agentic/agents/claude/subagents/
```

Create custom agents for domain-specific work:
```bash
bash .agentic/tools/suggest-agents.sh  # See suggestions
bash .agentic/tools/create-agent.sh game-rules  # Create one
```

---

## Claude Projects (Caching for Free!)

**Tip**: If using Claude Projects, add key files for automatic caching:

Upload to project knowledge base:
- `CONTEXT_PACK.md` - Architecture, entry points
- `STACK.md` - Tech stack, conventions
- `spec/PRD.md` - Requirements (if Core+PM)
- Key reference docs

**Benefits** (per [Claude usage guide](https://support.claude.com/en/articles/9797557-usage-limit-best-practices)):
- Cached content doesn't count against limits when reused
- Questions about these docs use fewer tokens
- More messages available for actual work

See `.agentic/token_efficiency/claude_best_practices.md` for details.

---

## Multi-Agent Scenarios

If multiple agents are working simultaneously:

1. **Check `.agentic/spec/.agentic/AGENTS_ACTIVE.md`** for coordination
2. **Use file locking** (scripts handle this automatically)
3. **Communicate via .agentic/AGENTS_ACTIVE.md** (don't step on each other's toes)
4. **Append-only operations** (SESSION_LOG.md, JOURNAL.md) are safe for concurrent use

---

## Checklists (USE THESE - They're Your Friend!)

- **[`checklists/session_start.md`]** - START every session with this
- **[`checklists/session_end.md`]** - END every session with this
- **[`checklists/feature_complete.md`]** - BEFORE claiming "done"
- **[`checklists/before_commit.md`]** - BEFORE every commit
- **[`checklists/smoke_testing.md`]** - RUN the app, verify it works

**These aren't optional - they're how you avoid forgetting critical steps.**

---

## Key Workflows

- **Session management**: `.agentic/workflows/automatic_journaling.md`
- **TDD mode**: `.agentic/workflows/tdd_mode.md`
- **Definition of done**: `.agentic/workflows/definition_of_done.md`
- **Git workflow**: `.agentic/workflows/git_workflow.md`
- **Proactive agent loop**: `.agentic/workflows/proactive_agent_loop.md`

---

## Summary: The Three Mandatory Protocols

1. **Session START**: Read `session_start.md`, load context, check blockers
2. **During work**: Update docs alongside code (not after!), log at checkpoints
3. **Session END**: Run `session_end.md`, update JOURNAL.md, summarize to user

**Checkpoints make you visible** - user knows what you're doing, progress isn't lost if crash.

**Scripts save tokens** - 40x cheaper than reading/rewriting whole files.

**Checklists prevent mistakes** - systematic coverage, nothing forgotten.

---

# 🛑 REMINDER (Read This Too!)

**Before implementing ANY feature:**

```
1. Do acceptance criteria exist?
   └─ NO? → 🛑 STOP. Create them FIRST. DO NOT write code.
   
2. Can I delegate?
   └─ YES? → Spawn subagent. Save tokens. Fresh context.
   
3. Is this small batch?
   └─ NO? → Split it. Max 5-10 files per commit.
```

**Trigger phrases that REQUIRE criteria check:**
- "build", "implement", "add", "create", "let's do", "make", "develop"

**You WILL forget this.** That's why it's at the TOP and BOTTOM of this file.

**Read `.agentic/checklists/feature_start.md` for every feature. No exceptions.**
