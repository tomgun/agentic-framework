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

## Documentation sync (required)
Check these files are accurate and current:
- [ ] **CONTEXT_PACK.md** accurately reflects current codebase state
  - "Where to look first" includes all created entry points
  - No "(Not yet created)" or "(To be created)" placeholders remain for completed work
  - "Current top priorities" matches actual next steps from STATUS.md
  - "Architecture snapshot" reflects current structure
- [ ] **STATUS.md** shows current phase and completed work
  - "Current focus" is accurate
  - "In progress" lists only active work (completed items removed or moved)
  - "Next up" reflects actual priorities
  - "Current session state" updated if mid-implementation
- [ ] **FEATURES.md** (spec/FEATURES.md) status matches implementation reality
  - Feature `Status` changed appropriately (planned → in_progress → shipped)
  - `Implementation: State` matches actual progress (none → partial → complete)
  - `Implementation: Code` field lists actual file paths
  - `Tests` fields reflect test coverage reality (todo → partial → complete)
  - `Verification: Accepted` is 'yes' only if tested and working


