---
command: /session-start
description: Start new session with context loading
---

# Session Start Prompt

I'm starting a new coding session on this project, which uses the Agentic AI Framework.

Please help me get oriented by:

1. Reading `.agentic/STATUS.md` for current project state and focus
2. Checking `.agentic/HUMAN_NEEDED.md` for any blockers requiring my attention
3. Reviewing recent work in `JOURNAL.md` (last 2-3 entries)
4. Checking `.agentic/session/WIP.md` for any interrupted work
5. For Formal mode: Check for active features in `.agentic/spec/FEATURES.md` (status: in_progress)

Then show ONLY a concise dashboard — no preamble text, no "let me check", no narration of what you're reading. The dashboard is the first thing I see. Include:
- Where we left off
- Any blockers or decisions needed
- What makes sense to work on next
- Suggested next steps to pick from

---

**Framework Guidelines:**
- Follow `.agentic/lib/agents/shared/agent_operating_guidelines.md`
- Use checklists in `.agentic/lib/checklists/`
- Prioritize Test-Driven Development (write tests first)
- Keep documentation (JOURNAL.md, STATUS.md, specs) updated in the same commit as code
- Run quality checks before committing

