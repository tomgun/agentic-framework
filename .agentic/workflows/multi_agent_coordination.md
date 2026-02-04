# Multi-Agent Coordination Protocol

**Purpose**: Enable multiple AI agents to work simultaneously on different features without conflicts, using Git worktrees and coordination files.

---

## Two Approaches to Multi-Agent Development

This framework supports **two complementary approaches**:

### 1. Native Sub-Agents (Sequential Pipeline)

Use the tool's built-in sub-agent capabilities for **specialized sequential work**:

```
Feature F-0042: User Authentication
  ├── Research Agent → docs/research/auth.md
  ├── Planning Agent → spec/acceptance/F-0042.md
  ├── Test Agent → tests/auth.test.ts (all RED)
  ├── Implementation Agent → src/auth.ts (all GREEN)
  ├── Review Agent → APPROVED
  ├── Spec Update Agent → FEATURES.md updated
  ├── Documentation Agent → docs/auth.md
  └── Git Agent → committed
```

**Best for**: Complex features with clear phases, context efficiency, quality gates.

**Setup**:
- Claude Code: See `.agentic/agents/claude/sub-agents.md`
- Cursor: See `.agentic/agents/cursor/agents-setup.md`
- Role definitions: `.agentic/agents/roles/`

### 2. Git Worktrees (Parallel Features)

Use Git worktrees for **parallel work on different features**:

```
/project/           (main) ← coordination hub
/project-F0042/     (feature/F-0042) ← Agent 1
/project-F0043/     (feature/F-0043) ← Agent 2
```

**Best for**: Independent features, team development, urgent parallel work.

**Setup**: Run `bash .agentic/tools/setup-agent.sh pipeline`

### Choosing the Right Approach

| Scenario | Approach |
|----------|----------|
| Complex feature with research, testing, review phases | Native Sub-Agents |
| Multiple independent features simultaneously | Git Worktrees |
| Single developer, one feature at a time | Single Agent (default) |
| Team with multiple human-agent pairs | Git Worktrees |
| Quality-critical with code review requirements | Native Sub-Agents |

---

## When to Use Multi-Agent Development

**✅ Good for:**
- Large features that can be parallelized
- Independent features with minimal coupling
- Team development with multiple human-agent pairs
- Urgent features that need parallel implementation
- Different technology domains (frontend + backend simultaneously)

**⚠️ Challenges:**
- Merge conflicts (more branches = more conflicts)
- Coordination overhead (agents must sync frequently)
- Dependency management (Feature A needs Feature B)
- Shared resource contention (both agents editing FEATURES.md)

**💡 Best practice**: Start with 2-3 agents max. Add more only if features are truly independent.

## Architecture: Git Worktrees

### What are worktrees?

**Git worktrees** let you have multiple working directories (checkouts) from the same repository:

```bash
# Main worktree (coordination hub)
/Users/dev/project/           # main branch
├── .agentic-state/AGENTS_ACTIVE.md          # Shared coordination file
├── STACK.md                  # Shared (read-only for workers)
├── CONTEXT_PACK.md           # Shared (read-only for workers)
├── spec/                     # Shared specs
└── .agentic/                  # Framework

# Worker worktree 1 (Agent 1)
/Users/dev/project-F0042/     # feature/F-0042 branch
├── STATUS.md                 # Agent 1's local status
├── JOURNAL.md                # Agent 1's progress log
└── [feature code]

# Worker worktree 2 (Agent 2)
/Users/dev/project-F0043/     # feature/F-0043 branch
├── STATUS.md                 # Agent 2's local status
├── JOURNAL.md                # Agent 2's progress log
└── [feature code]
```

**Benefits:**
- Each agent has dedicated directory + branch
- No checkout conflicts (Agent 1 on branch A, Agent 2 on branch B simultaneously)
- Easy to open in separate IDE windows
- Git worktree handles branch management

### Setting Up Worktrees

**Human or orchestrator agent runs:**

```bash
cd /Users/dev/project  # Main worktree (main branch)

# Create worktree for Agent 1 working on F-0042
git worktree add ../project-F0042 -b feature/F-0042
echo "Agent 1: Open Cursor at /Users/dev/project-F0042"

# Create worktree for Agent 2 working on F-0043
git worktree add ../project-F0043 -b feature/F-0043
echo "Agent 2: Open Cursor at /Users/dev/project-F0043"

# List all worktrees
git worktree list
```

**Each agent now works in their own directory.**

## Coordination File: `.agentic-state/AGENTS_ACTIVE.md`

**Location**: Repo root (main worktree)

**Purpose**: Central coordination hub for all agents

**Template:**

