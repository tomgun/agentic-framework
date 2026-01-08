# TDD Mode (Test-Driven Development)

**📌 OPTIONAL alternative to the default Acceptance-Driven approach.**

Set `development_mode: tdd` in your `STACK.md` to enable.

---

## When to Use TDD

**TDD is a good fit when:**
- You prefer the discipline of tests-first development
- Working on critical/complex logic (authentication, payments, algorithms)
- Refactoring existing code (tests ensure behavior is preserved)
- When you need very high confidence in correctness
- Smaller, incremental changes are preferred

**When Acceptance-Driven (standard) is better:**
- Rapid prototyping or exploration
- AI-generated implementations where AI can work on larger chunks
- Discovery-phase work where specs are evolving
- When acceptance criteria need to be discovered during implementation

**To enable TDD**: Set `development_mode: tdd` in `STACK.md`

---

## Preconditions

Before starting TDD workflow, verify:

- [ ] **Feature has acceptance criteria**: Check `spec/acceptance/F-####.md` exists (Core+PM) or informal criteria in `PRODUCT.md` (Core)
- [ ] **Test framework is set up**: Verify test command in `STACK.md` works (`npm test`, `cargo test`, `pytest`, etc.)
- [ ] **No failing tests**: Run full test suite - must be GREEN before adding new tests
- [ ] **Clear what to build**: Understand the behavior you're testing (from acceptance criteria or discussion)
- [ ] **Development environment ready**: Can run tests locally, code editor configured

**If any precondition fails:**
- Missing acceptance criteria → Add to `HUMAN_NEEDED.md`, create criteria with human
- Test framework not set up → Follow `STACK.md` setup instructions or research testing framework
- Failing tests → Fix existing issues before adding new tests (or mark as known failures)
- Unclear requirements → Discuss with human, update `HUMAN_NEEDED.md`

---

## Progress Tracking

Copy this checklist to track your TDD progress:

```
TDD Cycle Progress:
- [ ] Step 1: Picked specific behavior to test
- [ ] Step 2: Written failing test (RED phase)
- [ ] Step 3: Verified test fails for right reason
- [ ] Step 4: Written minimal implementation (GREEN phase)
- [ ] Step 5: All tests pass (including new one)
- [ ] Step 6: Refactored for clarity (if needed)
- [ ] Step 7: Updated documentation (FEATURES.md, JOURNAL.md)
- [ ] Step 8: Committed with descriptive message
```

**Self-check**: After each cycle, verify you completed all 8 steps. Don't skip steps.

---

## Benefits of TDD (When You Choose It)

### Token Economics Benefits

**Smaller context windows per step:**
- One test + one implementation at a time
- Clear stopping/resuming points
- Less code to review/understand per iteration

**Less rework:**
- Testable design from the start (no later refactoring for testability)
- Fewer bugs = fewer debugging sessions
- Clearer requirements = less back-and-forth

**Better for context resets:**
- "Last test passed" is clear resumption point
- Next test to write is clear next step
- No ambiguity about progress

### Code Quality Benefits

**Forces good design:**
- Code must be testable = better separation of concerns
- Smaller functions/methods
- Clearer interfaces
- Minimal implementation (no over-engineering)

**Built-in documentation:**
- Tests show how to use the code
- Tests capture requirements
- Tests demonstrate expected behavior

**Safe refactoring:**
- Tests ensure behavior doesn't break
- Can improve code quality continuously

## What is TDD Mode?

In TDD mode, agents **write tests first**, then implement the code to make them pass.

### Red-Green-Refactor Cycle

1. **Red**: Write a failing test that defines desired behavior
2. **Green**: Write minimal code to make the test pass
3. **Refactor**: Improve code quality without changing behavior
4. **Repeat**: Add next test for next behavior

## When to Use TDD Mode

### ✅ Recommended for (most code):
- **Business logic**: Functions with well-defined inputs/outputs
- **APIs and interfaces**: When contracts are stable
- **Data transformations**: Parsing, validation, formatting
- **Algorithms**: Sorting, searching, calculations
- **Bug fixes**: Write failing test that reproduces bug, then fix
- **Refactoring**: Tests ensure behavior doesn't change

