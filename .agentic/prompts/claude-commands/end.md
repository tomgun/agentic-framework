---
command: /end
description: End session with proper documentation
---

I'm wrapping up this work session.

Please follow the session end workflow from `.agentic/prompts/claude/session_end.md`.

Specifically:

1. Update `JOURNAL.md` with session summary
2. Update `STATUS.md` or `PRODUCT.md` with current state
3. Update `spec/FEATURES.md` if in Core+PM mode
4. Check if anything should go in `HUMAN_NEEDED.md`
5. Generate fresh `.continue-here.md`: `python3 .agentic/tools/continue_here.py`
6. Verify git status is clean (or explain uncommitted changes)
7. Provide session summary:
   - What was accomplished
   - What's ready for next session
   - Any important notes

Then ask if I'm ready to commit (if there are uncommitted changes).

