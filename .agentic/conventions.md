# Project Conventions

Code quality standards for agents and developers. STACK.md may override these with project-specific rules.

## Security (validate at boundaries)

1. **Validate all external input** — user input, API payloads, file reads, environment variables.
2. **Parameterized queries only** — never interpolate user data into SQL, shell commands, or templates.
3. **Sanitize output** — prevent XSS by escaping or using textContent. Never `innerHTML` with user data.
4. **No hardcoded secrets** — use environment variables. Never commit `.env`, credentials, or API keys.
5. **Least privilege** — request minimal permissions. Check authorization before every action.

## Testability (design for it)

1. **Dependency injection** — pass dependencies as parameters, don't import singletons.
2. **Pure functions** — business logic should take input and return output with no side effects.
3. **Separate logic from I/O** — keep business rules in pure modules, I/O in thin boundary layers.
4. **Small functions** — 5-20 lines ideal. If it's hard to test, it's doing too much.
5. **Explicit error handling** — fail fast with specific errors. No silent failures or swallowed exceptions.

## Naming

| Thing | Style | Example |
|-------|-------|---------|
| Variables/functions | camelCase (JS/TS) or snake_case (Python) | `getUserById`, `get_user_by_id` |
| Booleans | `is`/`has`/`can`/`should` prefix | `isActive`, `hasPermission` |
| Constants | UPPER_SNAKE_CASE | `MAX_RETRY_ATTEMPTS` |
| Classes/types | PascalCase | `UserService`, `ValidationResult` |
| Files | kebab-case (JS/TS) or snake_case (Python) | `user-service.ts`, `user_service.py` |

- Functions start with a verb: `get`, `create`, `validate`, `send`, `calculate`.
- Arrays/lists use plural names: `users`, `items`, `errors`.
- No cryptic abbreviations. `calculateTotal` over `calcTot`.

## Code structure

- **Functions**: <50 lines. One purpose. If it's hard to name, it does too much.
- **Parameters**: 3-4 max. Use an options object if more are needed.
- **Nesting**: <4 levels deep. Use early returns to flatten.
- **No magic numbers**: Name all constants. `MILLISECONDS_PER_DAY` not `86400000`.
- **Comments explain why, not what**: Good code is self-documenting. Comment non-obvious decisions.
- **Import order**: External libraries, then internal modules, then types. No unused imports.

## Efficiency (green coding summary)

1. **Minimize dependencies** — each dep is attack surface, build time, and maintenance burden.
2. **Avoid wasteful patterns** — no polling when events work, no `SELECT *` when 2 columns suffice, no N+1 queries.
3. **Prefer efficient algorithms** — O(n) with a Map beats O(n^2) with nested loops. Profile before optimizing hot paths.
4. **Clean up resources** — close connections, remove listeners, release handles. Use `try/finally` or equivalent.

## Small batch development

1. **One feature at a time** per agent. Complete it before starting another.
2. **Max 5-10 files per commit**. If more are needed, break the feature into smaller pieces.
3. **One logical change per commit**. Don't mix refactoring with feature work.
4. **Commit often** — at least once per hour of work. Each commit should leave the project in a working state.

## Error handling

- **Fail fast**: Validate inputs at function entry. Don't let bad data propagate.
- **Be specific**: Custom error types beat generic `Error`. Include context (what failed, what was expected).
- **Don't swallow errors**: Log, re-throw, or handle explicitly. Never empty `catch {}`.
- **Result types for expected failures**: Use `Result<T, E>` or equivalent when failure is a normal outcome, not an exception.

## Testing standards

- Test the **happy path**, **edge cases**, **invalid input**, and **error conditions**.
- Tests must be **deterministic** — no flaky tests, no reliance on external services.
- A test should **fail before the fix and pass after**. If it always passes, it proves nothing.
- Ask: "Could this test pass with a broken implementation?" If yes, it's too weak.

## Project-specific overrides

Check `STACK.md` for project-specific settings that override these defaults:
- `development_mode` — standard (implement first) or tdd (test first)
- Language-specific linting and formatting rules
- Additional security requirements or NFRs
- Custom file organization patterns

**Project-specific conventions**: If `.agentic/local/conventions.md` exists, it contains
additional project-specific coding conventions that supplement and may override the defaults
above. Always check that file for project-level rules before implementing.
