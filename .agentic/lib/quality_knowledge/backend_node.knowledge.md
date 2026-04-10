# Node.js Backend Quality Knowledge

Deep domain expertise for building production Node.js backends with Express, Fastify, or Hono.

## Event Loop Blocking

The single most critical performance issue in Node.js. The event loop processes all I/O callbacks, timers, and incoming requests on a single thread. Blocking it freezes everything.

### Common Blockers
```javascript
// BAD: Synchronous file read blocks event loop
const data = fs.readFileSync('/large-file.json')

// GOOD: Async file read
const data = await fs.promises.readFile('/large-file.json')

// BAD: CPU-intensive JSON parsing of large payload
const big = JSON.parse(hugeString)  // >100MB blocks for seconds

// GOOD: Stream parsing or use worker_threads
const { Worker } = require('worker_threads')
```

### Detection
```bash
# Use clinic.js to detect event loop delays
npx clinic doctor -- node server.js
npx clinic flame -- node server.js  # Find hot functions
```

### Rule of Thumb
If an operation takes >10ms synchronously, it must be async or offloaded to a worker.

## Memory Leak Patterns

### Common Sources
1. **Growing arrays/maps**: Unbounded caches without eviction
2. **Event listeners**: Adding listeners without removing them
3. **Closures**: Capturing large objects in callbacks that outlive their scope
4. **Streams**: Readable streams that are never consumed or destroyed

### Detection
```bash
# Heap snapshot comparison
node --inspect server.js
# In Chrome DevTools: Take heap snapshot, exercise app, take another, compare

# Or use 0x for flamegraphs
npx 0x server.js
```

### Prevention Pattern
```javascript
// Always remove listeners
const handler = () => { /* ... */ }
emitter.on('event', handler)
// Later:
emitter.off('event', handler)

// Use AbortController for cleanup
const controller = new AbortController()
fetch(url, { signal: controller.signal })
// Later:
controller.abort()

// Bounded cache
const cache = new Map()
function set(key, value) {
  if (cache.size >= MAX_SIZE) {
    const oldest = cache.keys().next().value
    cache.delete(oldest)
  }
  cache.set(key, value)
}
```

## Error Handling

### Unhandled Rejections
```javascript
// ALWAYS handle promise rejections
process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection:', { reason })
  // In production: graceful shutdown
  process.exit(1)
})

// Express: use express-async-errors or wrap handlers
import 'express-async-errors'  // Auto-catches async errors

// Fastify: Built-in async support — errors caught automatically
fastify.get('/users', async (request, reply) => {
  const users = await db.query('SELECT * FROM users')
  return users  // Errors auto-caught
})
```

### Graceful Shutdown
```javascript
async function shutdown(signal) {
  logger.info(`${signal} received, shutting down gracefully`)

  // 1. Stop accepting new connections
  server.close()

  // 2. Wait for in-flight requests (with timeout)
  await Promise.race([
    new Promise(resolve => server.on('close', resolve)),
    new Promise(resolve => setTimeout(resolve, 30000)),
  ])

  // 3. Close database connections
  await db.destroy()

  process.exit(0)
}

process.on('SIGTERM', () => shutdown('SIGTERM'))
process.on('SIGINT', () => shutdown('SIGINT'))
```

## Input Validation with Zod

```typescript
import { z } from 'zod'

const CreateUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100),
  age: z.number().int().min(0).max(150),
})

// In route handler:
app.post('/users', async (req, res) => {
  const result = CreateUserSchema.safeParse(req.body)
  if (!result.success) {
    return res.status(400).json({ errors: result.error.flatten() })
  }
  const user = result.data  // Fully typed and validated
  // ...
})
```

## Database Patterns

### Connection Pooling (PostgreSQL)
```typescript
import { Pool } from 'pg'

const pool = new Pool({
  max: 20,               // Max connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
})

// Always release connections
const client = await pool.connect()
try {
  const result = await client.query('SELECT * FROM users WHERE id = $1', [id])
  return result.rows[0]
} finally {
  client.release()  // MUST release back to pool
}
```

### Prisma
```typescript
// prisma/schema.prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

// In app:
const prisma = new PrismaClient({
  log: ['query', 'warn', 'error'],  // Log slow queries
})

// Use transactions for multi-step operations
await prisma.$transaction(async (tx) => {
  const user = await tx.user.create({ data: { ... } })
  await tx.account.create({ data: { userId: user.id, ... } })
})
```

## Streaming Large Responses

```typescript
// BAD: Buffer entire file in memory
app.get('/download', async (req, res) => {
  const data = await fs.promises.readFile('large-file.csv')
  res.send(data)  // Entire file in memory
})

// GOOD: Stream the response
app.get('/download', (req, res) => {
  const stream = fs.createReadStream('large-file.csv')
  res.setHeader('Content-Type', 'text/csv')
  stream.pipe(res)
})
```

## Testing Node.js Backends

### supertest for API testing
```typescript
import request from 'supertest'
import { app } from './app'

describe('GET /users', () => {
  it('returns users list', async () => {
    const res = await request(app)
      .get('/users')
      .set('Authorization', `Bearer ${token}`)
      .expect(200)

    expect(res.body).toHaveLength(2)
    expect(res.body[0]).toHaveProperty('email')
  })
})
```

## Deployment Checklist
- [ ] `NODE_ENV=production` set
- [ ] Health check endpoint (`/health`) returns 200
- [ ] Graceful shutdown handles SIGTERM
- [ ] Connection pool configured (not default unlimited)
- [ ] Request timeout set (default is infinite in Express)
- [ ] Structured logging (pino) to stdout
- [ ] npm audit shows no high/critical vulnerabilities
- [ ] Rate limiting on auth and public endpoints
