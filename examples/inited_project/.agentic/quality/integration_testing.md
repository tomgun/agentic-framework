# Integration testing

Purpose: guide when and how to write integration tests that verify component boundaries and external dependencies.

## What is an integration test?

An integration test verifies that multiple components work correctly together, including:
- Component A calling component B
- Application code interacting with databases
- Application code calling external APIs
- File system interactions
- Network communication
- Multi-process/thread coordination

**Key distinction from unit tests**: Integration tests use real dependencies (or realistic fakes), while unit tests use mocks/stubs.

## When to write integration tests

### Always write integration tests for:
1. **Database interactions**
   - Queries return correct data
   - Transactions commit/rollback properly
   - Schema constraints are enforced
   - Migrations work correctly

2. **External API boundaries**
   - Requests are formatted correctly
   - Responses are parsed correctly
   - Error handling works (timeouts, retries, malformed responses)
   - Authentication/authorization flows

3. **File system operations**
   - Read/write operations
   - File permissions handling
   - Directory traversal
   - Large file handling

4. **Cross-module workflows**
   - User registration flow (auth + email + database)
   - Payment processing (checkout + payment provider + order creation)
   - Data pipelines (ingest + transform + store)

### Consider integration tests for:
- Performance-sensitive paths (measure actual performance)
- Security-critical operations (test real crypto, not mocks)
- Complex state machines across components
- Concurrency/race condition scenarios

### Skip integration tests when:
- Pure business logic (use unit tests)
- Simple pass-through code
- UI rendering (use unit tests for logic, E2E for user flows)

## Test doubles strategy

### Real dependencies (preferred for integration tests)
- **Database**: Use test database or in-memory DB (SQLite)
- **File system**: Use temporary directories
- **Time/clock**: Use controllable clock implementation
- **Random**: Use seeded RNG

### Fakes (realistic implementations)
- **External APIs**: Fake server with realistic responses
- **Email service**: Fake that captures emails without sending
- **Payment gateway**: Fake with configurable success/failure

### Mocks/Stubs (avoid in integration tests)
- Use only when real dependency is truly unavailable (hardware, expensive cloud services)
- Prefer fakes over mocks for integration tests

## Test environment management

### Database tests
```typescript
// Example pattern
describe('User repository', () => {
  let db: Database;
  
  beforeAll(async () => {
    db = await createTestDatabase(); // Fresh DB or in-memory
  });
  
  beforeEach(async () => {
    await db.truncateAll(); // Clean slate for each test
  });
  
  afterAll(async () => {
    await db.close();
  });
  
  it('creates user with unique email', async () => {
    const user = await userRepo.create({email: 'test@example.com'});
    await expect(userRepo.create({email: 'test@example.com'}))
      .rejects.toThrow('Email already exists');
  });
});
```

### API integration tests
```typescript
// Example: Testing against fake API
describe('Payment service integration', () => {
  let fakePaymentServer: FakeServer;
  
  beforeAll(() => {
    fakePaymentServer = new FakePaymentServer({port: 8888});
    fakePaymentServer.start();
  });
  
  afterAll(() => {
    fakePaymentServer.stop();
  });
  
  it('handles declined card', async () => {
    fakePaymentServer.setNextResponse({status: 'declined', code: 'insufficient_funds'});
    
    const result = await paymentService.charge({amount: 100, token: 'test'});
    
    expect(result.success).toBe(false);
    expect(result.error).toContain('insufficient funds');
  });
});
```

### File system tests
```typescript
import {mkdtemp, rm} from 'fs/promises';
import {tmpdir} from 'os';
import {join} from 'path';

describe('File processor', () => {
  let testDir: string;
  
  beforeEach(async () => {
    testDir = await mkdtemp(join(tmpdir(), 'test-'));
  });
  
  afterEach(async () => {
    await rm(testDir, {recursive: true});
  });
  
  it('processes all files in directory', async () => {
    // Write test files to testDir
    // Run processor
    // Verify output files
  });
});
```

## Contract testing

When multiple services/modules communicate, use contract tests to verify agreements.

### Provider contract (server/API side)
```typescript
// Test that API provides what consumers expect
describe('User API contract', () => {
  it('GET /users/:id returns expected shape', async () => {
    const response = await api.get('/users/123');
    
    expect(response).toMatchSchema({
      id: expect.any(String),
      email: expect.any(String),
      createdAt: expect.any(String),
    });
  });
});
```

