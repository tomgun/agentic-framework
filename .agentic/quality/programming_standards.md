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

### 2. Security First
- **Validate all external input** (user input, API calls, file reads)
- **Never trust data** from untrusted sources
- **Sanitize output** (prevent XSS, injection attacks)
- **Protect secrets** (no hardcoded credentials, use environment variables)
- **Follow principle of least privilege** (minimal permissions)

See [Security Best Practices](#security-best-practices) section for details.

### 3. Efficiency When Measured
- **Make it work, make it right, then make it fast** (in that order)
- **Profile before optimizing** (don't guess)
- **Optimize hot paths** (where data shows bottlenecks)
- **Green coding**: Energy efficiency matters, but clarity comes first
  - Caching reduces compute, but adds complexity
  - Choose simple solutions first, optimize when needed

See [Performance & Efficiency](#performance--efficiency) section for details.

### 4. Small & Focused
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

### 5. Testability First (CRITICAL)
- **Design code to be testable WITHOUT running the UI** (see `design_for_testability.md`)
- **Separate business logic from presentation** (Model-View separation)
- **Business logic should be pure functions** (no UI dependencies, no global state)
- Inject dependencies (don't use globals/singletons)
- Separate pure logic from side effects
- Small functions are easier to test
- **See `.agentic/checklists/smoke_testing.md` for testable architecture patterns**

**Critical lesson from real projects:**
```typescript
// ❌ BAD: Game logic mixed with UI (CANNOT test without UI)
const GameBoard = () => {
  const handleClick = (square) => {
    // Logic tightly coupled to React state and DOM
    if (selectedPiece && isValidMove(selectedPiece, square)) {
      // Direct state mutation, no way to test this logic!
      board[square.x][square.y] = selectedPiece;
      setCurrentPlayer(currentPlayer === 'white' ? 'black' : 'white');
    }
  };
};

// ✅ GOOD: Game logic separated (CAN test without UI)
// src/engine/gameEngine.ts
class GameEngine {
  applyMove(state: GameState, move: Move): GameState {
    // Pure function: state + move → new state
    // Easy to unit test!
    if (!this.isValidMove(state, move)) {
      throw new Error("Invalid move");
    }
    const newState = { ...state };
    newState.board[move.to.x][move.to.y] = state.board[move.from.x][move.from.y];
    newState.currentPlayer = state.currentPlayer === 'white' ? 'black' : 'white';
    return newState;
  }
}

// src/ui/GameBoard.tsx (thin UI layer)
const GameBoard = () => {
  const [gameState, setGameState] = useState(initialState);
  const engine = new GameEngine();
  
  const handleClick = (square) => {
    try {
      const newState = engine.applyMove(gameState, { from: selected, to: square });
      setGameState(newState); // UI just renders the new state
    } catch (error) {
      showError(error.message);
    }
  };
};
```

### 6. Self-Documenting Code
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

## Security Best Practices

### Input Validation (CRITICAL)

**Validate all external input immediately**:

```typescript
// Web API endpoint
function createUser(req: Request): Response {
  // Validate FIRST
  if (!req.body.email || !isValidEmail(req.body.email)) {
    throw new ValidationError('Invalid email');
  }
  if (!req.body.password || req.body.password.length < 8) {
    throw new ValidationError('Password must be at least 8 characters');
  }
  
  // Sanitize
  const email = sanitizeEmail(req.body.email);
  const name = sanitizeHtml(req.body.name); // Remove potential XSS
  
  // Then proceed
  return userService.createUser({ email, name, password: req.body.password });
}
```

**Validation rules**:
- **Whitelist over blacklist**: Define what's allowed, not what's forbidden
- **Type checking**: Ensure data types are correct
- **Range checking**: Verify numbers are in valid ranges
- **Format validation**: Use regex for emails, phone numbers, etc. (but carefully - avoid ReDoS)
- **Length limits**: Prevent buffer overflows, DoS attacks

### SQL Injection Prevention

**ALWAYS use parameterized queries** (never string concatenation):

```typescript
// ❌ BAD - SQL Injection vulnerable
function getUserByEmail(email: string) {
  return db.query(`SELECT * FROM users WHERE email = '${email}'`);
  // Attacker can send: ' OR '1'='1' --
}

// ✅ GOOD - Parameterized query
function getUserByEmail(email: string) {
  return db.query('SELECT * FROM users WHERE email = ?', [email]);
  // Driver escapes the parameter safely
}
```

### XSS (Cross-Site Scripting) Prevention

**Sanitize all user-generated content before displaying**:

```typescript
import DOMPurify from 'dompurify';

// ❌ BAD - XSS vulnerable
function displayUserComment(comment: string) {
  document.getElementById('comment').innerHTML = comment;
  // Attacker can send: <script>stealCookies()</script>
}

// ✅ GOOD - Sanitized
function displayUserComment(comment: string) {
  const sanitized = DOMPurify.sanitize(comment);
  document.getElementById('comment').innerHTML = sanitized;
}

// Even better: Use textContent for plain text
function displayUserComment(comment: string) {
  document.getElementById('comment').textContent = comment; // No HTML parsing
}
```

### Authentication & Authorization

**Check permissions before actions**:

```typescript
// ✅ GOOD - Check authentication and authorization
async function deleteUser(requesterId: string, targetUserId: string): Promise<void> {
  // 1. Authenticate: Who is making the request?
  const requester = await getUserById(requesterId);
  if (!requester) {
    throw new UnauthenticatedError('User not logged in');
  }
  
  // 2. Authorize: Can they perform this action?
  if (!requester.isAdmin && requester.id !== targetUserId) {
    throw new UnauthorizedError('Cannot delete other users');
  }
  
  // 3. Perform action
  await db.deleteUser(targetUserId);
}
```

### Secrets Management

**NEVER hardcode secrets**:

```typescript
// ❌ BAD - Hardcoded secrets
const API_KEY = 'sk_live_abc123...';
const DB_PASSWORD = 'mypassword123';

// ✅ GOOD - Environment variables
const API_KEY = process.env.API_KEY;
const DB_PASSWORD = process.env.DB_PASSWORD;

if (!API_KEY || !DB_PASSWORD) {
  throw new Error('Required environment variables not set');
}
```

**Security checklist for secrets**:
- Use environment variables (`.env` file, never commit to git)
- Use secret management services (AWS Secrets Manager, HashiCorp Vault)
- Rotate secrets regularly
- Use different secrets for dev/staging/production
- Never log secrets (even in error messages)

### Cryptography

**Use proven libraries, don't roll your own**:

```typescript
import bcrypt from 'bcrypt';
import crypto from 'crypto';

// ✅ Password hashing (bcrypt, argon2, scrypt)
async function hashPassword(password: string): Promise<string> {
  const saltRounds = 10;
  return bcrypt.hash(password, saltRounds);
}

async function verifyPassword(password: string, hash: string): Promise<boolean> {
  return bcrypt.compare(password, hash);
}

// ✅ Generating secure random tokens
function generateSecureToken(): string {
  return crypto.randomBytes(32).toString('hex');
}

// ❌ BAD - Weak hashing
function weakHash(password: string): string {
  return crypto.createHash('md5').update(password).digest('hex'); // MD5 is broken!
}
```

### HTTPS & Transport Security

**Always use HTTPS in production**:

```typescript
// ✅ Enforce HTTPS
app.use((req, res, next) => {
  if (process.env.NODE_ENV === 'production' && !req.secure) {
    return res.redirect(301, `https://${req.headers.host}${req.url}`);
  }
  next();
});

// ✅ Set security headers
app.use((req, res, next) => {
  res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  next();
});
```

### Rate Limiting & DoS Prevention

**Protect against abuse**:

```typescript
import rateLimit from 'express-rate-limit';

// Limit login attempts
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 attempts
  message: 'Too many login attempts, please try again later'
});

