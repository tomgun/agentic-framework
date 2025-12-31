# AGENTS.md

This repo uses the agentic framework located at `agentic/`.

## Non-negotiables
- Add/update tests for new or changed logic.
- Keep `STATUS.md` current.
- Keep `/spec/*` truthful; write ADRs for real tradeoffs.

## Read-first (before coding)
- `CONTEXT_PACK.md`
- `STATUS.md`
- `spec/OVERVIEW.md`
- `spec/FEATURES.md`
- `spec/NFR.md` (if any constraints apply)
- The relevant acceptance file(s): `spec/acceptance/F-####.md`
- The relevant sections in `spec/PRD.md` and `spec/TECH_SPEC.md`
- `spec/LESSONS.md` and relevant `/adr/*` (if touching tricky areas)

Full rules: `agentic/agents/shared/agent_operating_guidelines.md`
