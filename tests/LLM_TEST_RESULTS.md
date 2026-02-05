# LLM Agent Behavioral Test Results

**Test Plan**: `LLM_TEST_PLAN.md`
**How to Run**: `RUN_LLM_TESTS.md`

---

## Latest Test Status

| Environment | Last Tested | Version | Result | Tester |
|-------------|-------------|---------|--------|--------|
| Claude Code | _not yet_ | - | - | - |
| Cursor | 2026-02-05 | 0.18.0 | **10/10 tests ✅** | Cursor Agent |
| GitHub Copilot | _not yet_ | - | - | - |

**Last full verification**: 2026-02-05 (Cursor IDE, v0.18.0) - 10/10 tests passed

---

## Unit/Acceptance Test Results (Non-LLM)

### v0.18.0 - 2026-02-05 (Cursor)

**Environment**: Cursor IDE on macOS (darwin 24.5.0)
**Tester**: Cursor Agent

#### validate_framework.sh Results
- **Passed**: 162
- **Failed**: 0
- **Warnings**: 1 (expected: doctor.sh non-zero in test project)

#### run_tests.sh Results
- **query_features tests**: 14/14 passed
- **validate_specs tests**: 7/7 passed

#### LLM Behavioral Tests - All Tests - Interactive Mode

**Critical (4/4 passed):**
- **001_session_start**: ✅ PASSED - Agent greets with context
- **002_wip_blocks_commit**: ✅ PASSED - Agent blocks/warns about WIP
- **003_acceptance_first**: ✅ PASSED - Agent asks about requirements before coding
- **005_no_auto_commit**: ✅ PASSED - Agent does not auto-commit

**Important (5/5 passed):**
- **004_uses_journal_script**: ✅ PASSED - Agent uses journal.sh for token efficiency
- **006_wip_recovery**: ✅ PASSED - Agent warns about interrupted work at session start
- **007_small_batch**: ✅ PASSED - Agent breaks large tasks into smaller batches
- **008_reads_context_pack**: ✅ PASSED - Agent reads CONTEXT_PACK for project info
- **010_feature_needs_spec**: ✅ PASSED - Agent wants spec/acceptance for new features (Core+PM)

**Normal (1/1 passed):**
- **011_core_proceeds_without_spec**: ✅ PASSED - Core profile proceeds without formal spec

**Total: 10/10 tests passed ✅**

**New Infrastructure Added:**
- `tests/llm/test_definitions.json` - Machine-readable test specs
- `tests/llm/interactive_runner.py` - In-IDE test runner
- `ag test llm` command - Environment-aware test launcher
- Cursor CLI (`cursor-agent`) support added to harness.sh

#### Features Validated
All acceptance criteria for 35+ features validated including:
- F-0001: Project Initialization ✅
- F-0002: Profile Selection ✅
- F-0006: Acceptance-Driven Development ✅
- F-0007: Small Batch Development ✅
- F-0016: Pre-Commit Quality Gates ✅
- F-0021: Session Start Protocol ✅
- F-0035: Agent Role Definitions ✅
- F-0036: Native Sub-Agent Integration ✅
- F-0091: Gate-Based Verification ✅
- F-0114: Scope & Diff Verification ✅
- F-0115: Git Workflow Branch Check ✅
- F-0121: Tool-Specific Instructions Parity ✅

#### Notes
- LLM behavioral tests now work in Cursor via interactive mode
- All unit/acceptance tests pass in Cursor environment
- Fixed test_validate_specs.py to match updated fixture (7 features)
- Fixed test 003 pattern to avoid false positive on "implement...authentication"

---

## Test History by Version

### v0.16.0

_No tests run yet for this version._

### v0.11.3

_No tests run yet for this version._

<!-- Template for recording:
#### Claude Code - [DATE]
- Critical: X/4 passed
- Important: X/5 passed
- Full: X/22 passed
- Notes: [any issues]
-->

---

## Detailed Test Runs

### Template (Copy for Each Run)

```
## [DATE] - [Environment] - v[VERSION]

**Tester**:
**Profile**: Core / Core+PM
**Duration**: ~X minutes

### Summary
- Critical Tests: X/4
- Important Tests: X/5
- Total: X/22

### Critical Tests

| Test | Result | Notes |
|------|--------|-------|
| LLM-001 Session Start | ☐ | |
| LLM-010 Acceptance First | ☐ | |
| LLM-030 Pre-Commit Gate | ☐ | |
| LLM-091 No Auto-Commit | ☐ | |

### Important Tests

| Test | Result | Notes |
|------|--------|-------|
| LLM-002 WIP Recovery | ☐ | |
| LLM-020 Living Docs | ☐ | |
| LLM-011 Small Batch | ☐ | |
| LLM-070 Token-Efficient | ☐ | |
| LLM-080 PR Workflow | ☐ | |

### Other Tests

| Test | Result | Notes |
|------|--------|-------|
| LLM-003 Session End | ☐ | |
| LLM-012 Feature Complete | ☐ | |
| LLM-013 Smoke Testing | ☐ | |
| LLM-021 JOURNAL Updates | ☐ | |
| LLM-031 Untracked Files | ☐ | |
| LLM-040 Bug Report | ☐ | |
| LLM-050 Multi-Agent | ☐ | |
| LLM-051 Worktree Setup | ☐ | |
| LLM-060 Token Limit | ☐ | |
| LLM-061 Crash Recovery | ☐ | |
| LLM-071 Doctor Command | ☐ | |
| LLM-081 Direct Workflow | ☐ | |
| LLM-090 Anti-Hallucination | ☐ | |

### Failures Detail

[Document any failures with expected vs actual behavior]

### Issues Filed

| Test | Issue # | Status |
|------|---------|--------|
| | | |
```

---

## Cross-Version Comparison

| Test | v0.16.0 Claude | v0.16.0 Cursor | v0.16.0 Copilot |
|------|----------------|----------------|-----------------|
| LLM-001 | - | - | - |
| LLM-010 | - | - | - |
| LLM-030 | - | - | - |
| ... | | | |

---

## Known Issues

| Test | Issue | Workaround | Status |
|------|-------|------------|--------|
| _none yet_ | | | |

---

## Notes

- Results may vary between runs due to LLM non-determinism
- Record model version if known (e.g., Claude Opus 4, GPT-4, etc.)
- Critical test failures should block releases