app.post('/api/login', loginLimiter, async (req, res) => {
  // Login logic
});

// Limit API requests per user
const apiLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 100, // 100 requests per minute per user
  keyGenerator: (req) => req.user?.id || req.ip
});

app.use('/api/', apiLimiter);
```

### Security Logging & Monitoring

**Log security events** (but not sensitive data):

```typescript
// ✅ GOOD - Log security events
function handleLoginAttempt(email: string, success: boolean, ip: string) {
  logger.info('Login attempt', {
    email: email, // OK to log
    success: success,
    ip: ip,
    timestamp: new Date().toISOString()
  });
}

// ❌ BAD - Logging sensitive data
function handleLoginAttempt(email: string, password: string, success: boolean) {
  logger.info('Login attempt', {
    email: email,
    password: password, // NEVER log passwords!
    success: success
  });
}
```

**What to log**:
- ✅ Authentication events (login, logout, failed attempts)
- ✅ Authorization failures (access denied)
- ✅ Suspicious activity (unusual patterns, rate limit hits)
- ❌ Passwords, API keys, tokens, credit card numbers, PII

---

## Performance & Efficiency

### Principles

1. **Make it work, make it right, make it fast** (in that order)
2. **Profile before optimizing** (measure, don't guess)
3. **Optimize hot paths** (where profiler shows bottlenecks)
4. **Premature optimization is the root of all evil** (Donald Knuth)

### When to Optimize

**✅ Optimize when**:
- Profiler shows bottleneck
- NFR specifies performance requirement
- User-visible slowness (>100ms for UI interaction)
- Resource usage unsustainable (memory leaks, CPU spikes)

**❌ Don't optimize when**:
- "This might be slow" (without evidence)
- Code is already fast enough
- Optimization makes code harder to understand (unless critical)

### Efficient Data Structures

**Choose right data structure for the job**:

```typescript
// ❌ Slow - O(n) lookup
const users = []; // Array
function findUserById(id: string) {
  return users.find(u => u.id === id); // Linear search
}

