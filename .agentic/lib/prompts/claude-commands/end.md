---
command: /end
description: End session with proper documentation
---

I'm wrapping up this work session.

Please follow the session end workflow from `.agentic/lib/checklists/session_end.md`.

Specifically:

1. Update `JOURNAL.md` with session summary
2. Update `.agentic/STATUS.md` with current state and next steps
3. Update `.agentic/spec/FEATURES.md` if in Formal mode
4. Check if anything should go in `.agentic/HUMAN_NEEDED.md`
5. Verify git status is clean (or explain uncommitted changes)
6. Provide session summary:
   - What was accomplished
   - What's ready for next session
   - Any important notes

Then ask if I'm ready to commit (if there are uncommitted changes).

