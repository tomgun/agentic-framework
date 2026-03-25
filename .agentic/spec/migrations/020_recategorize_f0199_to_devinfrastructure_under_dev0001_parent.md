<!-- migration-id: 020 -->
<!-- date: 2026-03-24 -->
<!-- author: Tomas Günther -->
<!-- type: feature -->

# Migration 020: Re-categorize DEV-003 to dev-infrastructure under DEV-001

## Context & Why

DEV-003 (Instruction File Integrity) is framework development tooling, not a user-facing
capability. Introduced the DEV-XXXX namespace for development infrastructure items.
DEV-003 is now grouped under the DEV-001 parent container with Type: infrastructure.

## Changes

### Features Modified

- DEV-003: Category changed from `agent-system` → `dev-infrastructure`; added `parent: DEV-001`,
  `tags: [infrastructure, internal]`. No assertions changed — only metadata.

## Dependencies

- **Requires**: DEV-001 contract + FEATURES.md section (same commit)
- **Blocks**: None
- **Related**: DEV-002 (migration 019), DEV-004 (migration 021)

## Acceptance Criteria

- [x] DEV-003 has `parent: DEV-001` in contract YAML
- [x] DEV-003 has `category: dev-infrastructure` in contract YAML
- [x] DEV-003 listed under DEV-001 children in FEATURES.md

## Rollback Plan

1. Revert category to `agent-system`, remove `parent` and `tags` fields from DEV-003.yaml
2. Update FEATURES.md: remove Type/Parent annotation from DEV-003 entry
