# Test strategy (technology-agnostic)

## Goals
- Catch regressions quickly (fast unit tests).
- Validate integration points (slower integration tests).
- Validate user-visible behavior where needed (acceptance/E2E).

## Test pyramid (default)
- Unit: most tests, fast, deterministic
- Integration: fewer, cover boundaries (DB/network/FS) - see `.agentic/quality/integration_testing.md`
- Acceptance/E2E: smallest set, cover critical flows

## What counts as a “unit”
- A unit is a component with **controlled dependencies** (mocked/faked).
- If a test requires network/DB/real filesystem by default, it’s not a unit test.

## Principles
- Deterministic and isolated: no reliance on time/network/global state.
- Clear assertions: test one behavior, one reason to fail.
- Prefer contract tests at boundaries (see `.agentic/quality/integration_testing.md` for details).

## Test data management
- Use factories for variable test data (builders, random but seeded)
- Use fixtures for read-only reference data
- Keep tests isolated - clean up between tests
- Document test data strategy in `STACK.md`

## Naming & placement
- Keep tests near code or in a dedicated `tests/` folder—pick one convention and note it in `STACK.md`.
- Prefer a consistent naming scheme so agents can find tests quickly.