### Consumer contract (client side)
```typescript
// Test that client correctly uses API
describe('User client contract', () => {
  it('sends correctly formatted create request', async () => {
    const mockServer = setupMockServer();
    
    await userClient.create({email: 'test@example.com', name: 'Test'});
    
    expect(mockServer.lastRequest).toMatchObject({
      method: 'POST',
      path: '/users',
      body: {email: expect.any(String), name: expect.any(String)},
    });
  });
});
```

## Test data management

### Fixtures
- Use for read-only test data
- Load once, reuse across tests
- Version control fixture files

### Factories
- Use for test data that varies per test
- Builder pattern for complex objects
- Random but deterministic (seeded)

```typescript
// Example factory
function createUser(overrides = {}) {
  return {
    id: randomId(),
    email: `test${randomInt()}@example.com`,
    createdAt: new Date(),
    ...overrides,
  };
}
```

### Test isolation
- Each test should be independent
- Clean up between tests (truncate DB, delete files)
- Avoid shared mutable state

## Performance in integration tests

### Keep tests fast
- Use in-memory databases when possible
- Parallelize independent tests
- Mock slow external services (but keep some E2E tests with real services)

### Test performance explicitly
```typescript
it('search completes within 200ms', async () => {
  const start = Date.now();
  await searchService.search('query');
  const duration = Date.now() - start;
  
  expect(duration).toBeLessThan(200);
});
```

## Organizing integration tests

### Directory structure options

**Option A: Co-located with unit tests**
```
src/
  user/
    user.service.ts
    user.service.test.ts        # unit tests
    user.service.integration.ts # integration tests
```

**Option B: Separate directory**
```
src/
  user/
    user.service.ts
    user.service.test.ts
tests/
  integration/
    user.integration.ts
```

Choose one approach and document in `STACK.md`.

### Naming conventions
- Use `.integration.ts` or `.integration.test.ts` suffix
- Or place in `tests/integration/` directory
- Make it easy to run integration tests separately: `npm run test:integration`

## CI/CD considerations

### Test stages
1. **Fast checks**: Lint, type check (< 30s)
2. **Unit tests**: No external dependencies (< 2 min)
3. **Integration tests**: With test database/fakes (< 5 min)
4. **E2E tests**: Full system (< 10 min)

### Environment setup
- Document required services in `STACK.md`
- Use docker-compose for local test databases
- Use environment variables for configuration
- Provide setup script: `npm run test:setup`

## Examples by domain

### Web application
- Request/response integration tests
- Database query tests
- Session/auth tests
- File upload tests

### Mobile application
- Local storage/database tests
- Network request tests
- Background task tests
- Push notification tests (with fake)

### VST/Audio plugin (JUCE)
- Audio I/O golden file tests
- Host automation tests
- State save/load tests
- Performance/latency tests

### Game
- Save/load tests
- Input replay tests
- Network multiplayer tests (with fake server)
- Asset loading tests

## Common patterns

### Transactional tests
```typescript
await db.transaction(async (tx) => {
  const user = await tx.createUser({...});
  await tx.createProfile({userId: user.id, ...});
  // If anything fails, rollback
});
```

### Retry/timeout tests
```typescript
it('retries failed requests', async () => {
  fakeServer.failNextRequests(2);
  
  const result = await client.requestWithRetry('/endpoint');
  
  expect(result.success).toBe(true);
  expect(fakeServer.requestCount).toBe(3); // 2 failures + 1 success
});
```

### Error propagation tests
```typescript
it('surfaces database errors correctly', async () => {
  await expect(
    service.createWithInvalidData({...})
  ).rejects.toThrow(ValidationError);
});
```

## Documentation in spec

Update `spec/FEATURES.md` for each feature:
- Mark `Test strategy: integration` when applicable
- List integration test coverage in Tests section
- Link to test files in Implementation section

Update `spec/TECH_SPEC.md`:
- Document test environment setup
- List required test dependencies
- Specify test database approach

## Related resources
- Unit testing: `.agentic/quality/test_strategy.md`
- Design for testability: `.agentic/quality/design_for_testability.md`
- Definition of done: `.agentic/workflows/definition_of_done.md`

