# F-0186: Autonomous Scheduler — Implementation Plan

**Status**: APPROVED
**ADR**: ADR-001, Phase 7, Section 3
**Dependencies**: F-0182 (Critical Review Agent) ✓, F-0184 (Epic Decomposition) ✓

## Architecture

### New file: `.agentic/lib/auto/scheduler.py`

`AutonomousScheduler` class that implements the scheduling loop from ADR-001:

1. Query `get_unblocked()` — features with available forward transitions
2. Filter to epic's children (when running `ag auto epic F-XXXX`)
3. Skip features with pending reviews (non-blocking)
4. For each unblocked feature, spawn component-scoped worker via `TaskRunner`
5. Worker executes next transition; if review blocks → record, continue
6. When critical agent escalates → HUMAN_NEEDED entry + continue
7. When all features blocked on review → report status + wait/poll
8. When human resolves review → feature becomes unblocked again
9. Repeat until all features shipped or max errors

### Modified file: `.agentic/lib/auto/crunch.py`

AC-004: Evolve into scheduler-backed execution. `CrunchRunner.run()` delegates
to `AutonomousScheduler` for the scheduling loop. Single rewrite — crunch becomes
a thin wrapper that creates a scheduler and calls `scheduler.run()`.

### Modified file: `.agentic/lib/tools/ag.sh`

Add `ag auto epic F-XXXX` subcommand under `cmd_auto()`.

### New file: `tests/test_scheduler.py`

Unit tests covering all 9 ACs.

## Key Interfaces Used

- `FeatureStateMachine.get_unblocked()` → unblocked features
- `ComponentRegistry.get()` → component for worker scoping
- `review.has_pending_review()` / `review.get_pending_reviews()` → review status
- `spawn_claude()` → spawn worker agents
- `query_features.get_children()` → epic children
- `blocker.sh` → HUMAN_NEEDED entries for escalations
- `TaskRunner` → per-feature implementation
- `EngineState` → pause/stop control

## Files Modified

1. `.agentic/lib/auto/scheduler.py` (new)
2. `.agentic/lib/auto/crunch.py` (evolve)
3. `.agentic/lib/tools/ag.sh` (add epic subcommand)
4. `tests/test_scheduler.py` (new)
5. `.agentic/spec/acceptance/F-0186.md` (check ACs as implemented)
