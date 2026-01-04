---
command: /start
description: Start new session with context loading
---

I'm starting a new work session on this project.

Please follow the session start workflow from `.agentic/prompts/claude/session_start.md` or `.agentic/workflows/proactive_agent_loop.md`.

Specifically:

1. Load essential context (CONTEXT_PACK, STATUS/PRODUCT, JOURNAL, HUMAN_NEEDED)
2. Check for:
   - Blockers in HUMAN_NEEDED.md
   - In-progress work from last session
   - Features awaiting acceptance
3. Present session context with prioritized options
4. Ask what I'd like to focus on

**If Claude hooks are enabled**: Session context may have been auto-injected, so acknowledge that and proceed from there.

