# Git Workflow for Agentic Development

**Purpose**: Define how agents interact with Git, including commit protocols, PR workflows, and multi-agent coordination.

## Core Principle: Human-Reviewed Commits

**🚨 CRITICAL RULE FOR AGENTS:**

**NEVER commit changes without explicit human approval.**

- Always present changes and ask for review first
- Only commit when user explicitly says "commit", "commit this", "commit and push", etc.
- Exception: User grants blanket approval ("auto-commit everything", "commit all changes automatically")

**Why?** Humans need to:
- Review code quality before it enters version history
- Understand what changed and why
- Catch mistakes before they propagate
- Learn from the agent's changes
- Maintain control over their repository

## Workflow Modes

Projects configure their Git workflow in `STACK.md`:

```yaml
git_workflow: direct  # or 'pull_request'
```

### Mode 1: Direct Commits (Default for Solo Developers)

**When to use**: Solo developer, prototyping, simple projects, personal repos

**Agent protocol:**
1. **Implement changes** (code, tests, docs)
2. **Present summary** to user:
   ```
   I've implemented [feature/fix]. Changes:
   - Modified: file1.py (added validateInput function)
   - Modified: test_file1.py (added 3 test cases)
   - Updated: spec/FEATURES.md (marked F-0042 as complete)
   
   Would you like to review the changes before I commit?
   ```
3. **Wait for user approval**: "yes", "commit", "looks good", etc.
4. **Commit with clear message**: Follow conventional commits
5. **Ask about push**: "Should I push this to remote?"

**Example interaction:**
```
Agent: "I've completed F-0042. Would you like to commit?"
Human: "Show me the changes first"
Agent: [presents diff or summary]
Human: "Looks good, commit it"
Agent: [commits]
Agent: "Committed. Push to origin?"
Human: "Yes"
Agent: [pushes]
```

### Mode 2: Pull Request Workflow (Teams / Collaborative)

**When to use**: Team projects, open source, code review required, CI/CD pipelines

**Agent protocol:**
1. **Check for worktree** (multi-agent): Is this agent in a dedicated worktree/branch?
2. **Create feature branch** (if not already on one):
   ```bash
   git checkout -b feature/F-0042-password-validation
   ```
3. **Implement changes** (code, tests, docs)
4. **Commit to feature branch** (after user approval):
   ```bash
   git commit -m "feat(auth): add password validation (F-0042)"
   ```
5. **Push feature branch**:
   ```bash
   git push origin feature/F-0042-password-validation
   ```
6. **Create Pull Request** (via GitHub CLI or API):
   ```bash
   gh pr create --title "feat: Add password validation (F-0042)" \
                --body "Implements F-0042: Password validation\n\nChanges:\n- Added validatePassword function\n- Added unit tests\n- Updated FEATURES.md\n\nAcceptance: spec/acceptance/F-0042.md"
   ```
7. **Notify user**:
   ```
   Agent: "PR created: https://github.com/user/repo/pull/123
          Waiting for review and CI checks.
          What would you like me to work on next?"
   ```

**Configuration in STACK.md:**
```yaml
git_workflow: pull_request
pr_settings:
  draft_by_default: true  # Create draft PRs until agent confirms done
  auto_request_review: true  # Request review from configured reviewers
  require_ci_pass: true  # Don't ask to merge until CI passes
  reviewers: ["human_username"]  # GitHub usernames to auto-assign
```

## Multi-Agent Coordination (Worktrees)

**When to use**: Multiple agents working on different features simultaneously

### Setup: Worktrees

**Main agent (orchestrator) creates worktrees:**

```bash
# Main worktree (coordination, shared docs)
cd /Users/developer/project

# Agent 1 worktree: feature F-0042
git worktree add ../project-agent1-F0042 -b feature/F-0042
# Agent 2 worktree: feature F-0043
git worktree add ../project-agent2-F0043 -b feature/F-0043
# Agent 3 worktree: feature F-0044
git worktree add ../project-agent3-F0044 -b feature/F-0044
```

**Each agent works in its own directory with its own branch.**

### Shared vs. Per-Agent State

| File | Shared (main worktree) | Per-Agent (feature worktree) |
|------|------------------------|------------------------------|
| `STACK.md` | ✅ Read-only | ❌ Don't edit |
| `CONTEXT_PACK.md` | ✅ Read-only | ❌ Don't edit |
| `spec/FEATURES.md` | ✅ Read-only (check assigned features) | ⚠️ Only update your feature |
| `spec/PRD.md`, `spec/TECH_SPEC.md` | ✅ Read-only | ❌ Don't edit |
| `spec/NFR.md` | ✅ Read-only | ❌ Don't edit |
| `STATUS.md` | ❌ Don't use | ✅ Per-agent (your status only) |
| `JOURNAL.md` | ❌ Don't use | ✅ Per-agent (your progress) |
| `AGENTS_ACTIVE.md` | ✅ Shared coordination | ⚠️ Update your entry |
| Code files | ⚠️ Depends on feature | ✅ Edit freely in your feature |