// ✅ Fast - O(1) lookup
const users = new Map<string, User>(); // Map/HashMap
function findUserById(id: string) {
  return users.get(id); // Constant time
}
```

**Common patterns**:
- **Frequent lookups**: Use Map/HashMap/Dict (O(1) vs Array O(n))
- **Ordered data**: Use sorted arrays + binary search (O(log n))
- **Unique items**: Use Set (O(1) membership test vs Array O(n))
- **FIFO queue**: Use Queue (O(1) enqueue/dequeue vs Array O(n) shift)

### Database Query Optimization

**Minimize database roundtrips**:

```typescript
// ❌ BAD - N+1 query problem
async function getUsersWithOrders(userIds: string[]) {
  const users = await db.getUsers(userIds);
  for (const user of users) {
    user.orders = await db.getOrdersByUserId(user.id); // N queries!
  }
  return users;
}

// ✅ GOOD - Single query with JOIN
async function getUsersWithOrders(userIds: string[]) {
  return db.query(`
    SELECT users.*, orders.*
    FROM users
    LEFT JOIN orders ON users.id = orders.user_id
    WHERE users.id IN (?)
  `, [userIds]);
}
```

**Database performance checklist**:
- Add indexes on frequently queried columns
- Use `EXPLAIN` to analyze query plans
- Avoid `SELECT *` (select only needed columns)
- Use pagination for large result sets
- Cache frequently accessed data (with invalidation strategy)

### Caching (Green Coding)

**Cache expensive operations** (but add complexity mindfully):

```typescript
// Simple in-memory cache
const cache = new Map<string, CacheEntry>();

async function getUser(userId: string): Promise<User> {
  // Check cache first
  const cached = cache.get(userId);
  if (cached && Date.now() - cached.timestamp < 60000) { // 1 minute TTL
    return cached.value;
  }
  
  // Cache miss - fetch from database
  const user = await db.getUserById(userId);
  cache.set(userId, { value: user, timestamp: Date.now() });
  return user;
}

// Invalidate cache on update
async function updateUser(userId: string, updates: Partial<User>) {
  await db.updateUser(userId, updates);
  cache.delete(userId); // Invalidate cache
}
```

**Caching considerations**:
- ✅ Reduces compute/energy (green coding)
- ✅ Improves response time
- ⚠️ Adds complexity (cache invalidation is hard)
- ⚠️ Stale data risk (need expiration/invalidation strategy)
- 💡 Use for: Read-heavy data, expensive computations, external API calls

### Lazy Loading & Pagination

**Don't load everything at once**:

```typescript
// ❌ BAD - Load all users (could be millions)
async function getAllUsers() {
  return db.query('SELECT * FROM users');
}

// ✅ GOOD - Paginate
async function getUsers(page: number, pageSize: number = 20) {
  const offset = page * pageSize;
  return db.query('SELECT * FROM users LIMIT ? OFFSET ?', [pageSize, offset]);
}

// ✅ GOOD - Lazy load related data
interface User {
  id: string;
  name: string;
  getOrders(): Promise<Order[]>; // Lazy load orders only when needed
}
```

### Async & Parallel Processing

**Don't block unnecessarily**:

```typescript
// ❌ BAD - Sequential (slow)
async function fetchAllData() {
  const users = await fetchUsers();      // Wait 500ms
  const products = await fetchProducts(); // Wait 500ms
  const orders = await fetchOrders();    // Wait 500ms
  return { users, products, orders };    // Total: 1500ms
}

// ✅ GOOD - Parallel (fast)
async function fetchAllData() {
  const [users, products, orders] = await Promise.all([
    fetchUsers(),      // All run in parallel
    fetchProducts(),   //
    fetchOrders()      //
  ]);
  return { users, products, orders }; // Total: 500ms (slowest)
}
```

### Resource Management

**Clean up resources**:

```typescript
// ✅ Always close connections/files
async function processFile(filePath: string) {
  const file = await fs.open(filePath, 'r');
  try {
    const data = await file.readFile();
    return processData(data);
  } finally {
    await file.close(); // Always close, even on error
  }
}

