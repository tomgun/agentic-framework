# Definition of Done

Every change should satisfy:

## Correctness
- Behavior matches acceptance criteria.
- Edge cases considered (nulls/empties/errors/retries/time).

## Tests (required)
- Unit tests added/updated for new or changed logic.
- Tests are deterministic and fast.
- If the domain requires it, add appropriate non-unit tests (examples):
  - Web: request/response integration tests, UI acceptance tests
  - Mobile: simulator/device smoke tests, UI tests where critical
  - VST/JUCE: audio I/O golden tests, host automation tests, realtime/perf budget checks
  - Games: determinism/replay tests, perf budgets

## Maintainability
- Code is readable; complexity is justified.
- Public interfaces are documented where needed.

## Docs & project truth (required)
- `STATUS.md` updated to reflect reality.
- Specs updated if they changed, or an ADR created if a real decision was made.


