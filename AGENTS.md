# AGENTS.md

> **Note**: This file is a REFERENCE document. It is NOT auto-loaded by AI tools.
> The auto-loaded files (CLAUDE.md, .cursorrules, etc.) point to this file.

This repo uses the **Agentic Framework** located at `.agentic/`.

## Non-negotiables

**Document blockers immediately:**
- When you identify something requiring human action (install dependency, make decision, access credentials), ADD IT TO `HUMAN_NEEDED.md` IMMEDIATELY
- Don't just mention it in chat - document it so it's not forgotten

**Keep documentation current:**
- Update `.agentic-journal/JOURNAL.md` before ending ANY session (if session ends abruptly, JOURNAL is the only record)
- Keep `OVERVIEW.md` up to date with vision and completed capabilities
- Keep `CONTEXT_PACK.md` current when architecture changes
- If this repo uses the Formal profile: keep `STATUS.md` and `/spec/*` truthful

**Code quality:**
- Add/update tests for new or changed logic
- Run smoke tests before claiming features work
- Separate business logic from UI for testability

## Full Guidelines

See `.agentic/agents/shared/agent_operating_guidelines.md`

## Tool-Specific Files

These are auto-loaded by your AI tool:
- **Claude Code**: `CLAUDE.md`
- **Cursor**: `.cursorrules`
- **GitHub Copilot**: `.github/copilot-instructions.md`

To regenerate: `bash .agentic/tools/setup-agent.sh all`
