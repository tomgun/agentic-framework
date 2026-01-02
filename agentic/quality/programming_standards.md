# Programming Standards & Code Quality

**Purpose**: Define code quality standards for easy-to-maintain, understand, and test source code.

**Audience**: All agents (Test, Implementation, Refactoring) and human developers.

---

## Core Principles

### 1. Clarity Over Cleverness
- **Write code for humans first, machines second**
- Choose descriptive names over short/cryptic ones
- Favor explicit over implicit
- Avoid "magic" numbers, strings, or behaviors

**Bad**:
```typescript
const d = 86400000; // what is this?
if (x && x.l > 5 && !x.d) { ... } // cryptic
```

**Good**:
```typescript
const MILLISECONDS_PER_DAY = 24 * 60 * 60 * 1000;
if (user && user.loginAttempts > MAX_LOGIN_ATTEMPTS && !user.isDeleted) { ... }
```

### 2. Small & Focused
- **Functions**: One clear purpose, ~5-20 lines ideal
- **Classes**: Single responsibility, ~100-300 lines ideal
- **Files**: Related functionality, ~200-500 lines ideal
- If something is hard to name, it's probably doing too much

**Bad**:
```typescript
function processUserDataAndSendEmailAndUpdateDatabase(user) {
  // 150 lines doing 3 different things
}
```

**Good**:
```typescript
function validateUser(user): ValidationResult { ... }
function sendWelcomeEmail(user): Promise<void> { ... }
function saveUserToDatabase(user): Promise<void> { ... }
```

