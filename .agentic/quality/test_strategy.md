# Test strategy (technology-agnostic)

## Goals
- Catch regressions quickly (fast unit tests).
- Validate integration points (slower integration tests).
- Validate user-visible behavior where needed (acceptance/E2E).
- **Verify edge cases and error conditions** (not just happy paths).

## Test pyramid (default)
- Unit: most tests, fast, deterministic
- Integration: fewer, cover boundaries (DB/network/FS) - see `.agentic/quality/integration_testing.md`
- Acceptance/E2E: smallest set, cover critical flows

## What counts as a "unit"
- A unit is a component with **controlled dependencies** (mocked/faked).
- If a test requires network/DB/real filesystem by default, it's not a unit test.

## Principles
- Deterministic and isolated: no reliance on time/network/global state.
- Clear assertions: test one behavior, one reason to fail.
- Prefer contract tests at boundaries (see `.agentic/quality/integration_testing.md` for details).
- **Test edge cases and errors, not just happy paths** (see below).

---

## What to Test (Comprehensive Coverage)

### 1. Happy Path (Success Cases)
The basic, expected functionality:

```typescript
// Example: Password validation
test('should accept valid password', () => {
  expect(validatePassword('ValidPass123')).toBe(true);
});
```

### 2. Edge Cases (Boundary Conditions)

**Always test boundaries**:

```typescript
// Length boundaries
test('should accept password with exactly 8 characters', () => {
  expect(validatePassword('Pass1234')).toBe(true);
});

test('should reject password with 7 characters', () => {
  expect(validatePassword('Pass123')).toBe(false);
});

// Numeric boundaries
test('should handle age at boundary (0)', () => {
  expect(isValidAge(0)).toBe(true); // Is 0 valid?
});

test('should handle age at boundary (150)', () => {
  expect(isValidAge(150)).toBe(true); // Upper bound
});

// Array boundaries
test('should handle empty array', () => {
  expect(calculateAverage([])).toBe(0); // Or throw error?
});

test('should handle single-item array', () => {
  expect(calculateAverage([5])).toBe(5);
});
```

**Common edge cases to test**:
- **Empty**: Empty string `""`, empty array `[]`, empty object `{}`
- **Zero/One**: `0`, `1` (often special cases)
- **Boundaries**: Min/max values (`-1`, `0`, `1`, `MAX_INT`)
- **Just before/after threshold**: If limit is 100, test `99`, `100`, `101`
- **Large values**: Very large numbers, long strings
- **Unicode/Special characters**: Emojis 🎉, accents (café), CJK characters (日本)

### 3. Invalid Input (Error Cases)

**Test how code handles bad input**:

```typescript
// Null/undefined
test('should reject null password', () => {
  expect(() => validatePassword(null)).toThrow(ValidationError);
});

test('should reject undefined password', () => {
  expect(() => validatePassword(undefined)).toThrow(ValidationError);
});

// Wrong type
test('should reject number as password', () => {
  expect(() => validatePassword(123)).toThrow(TypeError);
});

// Invalid format
test('should reject email without @', () => {
  expect(isValidEmail('notanemail')).toBe(false);
});

// Out of range
test('should reject negative age', () => {
  expect(isValidAge(-1)).toBe(false);
});

// Malformed data
test('should reject malformed JSON', () => {
  expect(() => parseUserData('{invalid json')).toThrow(SyntaxError);
});
```

**Invalid input checklist**:
- `null`, `undefined`
- Wrong types (string instead of number, number instead of string)
- Negative numbers (where positive expected)
- Out-of-range values
- Invalid formats (malformed email, phone, URL)
- Injection attempts (SQL, XSS payloads) - security tests
- Excessively large input (DoS prevention)

### 4. Time-Based Behavior

**Test time-dependent logic** (use controllable clock):

```typescript
// Example: Token expiration
test('should accept token before expiration', () => {
  const clock = new MockClock('2026-01-01T10:00:00Z');
  const token = createToken({ expiresAt: '2026-01-01T11:00:00Z' }, clock);
  
  clock.setTime('2026-01-01T10:30:00Z'); // 30 min after creation
  expect(isTokenValid(token, clock)).toBe(true);
});

test('should reject token after expiration', () => {
  const clock = new MockClock('2026-01-01T10:00:00Z');
  const token = createToken({ expiresAt: '2026-01-01T11:00:00Z' }, clock);
  
  clock.setTime('2026-01-01T11:01:00Z'); // 1 min after expiration
  expect(isTokenValid(token, clock)).toBe(false);
});

test('should reject token at exact expiration time', () => {
  const clock = new MockClock('2026-01-01T10:00:00Z');
  const token = createToken({ expiresAt: '2026-01-01T11:00:00Z' }, clock);
  
  clock.setTime('2026-01-01T11:00:00Z'); // Exact expiration
  expect(isTokenValid(token, clock)).toBe(false);
});
```

**Time-based test patterns**:
- **Timeouts**: Test what happens when operation takes too long
- **Expiration**: Tokens, sessions, cache entries
- **Rate limiting**: Test request throttling
- **Scheduling**: Cron jobs, delayed tasks
- **Timestamps**: Creation time, update time, sorting by time
- **Time zones**: UTC vs local time, DST transitions
- **Retries with backoff**: Exponential backoff timing

**How to test time** (avoid real delays):

```typescript
// ❌ BAD - Real delays make tests slow
test('should timeout after 5 seconds', async () => {
  await sleep(5000); // Test takes 5 seconds!
  expect(hasTimedOut).toBe(true);
});

// ✅ GOOD - Mock time
test('should timeout after 5 seconds', () => {
  const clock = new MockClock();
  startOperation(clock);
  
  clock.advance(5000); // Instant in test
  expect(hasTimedOut).toBe(true);
});
```

