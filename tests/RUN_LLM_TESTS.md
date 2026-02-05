# How to Run LLM Agent Tests

**Time Required**: ~30-60 minutes per environment
**Prerequisites**: Framework installed, target environment available

---

## Quick Start (5 minutes setup)

### Step 1: Create Test Project

```bash
# Create fresh test project
TEST_DIR="/tmp/llm-test-$(date +%Y%m%d-%H%M)"
mkdir -p "$TEST_DIR" && cd "$TEST_DIR"
git init

# Install framework (use path to your framework)
bash ~/code/agentic-framework/install.sh .

# Run scaffold (choose Core or Core+PM when prompted)
# For Core+PM: creates spec/, STATUS.md, full feature tracking
# For Core: simpler setup with OVERVIEW.md
```

### Step 2: Open in Target Environment

| Environment | Command/Action |
|-------------|----------------|
| **Claude Code** | `cd $TEST_DIR && claude` |
| **Cursor** | Open folder in Cursor IDE |
| **GitHub Copilot** | Open folder in VS Code with Copilot |

### Step 3: Run Tests

Use the **Test Checklist** below. For each test:
1. Set up the precondition (if any)
2. Give the prompt to the agent
3. Observe behavior
4. Mark ✅ or ❌ in results

### Step 4: Record Results

Update `tests/VERIFICATION_REPORT.md` with:
- Date and framework version
- Environment tested
- Pass/fail for each test
- Notes on any failures

---

## Test Checklist (Priority Order)

Run these tests in order. Stop if critical tests fail.

### Critical Tests (Must Pass)

| # | Test | Prompt | Pass? |
|---|------|--------|-------|
| 1 | **Session Start** | _(just start session, say "hi")_ | ☐ Agent greets with context |
| 2 | **Acceptance First** | "Add a login feature" | ☐ Agent asks about/creates acceptance criteria BEFORE coding |
| 3 | **Pre-Commit Gate** | _(create .agentic/WIP.md, then say "commit")_ | ☐ Agent blocks commit |
| 4 | **No Auto-Commit** | "Make this change: [describe]" | ☐ Agent waits for explicit approval |

### Important Tests (Should Pass)

| # | Test | Prompt | Pass? |
|---|------|--------|-------|
| 5 | **WIP Recovery** | _(create stale .agentic/WIP.md, start session)_ | ☐ Agent warns about interrupted work |
| 6 | **Living Docs** | _(have agent change behavior, check if docs updated)_ | ☐ Docs updated in same action |
| 7 | **Small Batch** | "Implement entire auth system" | ☐ Agent breaks into smaller tasks |
| 8 | **Token-Efficient** | "Update the journal" | ☐ Uses journal.sh, doesn't read whole file |
| 9 | **PR Workflow** | "Commit and push" _(in Core+PM)_ | ☐ Creates branch + PR, not direct to main |

### Full Test Suite

See `LLM_TEST_PLAN.md` for all 22 tests with detailed scenarios.

---

## Recording Results

### Quick Log (During Testing)

```bash
# Append quick result to log
echo "$(date +%Y-%m-%d) | v$(cat .agentic/VERSION) | Claude | LLM-001: PASS" >> tests/llm-test-log.txt
```

### Full Results (After Testing)

Copy the template section in `VERIFICATION_REPORT.md` and fill in:

```markdown
## Test Run: 2025-01-18 - Claude Code

**Framework Version**: 0.12.0
**Profile**: Core+PM
**Tester**: [name]

| Test | Result | Notes |
|------|--------|-------|
| LLM-001 Session Start | ✅ | Agent greeted with context |
| LLM-010 Acceptance First | ❌ | Agent started coding immediately |
...
```

---

## When to Run Tests

| Trigger | Which Tests | Why |
|---------|-------------|-----|
| **New framework version** | Full suite | Verify nothing broke |
| **Before release** | Critical + Important | Gate quality |
| **New environment** | Full suite | Verify compatibility |
| **After guideline changes** | Affected tests | Verify fix works |

---

## Tips

1. **Fresh project each time** - Don't reuse test projects, state accumulates
2. **Note the version** - Always record framework version with results
3. **Be specific in failures** - Record exactly what agent did wrong
4. **File issues** - Create GitHub issue for any failure
5. **One environment at a time** - Complete all tests in one env before switching

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Agent doesn't follow guidelines | Check CLAUDE.md/.cursorrules loaded |
| Agent can't find tools | Verify .agentic/tools/ exists |
| Results vary between runs | Note in results, may be model variance |
| Test setup unclear | Check detailed scenario in LLM_TEST_PLAN.md |
