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


### Session: 2026-03-24 06:19 - Phase gate bypassed

**Why**: Incomplete phases overridden at shipping time

**What changed**:
- F-0193: --force-phases used. 

**Next steps**:
- TBD

**Blockers**: None


### Session: 2026-03-24 06:20 - Phase gate bypassed

**Why**: Incomplete phases overridden at shipping time

**What changed**:
- F-0193: --force-phases used. 

**Next steps**:
- TBD

**Blockers**: None


### Session: 2026-03-24 06:20 - Phase gate bypassed

**Why**: Incomplete phases overridden at shipping time

**What changed**:
- F-0193: --force-phases used. 

**Next steps**:
- TBD

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


### Session: 2026-03-27 18:46 - Phase gate bypassed

**Why**: Incomplete phases overridden at shipping time

**What changed**:
- F-035: --force-phases used. 

**Next steps**:
- TBD

**Blockers**: None


### Session: 2026-03-27 18:46 - Phase gate bypassed

**Why**: Incomplete phases overridden at shipping time

**What changed**:
- F-035: --force-phases used. 

**Next steps**:
- TBD

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

