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


### Session: 2026-03-02 00:05 - Sequential Feature IDs (v0.37.0)

**Why**: 41% of features were in overflow range with no category meaning; fixed 3 pre-existing bugs found during implementation

**Accomplished**:
- Dropped category-from-ID-range encoding; category is now metadata field on all 114 features. Updated quick_feature.sh (--category flag, octal bug fix), query_features.py and feature_stats.py (bold-key parser fix, --category filter), manifest.sh (idempotent output). SPEC_SCHEMA category field made project-defined. All tests pass (317 validation, 15 query tests).

**Next steps**:
- PR #58 review

**Blockers**: None


### Session: 2026-03-02 08:57 - F-0148 SDD Toolkit Insights

**Why**: Implements prioritized subset of SDD toolkit analysis recommendations

**Accomplished**:
- Implemented 4 groups: spec format evolution (Behavior section, priority tags, verify-independently), clarification taxonomy in writing-specs, execution order + [P] markers in planning/implementing, user-extension directory (.agentic-local/extensions/). Fixed report characterization errors. All 317 validation tests pass.

**Next steps**:
- PR review, merge, update FEATURES.md to shipped

**Blockers**: None


### Session: 2026-03-02 11:58 - F-0148–F-0153 Implementation

**Why**: Completing SDD toolkit insights batch 1+2

**Accomplished**:
- Implemented 6 SDD toolkit features: spec format evolution, structured clarification, checkpoint validation, user-extensions, semantic spec analysis, AC-level coverage tracking

**Next steps**:
- PR review and merge

**Blockers**: None


### Session: 2026-03-03 18:59 - Git hooks verification fix

**Why**: Dogfooding feedback from virtual-tree project revealed hooks were never verified after init

**Accomplished**:
- Implemented three defense-in-depth layers for git hooks: init verification in scaffold.sh, session-start check, pre-commit agent-side check. 8 files modified. PR #60 created. Also captured 4 dogfooding TODOs from Cursor feedback (T-0034–T-0037).

**Next steps**:
- Merge PR #60. Consider prioritizing T-0035 (unregistered shipped code detector) and T-0036 (SKIP_COMPLEXITY escalation) as next dogfooding fixes.

**Blockers**: None


### Session: 2026-03-03 22:07 - Enforcement Gap Fixes (F-0154/F-0155/F-0156)

**Why**: Dogfooding feedback from Cursor revealed three enforcement gaps

**Accomplished**:
- Implemented T-0036 (SKIP_COMPLEXITY per-file warnings), T-0035 (unregistered shipped code detector in sync.sh), T-0037 (session start spec drift surfacing). 8 new tests, 5 validation checks, 3 acceptance files. 372/0 validation, 8/8 unit tests.

**Next steps**:
- Show changes to human, create feature branch and PR

**Blockers**: None


### Session: 2026-03-05 08:39 - smoke-test

**Accomplished**:
- paths.sh migration

**Next steps**:
- verify

**Blockers**: none


### Session: 2026-03-05 08:39 - smoke-test

**Accomplished**:
- paths.sh migration

**Next steps**:
- verify

**Blockers**: none


### Session: 2026-03-05 10:18 - smoke-test

**Accomplished**:
- paths.sh migration

**Next steps**:
- verify

**Blockers**: none


### Session: 2026-03-05 12:32 - smoke-test

**Accomplished**:
- paths.sh migration

**Next steps**:
- verify

**Blockers**: none


### Session: 2026-03-05 13:06 - smoke-test

**Accomplished**:
- paths.sh migration

**Next steps**:
- verify

**Blockers**: none


### Session: 2026-03-05 19:20 - smoke-test

**Accomplished**:
- paths.sh migration

**Next steps**:
- verify

**Blockers**: none


### Session: 2026-03-05 20:50 - smoke-test

**Accomplished**:
- paths.sh migration

**Next steps**:
- verify

**Blockers**: none


### Session: 2026-03-05 21:26 - smoke-test

**Accomplished**:
- paths.sh migration

**Next steps**:
- verify

**Blockers**: none


### Session: 2026-03-05 22:18 - smoke-test

**Accomplished**:
- paths.sh migration

**Next steps**:
- verify

**Blockers**: none


### Session: 2026-03-05 22:19 - Test Entry

**Accomplished**:
- Did testing

**Next steps**:
- More tests

**Blockers**: None


### Session: 2026-03-05 22:30 - Test Entry

**Accomplished**:
- Did testing

**Next steps**:
- More tests

**Blockers**: None


### Session: 2026-03-05 22:32 - Test Entry

**Accomplished**:
- Did testing

**Next steps**:
- More tests

**Blockers**: None


### Session: 2026-03-06 15:50 - smoke-test

**Accomplished**:
- paths.sh migration

**Next steps**:
- verify

**Blockers**: none


### Session: 2026-03-06 15:51 - Test Entry

**Accomplished**:
- Did testing

**Next steps**:
- More tests

**Blockers**: None


### Session: 2026-03-06 16:23 - smoke-test

**Accomplished**:
- paths.sh migration

**Next steps**:
- verify

**Blockers**: none


### Session: 2026-03-06 16:29 - v0.41.0 Directory Restructure

**Why**: Major architectural change — 369 framework lib files replaced by single tarball

**Accomplished**:
- Completed 4-phase restructure: paths.sh abstraction, lib/ separation, project file consolidation, tarball release pipeline. Fixed review issues: pre-commit CI detection, macOS grep compat, stale docs. Updated CONTRIBUTIONS.md.

**Next steps**:
- Merge PR #62 after human review. Test upgrade path from v0.40.0.

**Blockers**: PR #62 awaiting review


### Session: 2026-03-06 16:39 - F-0157/F-0158/F-0159 Specs

**Why**: Formal spec coverage for v0.41.0 architectural changes

**Accomplished**:
- Added feature specs and acceptance criteria for directory restructure (F-0157), central path resolution (F-0158), bootstrap mechanism (F-0159). 41 total acceptance criteria.

**Next steps**:
- Merge PR #62.

**Blockers**: None


### Session: 2026-03-06 16:48 - smoke-test

**Accomplished**:
- paths.sh migration

**Next steps**:
- verify

**Blockers**: none


### Session: 2026-03-06 18:05 - v0.41.0 test fixes

**Why**: All 209 framework + 101 unit tests now pass

**Accomplished**:
- Fixed all automated tests: settings.sh profile resolution, ag.sh stale paths, drift.sh/coverage.py bugs, periodic-checks.sh state dir, test assertions updated

**Next steps**:
- Push to PR, human review

**Blockers**: None


### Session: 2026-03-06 20:52 - Autonomous Workflow Modes (F-0161–F-0163)

**Why**: Completes autonomous workflow engine: F-0160 foundation + F-0161/F-0162/F-0163 execution modes

**Accomplished**:
- Implemented verify.py (test-fix loop), task.py (per-feature implementation), crunch.py (multi-feature batch). 75 tests, 60+ validation checks, 5 LLM tests. Updated 8 docs including mermaid diagrams. Version 0.43.0.

**Next steps**:
- PR review, merge, test in scratch project

**Blockers**: None


### Session: 2026-03-06 22:20 - F-0164 Tiered Verify Loop

**Why**: Enable projects with multiple test levels (unit+e2e) to use the autonomous verify loop

**Accomplished**:
- Implemented multi-tier test execution in verify.py, 40 new tests, Playwright/Cypress parsers, tier-specific fix prompts, spec-first gate fix

**Next steps**:
- PR2: visual verification, PR3: scaffolding

**Blockers**: None


### Session: 2026-03-06 22:53 - Advisory batch limits

**What changed**:
- Implemented advisory batch-size limits on feature branches (T-0024, T-0027, v0.44.2). PR #65 created.

**Next steps**:
- Human review of PR #65

**Blockers**: None


### Session: 2026-03-06 23:38 - Auto mode fixes

**Why**: Auto modes had placeholder code and unsafe defaults

**What changed**:
- Wired up engine.py placeholders, tier-aware permissions, removed --no-verify, cleaned HUMAN_NEEDED

**Next steps**:
- Test crunch mode end-to-end

**Blockers**: None


### Session: 2026-03-07 00:39 - F-0168 Review Fixes

**Why**: Code review found 6 issues

**What changed**:
- Fixed screenshot collision bug, module-level import, spec/changelog gaps, marked F-0168 shipped

**Next steps**:
- Push PR, merge

**Blockers**: None


### Session: 2026-03-07 00:42 - F-0168 Visual Verification + E2E Scaffolding (v0.45.0)

**Why**: PR2+PR3 of tiered verify loop plan

**What changed**:
- Implemented visual verification (screenshot collection, AI review via Anthropic API), E2E scaffolding (detect Playwright/Cypress/Detox/WebdriverIO), surfaced auto modes across all agent instruction files and framework docs. 42 new tests, all 260 validation checks pass.

**Next steps**:
- Merge PR #66, tag v0.45.0. Next: T-0043 AC scheduling/parallel execution in auto modes

**Blockers**: None


### Session: 2026-03-07 01:02 - Spec Protection Docs

**Why**: Spec protection was invisible in entry points agents read first — only discovered at pre-commit block time

**What changed**:
- Filled migration 008 stub, added spec protection bullet to all 5 agent entry points (CLAUDE.md, cursorrules, copilot, codex, claude template), added callout to FRAMEWORK_QUICK_START.md, added section to agent_operating_guidelines.md

**Next steps**:
- Commit and PR

**Blockers**: None


### Session: 2026-03-07 13:48 - QA Suite (F-0169–F-0175)

**Why**: LLMs produce tests that look correct but prove nothing — framework needs formal quality assurance for the spec→AC→test chain

**What changed**:
- Implemented all 5 phases: NFR catalog+discovery, NFR enforcement in spec-writing, spec-audit.sh verification tool, change propagation pipeline, qa-tracker state machine, retrospective enforcement, and glue/docs. 260 tests pass, 0 failures. All new ag commands work: audit, nfr list/discover/coverage.

**Next steps**:
- Show changeset for human review, commit to feature branch, create PR

**Blockers**: None


### Session: 2026-03-07 17:38 - QA Suite Tests

**Why**: Tests were missing from initial QA suite commit

**What changed**:
- Added 76 validation tests for F-0169–F-0175 (336 total, 0 failures). Added 4 LLM behavioral tests. Saved plan to journal/plans/. Fixed NFR-0003 statement: context management.

**Next steps**:
- Push and update PR

**Blockers**: None


### Session: 2026-03-07 17:49 - NFR-0003 Reframe

**Why**: Pre-commit file limit is too late; the constraint belongs at decomposition time

**What changed**:
- Reframed from 'small batch commits' to 'small batch work' — enforcement at planning time, not pre-commit

**Next steps**:
- Push and update PR

**Blockers**: None


### Session: 2026-03-07 18:06 - QA Suite Gap Closure

**Why**: Plan specified these integrations but they were missed in initial implementation

**What changed**:
- Closed all 6 gaps: nfr-coverage.sh standalone tool, migration.sh auto-propagation, nfr.sh auto-propagation, status.sh QA summary, init_playbook retro cadence question, FRAMEWORK docs updated

**Next steps**:
- Push to PR

**Blockers**: None


### Session: 2026-03-07 18:14 - Plan-Aware Code Review (F-0176)

**Why**: Review skill had no plan awareness — missed the most valuable review dimension for plan-driven development

**What changed**:
- Added Step 1b plan lookup + Plan Alignment dimension to reviewing-code skill. Spec, acceptance, migration, 8 validation tests.

**Blockers**: None


### Session: 2026-03-08 — F-0177/F-0178 State Machine PR + Review Fixes (v0.47.0)

**Why**: Feature lifecycle had no formal state tracking — features jumped from planned to shipped with no enforced intermediate gates

**What changed**:
- Created PR #70 with formal 9-state feature lifecycle (state_machine.py, gates.py, ADR-001, 22 blast radius files, 65 tests)
- Code review found 4 design issues: duplicate GateResult class, dual gate registry, fragile 2000-char parser cap, gates not wired in CLI
- Fixed all: GateResult single source in gates.py, removed module-level GATE_REGISTRY, removed char cap, wired register_default_gates in main()
- Found and fixed __main__ dual-import bug: running state_machine.py as script caused gates to register on a different FeatureState enum than the one used by main(). Fix: pass state_enum explicitly to avoid circular import creating duplicate module
- Added missing release artifacts: VERSION 0.46.1→0.47.0, CHANGELOG v0.47.0 entry, HOW_IT_WORKS.md state machine section + diagram update

**Key lesson**: End-to-end CLI smoke test caught a real bug that unit tests missed — gates were never called from the CLI because register_default_gates wasn't invoked in main(). Then the fix revealed a subtler Python dual-import issue (__main__ vs module identity). Unit tests alone are insufficient for CLI tools.

**Next steps**:
- Human review of PR #70

**Blockers**: None


### Session: 2026-03-08 13:35 - Smoke Test Gate

**Why**: Unit tests verify logic but not wiring — features can pass all tests and still be broken

**What changed**:
- Added end-to-end smoke testing as required gate in feature_implementation, before_commit, and feature_complete checklists. User insight: 'how do we know it works?' revealed gates weren't wired in CLI despite 65 passing unit tests.

**Next steps**:
- Human review PR #70

**Blockers**: None

- T-0044 (post-merge dogfood workflow) queued. PR #70 closed.

**Blockers**: None

sign fixes, gate wiring bug, smoke test gates, CLAUDE.md journal format fix. Identified post-merge dogfooding gap (T-0044): framework has dogfooding as principle but no enforcement after PR merge.

**Next steps**:

### Session: 2026-03-08 15:58 - Docker Sandbox

**Why**: Enable autonomous Claude Code in isolated containers with user-configurable security

**What changed**:
- Devcontainer with iptables firewall, GH_TOKEN auth, zsh history, sandbox-setup skill with security interview (Open/Standard/Locked)

**Next steps**:
- Merge PR, add sandbox quick-start to README

**Blockers**: None


### Session: 2026-03-08 17:48 - Journal outcome-focused hints

**Why**: Agents kept writing implementation-focused journal entries because skill files had stale hints like 'Done' and 'What was done'

**What changed**:
- All 13 instruction files now prompt agents to write outcome-focused journal entries instead of listing file names

**Next steps**:
- Merge PR

**Blockers**: None


### Session: 2026-03-08 20:48 - F-0189 Doc Enforcement

**Why**: Agents routinely skip doc updates; enforcement was advisory-only

**What changed**:
- Documentation drift detection wired into feature acceptance gates — state machine blocks/warns per docs_gate setting, autonomode spawns doc-update Claude before PR, agent skills get explicit doc steps

**Next steps**:
- Merge PR #77

**Blockers**: None


### Session: 2026-03-08 19:22 - F-0190 Backlog Work Assignment

**Why**: Work assignments got lost between sessions and machines — no structural mechanism for ordered work

**What changed**:
- Agents on any machine now know what to work on next via git-tracked BACKLOG.json queue. Structural gates enforce queue order at implement/work/done commands.

**Next steps**:
- See backlog (ag backlog list). Merge PR, then follow-up: STATUS.md simplification.

**Blockers**: None

**Metadata**:
- Feature: F-0190


### Session: 2026-03-08 19:28 - F-0190 review fixes

**Why**: Code review found issues that should be fixed before merge

**What changed**:
- Fixed 3 code review issues: unknown backlog subcommand now errors, F-0190 Since version corrected to v0.49.0, cmd_start backlog display consolidated to single python3 call

**Next steps**:
- Push fixes to PR #78 for re-review

**Blockers**: None


### Session: 2026-03-08 19:34 - F-0190 doc updates

**Why**: Backlog feature was code-complete but agents had no awareness of it — instruction files ARE the feature delivery

**What changed**:
- All agent instruction files now reference backlog: 18 files across quick commands, trigger tables, where-to-log routing, session start, feature workflow gates, and completion flow

**Next steps**:
- Push to PR #78, re-review

**Blockers**: None


### Session: 2026-03-08 19:36 - F-0190 user-facing docs

**Why**: Instruction files were updated but actual documentation (HOW_IT_WORKS, DEVELOPER_GUIDE) was still missing backlog content

**What changed**:
- HOW_IT_WORKS.md has backlog section + mermaid diagram, DEVELOPER_GUIDE.md has backlog in workflows, memory-seed has instruction-files-are-features rule

**Next steps**:
- Push final docs to PR #78

**Blockers**: None


### Session: 2026-03-08 21:06 - F-0180 Review Checkpoints

**Why**: Quality gates between lifecycle states — gates check structure, reviews check quality

**What changed**:
- Review checkpoint framework with configurable modes (human/critical_agent/auto) per transition, ag review command, verdict artifacts, 30 tests — all passing

**Next steps**:
- Instruction file updates, VERSION bump, smoke test

**Blockers**: None


### Session: 2026-03-08 21:12 - F-0180 instruction files

**Why**: Framework features must update instruction files to reach agents in user projects

**What changed**:
- Added ag review to all instruction files (13 files), 21 framework validation tests, trigger word tables, memory-seed, auto_orchestration, DEVELOPER_GUIDE, HOW_IT_WORKS

**Next steps**:
- Smoke test, VERSION bump

**Blockers**: None


### Session: 2026-03-08 21:25 - F-0180 code review fixes

**Why**: Harden review checkpoint framework after code review

**What changed**:
- Fixed all 14 code review findings: feature ID validation, regression pairs sync with state_machine, atomic verdict writes, safe file operations, flexible HN-ID regex, mutually exclusive CLI flags, cache-clearing test fixture, 12 new tests

**Next steps**:
- Feature complete

**Blockers**: None


### Session: 2026-03-08 21:55 - F-0192 Review Subagent

**Why**: Token efficiency: review context is large but disposable

**What changed**:
- Review skill delegates to fresh-context subagent — diffs and file reads stay out of main conversation, only structured findings report comes back

**Next steps**:
- PR review, merge

**Blockers**: None


### Session: 2026-03-09 11:37 - F-0194 review fixes

**Why**: Code review found critical locking bugs and missing worktree cleanup wiring

**What changed**:
- Fixed all code review findings: atomic file locking (C-1/C-2/C-3), global agent detection in cmd_start (H-2), worktree auto-cleanup in ag done (H-3), per-worktree feature resolution (H-4), AGENTS_JSON export (H-6), migrate dedup (M-3), active stale detection (M-5), safe auto-remove (M-6), targeted stderr suppression (M-9)

**Next steps**:
- PR ready for re-review

**Blockers**: None


### Session: 2026-03-09 12:10 - F-0194 shipped

**Why**: Post-merge housekeeping

**What changed**:
- AGENTS.json registry + worktree-by-default merged and tagged v0.51.0. Added T-0048/T-0049: plan file gate for ag implement and /review.

**Next steps**:
- Next feature from backlog

**Blockers**: None


### Session: 2026-03-09 13:04 - Fix HUMAN_NEEDED path

**Why**: Post-merge PR auto-resolve was broken since directory restructure

**What changed**:
- sync.sh and ag.sh now use $HUMAN_NEEDED_FILE from paths.sh instead of hardcoded root path — PR cleanup phase was silently skipping the file after directory restructure

**Next steps**:
- None

**Blockers**: None


### Session: 2026-03-09 14:39 - Agent-agnostic cleanup

**Why**: Enforcing agent-agnostic principle: scripts belong in .agentic/ not .claude/

**What changed**:
- dashboard.sh moved to .agentic/lib/tools/, FRAMEWORK_DEVELOPMENT.md gains Agent-Agnostic and Lessons Learned sections, auto-memory slimmed to pointers

**Next steps**:
- Commit and push to PR #85

**Blockers**: None


### Session: 2026-03-09 16:12 - F-0181 Autonomous Formal

**Why**: ADR-001 Phase 3: enable autonomous agent workflows with formal rigor

**What changed**:
- Added autonomous_formal profile with is_formal_like() helper, 22 files updated, 18 tests passing, PR #86 created

**Next steps**:
- Human review of PR #86

**Blockers**: None


### Session: 2026-03-09 17:34 - F-0182 Critical Review Agent

**Why**: Making critical_agent functional is the key enabler for autonomous workflows (F-0186) and the full ADR-001 Phase 4 vision

**What changed**:
- critical_agent review mode now spawns adversarial Claude instance with structured verdicts, model resolution, error handling + retry, human fallback. 46 new tests, 574/574 framework validation. Replaces F-0182 placeholder.

**Next steps**:
- F-0183 Taste/Style or F-0184 Epic Decomposition (both unblocked by F-0182)

**Blockers**: None


### Session: 2026-03-09 17:56 - Silent session start

**Why**: Agents were outputting verbose narration before the dashboard, wasting screen space and user attention

**What changed**:
- Session start dashboard is now the first text output across all tools — no preamble narration before dashboard in Claude, Cursor, Copilot, Codex instruction layers

**Next steps**:
- Commit and PR

**Blockers**: None


### Session: 2026-03-09 20:02 - F-0195 Collision Prevention

**Why**: Preventing destructive git ops from destroying work when multiple sessions share a checkout

**What changed**:
- Three-layer multi-session collision prevention: session auto-registration, advisory UserPromptSubmit warning, instruction hardening across all agent templates. 18 unit tests + 13 structural validation tests.

**Next steps**:
- PR #90 review and merge

**Blockers**: None


### Session: 2026-03-09 21:56 - Dashboard self-rendering (v0.52.2)

**Why**: Agents kept reformatting the dashboard despite instruction hardening; moved rendering into the script itself

**What changed**:
- dashboard.sh now renders final emoji dashboard — agents output verbatim, no parsing needed

**Next steps**:
- F-0180 Review Checkpoint Framework

**Blockers**: None


### Session: 2026-03-09 22:47 - Dashboard project name

**Why**: Dashboard showed 'workspace' instead of real project name in containers

**What changed**:
- Derive repo name from git remote when dir name is generic (e.g. Docker /workspace)

**Next steps**:
- None

**Blockers**: None


### Session: 2026-03-09 23:20 - Backlog commit fix

**Why**: Backlog advancement was silently lost between sessions because skills never staged BACKLOG.json

**What changed**:
- Completing-work and committing-changes skills now ensure BACKLOG.json changes are committed alongside feature completions

**Next steps**:
- Review and merge PR

**Blockers**: None


### Session: 2026-03-10 09:47 - Intent-Based Skill Triggers

**Why**: Agent missed completing-work workflow when user said 'merged' because trigger words were a brittle keyword list

**What changed**:
- Skill trigger descriptions now match user intent instead of exact keywords — agents will correctly fire completing-work on 'merged', fixing-bugs on 'crash', etc.

**Next steps**:
- F-0183 implementation

**Blockers**: None


### Session: 2026-03-10 13:09 - F-0196 ag flush

**Why**: State files accumulated dirty across sessions because PR workflow was disproportionate for bookkeeping changes

**What changed**:
- Framework now has ag flush command to commit state-only files directly to main without a PR — hardcoded allowlist enforces security boundary

**Next steps**:
- Merge PR, bump VERSION, mark shipped

**Blockers**: None


### Session: 2026-03-10 13:22 - F-0196 Shipped

**Why**: Eliminated friction from state file commits in PR workflow

**What changed**:
- ag flush command now available — state files (BACKLOG.json, STATUS.md, JOURNAL.md, etc.) can be committed directly to main without a PR

**Next steps**:
- Next backlog item

**Blockers**: None


### Session: 2026-03-10 13:24 - ag flush bugfix

**Why**: ag flush failed on first real use due to unstaged changes blocking rebase

**What changed**:
- Fixed ag flush failure when dirty state files exist during git pull --rebase — stage files before pull, unstage on conflict

**Next steps**:
- None

**Blockers**: None


### Session: 2026-03-10 14:01 - VERSION Post-Merge Workflow

**Why**: Multi-PR VERSION conflicts made in-PR bumping unworkable

**What changed**:
- VERSION bumps now happen post-merge via ag done instead of in PRs, eliminating multi-PR merge conflicts on VERSION file

