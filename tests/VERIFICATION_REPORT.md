# Framework Verification Report

**Single source of truth for ALL test results.**

**Generated**: 2026-03-31
**Framework Version**: 0.77.0

---

## Executive Summary

| Metric | Value |
|--------|-------|
| Acceptance Tests (validate_framework.sh) | 723 passed, 0 failed, 8 warnings |
| Integration Tests (test_workflow_breaker.sh) | 22 passed, 1 known gap |
| Unit Tests (run_tests.sh) | 21/21 passed |
| LLM Behavioral Tests (harness.sh) | 81 defined (42/42 verified via Claude Code) |
| **Total Tests** | **766+ passing** |
| Test Pass Rate | 100% (acceptance + unit) |
| Principles Covered | 13/13 |
| Profile Coverage | Discovery ✅, Formal ✅, Autonomous Formal ✅ |

---

## Latest Test Runs

| Environment | Last Tested | Version | Result | Tester |
|-------------|-------------|---------|--------|--------|
| validate_framework.sh | 2026-03-31 | 0.77.0 | **723/723 (100%)** | bash |
| test_workflow_breaker.sh | 2026-03-31 | 0.77.0 | **22/23 (1 known gap)** | bash |
| Claude Code (LLM) | 2026-02-09 | 0.34.0 | **42/42 (100%)** | Sonnet |
| Cursor CLI (agent) | 2026-02-06 | 0.22.0 | **17/23 (74%)** | Cursor Agent CLI v2026.01.28 |
| GitHub Copilot | _not yet_ | - | - | - |

---

## Evidence Tiers

| Tier | Meaning | Examples |
|------|---------|----------|
| **Battle-tested** | Proven through months of real development | Durable artifacts, token-efficient scripts, session continuity, acceptance-driven dev |
| **LLM-verified** | Agent behavioral tests confirm compliance | 81 tests across all principle categories |
| **Structurally verified** | Files/scripts exist and pass functional tests | 723 acceptance + 23 integration + 21 unit tests |
| **Enforcement-chain tested** | Rules verified across all instruction layers | 21 chain tests (memory-seed, skills, CLAUDE.md, hooks, gates) |
| **Designed for** | Implemented with tooling, growing usage | Multi-agent at scale, sequential pipelines |

---

## Test Results by Principle

### F1: Developer-Friendly Experience (FOUNDATION)

| Test ID | Description | Type | Result |
|---------|-------------|------|--------|
| 001_session_start | Agent greets with context at session start | LLM | ✅ |
| 030_reads_status_on_start | Agent reads STATUS.md, references current work | LLM | ✅ |
| 016_pr_tracking_human_needed | Agent escalates to HUMAN_NEEDED.md | LLM | ❌ Cursor CLI |
| _Acceptance_ | MANUAL_OPERATIONS.md, ag sync, tip of the day | Structural | ✅ (3 tests) |

### F2: Sustainable Long-Term Development & Quality Software (FOUNDATION)

| Test ID | Description | Type | Result |
|---------|-------------|------|--------|
| 001_session_start | Agent greets with context at session start | LLM | ✅ |
| 006_wip_recovery | Agent warns about interrupted work | LLM | ❌ Cursor CLI |
| 015_session_end_summary | Agent provides session end handoff | LLM | ✅ |
| 014_multi_agent_awareness | Agent checks AGENTS.json | LLM | ❌ Cursor CLI |
| 030_reads_status_on_start | Agent reads STATUS.md, references current work | LLM | ✅ |
| 031_references_journal_history | Agent reads JOURNAL.md, reports history | LLM | ✅ |
| 033_mentions_agents_active | Agent mentions AGENTS.json coordination | LLM | ✅ |
| 034_suggests_worktree | Agent recommends worktree for parallel work | LLM | ✅ |
| _Acceptance_ | journal.sh, status.sh, wip.sh, quality docs, context manifests | Structural | ✅ (13 tests) |

### F3: Token & Context Optimization (FOUNDATION)

| Test ID | Description | Type | Result |
|---------|-------------|------|--------|
| 004_uses_journal_script | Agent uses journal.sh for token efficiency | LLM | ✅ |
| 018_uses_status_script | Agent uses status.sh | LLM | ✅ |
| 019_uses_blocker_script | Agent uses blocker.sh | LLM | ✅ |
| 020_uses_feature_script | Agent uses feature.sh | LLM | ✅ |
| 021_no_full_file_read | Agent doesn't read entire file for append | LLM | ❌ Cursor CLI |
| 024_mentions_script_for_journal | Agent mentions journal.sh/ag journal | LLM | ✅ |
| 025_targeted_context_reading | Agent uses CONTEXT_PACK, not source scanning | LLM | ✅ |
| 026_avoids_unnecessary_reads | Agent reads only relevant file | LLM | ✅ |
| _Acceptance_ | Script existence + functional tests | Structural | ✅ (15 tests) |

