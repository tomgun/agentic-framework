# LLM Agent Behavioral Test Results

**Test Plan**: `LLM_TEST_PLAN.md`
**How to Run**: `RUN_LLM_TESTS.md`

---

## Latest Test Status

| Environment | Last Tested | Version | Result | Tester |
|-------------|-------------|---------|--------|--------|
| Claude Code | _not yet_ | - | - | - |
| Cursor | 2026-02-05 | 0.19.0 | **22/22 tests ✅** | Cursor Agent |
| GitHub Copilot | _not yet_ | - | - | - |

**Last full verification**: 2026-02-05 (Cursor IDE, v0.19.0) - 22/22 tests passed (Critical: 7/7, Important: 12/12, Normal: 3/3)

---

## Unit/Acceptance Test Results (Non-LLM)

### v0.19.0 - 2026-02-05 (Cursor)

**Environment**: Cursor IDE on macOS (darwin 24.5.0)
**Tester**: Cursor Agent (claude-4.6-opus-high-thinking)

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

**Original Tests Total: 10/10 passed ✅**

#### Value Proposition Tests (v0.19.0)

**Token Efficiency (3/3 passed):**
- **024_mentions_script_for_journal**: ✅ PASSED - Agent mentions journal.sh/ag journal for token efficiency
- **025_targeted_context_reading**: ✅ PASSED - Agent uses CONTEXT_PACK for targeted info, not source scanning
- **026_avoids_unnecessary_reads**: ✅ PASSED - Agent reads only relevant file for simple edit

**Anti-Hallucination (3/3 passed - Critical):**
- **027_no_fabricated_methods**: ✅ PASSED - Agent identifies only getUser/updateUser exist, doesn't invent syncPreferences
- **028_no_fabricated_config**: ✅ PASSED - Agent notes MAX_RETRIES not in config, offers to add it
- **029_verifies_db_schema**: ✅ PASSED - Agent checks schema, reports last_login missing, suggests migration

**Durable Artifacts (3/3 passed):**
- **030_reads_status_on_start**: ✅ PASSED - Agent reads STATUS.md, references payment gateway and Stripe
- **031_references_journal_history**: ✅ PASSED - Agent reads JOURNAL.md, reports race condition fix in auth
- **032_knows_architecture_from_context_pack**: ✅ PASSED - Agent references packages/api/prisma/migrations/ from CONTEXT_PACK

**Multi-Agent & Profiles (3/3 passed):**
- **033_mentions_agents_active**: ✅ PASSED - Agent mentions AGENTS_ACTIVE coordination and worktrees
- **034_suggests_worktree_for_parallel**: ✅ PASSED - Agent recommends git worktree for isolation
- **035_core_is_lightweight**: ✅ PASSED - Agent implements function directly without requiring spec/feature ID

**Grand Total: 22/22 tests passed ✅**
- Critical: 7/7 (session, commit, acceptance, anti-hallucination)
- Important: 12/12 (scripts, context, durable artifacts, multi-agent, profiles)
- Normal: 3/3 (core profile, token efficiency, parallel work)

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
- LLM behavioral tests run in Cursor via interactive mode with pattern verification
- All unit/acceptance tests pass in Cursor environment
- Fixed test_validate_specs.py to match updated fixture (7 features)
- Fixed test 003 pattern to avoid false positive on "implement...authentication"
- Anti-hallucination tests (027-029) use partial real code - agent correctly refuses to fabricate methods/config/fields
- Token efficiency tests verify agent awareness of scripts, not enforcement
- Test projects created for critical tests; file/commit checks verified independently

---

## Test History by Version

### v0.16.0

_No tests run yet for this version._

### v0.11.3

_No tests run yet for this version._

<!-- Template for recording:
#### Claude Code - [DATE]
- Critical: X/7 passed
- Important: X/11 passed
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
