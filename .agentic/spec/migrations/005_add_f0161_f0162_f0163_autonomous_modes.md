<!-- migration-id: 005 -->
<!-- date: 2026-03-06 -->
<!-- author: Tomas -->
<!-- type: feature -->

# Migration 005: Add F-0161, F-0162, F-0163 Autonomous Modes

## Context & Why

Implements the three autonomous execution modes that build on the F-0160 engine foundation:
- F-0161: Verify mode (test-fix loop)
- F-0162: Task mode (single-feature implementation)
- F-0163: Crunch mode (multi-feature batch)

## Changes

### Features Added

- F-0161: Autonomous Verify Mode (shipped, 7 ACs)
- F-0162: Autonomous Task Mode (shipped, 9 ACs)
- F-0163: Autonomous Crunch Mode (shipped, 7 ACs)

## Related Files

- `.agentic/spec/acceptance/F-0161.md` - Shipped (7 acceptance criteria)
- `.agentic/spec/acceptance/F-0162.md` - Shipped (9 acceptance criteria)
- `.agentic/spec/acceptance/F-0163.md` - Shipped (7 acceptance criteria)
- `.agentic/lib/auto/verify.py` - Test-fix loop engine
- `.agentic/lib/auto/task.py` - Single-feature runner
- `.agentic/lib/auto/crunch.py` - Multi-feature batch orchestrator
