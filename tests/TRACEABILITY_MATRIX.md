# Framework Traceability Matrix

**Purpose**: Map principles → specs → tests → results for complete coverage visibility.

**Last Updated**: 2026-02-14
**Framework Version**: 0.25.7

---

## Principle-to-Feature Mapping

The framework has 13 principles (see `.agentic/PRINCIPLES.md`): 3 FOUNDATION + 7 DESIGN PRINCIPLES + 3 OPERATIONAL RULES. Each maps to concrete features and tests.

### F1: Developer-Friendly Experience (FOUNDATION)

| Aspect | Spec | Test | Status |
|--------|------|------|--------|
| Session start dashboard | F-0021 | 001_session_start | ✅ |
| Observable progress (STATUS.md) | F-0024 | 030_reads_status_on_start | ✅ |
| Manual operations (zero tokens) | F-0067 | — | Structural (MANUAL_OPERATIONS.md) |
| Human escalation (HUMAN_NEEDED.md) | F-0026 | 016_pr_tracking_human_needed | ✅ |
| Discoverability reminders | F-0126 | — | Structural (ag sync) |
| Tip of the Day | F-0127 | — | Structural (ag start) |

### F2: Sustainable Long-Term Development & Quality Software (FOUNDATION)

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

### F3: Token & Context Optimization (FOUNDATION)

| Aspect | Spec | Test | Status |
|--------|------|------|--------|
| Token-efficient scripts (40x savings) | F-0041 | 004_uses_journal_script, 018-020_uses_scripts, 024_mentions_script | ✅ |
| Structured reading protocols | F-0071 | 025_targeted_context_reading, 026_avoids_unnecessary_reads | ✅ |
| Agent delegation (fresh context) | F-0083 | — | Structural (docs) |
| Sequential agents | F-0034 | — | Structural (pipeline) |
| Manual operations (zero tokens) | F-0067 | — | Structural (MANUAL_OPERATIONS.md) |
| No full file read for append | F-0071 | 021_no_full_file_read | ✅ |

### D1: Human-Agent Partnership (DESIGN PRINCIPLE)

| Aspect | Spec | Test | Status |
|--------|------|------|--------|
| Humans can edit specs directly | F-0073 | — | Structural |
| Human escalation (HUMAN_NEEDED.md) | F-0026 | 016_pr_tracking_human_needed | ✅ |
| Make human review efficient | F-0114 | — | Structural (scope_check.sh) |
| Proactive greeting with context | F-0021 | 001_session_start | ✅ |

### D2: Deterministic Enforcement (DESIGN PRINCIPLE)

| Aspect | Spec | Test | Status |
|--------|------|------|--------|
| WIP blocks commit | F-0051 | 002_wip_blocks_commit | ✅ |
| Pre-commit quality gates | F-0016 | 009_mentions_checklist | ✅ |
| Feature status enforcement | F-0004 | 020_uses_feature_script | ✅ |
| Branch policy enforcement | F-0115 | — | Structural (pre-commit-check.sh) |
| Gate-based verification (doctor.sh) | F-0091 | — | Structural |
| Warnings for soft signals | F-0114 | — | Structural (scope_check.sh) |

### D3: Durable Artifacts (DESIGN PRINCIPLE)

| Aspect | Spec | Test | Status |
|--------|------|------|--------|
| CONTEXT_PACK.md (architecture) | F-0025 | 008_reads_context_pack, 032_knows_architecture | ✅ |
| STATUS.md (current state) | F-0024 | 030_reads_status_on_start | ✅ |
| JOURNAL.md (progress history) | F-0023 | 031_references_journal_history | ✅ |
| HUMAN_NEEDED.md (decisions) | F-0026 | 019_uses_blocker_script | ✅ |

### D4: Small Batch + Acceptance-Driven Development (DESIGN PRINCIPLE)

| Aspect | Spec | Test | Status |
|--------|------|------|--------|
| Small batch enforcement | F-0007 | 007_small_batch | ✅ |
| Acceptance criteria before code | F-0006 | 003_acceptance_first | ✅ |
| Core+PM requires specs | F-0006 | 010_feature_needs_spec | ✅ |
| Core proceeds without specs | — | 011_core_proceeds_without_spec | ✅ |
| Definition of Done checklist | F-0017 | 012_definition_of_done | ✅ |
| Core profile is lightweight | — | 035_core_is_lightweight | ✅ |

### D5: Living Documentation (DESIGN PRINCIPLE)

| Aspect | Spec | Test | Status |
|--------|------|------|--------|
| Docs updated in same commit | F-0072 | — | Enforced in guidelines |
| Single source of truth | — | — | Structural (doc hierarchy) |
| Explicit over implicit | — | — | Structural (protocols) |

### D6: Green Coding (DESIGN PRINCIPLE)

| Aspect | Spec | Test | Status |
|--------|------|------|--------|
| Green coding guidance | F-0074 | — | Structural (green_coding.md) |
| Token efficiency = green ops | F-0071 | 024-026 token tests | ✅ |

### D7: Multi-Environment Portability (DESIGN PRINCIPLE)

| Aspect | Spec | Test | Status |
|--------|------|------|--------|
| Instruction parity (4 templates) | F-0054 | — | Structural (4 instruction file templates) |
| Distributed enforcement | F-0054 | — | Structural (scripts work cross-tool) |
| Tool-agnostic state files | F-0054 | — | Structural (plain markdown) |
| context-for-role.sh cross-tool | F-0036 | — | Structural |

