# Claude (Anthropic) Instructions

You are working in a repository that uses the **Agentic Framework** for AI-assisted development.

---

## 🚨 MANDATORY: Session Start Protocol

**BEFORE doing ANY work, run this protocol:**

1. **Read `.agentic/checklists/session_start.md`** (2-minute checklist)
   - Loads project context efficiently
   - Identifies current task/blockers
   - Sets up session correctly

2. **Use token-efficient scripts** (not file edits):
   ```bash
   # Append to JOURNAL.md (don't read/rewrite whole file!)
   bash .agentic/tools/journal.sh "Topic" "What done" "What next" "Blockers"
   
   # Update STATUS.md sections (don't rewrite whole file!)
   bash .agentic/tools/status.sh focus "Current task description"
   ```

3. **Check for blockers in `HUMAN_NEEDED.md`**
   - If blockers exist, address them FIRST or escalate

**Why mandatory**: Without this, you'll waste tokens re-reading context and miss critical blockers.

**Checkpoint**: After reading session_start.md, tell user: "✓ Session started. Working on: [task]. Blockers: [none/list]"

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

**Located in `.agentic/tools/`** - these save massive tokens by avoiding full file reads:

### 1. `journal.sh` - Append to JOURNAL.md
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

## Core Guidelines (Unchanged)

1. **Read at session start**:
   - `AGENTS.md` (if present)
   - `.agentic/agents/shared/agent_operating_guidelines.md` (mandatory)
   - `CONTEXT_PACK.md` (where things are, how to run)
   - `STATUS.md` (current focus, next steps)

2. **Follow programming standards** (`.agentic/quality/programming_standards.md`):
   - Security first, clear naming, small functions, explicit errors
   
3. **Follow testing standards** (`.agentic/quality/test_strategy.md`):
   - Happy path + edge cases + invalid input + time-based behavior

4. **Development approach**:
   - Check `STACK.md` for `development_mode` (tdd recommended)
   - TDD: Write tests FIRST (see `.agentic/workflows/tdd_mode.md`)

5. **Never auto-commit**:
   - ALWAYS show changes to human first
   - ONLY commit when human explicitly approves

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

1. **Check `.agentic/spec/AGENTS_ACTIVE.md`** for coordination
2. **Use file locking** (scripts handle this automatically)
3. **Communicate via AGENTS_ACTIVE.md** (don't step on each other's toes)
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

**Follow these, and you'll be a reliable, efficient agent.** ✅
