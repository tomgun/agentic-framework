<!-- migration-id: 010 -->
<!-- date: 2026-03-07 -->
<!-- author: Tomas Günther -->
<!-- type: feature -->

# Migration 010: Add auto-propagation ACs to F-0172 and F-0173 (implemented but not originally specified)

## Context & Why

During PR #68 code review, we found that `migration.sh create` and `nfr.sh` both auto-call
`qa-tracker.sh add-propagation` for affected features. This behavior was implemented in F-0172
and F-0173 but not captured in their acceptance criteria. Adding ACs to match implementation.

## Changes

### Features Modified

- F-0172 (Change Propagation Pipeline):
  - AC-005: `migration.sh create` auto-calls `qa-tracker.sh add-propagation` for affected features
  - AC-006: `nfr.sh` status update auto-calls `qa-tracker.sh add-propagation` for referencing features
  - Removed "Automatic propagation item creation on migration.sh" from Out of Scope
- F-0173 (QA Tracker State Machine):
  - AC-013: `migration.sh create` auto-creates propagation items via `qa-tracker.sh`
  - AC-014: `nfr.sh` status update auto-creates propagation items via `qa-tracker.sh`

## Dependencies

- **Requires**: Migration 009 (QA suite)
- **Blocks**: None
- **Related**: F-0172, F-0173

## Acceptance Criteria

- [x] F-0172 acceptance file has AC-005 and AC-006
- [x] F-0173 acceptance file has AC-013 and AC-014
- [x] Out of Scope sections updated

## Implementation Notes

ACs document behavior already implemented in `nfr.sh` (lines 139-148) and `migration.sh` (propagation hook).
F-0172 AC-005/006 and F-0173 AC-013/014 moved from `## NFR Compliance` to `## Acceptance Criteria` section (structural fix — these are functional ACs, not NFR items).

## Rollback Plan

1. Revert AC-005/AC-006 from `.agentic/spec/acceptance/F-0172.md`
2. Revert AC-013/AC-014 from `.agentic/spec/acceptance/F-0173.md`

## Related Files

- `.agentic/spec/acceptance/F-0172.md` — Added AC-005, AC-006
- `.agentic/spec/acceptance/F-0173.md` — Added AC-013, AC-014
