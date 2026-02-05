# Automated LLM Behavioral Tests

Automated testing of agent behaviors using fresh project contexts.

## Quick Start

```bash
# Run all tests
bash tests/llm/harness.sh

# Run critical tests only (fast, cheap)
bash tests/llm/harness.sh --critical

# Run tests by section
bash tests/llm/harness.sh --section trigger

# Compare Opus vs Sonnet (generates compatibility report)
bash tests/llm/harness.sh --compare-models

# List available tests/sections
bash tests/llm/harness.sh --list
bash tests/llm/harness.sh --sections

# Keep temp projects for debugging
KEEP_PROJECTS=1 bash tests/llm/harness.sh
```

## How It Works

1. **Fresh context per test**: Each test creates a new temp project with the framework installed
2. **Real agent interaction**: Sends prompts to Claude CLI, captures output
3. **Outcome verification**: Checks output patterns, file existence, git state
4. **Pass/fail reporting**: Clear results for each test

## Test Structure

Each test is a bash script in `tests/llm/tests/`:

```bash
#!/usr/bin/env bash
# Description: What this test verifies
# Category: Critical|Important|Other
# Tests: LLM-XXX (reference to LLM_TEST_PLAN.md)

# Setup - create fresh project
setup_test_project "core"  # or "core-pm"

# Action - send prompt to agent
send_prompt "your prompt here"

# Verify - check outcomes
FAILURES=0
check_output_contains "expected pattern" "Description" || ((FAILURES++))
check_file_exists "some/file.md" "File was created" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
```

## Available Helper Functions

| Function | Description |
|----------|-------------|
| `setup_test_project "profile"` | Create temp project (core or core-pm) |
| `send_prompt "text"` | Send prompt to Claude, capture output |
| `check_output_contains "pattern" "desc"` | Verify output has pattern |
| `check_output_not_contains "pattern" "desc"` | Verify output lacks pattern |
| `check_file_exists "path" "desc"` | Verify file was created |
| `check_file_not_exists "path" "desc"` | Verify file was NOT created |
| `check_file_contains "path" "pattern" "desc"` | Verify file content |
| `cleanup_test_project` | Remove temp project |

## Current Tests

| Test | Category | Description |
|------|----------|-------------|
| 001_session_start | Critical | Agent greets with context |
| 002_wip_blocks_commit | Critical | WIP.md blocks commits |
| 003_acceptance_first | Critical | Agent asks about requirements before coding |
| 004_uses_journal_script | Important | Agent uses journal.sh, not file edits |
| 005_no_auto_commit | Critical | Agent doesn't commit without approval |
| 006_wip_recovery | Important | Agent warns about interrupted work |
| 007_small_batch | Important | Agent breaks large tasks into pieces |
| 008_reads_context_pack | Important | Agent reads CONTEXT_PACK.md |
| 009_mentions_checklist | Normal | Agent references checklists |
| 010_feature_needs_spec | Important | Core+PM requires spec before coding |
| 011_core_proceeds_without_spec | Normal | Core profile proceeds without spec |

## Adding New Tests

1. Create `tests/llm/tests/NNN_test_name.sh`
2. Add description comment at top
3. Use helper functions (setup, send_prompt, check_*)
4. Return 0 for pass, 1 for fail

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_CMD` | `claude` | Path to Claude CLI |
| `CLAUDE_MODEL` | `opus` | Model: opus, sonnet, or full model name |
| `TOOL` | `claude` | Tool: claude, cursor, copilot |
| `KEEP_PROJECTS` | `0` | Set to `1` to keep temp projects |

## Limitations

- Tests depend on Claude CLI behavior and availability
- Non-determinism: LLM responses vary between runs
- Some tests may need adjustment based on model version
- Interactive features can't be fully tested

## Feedback Loop

Use these tests to iterate on framework guidelines:

1. Write test for desired behavior
2. Run test → observe failure
3. Update CLAUDE.md or agent guidelines
4. Re-run test → verify fix
5. Repeat until behavior is consistent

## See Also

- `tests/LLM_TEST_PLAN.md` - Full test scenarios (22 tests)
- `tests/VERIFICATION_REPORT.md` - All test results (single source of truth)
- `tests/RUN_LLM_TESTS.md` - Manual test guide
