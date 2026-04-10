---
command: /start
description: Start new session with context loading
---

I'm starting a new work session on this project.


Specifically:

1. Silently load essential context (CONTEXT_PACK, STATUS/PRODUCT, JOURNAL, HUMAN_NEEDED)
2. Silently check for:
   - Blockers in HUMAN_NEEDED.md
   - In-progress work from last session
   - Features awaiting acceptance
3. Show ONLY the dashboard — no preamble text, no "let me check...", no narration. The dashboard is the first thing I see.
4. Include suggested next steps to pick from

**If Claude hooks are enabled**: Session context may have been auto-injected, so acknowledge that and proceed from there.

