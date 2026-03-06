<!-- migration-id: 006 -->
<!-- date: 2026-03-06 -->
<!-- author: agent -->
<!-- type: feature -->

# Migration 006: Extend F-0161 with F-0164 reference

## Context & Why

F-0164 (Tiered Verify Loop) extends F-0161 (Autonomous Verify Mode) with multi-tier test execution. The F-0161 acceptance file needs a cross-reference to its extension.

## Changes

### Features Modified

- F-0161: Added "Extended by F-0164" reference at bottom of acceptance criteria file. No criteria changed — additive note only.

## Acceptance Criteria

- [x] F-0161 acceptance criteria unchanged (no removals or modifications)
- [x] Cross-reference to F-0164 added

## Related Files

- `.agentic/spec/acceptance/F-0161.md` - Added extension reference
