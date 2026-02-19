# STATUS.md

<!-- format: status-v0.1.0 -->

Purpose: the living "truth" of where the Agentic Framework development is today.

## Current session state
- F-0139: Doc Lifecycle System — implementation complete, tests passing (Updated: 2026-02-19 18:59 EET)

## Current focus
- Infrastructure validation tests shipped (v0.25.6, PR #27)
- Three-layer enforcement proven: git hooks + CLAUDE.md triggers + memory seed

## In progress
- PR #27 awaiting review (infrastructure validation tests)

## Next up
- Run infrastructure LLM tests (`bash tests/infrastructure/run.sh --with-llm`)
- Run interactive memory tests (`bash tests/infrastructure/run.sh --interactive`)
- Real-world project validation (non-framework project)

## Known issues / risks
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
