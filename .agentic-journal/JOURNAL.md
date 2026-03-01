# JOURNAL

<!-- format: journal-v0.1.0 -->

**Purpose**: Capture session-by-session progress so both humans and agents can resume work effortlessly.

---

## Session Log (most recent last)

### Session: 2026-01-15 (Agent 2 - Dogfooding Setup)

**Focus**: Framework dogfooding - making the framework use its own session protocols

**Accomplished**:
- Identified that framework repo was missing session files (STATUS.md, CONTEXT_PACK.md, JOURNAL.md, HUMAN_NEEDED.md)
- Created all four files for framework development
- Registered as Agent 2 in AGENTS_ACTIVE.md

**Context**:
- Agent 1 is also active, working on PR workflow implementation
- Framework version: 0.11.2

**Next steps**:
- Update CLAUDE.md to include session start protocol
- Verify session start checklist now works
- Coordinate with Agent 1 on pending changes

---

<!-- Agents: Append new session entries above this line -->

### Session: 2026-01-26 17:03 - Context Optimization Implementation

**Accomplished**:
- - Analyzed framework reliability (16/21 LLM tests pass)\n- Created 9 context manifests for role-based loading\n- Built context-for-role.sh tool\n- Updated orchestrator with minimal context instructions\n- Started guidelines modularization (anti-hallucination.md)\n- PR #10 created

**Next steps**:
- - Merge PR #10\n- Test in real orchestrator scenarios\n- Continue guideline modularization\n- JSON backend for status.sh

**Blockers**: None


### Session: 2026-01-26 17:17 - Expanded Task-Type Detection

**Accomplished**:
- - Added 15 new specialized agent manifests\n- Domain: compliance, domain, design, ux\n- Technical: refactor, perf, security, api-design, db, migration\n- Deployment: devops, appstore, aws, azure, gcp\n- Updated auto_orchestration.md with trigger patterns\n- Total: 24 agent types now supported

**Next steps**:
- - Test agents in real scenarios\n- Add more deployment targets if needed

**Blockers**: None


### Session: 2026-01-26 23:28 - Context Optimization Complete

**Accomplished**:
- - Created multi-agent.md guideline module\n- Consolidated CLAUDE.md (512 → 113 lines, 78% reduction)\n- Updated guidelines README migration status\n- All guideline modules now extracted: anti-hallucination, token-efficiency, small-batch, wip-tracking, multi-agent

**Next steps**:
- - Update CONTRIBUTIONS.md with v0.11.0 work\n- Consider updating agent_operating_guidelines.md to reference modular guidelines

**Blockers**: None


### Session: 2026-01-26 23:32 - Dogfooding fix

**Accomplished**:
- Updated CONTEXT_PACK.md to reflect current architecture:\n- Added modular guidelines section\n- Added token-efficient tools with JSON backend\n- Added state files section\n- Framework now properly dogfoods itself

**Next steps**:
- Verify all dogfooding practices are in place

**Blockers**: None


### Session: 2026-01-27 00:08 - Framework ADRs + CLAUDE.md Fix

**Accomplished**:
- - Reverted CLAUDE.md consolidation (was a mistake - removed essential bootstrap content)\n- Created docs/adr/ for framework architecture decisions\n- Created ADR-001: CLAUDE.md Must Be Self-Contained\n- Added step 9 to FRAMEWORK_QUICK_START.md: sync CLAUDE.md when guidelines change\n- Updated CONTEXT_PACK.md to reference ADRs

**Next steps**:
- When updating guidelines/principles, remember to sync CLAUDE.md

**Blockers**: None


### Session: 2026-01-27 20:16 - Context Optimization + Dogfooding

**Accomplished**:
- - Added 15 subagent definitions matching context manifests\n- Identified dogfooding gap: root CLAUDE.md was 102 lines vs framework's 511\n- Merged full framework CLAUDE.md with framework-specific sections\n- Established HOW vs WHAT separation pattern

**Next steps**:
- - Consider what's next for framework development

**Blockers**: None


### Session: 2026-01-27 20:28 - v0.12.0 Release

**Accomplished**:
- - Updated all version references (14 files)\n- Updated CONTRIBUTIONS.md with subagents + dogfooding sections\n- Added periodic CONTRIBUTIONS.md update reminder to dev guide\n- Tested install.sh and upgrade.sh - both working\n- Created tag v0.12.0 and pushed

**Next steps**:
- - Create GitHub release with CHANGELOG excerpt

**Blockers**: None


### Session: 2026-01-30 21:21 - Session start checklist validation

**Accomplished**:
- Validated all files/tools referenced in session_start.md exist and work correctly

**Next steps**:
- Continue framework feature development

**Blockers**: None


### Session: 2026-02-01 12:44 - v0.14.0 shipped + Next planning task