```markdown
# Active Agents

Last sync: 2026-01-02 16:00

## Agent 1 (cursor-agent-1)
- **Feature**: F-0042 (password validation)
- **Branch**: feature/F-0042
- **Worktree**: /Users/dev/project-F0042
- **Status**: in_progress
- **Phase**: implementing (30% done)
- **Started**: 2026-01-02 14:30
- **Last update**: 2026-01-02 15:55
- **Next sync**: 2026-01-02 16:15
- **Blocking**: none
- **Blocked by**: none
- **Files editing**: lib/auth.ts, lib/auth.test.ts
- **Notes**: Implementation complete, writing tests now

## Agent 2 (cursor-agent-2)
- **Feature**: F-0043 (user profile page)
- **Branch**: feature/F-0043
- **Worktree**: /Users/dev/project-F0043
- **Status**: blocked
- **Phase**: waiting
- **Started**: 2026-01-02 14:35
- **Last update**: 2026-01-02 15:58
- **Next sync**: 2026-01-02 16:15
- **Blocking**: none
- **Blocked by**: F-0042 (needs auth API to test profile features)
- **Files editing**: pages/profile.tsx, components/ProfileCard.tsx
- **Notes**: UI complete, waiting for F-0042 merge to integrate auth checks

## Agent 3 (cursor-agent-3)
- **Feature**: F-0044 (email notifications)
- **Branch**: feature/F-0044
- **Worktree**: /Users/dev/project-F0044
- **Status**: in_progress
- **Phase**: implementing (60% done)
- **Started**: 2026-01-02 14:40
- **Last update**: 2026-01-02 16:00
- **Next sync**: 2026-01-02 16:15
- **Blocking**: none
- **Blocked by**: none
- **Files editing**: lib/email.ts, lib/email.test.ts, spec/FEATURES.md
- **Notes**: Independent feature, no conflicts expected

## Merge Queue
1. F-0042 (Agent 1) - Ready for review
2. F-0043 (Agent 2) - Waiting on F-0042
3. F-0044 (Agent 3) - Independent, can merge anytime

## Shared File Locks (Prevent Conflicts)
- `spec/FEATURES.md`: Agent 3 editing (adding F-0044 details)
- `CONTEXT_PACK.md`: No locks
- `spec/TECH_SPEC.md`: No locks

## Recent Merges
- 2026-01-02 13:00: F-0041 (login UI) merged by Agent 1

## Known Conflicts
- None currently
```

## Agent Protocol

### Phase 1: Session Start

**Every agent must:**

1. **Open their worktree** (not main repo)
2. **Read `.agentic-state/AGENTS_ACTIVE.md`** from main worktree:
   ```bash
   cat /Users/dev/project/.agentic-state/AGENTS_ACTIVE.md
   ```
3. **Update their entry**:
   - Last update timestamp
   - Current phase
   - Files they're about to edit
4. **Check for conflicts**:
   - Is another agent editing the same files?
   - Is their feature blocked by another agent's work?
5. **Fetch latest from main**:
   ```bash
   git fetch origin main
   ```

**Example agent start message:**

```
Agent 1: "Starting session in worktree /Users/dev/project-F0042
          Feature: F-0042 (password validation)
          
          Checking .agentic-state/AGENTS_ACTIVE.md...
          - Agent 2 is working on F-0043 (profile page), blocked by my work
          - Agent 3 is working on F-0044 (emails), independent
          - No file conflicts detected
          
          Proceeding with implementation. Will update .agentic-state/AGENTS_ACTIVE.md every 15 min."
```

### Phase 2: During Work

**Every 15-30 minutes, agent updates `.agentic-state/AGENTS_ACTIVE.md`:**

```bash
# From agent's worktree, access main worktree file
cd /Users/dev/project  # Main worktree
# Edit .agentic-state/AGENTS_ACTIVE.md: update "Last update", "Phase", "Notes"
git add .agentic-state/AGENTS_ACTIVE.md
git commit -m "docs: Agent 1 progress update (F-0042 60% done)"
git push origin main
```

**What to update:**
- `Last update`: Current timestamp
- `Phase`: planning | implementing | testing | reviewing | blocked | done
- `Notes`: Brief status ("tests passing", "found bug in X", "waiting for review")

**If blocked:**
- Update `Status: blocked`
- Update `Blocked by: F-XXXX (reason)`
- Add note explaining what you need

**If file conflict detected:**
- Check if another agent is editing the same file
- Coordinate in `.agentic-state/AGENTS_ACTIVE.md` notes: "Coordinating with Agent 2 on FEATURES.md edits"

### Phase 3: Before Committing

