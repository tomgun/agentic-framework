<!-- migration-id: 023 -->
<!-- date: 2026-03-28 -->
<!-- author: Tomas Günther -->
<!-- type: feature -->

# Migration 023: Reopen F-033 to add auto-sync scope (formerly F-034)

## Context & Why

F-034 (Project Customization Auto-Sync) was identified as feature inflation — auto-sync
during upgrades is part of making the customization layer (F-033) actually work, not a
separate capability. F-034 scope folded into F-033; F-033 reopened to deliver it.

## Changes

### Features Modified

- F-033: Added auto-sync scope — upgrade.sh detects unmodified vs customized local files,
  replaces unmodified templates, preserves customized files with .new for review.
  Added AC-008, AC-009, AC-010. Status: shipped → in-progress.

### Features Deprecated

- F-034: Removed. Scope absorbed into F-033.

## Acceptance Criteria

- [x] upgrade.sh contains local customization sync step (AC-008)
- [x] upgrade.sh creates missing extension subdirectories (AC-009)
- [x] upgrade.sh preserves customized files with .new (AC-010)

## Rollback Plan

1. Revert upgrade.sh Step 5a
2. Re-add F-034 to FEATURES.md and BACKLOG.json
3. Restore F-033 contract to pre-auto-sync state
