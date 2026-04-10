# Testing Strategy & Methodology

Universal testing guidance for all projects. Covers test pyramid, unit testing schools (London vs Classical), test doubles, and coverage strategy.

## Test Pyramid

```
        /  E2E  \        Few, slow, high confidence
       / Integration \    Moderate count, test boundaries
      /    Unit Tests  \  Many, fast, focused
```

| Level | Count | Speed | What It Validates |
|-------|-------|-------|-------------------|
| Unit | Many (70-80%) | <1ms each | Business logic, algorithms, data transforms |
| Integration | Moderate (15-25%) | 10ms-1s each | Boundaries: DB, APIs, file system, cross-module |
| E2E | Few (5-10%) | 1-30s each | Critical user flows end-to-end |

**Anti-pattern**: Inverted pyramid (many E2E, few unit). Slow, flaky, hard to debug failures.

## Unit Testing: London vs Classical

Two schools of thought. **Neither is universally better** — use the right one for the situation.

### Classical (Detroit) Style
**Test the unit through its public interface. Use real collaborators. Assert on state.**

```typescript
// Classical: Real dependencies, state assertions
test('order calculates total with tax', () => {
  const catalog = new ProductCatalog()         // Real collaborator
  catalog.addProduct('widget', 10.00)
  const order = new Order(catalog)

  order.addItem('widget', 3)

  expect(order.total).toBe(30.00)              // Assert state
  expect(order.totalWithTax(0.1)).toBe(33.00)  // Assert state
})
```

**Strengths**: Tests behavior, not implementation. Refactoring-resistant. Catches integration bugs between collaborators.

**Weaknesses**: Failures can cascade (bug in ProductCatalog breaks Order tests). Setup can be verbose.

**Use when**:
- Testing business logic and domain models
- Collaborators are simple and stable
- You want refactoring freedom
- The unit's value is in its output, not its interactions

### London (Mockist) Style
**Isolate the unit completely. Mock all collaborators. Assert on interactions.**

```typescript
// London: Mocked dependencies, interaction assertions
test('order requests price from catalog', () => {
  const catalog = mock<ProductCatalog>()       // Mocked collaborator
  catalog.getPrice.mockReturnValue(10.00)
  const order = new Order(catalog)

  order.addItem('widget', 3)

  expect(catalog.getPrice).toHaveBeenCalledWith('widget')  // Assert interaction
  expect(order.total).toBe(30.00)
})
```

**Strengths**: Pinpoints failures exactly. Forces explicit dependency design. Good for testing protocol/interaction contracts.

**Weaknesses**: Couples tests to implementation (changing how, not what, breaks tests). Mocks can diverge from real behavior.

**Use when**:
- Testing interactions with external systems (APIs, message queues)
- The unit's value is in HOW it communicates, not just WHAT it returns
- You need to verify specific call patterns (retry logic, caching, batching)
- Real collaborators are slow, expensive, or have side effects

### Decision Framework

| Situation | Prefer | Why |
|-----------|--------|-----|
| Pure business logic | Classical | Output matters, not how it's computed |
| Domain models | Classical | Rich behavior, many valid implementations |
| API/service clients | London | Verify correct HTTP calls, headers, retry |
| Event publishers | London | Verify correct events emitted |
| Repository pattern | Classical with real DB | ORM queries must actually work |
| Cache layer | London | Verify cache-hit/miss logic |
| Controller/handler | London (partially) | Mock services, assert responses |
| Utility functions | Classical | Pure input→output |

### The Pragmatic Middle

Most real codebases use both. A reasonable default:

1. **Classical for domain logic** — test through public API with real value objects
2. **London for boundaries** — mock external services, databases (in unit tests), file systems
3. **Real dependencies in integration tests** — verify the mocks match reality

## Test Doubles

| Double | What It Does | When to Use |
|--------|-------------|-------------|
| **Dummy** | Passed but never used | Fill required parameters |
| **Stub** | Returns canned data | Control indirect inputs |
| **Spy** | Records calls for later assertion | Verify interactions happened |
| **Mock** | Pre-programmed expectations, verifies calls | London-style unit tests |
| **Fake** | Working implementation, simplified | Integration tests (in-memory DB, fake API) |

