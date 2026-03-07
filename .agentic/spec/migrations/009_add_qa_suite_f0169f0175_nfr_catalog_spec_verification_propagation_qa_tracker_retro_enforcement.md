<!-- migration-id: 009 -->
<!-- date: 2026-03-07 -->
<!-- author: Tomas -->
<!-- type: feature -->

# Migration 009: QA Suite (F-0169–F-0175)

## Context & Why

LLMs produce code and tests that look correct but may be subtly wrong — tests that assert nothing meaningful, acceptance criteria with vague language, NFRs that were never discussed. This epic adds formal quality assurance: NFR discovery, spec verification ("who tests the tests?"), change propagation tracking, and retrospective enforcement.

## Changes

### Features Added

- F-0169: NFR Discovery & Catalog — type-specific NFR suggestions during init
- F-0170: NFR Enforcement in Spec Writing — active matching, promotion detection
- F-0171: Spec Verification Tool — multi-layer audit (structural, coverage, heuristics, LLM review)
- F-0172: Change Propagation Pipeline — trace NFR/migration changes downstream
- F-0173: QA Tracker State Machine — persistent tracking with escalation
- F-0174: Retrospective Enforcement — settings-based, proactive triggers
- F-0175: Glue & Documentation — feature registration, version bump

### NFRs Added

- NFR-0003: Small batch commits
- NFR-0004: Spec-first development

### Settings Added (profiles.conf + STACK template)

- retrospective_enabled: Discovery=no, Formal=yes
- qa_propagation_warn_days: 3
- qa_propagation_escalate_days: 7
- qa_audit_freshness_days: 30

## Dependencies

- **Requires**: None
- **Blocks**: None
- **Related**: F-0147 (spec-writing workflow), F-0131 (settings-over-profiles)

## New Files

- `.agentic/lib/init/nfr-catalog.md` — NFR suggestions by project type
- `.agentic/lib/tools/spec-audit.sh` — Verification + propagation tool
- `.agentic/lib/tools/qa-tracker.sh` — QA state machine
- `.agentic/lib/tools/test-review-prompt.md` — LLM test review template
- `.agentic/spec/acceptance/F-0169.md` through `F-0175.md`
- `.agentic/spec/acceptance/NFR-0003.md`, `NFR-0004.md`

## Modified Files

- `.agentic/lib/init/init_playbook.md` — Step 2c NFR Discovery
- `.agentic/lib/init/memory-seed.md` — NFR proactive + "who tests the tests?" triggers
- `.agentic/lib/workflows/spec_writing.md` — Active NFR matching + promotion
- `.agentic/lib/checklists/spec_writing.md` — NFR gate with sub-checkboxes
- `.agentic/lib/checklists/feature_start.md` — Gate 1 NFR compliance check
- `.agentic/lib/checklists/feature_complete.md` — NFR verification
- `.agentic/lib/checklists/retrospective.md` — Spec audit + NFR review + propagation sections
- `.agentic/lib/workflows/retrospective.md` — Sections 3.5 and 3.6
- `.agentic/lib/checklists/session_start.md` — QA tracker status
- `.agentic/lib/tools/retro_check.sh` — Settings framework refactor + --status
- `.agentic/lib/tools/periodic-checks.sh` — QA health + retro action items checks
- `.agentic/lib/hooks/pre-commit-check.sh` — Advisory propagation warning
- `.agentic/lib/tools/ag.sh` — audit + nfr commands
- `.agentic/lib/presets/profiles.conf` — New QA settings
- `.agentic/lib/init/STACK.template.md` — New QA settings section
- `.agentic/lib/agents/claude/skills/completing-work/SKILL.md` — Step 6 retro check
- `.claude/skills/completing-work/SKILL.md` — Step 6 retro check
- `.agentic/spec/NFR.md` — NFR-0003, NFR-0004
- `.agentic/spec/FEATURES.md` — F-0169 through F-0175

## Rollback Plan

1. Revert commit
2. Remove new files listed above
3. Settings are backwards-compatible (new settings have defaults)
