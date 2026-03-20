<!-- migration-id: 017 -->
<!-- date: 2026-03-20 -->
<!-- author: Claude -->
<!-- type: evolution -->

# Migration 017: Evolve F-0138/F-0139/F-0207 — Concrete 3-Concern Doc Decision Tree in Skill Instructions

## Context & Why

Documentation updates (project docs AND instruction files) were skipped 20+ times despite rules existing in 3+ places. Root cause: the shipped specs for F-0138 (Doc Impact Tracking), F-0139 (Doc Lifecycle System), and F-0207 (Project Doc Lifecycle) specified the *tooling* (`docs.sh`, `drift.sh`, `docs_gate`) but never specified what the *skill instructions* should say to agents.

The implementing-features skill Step 6 was a single line: `docs.sh --check-freshness`. The before_commit.md doc section was a generic list. Both were too vague for agents to follow concretely — they'd read the instruction, not know exactly which files to check, and skip it.

The insight: "docs" means two things and agents conflate them: (1) project documentation (CHANGELOG, HOW_IT_WORKS, etc.) and (2) instruction files (CLAUDE.md, cursorrules, etc.). The skill instructions need to separate these explicitly with file paths.

## Changes

### Features Modified

- **F-0138**: Add ACs for skill instruction concreteness — implementing-features Step 6 must have 3 sub-steps with explicit file paths, not just "run docs.sh"
- **F-0139**: Add ACs for registry maintenance in skills — agents must check for new/moved/deleted docs in the registry, not just read it
- **F-0207**: Add ACs for before_commit.md backstop and completing-work verification — same 3-concern structure must appear in commit-time and completion-time checklists

## Dependencies

- **Requires**: F-0138, F-0139, F-0207 (shipped)
- **Blocks**: None
- **Related**: F-0237 (memory-seed optimization)

## Acceptance Criteria

### F-0138 Evolution — Skill Instruction Concreteness

- [x] **AC-017**: implementing-features Step 6 has 3 concrete sub-steps: 6a (project docs via registry), 6b (registry maintenance), 6c (instruction files — framework dev only)
- [x] **AC-018**: Step 6a explicitly lists common `feature_done` docs by path (HOW_IT_WORKS, INSTRUCTION_ARCHITECTURE, DEVELOPER_GUIDE, OVERVIEW, FRAMEWORK_WORKFLOW)
- [x] **AC-019**: Step 6a distinguishes `feature_done` vs `pr` trigger docs (pr docs noted for commit time, not updated during implementation)
- [x] **AC-020**: Step 6c is conditional on `FRAMEWORK_DEVELOPMENT.md` existence (auto-detects framework dev context)
- [x] **AC-021**: Step 6c lists exact file paths: 5 Quick Commands files, 4 trigger table files, help.sh, memory-seed.md

### F-0139 Evolution — Registry Maintenance in Skills

- [x] **AC-022**: implementing-features Step 6b instructs: new doc → register it, changed component with no doc → decide if needed, deleted/moved doc → update registry
- [x] **AC-023**: completing-work Step 5b verifies registry maintenance was done (new docs registered in STACK.md `## Docs`)

### F-0207 Evolution — Backstop and Completion Verification

- [x] **AC-024**: before_commit.md "Documentation Sync" section uses same 3-concern structure as implementing-features Step 6
- [x] **AC-025**: before_commit.md explicitly checks `pr`-triggered docs at commit time (CHANGELOG, README, CONTRIBUTIONS)
- [x] **AC-026**: before_commit.md instruction files concern lists exact file paths (same as Step 6c)
- [x] **AC-027**: completing-work Step 5b verifies all 3 concerns (registry docs, registry maintenance, instruction files)
- [x] **AC-028**: FRAMEWORK_WORKFLOW.md added to docs registry in STACK.md `## Docs` with trigger `feature_done`

## Implementation Notes

All ACs already implemented in commit `e190577`. This migration documents the spec evolution retroactively.

## Rollback Plan

1. Revert implementing-features Step 6 to single-line `docs.sh --check-freshness`
2. Revert before_commit.md to separated "Documentation Sync" + "Framework Development Only" sections
3. Revert completing-work Step 5b to simple `--check-freshness` call
4. Remove FRAMEWORK_WORKFLOW.md from STACK.md `## Docs`

## Related Files

- `.claude/skills/implementing-features/SKILL.md` — Step 6 rewritten (6a/6b/6c)
- `.claude/skills/committing-changes/references/before_commit.md` — Documentation Sync rewritten as 3-concern backstop
- `.claude/skills/completing-work/SKILL.md` — Step 5b expanded to verify all 3 concerns
- `STACK.md` — FRAMEWORK_WORKFLOW.md added to `## Docs` registry