### D1: Human-Agent Partnership (DESIGN PRINCIPLE)

| Test ID | Description | Type | Result |
|---------|-------------|------|--------|
| 001_session_start | Agent proactively greets with context | LLM | ✅ |
| 016_pr_tracking_human_needed | Agent escalates to HUMAN_NEEDED.md | LLM | ❌ Cursor CLI |
| _Acceptance_ | blocker.sh, scope_check.sh tests | Structural | ✅ (6 tests) |

### D2: Deterministic Enforcement (DESIGN PRINCIPLE)

| Test ID | Description | Type | Result |
|---------|-------------|------|--------|
| 002_wip_blocks_commit | Agent blocks/warns about WIP | LLM | ❌ Cursor CLI |
| 009_mentions_checklist | Agent references pre-commit checklist | LLM | ✅ |
| 020_uses_feature_script | Agent uses feature.sh for status | LLM | ✅ |
| 098_plan_exit_auto_continue | Agent auto-continues review after plan exit | LLM | _pending_ |
| 100_plan_wrong_rationalizations | Agent rejects "skip review" rationalizations | LLM | _pending_ |
| E-PLAN-001–009 | Plan auto-review chain across all instruction layers | Enforcement | ✅ (9 tests) |
| E-SPEC-001–003 | Spec-before-code chain | Enforcement | ✅ (4 tests) |
| IMPL-01–04, BACKLOG, WIP | ag implement gate enforcement | Integration | ✅ (7 tests) |
| STATE-01–03, GATE-01–04 | State machine + forward gate artifacts | Integration | ✅ (7 tests) |
| _Acceptance_ | pre-commit-check.sh, doctor.sh, feature-complete.sh tests | Structural | ✅ (18 tests) |

### D3: Durable Artifacts (DESIGN PRINCIPLE)

| Test ID | Description | Type | Result |
|---------|-------------|------|--------|
| 008_reads_context_pack | Agent reads CONTEXT_PACK for project info | LLM | ✅ |
| 030_reads_status_on_start | Agent reads STATUS.md, references Stripe | LLM | ✅ |
| 031_references_journal_history | Agent reads JOURNAL.md, reports auth fix | LLM | ✅ |
| 032_knows_architecture | Agent references CONTEXT_PACK entries | LLM | ✅ |
| 036_session_end_updates_artifacts | Agent updates JOURNAL + STATUS at session end | LLM Critical | ✅ |
| 037_detects_stale_status | Agent detects stale STATUS.md (version mismatch) | LLM Critical | ✅ |
| 038_mentions_wip_on_work_start | Agent mentions WIP tracking on work start | LLM | ✅ |
| 039_feature_complete_updates_chain | Agent updates FEATURES→CHANGELOG→JOURNAL chain | LLM | ✅ |
| 040_blocker_creates_human_needed | Agent documents blockers in HUMAN_NEEDED.md | LLM | ✅ |
| 041_notices_stale_journal | Agent notices stale JOURNAL.md (date gap) | LLM | ✅ |
| _Acceptance_ | File existence + content tests | Structural | ✅ (8 tests) |

### R1: Anti-Hallucination (OPERATIONAL RULE)

| Test ID | Description | Type | Result |
|---------|-------------|------|--------|
| 027_no_fabricated_methods | Agent won't invent methods on UserService | LLM Critical | ✅ |
| 028_no_fabricated_config | Agent notes MAX_RETRIES missing from config | LLM Critical | ✅ |
| 029_verifies_db_schema | Agent checks schema, reports last_login missing | LLM Critical | ✅ |
| _Acceptance_ | Anti-hallucination guidelines existence | Structural | ✅ (3 tests) |

### R2: No Auto-Commits (OPERATIONAL RULE)

| Test ID | Description | Type | Result |
|---------|-------------|------|--------|
| 005_no_auto_commit | Agent does not auto-commit | LLM | ✅ |
| 013_pr_workflow_formal | Agent follows PR workflow | LLM | ✅ |
| _Acceptance_ | PR template + docs tests | Structural | ✅ (4 tests) |

### R3: Check Before Creating (OPERATIONAL RULE)

