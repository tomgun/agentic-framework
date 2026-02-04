# LLM Agent Behavioral Test Results

**Test Plan**: `LLM_TEST_PLAN.md`
**How to Run**: `RUN_LLM_TESTS.md`

---

## Latest Test Status

| Environment | Last Tested | Version | Result | Tester |
|-------------|-------------|---------|--------|--------|
| Claude Code | _not yet_ | - | - | - |
| Cursor | _not yet_ | - | - | - |
| GitHub Copilot | _not yet_ | - | - | - |

**Last full verification**: _not yet_

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