### Coordination Protocol

**File: `AGENTS_ACTIVE.md` (at repo root)**

```markdown
# Active Agents

## Agent 1 (cursor-agent-1)
- Feature: F-0042 (password validation)
- Branch: feature/F-0042
- Worktree: ../project-agent1-F0042
- Status: in_progress
- Started: 2026-01-02 14:30
- Blocking: none
- Blocked by: none
- Last update: 2026-01-02 15:45
- Next sync: 2026-01-02 16:00

## Agent 2 (cursor-agent-2)
- Feature: F-0043 (user profile page)
- Branch: feature/F-0043
- Worktree: ../project-agent2-F0043
- Status: in_progress
- Started: 2026-01-02 14:35
- Blocking: none
- Blocked by: F-0042 (needs auth working first)
- Last update: 2026-01-02 15:50
- Next sync: 2026-01-02 16:00
- Note: Waiting for F-0042 to merge before completing integration tests

## Agent 3 (cursor-agent-3)
- Feature: F-0044 (password reset flow)
- Branch: feature/F-0044
- Worktree: ../project-agent3-F0044
- Status: in_progress
- Started: 2026-01-02 14:40
- Blocking: none
- Blocked by: F-0042 (depends on validatePassword function)
- Last update: 2026-01-02 15:55
- Next sync: 2026-01-02 16:00
- Note: Can proceed with UI/routing, will integrate with F-0042 after merge
```

### Agent Protocol in Multi-Agent Mode

**At session start:**
1. **Check `AGENTS_ACTIVE.md`**: See what other agents are working on
2. **Update your entry**: Status, last update timestamp
3. **Check dependencies**: Is your feature blocked by another agent's work?
4. **Check for conflicts**: Will you edit files another agent is editing?

**While working:**
1. **Stay in your worktree/branch**: Don't touch main branch
2. **Update `AGENTS_ACTIVE.md` every 15-30 min**: Keep others informed
3. **Coordinate on shared files**: If you must edit `FEATURES.md`, sync carefully
4. **Use feature toggles**: If your code depends on incomplete features

**Before committing:**
1. **Check `AGENTS_ACTIVE.md` again**: Any conflicts emerged?
2. **Pull latest from main**: `git fetch origin main`
3. **Check for merge conflicts**: `git merge origin/main` (in your branch)
4. **Resolve conflicts** (if any): Ask human for help with non-trivial conflicts

**After PR merged:**
1. **Update `AGENTS_ACTIVE.md`**: Mark feature complete, remove entry or mark "done"
2. **Notify dependent agents**: Add notes to their entries if they were waiting on you
3. **Sync main worktree**: Main agent pulls latest into shared worktree

### Orchestrator Agent (Optional)

**Role**: Coordinates multiple worker agents, resolves conflicts, manages merge order

**Responsibilities:**
- Maintains `AGENTS_ACTIVE.md`
- Assigns features to worker agents
- Monitors progress and dependencies
- Resolves merge conflicts
- Merges PRs in correct order (respecting dependencies)
- Updates shared documentation after merges

**Not needed for**: 2-3 agents with independent features

**Useful for**: 4+ agents, complex dependencies, tight coupling

## Commit Message Convention

Follow **Conventional Commits**:

```
<type>(<scope>): <subject>

[optional body]

[optional footer: references to features/issues]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `test`: Adding or updating tests
- `chore`: Maintenance (deps, config)

**Examples:**
```bash
# Simple feature
git commit -m "feat(auth): add password validation (F-0042)"

# Bug fix with details
git commit -m "fix(auth): handle null email in validatePassword

Password validation was throwing when email field was null.
Now explicitly checks for null/undefined before validation.

Fixes: F-0042 acceptance criterion 4
"

# Documentation update
git commit -m "docs(features): mark F-0042 as shipped"

# Multi-agent coordination
git commit -m "feat(profile): add user profile page (F-0043)

Integrates with auth system from F-0042.

Depends-on: F-0042
Agent: cursor-agent-2
"
```

## Integration with Framework

### In `STACK.md`:

```yaml
# Git workflow configuration
git_workflow: pull_request  # or 'direct'

# PR settings (if using pull_request mode)
pr_settings:
  draft_by_default: true
  auto_request_review: true
  require_ci_pass: true
  reviewers: ["human_username"]

