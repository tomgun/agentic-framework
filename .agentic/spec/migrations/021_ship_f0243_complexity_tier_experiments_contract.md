<!-- migration-id: 021 -->
<!-- date: 2026-03-24 -->
<!-- author: Tomas Günther -->
<!-- type: feature -->

# Migration 021: Ship DEV-004 Complexity Tier Experiments

## Context & Why

DEV-004 (Complexity Tier Experiments) is a new research item under DEV-001.
Shipping the initial contract with 3 structural assertions covering the harness
implementation (tier_experiment.py, complexity_tiers.yaml, auto.sh wiring).

## Changes

### Features Added

- DEV-004: New contract shipped. Research item under DEV-001.
  - AC-001: tier_experiment.py with TierMetrics dataclass
  - AC-002: complexity_tiers.yaml with 3 tiers + review_plan override
  - AC-003: ag auto tier-experiment wired in auto.sh

## Dependencies

- **Requires**: DEV-001 (same commit)
- **Blocks**: None
- **Related**: DEV-002 (migration 019), DEV-003 (migration 020)

## Acceptance Criteria

- [x] DEV-004 contract exists at spec/contracts/DEV-004.yaml
- [x] DEV-004 has lifecycle: shipped, parent: DEV-001, tags: [research, internal]
- [x] All 3 assertions pass in validate_framework.sh

## Rollback Plan

1. Delete spec/contracts/DEV-004.yaml
2. Update FEATURES.md: remove DEV-004 entry or reset to planning state
