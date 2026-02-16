# Start Feature Implementation Prompt (Formal Mode)

I want to implement feature **F-[XXXX]** (replace with actual feature ID).

Please follow this workflow:

1. **Read the feature spec:**
   - Check `spec/FEATURES.md` for F-[XXXX]
   - Read acceptance criteria at `spec/acceptance/F-[XXXX].md`
   - Check dependencies and related features

2. **Test-Driven Development (TDD):**
   - Write tests FIRST based on acceptance criteria
   - Start with unit tests for core logic
   - Add integration tests if feature involves multiple components
   - Run tests to confirm they FAIL (red phase)

3. **Implementation:**
   - Write minimal code to make tests pass (green phase)
   - Follow programming standards in `.agentic/workflows/programming_standards.md`
   - Add code annotations (`@feature F-[XXXX]`, `@acceptance AC1`)
   - Refactor for clarity and maintainability

4. **Update specs as you go:**
   - Update `spec/FEATURES.md`:
     - Change status: planned → in_progress
     - Update implementation state: none → partial
     - Add code file paths
     - Update test coverage: todo → partial → complete
   - Keep acceptance criteria file in sync

5. **Before marking complete:**
   - All acceptance criteria met
   - Tests pass (unit + integration + acceptance)
   - Code reviewed for quality
   - Documentation updated

6. **Update JOURNAL.md:**
   - Log progress, decisions, and any challenges

---

**Reminders:**
- Follow `.agentic/checklists/implementing_feature.md`
- Keep commits atomic and descriptive
- Update documentation in same commit as code
- If stuck or need human decision, add to `HUMAN_NEEDED.md`