**Agent checklist:**

1. **Pull latest main** (check for merged changes):
   ```bash
   git fetch origin main
   git merge origin/main  # Into your feature branch
   ```
2. **Resolve conflicts** (if any):
   - If trivial (docs): Resolve automatically
   - If non-trivial (code): Present to human for review
3. **Re-run tests** after merge
4. **Update `.agentic-state/AGENTS_ACTIVE.md`** (mark ready for review):
   ```markdown
   - **Status**: ready_for_review
   - **Phase**: complete
   - **Notes**: All tests passing, ready to merge
   ```

### Phase 4: Create PR (if using PR workflow)

**Agent creates PR:**

```bash
git push origin feature/F-0042

gh pr create \
  --title "feat(auth): Add password validation (F-0042)" \
  --body "Implements F-0042\n\nAgent: cursor-agent-1\nSee: spec/acceptance/F-0042.md" \
  --label "agent-generated"
```

**Update `.agentic-state/AGENTS_ACTIVE.md`:**

```markdown
- **Status**: pr_created
- **PR**: #123
- **Phase**: awaiting_review
```

### Phase 5: After PR Merged

**Agent or orchestrator:**

1. **Update `.agentic-state/AGENTS_ACTIVE.md`**:
   - Move entry to "Recent Merges" section
   - Remove from active list (or mark status: complete)
2. **Notify dependent agents**:
   - If Agent 2 was blocked by this feature, update their entry: "F-0042 merged, unblocked"
3. **Pull main into all worktrees** (so others get your changes):
   ```bash
   cd /Users/dev/project-F0043  # Agent 2's worktree
   git fetch origin main
   git merge origin/main
   ```

## Shared vs. Per-Agent Files

| File | Location | Access | Notes |
|------|----------|--------|-------|
| **Shared (Read-Only for Workers)** ||||
| `STACK.md` | Main worktree | Read-only | Configuration, don't edit |
| `CONTEXT_PACK.md` | Main worktree | Read-only | Architecture, don't edit |
| `spec/PRD.md` | Main worktree | Read-only | Requirements, don't edit |
| `spec/TECH_SPEC.md` | Main worktree | Read-only | Tech decisions, don't edit |
| `spec/NFR.md` | Main worktree | Read-only | Constraints, don't edit |
| **Coordination (Shared Write)** ||||
| `.agentic-state/AGENTS_ACTIVE.md` | Main worktree | ⚠️ Update your entry only | Central coordination |
| `spec/FEATURES.md` | Main worktree | ⚠️ Update your feature only | Lock before editing |
| **Per-Agent (Private)** ||||
| `STATUS.md` | Agent worktree | Read/write freely | Your local status |
| `JOURNAL.md` | Agent worktree | Read/write freely | Your progress log |
| **Code/Tests** ||||
| `src/**`, `lib/**`, etc. | Agent worktree | Read/write freely | Your feature code |
| Shared code (utils, types) | Agent worktree | ⚠️ Coordinate first | High conflict risk |

### File Lock Protocol (Prevent Conflicts)

**Before editing shared files:**

1. **Check `.agentic-state/AGENTS_ACTIVE.md` → "Shared File Locks"**
2. **If file is locked**: Wait or coordinate
3. **If file is free**: Add lock entry
   ```markdown
   ## Shared File Locks
   - `spec/FEATURES.md`: Agent 1 editing (adding F-0042 status)
   ```
4. **Edit file quickly** (< 5 minutes)
5. **Commit and remove lock**

**For long edits**: Coordinate directly with other agents via notes.

## Dependency Management

### Scenario 1: Agent 2 Depends on Agent 1's Work

**Setup:**
- Agent 1: Implementing auth system (F-0042)
- Agent 2: Implementing profile page (F-0043) - needs auth

**Strategy:**

**Option A: Wait (if tightly coupled)**
```markdown
# Agent 2 in .agentic-state/AGENTS_ACTIVE.md
- **Status**: blocked
- **Blocked by**: F-0042 (needs validatePassword function)
- **Notes**: Waiting for F-0042 to merge. Will start UI design in meantime.
```

**Option B: Mock/Stub (if loosely coupled)**
```typescript
// Agent 2: Create stub until Agent 1 merges
// TODO: Replace with real auth after F-0042 merges
function validatePassword(password: string): boolean {
  return true; // Stub for now
}
```

**Option C: Work in parallel with integration later**
- Agent 2: Build UI, routing, components
- Agent 1: Build auth system
- After both merge: Agent 2 integrates auth into UI (small PR)

### Scenario 2: Shared Code Changes