// ✅ Use connection pools (not one connection per request)
const pool = new pg.Pool({
  max: 20, // Maximum 20 connections
  idleTimeoutMillis: 30000
});
```

### Memory Efficiency

**Avoid memory leaks**:

```typescript
// ❌ BAD - Memory leak (listeners never removed)
class EventEmitter {
  private listeners = [];
  
  on(event: string, callback: Function) {
    this.listeners.push(callback); // Accumulates forever!
  }
}

// ✅ GOOD - Provide cleanup
class EventEmitter {
  private listeners = new Map<string, Set<Function>>();
  
  on(event: string, callback: Function): () => void {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set());
    }
    this.listeners.get(event)!.add(callback);
    
    // Return cleanup function
    return () => this.off(event, callback);
  }
  
  off(event: string, callback: Function) {
    this.listeners.get(event)?.delete(callback);
  }
}
```

### Green Coding (Environmental Efficiency)

**Principles**:
- Energy-efficient code reduces carbon footprint
- But: **Clarity comes first**, optimize when justified
- Caching/memoization saves energy (fewer computations)
- Efficient algorithms reduce compute time (greener)
- Lazy loading reduces unnecessary work

**Balance**:
```typescript
// Simple & clear (good default)
function calculateDiscount(price: number, percent: number): number {
  return price * (1 - percent / 100);
}

// Cached (if called frequently with same inputs)
const discountCache = new Map<string, number>();

function calculateDiscount(price: number, percent: number): number {
  const key = `${price}-${percent}`;
  if (discountCache.has(key)) {
    return discountCache.get(key)!; // Saves computation (green)
  }
  
  const result = price * (1 - percent / 100);
  discountCache.set(key, result);
  return result;
}
// Trade-off: More complex, but saves energy if called often
```

**Green coding checklist**:
- ✅ Use efficient algorithms (O(n log n) vs O(n²))
- ✅ Cache when read-heavy
- ✅ Lazy load (don't process what's not needed)
- ✅ Optimize hot paths (measured with profiler)
- ✅ Clean up resources (prevent leaks)
- ❌ Don't sacrifice clarity for minor gains

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

**Correctness & Functionality**:
- [ ] **Meets acceptance criteria** (all ACs verified)
- [ ] **Edge cases handled** (empty input, null, boundary values)
- [ ] **Error handling present** and specific

**Code Quality**:
- [ ] **Names** are clear and descriptive (no cryptic abbreviations)
- [ ] **Functions** are small (<50 lines) and focused (single purpose)
- [ ] **No magic numbers** (constants are named)
- [ ] **Type safety** (TypeScript types, Python hints present)
- [ ] **No deep nesting** (< 4 levels ideal)
- [ ] **No duplication** (DRY - Don't Repeat Yourself)
- [ ] **Comments** explain why, not what
- [ ] **Imports** are organized and unused ones removed
- [ ] **Console logs / debug code** removed

**Security** (CRITICAL):
- [ ] **Input validation** present for all external input
- [ ] **SQL queries** use parameterized queries (no string concatenation)
- [ ] **XSS prevention**: User content sanitized before display
- [ ] **Authentication/Authorization** checked before sensitive operations
- [ ] **No hardcoded secrets** (use environment variables)
- [ ] **No sensitive data in logs** (passwords, tokens, API keys)
- [ ] **HTTPS enforced** in production code
- [ ] **Rate limiting** present for abuse-prone endpoints (login, API)

**Performance & Efficiency**:
- [ ] **No obvious performance issues** (e.g., N+1 queries)
- [ ] **Efficient data structures** used (Map for lookups, Set for unique items)
- [ ] **Database queries optimized** (indexes, no SELECT *, pagination)
- [ ] **Async operations parallelized** where appropriate (Promise.all)
- [ ] **Resources cleaned up** (connections closed, listeners removed)
- [ ] **Caching considered** for expensive/frequent operations (if justified)
- [ ] **Optimization justified** (profiled, not premature)

**Testing & Documentation**:
- [ ] **Feature annotations** present (`@feature`, `@acceptance`, `@nfr`)
- [ ] **Tests** exist and pass (unit, integration, E2E as needed)
- [ ] **Test coverage adequate** (>80% for business logic)
- [ ] **TODOs** have context (not just "TODO: fix this")

**Project Integration**:
- [ ] **Formatted** using project linter/formatter
- [ ] **Quality checks** pass (`quality_checks.sh`)
- [ ] **Specs updated** (FEATURES.md, STATUS.md if needed)

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

