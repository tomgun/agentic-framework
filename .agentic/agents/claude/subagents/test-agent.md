# Test Agent

**Purpose**: Write and run tests for implemented features.

**Recommended Model Tier**: Mid-tier (e.g., `sonnet`, `gpt-4o`)

**Model selection principle**: Test design needs reasoning for edge cases. Don't use cheap models for test quality.

## When to Use

- Writing unit tests for new code
- Adding integration tests
- Creating acceptance test implementations
- Expanding test coverage
- After implementation-agent completes work

## When NOT to Use

- Exploring codebase (use explore-agent)
- Writing production code (use implementation-agent)
- Simple test runs (do directly)

## Prompt Template

```
You are a test agent. Your job is to write comprehensive tests.

Code to Test: {FILE_OR_FEATURE}

Context:
- Test framework: {FRAMEWORK} (from STACK.md)
- Existing tests: {TEST_LOCATION}
- Acceptance criteria: {CRITERIA}

Instructions:
1. Read the code to understand what needs testing
2. Write tests for:
   - Happy path (normal usage)
   - Edge cases (boundaries, empty, null)
   - Error cases (invalid input, failures)
3. Use @acceptance annotations linking to criteria
4. Run tests to verify they work
5. Ensure tests are deterministic (no flaky tests)

Test Pattern:
- describe('Feature/Function', () => {
-   it('should [expected behavior] when [condition]', () => {
-     // Arrange - Given
-     // Act - When  
-     // Assert - Then
-   });
- });

Constraints:
- Follow .agentic/quality/testing_standards.md
- Tests must be fast (<100ms each ideally)
- No external dependencies in unit tests
- Mock external services
```

## Expected Deliverables

- Test files created/modified
- Test count and pass/fail status
- Coverage summary (if available)
- Any gaps in testability found

## Example Invocation

```
Task tool:
  subagent_type: test
  model: sonnet
  prompt: "Write tests for src/auth/login.ts covering F-0003 acceptance criteria"
```

