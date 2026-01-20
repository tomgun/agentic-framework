---
command: /continue
description: Resume work - read project state and present options
---

I want to resume work on this project.

Please follow the session start checklist (`.agentic/checklists/session_start.md`):

1. **Check project phase** from `STATUS.md` or `PRODUCT.md`:
   - **Discovery**: Figuring out what to build (research, requirements, examples, designs)
   - **Building**: Iteratively building it (specs, designs, code, tests evolve together)

2. **Check for interrupted work**:
   ```bash
   bash .agentic/tools/wip.sh check
   ```

3. **Read current state** from `STATUS.md` or `PRODUCT.md`:
   - Project phase and focus
   - Current work in progress
   - Next steps planned

4. **Check for blockers** in `HUMAN_NEEDED.md`

5. **Present summary**:
   - Project phase: [discovery | building] - [focus]
   - Current focus: [what we're working on]
   - Progress: [what's done]
   - Blockers: [any items needing human input]

Then ask me what I'd like to work on.

---

**Context files to check:**
- `STATUS.md` or `PRODUCT.md` (project phase and current state)
- `HUMAN_NEEDED.md` (blockers)
- `JOURNAL.md` (recent history)
- `.agentic/WIP.md` (interrupted work detection)
