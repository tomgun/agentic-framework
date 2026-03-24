<!-- migration-id: 021 -->
<!-- date: 2026-03-24 -->
<!-- author: Tomas Günther -->
<!-- type: feature -->

# Migration 021: Ship F-0243 Complexity Tier Experiments

## Context & Why

F-0243 (Complexity Tier Experiments) is a new research item under DEV-0001.
Shipping the initial contract with 3 structural assertions covering the harness
implementation (tier_experiment.py, complexity_tiers.yaml, auto.sh wiring).

## Changes

### Features Added

- F-0243: New contract shipped. Research item under DEV-0001.
  - AC-001: tier_experiment.py with TierMetrics dataclass
  - AC-002: complexity_tiers.yaml with 3 tiers + review_plan override
  - AC-003: ag auto tier-experiment wired in auto.sh

## Dependencies

- **Requires**: DEV-0001 (same commit)
- **Blocks**: None
- **Related**: F-0122 (migration 019), F-0199 (migration 020)

## Acceptance Criteria

- [x] F-0243 contract exists at spec/contracts/F-0243.yaml
- [x] F-0243 has lifecycle: shipped, parent: DEV-0001, tags: [research, internal]
- [x] All 3 assertions pass in validate_framework.sh

## Rollback Plan

1. Delete spec/contracts/F-0243.yaml
2. Update FEATURES.md: remove F-0243 entry or reset to planning state
