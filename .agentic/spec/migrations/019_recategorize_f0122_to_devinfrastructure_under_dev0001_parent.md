<!-- migration-id: 019 -->
<!-- date: 2026-03-24 -->
<!-- author: Tomas Günther -->
<!-- type: feature -->

# Migration 019: Re-categorize F-0122 to dev-infrastructure under DEV-0001

## Context & Why

F-0122 (Testing Infrastructure) is framework development tooling, not a user-facing
capability. Introduced the DEV-XXXX namespace for development infrastructure items.
F-0122 is now grouped under the DEV-0001 parent container with Type: infrastructure.

## Changes

### Features Modified

- F-0122: Category changed from `quality` → `dev-infrastructure`; added `parent: DEV-0001`,
  `tags: [infrastructure, internal]`. No assertions changed — only metadata.

## Dependencies

- **Requires**: DEV-0001 contract + FEATURES.md section (same commit)
- **Blocks**: None
- **Related**: F-0199 (migration 020), F-0243 (migration 021)

## Acceptance Criteria

- [x] F-0122 has `parent: DEV-0001` in contract YAML
- [x] F-0122 has `category: dev-infrastructure` in contract YAML
- [x] F-0122 listed under DEV-0001 children in FEATURES.md

## Rollback Plan

1. Revert category to `quality`, remove `parent` and `tags` fields from F-0122.yaml
2. Update FEATURES.md: remove Type/Parent annotation from F-0122 entry