**Setup:**
- Agent 1: Adding new field to User type
- Agent 2: Also needs to add field to User type

**Strategy:**

1. **Coordinate in `.agentic-state/AGENTS_ACTIVE.md`**:
   ```markdown
   ## Coordination Notes
   - Agent 1 & Agent 2: Both need User type changes
   - Decision: Agent 1 will add both fields in one commit
   - Agent 2: Wait for Agent 1's PR to merge, then rebase
   ```

2. **One agent makes the change** (avoid merge conflicts)

3. **Other agent rebases** after merge:
   ```bash
   git fetch origin main
   git rebase origin/main
   ```

## Orchestrator Agent (Optional)

**When to use**: 4+ agents, complex dependencies, tight coordination needed

**Responsibilities:**

1. **Assign features** to worker agents
2. **Maintain `.agentic-state/AGENTS_ACTIVE.md`** (update statuses, merge queue)
3. **Resolve conflicts** (prioritize work, reorder merge queue)
4. **Merge PRs** in dependency order
5. **Update shared docs** after merges (FEATURES.md, CONTEXT_PACK.md)
6. **Monitor progress** (check if agents are blocked)

**Not needed for**: 2-3 agents with independent features (self-coordination via .agentic-state/AGENTS_ACTIVE.md)

**Orchestrator workflow:**

```markdown
# Orchestrator session (every 30-60 min)
1. Read all agent entries in .agentic-state/AGENTS_ACTIVE.md
2. Check for blockers:
   - Is Agent 2 blocked by Agent 1? → Prioritize Agent 1's PR review
   - Are agents editing same files? → Coordinate sequencing
3. Review PRs in merge queue order:
   - Merge F-0042 (unblocks Agent 2)
   - Wait for Agent 2 to rebase and update PR
   - Merge F-0043
4. Update shared docs (FEATURES.md, CONTEXT_PACK.md) after merges
5. Notify agents of changes via .agentic-state/AGENTS_ACTIVE.md notes
```

## Conflict Resolution

### Merge Conflicts (Code)

**Detection:**
```bash
git merge origin/main
# CONFLICT: Merge conflict in lib/auth.ts
```

**Protocol:**
1. **Identify conflict owner**: Whose feature touched this file?
2. **If both agents**: Present conflict to human
   ```
   Agent 1: "Merge conflict in lib/auth.ts with Agent 2's changes.
            Both of us added functions to the same area.
            Need human review to resolve."
   ```
3. **Human resolves** conflict
4. **Agents continue**

**Prevention:**
- Coordinate in `.agentic-state/AGENTS_ACTIVE.md` before editing shared files
- Use feature branches (not shared branches)
- Keep features small and independent

### Priority Conflicts (Blocking)

**Scenario**: Agent 1 and Agent 2 both need resource X

**Resolution:**
1. **Check `.agentic-state/AGENTS_ACTIVE.md` → Merge Queue`**: Who's ahead?
2. **Follow queue order**: First come, first served
3. **Or human decides**: "Agent 1 is higher priority, Agent 2 waits"

### Documentation Conflicts (FEATURES.md)

**Scenario**: Both agents need to update `spec/FEATURES.md`

**Strategy:**
1. **Use file locks** (see above)
2. **Quick edits**: In and out in < 5 min
3. **Or coordinate**: "Agent 1 will update F-0042 entry, Agent 2 will update F-0043 entry in same commit"

## Tools for Multi-Agent Coordination

> **TODO (F-0108)**: The scripts below are planned but not yet implemented. For now use:
> - `worktree.sh` for Git worktree management
> - `.agentic-state/AGENTS_ACTIVE.md` for manual coordination
> - `wip.sh` for work-in-progress tracking

### `.agentic/tools/agents_active.sh` (TODO)

```bash
#!/usr/bin/env bash
# Show active agents and their status

cat .agentic-state/AGENTS_ACTIVE.md | grep -A 10 "^## Agent"
```

### `.agentic/tools/check_agent_conflicts.sh` (TODO)

```bash
#!/usr/bin/env bash
# Check if current agent has conflicts with others

AGENT_ID=$1
FILES_EDITING=$2  # Comma-separated

# Parse .agentic-state/AGENTS_ACTIVE.md
# Check if FILES_EDITING overlap with other agents' "Files editing"
# Output: conflicts or "No conflicts detected"
```

### `.agentic/tools/sync_worktrees.sh` (TODO)

```bash
#!/usr/bin/env bash
# Pull latest main into all worktrees

for worktree in $(git worktree list --porcelain | grep "worktree" | cut -d' ' -f2); do
  echo "Syncing $worktree..."
  cd "$worktree"
  git fetch origin main
  git merge origin/main --no-edit || echo "Merge conflict in $worktree - manual resolution needed"