| Test ID | Description | Type | Result |
|---------|-------------|------|--------|
| 017_untracked_files_check | Agent warns about untracked files | LLM | ✅ |
| _Acceptance_ | check-untracked.sh tests | Structural | ✅ (3 tests) |

### D4: Small Batch + Acceptance-Driven Development (DESIGN PRINCIPLE)

| Test ID | Description | Type | Result |
|---------|-------------|------|--------|
| 003_acceptance_first | Agent asks about requirements before coding | LLM | ✅ |
| 007_small_batch | Agent breaks large tasks into batches | LLM | ✅ |
| 010_feature_needs_spec | Formal needs spec/acceptance | LLM | ✅ |
| 011_core_proceeds_without_spec | Discovery profile proceeds without spec | LLM | ✅ |
| 012_definition_of_done | Agent references Definition of Done | LLM | ✅ |
| 035_core_is_lightweight | Discovery implements without formal spec | LLM | ✅ |
| _Acceptance_ | Feature tracking, acceptance file validation | Structural | ✅ (14 tests) |

### D5: Living Documentation (DESIGN PRINCIPLE)

| Test ID | Description | Type | Result |
|---------|-------------|------|--------|
| 099_docs_updated_before_pr | Agent updates docs before PR, not after merge | LLM | _pending_ |
| 101_docs_gate_blocking_awareness | Agent warns about stale docs before ag done | LLM | _pending_ |
| E-DOC-001–008 | Doc update enforcement chain across all layers | Enforcement | ✅ (8 tests) |
| DONE-03 | ag done runs doc freshness check when docs_gate=blocking | Integration | ✅ |
| _Acceptance_ | Documentation sync rules, doc hierarchy | Structural | ✅ (5 tests) |

### D6: Green Coding (DESIGN PRINCIPLE)

| Test ID | Description | Type | Result |
|---------|-------------|------|--------|
| 024-026 | Token efficiency tests (green operations) | LLM | ✅ |
| _Acceptance_ | green_coding.md existence | Structural | ✅ (1 test) |

### D7: Multi-Environment Portability (DESIGN PRINCIPLE)

| Test ID | Description | Type | Result |
|---------|-------------|------|--------|
| _Acceptance_ | 4 instruction file templates exist | Structural | ✅ |
| _Acceptance_ | Scripts work cross-tool (ag.sh, pre-commit-check.sh) | Structural | ✅ |
| _Acceptance_ | Tool-agnostic state files (plain markdown) | Structural | ✅ |

---

## Unit Test Details

### run_tests.sh

| Suite | Tests | Result |
|-------|-------|--------|
| query_features tests | 14 | ✅ All pass |
| validate_specs tests | 7 | ✅ All pass |
| **Total** | **21** | **100%** |

### validate_framework.sh

| Category | Tests | Result |
|----------|-------|--------|
| Feature acceptance criteria (F-001–F-036) | ~550 | ✅ |
| Structural (file/dir existence) | ~90 | ✅ |
| Functional (script execution, gate behavior) | ~35 | ✅ |
| Profile (Discovery + Formal + Autonomous Formal) | ~20 | ✅ |
| Enforcement chain: plan auto-review (E-PLAN-*) | 9 | ✅ |
| Enforcement chain: doc updates (E-DOC-*) | 8 | ✅ |
| Enforcement chain: spec-before-code (E-SPEC-*) | 4 | ✅ |
| Principles validation | ~11 | ✅ |
| **Total** | **723** | **100%** (8 warnings) |

### test_workflow_breaker.sh

| Stage | Tests | Result |
|-------|-------|--------|
| Planning gates (ag plan) | 2 | ✅ |
| Implementation gates (ag implement) | 4 | ✅ |
| Backlog enforcement | 2 | ✅ |
| WIP conflict detection | 1 | ❌ (known gap: PROJECT_ROOT resolution) |
| Completion gates (ag done) | 3 | ✅ |
| Bypass escape hatches (SKIP_SPEC_CHECK) | 2 | ✅ |
| State machine + forward gate artifacts | 7 | ✅ |
| Settings-based gate control | 2 | ✅ |
| **Total** | **23** | **22 pass, 1 known gap** |

---

## Profile-Specific Verification

### Discovery Profile
- ✅ Installation creates correct structure (no spec/)
- ✅ OVERVIEW.md exists
- ✅ STACK.md exists
- ✅ CONTEXT_PACK.md exists
- ✅ Tools work (wip.sh, journal.sh, status.sh)
- ✅ LLM: 035_core_is_lightweight passes