### ⚠️ Consider standard mode for:
- **Initial exploration**: When you're figuring out what to build (prototype first, then add tests)
- **UI layout**: Visual design often needs iteration (add tests for behavior, not pixels)
- **External API integration**: When you don't control the interface yet (use mocks/stubs, then real tests)
- **Spike/research**: When requirements are completely unclear

**Rule of thumb**: Use TDD for ~80% of your code. Use standard mode for the exploratory ~20%.

## TDD Development Loop (replaces standard dev_loop.md)

### 1. Pick work
- Start from `STATUS.md` (current focus / next up)
- Choose one small, testable task
- Read acceptance criteria from `spec/acceptance/F-####.md`

### 2. Write failing test FIRST
```markdown
**Before writing implementation code:**

1. Identify the smallest testable behavior
2. Write a test that expects that behavior
3. Run test → verify it fails (RED)
4. Commit: "test: add failing test for [behavior]"
```

**Example** (TypeScript):
```typescript
// lib/auth.test.ts
describe('validatePassword', () => {
  it('should reject passwords shorter than 8 characters', () => {
    expect(validatePassword('short')).toBe(false);
  });
});
```

Run: ❌ **FAIL** (validatePassword doesn't exist yet)

### 3. Implement minimal code
```markdown
**Write just enough code to make the test pass:**

1. Implement the simplest solution
2. Don't add extra features or over-engineer
3. Run test → verify it passes (GREEN)
4. Commit: "feat: implement [behavior]"
```

**Example**:
```typescript
// lib/auth.ts
export function validatePassword(password: string): boolean {
  return password.length >= 8;
}
```

Run: ✅ **PASS**

### 4. Refactor if needed
```markdown
**Improve code quality without changing behavior:**

1. Remove duplication
2. Improve naming
3. Extract functions/classes
4. Run tests → verify still passing (GREEN)
5. Commit: "refactor: improve [aspect]"
```

### 5. Repeat for next behavior
Add next test for next acceptance criterion, repeat cycle.

### 6. Quality validation & docs
- Run `bash quality_checks.sh --pre-commit` (if configured)
- Update `STATUS.md` (always)
- Update `spec/FEATURES.md` test status as tests accumulate
- Update specs/ADRs if behavior/architecture changed
- Append to `JOURNAL.md` at session end

## TDD-Specific Rules for Agents

### MUST follow:
1. **Test first, always**: No implementation code before test exists
2. **One test at a time**: Write one failing test, implement, then next test
3. **Minimal implementation**: Don't add code that isn't required by a test
4. **Run tests after every change**: Verify red → green transitions
5. **Commit frequently**: Separate commits for test, implementation, refactor

### Test should:
- Be specific and focused (one behavior per test)
- Have clear assertions (not just "should work")
- Use descriptive names (`should reject short passwords`, not `test1`)
- Be deterministic (no flaky tests)

### Implementation should:
- Make the test pass with simplest code
- Not add features not covered by tests
- Not skip error handling if tests require it

## Example TDD Session

**Feature**: F-0042 User authentication (password validation)

**Acceptance criteria** (from `spec/acceptance/F-0042.md`):
- AC1: Password must be at least 8 characters
- AC2: Password must contain at least one number
- AC3: Password must contain at least one uppercase letter

### Iteration 1: AC1 - Length validation

**Step 1: Write test** (❌ RED)
```typescript
test('should reject passwords shorter than 8 characters', () => {
  expect(validatePassword('short')).toBe(false);
});

test('should accept passwords 8+ characters', () => {
  expect(validatePassword('longenough')).toBe(true);
});
```
Commit: `test: add password length validation tests`

**Step 2: Implement** (✅ GREEN)
```typescript
export function validatePassword(password: string): boolean {
  return password.length >= 8;
}
```
Commit: `feat: implement password length validation`

### Iteration 2: AC2 - Number requirement

**Step 1: Write test** (❌ RED)
```typescript
test('should reject passwords without numbers', () => {
  expect(validatePassword('NoNumbers')).toBe(false);
});

test('should accept passwords with numbers', () => {
  expect(validatePassword('HasNumber1')).toBe(true);
});
```
Commit: `test: add password number requirement tests`

**Step 2: Implement** (✅ GREEN)
```typescript
export function validatePassword(password: string): boolean {
  if (password.length < 8) return false;
  if (!/\d/.test(password)) return false;
  return true;
}
```
Commit: `feat: require number in password`

**Step 3: Refactor** (✅ GREEN)
```typescript
export function validatePassword(password: string): boolean {
  const hasMinLength = password.length >= 8;
  const hasNumber = /\d/.test(password);
  return hasMinLength && hasNumber;
}
```
Commit: `refactor: improve password validation readability`

### Continue for AC3...

## Benefits of TDD Mode

✅ **Forces clarity**: Can't write code until you know what it should do  
✅ **Built-in regression tests**: Every behavior has a test from day one  
✅ **Simpler designs**: Minimal code, no over-engineering  
✅ **Easier debugging**: Test failures pinpoint exact issue  
✅ **Living documentation**: Tests show how to use the code  
✅ **Safe refactoring**: Tests ensure behavior doesn't break

## Challenges of TDD Mode

⚠️ **Slower initial progress**: Writing tests first takes more time upfront  
⚠️ **Requires clear requirements**: Hard to write tests if you don't know what to build  
⚠️ **Can feel rigid**: Less room for exploration and discovery  
⚠️ **Test maintenance**: More tests = more code to maintain

## Enabling TDD Mode in Your Project

### 1. Update STACK.md

Add to your `STACK.md`:

```markdown
## Development approach
- **development_mode**: tdd
- **test_first**: yes
- **commit_strategy**: separate commits for test/implementation/refactor
```

### 2. Tell your agent

When starting work:

> "This project uses TDD mode. Follow `.agentic/workflows/tdd_mode.md` instead of the standard dev loop."

Or add to your `AGENTS.md`:

```markdown
## Development Mode

**This project uses Test-Driven Development (TDD).**

Follow `.agentic/workflows/tdd_mode.md` for the red-green-refactor cycle:
1. Write failing test first
2. Implement minimal code to pass
3. Refactor if needed
4. Repeat

See STACK.md `development_mode: tdd` for confirmation.
```

### 3. Agent will check STACK.md

Agents following `agent_operating_guidelines.md` will check for `development_mode: tdd` in STACK.md and switch to TDD workflow automatically.

## Disabling TDD Mode

Remove or change in `STACK.md`:

```markdown
## Development approach
- **development_mode**: standard  # or remove field entirely
```

Agents will fall back to standard `dev_loop.md` (tests required, but not necessarily first).

## Hybrid Approach

You can use TDD selectively:

```markdown
## Development approach
- **development_mode**: hybrid
- **tdd_for**: core business logic, APIs, bug fixes
- **standard_for**: UI, exploratory work, prototypes
```

Then instruct agent case-by-case:

> "Implement F-0042 using TDD" (agent uses tdd_mode.md)  
> "Prototype the dashboard UI" (agent uses dev_loop.md)

---

## Error Recovery

**Common TDD problems and solutions:**

### Problem: Tests won't run at all

**Symptoms**: Test runner not found, import errors, configuration errors

**Solutions**:
1. Check `STACK.md` for correct test command
2. Verify dependencies installed (`npm install`, `pip install -r requirements.txt`, etc.)
3. Check test framework is in project dependencies
4. Verify test files are in correct location (check framework conventions)
5. Add to `HUMAN_NEEDED.md` if test setup is unclear

**Prevention**: Run `doctor.sh --quick` before starting TDD cycle

---

### Problem: Tests pass immediately (false positive)

**Symptoms**: New test passes without implementation, always green

**Root cause**: Test is too weak or not actually testing the behavior

**Solutions**:
1. Verify test actually calls the function/method being tested
2. Check assertions are meaningful (not always true)
3. Run test in isolation to confirm it can fail
4. Add more specific assertions
5. Test the negative case first (should fail, then invert)

**Example of weak test**:
```python
def test_validate_password():
    result = validate_password("test")
    assert result is not None  # Too weak! Always passes
```

**Better**:
```python
def test_validate_password_rejects_short():
    result = validate_password("short")  
    assert result == False  # Specific expectation
```

---

### Problem: Stuck in RED phase (tests won't pass)

**Symptoms**: Can't make tests pass, implementation seems correct but fails

**Solutions**:
1. **Simplify test**: Make it test less behavior, split into smaller tests
2. **Check test logic**: Is the test correct? Read it carefully
3. **Debug**: Add print statements or use debugger to see actual vs. expected
4. **Verify assumptions**: Are you testing what you think you're testing?
5. **Ask for help**: Add specific question to `HUMAN_NEEDED.md` with:
   - Test code
   - Implementation code  
   - Expected vs. actual behavior
   - What you've tried

**Break the cycle**: If stuck >15 minutes, write simpler test that you CAN pass, build up from there

---

### Problem: Refactoring breaks tests

**Symptoms**: Tests were passing, now failing after refactor

**Root cause**: Tests were coupled to implementation details, not behavior

**Solutions**:
1. **Revert refactor**: Go back to passing state
2. **Identify coupling**: What implementation detail changed that broke test?
3. **Rewrite test**: Test behavior/output, not internal implementation
4. **Re-attempt refactor**: With better tests, try again

**Prevention**: Write tests that test "what" not "how"

**Bad (tests implementation)**:
```python
def test_sorts_using_quicksort():
    assert uses_quicksort(sort([3,1,2]))  # Coupled to algorithm
```

**Good (tests behavior)**:
```python
def test_sorts_numbers_ascending():
    assert sort([3,1,2]) == [1,2,3]  # Tests outcome
```

---

### Problem: Too many tests failing at once

**Symptoms**: After adding new code, many unrelated tests fail

**Root cause**: Changed shared code or broke a core assumption

**Solutions**:
1. **Revert immediately**: Go back to last known good state
2. **Smaller steps**: Make incremental changes, run tests after each
3. **Isolate change**: Refactor first (tests passing), then add feature
4. **Check dependencies**: Did you break a shared utility or core function?

**Prevention**: Commit after each GREEN phase. If something breaks, you can revert easily.

---

### Problem: Tests are slow

**Symptoms**: Test suite takes too long to run, slows down TDD cycle

**Solutions**:
1. **Run subset**: Test only the file you're working on during TDD
2. **Mock external deps**: Database, API calls, file I/O should be mocked for unit tests
3. **Parallel execution**: Most test runners support parallel tests
4. **Mark slow tests**: Tag integration/slow tests separately, skip during TDD
5. **Profile tests**: Find the slowest tests and optimize or move to integration suite

**TDD cycle should be <10 seconds**: If longer, you're doing integration testing not unit testing

**Example** (Jest):
```bash
# Fast: Test only current file during TDD
npm test -- auth.test.ts --watch

# Slow: Full suite (run before commit)
npm test
```

---

### Problem: Don't know what to test next

**Symptoms**: Feature is partially done, unclear what behavior to add next

**Solutions**:
1. **Check acceptance criteria**: `spec/acceptance/F-####.md` lists all required behavior
2. **List edge cases**: Write down all the "what if" scenarios
3. **Start with happy path**: Test normal, expected usage first
4. **Then error cases**: Invalid input, boundary conditions, failures
5. **Check test coverage**: Gaps in coverage suggest untested behavior

**Systematic approach**:
1. Happy path (normal usage)
2. Edge cases (boundary values, empty, null, zero)
3. Error handling (invalid input, exceptions)
4. Integration (does it work with other components?)

---

### Problem: Unclear requirements

**Symptoms**: Don't know what the correct behavior should be

**Solutions**:
1. **Don't guess**: Add question to `HUMAN_NEEDED.md` immediately
2. **Document assumption**: If you must proceed, write assumption in test comment and `JOURNAL.md`
3. **Ask human**: Blocker = stop and escalate, don't waste tokens guessing
4. **Check similar features**: How do existing features handle this?

**Never write tests for guessed behavior** - you'll have to rewrite them later

---

## Tools Support

All existing tools work with TDD mode:
- `verify.sh` still checks test coverage
- `doctor.py` validates FEATURES.md test status
- `report.sh` shows feature completion

The only difference is **when** tests are written (before vs. after implementation).

## See Also

- Standard development loop: `.agentic/workflows/dev_loop.md`
- Test strategy: `.agentic/quality/test_strategy.md`
- Definition of done: `.agentic/workflows/definition_of_done.md`
- Design for testability: `.agentic/quality/design_for_testability.md`

