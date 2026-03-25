<!-- migration-id: 019 -->
<!-- date: 2026-03-24 -->
<!-- author: Tomas Günther -->
<!-- type: feature -->

# Migration 019: Re-categorize DEV-002 to dev-infrastructure under DEV-001

## Context & Why

DEV-002 (Testing Infrastructure) is framework development tooling, not a user-facing
capability. Introduced the DEV-XXXX namespace for development infrastructure items.
DEV-002 is now grouped under the DEV-001 parent container with Type: infrastructure.

## Changes

### Features Modified

- DEV-002: Category changed from `quality` → `dev-infrastructure`; added `parent: DEV-001`,
  `tags: [infrastructure, internal]`. No assertions changed — only metadata.

## Dependencies

- **Requires**: DEV-001 contract + FEATURES.md section (same commit)
- **Blocks**: None
- **Related**: DEV-003 (migration 020), DEV-004 (migration 021)

## Acceptance Criteria

- [x] DEV-002 has `parent: DEV-001` in contract YAML
- [x] DEV-002 has `category: dev-infrastructure` in contract YAML
- [x] DEV-002 listed under DEV-001 children in FEATURES.md

## Rollback Plan

1. Revert category to `quality`, remove `parent` and `tags` fields from DEV-002.yaml
2. Update FEATURES.md: remove Type/Parent annotation from DEV-002 entry
