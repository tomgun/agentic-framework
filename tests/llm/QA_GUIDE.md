# LLM Behavioral Testing - QA Guide

**Purpose**: Verify that AI agents follow framework guidelines correctly.

---

## Quick Reference

```bash
# Run all automated tests (Claude Code)
bash tests/llm/harness.sh

# Run single test
bash tests/llm/harness.sh tests/llm/tests/001_session_start.sh

# Run with specific model
CLAUDE_MODEL=opus bash tests/llm/harness.sh

# Run with Cursor (manual mode)
TOOL=cursor bash tests/llm/harness.sh tests/llm/tests/001_session_start.sh

# Keep test projects for debugging
KEEP_PROJECTS=1 bash tests/llm/harness.sh
```

---

## Tool Selection

The test harness supports multiple AI tools via the `TOOL` environment variable:

| Tool | Value | Automation | Notes |
|------|-------|------------|-------|
| **Claude Code** | `claude` (default) | Full | CLI-based, fully automated |
| **Cursor** | `cursor` | Partial | IDE-based, requires manual prompt entry |
| **GitHub Copilot** | `copilot` | Partial | IDE-based, requires manual prompt entry |

### Fully Automated (Claude Code)

```bash
# Default - uses Claude Code CLI
bash tests/llm/harness.sh

# Explicit
TOOL=claude bash tests/llm/harness.sh
```

### Semi-Automated (Cursor, Copilot)

For IDE-based tools, the harness:
1. Sets up the test project automatically
2. Prints the prompt you need to enter manually
3. Waits for you to complete the interaction
4. Verifies outcomes automatically

```bash
# Cursor
TOOL=cursor bash tests/llm/harness.sh tests/llm/tests/001_session_start.sh

# GitHub Copilot
TOOL=copilot bash tests/llm/harness.sh tests/llm/tests/001_session_start.sh
```

---

## Model Selection (Claude Code)

```bash
# Use Opus 4.5 (recommended for testing)
CLAUDE_MODEL=opus bash tests/llm/harness.sh

# Use Sonnet (faster, cheaper)
CLAUDE_MODEL=sonnet bash tests/llm/harness.sh

# Use specific model version
CLAUDE_MODEL=claude-opus-4-5-20251101 bash tests/llm/harness.sh
```

**Recommendation**: Use `opus` for verification testing. It's the most capable model and what users with serious projects will use.

---

## Running Tests Manually

If the automated harness doesn't work or you need more control:

### Step 1: Create Test Project

```bash
# Create fresh project
TEST_DIR="/tmp/llm-test-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$TEST_DIR" && cd "$TEST_DIR"
git init
git config user.email "test@example.com"
git config user.name "Test User"

# Install framework
bash ~/code/agentic-framework/install.sh .

# Initial commit
git add -A && git commit -m "Initial setup"

echo "Test project ready at: $TEST_DIR"
```

### Step 2: Open in Your Tool

| Tool | Command |
|------|---------|
| Claude Code | `cd $TEST_DIR && claude --model opus` |
| Cursor | Open `$TEST_DIR` folder in Cursor IDE |
| GitHub Copilot | Open `$TEST_DIR` folder in VS Code |

### Step 3: Run Test Scenario

Each test has a prompt and expected outcomes. Example for `001_session_start`:

**Prompt**: `hi`

**Expected Outcomes**:
- [ ] Agent greets with context (mentions session, project, or context)
- [ ] Agent references reading context files (CONTEXT_PACK, session_start.md)
- [ ] No WIP.md created (simple greeting shouldn't start work)

### Step 4: Record Results

Check the outcomes and record in `tests/VERIFICATION_REPORT.md`:

```markdown
## Test Run: 2026-01-18 - Claude Code (Opus 4.5)

| Test | Result | Notes |
|------|--------|-------|
| 001_session_start | ✅ | Agent greeted with context, mentioned CONTEXT_PACK |
| 002_wip_blocks_commit | ✅ | Correctly blocked, explained WIP |
...
```

---

## Interpreting Results

### Pass (✅)

Agent behavior matches expected outcomes. The framework guidelines are working.

### Fail (❌)

Agent didn't follow expected behavior. This means:

1. **Guideline issue**: The instructions in CLAUDE.md or agent docs aren't clear enough
2. **Model issue**: The model didn't follow instructions (non-determinism)
3. **Test issue**: The test expectations are wrong

**What to do**:
1. Re-run the test (LLMs are non-deterministic)
2. If fails consistently, check the relevant guideline files
3. Update guidelines to be clearer/stronger
4. Re-run to verify fix

### Flaky (⚠️)

Passes sometimes, fails sometimes. This indicates:
- Guidelines are ambiguous
- Model is on the edge of following them

**What to do**:
1. Run 3-5 times to get failure rate
2. Strengthen the guidelines
3. Add more explicit triggers/stops

---

## Test Categories

| Category | Tests | Priority |
|----------|-------|----------|
| **Critical** | 001, 002, 003, 005 | Must pass |
| **Important** | 004 | Should pass |
| **Coverage** | Future tests | Nice to have |

**Critical tests must pass** before releasing a framework version.

---

## Debugging Failed Tests

### Keep the test project

```bash
KEEP_PROJECTS=1 bash tests/llm/harness.sh tests/llm/tests/001_session_start.sh
```

This preserves the `/tmp/llm-test-XXXXXX` directory so you can:
- Inspect files created
- Check git history
- Manually retry prompts

### Check the output file

```bash
cat /tmp/llm-test-XXXXXX/.test_output
```

Contains the full agent response for analysis.

### Run interactively

```bash
cd /tmp/llm-test-XXXXXX
claude --model opus
# Then manually enter the test prompt
```

---

## Adding New Tests

See `tests/llm/README.md` for the test format. Quick example:

```bash
#!/usr/bin/env bash
# Description: Agent should do X when Y
# Category: Important
# Tests: LLM-XXX

setup_test_project "core"  # or "core-pm"

send_prompt "your test prompt"

FAILURES=0
check_output_contains "expected pattern" "Description" || ((FAILURES++))
check_file_exists "expected/file.md" "File created" || ((FAILURES++))

cleanup_test_project
[[ $FAILURES -eq 0 ]]
```

---

## Continuous Improvement Loop

```
1. Identify behavior gap → Write test
2. Run test → Observe failure
3. Update guidelines → CLAUDE.md, agent docs
4. Re-run test → Verify fix
5. Commit both test + guideline changes
6. Repeat
```

This is **TDD for agent behavior**. Short feedback loops = rapid framework improvement.

---

## See Also

- `tests/llm/README.md` - Harness documentation
- `tests/llm/harness.sh` - Test runner source
- `tests/LLM_TEST_PLAN.md` - Full test scenarios (22 tests)
- `tests/VERIFICATION_REPORT.md` - All test results (single source of truth)
- `tests/RUN_LLM_TESTS.md` - Manual test quick start
