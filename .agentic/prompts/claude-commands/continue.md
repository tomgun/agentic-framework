---
command: /continue
description: Resume work from .continue-here.md checkpoint
---

I want to resume work on this project.

Please:

1. Check if `.continue-here.md` exists
2. If yes: Read it and present a summary of:
   - Where we left off
   - Current focus
   - Active blockers
   - Recommended next steps
3. If no: Generate it now with `python3 .agentic/tools/continue_here.py`, then read it

Then ask me what I'd like to work on.

---

**Context files to check:**
- `.continue-here.md` (primary)
- `HUMAN_NEEDED.md` (blockers)
- `JOURNAL.md` (recent history)
- `STATUS.md` or `PRODUCT.md` (current state)

