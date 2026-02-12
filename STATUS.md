# STATUS.md

<!-- format: status-v0.1.0 -->

Purpose: the living "truth" of where the Agentic Framework development is today.

## Current session state
- Infrastructure validation tests implemented, 52/52 passing (Updated: 2026-02-12 15:21 EET)

## Current focus
- Domain categories + systematic brownfield spec generation (v0.25.0)

## In progress
- None

## Next up
- Re-run LLM tests with full 48-test suite to get updated pass rates
- Real-world project validation (non-framework)
- Consider progressive disclosure implementation
- Context7 MCP integration: test in real project scenario

## Backlog
- Apply mutation tests to framework LLM tests (validate tests catch real failures)
- Progressive disclosure of complexity
- Automated CI for LLM tests via Claude CLI

## Known issues / risks
- LLM tests run interactively (simulated) — need Claude CLI for fully automated runs
- Some CHANGELOG.md historical references point to old file locations (acceptable — historical records)

## Decisions needed
- None currently

## Release notes (optional)
- v0.25.0: Domain categories, `ag specs` brownfield pipeline, infra pattern detection, 3 new LLM tests, 16 new pytest tests
- v0.23.0: Three-layer architecture visibility, persistent artifacts consolidation, 30 LLM tests, settings functional tests
- v0.22.0: Instruction file slimdown ~70% (L-0002 fix), LLM test bug fixes, subagent context waste documented
- v0.21.0: Structural enforcement for durable artifacts, `status.sh infer`, 6 new artifact-maintenance LLM tests
- v0.20.0: Traceability overhaul, test consolidation, Context7 MCP update, KISS meta-principle
- See CHANGELOG.md for full history