# Multi-agent settings (if using worktrees)
multi_agent:
  enabled: true
  orchestrator: cursor-main  # Main agent identifier
  workers:
    - id: cursor-agent-1
      worktree: ../project-agent1
    - id: cursor-agent-2
      worktree: ../project-agent2
```

### In agent guidelines:

- Read `git_workflow` from `STACK.md` before committing
- If `multi_agent.enabled: true`, check `AGENTS_ACTIVE.md` at session start
- Always get human approval before committing (unless explicitly told to auto-commit)

### Tool integration:

```bash
# Check git workflow mode
bash .agentic/tools/git_mode.sh

# List active agents
bash .agentic/tools/agents_active.sh

# Check for conflicts with other agents
bash .agentic/tools/check_agent_conflicts.sh
```

## Troubleshooting

### "I'm blocked by another agent's work"
1. Check their PR status
2. If urgent: Ask human to prioritize that PR
3. If not urgent: Work on a different feature
4. If possible: Use feature toggles or mocks to unblock yourself

### "Merge conflict with another agent's changes"
1. Don't resolve automatically
2. Present conflict to human: "File X has conflicts with Agent 2's changes. Need your review."
3. Wait for human to resolve or give guidance

### "I need to update shared docs (FEATURES.md, CONTEXT_PACK.md)"
1. In PR mode: Do it in your PR, will be reviewed
2. In multi-agent mode: Coordinate in `AGENTS_ACTIVE.md` first
3. Keep changes minimal and scoped to your feature

## Security & Safety

**NEVER:**
- Force push (`git push --force`) without explicit human approval
- Push to `main`/`master` directly (unless `git_workflow: direct` and approved)
- Delete branches other agents are using
- Rewrite history (`git rebase`, `git reset --hard`) in shared branches
- Skip hooks (`--no-verify`) without explicit permission

**ALWAYS:**
- Get human review before committing
- Respect branch protection rules
- Check `AGENTS_ACTIVE.md` before force operations
- Ask before deleting any branch

## Examples

### Example 1: Solo Developer, Direct Mode

```yaml
# STACK.md
git_workflow: direct
```

**Agent session:**
```
Agent: "I've implemented password validation (F-0042). Changes:
        - lib/auth.ts: Added validatePassword function
        - lib/auth.test.ts: Added 5 test cases
        - spec/FEATURES.md: Marked F-0042 implementation complete
        
        All tests pass. Ready to commit?"
Human: "Yes, commit it"
Agent: [commits with message "feat(auth): add password validation (F-0042)"]
Agent: "Committed. Push to origin?"
Human: "Yes"
Agent: [pushes]
```

### Example 2: Team Project, PR Mode

```yaml
# STACK.md
git_workflow: pull_request
pr_settings:
  draft_by_default: false
  auto_request_review: true
  reviewers: ["alice", "bob"]
```

**Agent session:**
```
Agent: "I've completed F-0042. Creating PR..."
Agent: [creates PR #123]
Agent: "PR created: https://github.com/team/project/pull/123
        Reviewers: @alice, @bob
        CI checks running...
        
        What should I work on next?"
Human: "Start on F-0043"
Agent: [checks out new branch, starts F-0043]
```

### Example 3: Multi-Agent with Worktrees

```yaml
# STACK.md
git_workflow: pull_request
multi_agent:
  enabled: true
  orchestrator: cursor-main
```

**Agent 1 session:**
```
Agent1: [reads AGENTS_ACTIVE.md]
Agent1: "I see Agent 2 is working on F-0043 (profile page).
         I'm assigned F-0042 (auth). No conflicts expected.
         Starting implementation in worktree ../project-agent1-F0042..."
[... works on F-0042 ...]
Agent1: [updates AGENTS_ACTIVE.md with progress]
Agent1: "F-0042 complete. Creating PR..."
```

**Agent 2 session (blocked by Agent 1):**
```
Agent2: [reads AGENTS_ACTIVE.md]
Agent2: "I'm working on F-0043 (profile page).
         This depends on F-0042 (auth) which Agent 1 is finishing.
         I'll start with the UI/routing parts that don't need auth yet.
         Will integrate auth after Agent 1's PR merges."
[... works on independent parts ...]
Agent2: [updates AGENTS_ACTIVE.md: "Blocked by F-0042, proceeding with UI"]
```

## References

- `.agentic/agents/shared/agent_operating_guidelines.md` - Core agent rules
- `.agentic/workflows/dev_loop.md` - Development workflow
- `.agentic/workflows/multi_agent_coordination.md` - Detailed multi-agent protocol
- `.agentic/init/STACK.template.md` - Configuration template