**Accomplished**:
- - Shipped OVERVIEW.md as high-level context document (PR #15 merged)
- - Dynamic version badge in README
- - Rebased on main after drift detection merge

**Next steps**:
- ULTRATHINK: Spec-code traceability system
- - Problem: How to guarantee specs and implementation stay in sync?
- - Full chain: vision → features/NFRs → acceptance criteria → tests → code
- - Need: Know what's outdated/unimplemented at any time
- - Also: Detect obsolete instructions that bloat context
- - Research: What options exist for reliable mapping?
- - Question: Is this even practical?

**Blockers**: None - needs deep research/planning first


### Session: 2026-02-02 23:03 - F-0109 Spec-Code Traceability

**Accomplished**:
- Implemented drift.sh --json, coverage.py enhancements, ag trace CLI, doc-check.sh enforcement, traced_notes_app example, 18 new tests

**Next steps**:
- Push changes, bump version to 0.15.0

**Blockers**: None


### Session: 2026-02-03 18:35 - F-0114 Scope & Diff Verification

**Accomplished**:
- Implemented scope_check.sh, added diff stats to pre-commit, added 6 agent behavior principles to PRINCIPLES.md, updated WIP template with IN_SCOPE field

**Next steps**:
- Run tests, verify with validation script, commit changes

**Blockers**: None


### Session: 2026-02-04 13:05 - F-0116 Maintainability Enforcement

**Accomplished**:
- Implemented test execution gate, complexity limits, escape hatches, WIP auto-creation, frontmatter parsing, migration support

**Next steps**:
- Create PR, merge to main

**Blockers**: None


### Session: 2026-02-04 18:55 - Test Entry

**Accomplished**:
- Tested manifest generation

**Next steps**:
- Continue implementation

**Blockers**: None

**Metadata**:
- Feature: F-0116
- Files changed: 28
- Commits: e7fd59e,b62f5a0


### Session: 2026-02-05 23:13 - Principles Simplification

**Accomplished**:
- Simplified PRINCIPLES.md from 48+11 entries (1542 lines) to 11 core principles (~240 lines, 84% reduction). Updated README.md Design Principles to align. Updated validation tests. All 171 acceptance tests + all unit tests pass.

**Next steps**:
- Update traceability matrix, verification report, and value proposition docs to reflect new principle structure. Make README more honest about what works and why.

**Blockers**: None


### Session: 2026-02-06 00:03 - v0.19.0-v0.20.0 Cursor Session: Principles Simplification & Documentation Overhaul

**Accomplished**:
- Principles simplified 48→11 (8 NON-NEGOTIABLE + 3 RECOMMENDED). Added KISS meta-principle. Test results consolidated into single VERIFICATION_REPORT.md. Traceability matrix rewritten for 11 principles. Context7 docs updated from CLI to MCP server. README.md added 'Why This Framework?' section. Review/plan files consolidated into docs/reviews/ and docs/plans/. Framework-dev guides moved to repo root. 12 new LLM tests added (024-035). All 22 LLM tests passing. v0.19.0 and v0.20.0 released.

**Next steps**:
- Run validation tests for v0.20.0. Re-run LLM tests. Test Context7 MCP setup. Consider progressive disclosure implementation.

**Blockers**: None


### Session: 2026-02-06 12:35 - v0.22.0: Instruction slimdown

**Accomplished**:
- Rewrote all instruction templates ~70% smaller (277→79, 268→69/71). Fixed LLM test bugs (002 mkdir path, 003 pattern matching). Updated L-0002 lesson with subagent context multiplier insight. All 171 validation tests passing.

**Next steps**:
- Run LLM behavioral tests to confirm compliance improvement. Consider progressive disclosure implementation.

**Blockers**: None


### Session: 2026-02-06 20:07 - v0.22.0 LLM behavioral test results

**Accomplished**:
- Ran critical LLM tests (harness.sh --critical). Results: 2 PASSED (003_acceptance_first, 005_no_auto_commit), 2 FAILED (001_session_start, 002_wip_blocks_commit), 1 RATE_LIMITED (010_feature_needs_spec). Test 003 fix confirmed working - was failing before, now passes. Test 001 (session start) still fails - agent doesn't greet with context on bare 'hi'. Test 002 partial - agent detects WIP but doesn't use blocking language pattern.

**Next steps**:
- Investigate 001 session start failure (may need stronger instruction positioning or test adjustment). Re-run 010 when rate limit resets. Consider whether 002 verification pattern is too strict.

**Blockers**: Rate limited on test 010 (resets Feb 8 11am)


### Session: 2026-02-07 21:14 - Instruction Architecture Design + Framework Cleanup Plan

**Accomplished**:
- Created docs/INSTRUCTION_ARCHITECTURE.md — single authoritative design document synthesizing ChatGPT 5.2 and Claude Opus 4.6 research on instruction files, subagent context, and three-layer architecture. Created L-0004 lesson (plan-review process). Updated L-0003 with resolution reference. Fixed false subagent inheritance claim in FRAMEWORK_DEVELOPMENT.md line 94. Added design references to FRAMEWORK_QUICK_START.md and PRINCIPLES.md. Updated CONTRIBUTIONS.md, CHANGELOG.md, bumped VERSION to 0.22.1. Committed all as 'docs: instruction architecture design document + research references'. Then ran exhaustive 3-round plan-review loop for framework cleanup plan (v1→v2→v3). Round 1 caught 5 CRITICAL + 10 IMPORTANT issues. Round 2 caught 3 IMPORTANT + 3 SUGGESTION. Round 3 caught 4 SUGGESTION only — plan APPROVED.

**Next steps**:
- Implement framework cleanup plan v3 (7 batches): Batch 1 core-rules.md + always-inject, Batch 2 slim templates, Batch 3 slim root files, Batch 4 ag.sh fixes, Batch 5a/5b guidelines refactor, Batch 6 checklists + legacy cleanup

**Blockers**: None — plan approved and ready for implementation


### Session: 2026-02-07 21:35 - Framework Cleanup Implementation Complete

**Accomplished**:
- All 7 batches of the instruction architecture cleanup plan implemented: Batch 1 (core-rules.md + always-inject), Batch 2 (slim templates 79→38-40 lines), Batch 3 (slim root files 92→51-53 lines, codex 286→50), Batch 4 (ag.sh playbook refs + cmd_done blocking), Batch 5a (guidelines 434→115 lines), Batch 5b (cross-reference fixes), Batch 6 (checklist cross-refs + 6 legacy tools archived). All 4 design gaps from INSTRUCTION_ARCHITECTURE.md resolved. 172 tests pass, 0 failures.

**Next steps**:
- Review changes and commit

**Blockers**: None


### Session: 2026-02-09 19:33 - LLM Test Suite v0.23.0

**Accomplished**:
- Fixed 3 test bugs (006/014 mkdir, 022 regex), fixed harness rate-limit detection, ran full suite 42/42 pass (100% Sonnet), registered F-0123 + approved plan, tagged v0.23.0

**Next steps**:
- Push v0.23.0 release, implement F-0123

**Blockers**: None


### Session: 2026-02-10 00:08 - Structural Enforcement: JOURNAL/STATUS Staleness

**Accomplished**:
- Implemented commit-relative staleness checks in pre-commit-check.sh (BLOCKING) and UserPromptSubmit.sh (proactive reminder). Added SKIP_STALENESS escape hatch. Added contribution logging rule to CLAUDE.md and .cursorrules. Updated CONTRIBUTIONS.md.

**Next steps**:
- Review with user, commit changes

**Blockers**: None


### Session: 2026-02-10 00:29 - F-0123 Intelligent Onboarding Implementation

**Accomplished**:
- Implemented all 10 steps: brownfield detection in scaffold.sh, discover.sh orchestrator, discover.py analysis engine (stack/feature/architecture detection), render_proposals.py, init_playbook Step 0.5, ag approve-onboarding command, doctor.py proposal awareness, 31 pytest tests (all pass), 12 validation checks (184/184 pass), .gitignore + feature status

**Next steps**:
- Review changes, commit, update F-0123 status to shipped, test in scratch project

**Blockers**: None


### Session: 2026-02-10 10:50 - Memory Seed for Init

**Accomplished**:
- Created memory-seed.md (52 lines), updated init_playbook.md (Claude/Codex/Windsurf sections), added memory seed pointer to CLAUDE.md template. 184/184 validation checks pass.

**Next steps**:
- Commit and PR. Follow-up: add windsurf to setup-agent.sh, Codex AGENTS.md as primary.

**Blockers**: None


### Session: 2026-02-10 11:14 - v0.24.0 Release

**Accomplished**:
- Tagged v0.24.0: F-0123 intelligent onboarding for existing projects, agent memory seeding during init (Claude/Codex/Windsurf), Windsurf support in init playbook.

**Next steps**:
- PR for feature branch, merge to main, tag v0.24.0.

**Blockers**: None


### Session: 2026-02-10 14:08 - Eliminate status.json

**Accomplished**:
- Refactored status.sh to update STATUS.md directly (removed ~90 lines of JSON intermediary), deleted .agentic/state/ directory, added upgrade.sh cleanup, updated CONTEXT_PACK.md and INSTRUCTION_ARCHITECTURE.md. All 184 validation tests pass.

**Next steps**:
- Next task from backlog

**Blockers**: None


### Session: 2026-02-10 19:30 - Deep Feature Discovery

**Accomplished**:
- Implemented sub-project detection, serverless function detection, UI component grouping, feature clustering, API spec detection in discover.py. Updated render_proposals.py for richer output with clusters. Enhanced init_playbook.md Step 0.5b for feature synthesis. 59 tests all passing. Fixed user-facing 'Core+PM' jargon.

**Next steps**:
- Verify against real multi-sub-project repo. Consider follow-up for Django/Rails/Spring patterns.

**Blockers**: None


### Session: 2026-02-11 00:26 - Domain Categories + ag specs (v0.25.0)

**Accomplished**:
- Implemented detect_infra_patterns() and detect_domains() in discover.py, domain-tagged FEATURES.md in render_proposals.py, ag specs command with plan-resume support, size-aware routing and greenfield domains in init_playbook, brownfield plan detection in session_start, brownfield spec pipeline in auto_orchestration. 75 pytest tests pass, 184 validation checks pass. 3 new LLM tests (044-046). Bumped to v0.25.0.

**Next steps**:
- Next task from backlog

**Blockers**: None


### Session: 2026-02-11 12:24 - Enforcement Gaps

**Accomplished**:
- Implemented all 20 gap closures: 4 structural gates (ag done blocking, one-feature-at-a-time, FEATURES.md staleness in pre-commit + ag commit), behavioral reinforcement (memory-seed pitfalls, cmd_work advisory), doc honesty (PRINCIPLES enforcement tiers, auto_orchestration gate table, ROI qualification), 3 new LLM tests (047-049). 184/184 validation, 75/75 pytest.

**Next steps**:
- Commit enforcement gaps, run LLM tests with full 48-test suite

**Blockers**: None


### Session: 2026-02-11 22:10 - Memory-seed infrastructure

**Accomplished**:
- Created memory-check.sh (advisory integrity check), wired into ag start, documented defense-in-depth layer in INSTRUCTION_ARCHITECTURE.md, added memory seed maintenance to FRAMEWORK_DEVELOPMENT.md, updated CONTEXT_PACK.md with instruction architecture section, fixed stale counters

**Next steps**:
- Rewrite memory-seed.md in imperative format (trigger→action style), explore intent-based trigger matching beyond exact keywords

**Blockers**: None


### Session: 2026-02-11 22:18 - Intent-based triggers + imperative memory-seed

**Accomplished**:
- Rewrote memory-seed.md as imperative action rules, updated all 7 trigger tables to intent-based matching with synonyms, added memory-check instruction to CLAUDE.md template+root

**Next steps**:
- Dogfood by re-seeding memory with new content, consider LLM test for memory-seeded command execution

**Blockers**: None


### Session: 2026-02-12 00:17 - ag sync + discoverability + tip of the day

**Accomplished**:
- Implemented ag sync (5-phase drift detection), discoverability reminders in ag start (dim workflow line + yellow sync probe), tip of the day (10 random tips per session), updated CONTRIBUTIONS.md

**Next steps**:
- Dogfood re-seed, LLM test for sync, real-world project validation

**Blockers**: None


### Session: 2026-02-12 09:35 - F-0128 Specs-Before-Code Enforcement

**Accomplished**:
- Root cause analysis (7 findings), 7 fixes: ag work hard block in Core+PM, ag implement plan-review gate, doctor check blocking, pre-commit workflow bypass, trigger table one-liner, memory-seed imperative, auto_orchestration pre-condition. Plan-review loop: 3 iterations (2 REVISION_NEEDED, 1 APPROVED). LLM test 050 added.

**Next steps**:
- Dogfood: test the enforcement in next feature implementation

**Blockers**: None


### Session: 2026-02-12 13:28 - F-0129 Git Hook Enforcement

**Why**: Pre-commit hooks existed since v0.20 but git never actually called them — `scaffold.sh` copied hook files into `.git/hooks/` which got overwritten or ignored. Every quality gate (WIP locks, staleness checks, branch policy) was theatre. The fix: use `git config core.hooksPath .agentic/hooks` so git reads hooks from our tracked directory.

**Accomplished**:
- Pre-commit dispatcher with CI detection and STACK.md config routing (`pre_commit_hook: fast|full|no`)
- `core.hooksPath` wiring in scaffold.sh and upgrade.sh
- `ag hooks` command (install/status/disable), sync phase 6, start warning
- All 184 framework tests pass

**Next steps**:
- Prove the hooks actually work with mutation tests

**Blockers**: None


### Session: 2026-02-12 15:21 - Infrastructure validation mutation tests

**Why**: We shipped three enforcement layers (git hooks, CLAUDE.md triggers, memory seed) but had no proof they actually work — or that things break without them. Mutation testing answers: "if I remove this, does enforcement disappear?" This is especially important for git hooks where silent bypass means zero quality gates.

**Accomplished**:
- 8 structural positive tests (S01-S08): hooks configured, WIP blocks, staleness blocks, branch policy, defense-in-depth
- 3 mutation tests (M01-M03): removing core.hooksPath / hook file / setting `no` all silently bypass enforcement
- S06 "killer test": simulates LLM ignoring CLAUDE.md → hook still catches it (proves layered architecture)
- 6 LLM behavioral tests, 2 interactive memory tests, 2 LLM mutation tests (ready to run)
- 52 assertions all passing in 32s, $0 cost
- Date-prefixed all plan files, updated init_playbook for F-0129

**Next steps**:
- Run LLM tests (`--with-llm`) to prove framework changes agent behavior vs bare baseline
- Real-world project validation (non-framework)

**Blockers**: None


### Session: 2026-02-14 09:46 - Principle restructuring

**Why**: Two foundational motivations (developer UX, code quality) were never given principle status despite being the reasons the framework exists

**Accomplished**:
- Restructured 12 principles into 3 tiers: 3 FOUNDATION (P1 Developer-Friendly Experience NEW, P2 Sustainable+Quality MERGED, P3 Context Efficiency PROMOTED) + 6 NON-NEGOTIABLE (P4-P9) + 3 RECOMMENDED (P10-P12). Updated 9 files: PRINCIPLES.md, HOW_IT_WORKS.md, README.md, .agentic/README.md, FRAMEWORK_QUICK_START.md, INSTRUCTION_ARCHITECTURE.md, TRACEABILITY_MATRIX.md, VERIFICATION_REPORT.md, implementation-agent.yaml. Promoted programming_standards.md to REQUIRED. All 184 validation tests pass.

**Next steps**:
- Create feature branch and PR for review

**Blockers**: None


### Session: 2026-02-14 14:19 - Principles DAG Hierarchy

**Accomplished**:
- Restructured 12→13 principles into derivation DAG (F1-F3/D1-D7/R1-R3) with 22 edges, added D7 Multi-Env Portability. Fixed doc drift: stale versions (0.19.0→0.25.7), broken example links, stale line counts across 5 docs.

**Next steps**:
- Commit and PR for review

**Blockers**: None


### Session: 2026-02-14 14:20 - Doc Drift Fixes

**Accomplished**:
- Fixed stale versions (0.19.0→0.25.7), line counts, broken example links, stale P2 reference across 5 docs

**Next steps**:
- PR ready for review

**Blockers**: None


### Session: 2026-02-14 14:28 - Quick Start cleanup

**Accomplished**:
- Updated FRAMEWORK_QUICK_START.md heading and table to use F/D/R principle IDs, removed old Non-Negotiable tier label

**Next steps**:
- All 11 review items now resolved

**Blockers**: None


### Session: 2026-02-15 00:13 - F-0130 Rough Specs & Structural Nudging

**Accomplished**:
- Removed Phase from STATUS.template.md and all refs. Added Core nudges (pre-commit checklist, ag work tip, WIP Success Criteria). Added Core+PM surfacing (ag done [Discovered] count, sync.sh acceptance check). Updated PRINCIPLES.md, spec_evolution.md, FRAMEWORK_QUICK_START.md. Created F-0130 spec + acceptance + 10 validation tests (194/194 pass).

**Next steps**:
- Commit and PR

**Blockers**: None


### Session: 2026-02-15 21:50 - Profile Rename: Discovery/Formal

**Why**: Profile names Core/Core+PM imply modular system that doesn't exist. Discovery/Formal better reflects the actual distinction: informal vs formal specs.

**Accomplished**:
- Completed all 5 batches of profile rename across ~70 files. Core→Discovery, Core+PM→Formal. Added backwards-compatible normalization in all profile-reading functions. Fixed pre-existing test_phase_detect.py WIP path bug (.agentic/ → .agentic-state/). All tests passing: 194/194 validate_framework, 6/6 phase_detect, 20/21 ag gateway (1 pre-existing failure).

**Next steps**:
- Commit changes on feature branch and create PR.

**Blockers**: None


### Session: 2026-02-16 15:24 - Profile Rename Final Cleanup

**Why**: Old profile names were dead code — keeping normalization created false impression they were still supported

**Accomplished**:
- Removed all backward compat normalization (core/core+product/core+pm no longer accepted). Deleted enable-product-management.sh. Updated ~37 files: tools, tests, specs. Added legacy-fix note to agent_operating_guidelines.md. PR #30 created, review fixes applied.

**Next steps**:
- Merge PR #30. Follow-up: rename stale 'Core Profile' headings in checklists/wip-tracking.md

**Blockers**: None


### Session: 2026-02-17 10:07 - Settings-Over-Profiles

**Why**: Profiles are now presets that set bundles of settings. All framework logic checks individual settings via get_setting(). Users can override any setting independently.

**Accomplished**:
- Implemented full settings architecture: Phase 1 (lib/settings.sh, lib/settings.py, presets/profiles.conf, presets/constraints.conf, ag set command, STACK.template ## Settings section), Phase 2a (ag.sh 9 profile→setting conversions, sync.sh, pre-commit-check.sh, session-start.sh, enable-formal.sh), Phase 2b (phase_detect.py, doctor.py, verify.py, render_proposals.py, continue_here.py, discover.py), Phase 2c (upgrade.sh adds lib/presets to DIRS_TO_REPLACE + Settings migration, discover.sh settings-aware, scaffold.sh writes ## Settings), Phase 3 (gates tables in guidelines/auto_orchestration, CLAUDE.md template, 15 new tests in validate_framework.sh including 3 functional)

**Next steps**:
- Show changes to human for commit

**Blockers**: None


### Session: 2026-02-17 18:35 - Settings-Over-Profiles

**Why**: Profiles were all-or-nothing; settings allow individual overrides

**Accomplished**:
- Implemented full settings architecture: shared libs (settings.sh/py), profiles.conf presets, constraints.conf, ag set command. Converted all 18 files from profile branching to get_setting(). Added 15 framework tests, 12 LLM behavioral tests.

**Next steps**:
- Create PR for review

**Blockers**: None


### Session: 2026-02-17 20:56 - Review fixes

**Accomplished**:
- Fixed all review findings: W1 enum validation, W2 gate enforcement docs, W3 scaffold.sh dead code, W4 STACK.md formatting, S1 whitespace trim parity, S2 Python caching, S3 phase_detect docstring, S4 additional tests, S5 render_proposals import

**Next steps**:
- Merge PR

**Blockers**: None


### Session: 2026-02-17 21:45 - Settings docs & version bump

**Accomplished**:
- Moved settings docs to DEVELOPER_GUIDE.md, added I-0004/I-0005, updated READMEs, version 0.27.0

**Next steps**:
- PR #31 merge review

**Blockers**: None


### Session: 2026-02-18 00:19 - F-0132 Spec-First Gate

**Accomplished**:
- Added programmatic gates to ag plan (FEATURES.md check) and ag implement (FEATURES.md + acceptance file check). SKIP_SPEC_CHECK=1 escape hatch. 3 new tests. Fixed I-0002.

**Next steps**:
- Next pending tasks

**Blockers**: None


### Session: 2026-02-18 00:25 - F-0133 Durable Plan Artifacts

**Accomplished**:
- Added ag plan --save command, plan-save rule to CLAUDE.md template and agent guidelines. Fixes I-0003.

**Next steps**:
- Next pending tasks (#6, #7, #11)

### Session: 2026-02-18 00:28 - Skill routing + review-after-PR

**Accomplished**:
- Added routing hints: framework roles use /slash commands not Task tool. PR rule now offers /review after creation.

**Next steps**:
- DEVELOPER_GUIDE rewrite, centralized TODO tracking

**Blockers**: None


### Session: 2026-02-18 00:44 - Session: settings-over-profiles completion + task cleanup

**Why**: Consolidating session progress before plan-review loop

**Accomplished**:
- Merged PR #31 (F-0131 settings-over-profiles, v0.27.0 tagged). Fixed all review findings (W1-W4, S1-S5). Shipped F-0132 (spec-first gate, PR #32) fixing I-0002. Shipped F-0133 (durable plans + 16 archived plans, PR #33) fixing I-0003. Shipped skill routing hints + review-after-PR (PR #34). Moved settings docs to DEVELOPER_GUIDE.md, filed I-0004/I-0005. Updated CONTRIBUTIONS.md, READMEs, VERSION.

**Next steps**:
- Plan-review loop for #11 (DEVELOPER_GUIDE rewrite) and #12 (centralized TODO tracking)

**Blockers**: None


### Session: 2026-02-18 00:50 - CONTRIBUTIONS & CHANGELOG catchup

**Why**: CONTRIBUTIONS was 5 versions behind — capturing all user contributions before they get lost to context compression

**Accomplished**:
- Updated CONTRIBUTIONS.md with v0.25.8-v0.27.0 entries (rough specs, profile rename, settings-over-profiles, spec-first gate, durable plans, skill routing). Updated CHANGELOG.md with v0.26.0 and v0.27.0 entries. Updated architecture decisions list. Created F-0134 feature entry and acceptance criteria for DEVELOPER_GUIDE rewrite.

**Next steps**:
- Plan-review loop for F-0134 DEVELOPER_GUIDE rewrite, then Task #12 centralized TODO tracking

**Blockers**: None


### Session: 2026-02-18 10:18 - F-0134 DEVELOPER_GUIDE rewrite

**Why**: Guide was framing users as script operators; now chat-first with scripts as agent tooling

**Accomplished**:
- Chat-first reframing of all 10 sections, stale URLs/version/NFR fixed, F-0132/F-0133 shipped in FEATURES.md, summary table corrected

**Next steps**:
- Commit and PR, then plan-review-loop CLAUDE.md trigger (task #7), NFR.md spec role (task #11)

**Blockers**: None


### Session: 2026-02-18 13:26 - F-0134 review fixes

**Accomplished**:
- Fixed CONTRIBUTIONS.md duplicate, F-0134 marked shipped, summary table updated

**Next steps**:
- Force-push PR, remaining tasks #7 #11

**Blockers**: None


### Session: 2026-02-18 13:29 - F-0135 memory-seed feature

**Accomplished**:
- Created F-0135 feature entry and acceptance criteria for memory-seed defense-in-depth layer. Retroactive tracking — mechanism shipped in v0.25.3. 3 'should have' criteria identified: 2 LLM tests + DEVELOPER_GUIDE mention.

**Next steps**:
- Commit, push to PR #35

**Blockers**: None


### Session: 2026-02-18 14:03 - NFR content validation

**Why**: NFR.md fields were theater - nothing validated content. Now doctor.py validates categories, status enums, test file paths, and placeholder detection.

**Accomplished**:
- Implemented validate_nfr_content() in doctor.py, nfr.sh script, framework spec/NFR.md with 2 real NFRs, 15 pytest tests, schema tech debt note, DEVELOPER_GUIDE updates

**Next steps**:
- Show changes to human, commit, create PR

**Blockers**: None


### Session: 2026-02-18 18:41 - NFR review fixes

**Accomplished**:
- Fixed import placement, nfr.sh error msg, pytest.skip, backtick test

**Next steps**:
- Push and merge PR #36

**Blockers**: None


### Session: 2026-02-18 18:50 - Version bump v0.27.2

**Accomplished**:
- CONTRIBUTIONS, CHANGELOG, VERSION, STACK.md, DEVELOPER_GUIDE footer updated

**Next steps**:
- Merge PR #36

**Blockers**: None


### Session: 2026-02-18 19:51 - NFR Acceptance Criteria

**Why**: Structured acceptance criteria for NFRs matching feature pattern

**Accomplished**:
- Created NFR-0001/0002 acceptance files, added validator check for missing acceptance files, 3 new tests, updated template and NFR.md entries

**Next steps**:
- PR review, merge to main

**Blockers**: None


### Session: 2026-02-18 19:57 - Pre-commit gate fix

**Why**: NFR spec changes incorrectly triggered FEATURES.md staleness gate

**Accomplished**:
- Split spec staleness gate into 3c (FEATURES.md for feature specs) and 3d (NFR.md for NFR specs) — symmetric logic

**Next steps**:
- PR review

**Blockers**: None


### Session: 2026-02-18 23:05 - Plan-mode-exit trigger

**Why**: Agents skipped durable save and review loop after native plan mode exit

**Accomplished**:
- Added trigger to all instruction files and memory-seed: after exiting plan mode, save plan durably and invoke review if enabled. S07 test updated to verify.

**Next steps**:
- Next tasks from backlog

**Blockers**: None


### Session: 2026-02-19 06:29 - F-0136 Centralized TODO Tracking

**Why**: Ideas scattered across 5 files with no designated inbox — agents dump tasks into HUMAN_NEEDED.md

**Accomplished**:
- TODO.md + todo.sh + ag todo command, routing rules in all instruction files, S07 test updated (26/26), scaffold for both profiles, STATUS.md Backlog removed, HN count bug fixed

**Next steps**:
- Mark F-0136 shipped, merge PR

**Blockers**: None


### Session: 2026-02-19 10:49 - F-0136 routing rule parity

**Why**: Routing rule was only in Claude files, not other agents — agents using codex/copilot/cursor would misroute tasks

**Accomplished**:
- Added Where-to-log routing rule to codex, copilot, cursor instruction files; documented in DEVELOPER_GUIDE.md Best Practices #7; created S09 structural test for cross-agent routing consistency

**Next steps**:
- PR #38 ready for final review

**Blockers**: None


### Session: 2026-02-19 10:52 - F-0136 routing rule in docs

**Why**: Routing rule needed in user-facing docs, not just agent instruction files

**Accomplished**:
- Added Where-to-log routing table to agent_operating_guidelines.md, MANUAL_OPERATIONS.md, START_HERE.md; expanded S09 test to cover all 9 files

**Next steps**:
- PR #38 ready

**Blockers**: None


### Session: 2026-02-19 10:59 - F-0136 shipped

**Why**: Merge complete

**Accomplished**:
- PR #38 merged, centralized TODO tracking live on main (v0.28.0)

**Next steps**:
- Pick next feature from backlog

**Blockers**: None


### Session: 2026-02-19 12:32 - F-0138 Documentation Impact Tracking

**Why**: Agents lacked systematic way to know which docs needed updating after feature completion

**Accomplished**:
- Implemented docs impact tracking: drift.sh --docs wired into ag done with docs_gate setting (off/warning/blocking), ## Documentation section added to CONTEXT_PACK.md template and framework instance, documentation-agent.md updated with concrete drift.sh-based process, docs_gate added to profiles.conf/STACK.md/auto_orchestration.md

**Next steps**:
- Review PR, run ag done F-0138

**Blockers**: None


### Session: 2026-02-19 13:01 - v0.29.0 release

**Why**: Version bump for F-0138 Documentation Impact Tracking and test planning enforcement

**Accomplished**:
- Updated VERSION→0.29.0, STACK.md, FEATURES.md, CHANGELOG, CONTRIBUTIONS with F-0138 + test framework improvements (acceptance.template.md, ## Tests in Gate 1)

**Next steps**:
- Create PR for v0.29.0

**Blockers**: None


### Session: 2026-02-19 17:48 - F-0138 PR review fixes

**Why**: Keeping PR quality high before merge

**Accomplished**:
- Fixed 3 review issues: FRAMEWORK_DEVELOPMENT.md step numbering, F-0138.md ## Tests section, ag.sh SKIP_DOCS_GATE escape hatch

**Next steps**:
- Merge PR #40

**Blockers**: None


### Session: 2026-02-19 18:59 - F-0139: Doc Lifecycle System

**Why**: F-0139 closes the gap between doc detection (F-0138) and doc writing

**Accomplished**:
- Implemented full doc lifecycle: docs.sh (context assembler), doc_types.md (8 types), ag docs command, wiring into ag done (feature_done + pr triggers) and ag sync (session staleness). Updated STACK.template.md, auto_orchestration.md, documentation-agent.md (dual-mode), STACK.md (dogfooding). 262 tests pass, 0 failures.

**Next steps**:
- Show changes to human, commit if approved, create PR

**Blockers**: None


### Session: 2026-02-20 21:01 - F-0140: Proactive WIP Creation

**Why**: Real-world token-limit crash lost 466 lines because WIP was never created — plan-mode-exit never chained to ag implement

**Accomplished**:
- Plan-mode-exit trigger chains to ag implement across all 5 instruction files, (creates WIP) annotation on Build triggers, memory-seed WIP steps, doctor.py path fix, checklists updated, S10 structural test, L07 LLM test, validate_framework.sh F-0140 section (14 checks), spec/acceptance/F-0140.md + FEATURES.md entry

**Next steps**:
- PR review, mark F-0140 shipped

**Blockers**: None


### Session: 2026-02-23 18:41 - F-0141: Explicit Settings in STACK.md

**Accomplished**:
- Rewrote STACK.template.md with explicit settings + inline docs; Updated scaffold.sh profiles.conf loop; Added smart profile cascade in ag.sh; Added pre_commit_hook validation; Updated upgrade.sh for missing settings; Dogfooding root STACK.md; Added 11 F-0141 tests + 2 functional scaffold tests; Fixed 3 pre-existing tests; All 285 tests pass

**Next steps**:
- Show changes for review, then commit

**Blockers**: None


### Session: 2026-02-23 23:45 - F-0141 PR updates

**Accomplished**:
- Bumped version to 0.32.0 across all files, added F-0141 contributions entry, created L08 LLM test for settings compliance

**Next steps**:
- Merge PR

**Blockers**: None


### Session: 2026-02-24 12:38 - Performance review fixes (F-0142)

**Accomplished**:
- Self-healing hook install in ag preamble (D2 root cause), plan auto-save from .claude/plans/ + .cursor/plans/, test co-presence advisory check in pre-commit, CONTEXT_PACK placeholder detection in sync

**Next steps**:
- Register F-0142 in FEATURES.md, write acceptance tests, PR

**Blockers**: None


### Session: 2026-02-24 14:02 - TODO audit cleanup (v0.32.2)

**Accomplished**:
- Fixed blocker.sh double-write (T-0004), cleaned HUMAN_NEEDED.md resolved items (T-0006), replaced Cursor prompt stubs (T-0008), fixed README placeholder (T-0009), logged 6 new TODOs from audit

**Next steps**:
- Remaining TODOs: T-0001,T-0002,T-0003,T-0005,T-0007,T-0010,T-0011

**Blockers**: None


### Session: 2026-02-24 14:08 - Python migration + git tags (v0.32.3)

**Accomplished**:
- Removed read_profile() wrappers from doctor.py and verify.py (T-0005). Added git tag instruction to all 4 instruction files (T-0011)

**Next steps**:
- Remaining TODOs: T-0001,T-0002,T-0003,T-0007,T-0010

**Blockers**: None


### Session: 2026-02-25 16:47 - Fix upgrade.sh gaps with DRY config

**Why**: Upgrade was missing instruction regen and state file creation; three places defined required files with drift

**Accomplished**:
- Created state-files.conf as single source of truth; upgrade.sh: added instruction regen (5c), state file creation (6b), sync check (8b), memory-seed marker, feature registry; verify.py reads config; scaffold.sh reads config; extracted AGENTS.md template; fixed pre-existing local-at-script-level bug; fixed test assertion; 285/0 validation

**Next steps**:
- Version bump, PR

**Blockers**: None


### Session: 2026-02-25 23:34 - Upgrade review fixes

**Why**: Saktris upgrade review revealed multiple issues

**Accomplished**:
- Fixed BSD sed settings bug, added profile rename + JOURNAL migration + OVERVIEW skip in upgrade.sh

**Next steps**:
- Commit and bump version

**Blockers**: None


### Session: 2026-02-26 10:57 - Settings repair

**Accomplished**:
- Added concatenated line repair, dedup, and template-format Settings creation

**Next steps**:
- Commit and PR

**Blockers**: None


### Session: 2026-02-26 23:55 - Dogfooding audit

**Why**: Audit revealed framework not fully dogfooding itself

**Accomplished**:
- Fixed version mismatch, created missing state files (AGENTS.md, OVERVIEW.md, LESSONS.md, REFERENCES.md)

**Next steps**:
- Commit and PR

**Blockers**: None


### Session: 2026-02-28 15:04 - Doc Architecture Review

**Why**: Closing enforcement gaps identified in document architecture effectiveness review

**Accomplished**:
- Implemented R1 (OVERVIEW+CONTEXT_PACK staleness in sync.sh), R3 (auto-register docs in scaffold), R9 (retired stale.sh into sync.sh), R10 (fixed broken test/review agent refs). Dropped R2 (already implemented), R5 (wrong approach), R6 (already done). Deferred R4, R7, R8.

**Next steps**:
- Commit changes, bump version

**Blockers**: None


### Session: 2026-02-28 20:36 - F-0143 Skills-Primary Architecture

**Why**: Skills become primary workflow delivery for Claude Code, backed by structural enforcement

**Accomplished**:
- Implemented all 6 phases: YAML frontmatter on 52 playbooks, hand-crafted 12 spec-compliant skills, rewrote generate-skills.sh (copy from sources + validate + assemble references), thinned CLAUDE.md template to 39 lines, updated upgrade.sh migration, added auto_orchestration.md header note, created validate_skills.sh test suite

**Next steps**:
- Commit changes, create PR, run trigger tests

**Blockers**: None


### Session: 2026-02-28 21:37 - F-0143: Skills-Primary Architecture

**Why**: Anthropic Skills spec compliance, progressive disclosure for all tools

**Accomplished**:
- Implemented all 8 phases: 12 spec-compliant skills, 52 playbook frontmatters, 27 subagent frontmatters, generator rewrite, CLAUDE.md thinned, validation scripts, coverage gap fixes

**Next steps**:
- PR review and merge, post-merge tagging

**Blockers**: None


### Session: 2026-02-28 23:47 - Post-F-0143 Doc Sync

**Why**: Stale docs still referenced old auto-generated skills approach after F-0143 shipped

**Accomplished**:
- Updated 12 files: INSTRUCTION_ARCHITECTURE Skills layer, CHANGELOG v0.33-v0.34, DEVELOPER_GUIDE generate-skills docs, CONTRIBUTIONS F-0143 section, FEATURES F-0098 shipped, HOW_IT_WORKS fixes, memory-seed/STACK version bumps, install.sh skills condition, ROI/VALUE_PROP frontmatter benefits, skills regenerated

**Next steps**:
- PR review and merge

**Blockers**: None


### Session: 2026-03-01 00:30 - F-0143 LLM Tests

**Why**: Skills deliver workflow instructions — need LLM tests proving behavioral compliance

**Accomplished**:
- Added 3 skill behavioral tests (066-068): implement, bugfix, commit workflows

**Next steps**:
- Push to PR #52, merge

**Blockers**: None



### Session: 2026-03-01 11:31 - F-0144 Frontmatter Coverage

**Why**: Systematic frontmatter enables progressive disclosure on all agent-facing files, not just playbooks

**Accomplished**:
- Added YAML frontmatter to 71 remaining .agentic/ files (168/212 total). Created add-remaining-frontmatter.sh with --batch and --dry-run support. Updated ROI.md, FRAMEWORK_VALUE_PROPOSITION.md, INSTRUCTION_ARCHITECTURE.md counts. Added 8-check coverage validation to validate_framework.sh.

**Next steps**:
- Create PR, merge to main

**Blockers**: None


### Session: 2026-03-01 11:53 - Frontmatter context research

**Accomplished**:
- Research doc confirming .agentic/ frontmatter is inert (0 tokens). Added context cost note to INSTRUCTION_ARCHITECTURE.md.

**Next steps**:
- Push branch, PR ready

**Blockers**: None

### Session: 2026-03-01 12:17 - PR #53 review fixes

**Accomplished**:
- Marked F-0144 shipped, updated CONTRIBUTIONS.md with F-0144 + context research + memory seed gap

**Next steps**:
- Merge PR #53

**Blockers**: None


### Session: 2026-03-01 12:36 - F-0145 + F-0146

**Why**: Two features shipped in one batch after PR #53 merge conflict recovery

**Accomplished**:
- Implemented periodic-checks.sh (state/frequency/session/orphaned-plans), generate-project-agents.sh (5 stacks: react/fastapi/django/go/godot), 5 specialization .conf files, generate-skills.sh project injection, scaffold hook, ag agents command, 17 tests (all pass), 293/0 validation

**Next steps**:
- Commit + PR

**Blockers**: None


### Session: 2026-03-01 17:56 - F-0147 Spec-Writing Workflow

**Why**: Deterministic shipped-spec protection + canonical spec-writing workflow

**Accomplished**:
- Phase 1-3 implemented: shipped spec protection gates (Checks 14-16), Check 2 grep fix, spec_writing workflow/checklist, ag spec command, Claude skill rename, Gate 4 plan-review, doc sync

**Next steps**:
- Create PR for review

**Blockers**: None


### Session: 2026-03-01 21:49 - v0.36 dogfooding sync

**Why**: Framework-dev instruction files were stale after F-0143 through F-0147 shipped

**Accomplished**:
- Marked F-0136/0139/0140/0141/0145/0146/0147 shipped. Synced versions (STACK.md, FEATURES.md, .agentic/VERSION, memory-seed). Added CHANGELOG 0.35+0.36 entries. Updated all instruction files (CONTEXT_PACK, guidelines, cursorrules, CLAUDE.md templates, copilot/codex) with Skills architecture, spec-writing trigger, doc lifecycle, --why flag. Fixed feature.sh markdown bold format bug.

**Next steps**:
- PR review and merge

**Blockers**: None

