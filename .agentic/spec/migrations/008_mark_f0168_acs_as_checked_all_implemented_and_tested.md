<!-- migration-id: 008 -->
<!-- date: 2026-03-07 -->
<!-- author: Tomas Gunther -->
<!-- type: feature -->

# Migration 008: Mark F-0168 ACs as checked (all implemented and tested)

## Context & Why

F-0168 (Visual Verification — screenshot collection + AI visual review) was
implemented and all 13 acceptance criteria passed testing. This migration
records the spec-to-shipped transition: all ACs marked [x] in F-0168.md
and status changed to `shipped` in FEATURES.md.

## Changes

### Features Modified

- F-0168: Visual Verification & Screenshot Collection
  - All 13 ACs marked as checked (implemented and tested)
  - Status changed from `in_progress` to `shipped`

## Acceptance Criteria

- [x] F-0168.md has all 13 ACs checked
- [x] FEATURES.md shows F-0168 as shipped

## Implementation Notes

Shipped as part of v0.45.0 (PR #66). Includes screenshot collection,
AI visual review via Anthropic API, --visual CLI flag, and E2E
scaffolding docs.

## Rollback Plan

1. Revert F-0168.md AC checkboxes to unchecked
2. Change FEATURES.md F-0168 status back to in_progress

## Related Files

- `.agentic/spec/acceptance/F-0168.md` — ACs marked checked
- `.agentic/spec/FEATURES.md` — Status changed to shipped
