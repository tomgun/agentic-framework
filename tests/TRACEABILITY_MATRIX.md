# Framework Traceability Matrix

**Purpose**: Map principles → specs → tests → results for complete coverage visibility.

**Last Updated**: 2026-02-13
**Framework Version**: 0.25.6

---

## Principle-to-Feature Mapping

The framework has 12 core principles (see `.agentic/PRINCIPLES.md`): 3 FOUNDATION + 6 NON-NEGOTIABLE + 3 RECOMMENDED. Each maps to concrete features and tests.

### Principle 1: Developer-Friendly Experience (FOUNDATION)

| Aspect | Spec | Test | Status |
|--------|------|------|--------|
| Session start dashboard | F-0021 | 001_session_start | ✅ |
| Observable progress (STATUS.md) | F-0024 | 030_reads_status_on_start | ✅ |
| Manual operations (zero tokens) | F-0067 | — | Structural (MANUAL_OPERATIONS.md) |
| Human escalation (HUMAN_NEEDED.md) | F-0026 | 016_pr_tracking_human_needed | ✅ |
| Discoverability reminders | F-0126 | — | Structural (ag sync) |
| Tip of the Day | F-0127 | — | Structural (ag start) |

### Principle 2: Sustainable Long-Term Development & Quality Software (FOUNDATION)

| Aspect | Spec | Test | Status |
|--------|------|------|--------|
| Durable artifacts survive resets | F-0025 | 008_reads_context_pack, 030_reads_status_on_start, 031_references_journal_history, 032_knows_architecture | ✅ |
| Session continuity via JOURNAL | F-0023 | 004_uses_journal_script, 024_mentions_script_for_journal | ✅ |
| Observable progress (STATUS.md) | F-0024 | 030_reads_status_on_start | ✅ |
| Session start protocol | F-0021 | 001_session_start | ✅ |
| Session end handoff | F-0022 | 015_session_end_summary | ✅ |
| WIP recovery | F-0051 | 006_wip_recovery | ✅ |
| Quality standards wired to agents | F-0015 | — | Structural (context manifests) |
| Spec-driven development | F-0003-0006 | 003_acceptance_first, 010_feature_needs_spec | ✅ |

### Principle 3: Context Efficiency (FOUNDATION)

| Aspect | Spec | Test | Status |
|--------|------|------|--------|
| Token-efficient scripts (40x savings) | F-0041 | 004_uses_journal_script, 018-020_uses_scripts, 024_mentions_script | ✅ |
| Structured reading protocols | F-0071 | 025_targeted_context_reading, 026_avoids_unnecessary_reads | ✅ |
| Agent delegation (fresh context) | F-0083 | — | Structural (docs) |
| Sequential agents | F-0034 | — | Structural (pipeline) |
| Manual operations (zero tokens) | F-0067 | — | Structural (MANUAL_OPERATIONS.md) |
| No full file read for append | F-0071 | 021_no_full_file_read | ✅ |

### Principle 4: Human-Agent Partnership (NON-NEGOTIABLE)

| Aspect | Spec | Test | Status |
|--------|------|------|--------|
| Humans can edit specs directly | F-0073 | — | Structural |
| Human escalation (HUMAN_NEEDED.md) | F-0026 | 016_pr_tracking_human_needed | ✅ |
| Make human review efficient | F-0114 | — | Structural (scope_check.sh) |
| Proactive greeting with context | F-0021 | 001_session_start | ✅ |

### Principle 5: Deterministic Enforcement (NON-NEGOTIABLE)

| Aspect | Spec | Test | Status |
|--------|------|------|--------|
| WIP blocks commit | F-0051 | 002_wip_blocks_commit | ✅ |
| Pre-commit quality gates | F-0016 | 009_mentions_checklist | ✅ |
| Feature status enforcement | F-0004 | 020_uses_feature_script | ✅ |
| Branch policy enforcement | F-0115 | — | Structural (pre-commit-check.sh) |
| Gate-based verification (doctor.sh) | F-0091 | — | Structural |
| Warnings for soft signals | F-0114 | — | Structural (scope_check.sh) |

