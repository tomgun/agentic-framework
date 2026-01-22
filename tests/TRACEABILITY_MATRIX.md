# Framework Traceability Matrix

**Purpose**: Map principles → specs → tests → results for complete coverage visibility.

**Last Updated**: 2026-01-21
**Framework Version**: 0.12.0

---

## Coverage Summary

| Category | Principles | Specs | Tests | Coverage |
|----------|------------|-------|-------|----------|
| Session Management | 5 | 4 | 4 | 80% |
| Commit/Git Workflow | 6 | 5 | 5 | 83% |
| Feature Development | 4 | 4 | 3 | 75% |
| Token Efficiency | 5 | 3 | 5 | 100% |
| Multi-Agent | 3 | 2 | 1 | 33% |
| Quality Gates | 4 | 3 | 2 | 50% |

---

## Detailed Mapping

### 1. Session Management

| Principle | Spec | Test | Status |
|-----------|------|------|--------|
| Proactive greeting at session start | F-0021 | 001_session_start | ✅ |
| WIP recovery on interrupted work | F-0053 | 006_wip_recovery | ✅ |
| Session end summary/handoff | F-0022 | 015_session_end_summary | ✅ |
| Read CONTEXT_PACK first | F-0071 | 008_reads_context_pack | ✅ |
| Reference checklists | F-0016 | 009_mentions_checklist | ✅ |

### 2. Commit/Git Workflow

| Principle | Spec | Test | Status |
|-----------|------|------|--------|
| No auto-commit without approval | AGENTS.md | 005_no_auto_commit | ✅ |
| WIP blocks commit | F-0053 | 002_wip_blocks_commit | ✅ |
| PR workflow for Core+PM | F-0096 | 013_pr_workflow_corepm | ✅ |
| Track PRs in HUMAN_NEEDED | F-0099 | 016_pr_tracking_human_needed | ✅ |
| Warn about untracked files | F-0084 | 017_untracked_files_check | ✅ |
| Branch policy (no direct main) | F-0099 | - | ❌ Missing |

### 3. Feature Development

| Principle | Spec | Test | Status |
|-----------|------|------|--------|
| Acceptance criteria before code | F-0006 | 003_acceptance_first | ✅ |
| Small batch development | F-0007 | 007_small_batch | ✅ |
| Definition of Done checklist | F-0017 | 012_definition_of_done | ✅ |
| Core+PM requires specs | F-0006 | 010_feature_needs_spec | ✅ |
| Core can proceed without | - | 011_core_proceeds_without_spec | ✅ |
| Smoke testing required | F-0013 | - | ❌ Missing |
| Living documentation | F-0072 | - | ❌ Missing |

### 4. Token Efficiency

| Principle | Spec | Test | Status |
|-----------|------|------|--------|
| Use journal.sh (append-only) | F-0071 | 004_uses_journal_script | ✅ |
| Use status.sh (field updates) | F-0071 | 018_uses_status_script | ⚠️ Improved |
| Use blocker.sh (append-only) | F-0071 | 019_uses_blocker_script | ⚠️ Improved |
| Use feature.sh (field updates) | F-0071 | 020_uses_feature_script | ⚠️ Improved |
| No full file read for append | F-0071 | 021_no_full_file_read | ✅ |

### 5. Multi-Agent Coordination

| Principle | Spec | Test | Status |
|-----------|------|------|--------|
| Check AGENTS_ACTIVE.md | F-0031 | 014_multi_agent_awareness | ✅ |
| Register self in AGENTS_ACTIVE | F-0033 | - | ❌ Missing |
| Worktree coordination | F-0097 | - | ❌ Missing |

### 6. Quality Gates

| Principle | Spec | Test | Status |
|-----------|------|------|--------|
| Pre-commit checklist | F-0016 | 002_wip_blocks_commit | ✅ |
| Feature complete checklist | F-0017 | 012_definition_of_done | ✅ |
| Anti-hallucination | F-0055 | - | ❌ Missing |
| Doctor command verification | F-0091 | - | ❌ Missing |

---

## Test Results by Version

### v0.12.0 (2026-01-21)

**Environment**: Claude Code + Opus

| Test | Result | Notes |
|------|--------|-------|
| 001_session_start | ✅ Pass | |
| 002_wip_blocks_commit | ✅ Pass | |
| 003_acceptance_first | ✅ Pass | Occasionally flaky |
| 004_uses_journal_script | ✅ Pass | |
| 005_no_auto_commit | ✅ Pass | |
| 006_wip_recovery | ✅ Pass | Occasionally flaky |
| 007_small_batch | ✅ Pass | |
| 008_reads_context_pack | ✅ Pass | |
| 009_mentions_checklist | ✅ Pass | |
| 010_feature_needs_spec | ✅ Pass | |
| 011_core_proceeds_without_spec | ✅ Pass | |
| 012_definition_of_done | ✅ Pass | |
| 013_pr_workflow_corepm | ✅ Pass | |
| 014_multi_agent_awareness | ✅ Pass | Occasionally flaky |
| 015_session_end_summary | ⚠️ Flaky | Passes individually |
| 016_pr_tracking_human_needed | ⚠️ Flaky | Agent not always mentioning tracking |
| 017_untracked_files_check | ⚠️ Flaky | Passes individually |
| 018_uses_status_script | ⚠️ Improved | Trigger table added to CLAUDE.md, test prompt naturalized |
| 019_uses_blocker_script | ⚠️ Improved | Trigger table added to CLAUDE.md, test prompt naturalized |
| 020_uses_feature_script | ⚠️ Improved | Trigger table added to CLAUDE.md, test prompt naturalized |
| 021_no_full_file_read | ✅ Pass | |

**Summary**: 17/21 reliable, 4 improved (018-020 guidelines updated, need re-test)

---

## Missing Tests (Backlog)

| Priority | Principle | Spec | Notes |
|----------|-----------|------|-------|
| High | Smoke testing required | F-0013 | Agent should run app before claiming done |
| High | Anti-hallucination | F-0055 | Agent shouldn't invent feature status |
| Medium | Living documentation | F-0072 | Docs updated with code changes |
| Medium | Branch policy enforcement | F-0099 | Block direct push to main |
| Low | Worktree coordination | F-0097 | Multi-agent file isolation |
| Low | Doctor command | F-0091 | Agent uses doctor.sh for verification |

---

## How to Use This Matrix

1. **Before release**: Run all tests, update results table
2. **After guideline changes**: Run affected tests, check for regressions
3. **Coverage gaps**: Prioritize missing tests from backlog
4. **Flaky tests**: Investigate LLM prompt improvements

## Running Tests

```bash
# All tests (stops on rate limit, saves progress)
bash tests/llm/harness.sh

# Resume after rate limit (skips already-passed tests)
bash tests/llm/harness.sh --resume

# Check current progress
bash tests/llm/harness.sh --status

# Start fresh (clear saved state)
bash tests/llm/harness.sh --reset

# Critical only
bash tests/llm/harness.sh --critical

# By section
bash tests/llm/harness.sh --section scripts

# Single test
bash tests/llm/harness.sh tests/llm/tests/001_session_start.sh

# Compare models
bash tests/llm/harness.sh --compare-models
```

**Rate Limit Workflow:**
1. Run tests: `bash tests/llm/harness.sh`
2. When rate limited, progress is saved automatically
3. Check status: `bash tests/llm/harness.sh --status`
4. Resume later: `bash tests/llm/harness.sh --resume`
