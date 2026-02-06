# STATUS.md

<!-- format: status-v0.1.0 -->

Purpose: the living "truth" of where the Agentic Framework development is today.

## Current session state
- v0.22.0 released (Updated: 2026-02-06)
- 171 acceptance tests passing, 0 failures
- Instruction files slimmed ~70% (L-0002 fix), LLM test bugs fixed

## Current focus
- Instruction slimdown shipped; verify LLM behavioral test improvements

## In progress
- None

## Next up
- Run LLM behavioral tests (`bash tests/llm/harness.sh --critical`) to confirm compliance improvement
- Consider progressive disclosure implementation (only partial claim from audit)
- Context7 MCP integration: test in real project scenario
- Install Claude CLI for fully automated LLM test runs

## Roadmap (lightweight)
- Near-term:
  - Test Context7 MCP server setup end-to-end
  - Real-world project validation (non-framework)
- Later:
  - Progressive disclosure of complexity (partial implementation)
  - More LLM tests for edge cases
  - Automated CI for LLM tests via Claude CLI

## Known issues / risks
- LLM tests run interactively (simulated) — need Claude CLI for fully automated runs
- Some CHANGELOG.md historical references point to old file locations (acceptable — historical records)

## Decisions needed
- None currently

## Release notes (optional)
- v0.22.0: Instruction file slimdown ~70% (L-0002 fix), LLM test bug fixes, subagent context waste documented
- v0.21.0: Structural enforcement for durable artifacts, `status.sh infer`, 6 new artifact-maintenance LLM tests
- v0.20.0: Traceability overhaul, test consolidation, Context7 MCP update, KISS meta-principle
- v0.19.0: Principles simplification (48→11), value proposition audit, 12 new LLM tests
- See CHANGELOG.md for full history