**Mock clock libraries**:
- JavaScript: `sinon.useFakeTimers()`, `jest.useFakeTimers()`
- Python: `freezegun`, `unittest.mock.patch`
- Go: Inject `time.Now()` function
- Rust: `tokio::time::pause()` for async code

### 5. Concurrency & Race Conditions

**Test parallel execution** (if code is concurrent):

```typescript
// Example: Counter increment
test('should handle concurrent increments correctly', async () => {
  const counter = new AtomicCounter(0);
  
  // 100 concurrent increments
  await Promise.all(
    Array(100).fill(0).map(() => counter.increment())
  );
  
  expect(counter.value).toBe(100); // Should be atomic
});

// Example: Database deadlocks
test('should handle concurrent updates without deadlock', async () => {
  const promises = [
    updateUser(user1, { status: 'active' }),
    updateUser(user2, { status: 'active' }),
    updateUser(user3, { status: 'active' })
  ];
  
  await expect(Promise.all(promises)).resolves.toBeDefined();
  // Should complete without deadlock
});
```

### 6. Resource Exhaustion & Limits

**Test system limits**:

```typescript
// Memory limits
test('should handle large dataset without running out of memory', () => {
  const largeArray = Array(1_000_000).fill(1);
  expect(() => processData(largeArray)).not.toThrow();
});

// Connection pool limits
test('should queue requests when pool exhausted', async () => {
  const pool = new ConnectionPool({ maxSize: 10 });
  
  // 20 concurrent requests (exceeds pool size)
  const promises = Array(20).fill(0).map(() => 
    pool.execute('SELECT 1')
  );
  
  await expect(Promise.all(promises)).resolves.toBeDefined();
  // Should queue gracefully, not crash
});

// File descriptor limits
test('should close files properly to avoid exhaustion', async () => {
  for (let i = 0; i < 1000; i++) {
    await processFile(`file-${i}.txt`);
  }
  // Should not exhaust file descriptors
});
```

### 7. Network Failures & Timeouts

**Test resilience to failures** (see `integration_testing.md` for details):

```typescript
// Network timeout
test('should timeout gracefully on slow API', async () => {
  const slowApi = mockApiWithDelay(10000); // 10 second delay
  
  await expect(
    fetchData(slowApi, { timeout: 1000 }) // 1 second timeout
  ).rejects.toThrow(TimeoutError);
});

// Network error
test('should retry on network failure', async () => {
  const failingApi = mockApiWithFailures(2); // Fail twice, then succeed
  
  const result = await fetchDataWithRetry(failingApi, { maxRetries: 3 });
  expect(result).toBeDefined();
  expect(failingApi.callCount).toBe(3); // Failed twice, succeeded on 3rd
});
```

---

## Test Naming Conventions

**Use descriptive names that document behavior**:

```typescript
// ✅ GOOD - Clear what's being tested
test('should return user when ID exists', ...)
test('should throw UserNotFoundError when ID does not exist', ...)
test('should validate email format before creating user', ...)
test('should expire session after 30 minutes of inactivity', ...)

// ❌ BAD - Unclear what's expected
test('getUserById test', ...)
test('test1', ...)
test('should work', ...)
```

**Naming pattern**: `should [expected behavior] when [condition]`

---

## Test Data Management
- Use factories for variable test data (builders, random but seeded)
- Use fixtures for read-only reference data
- Keep tests isolated - clean up between tests
- Document test data strategy in `STACK.md`

## Naming & placement
- Keep tests near code or in a dedicated `tests/` folder—pick one convention and note it in `STACK.md`.
- Prefer a consistent naming scheme so agents can find tests quickly.

---

## Test Coverage Checklist

For each function/method, ensure tests cover:

- [ ] **Happy path**: Normal, expected input
- [ ] **Edge cases**: Boundaries (empty, zero, max, min)
- [ ] **Invalid input**: Null, undefined, wrong type, out of range
- [ ] **Errors**: Exception handling, error messages
- [ ] **Time-based**: Expiration, timeouts, scheduling (if applicable)
- [ ] **Concurrency**: Race conditions, deadlocks (if applicable)
- [ ] **Resource limits**: Memory, connections, files (if applicable)
- [ ] **Network failures**: Timeouts, retries, fallbacks (if applicable)

**Minimum coverage**: Happy path + invalid input + edge cases  
**Comprehensive coverage**: All of the above

---

## Test Result Logging (Framework Development)

When running tests for a release:

**CRITICAL ORDER**: Update version BEFORE running tests.

1. **Update VERSION first**: `echo "X.Y.Z" > VERSION`
2. **Update STACK.md version** to match
3. **Update spec/FEATURES.md version** to match
4. **THEN run tests**: `bash tests/validate_framework.sh`
5. **Update result files** with new version:
   - `tests/VERIFICATION_REPORT.md` - Test counts, feature list
   - `tests/LLM_TEST_RESULTS.md` - Manual test tracking

**Why order matters**: Test results are logged with the version number. Running tests first, then bumping version = results logged against wrong version.

**Anti-pattern**:
```bash
# ❌ WRONG - tests logged as v0.15.0
bash tests/validate_framework.sh  # Shows v0.15.0
echo "0.16.0" > VERSION           # Now v0.16.0 but tests said v0.15.0
```

**Correct pattern**:
```bash
# ✅ RIGHT - tests logged as v0.16.0
echo "0.16.0" > VERSION           # Set version first
bash tests/validate_framework.sh  # Shows v0.16.0
```

---

## See Also

- TDD workflow: `.agentic/workflows/tdd_mode.md`
- Integration testing: `.agentic/quality/integration_testing.md`
- Design for testability: `.agentic/quality/design_for_testability.md`
- Review checklist: `.agentic/quality/review_checklist.md`