done
```

## Best Practices

### For Agents:

1. **Update `.agentic-state/AGENTS_ACTIVE.md` frequently** (every 15-30 min)
2. **Check for blockers** before starting work
3. **Coordinate on shared files** (use locks)
4. **Pull main frequently** (every hour or before committing)
5. **Keep features small** (easier to merge, fewer conflicts)

### For Humans:

1. **Assign independent features** to different agents
2. **Review PRs quickly** (don't let agents block each other)
3. **Resolve conflicts promptly** (agents can't do this well)
4. **Monitor `.agentic-state/AGENTS_ACTIVE.md`** (check for stuck agents)
5. **Start with 2 agents**, scale up only if working well

### For Teams:

1. **Use orchestrator agent** for 4+ agents
2. **Daily sync meetings** (or async updates via .agentic-state/AGENTS_ACTIVE.md)
3. **Clear feature ownership** (one feature = one agent)
4. **Define integration points** upfront (APIs, interfaces)
5. **Automate testing** (catch integration bugs early)

## Example: 3 Agents, Independent Features

**Setup:**
```yaml
# STACK.md
git_workflow: pull_request
multi_agent:
  enabled: true
  workers:
    - id: cursor-agent-1
      worktree: /Users/dev/project-F0042
      feature: F-0042
    - id: cursor-agent-2
      worktree: /Users/dev/project-F0043
      feature: F-0043
    - id: cursor-agent-3
      worktree: /Users/dev/project-F0044
      feature: F-0044
```

**Day 1 (14:00):**
```
Human: Creates worktrees, assigns features
Agent 1: Starts F-0042 (auth)
Agent 2: Starts F-0043 (profile), notes dependency on F-0042
Agent 3: Starts F-0044 (emails), independent
```

**Day 1 (16:00):**
```
Agent 1: F-0042 60% done, tests passing
Agent 2: F-0043 UI done, waiting for F-0042 auth
Agent 3: F-0044 80% done, no blockers
```

**Day 1 (18:00):**
```
Agent 1: F-0042 complete, PR created (#123)
Agent 3: F-0044 complete, PR created (#124)
Agent 2: Still blocked, working on docs
```

**Day 2 (10:00):**
```
Human: Reviews PR #123 (Agent 1), merges
Agent 1: Updates .agentic-state/AGENTS_ACTIVE.md: "F-0042 merged"
Agent 2: Pulls main, integrates auth, completes F-0043, PR created (#125)
Human: Merges PR #124 (Agent 3) - independent, no conflicts
```

**Day 2 (14:00):**
```
Human: Reviews PR #125 (Agent 2), merges
All features complete!
```

## Troubleshooting

### "Agent is stuck/blocked"
- Check `.agentic-state/AGENTS_ACTIVE.md` → "Blocked by"
- Prioritize unblocking PR review/merge
- Consider reassigning feature if blocker is long-term

### "Constant merge conflicts"
- Features too tightly coupled → Redesign boundaries
- Agents editing same files → Use file locks or sequential work
- Merge more frequently → Don't let branches diverge

### ".agentic-state/AGENTS_ACTIVE.md not being updated"
- Remind agents to update every 15-30 min
- Add to agent guidelines as non-negotiable
- Use orchestrator to monitor and prompt updates

### "Agent doesn't see other agents' work"
- Agents not pulling main → Add to protocol
- Worktree not synced → Run `sync_worktrees.sh`
- PR not merged yet → Update merge queue priority

## References

### Native Sub-Agents (Sequential Pipeline)
- `.agentic/agents/roles/` - Specialized agent role definitions (8 roles)
- `.agentic/agents/claude/sub-agents.md` - Claude Code sub-agent integration
- `.agentic/agents/cursor/agents-setup.md` - Cursor agent setup
- `.agentic/pipeline/` - Pipeline state files for feature tracking

### Parallel Features (Git Worktrees)
- `.agentic/workflows/git_workflow.md` - Git protocols (PR, direct commits)
- `.agentic/agents/shared/agent_operating_guidelines.md` - Core agent rules
- `.agentic/init/STACK.template.md` - Multi-agent configuration
- Git worktrees docs: https://git-scm.com/docs/git-worktree

### Tools
- `bash .agentic/tools/setup-agent.sh pipeline` - Set up pipeline infrastructure
- `bash .agentic/tools/setup-agent.sh cursor-agents` - Copy roles to .cursor/agents/
- `bash .agentic/tools/project-health.sh` - Manager oversight and pipeline monitoring