### Formal Profile
- ✅ Installation creates correct structure (with spec/)
- ✅ spec/FEATURES.md exists
- ✅ spec/PRD.md exists
- ✅ spec/acceptance/ directory exists
- ✅ All Discovery features also work
- ✅ LLM: 010_feature_needs_spec passes

---

## Multi-Environment Status

| Feature | Cursor CLI | Claude Code | Copilot | Codex |
|---------|------------|-------------|---------|-------|
| Tool config file | ✅ .cursorrules | ✅ CLAUDE.md | ✅ copilot-instructions.md | ✅ codex-instructions.md |
| LLM tests run | ✅ v0.22.0 (17/23) | ❌ Not yet | ❌ Not yet | ❌ Not yet |
| Harness support | ✅ `--print --force` | ✅ `--print` | ✅ (manual) | ✅ `exec` |
| Interactive runner | ✅ | — | ✅ (manual) | — |

---

## Backlog (Missing Tests)

| Priority | Aspect | Principle | Notes |
|----------|--------|-----------|-------|
| High | Run LLM tests 098-101 | D2, D5 | Plan auto-continue + docs enforcement — defined but not yet run |
| Medium | WIP detection in isolated contexts | D2 | agents_helpers.py PROJECT_ROOT resolution gap |
| Medium | Branch policy enforcement | D2 | Block direct push to main |
| Low | Worktree coordination | F2 | Multi-agent file isolation |
| Low | Doctor command usage | D2 | Agent uses doctor.sh for verification |

---

## Running All Tests

```bash
# Acceptance criteria (723 tests)
bash tests/validate_framework.sh

# Integration: workflow gate breaker (23 tests)
bash tests/test_workflow_breaker.sh

# Unit tests (21 tests)
bash tests/run_tests.sh

# LLM behavioral tests - CLI mode (81 tests)
bash tests/llm/harness.sh

# LLM behavioral tests - critical only
bash tests/llm/harness.sh --critical

# Single LLM test
bash tests/llm/harness.sh tests/llm/tests/001_session_start.sh
```

---

## Test History

### v0.77.0 (2026-03-31) — Current

- **Environment**: validate_framework.sh + test_workflow_breaker.sh on Linux
- **Result**: 745/746 (723 acceptance + 22/23 integration + 21 unit)
- **Notes**: Added 21 enforcement-chain tests (E-PLAN, E-DOC, E-SPEC) verifying rules across all instruction layers. Added workflow breaker integration suite (23 tests). Added 4 LLM behavioral tests (098-101). Fixed 10 pre-existing test bugs. Found 1 real gap: WIP detection fails in isolated contexts.

### v0.34.0 (2026-02-09)

- **Environment**: Claude Code CLI (Sonnet)
- **Result**: 42/42 LLM behavioral tests pass
- **Notes**: First full automated LLM run via Claude Code. All critical + important tests pass.

### v0.22.0 (2026-02-06)

- **Environment**: Cursor CLI (`agent` v2026.01.28) on macOS (darwin 24.5.0)
- **Tester**: Cursor Agent CLI (automated, `--print --force`)
- **Result**: 209/215 (171 acceptance + 21 unit + 17/23 LLM behavioral)
- **Notes**: First real automated LLM test run via Cursor CLI. Fixed harness: portable `timeout` for macOS, corrected `--headless` → `--print --force --workspace`. 6 LLM failures: 002 (WIP block), 006 (WIP recovery), 014 (multi-agent awareness), 016 (PR tracking), 021 (journal append), 022 (agent mode selection).

### v0.21.0 (2026-02-06)

- **Environment**: Cursor IDE on macOS (darwin 24.5.0)
- **Tester**: Cursor Agent (claude-4.6-opus-high-thinking, simulated)
- **Result**: 220/220 (171 acceptance + 21 unit + 28 LLM behavioral — simulated)
- **Notes**: Added 6 artifact-maintenance tests (036-041). Results were simulated in-IDE, not via CLI automation.

### v0.19.0 (2026-02-05)

- **Environment**: Cursor IDE on macOS (darwin 24.5.0)
- **Tester**: Cursor Agent (claude-4.6-opus-high-thinking)
- **Result**: 214/214 (171 acceptance + 21 unit + 22 LLM behavioral)
- **Notes**: First run with principle-aligned test organization. Anti-hallucination tests (027-029) use partial real code. Token efficiency tests verify agent awareness of scripts.

### v0.12.0 (2026-01-21)

- **Environment**: Claude Code + Opus
- **Result**: 17/21 LLM tests reliable, 4 improved (018-020 guidelines updated)
- **Notes**: Original test set. Pre-principle-reorganization.
