<!-- migration-id: 020 -->
<!-- date: 2026-03-24 -->
<!-- author: Tomas Günther -->
<!-- type: feature -->

# Migration 020: Re-categorize DEV-0199 to dev-infrastructure under DEV-0001

## Context & Why

DEV-0199 (Instruction File Integrity) is framework development tooling, not a user-facing
capability. Introduced the DEV-XXXX namespace for development infrastructure items.
DEV-0199 is now grouped under the DEV-0001 parent container with Type: infrastructure.

## Changes

### Features Modified

- DEV-0199: Category changed from `agent-system` → `dev-infrastructure`; added `parent: DEV-0001`,
  `tags: [infrastructure, internal]`. No assertions changed — only metadata.

## Dependencies

- **Requires**: DEV-0001 contract + FEATURES.md section (same commit)
- **Blocks**: None
- **Related**: DEV-0122 (migration 019), DEV-0243 (migration 021)

## Acceptance Criteria

- [x] DEV-0199 has `parent: DEV-0001` in contract YAML
- [x] DEV-0199 has `category: dev-infrastructure` in contract YAML
- [x] DEV-0199 listed under DEV-0001 children in FEATURES.md

## Rollback Plan

1. Revert category to `agent-system`, remove `parent` and `tags` fields from DEV-0199.yaml
2. Update FEATURES.md: remove Type/Parent annotation from DEV-0199 entry
