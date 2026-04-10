# Code Quality Standards

Universal coding standards for clarity, maintainability, and correctness. Supplements `conventions.md` with detailed patterns and anti-patterns.

## Clarity Over Cleverness

Write code for humans first, machines second. The person reading this code in 6 months might be you.

### Naming
```typescript
// BAD: Cryptic abbreviations
const d = 86400000
const usrs = getUsrs(q)
if (x && x.l > 5 && !x.d) { ... }

// GOOD: Descriptive, self-documenting
const MILLISECONDS_PER_DAY = 24 * 60 * 60 * 1000
const users = getUsersByQuery(searchQuery)
if (user && user.loginAttempts > MAX_LOGIN_ATTEMPTS && !user.isDeleted) { ... }
```

### Functions
- **One purpose**: If a function does two things, make two functions
- **5-20 lines ideal**: If it's hard to read in one screen, break it up
- **Verb naming**: `calculateTotal`, `sendEmail`, `validateUser` — not `data`, `process`, `handle`
- **3-4 parameters max**: Use an options object if more are needed

```typescript
// BAD: Does three things, cryptic name
function processUserDataAndSendEmailAndUpdateDatabase(user) {
  // 150 lines doing 3 different things
}

// GOOD: Single purpose each
function validateUser(user): ValidationResult { ... }
function sendWelcomeEmail(user): Promise<void> { ... }
function saveUser(user): Promise<void> { ... }
```

### Early Returns (Flatten Nesting)
```typescript
// BAD: Deep nesting
function getDiscount(user) {
  if (user) {
    if (user.isPremium) {
      if (user.orders > 10) {
        return 0.2
      } else {
        return 0.1
      }
    } else {
      return 0
    }
  } else {
    return 0
  }
}

// GOOD: Early returns, flat
function getDiscount(user) {
  if (!user) return 0
  if (!user.isPremium) return 0
  if (user.orders > 10) return 0.2
  return 0.1
}
```

## Error Handling

### Fail Fast
Validate inputs at function entry. Don't let bad data propagate through layers.

```typescript
function transferMoney(from: Account, to: Account, amount: number) {
  // Validate immediately
  if (amount <= 0) throw new Error('Amount must be positive')
  if (amount > from.balance) throw new InsufficientFundsError()
  if (from.id === to.id) throw new Error('Cannot transfer to same account')

  // Proceed only with valid inputs
  from.debit(amount)
  to.credit(amount)
}
```

### Be Specific
Custom error types beat generic `Error`. Include context.

```typescript
// BAD: Generic, no context
throw new Error('Failed')

// GOOD: Specific, contextual
throw new OrderNotFoundError(`Order ${orderId} not found for user ${userId}`)
```

### Don't Swallow Errors
```typescript
// BAD: Silent failure — bug will manifest elsewhere
try {
  await saveToDatabase(data)
} catch (e) {
  // Nothing. Data is lost, no one knows.
}

// GOOD: Log, re-throw, or handle explicitly
try {
  await saveToDatabase(data)
} catch (e) {
  logger.error('Failed to save data', { error: e, data: data.id })
  throw e  // Let caller decide
}
```

### Result Types for Expected Failures
When failure is a normal outcome (not an exceptional case), use Result types:

```typescript
type Result<T, E> = { ok: true; value: T } | { ok: false; error: E }

function parseEmail(input: string): Result<Email, ValidationError> {
  if (!input.includes('@')) {
    return { ok: false, error: new ValidationError('Missing @') }
  }
  return { ok: true, value: new Email(input) }
}

// Caller handles both cases explicitly
const result = parseEmail(input)
if (!result.ok) {
  showError(result.error.message)
  return
}
const email = result.value
```

## Design for Testability

### Pure Core + Imperative Shell
Separate business logic (pure functions) from I/O (database, network, filesystem).

```typescript
// PURE CORE: Easy to test, no mocks needed
function calculateOrderTotal(items: LineItem[], taxRate: number): number {
  const subtotal = items.reduce((sum, item) => sum + item.price * item.quantity, 0)
  return subtotal * (1 + taxRate)
}

// IMPERATIVE SHELL: Thin, orchestrates I/O
async function processOrder(orderId: string) {
  const order = await db.getOrder(orderId)           // I/O
  const taxRate = await taxService.getRate(order.zip) // I/O
  const total = calculateOrderTotal(order.items, taxRate) // Pure
  await db.updateOrderTotal(orderId, total)            // I/O
}
```

### Dependency Injection
Pass dependencies as parameters, don't import singletons.

```typescript
// BAD: Hard to test — depends on global singleton
import { database } from './database'

function getUser(id: string) {
  return database.query('SELECT * FROM users WHERE id = ?', [id])
}

// GOOD: Injectable — can pass test double
function getUser(id: string, db: Database) {
  return db.query('SELECT * FROM users WHERE id = ?', [id])
}

// Test:
test('getUser returns user by id', async () => {
  const fakeDb = { query: jest.fn().mockResolvedValue({ id: '1', name: 'Test' }) }
  const user = await getUser('1', fakeDb)
  expect(user.name).toBe('Test')
})
```

### Common Testability Smells
- **Global state**: Static variables, singletons, module-level state
- **Hidden dependencies**: Functions that import their own dependencies
- **Time coupling**: Code that calls `new Date()` or `Date.now()` directly
- **Randomness**: Code that calls `Math.random()` directly
- **Large classes**: 500+ line classes with many responsibilities

## Magic Numbers and Strings

```typescript
// BAD: What do these mean?
if (status === 3) { ... }
setTimeout(callback, 86400000)
if (role === 'adm') { ... }

// GOOD: Named constants
const ORDER_STATUS_SHIPPED = 3
const ONE_DAY_MS = 24 * 60 * 60 * 1000
enum Role { ADMIN = 'admin', USER = 'user' }

if (status === ORDER_STATUS_SHIPPED) { ... }
setTimeout(callback, ONE_DAY_MS)
if (role === Role.ADMIN) { ... }
```

## Comments

### When to Comment
- **Why**, not what: Explain non-obvious decisions, business rules, workarounds
- **External constraints**: "This format is required by the payment provider API"
- **Performance**: "Using Map instead of filter because this runs 10K times/frame"
- **TODO with context**: `// TODO(F-302): Replace with generated profile when YAML support lands`

### When NOT to Comment
```typescript
// BAD: Comment restates the code
i++ // Increment i
const user = getUser(id) // Get the user by ID

// GOOD: No comment needed — the code is clear
i++
const user = getUser(id)
```

## Import Organization

```typescript
// 1. External/third-party libraries
import express from 'express'
import { z } from 'zod'

// 2. Internal modules (absolute paths)
import { UserService } from '@/services/user'
import { validateEmail } from '@/utils/validation'

// 3. Types (if separate)
import type { User, CreateUserInput } from '@/types'
```

No unused imports. No circular imports.