### 3. Testability First
- **Design code to be testable** (see `design_for_testability.md`)
- Inject dependencies (don't use globals/singletons)
- Separate pure logic from side effects
- Small functions are easier to test

### 4. Self-Documenting Code
- Good names eliminate need for comments
- Comments explain **why**, not **what**
- Code structure reveals intent

**Bad**:
```typescript
// Get the user
function g(i) {
  return db.query('SELECT * FROM users WHERE id = ?', [i]);
}
```

**Good**:
```typescript
function getUserById(userId: string): Promise<User> {
  // Query includes soft-deleted users for audit trail
  return db.query('SELECT * FROM users WHERE id = ?', [userId]);
}
```

---

## Naming Conventions

### Variables & Functions

**Style**: camelCase (JavaScript/TypeScript/Java), snake_case (Python/Rust)

**Rules**:
- **Boolean variables**: Use `is`, `has`, `can`, `should` prefix
  - `isActive`, `hasPermission`, `canEdit`, `shouldRetry`
- **Functions**: Start with verb describing action
  - `getUser`, `calculateTotal`, `validateEmail`, `sendNotification`
- **Arrays/Lists**: Plural names
  - `users`, `items`, `errors`
- **Constants**: UPPER_SNAKE_CASE
  - `MAX_RETRY_ATTEMPTS`, `DEFAULT_TIMEOUT_MS`

**Examples**:
```typescript
// Variables
const userName = 'John';           // camelCase
const isAuthenticated = true;      // boolean with 'is' prefix
const userList = [];               // plural for arrays

// Constants
const MAX_LOGIN_ATTEMPTS = 3;      // UPPER_SNAKE_CASE
const DEFAULT_PAGE_SIZE = 20;

// Functions
function getUserById(id: string) { ... }      // verb + noun
function calculateOrderTotal(items) { ... }   // verb + descriptive
function isValidEmail(email: string) { ... }  // boolean function
```

### Classes & Types

**Style**: PascalCase

**Rules**:
- Classes: Noun describing entity
  - `User`, `OrderProcessor`, `EmailService`
- Interfaces: Descriptive noun (avoid `I` prefix)
  - `UserRepository`, `EmailProvider` (not `IUserRepository`)
- Types/Interfaces: Describe shape/purpose
  - `UserData`, `ApiResponse`, `ValidationResult`

**Examples**:
```typescript
class UserAuthenticationService { ... }
interface DatabaseConnection { ... }
type ValidationResult = { isValid: boolean; errors: string[] };
```

### Files & Directories

**Style**: kebab-case (web) or snake_case (Python), PascalCase (classes in Java/C#)

**Rules**:
- One primary export per file
- File name matches primary export
- Group related files in directories

**Examples**:
```
user-authentication-service.ts  → exports UserAuthenticationService
email-validator.ts              → exports validateEmail, isValidEmail
types/                          → shared types
  user.ts                       → User type
  api-response.ts               → ApiResponse type
```

---

## Function Design

### Function Length
- **Target**: 5-20 lines
- **Maximum**: 50 lines (if longer, extract subfunctions)
- **If too long**: Extract helper functions with clear names

### Function Parameters
- **Maximum**: 3-4 parameters ideal
- **If more than 4**: Use object parameter
- **Required first, optional last**

**Bad**:
```typescript
function createUser(name, email, age, address, phone, isAdmin, createdAt, updatedAt) {
  // Too many parameters
}
```

**Good**:
```typescript
interface CreateUserParams {
  name: string;
  email: string;
  age: number;
  address: string;
  phone?: string;
  isAdmin?: boolean;
}

function createUser(params: CreateUserParams): User {
  // Clear, extensible
}
```

### Return Values
- **Be consistent**: Either always return or always throw, not mix
- **Use typed returns**: Define return types explicitly
- **Avoid nulls where possible**: Use `Option<T>`, `Result<T, E>`, or throw

**Good patterns**:
```typescript
// Return result object
function validatePassword(password: string): ValidationResult {
  return {
    isValid: password.length >= 8,
    errors: password.length < 8 ? ['Password too short'] : []
  };
}

// Throw on error
function getUserById(id: string): User {
  const user = db.findUser(id);
  if (!user) throw new UserNotFoundError(id);
  return user;
}

// Return null for optional
function findUserByEmail(email: string): User | null {
  return db.findUser({ email }) ?? null;
}
```

---

## Error Handling

### Principles
- **Fail fast**: Validate inputs early
- **Be specific**: Use specific error types/classes
- **Context**: Include relevant details in errors
- **Don't swallow errors**: Log, re-throw, or handle explicitly

### Error Types

**Define custom errors**:
```typescript
class UserNotFoundError extends Error {
  constructor(userId: string) {
    super(`User not found: ${userId}`);
    this.name = 'UserNotFoundError';
  }
}

class ValidationError extends Error {
  constructor(public field: string, public reason: string) {
    super(`Validation failed for ${field}: ${reason}`);
    this.name = 'ValidationError';
  }
}
```

### Error Handling Patterns

**Input validation** (fail fast):
```typescript
function processOrder(order: Order): void {
  if (!order) throw new Error('Order is required');
  if (!order.items || order.items.length === 0) {
    throw new ValidationError('items', 'Order must have at least one item');
  }
  // ... rest of logic
}
```

**Try-catch** (expected errors):
```typescript
async function fetchUserData(userId: string): Promise<User> {
  try {
    return await api.getUser(userId);
  } catch (error) {
    if (error instanceof NetworkError) {
      // Handle network failure
      throw new UserFetchError(`Failed to fetch user ${userId}: network error`);
    }
    // Unexpected error, re-throw
    throw error;
  }
}
```

**Result pattern** (for expected failures):
```typescript
type Result<T, E> = { ok: true; value: T } | { ok: false; error: E };

function parseDate(input: string): Result<Date, string> {
  const date = new Date(input);
  if (isNaN(date.getTime())) {
    return { ok: false, error: `Invalid date: ${input}` };
  }
  return { ok: true, value: date };
}
```

---

## Code Organization

### Imports/Dependencies
- **Order**: External libraries → Internal modules → Types
- **Group**: Related imports together
- **No unused imports**

```typescript
// External libraries
import express from 'express';
import jwt from 'jsonwebtoken';

// Internal modules
import { getUserById, updateUser } from './user-service';
import { validateToken } from './auth-utils';

// Types
import type { User, AuthToken } from './types';
```

### File Structure
```
Top of file:
  1. Imports
  2. Types/Interfaces (if small, otherwise separate file)
  3. Constants
  4. Main functions/classes
  5. Helper functions (after main code)
  6. Exports (if not inline)
```

**Example**:
```typescript
// 1. Imports
import { v4 as uuidv4 } from 'uuid';
import type { User, UserId } from './types';

// 2. Types (small ones)
type CreateUserResult = { success: boolean; userId?: UserId };

// 3. Constants
const MIN_PASSWORD_LENGTH = 8;
const MAX_LOGIN_ATTEMPTS = 3;

// 4. Main functions
export function createUser(email: string, password: string): CreateUserResult {
  if (!isValidPassword(password)) {
    return { success: false };
  }
  // ... implementation
}

export function deleteUser(userId: UserId): void {
  // ... implementation
}

// 5. Helper functions
function isValidPassword(password: string): boolean {
  return password.length >= MIN_PASSWORD_LENGTH;
}
```

---

## Comments & Documentation

### When to Comment

**DO comment**:
- **Why**: Explain non-obvious decisions
  ```typescript
  // Use exponential backoff to avoid overwhelming the API
  await delay(2 ** retryCount * 1000);
  ```
- **Gotchas**: Warn about edge cases or tricky behavior
  ```typescript
  // IMPORTANT: This function mutates the input array for performance
  function sortInPlace(arr: number[]): void { ... }
  ```
- **TODOs**: Mark technical debt (with ticket reference if possible)
  ```typescript
  // TODO(F-0042): Refactor to use async/await instead of callbacks
  ```
- **Public APIs**: Document parameters, returns, errors (JSDoc/docstrings)
  ```typescript
  /**
   * Fetches user by ID from the database.
   * @param userId - The unique user identifier
   * @returns The user object
   * @throws {UserNotFoundError} If user doesn't exist
   */
  function getUserById(userId: string): User { ... }
  ```

**DON'T comment**:
- **What**: Code should be self-explanatory
  ```typescript
  // BAD: Increment counter by 1
  counter++;
  
  // BAD: Loop through users
  for (const user of users) { ... }
  ```
- **Redundant info**: Don't repeat what code already says
  ```typescript
  // BAD: Set isActive to true
  user.isActive = true;
  ```

### Feature Annotations

**Always add** (see `code_annotations.md`):
```typescript
// @feature F-0042
// @acceptance AC1, AC2
// @nfr NFR-0003
function validateUserPassword(password: string): boolean {
  // ... implementation
}
```

---

## Specific Language Guidelines

### TypeScript/JavaScript

**Use TypeScript features**:
- Explicit types for function parameters and returns
- Interfaces for object shapes
- Enums for fixed sets of values
- Avoid `any` (use `unknown` if needed)

```typescript
// Good
function calculateDiscount(
  price: number,
  discountPercent: number
): number {
  return price * (1 - discountPercent / 100);
}

// Bad
function calculateDiscount(price, discount) {
  return price * (1 - discount / 100);
}
```

**Prefer const over let**, never var:
```typescript
const MAX_ITEMS = 100;        // Never changes
let currentCount = 0;         // Changes
// var x = 0;                 // NEVER use var
```

**Use modern ES6+ features**:
- Arrow functions for callbacks
- Destructuring for objects/arrays
- Template literals for strings
- Spread operator for copying
- Optional chaining (`?.`) and nullish coalescing (`??`)

```typescript
// Modern
const { name, email } = user;
const greeting = `Hello, ${name}!`;
const updatedUser = { ...user, lastLogin: new Date() };
const userName = user?.profile?.name ?? 'Anonymous';

// Avoid
const name = user.name;
const email = user.email;
const greeting = 'Hello, ' + name + '!';
const updatedUser = Object.assign({}, user, { lastLogin: new Date() });
```

### Python

**Follow PEP 8**:
- snake_case for functions/variables
- PascalCase for classes
- UPPER_SNAKE_CASE for constants
- Type hints for function parameters and returns

```python
# Good
def calculate_user_score(user_id: str, attempts: int) -> float:
    """Calculate score based on user attempts."""
    if attempts == 0:
        return 0.0
    return 100.0 / attempts

class UserService:
    MAX_RETRY_ATTEMPTS = 3
    
    def get_user(self, user_id: str) -> User:
        ...
```

**Use modern Python features**:
- Type hints (Python 3.5+)
- F-strings (Python 3.6+)
- Dataclasses (Python 3.7+)
- Union types with `|` (Python 3.10+)

```python
from dataclasses import dataclass

@dataclass
class User:
    id: str
    name: str
    email: str
    is_active: bool = True

def greet_user(user: User) -> str:
    return f"Hello, {user.name}!"
```

---

## Anti-Patterns to Avoid

### 1. Magic Numbers
**Bad**:
```typescript
if (user.loginAttempts > 5) { ... }
setTimeout(callback, 3000);
```

**Good**:
```typescript
const MAX_LOGIN_ATTEMPTS = 5;
const RETRY_DELAY_MS = 3000;

if (user.loginAttempts > MAX_LOGIN_ATTEMPTS) { ... }
setTimeout(callback, RETRY_DELAY_MS);
```

### 2. Deep Nesting
**Bad**:
```typescript
if (user) {
  if (user.isActive) {
    if (user.hasPermission('edit')) {
      if (document.isPublished) {
        // Too deep!
      }
    }
  }
}
```

**Good**:
```typescript
if (!user || !user.isActive) return;
if (!user.hasPermission('edit')) return;
if (!document.isPublished) return;
// Flat structure
```

### 3. God Objects/Functions
**Avoid**: Functions/classes that do everything

**Instead**: Break into smaller, focused units

### 4. Global State
**Avoid**: Global variables, singletons for everything

**Instead**: Dependency injection, explicit passing

### 5. Premature Optimization
**Avoid**: Optimizing before measuring

**Instead**: Make it work, make it right, make it fast (in that order)

### 6. Copy-Paste Programming
**Avoid**: Duplicating code

**Instead**: Extract shared logic into functions

---

## Code Review Checklist (for agents)

Before marking code complete, verify:

- [ ] **Names** are clear and descriptive
- [ ] **Functions** are small (<50 lines) and focused
- [ ] **No magic numbers** (constants are named)
- [ ] **Error handling** is present and specific
- [ ] **Type safety** (TypeScript types, Python hints)
- [ ] **No deep nesting** (< 4 levels ideal)
- [ ] **No duplication** (DRY - Don't Repeat Yourself)
- [ ] **Comments** explain why, not what
- [ ] **Feature annotations** present (`@feature`, `@acceptance`)
- [ ] **Tests** exist and pass
- [ ] **Imports** are organized and unused ones removed
- [ ] **Console logs / debug code** removed
- [ ] **TODOs** have context (not just "TODO: fix this")

---

## Language-Specific Style Guides (Reference)

### JavaScript/TypeScript
- **Primary**: [Airbnb JavaScript Style Guide](https://github.com/airbnb/javascript)
- **TypeScript**: [TypeScript Style Guide](https://google.github.io/styleguide/tsguide.html)
- **Formatting**: ESLint + Prettier (configure in project)

### Python
- **Primary**: [PEP 8](https://peps.python.org/pep-0008/)
- **Type Hints**: [PEP 484](https://peps.python.org/pep-0484/)
- **Formatting**: black, ruff (configure in project)

### Go
- **Primary**: `gofmt` (standard formatter)
- **Guide**: [Effective Go](https://go.dev/doc/effective_go)

### Rust
- **Primary**: `rustfmt` (standard formatter)
- **Guide**: [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/)

---

## Implementation Agent Checklist

**When implementing code, always**:

1. **Read** acceptance criteria first
2. **Design** for testability (inject dependencies)
3. **Write** small, focused functions
4. **Name** clearly and descriptively
5. **Handle** errors explicitly
6. **Add** feature annotations
7. **Format** using project linter/formatter
8. **Review** against this guide before submitting

---

## See Also

- [`design_for_testability.md`](design_for_testability.md) - Making code testable
- [`test_strategy.md`](test_strategy.md) - Testing approach
- [`review_checklist.md`](review_checklist.md) - Code review criteria
- [`tdd_mode.md`](../workflows/tdd_mode.md) - Test-driven development
- [`code_annotations.md`](../workflows/code_annotations.md) - Linking code to specs

