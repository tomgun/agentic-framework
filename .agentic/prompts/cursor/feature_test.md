# Create Tests for Feature Prompt (TDD Workflow)

I want to create tests for feature **F-[XXXX]** (replace with actual feature ID).

Please follow Test-Driven Development (TDD):

1. **Read acceptance criteria:**
   - Check `spec/acceptance/F-[XXXX].md` for all acceptance criteria
   - Understand success conditions and edge cases

2. **Create test structure:**
   - Set up test file(s) following project conventions
   - Organize tests by: happy path, edge cases, error handling
   - Follow naming conventions in `.agentic/workflows/testing_standards.md`

3. **Write test cases for:**
   - **Happy path**: Normal, expected usage
   - **Edge cases**: Boundary conditions, unusual inputs
   - **Invalid input**: Malformed data, type errors, null/undefined
   - **Error scenarios**: Network failures, timeouts, resource exhaustion
   - **Time-based behavior**: Delays, expiration, race conditions (if applicable)
   - **Concurrency**: Multiple operations, locks, thread safety (if applicable)

4. **Test annotations:**
   - Add `@acceptance AC1` comments linking tests to acceptance criteria
   - Add `@feature F-[XXXX]` to test file header

5. **Run tests (Red Phase):**
   - Confirm all tests FAIL before implementing
   - Fix any test setup issues

6. **Update spec:**
   - Update `spec/FEATURES.md`:
     - Set `Tests: Unit: partial` (or `complete` if all tests written)
   - Note any gaps or questions in `HUMAN_NEEDED.md`

7. **Document:**
   - Add entry to `JOURNAL.md` about test coverage
   - Note any interesting edge cases discovered

---

**Testing Standards:**
- Follow `.agentic/workflows/testing_standards.md`
- Use descriptive test names: `test_user_can_login_with_valid_credentials`
- Test behavior, not implementation
- Keep tests independent and repeatable
- Mock external dependencies