### Principle 6: Durable Artifacts (NON-NEGOTIABLE)

| Aspect | Spec | Test | Status |
|--------|------|------|--------|
| CONTEXT_PACK.md (architecture) | F-0025 | 008_reads_context_pack, 032_knows_architecture | ✅ |
| STATUS.md (current state) | F-0024 | 030_reads_status_on_start | ✅ |
| JOURNAL.md (progress history) | F-0023 | 031_references_journal_history | ✅ |
| HUMAN_NEEDED.md (decisions) | F-0026 | 019_uses_blocker_script | ✅ |

### Principle 7: Anti-Hallucination (NON-NEGOTIABLE)

| Aspect | Spec | Test | Status |
|--------|------|------|--------|
| No fabricated methods | F-0055 | 027_no_fabricated_methods | ✅ |
| No fabricated config keys | F-0055 | 028_no_fabricated_config | ✅ |
| Verify DB schema before use | F-0055 | 029_verifies_db_schema | ✅ |
| Never make things up | F-0055 | — | Enforced in guidelines |

### Principle 8: No Auto-Commits (NON-NEGOTIABLE)

| Aspect | Spec | Test | Status |
|--------|------|------|--------|
| Human approval required | AGENTS.md | 005_no_auto_commit | ✅ |
| PR workflow for Core+PM | F-0096 | 013_pr_workflow_corepm | ✅ |

### Principle 9: Check Before Creating (NON-NEGOTIABLE)

| Aspect | Spec | Test | Status |
|--------|------|------|--------|
| Search before creating | — | — | Enforced in guidelines |
| Untracked file protection | F-0084 | 017_untracked_files_check | ✅ |

### Principle 10: Small Batch + Acceptance-Driven Development (RECOMMENDED)

| Aspect | Spec | Test | Status |
|--------|------|------|--------|
| Small batch enforcement | F-0007 | 007_small_batch | ✅ |
| Acceptance criteria before code | F-0006 | 003_acceptance_first | ✅ |
| Core+PM requires specs | F-0006 | 010_feature_needs_spec | ✅ |
| Core proceeds without specs | — | 011_core_proceeds_without_spec | ✅ |
| Definition of Done checklist | F-0017 | 012_definition_of_done | ✅ |
| Core profile is lightweight | — | 035_core_is_lightweight | ✅ |

### Principle 11: Living Documentation (RECOMMENDED)

| Aspect | Spec | Test | Status |
|--------|------|------|--------|
| Docs updated in same commit | F-0072 | — | Enforced in guidelines |
| Single source of truth | — | — | Structural (doc hierarchy) |
| Explicit over implicit | — | — | Structural (protocols) |

### Principle 12: Green Coding (RECOMMENDED)

| Aspect | Spec | Test | Status |
|--------|------|------|--------|
| Green coding guidance | F-0074 | — | Structural (green_coding.md) |
| Token efficiency = green ops | F-0071 | 024-026 token tests | ✅ |

---

## Coverage Summary

| Principle | Aspects | LLM Tested | Structural | Coverage |
|-----------|---------|------------|------------|----------|
| 1. Developer-Friendly Experience | 6 | 3 | 3 | 100% |
| 2. Sustainable Quality | 8 | 7 | 1 | 100% |
| 3. Context Efficiency | 6 | 4 | 2 | 100% |
| 4. Human-Agent Partnership | 4 | 2 | 2 | 100% |
| 5. Deterministic Enforcement | 6 | 3 | 3 | 100% |
| 6. Durable Artifacts | 4 | 4 | 0 | 100% |
| 7. Anti-Hallucination | 4 | 3 | 1 | 100% |
| 8. No Auto-Commits | 2 | 2 | 0 | 100% |
| 9. Check Before Creating | 2 | 1 | 1 | 100% |
| 10. Small Batch + ADD | 6 | 6 | 0 | 100% |
| 11. Living Documentation | 3 | 0 | 3 | Structural only |
| 12. Green Coding | 2 | 1 | 1 | 100% |
| **Total** | **53** | **36** | **17** | **100%** |

