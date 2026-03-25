<!-- migration-id: 003 -->
<!-- date: 2026-03-06 -->
<!-- author: Tomas Günther -->
<!-- type: feature -->

# Migration 003: Initial spec creation for F-022, F-0158, F-0159

## Context & Why

v0.41.0 directory restructure was implemented across 3 phases before formal specs were created. Adding retroactive specs and acceptance criteria for the shipped features.

## Changes

### Features Added

- F-022: Directory Restructure & Tarball Distribution
  - Separates framework runtime (lib/) from project state
  - Tarball-based distribution for user projects
  - 16 acceptance criteria
- F-0158: Central Path Resolution
  - paths.sh/paths.py as single source of truth
  - Backward-compatible _resolve_path() helper
  - 12 acceptance criteria
- F-0159: Bootstrap & Thin Wrapper Mechanism
  - Auto-extraction from tarball, thin wrapper delegation
  - CI detection, STACK.md mode reading in pre-commit
  - 13 acceptance criteria

## Acceptance Criteria

- [x] F-022 spec and AC file created
- [x] F-0158 spec and AC file created
- [x] F-0159 spec and AC file created
- [x] Summary table updated with Architecture category

## Related Files

- `.agentic/spec/FEATURES.md` — 3 new feature entries + Architecture category
- `.agentic/spec/acceptance/F-022.md` — 16 ACs
- `.agentic/spec/acceptance/F-0158.md` — 12 ACs
- `.agentic/spec/acceptance/F-0159.md` — 13 ACs
