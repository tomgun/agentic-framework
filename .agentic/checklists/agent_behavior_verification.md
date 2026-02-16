# Agent Behavior Verification Checklist

**Purpose**: Manual verification of agent behavior that cannot be automated.
These tests require a real LLM agent interacting with the framework.

---

## How to Use This Checklist

1. Create a fresh test project (Discovery or Formal profile)
2. Start an AI agent session (Claude, Cursor, etc.)
3. Walk through each test section
4. Check off items as the agent demonstrates the behavior
5. Note any failures for framework improvement

---

## 1. Session Protocol Tests

### Session Start
- [ ] Agent reads session_start.md checklist (or equivalent)
- [ ] Agent checks AGENTS_ACTIVE.md for other active agents
- [ ] Agent reads CONTEXT_PACK.md before coding
- [ ] Agent reads STATUS.md for current focus
- [ ] Agent checks for .upgrade_pending marker
- [ ] Agent checks for .agentic-state/WIP.md (interrupted work)

### Session End
- [ ] Agent updates JOURNAL.md with session summary
- [ ] Agent updates STATUS.md with current state
- [ ] Agent checks for uncommitted changes
- [ ] Agent checks for untracked files
- [ ] Agent notes blockers in HUMAN_NEEDED.md if any

---

## 2. Feature Workflow Tests (Formal Only)

### Before Implementation
- [ ] Agent creates acceptance criteria file before coding
- [ ] Agent reads existing acceptance criteria for the feature
- [ ] Agent plans implementation based on acceptance criteria

### During Implementation
- [ ] Agent updates FEATURES.md status to in_progress
- [ ] Agent follows TDD when development_mode is tdd
- [ ] Agent creates small, focused commits
- [ ] Agent logs progress at natural checkpoints

### After Implementation
- [ ] Agent runs smoke test before marking complete
- [ ] Agent verifies all acceptance criteria met
- [ ] Agent updates FEATURES.md status to shipped
- [ ] Agent uses feature_complete.md checklist

---

## 3. Git Workflow Tests (Formal)

### PR-Based Workflow
- [ ] Agent creates feature branch (not commits to main)
- [ ] Agent uses conventional branch naming: feature/F-####-description
- [ ] Agent creates PR with summary and test plan
- [ ] Agent does NOT auto-merge without approval

### Commit Quality
- [ ] Agent runs doctor.sh (or equivalent) before committing
- [ ] Agent does NOT commit with active WIP
- [ ] Agent does NOT commit with untracked files warning
- [ ] Commit messages are descriptive and conventional

---

## 4. Quality Tests

### Code Quality
- [ ] Agent follows programming_standards.md guidelines
- [ ] Agent writes secure code (no obvious vulnerabilities)
- [ ] Agent handles errors appropriately
- [ ] Agent writes clear, maintainable code

### Test Quality
- [ ] Agent writes tests for new functionality
- [ ] Tests cover happy path, edge cases, error cases
- [ ] Agent runs tests before claiming "done"

---

## 5. Documentation Tests

### Living Documentation
- [ ] Agent updates docs when changing code behavior
- [ ] Agent updates CONTEXT_PACK.md for architecture changes
- [ ] Agent does NOT leave outdated documentation

---

## 6. Recovery Tests

### Interrupted Session
- [ ] Agent reads .agentic-state/WIP.md if present
- [ ] Agent can resume work from where it left off
- [ ] Agent uses JOURNAL.md for context recovery

### Error Recovery
- [ ] Agent handles tool failures gracefully
- [ ] Agent provides clear error messages to user
- [ ] Agent suggests fixes for common issues

---

## 7. Multi-Agent Coordination Tests

### Agent Awareness
- [ ] Agent detects other active agents via AGENTS_ACTIVE.md
- [ ] Agent communicates with user about coordination
- [ ] Agent does NOT overwrite other agents' work

---

## Test Results Template

```markdown
## Test Run: [DATE]
- Profile: [Discovery / Formal]
- Agent: [Claude Code / Cursor / etc.]
- Tester: [Name]

### Results
- Session Protocol: [X/6] passed
- Feature Workflow: [X/12] passed (PM only)
- Git Workflow: [X/7] passed
- Quality: [X/6] passed
- Documentation: [X/3] passed
- Recovery: [X/5] passed
- Multi-Agent: [X/3] passed

### Issues Found
1. [Description of any failures]

### Recommendations
1. [Suggested improvements]
```

---

## Notes

- These tests are subjective and require human judgment
- Run periodically to catch behavioral regressions
- Use fresh projects to avoid cached agent context
- Test both Discovery and Formal profiles separately