---

## Test Results by Version

### v0.19.0 (2026-02-05)

**Environment**: Cursor IDE (claude-4.6-opus-high-thinking)

| Test ID | Description | Principle | Result |
|---------|-------------|-----------|--------|
| 001_session_start | Proactive greeting with context | 1, 2 | ✅ |
| 002_wip_blocks_commit | WIP blocks commit | 5 | ✅ |
| 003_acceptance_first | Acceptance criteria before code | 10 | ✅ |
| 004_uses_journal_script | Token-efficient journaling | 3 | ✅ |
| 005_no_auto_commit | No auto-commit | 8 | ✅ |
| 006_wip_recovery | WIP recovery at session start | 2 | ✅ |
| 007_small_batch | Small batch enforcement | 10 | ✅ |
| 008_reads_context_pack | Reads CONTEXT_PACK first | 6 | ✅ |
| 009_mentions_checklist | References checklists | 5 | ✅ |
| 010_feature_needs_spec | Core+PM needs spec | 10 | ✅ |
| 011_core_proceeds_without_spec | Core without spec | 10 | ✅ |
| 012_definition_of_done | Definition of Done | 10 | ✅ |
| 013_pr_workflow_corepm | PR workflow | 8 | ✅ |
| 014_multi_agent_awareness | Multi-agent coordination | 2 | ✅ |
| 015_session_end_summary | Session end handoff | 2 | ✅ |
| 016_pr_tracking_human_needed | Human escalation | 1, 4 | ✅ |
| 017_untracked_files_check | Untracked file warning | 9 | ✅ |
| 018_uses_status_script | Token-efficient status | 3 | ✅ |
| 019_uses_blocker_script | Token-efficient blocker | 3, 6 | ✅ |
| 020_uses_feature_script | Token-efficient feature | 3, 5 | ✅ |
| 021_no_full_file_read | No full file read | 3 | ✅ |
| 024_mentions_script_for_journal | Journal script awareness | 3 | ✅ |
| 025_targeted_context_reading | Targeted context reading | 3 | ✅ |
| 026_avoids_unnecessary_reads | Avoids unnecessary reads | 3 | ✅ |
| 027_no_fabricated_methods | Anti-hallucination: methods | 7 | ✅ |
| 028_no_fabricated_config | Anti-hallucination: config | 7 | ✅ |
| 029_verifies_db_schema | Anti-hallucination: DB schema | 7 | ✅ |
| 030_reads_status_on_start | Durable: STATUS.md | 1, 2, 6 | ✅ |
| 031_references_journal_history | Durable: JOURNAL.md | 2, 6 | ✅ |
| 032_knows_architecture | Durable: CONTEXT_PACK.md | 6 | ✅ |
| 033_mentions_agents_active | Multi-agent coordination | 2 | ✅ |
| 034_suggests_worktree | Worktree for parallel work | 2 | ✅ |
| 035_core_is_lightweight | Core profile lightweight | 10 | ✅ |

**Summary**: 33/33 tests pass. All 12 principles have coverage (36 LLM behavioral + 17 structural).

### v0.12.0 (2026-01-21)

**Environment**: Claude Code + Opus

**Summary**: 17/21 reliable, 4 improved (018-020 guidelines updated).

---

## Missing Tests (Backlog)

| Priority | Aspect | Spec | Notes |
|----------|--------|------|-------|
| Medium | Living documentation sync | F-0072 | Agent updates docs in same commit |
| Medium | Branch policy enforcement | F-0115 | Block direct push to main |
| Low | Worktree coordination | F-0097 | Multi-agent file isolation |
| Low | Doctor command usage | F-0091 | Agent uses doctor.sh for verification |

---

## Running Tests

```bash
# Acceptance criteria validation (171 tests)
bash tests/validate_framework.sh

# Unit tests
bash tests/run_tests.sh

# LLM behavioral tests (CLI mode)
bash tests/llm/harness.sh

# LLM behavioral tests (IDE interactive mode)
python3 tests/llm/interactive_runner.py
```