### Hierarchy of Realism
```
Real thing > Fake > Stub > Mock > Dummy
     ← More confidence          Less confidence →
     ← Slower, harder setup     Faster, easier setup →
```

**Rule**: Use the most realistic double that doesn't make the test slow or flaky.

## What to Test

### Always Test
1. **Happy path**: The expected, successful flow
2. **Edge cases**: Empty inputs, boundary values, single-item collections
3. **Invalid input**: Null, wrong type, out of range, malformed
4. **Error conditions**: Network failures, timeouts, permission denied
5. **State transitions**: Valid and invalid transitions in state machines

### Common Edge Cases Checklist
- Empty string `""`, empty array `[]`, empty object `{}`
- Zero `0`, negative `-1`, MAX_INT
- Boundary values (if limit is 100: test 99, 100, 101)
- Unicode, emojis, special characters, very long strings
- Concurrent access (if applicable)
- Clock/time boundaries (midnight, DST, leap year)

### The Litmus Test
> "Could this test pass with a broken implementation?"

If yes, the test is too weak. A test that always passes proves nothing.

```typescript
// TOO WEAK: Passes even if calculateTotal is wrong
test('calculates total', () => {
  const result = calculateTotal([10, 20, 30])
  expect(result).toBeDefined()  // Always true unless it throws
})

// STRONG: Fails if logic is wrong
test('calculates total', () => {
  expect(calculateTotal([10, 20, 30])).toBe(60)
  expect(calculateTotal([])).toBe(0)
  expect(calculateTotal([0])).toBe(0)
})
```

## Integration Testing

### When to Write Integration Tests
- **Database interactions**: Queries, transactions, migrations, constraints
- **External API boundaries**: Request format, response parsing, error handling
- **File system operations**: Read/write, permissions, large files
- **Cross-module workflows**: Multi-step operations spanning services

### Test Doubles for Integration Tests
- **Database**: Use real test database (Docker, testcontainers), NOT mocks
- **External APIs**: Use fake server (msw, wiremock) with realistic responses
- **File system**: Use temporary directories
- **Time**: Use controllable clock (not mocked Date, but injectable clock)

### Why Not Mock the Database
Mocked database tests pass when:
- Your SQL has syntax errors
- Your ORM generates wrong queries
- Your migration is broken
- Your constraints don't match your code

Real database tests catch all of these.

```python
# BAD: Mock hides real problems
@patch('app.db.query')
def test_get_user(mock_query):
    mock_query.return_value = User(id=1, name='Test')
    result = get_user(1)
    assert result.name == 'Test'  # Passes even if SQL is wrong

# GOOD: Real database catches everything
def test_get_user(db_session):
    db_session.add(User(id=1, name='Test'))
    db_session.commit()
    result = get_user(1)
    assert result.name == 'Test'  # Fails if query, ORM, or schema is broken
```

## Test Organization

```
tests/
  unit/           # Fast, isolated, no external deps
    test_order.py
    test_pricing.py
  integration/    # Real DB, real file system
    test_user_repository.py
    test_payment_gateway.py
  e2e/            # Full application, browser/API client
    test_checkout_flow.py
```

### Naming Convention
```
test_<what>_<condition>_<expected>

test_calculateTotal_emptyArray_returnsZero
test_login_invalidPassword_returns401
test_createOrder_insufficientStock_throwsError
```

## Coverage

### Targets
- **Unit test coverage**: 70-85% is the sweet spot for most projects
- **100% coverage** is a vanity metric — it doesn't mean tests are good
- **0% coverage** means you're deploying on faith

### What Coverage Misses
Coverage measures execution, not correctness:
```typescript
// 100% coverage, 0% value
test('runs the function', () => {
  calculateDiscount(100, 'SAVE10')  // Executes all branches
  // But asserts NOTHING about the result
})
```

### Focus Coverage On
- Business-critical paths (payments, auth, data integrity)
- Complex logic (conditionals, state machines, algorithms)
- Error handling paths (the ones that bite you in production)

### Skip Coverage For
- Generated code, boilerplate, configuration
- Simple getters/setters with no logic
- Third-party library wrappers with no custom logic
