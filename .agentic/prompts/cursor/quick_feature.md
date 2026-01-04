# Quick Feature Implementation Prompt (Core Mode)

I want to implement a small feature: **[brief description]**

Please follow this streamlined workflow for Core mode:

1. **Plan briefly:**
   - What needs to be built?
   - What are the acceptance criteria (informal)?
   - Any technical considerations?

2. **Test-Driven Development (TDD):**
   - Write tests FIRST
   - Cover: happy path, edge cases, error handling
   - Run tests to confirm they FAIL

3. **Implement:**
   - Write minimal code to pass tests
   - Follow programming standards (`.agentic/workflows/programming_standards.md`)
   - Keep it simple and maintainable

4. **Verify:**
   - All tests pass
   - Run linter/formatter
   - Quick manual test if applicable

5. **Update `PRODUCT.md`:**
   - Add new feature to list
   - Update current focus/status
   - Note any technical decisions

6. **Update `JOURNAL.md`:**
   - Log what was implemented
   - Note any challenges or insights

7. **Commit:**
   - Descriptive commit message
   - Include code + tests + docs together

---

**Core Mode Philosophy:**
- Lighter process than Core+PM
- No formal specs, but still maintain quality
- `PRODUCT.md` is your single source of truth
- TDD ensures quality without heavy process
- Documentation stays current

**If you need more structure:**
- Consider upgrading to Core+PM mode
- Adds feature tracking, acceptance criteria files, sequential pipelines
- Run: `bash .agentic/tools/upgrade_profile.sh`

