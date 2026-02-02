# Code annotations (spec-to-code linking)

Purpose: create bidirectional links between code and specifications so agents and humans can trace feature implementations.

## Why annotate code?
- **Traceability**: quickly find which code implements which feature
- **Coverage verification**: ensure all features are implemented
- **Context for AI**: agents can understand feature scope when editing code
- **Maintenance**: future changes know which specs to update

## Annotation format

Use comments in your language's style:

```typescript
// @feature F-0001
// @acceptance AC2 (handle localStorage quota exceeded)
// @nfr NFR-0002 (graceful degradation)
function saveTodoWithFallback(todo: Todo): Result<void> {
  // implementation
}
```

```python
# @feature F-0003
# @nfr NFR-0001 (response time < 200ms)
def search_users(query: str) -> list[User]:
    # implementation
```

```rust
// @feature F-0012
// @nfr NFR-0005 (realtime safe, no allocations)
fn process_audio_buffer(buffer: &mut [f32]) {
    // implementation
}
```

## Annotation vocabulary

### @feature F-####
- Links code to a feature in `spec/FEATURES.md`
- Use on: functions, classes, components, modules implementing the feature
- Multiple features OK if code serves multiple features

### @acceptance AC# (description)
- Links to specific acceptance criterion from feature's acceptance file
- Use when code specifically addresses a particular acceptance requirement
- Optional but helpful for complex features

### @nfr NFR-#### (constraint)
- Links to non-functional requirement in `spec/NFR.md`
- Use when code must meet specific performance/security/reliability constraints
- Helps identify code that needs extra care during changes

## When to annotate

### Always annotate:
- Entry points for features (main functions/classes implementing the feature)
- Key algorithms or business logic
- Code addressing specific NFRs (performance-critical, security-sensitive, realtime)

### Don't over-annotate:
- Trivial helpers (unless feature-specific)
- Generated code
- Third-party code
- Infrastructure/boilerplate (unless it's feature-specific infrastructure)

### Rule of thumb:
If someone asks "where is feature F-0001 implemented?", the annotations should lead them to the answer quickly.

## Agent guidelines

### When implementing a feature:
1. Check `spec/FEATURES.md` for the feature ID
2. Check `spec/acceptance/F-####.md` for acceptance criteria IDs
3. Check `spec/NFR.md` if the feature has NFR constraints
4. Add annotations to key functions/classes you create

### When editing existing code:
1. Check if code has `@feature` annotations
2. If editing changes feature behavior, update the relevant `spec/FEATURES.md` entry
3. If editing impacts NFR compliance, verify NFR is still met
4. Update or add annotations as needed

### After implementing:
- Run `bash .agentic/tools/coverage.sh` to check annotation coverage
- Update `spec/FEATURES.md` with the "Code:" field pointing to annotated modules

## Example: full feature implementation

```typescript
// @feature F-0004
// User can persist todos across sessions
export class TodoStorage {
  // @feature F-0004
  // @acceptance AC1 (save todos to localStorage)
  // @nfr NFR-0003 (handle quota exceeded gracefully)
  async save(todos: Todo[]): Promise<Result<void>> {
    try {
      localStorage.setItem('todos', JSON.stringify(todos));
      return { ok: true };
    } catch (e) {
      if (e instanceof DOMException && e.code === 22) {
        // @acceptance AC2 (fallback when storage unavailable)
        return this.saveTempStorage(todos);
      }
      return { ok: false, error: e };
    }
  }

  // @feature F-0004
  // @acceptance AC3 (load todos on startup)
  async load(): Promise<Todo[]> {
    // implementation
  }
}
```

## Tools

- **Check coverage**: `python3 .agentic/tools/coverage.py`
  - Shows which features have/lack code annotations
  - Reports orphaned annotations (referencing non-existent features)
  - Options:
    - `--json` - Machine-readable JSON output
    - `--reverse FILE` - What features does FILE implement?
    - `--test-mapping` - Infer test→feature mapping

- **Trace**: `bash .agentic/tools/ag.sh trace`
  - Combined drift + coverage analysis
  - Options:
    - `ag trace` - Full report
    - `ag trace F-XXXX` - What files implement feature?
    - `ag trace FILE` - What features does file implement?
    - `ag trace --gaps` - Only show gaps
    - `ag trace --json` - Machine-readable output

- **Verify consistency**: `bash .agentic/tools/verify.sh`
  - Includes cross-reference checks for feature IDs

## Test-to-Feature Inference

The `coverage.py --test-mapping` command infers which tests validate which features using conventions (no annotations required).

### Inference Methods (Priority Order)

1. **Explicit Naming (High Confidence)**
   Test files named with feature ID are automatically mapped:
   ```
   tests/test_F0003_login.py → F-0003
   tests/test_F-0003_*.py → F-0003
   spec/F0003_spec.ts → F-0003
   ```

2. **Import Tracing (Medium Confidence)**
   If a test imports a file that has `@feature` annotations, the test is mapped to those features:
   ```python
   # test_auth.py
   from src.auth import login  # auth.py has @feature F-0003
   # → test_auth.py is mapped to F-0003
   ```

3. **Name Heuristics (Low Confidence)**
   _Reserved for future use._ Would match test names to feature descriptions.

### Example Output

```
Test→Feature Mapping (3 features with tests):
  F-0003:
    - tests/test_F0003_login.py (explicit_naming) [high]
    - tests/test_auth.py (import_tracing) [medium]
  F-0004:
    - tests/test_storage.py (import_tracing) [medium]
```

### Best Practices for Test Naming

For reliable test→feature mapping:
1. **Preferred**: Name test files with feature ID: `test_F0003_*.py`
2. **Alternative**: Import files that have `@feature` annotations
3. **Avoid**: Generic test names that require heuristic matching

## Migration strategy (for existing codebases)

1. Start with new features: annotate as you implement
2. Gradually annotate high-value existing features:
   - Core business logic first
   - Performance-critical paths (with NFR annotations)
   - Security-sensitive code (with NFR annotations)
3. Don't aim for 100% coverage - focus on traceability where it matters

## Language-specific notes

### JavaScript/TypeScript
- Use JSDoc format if you prefer: `/** @feature F-0001 */`
- Works in both .js and .ts files

### Python
- Use `# @feature F-0001` format
- Can also use docstrings for class/function-level annotations

### Rust
- Use `// @feature F-0001` or `/// @feature F-0001` (doc comments)

### Go
- Use `// @feature F-0001` format

### Other languages
- Use your language's comment syntax
- Pattern must be: `@feature F-####` for tool detection

