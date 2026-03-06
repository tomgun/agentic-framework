<!-- migration-id: 007 -->
<!-- date: 2026-03-06 -->
<!-- author: agent -->
<!-- type: feature -->

# Migration 007: Add F-0164 Tiered Verify Loop

## Context & Why

New feature extending the autonomous verify loop with multi-tier test execution. Projects can declare multiple named test tiers (unit, integration, e2e, etc.) in STACK.md, each with its own fix loop.

## Changes

### Features Added

- F-0164: Tiered Verify Loop
  - Multi-tier STACK.md parsing (Test commands: section)
  - Per-tier fix loops with configurable timeout and max iterations
  - Fast-fail by default, continue_on_failure per tier
  - Playwright and Cypress output parsers
  - Tier-specific Claude fix prompts (unit vs e2e)
  - --tier CLI filter flag
  - Full backward compatibility with single-tier projects

## Dependencies

- **Requires**: F-0161
- **Blocks**: None
- **Related**: F-0160

## Acceptance Criteria

- [x] 14 acceptance criteria defined and verified (see F-0164.md)
- [x] 40 new tests + 23 existing tests pass

## Related Files

- `.agentic/spec/acceptance/F-0164.md` - New acceptance criteria file
- `.agentic/spec/FEATURES.md` - F-0164 registered
- `.agentic/lib/auto/verify.py` - Core implementation
- `tests/test_auto_verify_tiers.py` - New test file
