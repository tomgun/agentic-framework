# Green Coding & Performance

Efficiency principles for sustainable, performant code. The rule: **make it work, make it right, make it fast** — in that order.

## When to Optimize

### Optimize When
- Profiler shows a measurable bottleneck
- User experience is degraded (slow page loads, frame drops, timeouts)
- Resource costs are significant (cloud bills, battery drain, memory pressure)

### Don't Optimize When
- "It might be slow someday" (premature optimization)
- The code runs once during initialization
- The difference is microseconds in a millisecond operation
- It would make the code harder to understand

### Safe Optimization Workflow
1. **Measure first** — profile before changing anything
2. **Set a target** — "page load under 2 seconds", "API response under 200ms"
3. **Change one thing** — isolate the optimization
4. **Measure again** — verify the improvement is real
5. **Check correctness** — optimizations frequently introduce bugs

## Algorithm Efficiency

### Common Traps

```typescript
// O(n²) — Hidden quadratic: includes() inside a loop
function findDuplicates(items: string[]): string[] {
  const duplicates: string[] = []
  for (const item of items) {
    if (items.filter(i => i === item).length > 1) {
      if (!duplicates.includes(item)) {  // Another O(n) inside O(n)
        duplicates.push(item)
      }
    }
  }
  return duplicates
}

// O(n) — Use a Map/Set
function findDuplicates(items: string[]): string[] {
  const counts = new Map<string, number>()
  for (const item of items) {
    counts.set(item, (counts.get(item) || 0) + 1)
  }
  return [...counts.entries()].filter(([, count]) => count > 1).map(([item]) => item)
}
```

### Rules of Thumb
- **Array.includes/indexOf inside a loop** → Use Set or Map
- **Nested loops over same data** → Often reducible to single pass with Map
- **Sorting just to find min/max** → Use single-pass scan
- **String concatenation in a loop** → Use array.join() or StringBuilder

## Caching

### The Two Hard Problems
> "There are only two hard things in Computer Science: cache invalidation and naming things." — Phil Karlton

### When Caching Helps
- Expensive computations repeated with same inputs
- External API calls with stable responses
- Database queries that don't change frequently

### When Caching Hurts
- Data that changes frequently (cache returns stale data)
- Data that must be consistent (financial, auth decisions)
- When cache key space is huge (cache never hits)

### Invalidation Strategies
| Strategy | Pros | Cons |
|----------|------|------|
| **TTL (time-based)** | Simple, predictable | Stale data until expiry |
| **Event-based** | Immediate freshness | Complex, easy to miss events |
| **Cache-aside (read-through)** | Lazy, only caches hot data | First request always slow |
| **Write-through** | Always fresh | Writes are slower |

### WARNING: Cache Invalidation Bugs
```typescript
// BUG: Cache returns stale user after role change
async function getUser(id: string): Promise<User> {
  const cached = cache.get(`user:${id}`)
  if (cached) return cached  // Returns old role!

  const user = await db.getUser(id)
  cache.set(`user:${id}`, user, { ttl: 3600 })
  return user
}

// FIX: Invalidate cache when user changes
async function updateUserRole(id: string, role: Role) {
  await db.updateRole(id, role)
  cache.delete(`user:${id}`)  // Invalidate!
}
```

## Resource Management

### Close What You Open
```typescript
// BAD: Connection leak
async function getData() {
  const conn = await pool.getConnection()
  const data = await conn.query('SELECT * FROM table')
  return data  // Connection never released!
}

// GOOD: Always release
async function getData() {
  const conn = await pool.getConnection()
  try {
    return await conn.query('SELECT * FROM table')
  } finally {
    conn.release()  // Always runs
  }
}
```

### Resource Cleanup Checklist
- [ ] Database connections released back to pool
- [ ] File handles closed after read/write
- [ ] Event listeners removed when component unmounts
- [ ] Timers cleared (clearTimeout, clearInterval)
- [ ] Streams properly ended/destroyed
- [ ] WebSocket connections closed on disconnect
- [ ] AbortControllers used for cancellable fetch requests

## Dependency Minimalism

### Before Adding a Dependency, Ask
1. **Is it worth the cost?** Every dep is: attack surface + build time + maintenance burden
2. **How much do we actually use?** Importing lodash for one function = 70KB for `_.get()`
3. **Is it maintained?** Check last commit date, open issues, bus factor
4. **Can we write it ourselves in <50 lines?** If yes, probably should

### Warning Signs
- `node_modules` larger than the application code
- More than 5 direct dependencies for a simple service
- Dependencies that pull in 100+ transitive deps
- Dependencies with no TypeScript types (if using TS)

## Database Efficiency

### N+1 Query Problem
```python
# BAD: 1 query for posts + N queries for authors (N+1)
posts = Post.objects.all()        # 1 query
for post in posts:
    print(post.author.name)       # 1 query per post = N queries

# GOOD: 2 queries total (1 for posts, 1 for authors)
posts = Post.objects.select_related('author').all()
```

### Index Strategy
- Index columns used in `WHERE`, `ORDER BY`, `JOIN ON`
- Index selective columns (high cardinality — many unique values)
- Don't index everything (slows writes, wastes space)
- Composite indexes: leftmost prefix rule — `(a, b, c)` covers queries on `(a)`, `(a, b)`, `(a, b, c)` but NOT `(b)` alone

### Query Anti-Patterns
- `SELECT *` when you need 2 columns
- `LIKE '%search%'` on large tables (can't use index)
- Sorting in application when database can sort
- Multiple round trips when a single JOIN works

## Frontend Performance

### Core Web Vitals Targets
| Metric | Good | Needs Work | Poor |
|--------|------|------------|------|
| LCP (Largest Contentful Paint) | <2.5s | 2.5-4.0s | >4.0s |
| FID (First Input Delay) | <100ms | 100-300ms | >300ms |
| CLS (Cumulative Layout Shift) | <0.1 | 0.1-0.25 | >0.25 |

### Quick Wins
- Lazy-load images below the fold
- Use WebP/AVIF instead of PNG/JPEG
- Minify and compress (gzip/brotli) all assets
- Set Cache-Control headers for static assets
- Use `<link rel="preconnect">` for third-party origins
