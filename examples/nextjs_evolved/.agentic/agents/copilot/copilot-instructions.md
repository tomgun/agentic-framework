# GitHub Copilot instructions

This repo uses the `.agentic/` agentic development framework.

## Source of truth (read first)
- `AGENTS.md` (if present)
- `CONTEXT_PACK.md`
- `STATUS.md`
- `spec/OVERVIEW.md`
- `spec/FEATURES.md`
- `spec/NFR.md` (if constraints apply)
- `spec/acceptance/F-####.md` for the feature you are changing
- `/spec/*` and `spec/adr/*`
- `STACK.md` for how to run/test

## Behavior contract
- Follow `.agentic/agents/shared/agent_operating_guidelines.md`.
- Prefer small incremental changes with tests.
- After changes, update `STATUS.md` and relevant specs/ADRs.

## Developer UX
- Always state next steps and any questions/decisions needed.