**Next steps**:
- Merge PR, verify ag done bumps VERSION on main

**Blockers**: None


### Session: 2026-03-10 15:03 - F-0200 PR1: State Machine Idempotency + intents.py

**Why**: Prerequisite for intent journal: state machine must handle re-execution gracefully

**What changed**:
- Fixed can_transition/transition idempotency (AC-001/002), created intents.py module with 7 functions and 38 unit tests (AC-003 through AC-009)

**Next steps**:
- PR2: intent-helpers.sh + cmd_implement wiring

**Blockers**: None


### Session: 2026-03-10 15:52 - Fix stray conflict marker

**Why**: validate_framework.sh had syntax error from stray conflict marker

**What changed**:
- Removed =======  marker left in validate_framework.sh from PR merge

**Next steps**:
- Merge to main

**Blockers**: None


### Session: 2026-03-10 18:03 - Autonomous workflow analysis

**Why**: Documenting what made parallel autonomous implementation work for future reference

**What changed**:
- Saved analysis of F-0197-F-0200 session to journal/lessons

**Next steps**:
- VERSION bump for merged features

**Blockers**: None


### Session: 2026-03-10 18:57 - ag done post-merge gaps

**Why**: Completed features stayed in_progress in FEATURES.md and lingered in backlog because ag done only warned (didn't act) and only advanced position-0 items

**What changed**:
- ag done now auto-marks features as shipped and removes them from backlog by ID (not position). Fixed feature.sh awk regex that silently failed on heading-format FEATURES.md — root cause of T-0050 status drift.

**Next steps**:
- Review and merge PR

**Blockers**: None


### Session: 2026-03-10 19:35 - F-0186 Autonomous Scheduler

**Why**: ADR-001 Phase 7: scheduling is the final piece for fully autonomous execution — reviews no longer stall the pipeline

**What changed**:
- AutonomousScheduler class enables non-blocking epic execution: finds unblocked features, spawns component-scoped workers, handles review escalations without stalling other features. Crunch mode now backed by scheduler. ag auto epic F-XXXX command available.

**Next steps**:
- Wire F-0186 validation into validate_framework.sh, update instruction files (memory-seed, auto_orchestration)

**Blockers**: None


### Session: 2026-03-10 19:50 - F-0186 Review Fixes

**Why**: Code review found correctness gaps and missing documentation

**What changed**:
- Applied 5 review findings: shipped-feature counting, escalation wiring, component-scoped work_root via load_registry, dead code cleanup in crunch.py. Added 4 new tests (23 total). Documented ag auto epic in all 9 instruction files.

**Next steps**:
- Push to PR #109 for re-review

**Blockers**: None


### Session: 2026-03-10 22:36 - F-0185 Coordination Server

**Why**: Enable parallel agents, remote review, and mobile monitoring via network API

**What changed**:
- HTTP JSON-RPC coordination server with 8 tools, atomic claim/release, concurrent access safety, bearer auth, 60 tests, full docs in HOW_IT_WORKS.md

**Next steps**:
- PR review, then ag done F-0185

**Blockers**: None


### Session: 2026-03-10 22:51 - F-0185 review fixes

**Why**: Code review of PR #110 found HIGH issue (review checkpoints not actually skipped in RPC) plus MEDIUM/LOW security and reliability issues

**What changed**:
- Fixed 4 code review findings: skip_review param on transition(), flag-based SIGTERM handler, idempotent cleanup guard, constant-time token comparison. Added CONTRIBUTIONS.md entry.

**Next steps**:
- Push to PR, merge

**Blockers**: None


### Session: 2026-03-10 23:06 - F-0185 shipped

**Why**: Feature completion lifecycle

**What changed**:
- Coordination Server merged and marked shipped. VERSION bumped to 0.53.2. Backlog advanced.

**Next steps**:
- Next feature from backlog

**Blockers**: None


### Session: 2026-03-10 23:53 - TODO Triage

**Why**: Post-F-0185/F-0186 cleanup — 38 TODOs accumulated, many obsolete

**What changed**:
- Closed 5 obsolete/shipped TODOs (T-0010, T-0016, T-0030, T-0031, T-0033), deprecated F-0108, promoted T-0051 to backlog position 0

**Next steps**:
- Implement T-0051 (AC check-off enforcement) or continue with F-0187

**Blockers**: None


### Session: 2026-03-11 00:11 - Key Insights Doc

**Why**: Capturing hard-won architectural lessons from 50+ versions of framework development

**What changed**:
- Created docs/KEY_INSIGHTS.md with 8 strategic patterns for AI agent control, added contribution entry

**Next steps**:
- Continue with backlog (T-0051 or F-0187)

**Blockers**: None


### Session: 2026-03-11 09:32 - F-0183 + T-0051

**Why**: ADR-002 gap: review_taste was a placeholder, now functional

**What changed**:
- Taste review wired into checkpoint system; AC check-off advisory in pre-commit; all doc updates done

**Next steps**:
- PR review, merge

**Blockers**: None


### Session: 2026-03-11 09:34 - F-0183 + T-0051 shipped

**Why**: ADR-002 implementation: review_taste now functional, backlog advances

**What changed**:
- Taste review wired into checkpoint system; AC advisory in pre-commit; all docs updated; VERSION 0.53.3

**Next steps**:
- Next: F-0201 Vision-to-Backlog Pipeline

**Blockers**: None


### Session: 2026-03-11 11:48 - Quick Wins Batch

**Why**: Batch of 5 quick-win TODO closures to reduce maintenance debt

**What changed**:
- Ship F-0103, remove legacy manifests, commit nudge, plan advisory in review, dashboard after done

**Next steps**:
- PR review, merge

**Blockers**: None


### Session: 2026-03-11 12:31 - Quick Wins Batch Shipped

**Why**: Reduce maintenance debt and improve agent completion UX

**What changed**:
- 5 TODOs closed: F-0103 shipped, legacy manifests removed, commit nudge in ag done + skill + cursorrules, plan advisory in ag review, dashboard after ag done

**Next steps**:
- Next backlog item

**Blockers**: None


### Session: 2026-03-11 13:47 - Quick Wins Batch 2

**Why**: Follow-up cleanup from quick wins batch 1

**What changed**:
- Fix manifest.sh legacy path (T-0055), close T-0015 and T-0028 as superseded

**Next steps**:
- Next backlog item

**Blockers**: None


### Session: 2026-03-11 16:58 - T-0054: Doc + LLM test gates

**Why**: Agents repeatedly forgot to update project docs and never considered LLM behavioral tests when shipping features

**What changed**:
- Agents now have explicit doc-update decision flow and LLM test advisory at three instruction layers (skills, memory-seed, before_commit checklist). Doc registry maintenance is part of the workflow, not an afterthought.

**Next steps**:
- Merge PR, ag done

**Blockers**: None


### Session: 2026-03-11 17:12 - Fix: backlog done guard

**Why**: backlog.sh done blindly popped position 0 without checking FEATURES.md status, causing F-0201 to be silently dropped

**What changed**:
- backlog.sh done now validates feature is shipped before removing — prevents accidental advancement of unimplemented features

**Next steps**:
- Merge, ag done

**Blockers**: None


### Session: 2026-03-11 17:25 - Fix: manifest + backlog guards

**Why**: manifest.sh regenerated duplicates after rebases, backlog.sh done silently dropped unshipped features

**What changed**:
- Manifests are now frozen after first generation (no rebase noise), commits deduped by message+date. Backlog done validates shipped status. State flush includes manifests.

**Next steps**:
- Merge PR, ag done

**Blockers**: None


### Session: 2026-03-11 17:39 - PR #117 merged

**Why**: Bug fixes for backlog safety and manifest regeneration

**What changed**:
- Backlog done guard prevents removing unshipped features; manifest dedup by message+date survives rebases; ag flush can commit manifests via prefix patterns

**Next steps**:
- STACK.md doc registry update, then next backlog item

**Blockers**: None


### Session: 2026-03-11 17:55 - Definition of done slogan

**Why**: Old slogan understated the full artifact lifecycle — specs and tests were missing from the definition of done

**What changed**:
- Updated 'code + docs = done' to 'spec + code + tests + docs = done' across all 11 instruction files

**Next steps**:
- PR review, merge, ag done

**Blockers**: None


### Session: 2026-03-11 18:14 - Plan gate enforcement

**Why**: Agents were skipping planning and jumping straight to AC/code when 'implement' was triggered without a plan

**What changed**:
- implementing-features now requires an approved plan before coding — no plan = STOP and plan first, not skip planning

**Next steps**:
- Commit, PR, then plan F-0207 properly

**Blockers**: None


### Session: 2026-03-11 22:47 - F-0207 Doc Lifecycle Validation

**Why**: Doc registry had no structural enforcement — entries could point to missing files, docs could exist unregistered

**What changed**:
- Docs can now be validated (--validate: registry health), scaffolded (--create: template + auto-register), and coverage-reported (--coverage: type breakdown). Pre-commit check 19 and ag done both enforce registry health when docs_gate is enabled.

**Next steps**:
- Merge, ag done, advance backlog

**Blockers**: None


### Session: 2026-03-11 23:01 - F-0207 Review Fixes

**Why**: PR review feedback on structural doc lifecycle feature

**What changed**:
- Fixed 6 PR review issues: return overflow in docs.sh, pre-commit check 19 now shows both missing and unregistered counts, added --coverage test, updated before_commit.md/auto_orchestration.md/HOW_IT_WORKS.md

**Next steps**:
- Push fixes, merge PR

**Blockers**: None


### Session: 2026-03-11 23:03 - F-0207 Complete

**Why**: Doc lifecycle was reactive — agents forgot to check registry. Now structural gates catch gaps.

**What changed**:
- Projects can now validate doc registry health (registered-but-missing + unregistered docs), scaffold new docs with auto-registration, and see coverage reports — enforced at ag done and pre-commit check 19

**Next steps**:
- Next: advance backlog

**Blockers**: None


### Session: 2026-03-12 12:29 - F-0208 Deferred Documentation Mode

**Why**: No way to opt out of inline doc updates without disabling all doc checks — users need to move fast AND eventually get docs

**What changed**:
- Projects can now set docs_mode: deferred to skip inline doc updates during fast iteration, with deferred-docs.json tracking what's owed and ag docs generate processing the queue later

**Next steps**:
- PR review, then ag done F-0208

**Blockers**: None


### Session: 2026-03-12 13:30 - F-0208 Complete

**Why**: Shipped deferred documentation mode

**What changed**:
- Projects can now set docs_mode: deferred to skip inline doc updates during fast iteration — deferred-docs.json tracks what's owed, ag docs generate processes the queue later

**Next steps**:
- Next backlog item

**Blockers**: None


### Session: 2026-03-12 18:39 - F-0201 ag kickoff

**Why**: Enable Mode 2/3 autonomous flow by converting product visions to structured specs in one command

**What changed**:
- Vision-to-backlog pipeline: kickoff.py backend (generate, validate, promote, edit ops, discard), ag.sh cmd_kickoff (script mode, review loop, settings), all 10 instruction files updated

**Next steps**:
- PR review, playbook mode (deferred to child)

**Blockers**: None


### Session: 2026-03-12 21:12 - F-0202: ag preview

**Why**: Enable Mode 2 feedback loops — users test working software rather than reviewing diffs

**What changed**:
- Projects can now show dev/build/test commands via ag preview — detects stack from STACK.md with auto-detection fallback, PM-aware commands (pnpm/yarn/bun), source attribution

**Next steps**:
- Ship F-0202, update memory-seed version sentinel

**Blockers**: None


### Session: 2026-03-12 21:44 - F-0202 shipped

**Why**: Enable Mode 2 feedback loops

**What changed**:
- ag run command available — shows dev/build/test commands with stack detection and PM awareness

**Next steps**:
- Next backlog item

**Blockers**: None


### Session: 2026-03-13 00:08 - F-0203 Auto-Commit Review

**Why**: Formalizing known R2 violation in task.py — auto-commit existed without review; now gated by review_commit setting

**What changed**:
- R2 principle now conditional: interactive sessions preserve absolute no-auto-commit rule; autonomous workflows (ag auto task/epic) can auto-commit after adversarial CriticalAgent review when review_commit: critical_agent. Dedicated review_commit() method with minimal context (staged diff + single AC only). 15 instruction files amended, 8 unit tests, 8 structural tests.

**Next steps**:
- PR review, merge, ag done

**Blockers**: None


### Session: 2026-03-13 10:22 - F-0203 Complete

**Why**: R2 principle amended to enable autonomous workflows without sacrificing safety

**What changed**:
- Framework now supports conditional auto-commit via review_commit setting — agents can commit autonomously when profile allows (autonomous_formal→critical_agent), while preserving human review by default

**Next steps**:
- Next: F-0204 Epic Integration Verification

**Blockers**: None


### Session: 2026-03-13 15:46 - F-0204 Shipped

**Why**: Closing the autonomous pipeline safety gap for epic shipping

**What changed**:
- Epic integration verification gate now prevents epics from shipping without cross-component tests passing

**Next steps**:
- Complete F-0204 done workflow, implement fix-draft-plan-bypass plan

**Blockers**: None


### Session: 2026-03-13 17:09 - PR cleanup + sandbox fixes

**Why**: Housekeeping after F-0204 + post-mortem fix landed

**What changed**:
- Merged PR #126 (orphaned plan detection), resolved 5 stale HUMAN_NEEDED entries, hardened sandbox firewall

**Next steps**:
- Next backlog item

**Blockers**: None


### Session: 2026-03-13 17:51 - AGENTS.json cleanup

**Why**: Completed entries accumulated forever in AGENTS.json, cluttering dashboard

**What changed**:
- release() and stale-claim cleanup now remove entries instead of marking completed; cmd_list and cleanup_stale purge legacy completed entries

**Next steps**:
- PR review, merge

**Blockers**: None


### Session: 2026-03-13 18:05 - Instruction file sync

**Why**: Templates and root instruction files had drifted — missing commands, wrong paths, stale triggers

**What changed**:
- Fixed cursor template path bugs, synced Quick Commands and trigger words across all 4 templates and 4 root files, added extends note to root CLAUDE.md

**Next steps**:
- Merge PR

**Blockers**: None


### Session: 2026-03-13 19:06 - F-0205 ag formalize

**Why**: No automated path from discovery-mode TODO items to formal spec artifacts — manual copy/reformat was tedious and error-prone

**What changed**:
- Projects can now promote TODO inbox items to formal spec structure (FEATURES.md entries + AC stubs) via ag formalize. Reuses quick_feature.sh and todo.sh triage. Supports single-item, multi-item, --all, and --dry-run modes.

**Next steps**:
- Merge PR, run ag done F-0205

**Blockers**: None


### Session: 2026-03-13 21:40 - F-0206: Feedback Capture System

**Why**: No structured way to capture and route user feedback after testing — feedback stayed in chat and was lost between sessions

**What changed**:
- Users can now capture, classify, and route feedback after testing working software via ag feedback. Keyword heuristics auto-classify as bug/feature/ac-adjust/unclear. Routes to existing tools (ISSUES.md, TODO.md). Persistent FEEDBACK_LOG.md with FB-XXXX IDs. Engine cleanup flushes in-flight feedback.

**Next steps**:
- Ship F-0206, advance backlog

**Blockers**: None


### Session: 2026-03-13 21:58 - Post-merge ag done

**Why**: Agent merged PR #130 but told user to run ag done instead of running it automatically

**What changed**:
- Agents now automatically run ag done after merging a PR via gh pr merge — no manual user prompt

**Next steps**:
- None — fix complete

**Blockers**: None


### Session: 2026-03-14 10:32 - F-0187 Multi-Repo Umbrella

**Why**: Enable framework to orchestrate components across separate git repositories

**What changed**:
- Implemented multi-repo umbrella support: header-aware component parsing with optional Repo column, umbrella path resolution with availability/git validation, contract topology validation, structured input collection

**Next steps**:
- Create PR for review, mark feature shipped after merge

**Blockers**: None


### Session: 2026-03-14 16:09 - F-0188 E2E Pipeline

**Why**: ADR-001 Phase 7 capstone: no single function chained kickoff→promote→epic→schedule before

**What changed**:
- Full autonomous pipeline wired: ag auto pipeline creates epic, promotes features with parent links, schedules all children through implement→review→ship. Gate check blocks human review mode. 14 E2E tests, all instruction files updated.

**Next steps**:
- Ship F-0188, advance backlog

**Blockers**: None


### Session: 2026-03-14 16:17 - F-0188 Shipped

**Why**: ADR-001 Phase 7 capstone: autonomous vision-to-shipped pipeline

**What changed**:
- End-to-end autonomous pipeline now available via ag auto pipeline — wires kickoff, epic, scheduler into single flow

**Next steps**:
- Next backlog item F-0209

**Blockers**: None


### Session: 2026-03-14 16:25 - ag done docs_gate fix

**Why**: set -e killed ag done before reaching flush, leaving FEATURES.md dirty

**What changed**:
- ag done no longer aborts when docs.sh --validate exits non-zero — VERSION bump and state flush now run reliably

**Next steps**:
- None

**Blockers**: None


### Session: 2026-03-14 19:09 - Plan review bypass fix

**Why**: Most repeated user feedback: agent skips review after plan mode exit

**What changed**:
- Dialectical review gate can no longer be bypassed after plan mode exit — ag.sh reordered, error messages carry review instructions, 9 instruction files updated with rationalization rebuttals

**Next steps**:
- PR review and merge

**Blockers**: None


### Session: 2026-03-14 17:59 - F-0209 shipped

**Why**: development_mode: tdd was a dead label with no enforcement

**What changed**:
- TDD mode is now a real behavioral mode with three enforcement layers: skill-level branching, --phase checkpoints, and completion gate blocking

**Next steps**:
- F-0210 next in backlog

**Blockers**: None


### Session: 2026-03-14 22:09 - F-0214 Parallel Epic Execution

**Why**: Sequential epic execution bottleneck — 5 children × 10min = 50min serial vs 10min parallel

**What changed**:
- ParallelDispatcher creates worktrees, spawns concurrent Claude processes, rolling slot management; strengthened LLM test requirement from advisory to mandatory

**Next steps**:
- PR review, manual testing with real epic

**Blockers**: None


### Session: 2026-03-14 20:17 - F-0214 Review Fixes

**Why**: Code review found file descriptor leak and dead code in parallel.py

**What changed**:
- Fixed fd leak in parallel dispatcher: log_file field on AgentProcess, removed dead spawn_claude_async, removed unused completed_ids

**Next steps**:
- Update CONTRIBUTIONS.md, merge PR

**Blockers**: None


### Session: 2026-03-14 20:17 - F-0214 CONTRIBUTIONS

**Why**: Framework dev rule: CONTRIBUTIONS.md on every PR

**What changed**:
- Added F-0214 contribution entry documenting parallel epic design and code review fixes

**Next steps**:
- Merge PR

**Blockers**: None


### Session: 2026-03-14 21:35 - F-0215 Framework Verification Loop

**Why**: No existing test exercises the framework as a user — unit/LLM tests miss integration gaps

**What changed**:
- Framework can now self-test by spawning agents that build real projects end-to-end using ag commands, self-healing framework bugs and delivering fixes as a PR

**Next steps**:
- Smoke test in sandbox, ship

**Blockers**: None


### Session: 2026-03-15 09:03 - Framework Verify Improvements

**Why**: First real verify-framework run revealed crash bug, timeout too short, and no visibility into agent progress

**What changed**:
- Fixed ScenarioRun crash, increased timeouts (3600s/7200s), added progress monitor thread and per-attempt log files, logs stored in workspace for cross-container visibility

**Next steps**:
- Run full verification suite (all scenarios)

**Blockers**: None


### Session: 2026-03-15 09:06 - Behavioral Expectations

**Why**: Milestones only checked process artifacts, not whether the built app actually works

**What changed**:
- Added ExpectationChecker with files_exist, commands_pass, source_contains checks to all 5 verification scenarios

**Next steps**:
- Run full verify-framework with expectations to validate end-to-end

**Blockers**: None


### Session: 2026-03-15 09:13 - Workflow Expectations

**Why**: Previous expectations only checked app output, not whether the framework workflow was actually followed

**What changed**:
- Added 7 workflow expectation types: features_have_status, plans_exist, plans_approved, acceptance_criteria_checked, journal_updated, commits_follow_convention, no_wip_at_end. Profile-aware: formal profiles require plans+review+AC checks, discovery only basic flow

**Next steps**:
- Run autonomous_formal scenario to validate plan review loop is detected

**Blockers**: None


### Session: 2026-03-15 09:27 - Repair Loop + Safety Guard

**Why**: Verification should iterate on failures instead of binary pass/fail, and must not run in production projects

**What changed**:
- Added iterative repair loop: failed expectations get targeted fix agents, up to 3 attempts, then escalate. Added framework-only guard: verify-framework refuses to run in user projects (checks FRAMEWORK_DEVELOPMENT.md)

**Next steps**:
- Run full verification with repair loop to validate end-to-end

**Blockers**: None


### Session: 2026-03-15 10:21 - Settings-driven workflow expectations

**Why**: Workflow expectations were coupled to profile names, not resolved settings — overrides were ignored

**What changed**:
- derive_workflow_expectations() uses get_setting() 3-level fallback; removed hardcoded workflow expectations from all 5 scenario YAMLs; fixed _write_stack_md to let profile defaults drive plan_review_enabled; added derivation tests

**Next steps**:
- PR review and merge

**Blockers**: None


### Session: 2026-03-15 10:27 - Agent bootstrap in verification

**Why**: Build agents were spawned without instruction files, operating blind

**What changed**:
- setup_project now calls setup-agent.sh + generate-skills.sh so build agents get CLAUDE.md, skills, and AGENTS.md — matching what real users get at install time

**Next steps**:
- PR review

**Blockers**: None


### Session: 2026-03-15 10:34 - Review fixes

**Why**: Code review found correctness and efficiency issues in the verification loop

**What changed**:
- Fixed 5 review issues: multirepo default profile, repair loop targeted re-check via check_one(), index-based milestone separation, journal ### Session: pattern, integration test for derivation wiring

**Next steps**:
- Push and update PR

**Blockers**: None


### Session: 2026-03-15 12:30 - Discovery-mode verification prompts

**Why**: Agent spawning should test instruction discovery, not plumbing — plumbing is already covered by 675+ static tests

**What changed**:
- Replaced recipe prompt with discovery prompt as default; added 5 behavioral checkers; removed review_plan/review_commit skip overrides; added --prompt-tier CLI flag; 34 new tests (94 total passing)

**Next steps**:
- PR review, E2E verification with real agent spawning

**Blockers**: None


### Session: 2026-03-15 12:51 - Discovery prompt iteration

**Why**: Discovery prompt too minimal — agents need autonomous context and CLAUDE.md pointer to discover framework workflow

**What changed**:
- Round 1 revealed agents ask for commit confirmation (no human in --print mode) and skip ag kickoff; added autonomous execution context and CLAUDE.md-first instruction to discovery prompt

**Next steps**:
- Re-run verification with fixed prompt

**Blockers**: None


### Session: 2026-03-15 13:06 - Discovery verification round 2 results

**Why**: Iterating on discovery prompt and behavioral checkers based on real verification results

**What changed**:
- todo_app discovery passed on attempt 2: agent read CLAUDE.md, used ag commands, built 30-test app, shipped 4 features; relaxed kickoff checker regex; fixed spec_before_code to skip scaffold commit

**Next steps**:
- Run cli_tool scenario, consider testing formal profile

**Blockers**: None


### Session: 2026-03-15 13:25 - CLI tool discovery verification

**Why**: Validating discovery prompt generalizes across different project types

**What changed**:
- cli_tool discovery passed on attempt 3: agent built 57-test file organizer with Click, 7 features shipped; all advisory behavioral checks also passed on successful attempt

**Next steps**:
- Run api_service scenario (TypeScript) to test cross-language discovery

**Blockers**: None


### Session: 2026-03-15 13:51 - API service discovery verification

**Why**: Confirming discovery prompt works across language boundaries

**What changed**:
- api_service (TypeScript/Express) discovery passed on attempt 2: 9 commits, 5 features shipped, all advisory checks passed; 3/3 discovery scenarios now verified across Python and TypeScript

**Next steps**:
- Test formal profile (todo_app settings-index 1) for dialectical review flow

**Blockers**: None


### Session: 2026-03-15 14:07 - Formal profile verification complete

**Why**: Complete verification of discovery-mode prompts across all profiles and languages

**What changed**:
- todo_app autonomous_formal passed on attempt 1 (with 3 repairs for AC/plans/plan-approval); all 5 advisory behavioral checks passed including plans_reviewed; 4/4 verification scenarios now confirmed working with discovery prompt

**Next steps**:
- PR ready — all scenarios verified

**Blockers**: None


### Session: 2026-03-15 17:12 - Framework fixes from verification findings

**Why**: Verification loop revealed agents block on commit confirmation in autonomous mode and skip AC check-off during done workflow

**What changed**:
- Amended commit rule across 14 instruction files: interactive=show first, autonomous=commit directly; added AC check-off instruction to completing-work skill

**Next steps**:
- Merge and push

**Blockers**: None


### Session: 2026-03-15 20:03 - Systematic Quality Improvement

**Why**: User projects need agents that write clear ACs, implement against them, and prove ACs are met

**What changed**:
- Shared AC parser, completeness enforcement (P1=100% P2=80% flat=80%), AC clarity gate in ag implement, NFR→AC inline integration with nfr-applicable.sh, language-aware test quality checks — all 4 phases shipped with 23 new unit tests and 675 framework tests passing

**Next steps**:
- Instruction file sync verification, LLM tests for behavioral changes

**Blockers**: None


### Session: 2026-03-15 20:05 - Contributions fix

**Why**: Accurate attribution

**What changed**:
- Corrected CONTRIBUTIONS.md — user framed the problem and directed reviews, did not design implementation details

**Next steps**:
- TBD

**Blockers**: None


### Session: 2026-03-15 20:11 - Review fixes

**Why**: Code review found correctness and portability bugs

**What changed**:
- Fixed 4 issues from code review: bare-format double-counting bug, --skip-clarity arg parsing, bash 3.x portability, mixed-format regression test

**Next steps**:
- TBD

**Blockers**: None


### Session: 2026-03-15 20:16 - Systematic Quality Epic shipped

**Why**: User projects get agents that write clear ACs, enforce completeness, and catch vague specs

**What changed**:
- Framework now has shared AC parser, completeness enforcement (P1=100% P2=80% flat=80%), AC clarity gate with rewrite suggestions, NFR→AC inline integration, language-aware test quality checks. 27 unit tests, 675 framework tests passing.

**Next steps**:
- LLM tests for behavioral changes, T-0067 NFR lifecycle templates

**Blockers**: None


### Session: 2026-03-15 22:12 - NFR Lifecycle Epic

**Why**: NFRs are passive documentation — building lifecycle tools to make them active

**What changed**:
- Plan approved (4 iterations, dialectical review). Order 0: spec stubs for F-0216 through F-0219. Order 0.5: validator bugfix — expanded VALID_NFR_CATEGORIES, added glob path resolution, fixed NFR-0004 test path.

**Next steps**:
- Implement F-0216 (NFR auto-generation) and F-0217 (NFR test gate) in parallel

**Blockers**: None


### Session: 2026-03-16 18:35 - Framework System Map — Deep Pipeline + Opportunity Map

**Why**: Document full framework pipeline transformations and identify maturity gaps

**What changed**:
- Added Sections 12-15 (spec derivation, AC-to-test, verification loop, research phase) with running F-0042 example. Renumbered Part IV/V. Created comprehensive opportunity map epic plan (19 features, 6 waves) with dialectical review.

**Next steps**:
- Commit and merge docs/framework-system-map PR. Then begin Wave 0 triage of in-progress features.

**Blockers**: None


### Session: 2026-03-16 18:45 - E-0001 Epic Plan Saved

**Why**: Durable plan storage for opportunity map epic

**What changed**:
- Saved approved epic plan (19 features, 6 waves) to journal/plans after dialectical review and PR #144 merge

**Next steps**:
- Wave 0: triage 11 in-progress features, register 19 new features in FEATURES.md

**Blockers**: None


### Session: 2026-03-16 21:03 - F-0222 State Machine Enforcement = Blocking

**Why**: Formal profiles had advisory-only enforcement despite blocking branches in ag.sh — wiring gap meant state_machine.py never received --enforce flag

**What changed**:
- Gate failures now block transitions for formal profiles; ag done plan backstop catches retroactive planning; KEY_INSIGHTS §15 + §16 added

**Next steps**:
- Ship F-0222, update remaining instruction files if needed

**Blockers**: None


### Session: 2026-03-16 21:28 - F-0222 Shipped

**Why**: Formal profiles had advisory-only enforcement — wiring gap fixed, merged via PR #148

**What changed**:
- State machine enforcement now blocking for formal profiles; plan backstop in ag done catches retroactive planning; KEY_INSIGHTS §15 + §16

**Next steps**:
- Next: F-0224 (next backlog item)

**Blockers**: None


### Session: 2026-03-16 21:38 - ag merge + ag verify F-XXXX

**Why**: Agent forgot to run ag done after merging PR #148 and checked off ACs without running smoke tests

**What changed**:
- Structural chaining: ag merge wraps gh pr merge + ag done; ag verify runs automated AC commands; ag done now auto-verifies before shipping

**Next steps**:
- Ship these commands

**Blockers**: None


### Session: 2026-03-16 21:42 - ag merge + ag verify shipped

**Why**: Agent behavioral failures (forgetting ag done, skipping smoke tests) now structurally prevented

**What changed**:
- Structural post-merge chaining and AC verification now enforced

**Next steps**:
- Next backlog item: F-0224

**Blockers**: None


### Session: 2026-03-17 07:29 - F-0224 Smoke Test Evidence

**Why**: ag done had no verification that smoke testing actually happened — tests pass != it works

**What changed**:
- Evidence-based gate in ag done: checks for .agentic/journal/evidence/F-XXXX-smoke.* files. Three modes (off/recommended/required). verify.py gains --feature flag for auto-generation. Also fixed plan naming convention to always use date prefix.

**Next steps**:
- PR review, then ag done F-0224

**Blockers**: None


### Session: 2026-03-17 10:26 - F-0234 Plan-Review Hooks

**Why**: Structural enforcement for plan-save and review at transition points

**What changed**:
- ExitPlanMode hook + pre-commit Check 21 + architecture doc + 17 tests + LLM test

**Next steps**:
- Field validation of A11 (ExitPlanMode matcher)

**Blockers**: None


### Session: 2026-03-17 15:41 - F-0193 review fixes

**Why**: Address code review findings

**What changed**:
- Fixed MULTILINE flag, unused imports, case pattern, import placement

**Next steps**:
- Push updated PR

**Blockers**: None


### Session: 2026-03-17 15:44 - F-0193 shipped

**Why**: 100+ duplicated regex patterns across 50+ files made format changes impractical

**What changed**:
- Feature ID patterns centralized into ids.py/ids.sh — any future format change is a one-file edit

**Next steps**:
- Next: PR 2 for other ID types (NFR, T, I, HN, FB, R)

**Blockers**: None


### Session: 2026-03-17 15:46 - F-0193 shipped

**Why**: 100+ duplicated regex patterns made format changes impractical

**What changed**:
- Feature ID patterns centralized into ids.py/ids.sh

**Next steps**:
- PR 2 for other ID types

**Blockers**: None


### Session: 2026-03-17 16:09 - Dogfood sync + deferred capture

**Why**: Root instruction files drifted from templates after recent PRs; future items from PRs/plans were not being captured durably

**What changed**:
- Framework-dev instruction files synced with templates (8 files), deferred-item capture with mandatory context added to workflow (skills, checklists, memory-seed), 8 TODOs captured from F-0234/F-0193 with full background

**Next steps**:
- Commit and PR for review

**Blockers**: None


### Session: 2026-03-17 17:10 - F-0224 Smoke Test Evidence

**Why**: F-0224 was 95% complete; DEVELOPER_GUIDE was the only instruction file missing the setting reference

**What changed**:
- DEVELOPER_GUIDE settings table now includes smoke_test_evidence — last gap in AC10 instruction file coverage

**Next steps**:
- Ship F-0224, advance backlog to F-0225

**Blockers**: None


### Session: 2026-03-17 17:51 - F-0224 + plan-scan dedup fix

**Why**: plan-scan.sh created duplicate plans when same content existed under different naming (E-0001 vs F-0219)

**What changed**:
- Smoke test evidence gate complete (DEVELOPER_GUIDE was last gap). Plan-scan now detects epic IDs and deduplicates by content hash — no more phantom F-0219 saves

**Next steps**:
- Ship PR, advance backlog to F-0225

**Blockers**: None


### Session: 2026-03-17 18:00 - Test Entry

**What changed**:
- Did testing

**Next steps**:
- More tests

**Blockers**: None


### Session: 2026-03-17 18:02 - Test Entry

**What changed**:
- Did testing

**Next steps**:
- More tests

**Blockers**: None


### Session: 2026-03-17 18:03 - Test Entry

**What changed**:
- Did testing

**Next steps**:
- More tests

**Blockers**: None


### Session: 2026-03-17 18:07 - Test Entry

**What changed**:
- Did testing

**Next steps**:
- More tests

**Blockers**: None


### Session: 2026-03-17 18:08 - Test Entry

**What changed**:
- Did testing

**Next steps**:
- More tests

**Blockers**: None


### Session: 2026-03-17 18:09 - Test Entry

**What changed**:
- Did testing

**Next steps**:
- More tests

**Blockers**: None


### Session: 2026-03-17 18:11 - Test Entry

**What changed**:
- Did testing

**Next steps**:
- More tests

**Blockers**: None


### Session: 2026-03-17 19:08 - F-0225 Spec Evolution Metrics

**Why**: Framework lacked visibility into how specs evolve during implementation — discovered requirements and churn were invisible

**What changed**:
- New spec-metrics.sh tool with discovery counting, churn analysis, JSON output; integrated into ag audit --metrics, dashboard, retrospective checklist; updated 3 instruction files; added LLM test 085

**Next steps**:
- PR review, merge, ag done

**Blockers**: None


### Session: 2026-03-17 19:27 - F-0225 Shipped

**Why**: Specs evolved invisibly during implementation; now teams can see discovery patterns and scope instability

**What changed**:
- Framework now surfaces spec evolution metrics — discovery markers and churn analysis — via ag audit --metrics, dashboard, and retrospective checklist

**Next steps**:
- Next: F-0229

**Blockers**: None


### Session: 2026-03-18 13:48 - F-0229 Annotation Enforcement

**Why**: coverage.py detected missing annotations but nothing enforced adding them at commit time

**What changed**:
- Pre-commit Check 22 gates newly-shipped features for @feature annotations — three modes (off/advisory/blocking) with profile defaults, grandfathering for existing features

**Next steps**:
- PR review, merge, ag done

**Blockers**: None


### Session: 2026-03-18 20:23 - Test Entry

**What changed**:
- Did testing

**Next steps**:
- More tests

**Blockers**: None


### Session: 2026-03-18 21:35 - F-0226 Complete

**Why**: Root instruction files were silently drifting from templates after PR merges

**What changed**:
- Framework now auto-detects root vs template instruction file drift after merges via ag dogfood

**Next steps**:
- Next: F-0216

**Blockers**: None


### Session: 2026-03-18 22:02 - F-0234 Complete

**Why**: Diverged agent definitions caused inconsistency across tools

**What changed**:
- Agent definitions reconciled: 6 new roles, 4 deprecated, drift detection enforced in validate_framework.sh

**Next steps**:
- Next: audit recent PRs for doc update gaps

**Blockers**: None


### Session: 2026-03-18 22:09 - Instruction File Sync

**Why**: 14-day audit found CLAUDE.md missing 9 commands vs other templates

**What changed**:
- All 8 instruction files now have identical Quick Commands (26 commands). Added audit/nfr/transition triggers to cursor/copilot/codex.

**Next steps**:
- PR review and merge

**Blockers**: None


### Session: 2026-03-19 06:16 - Project Documentation Sync

**Why**: 14-day audit found project documentation lagging behind shipped features

**What changed**:
- CHANGELOG updated with v0.53-v0.64 (13 features). HOW_IT_WORKS updated with 9 missing features, stale counts fixed, mermaid diagram expanded.

**Next steps**:
- PR review and merge

### Session: 2026-03-19 08:12 - F-0235 + F-0236 Implementation

**Why**: Closing two autonomous pipeline gaps: PRs created by ag auto task were unreviewed, and plan review required human input per iteration

**What changed**:
- Auto-review after PR creation (PRReviewer, fix loop, scheduler integration); Autonomous plan convergence loop (ConvergenceDetector, PlanSynthesizer, ConvergenceLoop); 8-role reviewer catalog with 6 expert agents; 49 new tests passing, 707/708 validation checks

**Next steps**:
- PR creation, human review

**Blockers**: None


### Session: 2026-03-19 10:16 - F-0235 + F-0236 Shipped

**Why**: Post-merge completion workflow

**What changed**:
- PR #162 merged. Both features shipped: auto-review after PR creation (F-0235) and autonomous plan convergence loop with expert reviewers (F-0236). Review findings fixed before merge (print_mode bug, dead code).

**Next steps**:
- Post-merge: dogfood sync, version bump

**Blockers**: None


### Session: 2026-03-19 10:34 - Post-merge dogfood sync

**Why**: Completing post-merge workflow that was skipped

**What changed**:
- Synced copilot + codex root instruction files with templates (5 missing sentinels). Marked F-0235 + F-0236 shipped.

**Next steps**:
- Done

**Blockers**: None


### Session: 2026-03-19 10:37 - Instruction file gap fix

**Why**: Post-merge dogfood sync was incomplete — instruction files missed new settings

**What changed**:
- Added F-0235/F-0236 settings to agent_operating_guidelines.md (4 new rows in settings table). Added dogfood sync step to completing-work SKILL.md.

**Next steps**:
- Done — all instruction files now reference new features

**Blockers**: None


### Session: 2026-03-19 10:40 - Systemic fixes: ag flush + auto dogfood

**Why**: ag flush failed after every squash merge; dogfood sync was manual-only, causing recurring drift

**What changed**:
- Fixed ag flush post-squash-merge failure (commit-first-then-rebase). Added --auto-fix to dogfood-sync.sh for automatic sentinel drift repair. ag done now calls dogfood-sync --auto-fix instead of --brief.

**Next steps**:
- Done

**Blockers**: None


### Session: 2026-03-19 13:23 - Plan review rule

**Why**: Agent recommended 'Proceed with refinements during implementation' which defeats the purpose of plan review

**What changed**:
- Added 'no deferred refinements' rule across 8 dialectical review files + CONTRIBUTIONS.md

**Next steps**:
- F-0216 implementation (plan is revised and ready for fresh review)

**Blockers**: None


### Session: 2026-03-19 13:31 - Auto-continue plan review

**Why**: Agent stopped and waited after plan mode despite convergence: auto setting — instructions everywhere said 'wait for user'

**What changed**:
- Wired ExitPlanMode hook + updated 15 instruction files for convergence-aware auto-continue after plan mode

**Next steps**:
- F-0216 implementation

**Blockers**: None


### Session: 2026-03-19 15:11 - Backlog title fix

**Why**: Dashboard showed 'F-0216 F-0216' instead of feature titles

**What changed**:
- Backlog entries now resolve feature titles from FEATURES.md instead of storing bare IDs; backfilled 18 existing entries

**Next steps**:
- F-0216 planning

**Blockers**: None


### Session: 2026-03-19 16:27 - F-0216 Prep

**Why**: Enable fully autonomous workflow for backlog processing

**What changed**:
- Switched to autonomous_formal profile. Approved F-0216 plan after dialectical review with Critic+Advocate agents.

**Next steps**:
- Implement F-0216 through autonomous pipeline

**Blockers**: None


### Session: 2026-03-19 16:39 - F-0216 Implementation

**Why**: Transform passive NFR discovery into active, recommendation-driven flow

**What changed**:
- Implemented NFR auto-generation: --limit and --machine flags for nfr-generate.sh, new nfr-write-batch.sh for batch NFR creation, ag nfr discover defaults to 8 pre-selected recommendations, ag kickoff writes NFR-SUGGESTIONS.md to staging deterministically

**Next steps**:
- Create PR, update acceptance criteria

**Blockers**: None


### Session: 2026-03-19 17:05 - F-0216 Shipped

**Why**: Active NFR discovery replaces passive catalog dump

**What changed**:
- NFR auto-generation with --limit, --machine, batch writer, kickoff integration. Full autonomous pipeline validated.

**Next steps**:
- Next: F-0217 (NFR-Aware Test Writing)

**Blockers**: None


### Session: 2026-03-19 17:10 - F-0217 Shipped

**Why**: Verified and shipped — all ACs satisfied by prior work

**What changed**:
- NFR-aware test writing already fully implemented: nfr-test-check.sh, skill integration, spec-audit --nfr-test-coverage, all tests passing

**Next steps**:
- Next backlog item

**Blockers**: None


### Session: 2026-03-19 17:13 - F-0218 Implementation

**Why**: Complete NFR propagation pipeline integration

**What changed**:
- Fixed 3 integration gaps: ag implement advisory now suggests nfr-propagate.sh sync, spec_writing checklist uses tool-based NFR matching, checklist references ### NFR Constraints format

**Next steps**:
- Create PR

**Blockers**: None


### Session: 2026-03-19 17:29 - F-0218 Shipped

**Why**: NFR.md is now a living source of truth that actively propagates into feature ACs

**What changed**:
- NFR propagation pipeline complete: derive/check/sync tools, capture with concurrency guard, spec-health integration, checklist updated to tool-based workflow

**Next steps**:
- Pipeline summary skill change PR

**Blockers**: None


### Session: 2026-03-19 17:56 - Dogfood Phase 1 Drift Fixed

**Why**: Instruction files are how features reach agents — missing commands mean agents don't know about capabilities

**What changed**:
- Resolved 18 missing command references across 6 instruction files. ag test made project-agnostic across all templates. Added contributions for autonomous pipeline, pipeline summary, dogfood drift investigation.

**Next steps**:
- Next backlog item (F-0219)

**Blockers**: None


### Session: 2026-03-19 17:59 - F-0219 Verification

**Why**: Complete NFR lifecycle epic (F-0216 through F-0219)

**What changed**:
- NFR health dashboard fully implemented: per-NFR report, summary/json/coverage modes, component filtering, dashboard integration, ag nfr subcommand hub. P2 scale features (caching, priority filtering) deferred.

**Next steps**:
- Ship F-0219

**Blockers**: None


### Session: 2026-03-19 18:39 - F-0220 Structural Doc Gate

**Why**: Doc updates silently skipped in autonomous pipelines — advisory gates had no teeth

**What changed**:
- Deterministic freshness check in docs.sh, Gate 4 in ag done done_failures, pre-commit Check 19 blocking, skill updates

**Next steps**:
- PR review, merge

**Blockers**: None


### Session: 2026-03-19 19:19 - PR #168 Merged

**Why**: Doc enforcement + sync safety

**What changed**:
- Structural doc freshness gate (F-0220) + fix check-environment.sh PROJECT_ROOT bug that caused ag sync to overwrite root files

**Next steps**:
- Clean up stale branches

**Blockers**: None


### Session: 2026-03-19 20:54 - F-0221 ag.sh Decomposition

**Why**: 4325-line monolith needs decomposition into sourced modules for maintainability

**What changed**:
- Plan approved after dialectical review; starting implementation

**Next steps**:
- Phase 1: extract lifecycle modules

**Blockers**: None


### Session: 2026-03-19 21:05 - F-0221 Phase 1

**Why**: ag.sh decomposition for maintainability

**What changed**:
- Extracted 5 lifecycle modules (start, plan, implement, commit, done) to commands/; tests 21/24 pass (3 pre-existing failures)

**Next steps**:
- Phase 2: extract kickoff, auto, specs

**Blockers**: None


### Session: 2026-03-19 21:15 - F-0221 Phase 4

**Why**: Complete ag.sh decomposition testing

**What changed**:
- Created test_ag_decomposition.sh (8 tests), updated validate_framework.sh (grep_ag helper), added LLM-084

**Next steps**:
- PR creation

**Blockers**: None


### Session: 2026-03-19 21:27 - F-0221 shipped

**Why**: Maintainability improvement for framework CLI gateway

**What changed**:
- ag.sh decomposed: 4325→363 lines, 12 sourced modules, PR #169 merged

**Next steps**:
- Next backlog item

**Blockers**: None


### Session: 2026-03-19 21:31 - F-0221 doc updates

**Why**: Docs must reflect ag.sh structural change

**What changed**:
- Updated HOW_IT_WORKS, INSTRUCTION_ARCHITECTURE, FRAMEWORK_WORKFLOW, CHANGELOG with decomposition details

**Next steps**:
- TBD

**Blockers**: None


### Session: 2026-03-20 06:05 - F-0221: Defense-in-depth for autonomous workflow

**Why**: Session d7d00d88 lost 68 min to 3 autonomous_formal violations — single advisory hook was consistently ignored

**What changed**:
- 4-layer enforcement stack prevents agents from coding with unapproved plans: ExitPlanMode (profile-aware), UserPromptSubmit (DRAFT detection), PostToolUse Write|Edit|MultiEdit (code-edit warning), Pre-commit Check 21 (blocking). Added 2 LLM tests + 6-case deterministic hook test.

**Next steps**:
- Merge PR, run ag done, update instruction files (memory-seed, CLAUDE.md template)

**Blockers**: None


### Session: 2026-03-20 06:11 - F-0221: Review fixes

**Why**: Code review found production bugs that would silently break hooks

**What changed**:
- Fixed 3 bugs from code review: grep pipefail crash in UserPromptSubmit, macOS grep -oP portability in on-code-edit, empty file_path fallthrough. Added CHANGELOG entry.

**Next steps**:
- Merge PR



### Session: 2026-03-20 06:36 - F-0237+F-0238: Memory-seed optimization + session analysis tool

**Why**: Memory-seed exceeded 100-line ceiling (L-0002); manual session analysis took 30+ min

**What changed**:
- Memory-seed compressed from 319→134 lines (58% reduction) while preserving all 58 sentinels and passing validation. Session analysis tool (session-analyze.py) parses Claude JSONL logs and detects workflow violations — tested against real d7d00d88 transcript.

**Next steps**:
- Merge PR, run LLM regression tests for memory-seed

**Blockers**: None


### Session: 2026-03-20 07:02 - F-0237+F-0238: Review fixes

**Why**: Code review found bugs and ID mismatch

**What changed**:
- Fixed review items: duplicate trigger row, overly broad test allowlist, unused import, fragile APPROVED detection, wrong feature IDs in STATUS/JOURNAL

**Next steps**:
- Merge PR

**Blockers**: None


### Session: 2026-03-20 07:41 - F-0237+F-0238: Instruction file updates

**Why**: Review found missing instruction file updates — framework rule: instruction files are part of the feature

**What changed**:
- Added ag analyze-session to all 6 instruction files (CLAUDE.md template, root CLAUDE.md, cursorrules, copilot, codex), trigger tables (cursorrules, copilot, codex, auto_orchestration), help.sh, memory-seed, and CHANGELOG

**Next steps**:
- Merge PR

**Blockers**: None


### Session: 2026-03-20 07:46 - F-0221+F-0237+F-0238: Project documentation updates

**Why**: Project docs must reflect shipped features — instruction files are not the same as documentation

**What changed**:
- Updated HOW_IT_WORKS (defense-in-depth hooks mechanism, memory-seed optimization note, session-analyze in tool inventory, 3rd hidden mechanism), DEVELOPER_GUIDE (ag analyze-session subsection), FRAMEWORK_WORKFLOW (Check 21 in quality gates table)

**Next steps**:
- Merge PRs

**Blockers**: None


### Session: 2026-03-20 08:09 - F-0237 Doc Decision Tree

**Why**: Doc updates kept getting skipped because instructions were too vague — concrete file lists and decision trees are harder to skip

**What changed**:
- Replaced vague doc checks with concrete 3-concern structure (project docs, registry maintenance, instruction files) in implementing-features Step 6, before_commit.md backstop, and completing-work Step 5b. Added FRAMEWORK_WORKFLOW.md to docs registry.

**Next steps**:
- PR review and merge

**Blockers**: None


### Session: 2026-03-20 08:27 - F-0237 Spec Evolution

**Why**: Specs are living documents — changes that affect shipped features must evolve those specs via migrations

**What changed**:
- Added spec evolution as explicit step in implementation (Step 7), commit (backstop), and completion (Step 5c) workflows. Created migration 017 evolving F-0138/F-0139/F-0207 ACs. Updated all 3 shipped acceptance criteria files with new AC groups.

**Next steps**:
- Fix commit message F-0224→F-0237, push to PR

**Blockers**: None


### Session: 2026-03-20 08:40 - F-0237 Spec Evolution in All Instruction Files

**Why**: Spec evolution must be in instruction files to reach agents — same principle as doc decision tree

**What changed**:
- Added 'specs are contracts AND living documents' to all instruction files: CLAUDE.md (root+template), cursorrules (root+template), copilot, codex, auto_orchestration (Step 9), agent_operating_guidelines, memory-seed. Added spec evolution check to reviewing-code skill (dimension 8). All conditional on formal profiles.

**Next steps**:
- Commit and push to PR

**Blockers**: None


### Session: 2026-03-20 09:17 - F-0237/F-0238 Review Fixes (Round 2)

**Why**: Code review found 7 issues — must fix all before merge

**What changed**:
- Fixed all review findings: cursorrules.txt template dogfood violation (ag analyze-session), dead implement_seen variable, grouped code_before_review violations, F-0238 AC-002 missing skipped_planning, journal ID references F-0224→F-0237, unit tests for session-analyze.py (7 tests), expanded allowlist for state files.

**Next steps**:
- Push and merge

**Blockers**: None


### Session: 2026-03-20 09:44 - F-0237 CONTRIBUTIONS

**Why**: Every framework PR captures user design insights in CONTRIBUTIONS.md

**What changed**:
- Updated CONTRIBUTIONS.md with 2 user design insights from PR #171: spec evolution as structural workflow, doc decision tree design principle.

**Next steps**:
- Merge PR

**Blockers**: None


### Session: 2026-03-20 10:37 - T-0082 Doc Currency Check

**Why**: Structural backstop for the behavioral 3-concern doc decision tree

**What changed**:
- Added validate_framework.sh check: shipped features in CHANGELOG must also appear in living docs (HOW_IT_WORKS, DEVELOPER_GUIDE, FRAMEWORK_WORKFLOW, INSTRUCTION_ARCHITECTURE, OVERVIEW). Inverse check: recent shipped features (F-0200+) missing from CHANGELOG entirely. 715 pass, 3 pre-existing failures, 9 new advisory warnings for pre-existing gaps.

**Next steps**:
- Flush to main

**Blockers**: None


### Session: 2026-03-20 10:37 - T-0082 commit

**Why**: Structural backstop

**What changed**:
- Committing doc currency check to main

**Next steps**:
- Done

**Blockers**: None


### Session: 2026-03-20 13:00 - F-0239 Post-Merge Enforcement

**Why**: Behavioral rules for post-merge workflow keep getting skipped; promoting to structural enforcement

**What changed**:
- Hook-based detection for bypassed ag merge: UserPromptSubmit warns unshipped features, PostToolUse warns gh pr merge. Enforcement hierarchy codified in PRINCIPLES.md D2. FEATURES.md entry + AC file + memory-seed updated.

**Next steps**:
- PR review, merge

**Blockers**: None


### Session: 2026-03-20 13:04 - F-0239 Instruction Files

**Why**: Framework dev rule: instruction files are part of the feature

**What changed**:
- Updated 8 instruction files: INSTRUCTION_ARCHITECTURE (hook table + A11), HOW_IT_WORKS (D2 feature row), CHANGELOG, agent_operating_guidelines (gate row), cursorrules/copilot/codex (trigger tables), auto_orchestration (merge trigger)

**Next steps**:
- Merge PR

**Blockers**: None


### Session: 2026-03-20 13:10 - F-0239 Shipped

**Why**: Promoting post-merge behavioral rules to structural enforcement

**What changed**:
- PR #173 merged: structural enforcement for post-merge workflow. Two hook detections + enforcement hierarchy in PRINCIPLES.md + 8 instruction file updates + CONTRIBUTIONS entry

**Next steps**:
- Post-merge: dogfood, VERSION, flush

**Blockers**: None


### Session: 2026-03-20 13:20 - State Drift Fix

**Why**: F-0219 state was stale — shipped feature still showing as planned in FEATURES.md and current in backlog

**What changed**:
- Marked F-0219 shipped (was still planned despite PR #167 merged), advanced backlog to F-0223, cleaned STATUS.md conflict markers

**Next steps**:
- F-0223 planning

**Blockers**: None


### Session: 2026-03-20 13:54 - F-0241: Central QA Registry

**Why**: Test coverage was fragmented across 12+ categories with no central visibility into what's tested and what gaps exist

**What changed**:
- Framework now has a generated QA map (docs/QA_REGISTRY.md) showing 207 features, 95 with test mappings, and 112 coverage gaps across 9 test categories. ag qa command provides on-demand generation and staleness checks.

**Next steps**:
- Implement F-0240 (Framework Execution Log) as foundation for simulation testing

**Blockers**: None


### Session: 2026-03-20 14:28 - F-0241 Shipped

**Why**: Shipped first QA Observatory feature

**What changed**:
- Central QA Registry now available via ag qa — 207 features mapped across 9 test categories, 95 with test mappings, 112 gaps identified

**Next steps**:
- Next: F-0240 (Framework Execution Log)

**Blockers**: None


### Session: 2026-03-20 16:12 - F-0240 Framework Execution Log

**Why**: Post-hoc debugging for framework failures; foundation for F-0242/DEV-0243

**What changed**:
- Structured append-only log at .agentic/session/framework.log — fwlog.sh + ag.sh/pre-commit/hooks instrumentation, 14 tests, all ACs pass

**Next steps**:
- PR review, then ag done F-0240

**Blockers**: None


### Session: 2026-03-20 17:38 - v2 Workflow Engine — Phase 1 Complete

**Why**: Framework had 554 files of instructions agents were supposed to remember. Shifting to structural enforcement where CLI refuses to proceed without artifacts.

**What changed**:
- Built state-machine-driven workflow engine (TransitionOrchestrator) that enforces artifact preconditions at transition time. 10 states, 14 transitions, 2 modes, 3 profiles. Per-work-item dirs in .agentic/work/F-XXXX/. 7 role prompts loaded JIT. ag.sh routes to v2 when engine: v2. 46+ tests, review fixes applied.

**Next steps**:
- Phase 2: Rearchitect auto system (engine.py, epic.py, critical_agent.py, kickoff.py, plan_convergence.py, review.py, scheduler.py) onto TransitionOrchestrator. Then Phase 3: consolidate 554 files to ~80. Phase 4: tool adapters + MCP.

**Blockers**: PR #177 on feat/v2-workflow-engine needs merge before Phase 2 starts


### Session: 2026-03-20 18:18 - v2 Phase 2A

**Why**: Phase 2 of v2 refactor: auto system must use TransitionOrchestrator as backbone

**What changed**:
- FEATURES.md sync shim + gate dispatch wired into TransitionOrchestrator. 82/82 tests pass.

**Next steps**:
- Phase 2B: state consumers (state_machine.py, gates.py, review.py adapters)

**Blockers**: None


### Session: 2026-03-20 18:34 - v2 Phase 2B

**Why**: State consumers must read from v2 work items for unified state management

**What changed**:
- Fixed gate_dispatch API calls (CriticalAgent, ConvergenceLoop). Added v2 adapter to FeatureStateMachine — delegates to TransitionOrchestrator when engine: v2. 163 tests pass.

**Next steps**:
- Phase 2C: execution layer integration (engine.py, task.py, scheduler.py)

**Blockers**: None


### Session: 2026-03-20 18:45 - v2 Phase 2C

**Why**: Execution layer must populate v2 work items and artifacts for unified state management

**What changed**:
- Execution layer v2 integration: verify.py writes verification.json artifact, scheduler ensures work items exist and advances v2 state after completion, task.py wires verification artifact. 163 tests pass.

**Next steps**:
- Phase 2D: feature management (epic.py, kickoff.py)

**Blockers**: None


### Session: 2026-03-20 18:58 - v2 Phase 2D

**Why**: Feature management layer must populate v2 work items for unified state tracking across epics

**What changed**:
- Epic decomposition and kickoff promotion now create v2 work items with parent links. 163 tests pass. Phase 2 complete.

**Next steps**:
- Phase 3: instruction consolidation + file reduction

**Blockers**: None


### Session: 2026-03-20 20:04 - Phase 3A+3B

**Why**: Phase 3 instruction consolidation — removing redundant files replaced by v2 CLI enforcement

**What changed**:
- v2 mode added to validate_framework.sh (703/3/17); enriched 7 role prompts (209→347 lines); created conventions.md (78 lines)

**Next steps**:
- Phase 3C: simplify skills + templates + tool scripts

**Blockers**: None


### Session: 2026-03-20 20:24 - Phase 3C

**Why**: Phase 3C: skills + templates simplified for v2 CLI enforcement

**What changed**:
- Simplified 25 skill stubs (Tier 1/2), updated 4 templates + 3 root wrappers, fixed 35 v2 validation guards

**Next steps**:
- Phase 3D: delete archived files in 4 batches

**Blockers**: None


### Session: 2026-03-20 21:03 - Phase 3 Complete

**Why**: Phase 3 instruction consolidation removes ~130 files of redundant instructions now enforced by v2 CLI

**What changed**:
- All 5 sub-phases done: 3A (validate_framework v2 mode), 3B (enriched prompts + conventions.md), 3C (skill stubs + template updates), 3D (4 deletion batches: ~25.6K lines removed), 3E (migration guide + docs)

**Next steps**:
- Create PR for Phase 3

**Blockers**: None


### Session: 2026-03-20 21:56 - Phase 3 Post-Merge

**Why**: Documenting the architectural insight that LLMs are probabilistic and can't be made deterministic via instructions alone

**What changed**:
- Added CONTRIBUTIONS entry (v2 structural enforcement over behavioral instructions, Phases 1-4) and KEY_INSIGHTS #17 (CLI state machines as endgame for workflow enforcement)

**Next steps**:
- Phase 4 or QA Observatory

**Blockers**: None


### Session: 2026-03-21 06:07 - Phase 4: Tool Adapters & MCP

**Why**: Make the framework universally accessible to any AI coding tool

**What changed**:
- ag export generates tool-specific instruction files from shared sections; ag check --quick enables <500ms hook enforcement; MCP server wraps 5 tools over stdio JSON-RPC

**Next steps**:
- PR review, merge, ag done

**Blockers**: None


### Session: 2026-03-21 06:47 - Phase 4 hook enforcement

**Why**: Phase 4 plan specified PostToolUse/PreToolUse hook wiring but only UserPromptSubmit was shipped

**What changed**:
- Added PreToolUse (blocking) + PostToolUse (advisory) ag check enforcement; fixed stale docs claiming no PreToolUse support

**Next steps**:
- Commit and PR

**Blockers**: None


### Session: 2026-03-21 07:19 - Phase 4 hook enforcement merged

**Why**: Phase 4 plan specified hook wiring but only UserPromptSubmit was shipped; PreToolUse support was incorrectly believed to not exist

**What changed**:
- PreToolUse blocking enforcement + PostToolUse advisory ag check shipped; stale PreToolUse docs fixed across 6 files; review findings addressed (allowlist, bootstrap, injection)

**Next steps**:
- F-0240 Framework Execution Log

**Blockers**: None


### Session: 2026-03-21 08:23 - Hooks-First Framework (F-0244)

**Why**: v2 engine duplicated what platform hooks now provide natively — 90% of complexity was compensating for LLM unreliability that hooks solve at the platform level

**What changed**:
- All 5 phases implemented: gate.py policy engine, Stop+PreToolUse enforcement hooks, context hooks v2 removal, v2 engine stripped from 5 auto system files, Cursor cross-tool adapters. 45 new tests, 126 total pass.

**Next steps**:
- Create PR, self-review, dogfood sync

**Blockers**: None


### Session: 2026-03-21 12:55 - F-0244 Shipped

**Why**: Post-merge completion workflow

**What changed**:
- Hooks-first framework simplification merged (PR #185). 5 child features shipped: Stop gate, PreToolUse enforcement, context hooks, v2 engine stripped, Cursor adapters.

**Next steps**:
- Dogfood sync, physical v2/ deletion follow-up

**Blockers**: None


### Session: 2026-03-21 13:35 - Pipeline --vision flag

**Why**: Pipeline required pre-structured JSON — the first step of the autonomous chain was manual

**What changed**:
- Added vision_to_features() and run_pipeline_from_vision() to pipeline.py; ag auto pipeline now accepts --vision for end-to-end autonomous flow from freeform text

**Next steps**:
- PR review, tests

**Blockers**: None


### Session: 2026-03-21 13:45 - PR #186 merged — pipeline --vision

**Why**: Post-merge dance for pipeline vision flag

**What changed**:
- ag auto pipeline now accepts --vision for end-to-end autonomous flow; fence stripping and feature validation hardened per review

**Next steps**:
- Dogfood sync, VERSION bump

**Blockers**: None


### Session: 2026-03-21 13:54 - Completing-work skill fix

**Why**: Agent ignored post-merge dance because skill had no merge-specific guidance

**What changed**:
- Added merge guidance and post-merge steps to skill — use ag merge not gh pr merge, fallback steps if already merged

**Next steps**:
- None

**Blockers**: None


### Session: 2026-03-21 15:01 - PR #187 merged — completing-work skill fix

**Why**: Post-merge dance for completing-work skill fix

**What changed**:
- Skill now guides post-merge workflow: ag merge, spec/backlog/journal steps, git tag, framework-dev sync

**Next steps**:
- None

**Blockers**: None


### Session: 2026-03-21 16:41 - Git-Deferred Mode + Spec Enforcement

**Why**: Algebra-rush case study: agent bypassed state machine and git entirely in autonomous_formal — framework needs git-optional mode and spec lifecycle enforcement

**What changed**:
- F-0250: git_mode (none|deferred|active) setting, ag git-init command, stack-aware .gitignore, gated git-dependent commands. F-0251: PreToolUse blocks source code edits when all features are planned in formal modes (8 tests).

**Next steps**:
- Review, ship both features, update instruction files checklist

**Blockers**: None


### Session: 2026-03-21 17:45 - F-0250 + F-0251 shipped

**Why**: PR #188 merged — algebra-rush onboarding analysis led to two features shipping

**What changed**:
- Git-deferred mode (3 modes, ag git-init, stack-aware .gitignore, command gating, dashboard) and formal spec lifecycle enforcement (PreToolUse blocks code when all features planned, defense-in-depth mirrors of 3 pre-commit checks). 62 gate tests pass.

**Next steps**:
- Dogfood sync, instruction file checklist, next backlog item

**Blockers**: None


### Session: 2026-03-21 21:29 - F-0300 Enforcement Gaps

**Why**: Street Fury test project exposed that enforcement collapses when git is deferred

**What changed**:
- 7 structural enforcement fixes: hook install in auto init, deferred-git gates, batch-work triggers across all instruction files, ag auto unlocked for deferred git, verification gate in state machine, spawned agent enforcement rules

**Next steps**:
- PR review, merge, ag done

**Blockers**: None


### Session: 2026-03-22 07:26 - F-0300 shipped

**Why**: Street Fury evaluation exposed that enforcement collapses in deferred-git mode

**What changed**:
- 7 enforcement gaps fixed: hook install in auto init, deferred-git pre-write gate, batch-work triggers in all instruction files, ag auto unlocked for deferred git, verification gate in state machine, spawned agent enforcement rules

**Next steps**:
- Next backlog item (F-0242)

**Blockers**: None


### Session: 2026-03-22 09:04 - Scaffold-first hooks

**Why**: Hooks were already pre-installed by scaffold but init playbook redundantly reinstalled them with misleading restart warnings

**What changed**:
- Eliminated 9 Claude hook wrappers — hooks.json points directly to lib/. Fixed false restart advisories in setup-agent, ag hooks install, ag auto init. Rewrote init_playbook Step 1a (verify/prune) and Step 2 (AskUserQuestion interview).

**Next steps**:
- PR review, merge

**Blockers**: None


### Session: 2026-03-22 09:25 - Scaffold-first hooks shipped

**Why**: Hooks were pre-installed by scaffold but init redundantly reinstalled with misleading restart warnings

**What changed**:
- Eliminated 9 Claude hook wrappers, hooks.json points to lib/ directly. Fixed false restart advisories. Init playbook now verify/prune + dynamic AskUserQuestion interview.

**Next steps**:
- Next backlog item

**Blockers**: None


### Session: 2026-03-22 09:40 - F-0301 NHL Enforcement Analysis

**Why**: Test project exposed that fail-open error handling in hook chain silently defeated state_enforcement=blocking

**What changed**:
- Analyzed NHL hockey game test incident — complete framework bypass under blocking enforcement. Documented 3 fail-open paths (PreToolUse exit code handling, regex gaps, missing no-WIP check). Code fixes shipped in #190. Added anti-rationalization callouts, expanded trigger words, timeout bump, lessons learned across 4 docs, incident analysis + plan artifacts.

**Next steps**:
- PR review and merge

**Blockers**: None


### Session: 2026-03-22 10:08 - Feature status audit

**Why**: 8 features had merged code but stale planned status — agents skipping ag done after direct-to-main commits

**What changed**:
- Fixed 3 stale features: F-0240+F-0242 marked shipped, F-0194 confirmed still planned (dead worktree code). Created F-0301 completion gate to structurally prevent ag done being skipped.

**Next steps**:
- Plan and implement F-0301

**Blockers**: None


### Session: 2026-03-22 10:22 - F-0301 Completion Gate

**Why**: Agents skipping ag done after direct-to-main commits left 3+ features with stale planned status

**What changed**:
- Implemented completion gate: ag implement blocks when prior backlog item has merged code but isn't shipped. Dashboard + ag start show advisory warnings. 11 tests pass.

**Next steps**:
- Merge PR, ag done F-0301

**Blockers**: None


### Session: 2026-03-22 10:29 - F-0301 shipped

**Why**: Post-merge completion ceremony

**What changed**:
- Merged PR #192, marked shipped, removed from backlog

**Next steps**:
- Next backlog item: DEV-0243

**Blockers**: None


### Session: 2026-03-22 12:40 - F-0302 Phase 1: Contract Infrastructure

**Why**: Spec system has 217 features describing history not state; ACs are markdown checklists checked once and forgotten; shipped behavior can silently disappear during refactoring

**What changed**:
- Built YAML contract system — schema, parser (contracts.py), ag contract command (12 subcommands), verify-contracts.sh runner, pre-commit protection (Check 23), paths integration, 42 unit tests, 7 validate_framework checks. All passing.

**Next steps**:
- Phase 0: Consolidate 217→~30-40 features. Phase 2: Write contracts for each. Phase 3: Switchover all ag commands to contracts.

**Blockers**: None


### Session: 2026-03-22 12:43 - F-0302 Phase 1 commit 2

**Why**: Splitting Phase 1 into reviewable commits

**What changed**:
- ag contract command (12 subcommands), verify-contracts.sh, pre-commit Check 23, 42 unit tests, 7 validate_framework assertions

**Next steps**:
- Create PR, continue Phase 0 triage in next session

**Blockers**: None


### Session: 2026-03-22 12:43 - F-0302 state update

**Why**: Ensuring agents see F-0302 as high-priority multi-session work

**What changed**:
- Renamed F-0302 to clarify scope: full spec system refactoring. Updated STATUS.md, BACKLOG.json, plan files.

**Next steps**:
- PR creation, then continue Phase 0 in next session

**Blockers**: None


### Session: 2026-03-22 12:53 - F-0302 Phase 0+2: Consolidation & contracts

**Why**: Writing contracts for all consolidated features

**What changed**:
- Consolidated 217 features → 33 contracts + 3 NFR contracts (36 total). All validate OK, 97 structural assertions pass. CONSOLIDATION_MAP.md maps old→new.

**Next steps**:
- Phase 3: switchover (update ag commands, engine, paths to use contracts)

**Blockers**: None


### Session: 2026-03-22 12:54 - F-0302 contracts batch 2

**Why**: Completing contract writing phase

**What changed**:
- Writing remaining feature + NFR contracts (F-0041 through F-0245, NFR-0001 through NFR-0004)

**Next steps**:
- Batch 3 commit, then Phase 3 switchover

**Blockers**: None


### Session: 2026-03-22 12:55 - F-0302 contracts batch 3a

**Why**: Contract writing phase

**What changed**:
- Advanced feature contracts: F-0101 through F-0181

**Next steps**:
- Batch 3b: remaining contracts + NFRs

**Blockers**: None


### Session: 2026-03-22 12:55 - F-0302 contracts batch 3b

**Why**: Completing all contract writing

**What changed**:
- Final contracts: F-0184 through NFR-0004. All 36 contracts written and validated.

**Next steps**:
- Push PR, continue Phase 3 switchover

**Blockers**: None


### Session: 2026-03-22 13:17 - F-0302 security fixes

**Why**: Code review found shell injection via single-quote in inline Python

**What changed**:
- Fixed shell injection in contract.sh: all user input passed via env vars, feature ID validation added. Fixed perf: 3→1 python calls per contract in check-all loop. Fixed FEATURES.md entry.

**Next steps**:
- Push, merge

**Blockers**: None


### Session: 2026-03-22 13:18 - F-0302 PR merged

**Why**: Post-merge completion

**What changed**:
- PR #193 merged to main — 51 files, 4310 lines. Phases 0-2 complete. CONTRIBUTIONS.md updated with user design insights.

**Next steps**:
- VERSION bump, then continue Phase 3 switchover in next session

**Blockers**: None


### Session: 2026-03-22 13:20 - VERSION bump

**Why**: Post-merge version bump

**What changed**:
- 0.72.0 for F-0302 Phases 0-2

**Next steps**:
- Phase 3

**Blockers**: None


### Session: 2026-03-22 20:58 - F-0302 Phase 3: The Switchover

**Why**: YAML contracts are now the primary spec system — single atomic switchover

**What changed**:
- Archived 208 AC files, rewrote FEATURES.md (217→33 entries), updated state machine to read contracts, updated all ag commands/scripts/Python modules/tests/instruction files

**Next steps**:
- Phase 4: Protection & Cleanup

**Blockers**: None


### Session: 2026-03-22 21:29 - F-0302 review fixes

**What changed**:
- Narrowed exception handling, fixed _build_child_contract schema, removed redundant sys.path.insert

**Next steps**:
- PR review

**Blockers**: None


### Session: 2026-03-22 21:32 - F-0302 review fixes round 2

**What changed**:
- Fixed inline Python in done.sh (heredoc with argv), added 4 tests for _build_child_contract, updated 2 epic tests for contracts

**Next steps**:
- PR merge

**Blockers**: None


### Session: 2026-03-22 21:39 - F-0302 Phase 3 shipped

**Why**: Spec system overhaul — contracts replace markdown ACs as source of truth

**What changed**:
- YAML contracts are now the primary spec system — 217 features consolidated to 33, all commands/scripts/tests updated, PR #195 merged

**Next steps**:
- Phase 4: Protection & Cleanup

**Blockers**: None


### Session: 2026-03-22 21:40 - F-0302 shipped — v0.73.0

**Why**: Post-merge completion

**What changed**:
- VERSION bump, contract lifecycle shipped, backlog advanced to DEV-0243

**Next steps**:
- Phase 4 or next backlog item

**Blockers**: None


### Session: 2026-03-23 07:21 - F-0302 Phase 4 Step 4.2

**Why**: Pending user_input on contracts had no agent-facing surface — agents couldn't discover or process change requests

**What changed**:
- User input automation wired into dashboard, ag start, ag implement, pre-commit exemption, new handling-contract-input skill, trigger words in 7 instruction files

**Next steps**:
- Verification testing, ship Phase 4

**Blockers**: None


### Session: 2026-03-23 08:14 - F-0302 review fixes

**Why**: Code review on PR #196 identified injection risk, inconsistency, and missing coverage

**What changed**:
- Fixed 5 code review issues: shell injection via env var, removed spurious 2>/dev/null, replaced chr(10) with splitlines(), added empty-features guard, added trigger word to Claude template

**Next steps**:
- Merge PR

**Blockers**: None


### Session: 2026-03-23 13:07 - F-0303 Phase Tracking

**Why**: Plans with multiple phases had no trackable work structure — ag done shipped features with incomplete phases

**What changed**:
- Multi-session plan phase tracking: phases.py core, ag phase CLI, workflow integrations (done/implement/dashboard/sync gates), instruction file updates, no-feature-inflation rule

**Next steps**:
- PR review, ship F-0303

**Blockers**: None


### Session: 2026-03-23 14:41 - F-0302 Phase 4: V2 Dead Code Cleanup

**Why**: v2 engine was a wrapper around the state machine that was removed in earlier phases — this cleans up all remaining dead code references

**What changed**:
- Removed v2 wrapper engine (14 files, ~3217 lines), 3 dead test files, V2_ENGINE variable + ~70 dead conditional blocks from validate_framework.sh, cleaned setup-agent.sh/upgrade.sh/ag.sh stubs, wired ag verify to verify-contracts.sh

**Next steps**:
- Merge PR, ag phase done F-0302 4, begin Phase 5

**Blockers**: None


### Session: 2026-03-23 15:33 - F-0302 Phase 5

**Why**: New projects need contract-first scaffolding; existing projects need migration path from markdown ACs

**What changed**:
- User project support: contract templates for scaffold, ag migrate-specs command, documentation updates across 20 files

**Next steps**:
- Phase 6 or mark F-0302 done

**Blockers**: None


### Session: 2026-03-23 16:10 - F-0302 Complete

**Why**: F-0302 shipped after PR #199 merge

**What changed**:
- Spec System Overhaul shipped — all 6 phases done. YAML contracts are the primary spec format. New projects scaffold with contracts, existing projects can migrate via ag migrate-specs.

**Next steps**:
- ag backlog done, next feature

**Blockers**: None


### Session: 2026-03-23 16:51 - Backlog cleanup

**Why**: Post-consolidation backlog had 14 orphaned F-XXXX IDs not in FEATURES.md — agents would be blocked by ag implement

**What changed**:
- Dropped F-0213, converted 4 items to tasks, added 9 planned features to FEATURES.md, reordered backlog with F-0193 current, fixed depends_on display bug

**Next steps**:
- F-0193 implementation

**Blockers**: None



### Session: 2026-03-23 18:58 - F-0193 Centralized IDs

**Why**: AC-003/AC-004 required all files use centralized imports — 10+ files still had inline patterns after prior refactoring wave

**What changed**:
- Replaced all inline feature ID patterns (14 Python, 4 shell) with centralized imports from ids.py/ids.sh. Zero remaining inline patterns outside source modules.

**Next steps**:
- Ship F-0193: advance lifecycle states

**Blockers**: None


### Session: 2026-03-23 20:00 - Fix Hook Automation Gaps + Instruction File Drift

**Why**: Hooks exited 0 and agents ignored advisory warnings; templates and root files had significant drift after F-0193

**What changed**:
- gate_stop() now blocks on DRAFT plans, unshipped merges, and unpushed feature branches without PRs; on-plan-mode-exit.sh injects Status: DRAFT mechanically; on-bash-merge-detect.sh shows structured REQUIRED NEXT ACTION block; SKILL.md warns agents to use ag implement CLI; 5 instruction files synced with missing trigger rows and rules

**Next steps**:
- Review and commit

**Blockers**: None


### Session: 2026-03-23 20:36 - Fix Hook Automation Gaps + Instruction File Drift

**Why**: Hooks exited 0 (advisory only) so agents could ignore them; templates had significant drift after F-0193

**What changed**:
- gate_stop() now blocks on DRAFT plans, unshipped merges, and unpushed feature branches; on-plan-mode-exit.sh mechanically injects Status: DRAFT; on-bash-merge-detect.sh shows structured REQUIRED NEXT ACTION block; SKILL.md warns agents to use ag implement CLI; 5 instruction files synced; root CLAUDE.md path bug fixed (work/ → journal/plans/)

**Next steps**:
- Review + commit

**Blockers**: None


### Session: 2026-03-24 06:09 - F-0193 shipped

**Why**: IDs were hardcoded in 100+ locations across 50 files; centralization future-proofs ID format changes

**What changed**:
- Centralized feature ID patterns into ids.py + ids.sh; widened F-\d{4} to F-\d{4,} across all Python and shell files; removed 4-digit ceiling

**Next steps**:
- Start DEV-0243 Complexity Tier Experiments

**Blockers**: None


### Session: 2026-03-24 06:45 - DEV-0243 Complexity Tier Experiments

**Why**: Provide empirical evidence for which framework profile produces best outcomes

**What changed**:
- Implemented empirical tier comparison harness: tier_experiment.py module with TierMetrics, collect_metrics, ExperimentResult; complexity_tiers.yaml experiment config with discovery/formal/autonomous_formal tiers; ag auto tier-experiment command; test_tier_experiment.py unit tests; LLM test 096; validate_framework.sh gates

**Next steps**:
- Commit and ship DEV-0243

**Blockers**: None


### Session: 2026-03-24 08:00 - DEV-0243 + DEV-0001 taxonomy

**Why**: DEV-0243 implements empirical tier comparison harness. DEV-0001 reorganizes internal tooling to be visually distinct from user-facing capabilities

**What changed**:
- DEV-0243 Complexity Tier Experiments shipped (tier_experiment.py, complexity_tiers.yaml, LLM test, 35 unit tests). DEV-0001 Framework Development Infrastructure taxonomy created: DEV-XXXX namespace, parent container, Type annotations on DEV-0122/DEV-0199/DEV-0243, lifecycle:ongoing for meta items, contract schema updated

**Next steps**:
- Ship and push

**Blockers**: none


### Session: 2026-03-24 08:16 - Review fixes — tier_experiment.py + DEV-0001

**Why**: Code review identified correctness and UX issues before running experiments

**What changed**:
- Fixed 6 review issues: removed dead pre-flight branch check, app_runs probes entrypoint with --help instead of proxying pip install, spec_created uses mtime > run_start_time to exclude scaffolded files, column width computed dynamically, DEV-0001 contract adds protection: advisory

**Next steps**:
- Push to PR

**Blockers**: none


### Session: 2026-03-24 19:39 - PR #202 review fixes

**Why**: PR review found critical blocker: ag workflow rejected DEV- IDs

**What changed**:
- Fixed 8 review issues: DEV-XXXX ID support in ids.py/ids.sh/contracts.py, tier_experiment cleanup (unused import, dead vars, venv isolation, spec snapshot, per-tier counts), migration 018 restored

**Next steps**:
- Push to PR, merge

**Blockers**: None


### Session: 2026-03-24 20:41 - F-0184 Phase 1a: Hierarchical ID System

**Why**: Enable feature hierarchy and clean renumber — foundational schema change

**What changed**:
- Schema + core code for dotted feature IDs (F-003.1), component metadata, shell audit of hardcoded patterns, 60 tests

**Next steps**:
- Phase 1b: epic.py decomposition with dotted IDs, new ag commands

**Blockers**: None


### Session: 2026-03-24 21:57 - F-0184 Phase 1b

**Why**: Enable hierarchical feature decomposition with dotted child IDs

**What changed**:
- Dotted ID allocation in decompose, extract_subfeature(), depth guards, component field (replaces tags), --recursive contract check, --parent contract create, 70 tests passing

**Next steps**:
- Phase 2: renumber script + mapping

**Blockers**: None


### Session: 2026-03-25 07:23 - F-0184 review fixes

**Why**: Address code review findings

**What changed**:
- Dead code removal, state guards, O(n) recursive check, env var security, criteria_set allowed

**Next steps**:
- Push PR

**Blockers**: None


### Session: 2026-03-25 13:40 - F-0184 Phase 2: Clean Renumber

**Why**: Feature IDs were chronological and hard to navigate — sequential grouping by category makes the feature registry human-friendly

**What changed**:
- Renumbered 36 F-/DEV- features from 4-digit to 3-digit sequential IDs grouped by category. Built renumber.py script with YAML-aware processing. Zero new test failures.

**Next steps**:
- Phase 2c: add migration entries to protected contracts

**Blockers**: None


### Session: 2026-03-25 17:07 - F-005 shipped

**Why**: Ship F-005 after all phases (decomposition + dotted IDs + renumber) completed

**What changed**:
- Feature Hierarchy & Decomposition complete: epic decomposition, dotted IDs, 3-digit renumbering

**Next steps**:
- Next backlog item

**Blockers**: None


### Session: 2026-03-26 16:53 - State file triage

**Why**: Post-refactor housekeeping: tracking files accumulated stale entries after F-005 + F-031 shipped

**What changed**:
- Cleared 31 merged-PR entries from HUMAN_NEEDED, closed 6 TODOs, reorganized TODO with open/closed separation, reordered backlog with T-0093 promoted to position 2

**Next steps**:
- Continue with backlog item 0 (state machine gates)

**Blockers**: None


### Session: 2026-03-26 21:47 - ExitPlanMode hook JSONL analysis

**Why**: ExitPlanMode hook was assumed VALIDATED (A11) but JSONL proves it never fired — all plan-review enforcement may rest on textual instructions alone, contradicting the documented principle that textual instructions are unreliable for cross-turn workflows

**What changed**:
- Proved via JSONL (session f85780c3) that PostToolUse:ExitPlanMode hook never fired — zero progress entries while other PostToolUse hooks (Write,Grep,Read) fired normally. Updated INSTRUCTION_ARCHITECTURE.md A11 from VALIDATED to INVALIDATED. Updated FRAMEWORK_DEVELOPMENT.md plan-review case study with 3 remaining gaps: (1) explore-before-review, (2) ExitPlanMode hook inert, (3) no review-evidence check in implement gate. Correct agent behavior in this session came from CLAUDE.md + memory text, NOT from the hook.

**Next steps**:
- Investigate whether Claude Code emits PostToolUse for built-in tools; if not, redesign enforcement to rely on pull mechanisms (ag implement gate, SessionStart orphan detection) and consider adding review-evidence check to gate 0d

**Blockers**: Need platform confirmation on built-in tool hook behavior


### Session: 2026-03-26 22:05 - Gates 6-8 strengthened

**Why**: Later state machine gates were advisory-only — agents could skip documentation, commit, and ship checks entirely

**What changed**:
- Gate 6: CHANGELOG blocks in docs_gate=blocking, journal freshness advisory, early-return bug fixed. Gate 7: blocks dirty tree + missing feature commits. Gate 8: blocks no merged PR (pull_request mode) or unpushed commits (direct), graceful gh degradation. state_machine.py auto-resolves enforce from settings.

**Next steps**:
- Merge PR, ag done, advance backlog

**Blockers**: None


### Session: 2026-03-26 22:18 - Gates 6-8 shipped

**Why**: Later gates were advisory-only, agents could skip documentation, commit, and ship checks

**What changed**:
- State machine gates 6-8 strengthened from advisory to blocking — CHANGELOG/drift blocks, dirty-tree/missing-commit blocks, merged-PR/unpushed-commit blocks. PR #206 squash-merged.

**Next steps**:
- F-035 Protected Main Branch Support (next backlog item)

**Blockers**: None


### Session: 2026-03-27 18:16 - F-035 Protected Main Branch Support

**Why**: Organizations with GitHub branch protection cannot push directly to main — ag flush needs a PR-based alternative

**What changed**:
- Implemented dual-path ag flush: direct mode (unchanged) vs protected mode (ephemeral branch + PR via gh). Added --auto-flush guard, done.sh reordering, stale branch cleanup, error recovery, settings/validation, instruction file updates, 12 structural tests.

**Next steps**:
- PR review, merge, VERSION bump via ag done

**Blockers**: None


### Session: 2026-03-27 18:45 - F-035 shipped

**Why**: Organizations with branch protection can now use ag flush without direct push access

**What changed**:
- Protected main branch support merged (PR #207). ag flush now creates ephemeral branch + PR when main_branch_mode: protected.

**Next steps**:
- Post-merge: VERSION bump, dogfood sync, flush state

**Blockers**: None


### Session: 2026-03-27 19:28 - VERSION file sync fix

**Why**: VERSION files drifted apart on every ag done cycle in framework-dev mode

**What changed**:
- Fixed split where done.sh bumps ./VERSION but dashboard reads .agentic/lib/VERSION. Added framework-dev-only sync, allowlist entry, and structural tests.

**Next steps**:
- Merge fix

**Blockers**: None


### Session: 2026-03-27 20:01 - Doc freshness gate scoping fix

**Why**: ag done was flagging ALL feature_done docs as stale regardless of feature relevance, forcing fake reviewed markers

**What changed**:
- check_freshness() now accepts manifest ID and scopes to docs whose tracked paths overlap feature's changed files; parse_registry supports optional tracks field; done.sh passes manifest to freshness check; STACK.md entries annotated with tracks

**Next steps**:
- Merge PR, ag done, advance backlog

**Blockers**: None


### Session: 2026-03-28 08:13 - E2E lifecycle test

**Why**: No integrated test existed for the full ag CLI lifecycle — regression risk on framework changes

**What changed**:
- S12_e2e_lifecycle.sh: 23 assertions covering scaffold→implement→commit→done lifecycle; added AC-004 to DEV-002 contract

**Next steps**:
- Mark backlog task done, commit

**Blockers**: None


### Session: 2026-03-28 14:50 - F-036 Workflow Definition File

**Why**: state_machine_af.yaml was dead config — no code read it. Now it's loadable, testable, and validated

**What changed**:
- YAML loader (workflow.py) with typed dataclasses for modes/profiles/artifacts/verification/docs_policy; consistency validation between YAML transitions and Python tables; state_machine.py integration with graceful degradation; 77 tests passing; validate_framework.sh F-036 checks

**Next steps**:
- Create contract/spec for F-036, create PR, ship

**Blockers**: None


### Session: 2026-03-28 18:26 - F-036 shipped

**Why**: Transformed dead config into validated source of truth for modes, profiles, artifacts

**What changed**:
- Workflow definition YAML loader and consistency validation merged. state_machine_af.yaml now loadable as typed Python objects with CI-enforced consistency.

**Next steps**:
- F-033 Project-Specific Customization Layer

**Blockers**: None


### Session: 2026-03-28 20:21 - F-033 Implementation

**Why**: Projects need upgrade-safe customization beyond STACK.md settings

**What changed**:
- All 6 phases: custom conventions, done-checks, lifecycle hooks, workflow directions, enforcement policies, docs+validation. 7 contract assertions pass. 2 new files, 10 modified, +260 lines.

**Next steps**:
- PR review, then ag done F-033

**Blockers**: None


### Session: 2026-03-28 20:58 - F-033 shipped

**Why**: Projects need upgrade-safe customization beyond STACK.md settings

**What changed**:
- Project-specific customization layer: 6 extension points in .agentic/local/ — conventions, done-checks, lifecycle hooks, workflow directions, enforcement policies, comprehensive docs

**Next steps**:
- F-034 Project Customization Auto-Sync

**Blockers**: None


### Session: 2026-03-28 21:38 - F-033 Auto-Sync

**Why**: Customization layer needs to survive upgrades — unmodified templates should get updates, customized files should be preserved

**What changed**:
- Added upgrade.sh Step 5a: local customization sync that detects unmodified vs customized files, replaces or writes .new; folded F-034 into F-033; added 3 new contract assertions

**Next steps**:
- Ship F-033, merge PR

**Blockers**: None


### Session: 2026-03-29 10:20 - F-0210: Configurable DoD per task type

**Why**: Spikes and docs features were blocked by test/doc gates that don't apply to their task type

**What changed**:
- Implemented task-type-aware Definition of Done: dod.conf with 4 types, dod.py resolution cascade, gates 3/5/6 skip for spike/docs, done.sh dynamic checklist, contract task_type field

**Next steps**:
- Instruction file updates, LLM tests

**Blockers**: None


### Session: 2026-03-29 11:27 - F-0210 shipped

**Why**: Post-merge completion

**What changed**:
- Configurable DoD per task type merged via PR #214. 4 types, gate skipping, backward compatible.

**Next steps**:
- Design phase formalization (next backlog item)

**Blockers**: None


### Session: 2026-03-29 20:33 - Design phase formalization

**Why**: Teams with complex architecture need a formal design step (ADRs, design docs) between planning and specification — no gate enforced it before

**What changed**:
- Optional DESIGNED state added between planned and specced. 15 files updated: state machine, gates, review map, profiles, downstream state lists, YAML workflow, contract, STACK template, tests. All 3 design_phase modes (off/optional/required) with gate enforcement and get_next_states filtering. Contract round-trip fidelity via new 'designing' lifecycle value.

**Next steps**:
- Review and merge PR. Run ag done after merge.

**Blockers**: None


### Session: 2026-03-29 20:46 - Design phase formalization shipped

**Why**: Post-merge completion for F-004 improvement

**What changed**:
- Optional designed state merged via PR #215. 10-state lifecycle, 3 design_phase modes, gate enforcement, contract round-trip fidelity, 17 new tests, docs updated.

**Next steps**:
- F-037 MCP Coordination Server (next backlog item)

**Blockers**: None



### Session: 2026-03-30 18:24 - Framework QA: workflow enforcement hardening

**Why**: Agent workflow violations (skipping plan review, shipping without docs) were not caught by existing tests — only structural file-existence checks, no enforcement-chain or behavioral coverage

**What changed**:
- Fixed 10 validate_framework.sh test bugs (env leaks, consolidation-unaware checks, missing PyYAML). Added 21 structural enforcement-chain tests that verify plan-review and doc-update instructions exist across ALL layers (CLAUDE.md, skills, memory-seed, hooks, gates). Fixed 2 real enforcement gaps: memory-seed missing plan auto-review rule, planning skill missing auto-continue instructions. Built test_workflow_breaker.sh (23 tests) exercising every gate from idea→shipped. Found 1 real gap: WIP detection via agents_helpers.py fails when PROJECT_ROOT differs from script path. Added 4 Critical LLM behavioral tests (098-101) for plan-exit auto-continue, docs-before-PR, wrong-rationalization rejection. Cleaned 5 garbage journal entries from prior test pollution.

**Next steps**:
- Run LLM behavioral tests 098-101 against Claude. Investigate WIP detection gap (agents_helpers.py PROJECT_ROOT resolution).

**Blockers**: None

### Session: 2026-03-31 08:20 - QA doc refresh

**Why**: QA docs were stale — test counts, principle mappings, and test inventories didn't reflect the new enforcement + integration tests

**What changed**:
- Updated all 5 QA docs (VERIFICATION_REPORT, TRACEABILITY_MATRIX, LLM_TEST_PLAN, QA_GUIDE, llm/README) to reflect new enforcement-chain tests, workflow breaker suite, and LLM tests 098-101

**Next steps**:
- Run LLM tests 098-101 against Claude Code

**Blockers**: None


### Session: 2026-04-01 08:03 - F-040 App Store Publishing

**Why**: Mobile app publishing is error-prone and repetitive — framework orchestration brings it under ag workflow

**What changed**:
- Implemented full ag publish pipeline: detect, preflight, providers (fastlane+custom), Python orchestrator with state, screenshots, metadata, status display, skill, 11 structural tests passing

**Next steps**:
- PR review and merge, then ag done F-040

**Blockers**: None


### Session: 2026-04-02 13:23 - F-040 shipped

**Why**: Post-merge completion ceremony

**What changed**:
- PR #217 merged, F-040 App Store Publishing shipped. 12/12 contract assertions pass.

**Next steps**:
- Next backlog item: F-037 MCP Coordination Server

**Blockers**: None


### Session: 2026-04-02 13:24 - F-040 state flush

**Why**: Post-merge state flush

**What changed**:
- Post-merge: F-040 shipped, contract fixes, VERSION bump

**Next steps**:
- F-037 MCP Coordination Server

**Blockers**: None


### Session: 2026-04-02 16:51 - F-041 Intelligence Engine

**Why**: Intelligence is core framework value — domain-specific quality, token efficiency, enforced learning

**What changed**:
- Feature registered, plan approved (F-041), backlog updated, branch created

**Next steps**:
- Phase 1: Patterns + Write Hook implementation

**Blockers**: None


### Session: 2026-04-02 17:02 - F-041 Phase 1: Patterns + Write Hook

**Why**: Intelligence engine Phase 1 delivers enforced pattern learning at write-time

**What changed**:
- patterns.yaml seeded with 7 entries from LESSONS.md, ag intel command (check/learn/patterns), PreToolUse pattern warnings for Write/Edit, upgrade.sh migration, 16/16 tests passing

**Next steps**:
- Phase 2: Anatomy + Token Ledger

**Blockers**: None


### Session: 2026-04-02 17:10 - F-041 review fixes

**Why**: PR #218 review feedback

**What changed**:
- All 9 review items fixed: shared parser, deduplication, --json, remove, severity validation, plan cleanup, FEATURES status

**Next steps**:
- Push updated PR

**Blockers**: None


### Session: 2026-04-02 17:26 - F-041 Cerebrum: project-scoped learning

**Why**: OpenWolf analysis revealed gap: no project-scoped capture of user preferences and learnings

**What changed**:
- cerebrum.yaml + remember/cerebrum/forget commands, correction triggers in 10 instruction files (CLAUDE.md, cursorrules, copilot, codex, memory-seed, 4 skills), 36/36 tests

**Next steps**:
- Phase 2: Anatomy + Token Ledger

**Blockers**: None


### Session: 2026-04-02 18:05 - F-041 Phase 2: Anatomy + Token Ledger

**Why**: File intelligence and session metrics — agents can now check file summaries/tokens before reading, and sessions track context cost

**What changed**:
- ag intel scan/file/stats commands, PostToolUse token tracking, Stop.sh finalization, 18 tests + 21 ACs

**Next steps**:
- Phase 3: Bootstrap + Quality Intelligence

**Blockers**: None


### Session: 2026-04-02 19:25 - F-041 Phase 3

**Why**: Intelligence engine needs knowledge generation to produce domain-specific quality intelligence from project stack

**What changed**:
- Bootstrap + retro commands: stack detection (STACK.md + codebase scan), quality-checklist.yaml template, test-strategy.yaml template, retro analysis (issues/lessons/shipped features). 16 tests passing.

**Next steps**:
- Phase 4: phase-aware queries + skill integration

**Blockers**: None


### Session: 2026-04-02 20:18 - F-041 Phase 4

**Why**: Make intelligence accessible at each workflow phase

**What changed**:
- Phase-aware intel queries (architecture, spec, implement, test) integrated into 4 skills + 5 instruction files + dashboard

**Next steps**:
- PR creation, then Phase 5 (read hook)

**Blockers**: None


### Session: 2026-04-02 20:30 - F-041 Phase 4 docs

**Why**: Intelligence engine docs were missing from framework documentation

**What changed**:
- Updated 4 framework docs with intelligence engine content (OVERVIEW, FRAMEWORK_MAP, HOW_IT_WORKS, DEVELOPER_GUIDE)

**Next steps**:
- Create PR

**Blockers**: None


### Session: 2026-04-02 20:49 - F-041 Phase 4 — remaining docs + contributions

**Why**: Complete doc coverage for intelligence engine feature

**What changed**:
- Updated PRINCIPLES, INSTRUCTION_ARCHITECTURE, FRAMEWORK_WORKFLOW, START_HERE, README, CONTRIBUTIONS with intelligence engine content

**Next steps**:
- Merge PR #221

**Blockers**: None


### Session: 2026-04-02 20:51 - F-041 CONTRIBUTIONS

**Why**: Capture user design decisions accurately

**What changed**:
- Expanded to 10 user insights from JSONL logs (Mar 11 - Apr 2)

**Next steps**:
- Merge PR

**Blockers**: None


### Session: 2026-04-02 21:00 - F-041 review fixes

**Why**: Code review findings

**What changed**:
- Fixed 6 code issues from review: prev_dimension scope leak, error pattern callback, contract loop O(n), AC-033 verify, NFR parsing, missing-file tests

**Next steps**:
- Merge PR

**Blockers**: None


### Session: 2026-04-02 21:05 - F-041 shipped

**Why**: Post-merge completion

**What changed**:
- Intelligence Engine Phases 1-4 complete and shipped as v0.77.1

**Next steps**:
- F-037 MCP Coordination Server

**Blockers**: None


### Session: 2026-04-03 09:02 - F-041 Intel Tests + F-042 Universal Capability Catalog

**Why**: Intelligence engine needed comprehensive test coverage; capability catalog was formal-only leaving discovery projects with no tracking; enforcement needed to use Claude hooks not pre-commit

**What changed**:
- Built 119 new intel tests (gaps, integration, logging), added intel event logging for sourcing audit, implemented universal capability catalog with Claude hook enforcement across all profiles

**Next steps**:
- Instruction file updates for enforcement hierarchy, PR review, ag done on main after merge

**Blockers**: None


### Session: 2026-04-03 09:06 - F-042 single format

**Why**: User feedback: dual format is confusing, discovery should be lightweight but still track what matters

**What changed**:
- Removed dual format from capability catalog — one format for all profiles

**Next steps**:
- Push PR, merge after review

**Blockers**: None


### Session: 2026-04-03 09:26 - PR #222 review fixes

**Why**: Code review found stale metadata and minor bugs before merge

**What changed**:
- Fixed 6 review issues: duplicate comment, stale F-042 metadata, test count correction, _il_int robustness

**Next steps**:
- Merge PR, ag done on main

**Blockers**: None


### Session: 2026-04-03 09:28 - Post-merge: dogfood sync + VERSION bump

**Why**: Post-merge dogfooding sync — templates had new content root files lacked

**What changed**:
- Synced enforcement hierarchy and design tracking sections to root CLAUDE.md and .cursorrules, added cap add references, bumped VERSION 0.77.1→0.78.1

**Next steps**:
- Tag v0.78.1, push

**Blockers**: None


### Session: 2026-04-03 12:45 - Hooks & Skills Enforcement Optimization

**Why**: Framework features had ~20-60% behavioral reliability; hooks+skills optimization raises most to ~75-95% structural enforcement

**What changed**:
- 18 changes across 4 phases: structural gates (DRAFT plan PreToolUse deny, shipped spec blocking, review evidence), intelligence push model (all profiles), workflow reliability (scheduler retry, backlog nudges, live sync), doc cleanup (enforcement tables in skills, memory-seed update). 7 review issues fixed. 6 new unit tests.

**Next steps**:
- Phase 4 remaining: enforcement map generation, full instruction file dedup audit

**Blockers**: None


### Session: 2026-04-06 10:54 - Fix framework disconnection detection

**Why**: False-positive FRAMEWORK DISCONNECTED every session because detection checked wrong file

**What changed**:
- Dashboard now checks .claude/hooks.json instead of settings.json; added restart advice; AC-003 to AC-007 on F-023

**Next steps**:
- None

**Blockers**: None


### Session: 2026-04-06 11:07 - Artifact remediation for PR #225

**Why**: Two features were implemented without framework workflow — specs, contracts, tests, docs, and instruction file sync were all missing

**What changed**:
- F-043 contract (16 ACs for persona/platform dimensions), F-015 migration (6 new ACs for framework disconnection detection), FEATURES.md entries, 30+ structural tests in validate_framework.sh, DEVELOPER_GUIDE personas section, HOW_IT_WORKS persona paragraph, ag persona in 6 instruction files (CLAUDE.md x2, cursorrules, copilot, codex, memory-seed), HUMAN_NEEDED PR tracking, writing-specs skill already had persona guidance

**Next steps**:
- Run full test suite, push to PR #225 branch

**Blockers**: None


### Session: 2026-04-06 13:31 - PR #225 merged — v0.79.0

**Why**: Remediated two features that bypassed workflow, plus evolved OVERVIEW.md and decision logging from design discussion

**What changed**:
- F-043 persona dimensions shipped, F-015 framework detection ACs added, F-042 decision routing + OVERVIEW enrichment + journal --decision flag. 42 files, 35 structural tests + 2 LLM tests. All instruction files synced.

**Next steps**:
- ag backlog list for next work item

**Blockers**: None


### Session: 2026-04-03 18:30 - Backlog reassessment: consolidate F-037/038/039

**Why**: Framework shipped equivalent infrastructure under F-018/F-030; standalone features violated no-feature-inflation rule

**What changed**:
- Deprecated F-037/038/039 as standalone features. Added planned ACs to F-018 (MCP transport + multi-repo) and F-030 (scheduling enhancements). Added AC-level status field to contract schema for incremental delivery on shipped features.

**Next steps**:
- Backlog is empty — decide next priorities

**Blockers**: None


### Session: 2026-04-06 14:55 - T-0097 ExitPlanMode migration gate

**Decision**: Block all profiles equally — advisory fallback for formal profile was a security gap

**What changed**:
- Made review evidence check blocking for all profiles in gate.py, added evidence gate to ag implement (checks review-pending sentinel + review.md markers), fixed bash 3.2 case syntax in intel.sh, added E-PLAN-010/011 regression tests

**Next steps**:
- Commit and create PR

**Blockers**: None


### Session: 2026-04-09 15:29 - Phase gate bypassed

**Why**: Incomplete phases overridden at shipping time

**What changed**:
- F-9998: --force-phases used. 

**Next steps**:
- TBD

**Blockers**: None


### Session: 2026-04-09 15:29 - Phase gate bypassed

**Why**: Incomplete phases overridden at shipping time

**What changed**:
- F-9997: --force-phases used. 

**Next steps**:
- TBD

**Blockers**: None


### Session: 2026-04-09 15:40 - Phase gate bypassed

**Why**: Incomplete phases overridden at shipping time

**What changed**:
- F-9998: --force-phases used. 

**Next steps**:
- TBD

**Blockers**: None


### Session: 2026-04-09 15:41 - Phase gate bypassed

**Why**: Incomplete phases overridden at shipping time

**What changed**:
- F-9997: --force-phases used. 

**Next steps**:
- TBD

**Blockers**: None


### Session: 2026-04-09 15:41 - Phase gate bypassed

**Why**: Incomplete phases overridden at shipping time

**What changed**:
- F-9998: --force-phases used. 

**Next steps**:
- TBD

**Blockers**: None


### Session: 2026-04-09 15:41 - Phase gate bypassed

**Why**: Incomplete phases overridden at shipping time

**What changed**:
- F-9997: --force-phases used. 

**Next steps**:
- TBD

**Blockers**: None


### Session: 2026-04-09 15:41 - Phase gate bypassed

**Why**: Incomplete phases overridden at shipping time

**What changed**:
- F-9998: --force-phases used. 

**Next steps**:
- TBD

**Blockers**: None


### Session: 2026-04-09 15:41 - Phase gate bypassed

**Why**: Incomplete phases overridden at shipping time

**What changed**:
- F-9997: --force-phases used. 

**Next steps**:
- TBD

**Blockers**: None


### Session: 2026-04-09 15:42 - Phase gate bypassed

**Why**: Incomplete phases overridden at shipping time

**What changed**:
- F-9998: --force-phases used. 

**Next steps**:
- TBD

**Blockers**: None


### Session: 2026-04-09 15:42 - Phase gate bypassed

**Why**: Incomplete phases overridden at shipping time

**What changed**:
- F-9997: --force-phases used. 

**Next steps**:
- TBD

**Blockers**: None


### Session: 2026-04-09 15:43 - Phase gate bypassed

**Why**: Incomplete phases overridden at shipping time

**What changed**:
- F-9998: --force-phases used. 

**Next steps**:
- TBD

**Blockers**: None


### Session: 2026-04-09 15:43 - Phase gate bypassed

**Why**: Incomplete phases overridden at shipping time

**What changed**:
- F-9997: --force-phases used. 

**Next steps**:
- TBD

**Blockers**: None


### Session: 2026-04-09 15:56 - Phase gate bypassed

**Why**: Incomplete phases overridden at shipping time

**What changed**:
- F-9998: --force-phases used. 

**Next steps**:
- TBD

**Blockers**: None


### Session: 2026-04-09 15:56 - Phase gate bypassed

**Why**: Incomplete phases overridden at shipping time

**What changed**:
- F-9997: --force-phases used. 

**Next steps**:
- TBD

**Blockers**: None


### Session: 2026-04-09 15:59 - Phase gate bypassed

**Why**: Incomplete phases overridden at shipping time

**What changed**:
- F-9998: --force-phases used. 

**Next steps**:
- TBD

**Blockers**: None


### Session: 2026-04-09 15:59 - Phase gate bypassed

**Why**: Incomplete phases overridden at shipping time

**What changed**:
- F-9997: --force-phases used. 

**Next steps**:
- TBD

**Blockers**: None


### Session: 2026-04-09 16:05 - Decision auto-capture + plan review enforcement

**Why**: User identified costly UserPromptSubmit scanning and journal spam from test runs

**What changed**:
- Sentinel-based plan gate (O(1) check), journal spam fix (test isolation), ag plan skip command

**Next steps**:
- PR review

**Blockers**: None


### Session: 2026-04-09 16:16 - Evidence-based plan approval gate

**Why**: User identified inverted gate logic, self-reported status vulnerability, and missing specs

**Decision**: Plan gates require evidence of independent review, not agent-written status

**What changed**:
- Redesigned plan review enforcement: safe-by-default (block unless approved), evidence-based approval (review.md with Critic/Advocate markers, not self-reported status), PostToolUse creates sentinel on verified review evidence, 12 new ACs (AC-052..063)

**Next steps**:
- PR review

**Blockers**: None


### Session: 2026-04-09 16:25 - Three structural enforcement improvements

**Why**: All three improvements from self-review — moving from advisory to structural

**Decision**: Discovery gets advisory nudges, formal gets blocking gates — same enforcement, different intensity

**What changed**:
- Auto-capture to project-memory.yaml from hooks (no agent involvement), spec-before-code ordering (formal=block, discovery=nudge), plan content validation (advisory check for AC/tests mentions)

**Next steps**:
- PR review

**Blockers**: None


### Session: 2026-04-09 16:34 - PR #229 merged

**Why**: User requested decision/instruction capture with framework-level storage and structural enforcement

**Decision**: Evidence-based plan approval (review.md markers), safe-by-default gates, auto-capture at hook level

**What changed**:
- Auto-capture pipeline, evidence-based plan gate, cerebrum→project-memory rename, spec-before-code enforcement, plan content validation. 15 new ACs (AC-052..066), 817 tests. User designed the evidence-based approval model.

**Next steps**:
- Post-merge: VERSION bump, dogfood sync, memory-seed update

**Blockers**: None


### Session: 2026-04-09 16:52 - F-025 Cursor Support Upgrade

**Why**: Cursor features evolved: .cursorrules deprecated, subagent frontmatter changed, native hooks/skills/MCP added

**What changed**:
- Upgraded Cursor IDE support to parity with Claude Code: .cursor/rules/*.mdc (4 templates), hooks.json (5 events with plan gate + decision capture), Cursor-compatible agent frontmatter, 12 skills, MCP template. 18 new tests, 832 total pass.

**Next steps**:
- Merge PR, run ag done F-025

**Blockers**: None


### Session: 2026-04-09 20:51 - F-025 Cursor sync/upgrade integration

**Why**: New .cursor/ artifacts were not wired into upgrade/sync/init paths — users upgrading would get .cursorrules regenerated but not the new rules/hooks/skills.

**What changed**:
- Fixed BSD sed bug in setup_cursor_agents (awk replaces sed for frontmatter strip). Fixed jq-not-found false failures in validate_framework.sh (python3 fallback). Added upgrade.sh step 5b-cursor to regenerate .cursor/ on upgrade. Extended check-environment.sh and sync.sh to detect missing .cursor/rules, hooks.json, skills. Regenerated .cursor/agents with correct Cursor frontmatter.

**Next steps**:
- Commit and push

**Blockers**: None


### Session: 2026-04-09 20:54 - gitignore: session sentinels and intel/token-summary

**Why**: These files kept appearing as untracked in git status — they are pure runtime artifacts with no commit value.

**What changed**:
- Added missing gitignore entries for transient runtime files: session event logs, sentinel flags, and intel/token-summary.json (derived cache). Updated gitignore.sh template so new user projects also ignore intel derived files.

**Next steps**:
- Done

**Blockers**: None


### Session: 2026-04-09 20:55 - Fix Cursor Stop hook missing .correction_hint_shown cleanup

**Why**: Sentinel was gitignored but not cleared at session end by Cursor hook, so it could persist across sessions and suppress the correction hint permanently.

**What changed**:
- Added rm -f for .correction_hint_shown in Cursor enforcement.sh Stop handler — parity with Claude Stop.sh which already clears it.

**Next steps**:
- Done

**Blockers**: None


### Session: 2026-04-09 20:57 - Clear session sentinels at session start

**Why**: Sentinels could persist across sessions if Stop hook didn't run (crash/force-quit), suppressing gates and hints that should fire fresh each session.

**What changed**:
- Added sentinel cleanup to SessionStart.sh (Claude) and context.sh SessionStart (Cursor). Covers crash recovery — Stop hook normally clears these but won't fire if session is force-quit.

**Next steps**:
- Done

**Blockers**: None


### Session: 2026-04-09 20:59 - F-025 ACs updated for Cursor upgrade completion

**Why**: Contract must reflect built state of shipped features — planned ACs are now implemented.

**What changed**:
- Updated contract F-025.yaml: promoted AC-006 through AC-009 from planned to built with verify commands + test refs. Added AC-010 (upgrade.sh cursor step), AC-011 (sync/check-env .cursor/ detection), AC-012 (Cursor Stop sentinel parity), AC-013 (SessionStart crash recovery). Added migration M-002.

**Next steps**:
- Done

**Blockers**: AC-001 (CLAUDE.md 107 lines) is pre-existing, unrelated to this work.


### Session: 2026-04-09 19:24 - F-041 LLM-Driven Preference Capture

**Why**: Regex-based auto-capture was too narrow, too noisy, and misattributed agent actions as user decisions

**Decision**: LLM does semantic classification, hooks do plumbing only

**What changed**:
- Replaced regex auto-capture with LLM-driven semantic classification. Added intel_capture setting (retro/realtime/off). Removed misattribution bugs, journal dual-write noise, and auto-capture from ag plan skip and ag set. User designed the approach after discovering agent was logging 'user decisions' the user never made.

**Next steps**:
- Monitor capture rate in retro mode; future: project-memory as state document

**Blockers**: None


### Session: 2026-04-09 20:00 - Surface planned assertions + agent-agnostic enforcement

**Why**: Planned assertions were permanently invisible — no gate or workflow checked for them after initial write

**Decision**: Advisory not blocking for ag done gate — legitimate to ship with deferred ACs

**What changed**:
- Added 4 mechanisms to surface unshipped assertions: ag contract promote command, verify-contracts.sh summary, ag done Gate 4 advisory, ag sync Phase 4b drift detection. Made enforcement hierarchy agent-agnostic across 6 instruction files.

**Next steps**:
- Test with PyYAML-enabled environment, consider adding LLM test for promote command

**Blockers**: None


### Session: 2026-04-10 06:34 - F-018 MCP Transport

**Why**: F-018 AC-002/003/004 fulfilled

**What changed**:
- MCP stdio transport for coordination server merged (PR #233). 8 coord tools exposed via MCP protocol. Stdout capture, isError pattern, signal handlers, tests.

**Next steps**:
- ag done F-018, VERSION bump

**Blockers**: None


### Session: 2026-04-10 10:33 - MCP Task Delegation

**Why**: Context exhaustion in long sessions — users needed external CLI loops for fresh context

**Decision**: Parent-only MCP access, always-delegate for 2+ ACs, MCP as state bridge not just coordination

**What changed**:
- Added 5 MCP tools (list_acs, get_task_brief, save_progress, get_next_action, get_delegation_prompt) for context-optimized subagent spawning. MCP server as state bridge across context boundaries. 123 tests pass (101 unit + 22 E2E). All review findings fixed (path traversal, last-entry-wins, lstrip corruption). Instruction files, CHANGELOG, HOW_IT_WORKS, DEVELOPER_GUIDE, contract updated.

**Next steps**:
- Merge PR #234, run ag done

### Session: 2026-04-10 07:33 - Fix scheduler logger + test updates

**Why**: Crunch tests were failing because CrunchRunner now delegates to AutonomousScheduler but tests still mocked at crunch layer

**What changed**:
- Fixed missing logger in scheduler.py causing NameError on retry; updated test_auto_crunch.py to mock at scheduler layer; fixed test_scheduler.py retry test

**Next steps**:
- None

**Blockers**: None


### Session: 2026-04-10 13:06 - MCP Context Optimization Plan

**Why**: Long-running sessions exhaust context; external CLI loops are a workaround that only works in CLI mode

**What changed**:
- Saved draft plan for MCP-driven context optimization — eliminates CLI runner loops by combining Agent tool + MCP coordination server

**Next steps**:
- Dialectical review if plan_review_enabled, then implementation

**Blockers**: None


### Session: 2026-04-10 13:31 - TODO Triage (2026-04-10)

**Why**: Backlog was empty, TODO inbox had 47 items accumulated over 2 months of v0.54→v0.81 development. Many referenced pre-v2 artifacts.

**Decision**: Closed 14 as obsolete/done based on codebase verification (not assumptions). Ordered backlog: bugs→investigation→cleanup→enforcement→tests→incremental.

**What changed**:
- Triaged all 47 open TODOs against v0.81.0 state. Closed 14 (shipped/obsolete: T-0002 Context7, T-0022 .conf, T-0025 NFRs, T-0045 IDs, T-0050 drift, T-0058 TDD, T-0065 discovery docs, T-0067 NFR lifecycle, T-0068 ExitPlanMode wrappers, T-0069 field-validate, T-0070 Check 21, T-0086 Phase 3 audit, T-0095 gate 0d evidence, T-0096 PreToolUse plan gate). Promoted 13 to backlog ordered by impact: bugs first (T-0078 env leak, T-0023 worktree), investigation (T-0094 PostToolUse), cleanup (T-0090 work/ artifacts), UX (T-0088 scaffold), enforcement (T-0072 git safety, T-0041 versioning), LLM tests (T-0083/84/85), CI (T-0003), incremental (T-0075 IDs, T-0087 AC timing). 20 ideas remain in inbox grouped by theme with parent feature annotations.

**Next steps**:
- Pick up T-0078 (backlog position 0) — ag done env leak fix

**Blockers**: None


### Session: 2026-04-10 14:31 - MCP backlog churn tests

**Why**: No test coverage existed for the MCP-driven backlog churn orchestration loop

**What changed**:
- Added 26 e2e tests exercising MCP coordinator for multi-feature backlog churning — covers claim/release lifecycle, cross-feature isolation, error/retry routing, CrunchRunner backlog integration, scaling to 5 features. All 149 MCP tests pass.

**Next steps**:
- Commit and merge

**Blockers**: None


### Session: 2026-04-10 19:31 - F-008: Quality Knowledge System

**Why**: v2 refactoring deleted ~17K lines of quality/workflow docs, replaced by 83-line conventions.md. Stack-specific domain knowledge (failure modes, testing strategies, library selection) was lost. 119 broken references across 52 files pointed to deleted content, including 2 functional breakages.

**Decision**: Quality knowledge lives in hybrid YAML+markdown format. YAML for machine-actionable data (generator compiles to quality_checks.sh), markdown companions for deep domain expertise (agents read during implementation). Blocking enforcement by default via STACK.md setting.

**What changed**:
- Rebuilt quality assurance knowledge lost in v2 refactor. 21 quality knowledge files (7 universal + 14 stack-specific), Python generator with ag quality CLI, enforcement wired into ag commit + pre-commit + gate.py. Fixed 111 broken references to deleted files across 52 source files. Updated 7 documentation files.

**Next steps**:
- Commit and create PR. Consider adding more stack types (Go, Rust, Flutter) in future.

**Blockers**: None


### Session: 2026-04-10 20:11 - F-008 post-merge

**What changed**:
- Merged PR #235. Fixing migration YAML schema (missing id field). Doc freshness gate shows 6 stale docs (pre-existing, not F-008 related).

**Next steps**:
- Bump VERSION

**Blockers**: None


### Session: 2026-04-10 20:14 - v0.82.0 release

**What changed**:
- VERSION bump to 0.82.0 — F-008 quality knowledge system shipped

**Next steps**:
- Update stale docs

**Blockers**: None


### Session: 2026-04-10 21:30 - F-008 doc freshness

**What changed**:
- Updated 5 stale docs flagged by ag done: FRAMEWORK_WORKFLOW.md, FRAMEWORK_MAP.md, INSTRUCTION_ARCHITECTURE.md, README.md, .cursor/ agents+rules. Fixed remaining broken refs to deleted v2 files.

**Next steps**:
- ag done F-008 should now pass doc gate

**Blockers**: None


### Session: 2026-04-13 19:13 - F-008 PR-A: skills.sh marketplace integration scaffold

**Why**: F-008 today ships 7 built-in stack quality files. Community stacks outside that set get nothing. skills.sh provides ~91k community skills but no safe install path into the framework.

**Decision**: Curated allowlist + confirm prompt (supply-chain gate), GitHub raw fetch only (no npx/arbitrary JS), mandatory sha pins, script quarantine, extension-dir landing zone. Three-PR phasing — engine first, init integration second, change-detection hook third.

**What changed**:
- Added ag skills CLI (suggest/install/sync/list/remove/update-pins/request) with curated allowlist at .agentic/lib/data/skills-marketplace.yaml, Python engine at skills_marketplace.py, bash dispatcher, Cursor generator extension. AC-009/010/011 + M-002 added to F-008 contract.

**Next steps**:
- PR-B: ag init integration (backlog pos 13). PR-C: STACK.md PostToolUse hook + cross-agent instruction sync + LLM tests (backlog pos 14).

**Blockers**: Real sha pins needed before first real install — current entries are seed placeholders (all-zero shas); ag skills install refuses seed pins explicitly.


### Session: 2026-04-14 20:15 - F-008 PR-B: skills.sh marketplace init integration

**Why**: PR-A delivered the CLI engine but no integration touchpoint — users had to know about ag skills to use it. PR-B wires it into the natural init flow.

**Decision**: Dual integration: scaffold.sh (structural, runs regardless of agent) + init_playbook.md (agent-guided, richer UX). --no-skills + skip_on_init preference for CI and repeat inits.

**What changed**:
- scaffold.sh now offers marketplace skills after brownfield stack detection. Three-way handling: interactive TTY gets Y/N/never prompt, non-interactive/no-TTY gets skip with info log, --no-skills flag for explicit opt-out. 'never' saves preference to skills-preferences.json. init_playbook.md Step 3b guides agent to run ag skills suggest after STACK.md fill. AC-012 added to F-008 contract.

**Next steps**:
- PR-C: STACK.md PostToolUse change hook + instruction-file sync + LLM tests (backlog pos 14).

**Blockers**: None.


### Session: 2026-04-26 16:33 - R-007 JSONL event spine

**Why**: Center-of-gravity inversion: agents don't reliably follow in-session rules, so enforcement and observability must live in processes the agent doesn't drive. Every later piece (TUI, quota ring, critic telemetry, intel-invocation tracking) reads from this spine — without it, autonomous Tier 3 work is faith-based

**Decision**: In-house validator over a jsonschema runtime dependency. The schema shape is small and fully under our control, the framework already treats jsonschema as optional in validate_specs.py, and keeping the schema JSON files canonical lets external tools (ajv, CI mirrors) use the same source of truth

**What changed**:
- Three append-only JSONL streams (events / delegation / token-ledger) now have canonical JSON Schemas plus fcntl.flock-serialized writers. 4 processes × 1000 concurrent events produce exactly 4000 valid lines; 8KB soft cap with truncation marker on the free-form field; in-house validator avoids a hard jsonschema runtime dep while the schema files stay authoritative for ajv/external use. 18 tests pass; runs under pytest or directly. First brick of the v5 observability substrate.

**Next steps**:
- R-001 (pre-commit gate, 3d) — reads the schema + uses gate_blocked/gate_skipped event types; then R-002 pre-push, then R-008 TUI

**Blockers**: None


### Session: 2026-04-26 16:51 - R-001 Tier 0 pre-commit gate (v5 redesign)

**Why**: Months of failed single-agent enforcement; v5 inverts to Tier 0 git-layer enforcement that fires regardless of which agent runs in the session

**Decision**: Stack R-001 branch on R-007 rather than ff-main locally — keeps both branches reviewable; merge to main is a separate user decision

**What changed**:
- Shipped precommit_gate.py with 6 hardcoded checks (tests, contracts, plan-approved sentinel, JOURNAL freshness, shipped-contract migrations, ag-commit breadcrumb), 31 tests passing without pytest/pyyaml deps. Wired ag commit --skip-gate <reason> for sanctioned audited bypasses; emits gate_blocked / gate_skipped / contract_check / test_run events to events.jsonl. Pre-commit shim installed at .git/hooks/pre-commit; activation in .agentic/hooks/ deferred to R-015 hooks register.

**Next steps**:
- R-002 prepush gate then R-008 TUI in parallel; eventually R-015 wires this gate into core.hooksPath active path

**Blockers**: PyYAML missing in dev container surfaces a real ag contract check failure — environmental, not introduced by R-001


### Session: 2026-04-26 17:05 - R-002 Tier 0 pre-push gate

**Why**: Pre-commit catches per-commit shape; pre-push catches range shape (rebases, amends, force-pushes that would land bad state on shared remote); composing both is v5's defense-in-depth at the git layer

**Decision**: Migration check across full pushed range reuses precommit_gate's line-based YAML helpers via lazy import — DRY without coupling the modules into each other

**What changed**:
- Shipped prepush_gate.py with 5 hardcoded checks (full integration tests, ag contract coverage threshold parsed from output, drift.sh --docs in formal+, range-walk migration check across <remote>..<local>, ag-push breadcrumb), 22 tests passing without pytest/pyyaml deps. Wired ag push --skip-gate <reason>; emits push_attempt event regardless of outcome (AC7) plus gate_blocked / gate_skipped / contract_check / test_run as in R-001. Pre-push shim installed at .git/hooks/pre-push.

**Next steps**:
- R-008 Textual TUI next (sequential per user direction)

**Blockers**: Same as R-001 — PyYAML missing in dev container makes ag contract coverage degrade to 0% which would block; tests stub the output so unit tests pass


### Session: 2026-04-26 17:51 - R-008 ag tui mission-control dashboard

**Why**: Tier 3 autonomous work without observability is faith-based; the dashboard is the thing connecting a user back to multi-hour runs. Quota burn-down ring (R-014) layers on top; this is the substrate.

**Decision**: Pure-Python + Textual split via panel *_lines() shapers — the R-007/R-001/R-002 pytest-free pattern works for TUI testing too; saves users from needing Textual in CI

**What changed**:
- Shipped tui/ package: pure-stdlib JSONL stream tailer (live-tail with rotation detect), thread-safe DashboardState aggregator (workers/events ring/health/tokens), 5 panel widgets (header/workers/events/health/drilldown) with shared color-hint table, Textual App entrypoint with lazy import, ag tui dispatcher. 28 tests pass without Textual installed (panels use *_lines() shapers as the pure-Python boundary; widget classes only loaded by run_tui()).

**Next steps**:
- Commit the sprint, then plan next sprint per backlog (Phase 0 fan-out: R-005 chmod, R-009 ag watch, R-010 ag fix, R-011 ag onboard, R-012 structured error msgs, R-013 quota, R-015 hooks register all unblocked)

**Blockers**: Textual + Rich missing in dev container by design — install hint surfaces cleanly when ag tui invoked here


### Session: 2026-04-26 18:10 - Sprint 1 review fixes

**Why**: Code review surfaced bugs + missed conventions; addressing before merge per CLAUDE.md no-merge-with-known-issues policy

**Decision**: VERSION drift left for ag done post-merge — touching VERSION manually mid-sprint violates the 'every merge bumps via ag done' convention

**What changed**:
- Addressed all reviewer feedback: prepush_gate dead code removed; tui/state monotonic clock + dead branch documented; tui/app double set_interval split into full + quota-only; tests strengthened (ring eviction, malformed YAML, quoted commands, conditional Textual skip); instruction files backport (root + template CLAUDE/cursorrules/copilot/codex + memory-seed + FRAMEWORK_MAP + HOW_IT_WORKS + DEVELOPER_GUIDE); CONTRIBUTIONS.md sprint 1 insights. 103 tests green. validate_framework.sh: 845/846 (pre-existing VERSION drift, not from sprint).

**Next steps**:
- Commit, push, merge to main per user direction

**Blockers**: Legacy bash gate's complexity warning at 18 staged files (advisory only, instruction-file backport spans 11 files by nature)


### Session: 2026-04-26 19:31 - V5 architectural decision contributions backfilled

**Why**: User explicitly asked to surface contributions from messages on the four topics (real-world projects, market research/M.A., Claude arch doc, transformation), then flagged the missed pushback dynamic — these were the highest-leverage user contributions in the redesign cycle but had no entries in CONTRIBUTIONS.md

**Decision**: Captured pushback as Thread 5 with its own four insights (#17-20) plus updated the Why-it-matters paragraph; positioned the new section before V5 SPRINT 1 to reflect chronology (architecture decision -> first sprint executes it)

**What changed**:
- Added new V5 ARCHITECTURAL DECISION section to CONTRIBUTIONS.md covering five threads of user insights upstream of Sprint 1: real-world downstream session failure, M.A. autonomy audit, Claude architecture PDF translation, transform-vs-greenfield decision, and iterative pushback against single-agent-hooks defaults. 20 insights total, all sourced from sibling doc + V5 plan + greenfield path doc with line refs. Closes the gap user flagged: prior CONTRIBUTIONS.md only credited Sprint 1 implementation pattern, not the architectural reframe that justified V5 itself

**Next steps**:
- commit + push to main; resume Phase 0 fan-out wave A starting with R-005

**Blockers**: None


### Session: 2026-04-26 19:56 - R-005 shipped: filesystem RO protection for shipped contracts

**Why**: Closes one of two known Tier 0 honest-limits — filesystem mutation of shipped contracts. Pre-commit gate (R-001) is the second wall.

**Decision**: Two-wall design: chmod 444 blocks accidental writes; pre-commit gate audits deliberate bypasses (chmod u+w + edit + commit). Sanctioned path is ag contract migrate, not lockdown — friction at the bypass, not the happy path.

**What changed**:
- ag contract promote chmods to 444; ag contract migrate is the sanctioned mutation path with audit trail; existing mutators refuse on locked contracts with sanctioned-path hints; EACCES on direct Edit/Write blocks accidental tampering

**Next steps**:
- Wave A R-012 next (structured pre-commit error messages w/ next-step suggestions)

**Blockers**: None


### Session: 2026-04-26 20:16 - R-012 shipped: structured gate error messages with central catalog

**Why**: Sprint 1 shipped working gates but with minimal failure UX — bare BLOCKED messages with inlined next-steps that drifted between the two gates. R-012 makes failures self-documenting.

**Decision**: Catalog is the source of truth; gates are thin. Adding a new check means adding a BlockReason + a from_reason() call — no inline next_steps allowed. Tests enforce that every from_reason(messages.X) reference resolves.

**What changed**:
- Extracted message catalog into .agentic/lib/hooks/messages.py (9 BlockReason constants). precommit_gate + prepush_gate both use GateResult.from_reason(); --verbose flag adds expanded detail + plan refs without bloating default output. 11 catalog tests covering invariants and gate integration.

**Next steps**:
- Wave A R-004 next (hook integrity SHA-256 baseline)

**Blockers**: None


### Session: 2026-04-26 20:19 - Removed fabricated CONTRIBUTIONS entries

**Why**: Honest attribution: CONTRIBUTIONS.md is for actual user design inputs, not author framings dressed up as quotes.

**What changed**:
- User flagged R-005 + R-012 entries as misattributed framings, not actual user insights. Removed both sections cleanly; conversation + journal entries already capture real inputs (Wave A ordering, phase-based PR batching).

**Next steps**:
- Continue Wave A: R-004 hook integrity baseline

**Blockers**: None


### Session: 2026-04-26 20:28 - R-004 shipped: hook integrity baseline

**Why**: Closes the second known Tier 0 honest-limit (sibling to R-005 chmod 444): an agent could quietly modify the hook scripts that run the gate itself.

**Decision**: Partial-JSON hashing of settings.json[hooks] only — cosmetic edits to unrelated keys don't trip the gate. Skip envvar honored only under CI so an agent in a local session cannot disable the check.

**What changed**:
- Tier 0 layer 3 complete. SHA-256 baseline of .git/hooks/*, .agentic/lib/hooks/*.py, .agentic/lib/integrity.py, .claude/hooks.json, .claude/settings.json[hooks subfield only], .claude/agents/*.md committed to .agentic/integrity.json. Pre-commit runs check_integrity FIRST (so a tampered later check still trips this one). ag integrity status/update commands; INTEGRITY_SKIP=1 honored only under CI=true. 13 unit tests, plain-script runnable. Gate hierarchy now: 1=git-layer, 2=filesystem RO, 3=hook integrity, 4=Claude hooks, ...

**Next steps**:
- Wave A R-003 last (ag merge local merge gate)

**Blockers**: None


### Session: 2026-04-27 05:29 - R-003 shipped: ag merge — local merge gate

**Why**: Closes the merge-side hole — until R-003, local git merge to main bypassed every Tier 0 check between PRs. Now ag merge runs the same contract/pending checks the gates run on commit/push, but at the merge boundary.

**Decision**: Polymorphic on first arg: numeric goes to gh pr merge (existing); branch name goes to new local-merge gate. Same command, two transports. Avoids breaking the well-known PR-merge ergonomic.

**What changed**:
- Wave A complete (sprint 2). ag merge dispatches numeric → PR path; non-numeric → local merge gate. Discovers feature IDs from commit-message range vs target HEAD; runs ag contract check, ag contract pending, FEATURES.md tracking check, advisory CI mirror check. Sanctioned bypass via --skip-gate '<reason>' (audited). 6 tests pass.

**Next steps**:
- Wave A merge candidate ready for review; Wave B (R-009 ag watch + R-013 quota report + R-006 GHA template + R-010 ag fix + R-011 ag onboard) unblocked next.

**Blockers**: None


### Session: 2026-04-27 08:03 - Wave A review fixes

**Why**: Self-review found 3 real bugs and 2 UX issues; fixing now keeps Wave A as a single coherent merge candidate rather than dragging review-feedback debt into Wave B.

**What changed**:
- Self-reviewed PR #242 (Wave A) and addressed 5 issues: misleading verbose tip in gate output replaced with explicit invocation; integrity baseline extended to events.py + contracts.py + settings.sh (closes audit/loader tampering hole); malformed JSON now distinct mismatch kind (compute_baseline refuses to persist malformed entries); R-XXX redesign IDs picked up by merge-gate feature regex (with contract + FEATURES.md checks correctly skipped); _contract_migrate --type validation rejects --type without --add-assertion. Added 5 tests.

**Next steps**:
- Wave A ready for external review

**Blockers**: None


### Session: 2026-04-27 09:22 - Sprint 2 / Wave A merged (PR #242 → 676985cb)

**Why**: Sprint 2 closed the two Tier 0 honest-limits documented post-sprint-1 (filesystem mutation of shipped contracts; hook tampering) and made gate failures self-documenting via the central message catalog. R-003 closed the merge-side hole. The hardening-before-polish ordering means Wave B's UX widgets land on a sealed base.

**Decision**: Squash-merge over fast-forward — sprint-1 precedent (single 'Merge sprint 1' commit). The 6 individual commits collapsed into 676985cb. Branch deleted on remote.

**What changed**:
- Tier 0 hardening cluster shipped. R-005 (chmod 444 on shipped contracts), R-012 (structured gate error catalog + --verbose), R-004 (hook integrity SHA-256 baseline w/ events.py + contracts.py + settings.sh covered), R-003 (ag merge local merge gate). Plus self-review fixes (5 issues addressed in fix(review) commit before merge). Enforcement hierarchy now 8 layers; 50 deterministic tests + 846 validate_framework ACs all green on main.

**Next steps**:
- Wave B unblocked: R-009 ag watch (2d), R-013 ag intel report --quota (2d), R-006 GHA template (1d), R-010 ag fix --skip-contract (2d), R-011 ag onboard (3d).

**Blockers**: None


### Session: 2026-04-27 09:31 - R-009 ag watch shipped

**Why**: SSH sessions need a lightweight observability frontend; TUI too heavy

**Decision**: Skip colorama dep; ANSI codes work natively on supported terminals

**What changed**:
- Color-coded events.jsonl tail; stdlib + ANSI; filter/since/once flags; 34 tests pass

**Next steps**:
- R-013 quota report next

**Blockers**: —


### Session: 2026-04-27 09:35 - R-013 quota report shipped

**Why**: Pro/Max quota awareness needed before Tier 2/3 work to avoid burnout

**Decision**: Window-based rate (not instantaneous) for projection — more stable and conservative

**What changed**:
- ag intel report --quota; rolling 5h window; per-tier+per-model breakdown; alerts at 70/85/95%; linear projection; --json output; 22 tests pass

**Next steps**:
- R-006 GHA template next

**Blockers**: —


### Session: 2026-04-27 09:38 - R-006 GHA template shipped

**Why**: Multi-contributor repos and compliance need GitHub-side enforcement; local hooks aren't shared across clones

**Decision**: Belt-and-suspenders only — Tier 0 already strong; mirror catches gaps, doesn't replace

**What changed**:
- agentic-gate.yml runs precommit+prepush in CI mirror; uploads logs+verification.json; PR comment on failure only; docs/CI_MIRROR.md; cmd_init surfaces template

**Next steps**:
- R-010 ag fix next

**Blockers**: —


### Session: 2026-04-27 09:42 - R-010 ag fix shipped

**Why**: Hotfixes need a fast path that doesn't bypass safety — only ceremony

**Decision**: Skip spec+plan only; tests/migrations/integrity stay required

**What changed**:
- ag fix "<msg>"; AGENT_FIX_MODE=1 skips check_contracts and check_plan_approved; preserves test/journal/integrity/migration; emits hotfix_commit event on success; [hotfix] footer; 9 tests

**Next steps**:
- R-011 ag onboard next

**Blockers**: —


### Session: 2026-04-27 09:46 - R-011 ag onboard shipped

**Why**: Multi-contributor projects need a fast cold-start path; current state isn't self-explanatory

**Decision**: Generate-from-current-state, not hand-curated; People section is hand-edited stub

**What changed**:
- ag onboard generates .agentic/ONBOARDING.md from STACK/FEATURES/STATUS/ADR/journal; --force overwrite; -o output; 5-min walkthrough; precommit gate references it; 12 tests

**Next steps**:
- Instruction file sync next

**Blockers**: —


### Session: 2026-04-27 09:49 - Wave B instruction sync

**Why**: Memory-seed and instruction files are how features reach agents in user projects

**Decision**: Same one-liner pattern in every instruction file (consistent with Wave A)

**What changed**:
- Updated CLAUDE.md (template+root), .cursorrules, copilot, codex, cursor template, memory-seed.md with R-006/R-009/R-010/R-011/R-013; flipped redesign-backlog statuses to shipped; STATUS.md current focus updated

**Next steps**:
- PR creation

**Blockers**: —


### Session: 2026-04-27 13:25 - Wave B review fixes

**Why**: Self-review found medium issue (projection denominator) + 5 minor/trivial; user asked to fix all

**Decision**: Active-span denominator with 60s floor — closer to 'current rate' intuition while protecting against tiny-N nonsense projections

**What changed**:
- Issue 1: quota projection uses min(window, now-earliest_record_ts) with 60s floor — bursty workloads now project sooner. Issue 2: print_blocked takes project_root (no subprocess on failure path). Issue 3: onboard restores strict mode before python heredoc + checks file written. Issue 4: 7 new bash dispatcher smoke tests for fix.sh + watch.sh. Issue 5: drop unused jsonschema from CI mirror. Issue 6: soften R-110 reference in 70% advice.

**Next steps**:
- Push to PR #243

**Blockers**: —


### Session: 2026-04-27 16:25 - Wave B — UX + observability cluster

**Why**: Tier 0 enforcement is real but not visible enough — Wave B closes the lightweight observability + new-contributor + emergency-path gaps so contributors can see what the gate is doing, what tokens are doing, and have an audited fast-path for genuine emergencies

**Decision**: Stdlib-only for new analysis modules (zero new runtime deps); CI mirror is belt-and-suspenders opt-in (not required); hotfix mode skips ceremony but not safety; quota uses active-span not full-window for projection denominator

**What changed**:
- Framework gained four user-facing commands (ag watch for SSH-friendly events.jsonl tail; ag intel report --quota for Pro/Max usage; ag fix for emergency commits with audited skip; ag onboard for new-contributor playbook) plus an opt-in GitHub Actions CI mirror. Quality bar moved: hotfix mode skips spec/plan but explicitly keeps tests + migrations + integrity (skip-narrowly, not skip-everything). Quota projection uses active-span (max(window_start, earliest_record_ts)) with a 60s floor — corrects a bursty-vs-steady misjudgement found in self-review. Pre-commit gate's failure path no longer shells out to git rev-parse for a value GateContext already holds. Onboard now fails loud on substitution errors instead of silently writing empty ONBOARDING.md.

**Next steps**:
- Phase 0 wrap (R-014 TUI quota ring, R-015 ag hooks register, R-016 bypass test battery) before Phase 1 opens

**Blockers**: —


### Session: 2026-04-27 16:39 - No-autorecord rule applies to user projects too

**Why**: User asked whether the rule applies to production projects — yes; multi-contributor projects benefit from the same logic since auto-memory is per-user/per-machine and invisible to teammates

**Decision**: Template carries shared concerns (dogfooding); root extends with framework-specific destinations only (FRAMEWORK_DEVELOPMENT, PRINCIPLES). Rule is not duplicated across layers.

**What changed**:
- Hoisted the no-autorecord rule from framework-dev wrapper into the canonical template (.agentic/lib/agents/claude/CLAUDE.md) so user projects receive it. Propagated the same one-liner into .cursorrules + cursor template, copilot-instructions + template, codex template, and memory-seed.md. Root CLAUDE.md no longer duplicates the rule — points at template instead, with a note that 'project' reads as 'framework' for framework dev.

**Next steps**:
- —

**Blockers**: —


### Session: 2026-04-28 04:50 - R-016 plan v6 APPROVED

**Why**: Original R-016 attack list lifted verbatim from sibling close-out-hardening doc that proposed surfaces (.close-out-pending sentinel, PreToolUse path-deny, content classification, state_enforcement levels) Phase 0 (R-001..R-015) didn't ship — only 2/12 attacks cleanly mapped

**Decision**: Preserve 12-test budget; realign composition to Phase 0 surfaces; six rounds of dialectical review until convergence in round 6 (zero new architectural bugs)

**What changed**:
- Phase 0 verification battery plan converged after six rounds of dialectical review. Composition: 12 attack-vectors × 3 profiles = 36-cell pass/fail matrix targeting Phase 0 Tier 0 surfaces (R-001..R-010). Test budget preserved from original; attack-vector list realigned to actual surfaces. Manifest-driven pass criteria (known-fails.yaml) ensures FAILs are linked deterministically. Six rounds surfaced 13 architectural bugs total; round 6 found zero new bugs and converged. One pre-existing R-001/R-004 limitation documented as out-of-scope (unbaselined .agentic/hooks/* shim).

**Next steps**:
- Begin Day-1 implementation — battery.sh scaffold helpers + run_battery.sh orchestrator skeleton

**Blockers**: None


### Session: 2026-04-28 06:31 - R-016 battery implementation complete (Day 1-5)

**Why**: Plan-approved sentinel was missing pre-commit; framework profile is autonomous_formal so AC3 enforces; sentinel touched after dialectical review v6 marked plan APPROVED. Commit 1 went through gate cleanly (validate_framework.sh: 846 PASS); commit 2 needed fresh JOURNAL after HEAD advanced.

**Decision**: Two-commit split: implementation (19 files) + state integration (3 files) — cohesive groups; matches recent sprint-style commit pattern in the repo

**What changed**:
- All 12 B-tests + 6 seeders + scaffold + orchestrator + day1_stub implemented. Final dry-run: 36-cell matrix, 34 PASS + 2 SKIP-by-design + 0 FAIL. Commit b91943cb captures the work. Pre-existing framework bug surfaced and worked around: ag contract list f-string mangled by bash interpolation in contract.sh:405 — needs separate followup, not R-016 scope. STACK.md location bug fixed during day1_stub run (write to root, not .agentic/). Pyyaml runtime dep documented in README.

**Next steps**:
- Stage commit 2 (backlog status + run_tests.sh opt-in integration); review; merge along with sibling journal-skill commits per branch-mixing decision

**Blockers**: None


### Session: 2026-04-28 07:27 - R-016 review-driven hardening

**Why**: Review identified that stderr-text matching was fragile against messages.py wording changes; seeder failures masked root causes; per-cell python3 -c was unnecessary subprocess overhead; AGENT_FIX_MODE leak risk; signal-kill /tmp accumulation; ANSI escapes ignored NO_COLOR

**Decision**: Pivot B-test pass criterion from prose-grep to structured gate_blocked event payload.failures — survives messages.py drift; assertion is now content-addressed by AC ID, not text

**What changed**:
- PR #244 self-review found 3 high + 3 medium fragility issues. v6 implementation hardened: B-tests now assert blocking via gate_blocked event payload.failures (AC-ID match) instead of grepping stderr prose; seeders bubble explicit SEED_FAIL context; env hygiene catches AGENT_FIX_MODE leaks; cleanup trap covers INT/TERM/HUP signals; results JSON batched into single python pass at end of run; NO_COLOR + non-tty respected for emitted output. Final verification: 36/36 cells unchanged (34 PASS + 2 SKIP-by-design + 0 FAIL).

**Next steps**:
- Push fixup commit; PR ready for human review/merge

**Blockers**: None


### Session: 2026-04-28 08:18 - R-016 shipped — Phase 0 verification battery on main

**Why**: Original R-016 in redesign-backlog had B01-B12 attack list copy-pasted from sibling close-out-hardening doc; only 2/12 attacks cleanly mapped to Phase 0 surfaces. Plan revision realigned attack vectors to declared deps. Six rounds of dialectical Critic+Advocate review surfaced 13 architectural bugs total before convergence.

**Decision**: Realign attack vectors to declared dependencies (preserve 12-test budget; swap composition); structured event assertions (not stderr text) for AC matching; manifest-driven pass criteria for FAILs

**What changed**:
- PR #244 squash-merged as 1dbca588. Phase 0 closeout's largest single deliverable: adversarial test suite proves Tier 0 catches each documented bypass attempt cross-profile. 12 × 3 = 36-cell pass/fail matrix targeting R-001/R-002/R-004/R-005/R-010 surfaces. Manifest-driven pass criteria via known-fails.yaml — orchestrator exits 2 on unlisted FAILs. Each B-test annotated with code-path-traced reference to the gate function:line it should trigger; structured event assertions (gate_blocked.payload.failures AC-ID match) survive messages.py wording changes. Co-shipped: journal-shape rule in committing-changes skill + no-autorecord rule hoisted into the canonical template (propagates to cursor/copilot/codex/memory-seed). VERSION bumped 0.84.0 → 0.84.1.

**Next steps**:
- Phase 0 closeout: R-014 (TUI quota burn-down ring) + R-015 (ag hooks register) remain. Then Phase 1 — R-101 Token Ledger visible — opens.

**Blockers**: None


### Session: 2026-04-28 09:03 - PR #241 merged — V5 contributions backfilled

**Why**: PR was open since 2026-04-26 with conflicts after Wave A/B merges; user asked to merge before starting R-014/R-015

**What changed**:
- Resolved STATUS.md + JOURNAL.md conflicts (kept main's current-state line; chronologically inserted PR's 19:31 entry before main's 19:56+ entries). Squash-merged as c694c84c. CONTRIBUTIONS.md gained the V5 ARCHITECTURAL DECISION section (5 threads, 20 insights from real-world failures, M.A. audit, Claude arch PDF, transform-vs-greenfield, iterative pushback).

**Next steps**:
- Begin R-014 (TUI quota burn-down ring) per Phase 0 closeout plan

**Blockers**: —


### Session: 2026-04-28 09:12 - R-014 shipped: TUI quota burn-down ring + alerts

**Why**: Phase 0 closeout cluster — R-014 surfaces the quota signal R-013 already computes; without it, autonomous runs hit Pro/Max limits with no visual warning. Pairs with R-008 ag tui as the user-facing observability layer.

**Decision**: Frozen-dataclass HeaderSnapshot extended with by_tier dict (default_factory). Ring char + color emitted as Rich markup so single header_lines() function serves both the Textual widget (renders color) and tests (substring check). Modal abort routes to existing action_abort no-op pending R-209 signal-to-PID wiring — keeps R-014 scope tight.

**What changed**:
- Header now renders a colored Unicode quarter-circle ring (○◔◐◕●) next to the percentage, with thresholded color (green<70 / yellow<85 / dark_orange<95 / red≥95). Tooltip on header shows by-tier token breakdown. New ModalScreen fires once per 95% episode (rising-edge logic with ack-suppression and reset-on-fall) and routes to existing action_abort hook. State.py extended with _by_tier accumulation from token-ledger 'tier' field.

**Next steps**:
- R-015 ag hooks register next (1d) — last item before Phase 0 closes

**Blockers**: —


### Session: 2026-04-28 09:36 - R-015 shipped: ag hooks register/unregister + auto-install on ag init

**Why**: Phase 0 closeout — fresh installs needed a one-shot 'arm Tier 0' command. Without it, projects that cloned the framework had to either know about core.hooksPath OR manually copy the launcher shims. Pairs with R-004 (integrity baseline) so register leaves the project in a verified state, not just hooked.

**Decision**: register/unregister write directly to .git/hooks/ (transparent, immediately visible via 'ls .git/hooks/') rather than core.hooksPath redirection (the F-0300 'install' transport remains for shared-repo workflows). Both transports are preserved — projects pick whichever fits. Test sandbox copies the framework lib into a tmp git repo and runs ag end-to-end (mirrors test_merge_gate.sh pattern).

**What changed**:
- New ag hooks register subcommand writes the canonical pre-commit + pre-push shim launchers directly to .git/hooks/, backs up any divergent existing hooks under .git/hooks/.backup-<ts>/, then refreshes the R-004 integrity baseline. Idempotent — second run is a no-op. ag hooks unregister restores the most recent backup (or removes shims cleanly when no backup exists). cmd_init now invokes register on both the already-initialized fast path and the guidance path, so fresh installs and re-runs both end with hooks armed. cmd_hooks moved out of operations.sh into its own commands/hooks.sh; install/status/disable preserved alongside the new subcommands.

**Next steps**:
- Phase 0 closeout complete (R-001..R-016). Phase 1 R-101 (Token Ledger visible) opens.

**Blockers**: —


### Session: 2026-04-28 13:00 - PR #246 review fixes — addressed all 11 issues

**Why**: External review of PR #246 surfaced 11 actionable issues (4 R-014, 7 R-015) covering modal latency, falsy-coalesce, tooltip cadence, format-change doc, AC1 deviation, idiom, race window, atomicity, init UX, baseline semantics, test fragility. Each addressed in place; tests extended; no behavioural regressions.

**Decision**: _hooks_dir always returns .git/hooks/ (matches AC1 literally; install/F-0300 remains the dedicated transport for core.hooksPath workflows). Modal trigger moved to fast tick — same snapshot data, lower latency, no extra cost. Header panel split into text vs tooltip update methods (cheap text rebuild stays at 0.5s; tooltip per-tier sort/% math at 30s). Atomic shim writes use sibling temp + mv to preserve prior state on crash mid-write.

**What changed**:
- R-014: modal trigger moved from 30s to 0.5s tick (catches 95% rising edge promptly); HeaderPanel split into update_from (text, every 0.5s) + update_tooltip_from (heavier by-tier math, every 30s); 0.0 falsy-coalesce replaced with explicit None check; format-change docstring added with regex migration hint. R-015: dropped core.hooksPath redirect from _hooks_dir (AC1 literal); replaced diff -q <(cat) with diff -q -; backup-dir now timestamp+pid+seq; atomic shim writes via temp+mv; cmd_init silent on no-op via new _hooks_already_registered helper; explicit design-choice comment block on unregister + integrity update; AC3 test parses JSON structurally; new AC6b test covers the silent path.

**Next steps**:
- PR review pass complete. Ready for re-review + merge.

**Blockers**: —


### Session: 2026-04-28 13:32 - Phase 0 manual smokes deferred to post-V5

**Why**: User asked to document the smoke procedures for later. The two manual checks couldn't run in the merge-time container (need pip install textual + a fresh sandbox); deferring is acceptable since deterministic tests + 846 ACs cover the structural correctness.

**What changed**:
- Captured both manual verifications (R-014 Textual ring/modal, R-015 ag hooks register against fresh project) in tests/smoke/phase-0-manual-smoke.md with expected-behaviour tables. T-0098 added with trigger condition + background + related links per the TODO-context rule.

**Next steps**:
- Squash-merge PR #246 when ready; smokes will run after the full V5 refactoring is shipped

**Blockers**: —


### Session: 2026-04-28 13:35 - PR #246 merged — Phase 0 closeout shipped (R-014 + R-015)

**Why**: User asked to merge after the review pass + smoke-test deferral was documented; PR was MERGEABLE/CLEAN, 846 framework ACs + 35 TUI tests + 8 hooks tests all green, no other active sessions.

**Decision**: Squash-merge over fast-forward — Wave A/B/R-016 precedent. The 4 individual commits (R-014, R-015, 11-issue review pass, smoke doc) collapsed into cb9af7ca. Manual smokes intentionally deferred since the merge-time agent container can't run pip install textual or a fresh-project sandbox; Phase 1 work doesn't depend on the smokes.

**What changed**:
- Squash-merged as cb9af7ca. R-014: colored quarter-circle quota ring (○◔◐◕●) + by-tier tooltip + 95%-rising-edge ModalScreen on the ag tui header. R-015: ag hooks register/unregister + auto-install on ag init. R-014 modal trigger lives on the 0.5s tick (≤0.5s latency to fire); HeaderPanel split into update_from (text, 0.5s) + update_tooltip_from (tooltip, 30s + once on mount). R-015 _hooks_dir always returns .git/hooks/ literally (matches AC1; install/F-0300 remains the dedicated core.hooksPath transport); atomic shim writes via temp+mv; backup-dir naming includes pid+seq for collision safety; cmd_init silent on no-op via _hooks_already_registered. Phase 0 (R-001..R-016) feature-complete.

**Next steps**:
- Phase 1 (R-101 — Token Ledger visible) opens. Update STATUS focus + memory-seed if relevant; manual smokes deferred to post-V5 per T-0098.

**Blockers**: —


### Session: 2026-04-28 15:32 - R-101 plan APPROVED

**Why**: Original R-101 backlog spec said reads token-ledger.jsonl (Deps: R-007). Reality: events.append_token_ledger() exists in R-007 ship but no production code calls it; the JSONL doesn't exist. Phase 1 voluntary-use test fails for a report showing zeros; per no-feature-inflation rule, hardening goes on R-101 not a new R.

**Decision**: Expand R-101 scope from read-only (2d) to emission+read+TUI (5d). Defer rename of .agentic/journal/token-ledger.jsonl to disambiguate from F-041's .agentic/session/token-ledger.json — that cascades through R-007/R-013/R-014 and is its own R-NNN.

**What changed**:
- Converged after 3 rounds of dialectical review. Round 1 found 3 HIGH + 5 MEDIUM (fictional AGENTS.json contract, undocumented stdin contract, weak verification gates, cache_creation accounting drift, Ctrl+C data leak, etc.). Round 2 found 1 new HIGH (false 'stale stub' claim about live F-041 file at .agentic/session/token-ledger.json that Stop.sh:80-104 actively writes) + 1 MEDIUM + 3 LOW. Round 3 found 0 HIGH + 0 MEDIUM + 3 LOW (all implementation-time cleanups). Architecture (Stop-hook emitter + watermark + read-side projection + TUI fold-in) survived intact across all rounds. Plan: 5d, 5 commits, includes emission to close the spec gap that R-101 originally assumed away.

**Next steps**:
- Implementation: feat/R-101-token-ledger-visible branch; commit boundaries documented in plan; G1-G5 verification gates

**Blockers**: None


### Session: 2026-04-28 15:49 - R-101 commit 1: emitter + attribution

**Why**: v3 plan approved 2026-04-28 after 3 rounds of dialectical review; emission was the missing link in the R-007/R-013/R-014 token ledger pipeline.

**What changed**:
- Shipped Components 1+4 of R-101: .agentic/lib/hooks/token_emit.py with Stop-hook + SessionStart-recovery entry points; current_feature() resolves via gitBranch primary then AGENTS.json by worktree then None; tokens_in carries pure input_tokens (no cache_creation summed) per quota.py:228 convention; schema-drift defensive logging emits token_emit_schema_change events. 12 unit tests cover all 6 fixture cases plus concurrency + watermark prune; all pass plus events.py 18 tests pass.

**Next steps**:
- Commit 2: register hooks in .claude/hooks.json + integrity baseline regen

**Blockers**: None


### Session: 2026-04-28 16:41 - R-101 commit 2: hook registration + integrity baseline

**Why**: v3 plan G4 numbered procedure: edit hooks → integrity update → stage all → commit succeeds. Naming-collision note: integrity.json baselines events.py (which we modified in commit 1) but does NOT baseline the new claude-hooks shims (R-004 only baselines .agentic/lib/hooks/*.py and .claude/hooks.json itself; shim shell scripts are out of scope). hooks.json change is captured.

**What changed**:
- Registered Stop-token-emit and SessionStart-token-recover shims in .claude/hooks.json (composed alongside existing Stop.sh and SessionStart.sh — telemetry shims always exit 0 so they don't affect existing enforcement). Ran ag integrity update to capture new baseline. End-to-end smoke test on the active session transcript: 242 records emitted, all tier1, single sessionId, sensible token sums (412 net-new input, 271K output, 45M cache reads — the cache-savings story is now visible in the ledger).

**Next steps**:
- Commit 3: ag intel report --tokens reader extending quota.py with session + rolling-30 projection

**Blockers**: None


### Session: 2026-04-30 20:09 - R-101 commit 3/5

**Why**: ACs 1-3 of R-101 explicitly required current-session + rolling-30 + breakdowns; commits 1+2 only fed the ledger, the report side was still empty

**What changed**:
- Read-side ag intel report --tokens lands. quota.build_token_report() streams the ledger once, aggregates per session, returns rolling-N. intel.sh --tokens wires through. Golden-master fixture (8 records, 3 sessions, pinned now) plus 16 new tests in test_token_report.py guard the M1 cache_creation accounting from regressing.

**Next steps**:
- Commit 4/5: TUI tokens line in header.py

**Blockers**: None


### Session: 2026-04-30 20:13 - R-101 commit 4/5

**Why**: Five-panel layout had to stay intact; folding into header.py was cheaper than adding a sixth panel

**What changed**:
- TUI header now shows the R-101 view: a second line with Session / Roll (N sess) / Top feature beneath the existing R-014 quota ring. State.py grew per-session aggregation bounded by a 30-session window with O(1) prune. Header CSS switched to height: auto so the panel collapses back to one line when no token data has been ingested.

**Next steps**:
- Commit 5/5: instruction file updates

**Blockers**: None


### Session: 2026-04-30 20:17 - R-101 commit 5/5

**Why**: Per instruction-files-are-part-of-the-feature: a new ag command must reach all agents to be useful

**What changed**:
- Instruction-file sync. Added ag intel report --tokens to: CLAUDE.md (root + template), cursorrules (root + template), copilot-instructions.md (.github + template), codex-instructions.md (template), memory-seed.md (quick commands + tokens trigger word), CHANGELOG.md Unreleased. The view is now discoverable from every agent surface.

**Next steps**:
- PR: open feat/R-101-token-ledger-visible PR; doc gate via ag done post-merge bumps VERSION

**Blockers**: None


### Session: 2026-05-01 08:50 - R-101 review fixups

**Why**: Independent review surfaced real correctness gaps; fixing on the same PR keeps the audit trail clean rather than merging known-buggy

**What changed**:
- Round-1 review found 5 issues: HIGH regex missed R-XXX prefixes (this PR's own branch dogfooded the bug — smoke test showed Top (untagged) 43K). MEDIUM watermark temp+rename invalidated flock semantic across writers. MEDIUM _safe_event swallowed all telemetry failures silently. LOW no-ts session exclusion, LOW --report break. All fixed: regex now matches schema's full {F,R,DEV,E,NFR}-N pattern; watermark write now in-place truncate+write under flock; _safe_event writes one stderr line on failure; docstring + CHANGELOG nits added. Three new regression tests: test_feature_attribution_branch_redesign_prefixes, test_watermark_concurrency_no_lost_updates (8 workers × 50 iters = 400 RMWs, no lost updates), test_safe_event_warns_to_stderr_when_telemetry_fails.

**Next steps**:
- Push fixup to PR #247; await CI mirror

**Blockers**: None


### Session: 2026-05-01 15:22 - Statusline (R-101 follow-up)

**Why**: User asked for status bar with ctx + 5h + week + project + branch + task; framework-wide install path was the right place since the statusline benefits all users running ag hooks register

**What changed**:
- Added Claude Code statusline showing project / branch / ctx % / 5h % reset / wk % reset / current task. statusline.py reads transcript_path for ctx %, quota.compute_quota for both windows, STATUS.md/AGENTS.json/git-log for task. statusline.sh shim runs as Claude Code's statusLine command. ag hooks register/install both auto-merge the snippet into .claude/settings.json (preserves existing permissions/mcpServers/customStatusLine; --force-statusline overrides). Documented quota_pro_max_weekly_tokens setting in STACK.template.md. Five live smoke scenarios verified including missing transcript / empty stdin / non-git cwd graceful paths.

**Next steps**:
- Push to PR #247; manual visual verification after Claude Code restart

**Blockers**: None


### Session: 2026-05-02 20:27 - R-101 statusline review fixup

**Why**: Per-prompt CPU on the statusline path matters because Claude Code calls it on every render — fixing now beats fixing after ledger growth surfaces lag in user reports

**What changed**:
- Independent review of HEAD 9f8bf1bd flagged one HIGH perf issue: statusline.quota_summary called compute_quota then re-iterated the ledger to find earliest_record_ts — two full passes per quota window, four per prompt with both 5h and 7d ceilings configured. At 100K records that's user-visible lag. Other findings (watermark crash safety, concurrent reads, regex correctness, env-var passing in heredoc, gitignore behavior) verified as already-correct. Fix: added earliest_record_ts to QuotaReport, captured during compute_quota's existing loop, statusline.quota_summary now reads the field instead of re-iterating. Two new regression tests in test_quota.py guard the value.

**Next steps**:
- Push to PR #247; await re-review

**Blockers**: None


### Session: 2026-05-03 16:22 - Statusline zero-config rate limits

**Why**: Framework users were not seeing any rate-limit info in the bar because STACK.md ceilings were never set; ledger-based projection was an estimate while Anthropic now ships exact values in the rate_limits envelope. Also: project name showed as 'workspace' inside Docker, hiding the actual repo name.

**Decision**: Drop the ledger-based statusline path; keep ledger for ag intel analytics. Single bar segment for rate limits. ANSI dim only on the freshness trailer.

**What changed**:
- Statusline now reads rate_limits straight from Claude Code envelope (no STACK.md ceilings needed). New format: 'N% 5h, M% 7d - reset HH:MM, Day HH:MM TZ (updated at main agent response)' with the trailer ANSI-dimmed. Project label now derived from git remote.origin.url so the bar shows 'agentic-framework' inside Docker mounts (was 'workspace'). 16 new tests covering blob parsing, dimmed trailer, shared-TZ reset block, repo-name fallback chain. Token ledger + STACK ceilings stay intact for ag intel report --quota/--tokens.

**Next steps**:
- Open PR

**Blockers**: None


### Session: 2026-05-14 09:23 - Statusline zero-config rate limits merged

**Why**: R-101 follow-up landed; ledger-based rate limits required STACK.md ceilings and didn't work for fresh users — envelope-based source removes that prerequisite.

**What changed**:
- PR #248 merged to main: statusline now reads rate_limits directly from Claude Code envelope (zero-config for users), groups percentages and reset times under one TZ label, dim-anchors the 'last main-agent response' caveat, adds an active-model segment, and uses git remote URL for repo name so Docker mounts show the real project. 7 files changed, 484 insertions, 127 deletions; 303 new test lines.

**Next steps**:
- Run ag flush to land VERSION bump + state files on main

**Blockers**: None


### Session: 2026-05-14 10:11 - T-0078: ag done subprocess env leak fix

**Why**: 5 phantom test failures because paths.sh:36-42 honors inherited ROOT_DIR, so subprocesses spawned by ag done's verification ran against the caller's project root instead of the sandbox

**Decision**: Scope to two named leak points; do NOT touch operations.sh:511 (verify-contracts.sh legitimately needs ROOT_DIR for cross-checkout invocations) or paths.sh precedence (R-209 territory). File parent-boot poisoning as T-0100 follow-up rather than expand scope.

**What changed**:
- Scrubbed framework-internal env vars (ROOT_DIR/PROJECT_ROOT/MAIN_PROJECT_ROOT/AGENTIC_ROOT/AGENTIC_LIB/AGENTS_JSON + defensive FRAMEWORK_ROOT) at the two subprocess boundaries where ag done dispatches user verify commands: legacy-markdown branch (operations.sh:546) and YAML contract branch (contracts.py:513-525). Added tests/test_subprocess_env_isolation.sh with 8 regression checks covering both paths plus the cross-checkout sanity case (verify-contracts.sh:511 still honors explicit ROOT_DIR override).

**Next steps**:
- Land PR, verify the 5 phantom functional failures resolve, pick up T-0100 (verify-contracts.sh:66 parent-boot poisoning follow-up) if reproducible.

**Blockers**: Pre-existing VERSION drift (root=0.85.1 vs lib=0.84.3) shows in validate_framework.sh; unrelated to this fix.


### Session: 2026-05-14 20:04 - T-0094 investigation deferred

**Why**: User flagged that /workspace JSONL evidence pre-dates current framework version; conclusion would be premature

**Decision**: Defer rather than file as bug or claim a fix — re-probe after v5 with same instrumentation

**What changed**:
- Partial probe inside /workspace container corroborated original observation (banner from on-plan-mode-exit.sh missing in 4 ExitPlanMode sessions) but data pre-dates current Mac framework + CC version. Removed from BACKLOG.json, kept TODO.md entry with retest angles. Backlog advances to T-0023.

**Next steps**:
- After v5 lands, retest with current framework + current CC (try hooks in .claude/settings.json, watch .cache/tool_use_counter + framework.log)

**Blockers**: v5 still in progress — investigation premature


### Session: 2026-05-14 21:04 - T-0023: smarter memory-seed sync

**Why**: Original script was a no-op (path bug), and even when it fired the stale advisory said 'go re-read the file' — high behavioral burden for the agent and prone to silent drift

**Decision**: Section-anchor-keyed diff via comments (<!-- section: slug -->) over header-text matching; renames now produce MODIFY blocks rather than REMOVE+ADD churn

**What changed**:
- Fixed three latent bugs in memory-check.sh (wrong SEED_FILE path, --show-toplevel vs --git-common-dir, missing version marker) and added structured PATCH output via new memory-diff.sh. Section anchors (<!-- section: slug -->) let the diff treat renames as MODIFY instead of REMOVE+ADD. Migration entry M-001 on F-022 adds AC-004/AC-005.

**Next steps**:
- Run ag commit and PR

**Blockers**: ag contract migrate unavailable in container (no pyyaml); migration applied by hand mirroring the tool's structure


### Session: 2026-05-16 16:33 - T-0023: review fixes

**Why**: Reviewer ran independent fresh-context review; my own tests passed but didn't catch any of these because they were too permissive

**What changed**:
- Code review found 3 blockers: grep -c bug producing '0\n0', GNU-only find -printf breaks on macOS, F-022 migration violated contract.schema.json (id pattern + dict-vs-string changes). Fixed all three plus a missing section anchor on '## Documentation', tightened the shell test with a fixture-pair sanity check, and tightened the LLM test to require numbered PATCH refs + Edit old_string/new_string semantics.

**Next steps**:
- Push to PR #250

**Blockers**: None


### Session: 2026-08-23 10:16 - Repo archived — v6 rebuild moved to agentic-af-for-claude

**Decision**: Archive this repo; v6 = new repo agentic-af-for-claude, Claude Code-first, ~2.5k LOC budget, CI-as-wall, derived state, shipped=code+tests+docs match spec

**What changed**:
- Reviewed the framework end-to-end (3 explorer agents), concluded with the repo's own retrospectives that ~90% of complexity compensated for 2025-era agent unreliability now handled natively by Claude Code. User approved a ground-up v6 rebuild in a new repo (github.com/tomgun/agentic-af-for-claude): extract-and-rebuild from specs/lessons, never porting code. Extraction shipped: VISION.md (full value inventory from PRINCIPLES/OVERVIEW/ADR-002/CONTRIBUTIONS), CAPABILITIES.md (disposition of every capability incl. NFR/ADR/feedback/epics — nothing dropped silently), ANTIPATTERNS.md (14 evidence-cited hard rules), spec format + F-001..F-014 seeds, BACKLOG queue, founding plan with 2-round multi-agent review record (critic/advocate/platform panel).

**Next steps**:
- All further work happens in the new repo; sessions start there. This repo is read-only design history.

**Blockers**: None