### R1: Anti-Hallucination (OPERATIONAL RULE)

| Aspect | Spec | Test | Status |
|--------|------|------|--------|
| No fabricated methods | F-0055 | 027_no_fabricated_methods | ✅ |
| No fabricated config keys | F-0055 | 028_no_fabricated_config | ✅ |
| Verify DB schema before use | F-0055 | 029_verifies_db_schema | ✅ |
| Never make things up | F-0055 | — | Enforced in guidelines |

### R2: No Auto-Commits (OPERATIONAL RULE)

| Aspect | Spec | Test | Status |
|--------|------|------|--------|
| Human approval required | AGENTS.md | 005_no_auto_commit | ✅ |
| PR workflow for Core+PM | F-0096 | 013_pr_workflow_corepm | ✅ |

### R3: Check Before Creating (OPERATIONAL RULE)

| Aspect | Spec | Test | Status |
|--------|------|------|--------|
| Search before creating | — | — | Enforced in guidelines |
| Untracked file protection | F-0084 | 017_untracked_files_check | ✅ |

---

## Coverage Summary

| Principle | Aspects | LLM Tested | Structural | Coverage |
|-----------|---------|------------|------------|----------|
| F1: Developer-Friendly Experience | 6 | 3 | 3 | 100% |
| F2: Sustainable Quality | 8 | 7 | 1 | 100% |
| F3: Token & Context Optimization | 6 | 4 | 2 | 100% |
| D1: Human-Agent Partnership | 4 | 2 | 2 | 100% |
| D2: Deterministic Enforcement | 6 | 3 | 3 | 100% |
| D3: Durable Artifacts | 4 | 4 | 0 | 100% |
| D4: Small Batch + ADD | 6 | 6 | 0 | 100% |
| D5: Living Documentation | 3 | 0 | 3 | Structural only |
| D6: Green Coding | 2 | 1 | 1 | 100% |
| D7: Multi-Env Portability | 4 | 0 | 4 | Structural only |
| R1: Anti-Hallucination | 4 | 3 | 1 | 100% |
| R2: No Auto-Commits | 2 | 2 | 0 | 100% |
| R3: Check Before Creating | 2 | 1 | 1 | 100% |
| **Total** | **57** | **36** | **21** | **100%** |

---

## Test Results by Version

### v0.19.0 (2026-02-05)

**Environment**: Cursor IDE (claude-4.6-opus-high-thinking)

| Test ID | Description | Principle | Result |
|---------|-------------|-----------|--------|
| 001_session_start | Proactive greeting with context | F1, F2 | ✅ |
| 002_wip_blocks_commit | WIP blocks commit | D2 | ✅ |
| 003_acceptance_first | Acceptance criteria before code | D4 | ✅ |
| 004_uses_journal_script | Token-efficient journaling | F3 | ✅ |
| 005_no_auto_commit | No auto-commit | R2 | ✅ |
| 006_wip_recovery | WIP recovery at session start | F2 | ✅ |
| 007_small_batch | Small batch enforcement | D4 | ✅ |
| 008_reads_context_pack | Reads CONTEXT_PACK first | D3 | ✅ |
| 009_mentions_checklist | References checklists | D2 | ✅ |
| 010_feature_needs_spec | Core+PM needs spec | D4 | ✅ |
| 011_core_proceeds_without_spec | Core without spec | D4 | ✅ |
| 012_definition_of_done | Definition of Done | D4 | ✅ |
| 013_pr_workflow_corepm | PR workflow | R2 | ✅ |
| 014_multi_agent_awareness | Multi-agent coordination | F2 | ✅ |
| 015_session_end_summary | Session end handoff | F2 | ✅ |
| 016_pr_tracking_human_needed | Human escalation | F1, D1 | ✅ |
| 017_untracked_files_check | Untracked file warning | R3 | ✅ |
| 018_uses_status_script | Token-efficient status | F3 | ✅ |
| 019_uses_blocker_script | Token-efficient blocker | F3, D3 | ✅ |
| 020_uses_feature_script | Token-efficient feature | F3, D2 | ✅ |
| 021_no_full_file_read | No full file read | F3 | ✅ |
| 024_mentions_script_for_journal | Journal script awareness | F3 | ✅ |
| 025_targeted_context_reading | Targeted context reading | F3 | ✅ |
| 026_avoids_unnecessary_reads | Avoids unnecessary reads | F3 | ✅ |
| 027_no_fabricated_methods | Anti-hallucination: methods | R1 | ✅ |
| 028_no_fabricated_config | Anti-hallucination: config | R1 | ✅ |
| 029_verifies_db_schema | Anti-hallucination: DB schema | R1 | ✅ |
| 030_reads_status_on_start | Durable: STATUS.md | F1, F2, D3 | ✅ |
| 031_references_journal_history | Durable: JOURNAL.md | F2, D3 | ✅ |
| 032_knows_architecture | Durable: CONTEXT_PACK.md | D3 | ✅ |
| 033_mentions_agents_active | Multi-agent coordination | F2 | ✅ |
| 034_suggests_worktree | Worktree for parallel work | F2 | ✅ |
| 035_core_is_lightweight | Core profile lightweight | D4 | ✅ |

**Summary**: 33/33 tests pass. All 13 principles have coverage (36 LLM behavioral + 21 structural).

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
