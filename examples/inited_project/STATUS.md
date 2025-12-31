# STATUS.md

Quick intent: the **project dashboard** (agent + human). Keep this current so resuming is effortless.

## Current focus
- Add persistence (localStorage) and simple filters (All/Active/Done).

## In progress
- F-0004 Persistence: store todos locally (planned next)

## Next up
- F-0005 Filters: All / Active / Done
- F-0006 Delete todo

## Roadmap (lightweight)
- Near-term:
  - F-0004 local persistence
  - F-0005 filters
  - F-0006 delete
- Later:
  - F-0007 E2E smoke test (Playwright)

## Known issues / risks
- No persistence yet (refresh loses state).

## Decisions needed
- Should we keep todos purely local, or add a backend?

## Release notes (optional)
- Initial demo supports: view/add/toggle todos.


