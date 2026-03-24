<!-- migration-id: 022 -->
<!-- date: 2026-03-24 -->
<!-- author: Tomas Günther -->
<!-- type: feature -->

# Migration 022: Reopen F-0184 for Phase 1b

## Context & Why

F-0184 was marked shipped after Phase 1a (schema + core code). Phase 1b (epic.py + commands) is the next planned PR per the approved plan. Reopening to implementing to continue the work.

## Changes

### Features Modified

- F-0184: Reopened from shipped → implementing for Phase 1b
  - Dotted ID allocation in decompose (F-XXX.1, F-XXX.2)
  - extract_subfeature() for AC extraction
  - Depth guards (MAX_DEPTH=2)
  - component: field replaces tags: pattern
  - ag contract check --recursive
  - ag contract create --parent

## Dependencies

- **Requires**: Phase 1a (shipped in PR #203)
- **Blocks**: Phase 2 (renumber)
- **Related**: F-0004 (Feature Tracking)

## Acceptance Criteria

- [x] Decompose produces dotted child IDs
- [x] Depth guard prevents over-nesting
- [x] extract_subfeature moves ACs to child
- [x] Contract check --recursive works
- [x] 70 tests passing

## Rollback Plan

1. Revert this commit
2. Mark F-0184 as shipped in FEATURES.md
