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

