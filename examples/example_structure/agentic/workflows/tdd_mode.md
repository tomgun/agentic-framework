# TDD Mode (Test-Driven Development)

**✅ RECOMMENDED for most projects.** Set `development_mode: tdd` in your `STACK.md`.

## Why TDD is Recommended

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

> "This project uses TDD mode. Follow `agentic/workflows/tdd_mode.md` instead of the standard dev loop."

Or add to your `AGENTS.md`:

```markdown
## Development Mode

**This project uses Test-Driven Development (TDD).**

Follow `agentic/workflows/tdd_mode.md` for the red-green-refactor cycle:
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

## Tools Support

All existing tools work with TDD mode:
- `verify.sh` still checks test coverage
- `doctor.py` validates FEATURES.md test status
- `report.sh` shows feature completion

The only difference is **when** tests are written (before vs. after implementation).

## See Also

- Standard development loop: `agentic/workflows/dev_loop.md`
- Test strategy: `agentic/quality/test_strategy.md`
- Definition of done: `agentic/workflows/definition_of_done.md`
- Design for testability: `agentic/quality/design_for_testability.md`

