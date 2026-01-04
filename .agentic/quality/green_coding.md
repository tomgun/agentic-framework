# Green Coding Standards

**Purpose**: Guidelines for environmentally responsible software development that minimizes energy consumption and carbon footprint.

**Audience**: All agents and human developers.

**Philosophy**: Efficient code is usually faster, cheaper, and greener. Green coding aligns with performance optimization and maintainability.

**⚠️ CRITICAL**: Green optimizations must NOT introduce bugs. Correctness > Clarity > Efficiency. Profile before optimizing, test thoroughly, start simple.

---

## ⚠️ WARNING: Don't Break Things to Be Green

### Complexity = Bug Risk

**Green optimizations can introduce bugs if not careful:**

```typescript
// ❌ DANGEROUS - Cache without invalidation (stale data bug!)
const cache = new Map();

function getUser(id) {
  if (cache.has(id)) return cache.get(id);
  const user = db.getUser(id);
  cache.set(id, user);
  return user;
}

function updateUser(id, data) {
  db.updateUser(id, data);
  // BUG: Cache not invalidated! Returns stale data forever
}

// ✅ SAFE - Cache with proper invalidation
const cache = new Map();

function getUser(id) {
  const cached = cache.get(id);
  if (cached && Date.now() < cached.expires) {
    return cached.data;
  }
  const user = db.getUser(id);
  cache.set(id, {
    data: user,
    expires: Date.now() + 60000 // 1 min TTL - auto-expires
  });
  return user;
}

function updateUser(id, data) {
  db.updateUser(id, data);
  cache.delete(id); // Explicit invalidation
}
```

**⚠️ Cache invalidation is notoriously difficult:**

> "There are only two hard things in Computer Science: cache invalidation and naming things." - Phil Karlton

**Why cache invalidation is hard:**
- **Distributed systems**: Multiple caches across servers need coordination
- **Cascading dependencies**: User changes → invalidate their orders → invalidate order summaries
- **Partial updates**: What if only one field changes? Invalidate entire object?
- **Race conditions**: Update and cache refresh happening simultaneously
- **Cache stampede**: All caches expire at once, overwhelming database
- **Multi-layered caches**: Browser cache, CDN cache, server cache, DB query cache

**Common bugs from green optimizations:**
- **Stale cache data**: Cache not invalidated on updates (most common!)
- **Race conditions**: Concurrent requests with lazy loading
- **Memory leaks**: Cache grows unbounded without eviction
- **Incorrect batching**: Batched operations applied in wrong order
- **Event loss**: Event-driven system drops events under load
- **Debounce issues**: User action lost due to aggressive debouncing
- **Cache stampede**: Thundering herd when cache expires
- **Inconsistent state**: Different caches have different versions

### The Safe Approach

**Priority order (NEVER compromise):**
1. **Correctness**: Code works correctly
2. **Clarity**: Code is maintainable
3. **Efficiency**: Code is fast + green

**Green optimization workflow:**
1. ✅ **Make it work** (correctness)
2. ✅ **Make it clear** (maintainability)
3. ✅ **Profile to find hotspots** (measure, don't guess)
4. ✅ **Optimize hot paths** (where data shows impact)
5. ✅ **Test thoroughly** (ensure no bugs introduced)

**When NOT to optimize:**
- ❌ No profiling data (premature optimization)
- ❌ Already fast enough (no user impact)
- ❌ Would make code fragile/complex (maintainability > green)
- ❌ Can't test edge cases thoroughly

### Test Green Optimizations Rigorously

**Caching example - what to test:**
```typescript
describe('User cache', () => {
  it('caches user data', () => {
    // Happy path
  });
  
  it('returns fresh data after TTL expires', () => {
    // Test expiration
  });
  
  it('invalidates cache on update', () => {
    const user = getUser('123');
    updateUser('123', { name: 'New Name' });
    const updated = getUser('123');
    expect(updated.name).toBe('New Name'); // Not stale!
  });
  
  it('handles concurrent requests', async () => {
    // Test race conditions
    const [u1, u2] = await Promise.all([
      getUser('123'),
      getUser('123')
    ]);
    // Should not cause double DB call or corrupt cache
  });
  
  it('evicts old entries when cache full', () => {
    // Test cache bounds (no memory leak)
  });
});
```

### Simple > Complex

**Start simple, optimize when needed:**

```typescript
// ✅ START HERE - Simple, no bugs
function getWeather(city) {
  return api.fetch(`/weather/${city}`);
}

// ⚠️ ADD ONLY IF PROFILING SHOWS PROBLEM
// And only after testing thoroughly
const cache = new LRU({ max: 100, ttl: 300000 }); // Use proven library!

function getWeather(city) {
  return cache.fetch(city, () => 
    api.fetch(`/weather/${city}`)
  );
}
```

**Use battle-tested libraries for complex patterns:**
- Caching: `lru-cache`, `node-cache`, Redis
- Debouncing: Lodash `debounce`, `throttle`
- Connection pooling: Built-in to DB libraries
- Don't roll your own unless you have expertise

### Document Trade-offs

**If you add complexity for green, document it:**

```typescript
/**
 * User cache with 60s TTL
 * 
 * WHY: getUser() called 1000x/sec, DB was bottleneck (99% cache hit rate)
 * TRADE-OFF: Adds complexity, possible stale data for up to 60s
 * INVALIDATION: Explicit on update/delete, auto-expires after 60s
 * TESTED: tests/cache.test.ts covers expiration, invalidation, concurrency
 */
const userCache = new LRUCache({ max: 10000, ttl: 60000 });
```

---

## Core Principles

### 1. Energy Efficiency = Better Code

**Green coding is NOT separate from good coding**:
- Efficient algorithms consume less energy AND run faster
- Proper resource management prevents leaks AND improves stability  
- Lazy loading reduces energy AND improves UX
- Caching reduces compute AND improves response times

**Balance**: Clarity comes first, then correctness, then efficiency. Green coding happens in the "efficiency" phase, not as an afterthought.

###  2. Measure, Don't Guess

**Profile before optimizing**:
- Use profiler to find energy hotspots
- Measure actual energy consumption (tools: PowerTop, Intel Power Gadget)
- Optimize where data shows impact
- Don't optimize for theoretical savings

### 3. Lifecycle Thinking

**Software longevity matters**:
- Well-designed, maintainable code lasts longer
- Fewer rewrites = less development energy
- Modular design enables targeted updates
- Technical debt forces energy-intensive rewrites

---

## Algorithm Efficiency

### Choose Lower Complexity Algorithms

**Complexity matters at scale**:

```python
# ❌ O(n²) - Wastes energy at scale
def find_duplicates_bad(items):
    duplicates = []
    for i in range(len(items)):
        for j in range(i + 1, len(items)):
            if items[i] == items[j]:
                duplicates.append(items[i])
    return duplicates

# ✅ O(n) - Energy efficient
def find_duplicates_good(items):
    seen = set()
    duplicates = set()
    for item in items:
        if item in seen:
            duplicates.add(item)
        seen.add(item)
    return list(duplicates)
```

**Energy impact** (10,000 items):
- O(n²): 100,000,000 operations
- O(n): 10,000 operations
- **99.99% reduction in CPU cycles**

### Use Appropriate Data Structures

```javascript
// ❌ O(n) lookup - Wastes energy on repeated searches
const users = []; // Array
function findUser(id) {
  return users.find(u => u.id === id); // Linear search every time
}

// ✅ O(1) lookup - Energy efficient
const users = new Map(); // HashMap
function findUser(id) {
  return users.get(id); // Constant time
}
```

**When it matters**: If `findUser()` called 1000 times with 10K users:
- Array: 10,000,000 comparisons
- Map: 1,000 lookups
- **99.99% reduction**

---

## Resource Management

### Lazy Loading

**Load only what's needed, when it's needed**:

```typescript
// ❌ Loads everything upfront
class User {
  id: string;
  name: string;
  orders: Order[]; // Loaded even if never accessed
  
  constructor(data) {
    this.id = data.id;
    this.name = data.name;
    this.orders = fetchAllOrders(data.id); // Heavy query!
  }
}

// ✅ Lazy loads on demand
class User {
  id: string;
  name: string;
  private _orders: Order[] | null = null;
  
  async getOrders(): Promise<Order[]> {
    if (!this._orders) {
      this._orders = await fetchOrders(this.id);
    }
    return this._orders;
  }
}
```

**Energy saved**: If only 20% of users need orders, lazy loading saves 80% of order queries.

### Pagination

**Don't load millions of records**:

```sql
-- ❌ Loads everything (could be millions)
SELECT * FROM users;

-- ✅ Paginate (load 50 at a time)
SELECT * FROM users LIMIT 50 OFFSET 0;
```

**Energy impact**: Loading 1M records vs 50 records:
- Network: 1M × record size vs 50 × record size
- Memory: Gigabytes vs kilobytes
- **~99.995% reduction in resource usage**

### Streaming for Large Data

```javascript
// ❌ Load entire file into memory
const data = fs.readFileSync('huge-file.json'); // Could be gigabytes!
const parsed = JSON.parse(data);

// ✅ Stream and process incrementally
const stream = fs.createReadStream('huge-file.json');
const parser = JSONStream.parse('*');

stream.pipe(parser);
parser.on('data', (record) => {
  processRecord(record); // Process one at a time
});
```

**Memory saved**: 10GB file:
- Load all: 10GB RAM
- Stream: ~10MB RAM
- **99.9% reduction in memory usage**

---

## Network Efficiency

### Caching

**Avoid redundant API calls**:

```typescript
// ❌ Fetches same data repeatedly
async function getWeather(city: string) {
  return await api.fetch(`/weather/${city}`); // Every call hits API
}

// ✅ Caches with TTL
const cache = new Map<string, {data: any, expires: number}>();

async function getWeather(city: string) {
  const cached = cache.get(city);
  if (cached && Date.now() < cached.expires) {
    return cached.data; // Serve from cache
  }
  
  const data = await api.fetch(`/weather/${city}`);
  cache.set(city, {
    data,
    expires: Date.now() + 5 * 60 * 1000 // 5 min TTL
  });
  return data;
}
```

**Energy saved** (1000 requests in 5 minutes):
- No cache: 1000 API calls
- With cache: ~1 API call (+ 999 cache hits)
- **99.9% reduction in API calls**

**⚠️ Cache Invalidation Strategies (The Hard Part)**

> "There are only two hard things in Computer Science: cache invalidation and naming things." - Phil Karlton

**Why it's hard**: When do you invalidate? Too early = cache misses. Too late = stale data.

**Strategy 1: Time-Based (TTL - Time To Live)**
```typescript
// Simplest: Cache expires after fixed time
cache.set(key, { data, expires: Date.now() + TTL });

// ✅ Good for: Read-heavy, data changes slowly, staleness acceptable
// ❌ Bad for: Data must be real-time, user sees own updates
// Example: Weather (5 min stale OK), stock prices (1 sec max)
```

**Strategy 2: Write-Through (Invalidate on Update)**
```typescript
function updateUser(id, data) {
  db.updateUser(id, data);      // Write to DB
  cache.delete(id);              // Invalidate cache
}

// ✅ Good for: User must see their own updates immediately
// ❌ Bad for: High write volume, distributed systems (hard to coordinate)
// Example: User profile, shopping cart
```

**Strategy 3: Write-Behind (Async Invalidation)**
```typescript
function updateUser(id, data) {
  db.updateUser(id, data);
  
  // Invalidate after write completes
  setTimeout(() => cache.delete(id), 100);
}

// ✅ Good for: Performance critical, slight staleness OK
// ❌ Bad for: Must be immediately consistent
// Example: View counts, analytics
```

**Strategy 4: Event-Based (Pub/Sub)**
```typescript
// When data changes, publish event
eventBus.on('user:updated', (userId) => {
  cache.delete(userId);
});

// ✅ Good for: Microservices, distributed caches
// ❌ Bad for: Event loss risk, added complexity
// Example: Multi-server deployments
```

**Strategy 5: Cache Versioning**
```typescript
// Include version in cache key
function getUser(id) {
  const version = getUserVersion(id); // From DB or separate store
  const key = `user:${id}:v${version}`;
  
  if (cache.has(key)) return cache.get(key);
  
  const user = db.getUser(id);
  cache.set(key, user);
  return user;
}

// On update: increment version (old cache keys automatically stale)
function updateUser(id, data) {
  db.updateUser(id, data);
  incrementUserVersion(id); // Old cache keys now useless
}

// ✅ Good for: Distributed systems, no invalidation needed
// ❌ Bad for: Version management overhead
// Example: CDNs, immutable data
```

**Strategy 6: Combination (Layered Defense)**
```typescript
// Most robust: TTL + explicit invalidation
const cache = new LRUCache({
  max: 500,                    // Max size (prevents memory leak)
  ttl: 5 * 60 * 1000,         // 5 min TTL (safety net)
  updateAgeOnGet: false        // Don't extend TTL on read
});

function getUser(id) {
  return cache.fetch(id, async () => {
    return await db.getUser(id);
  });
}

function updateUser(id, data) {
  db.updateUser(id, data);
  cache.delete(id);           // Explicit invalidation
  // If delete fails, TTL still expires eventually
}

// ✅ Good for: Production systems, belt-and-suspenders
// ❌ Bad for: Overkill for simple cases
// Example: Most real-world caching
```

**Common Pitfalls:**
1. **Cascading invalidation**: User update should invalidate user's orders? Order summaries?
   - Solution: Keep cache scopes simple, or use versioning
2. **Cache stampede**: All caches expire at once, overwhelming DB
   - Solution: Staggered TTLs, request coalescing
3. **Distributed inconsistency**: Server A's cache differs from Server B's
   - Solution: Centralized cache (Redis), pub/sub invalidation
4. **Race conditions**: Update and cache refresh happen simultaneously
   - Solution: Locking, optimistic concurrency, idempotent operations

**When to use which strategy:**

| Data Type | Update Frequency | Staleness Tolerance | Strategy |
|-----------|------------------|---------------------|----------|
| Weather | Low | High (5-30 min OK) | TTL only |
| User profile | Medium | Low (must see own updates) | TTL + Write-Through |
| Stock prices | High | Very Low (seconds) | Short TTL (1-5s) |
| Analytics | High | Medium | TTL + Write-Behind |
| Static assets | Never | Infinite | Cache forever + versioning |
| Distributed | Any | Varies | Event-Based + TTL |

**The Safe Default:**
```typescript
// Start with: TTL + LRU + Explicit invalidation
// Only add complexity if profiling shows need
const cache = new LRUCache({ max: 1000, ttl: 60000 });
// Simple, catches most issues, bounded memory
```

**Rule of Thumb**: If you can't reason about cache invalidation clearly, don't cache. Simple code > buggy caching.

### Compression

```javascript
// Enable compression for API responses
app.use(compression()); // Express middleware

// Result: 70-90% smaller payload
// JSON response: 1MB → 100KB (10x reduction)
```

### Efficient Data Formats

```typescript
// ❌ Verbose JSON
{
  "userId": 12345,
  "userName": "Alice",
  "userEmail": "alice@example.com"
}
// Size: 78 bytes

// ✅ Compact format (when supported)
// Protocol Buffers, MessagePack, etc.
// Size: ~25 bytes (67% reduction)
```

### Batch API Calls

```typescript
// ❌ N individual API calls
for (const id of userIds) {
  await api.getUser(id); // 100 API calls for 100 users
}

// ✅ Single batch request
const users = await api.getUsersBatch(userIds); // 1 API call
```

**Energy saved**: 100 API calls vs 1:
- Network overhead: 100× headers, handshakes, etc.
- **~99% reduction in network traffic**

---

## Background Tasks & Polling

### Event-Driven > Polling

```javascript
// ❌ WASTEFUL - Polls every second
setInterval(async () => {
  const updates = await checkForUpdates();
  if (updates) {
    processUpdates(updates);
  }
}, 1000);
// 86,400 checks/day, most returning "no updates"

// ✅ GREEN - Event-driven (webhooks, WebSockets)
websocket.on('update', (data) => {
  processUpdates(data);
});
// Only runs when actual updates occur
```

**Energy impact**:
- Polling: 86,400 API calls/day
- Events: ~100 messages/day (real updates only)
- **99.88% reduction**

### Debouncing & Throttling

```javascript
// ❌ Triggers on every keystroke (excessive)
searchInput.addEventListener('keyup', async (e) => {
  const results = await api.search(e.target.value);
  displayResults(results);
});
// User types "javascript" = 10 API calls

// ✅ Debounce - wait for pause
const debouncedSearch = debounce(async (query) => {
  const results = await api.search(query);
  displayResults(results);
}, 300); // Wait 300ms after last keystroke

searchInput.addEventListener('keyup', (e) => {
  debouncedSearch(e.target.value);
});
// User types "javascript" = 1 API call
```

**Energy saved**: 10 API calls → 1 API call (90% reduction)

### Intelligent Scheduling

```python
# ❌ Fixed interval (wasteful during low activity)
while True:
    process_queue()
    time.sleep(60)  # Every minute, even if queue empty

# ✅ Adaptive (scales to demand)
def process_with_backoff():
    consecutive_empty = 0
    while True:
        if process_queue():
            consecutive_empty = 0
            wait = 10  # Fast processing when busy
        else:
            consecutive_empty += 1
            wait = min(300, 10 * (2 ** consecutive_empty))  # Exponential backoff
        
        time.sleep(wait)
```

**Energy during low activity**:
- Fixed: Check every 60s
- Adaptive: Check every 300s (after backoff)
- **80% reduction during idle periods**

---

## Database Efficiency

### Avoid N+1 Queries

```python
# ❌ N+1 problem (1 query + N queries)
users = db.query("SELECT * FROM users")
for user in users:
    user.orders = db.query(f"SELECT * FROM orders WHERE user_id = {user.id}")
# 1 + 1000 = 1001 queries for 1000 users

# ✅ JOIN (1 query total)
result = db.query("""
    SELECT users.*, orders.*
    FROM users
    LEFT JOIN orders ON users.id = orders.user_id
""")
# 1 query, includes all data
```

**Energy saved**: 1001 queries → 1 query (99.9% reduction)

### Index Frequently Queried Columns

```sql
-- ❌ Full table scan on every query
SELECT * FROM users WHERE email = 'alice@example.com';
-- Scans 1M rows every time

-- ✅ Add index
CREATE INDEX idx_users_email ON users(email);
-- Now: O(log n) lookup instead of O(n)
```

**Energy impact** (1M users, 1000 queries/sec):
- No index: 1B row scans/sec
- With index: ~20K lookups/sec
- **99.998% reduction in disk I/O**

### Select Only Needed Columns

```sql
-- ❌ Fetches everything
SELECT * FROM users WHERE id = 123;
-- Returns 50 columns, 5KB per row

-- ✅ Fetch only what's needed
SELECT id, name, email FROM users WHERE id = 123;
-- Returns 3 columns, 200 bytes per row
```

**Bandwidth saved**: 5KB → 200 bytes (96% reduction)

---

## UI & Frontend Efficiency

### Virtual Scrolling

```jsx
// ❌ Render all 10,000 items
{items.map(item => <ListItem key={item.id} {...item} />)}
// Renders 10,000 DOM nodes

// ✅ Virtual scrolling (only visible items)
<VirtualList
  items={items}
  itemHeight={50}
  windowHeight={800}
/>
// Renders ~16 visible items (800 / 50)
```

**Energy saved**:
- Full render: 10,000 DOM nodes, continuous repaints
- Virtual: 16 DOM nodes
- **99.84% reduction in DOM operations**

### Debounce UI Updates

```javascript
// ❌ Update on every mouse move
canvas.addEventListener('mousemove', (e) => {
  updatePreview(e.x, e.y); // Could be 100+ times/sec
});

// ✅ Throttle to reasonable rate
const throttledUpdate = throttle((x, y) => {
  updatePreview(x, y);
}, 16); // ~60 FPS max

canvas.addEventListener('mousemove', (e) => {
  throttledUpdate(e.x, e.y);
});
```

**Energy saved**: 100 updates/sec → 60 updates/sec (40% reduction)

### Memoization

```javascript
// ❌ Recalculates every render
function ExpensiveComponent({data}) {
  const processed = expensiveCalculation(data); // Runs every render!
  return <div>{processed}</div>;
}

// ✅ Memoize (React example)
function ExpensiveComponent({data}) {
  const processed = useMemo(
    () => expensiveCalculation(data),
    [data] // Only recalculate when data changes
  );
  return <div>{processed}</div>;
}
```

**Energy saved**: If component renders 100 times but data changes 3 times:
- No memo: 100 calculations
- With memo: 3 calculations
- **97% reduction**

---

## Infrastructure & Deployment

### Serverless / Auto-Scaling

**Scale to demand instead of running idle servers**:

```yaml
# Traditional: 10 servers running 24/7
# Load: Peak 10 servers, avg 2 servers needed
# Waste: 8 servers × 16 idle hours/day = 128 server-hours/day wasted

# Serverless / Auto-scaling: Scale 0-10 based on load
# Runs only when needed
# Savings: ~80% energy reduction during off-peak
```

### Green Hosting

**Choose data centers powered by renewable energy**:
- AWS: Renewable energy goals, choose green regions
- Google Cloud: Carbon-neutral
- Azure: Carbon-negative by 2030
- Vercel, Netlify: Green hosting options

### Connection Pooling

```javascript
// ❌ New connection per request (expensive)
app.get('/users', async (req, res) => {
  const conn = await createConnection(DB_URL); // Handshake, auth every time
  const users = await conn.query('SELECT * FROM users');
  await conn.close();
  res.json(users);
});

// ✅ Reuse connections via pool
const pool = createPool({ max: 20 });

app.get('/users', async (req, res) => {
  const conn = await pool.acquire(); // Reuse existing connection
  const users = await conn.query('SELECT * FROM users');
  pool.release(conn);
  res.json(users);
});
```

**Energy saved**: Connection setup overhead (handshake, TLS, auth) eliminated for 95%+ of requests.

---

## Measuring Impact

### Energy Profiling Tools

**Measure actual energy consumption**:
- **Linux**: PowerTOP, perf
- **macOS**: Intel Power Gadget, Instruments
- **Windows**: Intel Power Gadget, Windows Performance Analyzer
- **Cloud**: AWS CloudWatch, Google Cloud Monitoring (CPU/memory as proxy)

### Metrics to Track

1. **Algorithm Complexity**: O(n log n) vs O(n²)
2. **API Calls Reduced**: Caching hit rate
3. **Database Queries**: N+1 eliminated, indexes added
4. **Network Bandwidth**: Compression ratio, smaller payloads
5. **Memory Usage**: Peak memory, leak detection
6. **CPU Usage**: Average CPU%, hotspots optimized
7. **Response Times**: Faster = less energy

### Carbon Footprint Estimation

**Rough formula**:
```
Carbon = Energy × Carbon Intensity of Grid

Where:
- Energy = CPU hours × CPU power (e.g., 100W)
- Carbon Intensity = g CO₂/kWh (varies by region: 50-800)

Example:
- 1000 server-hours/month
- 100W average power
- 400g CO₂/kWh (US avg)

= 1000h × 0.1kW × 400g
= 40,000g CO₂/month
= 40 kg CO₂/month
```

**Optimization impact**:
- Reduce server time 50% → 20 kg CO₂/month saved
- Over 1 year: 240 kg CO₂ saved (equivalent to ~1000 km of driving)

---

## Green Coding Checklist

### Algorithm & Data Structures
- [ ] Use lowest complexity algorithm practical (O(log n) > O(n) > O(n²))
- [ ] Use appropriate data structures (Map for lookups, not Array)
- [ ] Avoid nested loops where vectorization/batch operations work

### Resource Management
- [ ] Lazy load data (load only when needed)
- [ ] Paginate large datasets (don't load millions of records)
- [ ] Stream large files (don't load entire file into memory)
- [ ] Clean up resources (close connections, release memory)
- [ ] Use connection pools (reuse connections)

### Network
- [ ] Cache responses with appropriate TTL
- [ ] Compress data in transit (gzip, brotli)
- [ ] Use efficient formats (WebP, Protobuf when appropriate)
- [ ] Batch API calls (avoid N individual requests)
- [ ] Select only needed data (not SELECT *)

### Background Tasks
- [ ] Event-driven instead of polling (webhooks > setInterval)
- [ ] Debounce/throttle frequent operations
- [ ] Intelligent scheduling (adaptive intervals)
- [ ] Batch operations (process in groups, not one-by-one)

### Database
- [ ] Avoid N+1 queries (use JOINs)
- [ ] Index frequently queried columns
- [ ] Select only needed columns (not *)
- [ ] Use connection pools
- [ ] Paginate result sets

### UI & Frontend
- [ ] Virtual scrolling for long lists
- [ ] Debounce search inputs
- [ ] Memoize expensive computations
- [ ] Lazy load images/components
- [ ] Minimize redraw rates (60fps not always needed)

### Infrastructure
- [ ] Auto-scaling (scale to demand, not fixed capacity)
- [ ] Choose green hosting (renewable energy data centers)
- [ ] Right-size resources (don't over-provision)

---

## Anti-Patterns (Energy Waste)

❌ **Polling every second** when webhooks available  
❌ **Loading entire datasets** without pagination  
❌ **Full table scans** on large tables (missing indexes)  
❌ **N+1 queries** instead of JOINs  
❌ **No caching** for read-heavy data  
❌ **SELECT *** when only 2 columns needed  
❌ **Rendering 10K DOM nodes** instead of virtual scrolling  
❌ **New DB connection** per request instead of pooling  
❌ **O(n²) algorithms** when O(n log n) available  
❌ **Memory leaks** (accumulating event listeners, unclosed connections)  
❌ **Over-provisioned servers** running at 10% capacity 24/7  

---

## Balance: Green vs. Other Priorities

**Green coding is a factor, not the only factor**:

1. **Correctness First**: Buggy code that's energy-efficient is still useless (and dangerous!)
2. **Clarity Second**: Maintainability enables long-term efficiency
3. **Green Third**: Optimize for energy when correctness and clarity are solid

**⚠️ NEVER sacrifice correctness or introduce bugs for green optimization.**

### When to prioritize green coding:
- ✅ High-scale systems (1M+ users) - where small improvements have big impact
- ✅ Long-running processes (background jobs, servers) - cumulative energy savings
- ✅ Resource-constrained environments (mobile, embedded) - battery life matters
- ✅ High API call volumes - caching has proven 99%+ hit rate
- ✅ When it aligns with performance/cost optimization - win-win
- ✅ **When you can test edge cases thoroughly** - no hidden bugs

### When NOT to sacrifice clarity for green:
- ❌ Micro-optimizations that add complexity (hard to maintain)
- ❌ Premature optimization (profile first! measure don't guess)
- ❌ Code becomes unmaintainable (future you will hate it)
- ❌ **Can't test edge cases** (race conditions, cache invalidation, etc.)
- ❌ **Introducing bug risk** (correctness > green, always)

### Common Bug-Prone Patterns

**Be especially careful with:**
1. **Caching**: Stale data, invalidation complexity, race conditions, memory leaks
2. **Debouncing/Throttling**: Lost user actions, timing bugs
3. **Batching**: Order dependencies, partial failures
4. **Lazy loading**: Race conditions, loading indicators, error states
5. **Connection pooling**: Connection state, transaction boundaries
6. **Event-driven**: Lost events, ordering guarantees, back-pressure

**For these patterns:**
- Use battle-tested libraries (don't roll your own)
- Write extensive tests (happy path + edge cases)
- Document assumptions and trade-offs
- Monitor in production (detect stale cache, lost events, etc.)

### Example of good balance:

```python
# ✅ Clear and green (win-win, no bug risk)
def find_duplicates(items):
    seen = set()
    duplicates = set()
    for item in items:
        if item in seen:
            duplicates.add(item)
        seen.add(item)
    return list(duplicates)

# ❌ Over-optimized (confusing, potential bugs)
def find_duplicates(items):
    return list({x for x in items if items.count(x) > 1})  
    # Confusing AND O(n²) due to count()! Worse on both fronts.

# ⚠️ Complex green (only if measured need + thorough testing)
from functools import lru_cache

@lru_cache(maxsize=128)
def find_duplicates_cached(items_tuple):
    # Can only cache if items are immutable (tuple)
    # Adds complexity, only worth it if called repeatedly with same input
    # MUST TEST: cache hit/miss, memory bounds, immutability requirement
    seen = set()
    duplicates = set()
    for item in items_tuple:
        if item in seen:
            duplicates.add(item)
        seen.add(item)
    return tuple(duplicates)

# Wrapper to handle list->tuple conversion
def find_duplicates(items):
    return list(find_duplicates_cached(tuple(items)))
```

---

## Summary

**Green coding is not a separate discipline** - it's good software engineering:
- Efficient algorithms are faster AND greener
- Proper resource management prevents leaks AND saves energy
- Caching improves UX AND reduces compute
- Lazy loading is good design AND energy-efficient

**Key takeaways**:
1. **Profile first**: Measure before optimizing
2. **Optimize hot paths**: Where data shows impact
3. **Clarity first, then efficiency**: Don't sacrifice maintainability
4. **Think lifecycle**: Sustainable design reduces total energy over software lifetime
5. **Measure impact**: Track metrics to validate improvements

**The framework's stance**: We embrace green coding because it aligns with our core values of efficiency, quality, and long-term sustainability. Efficient software is better software.

---

**Last Updated**: 2026-01-03  
**Framework Version**: 0.2.5  

**See Also**:
- `programming_standards.md` - General code quality standards
- `PRINCIPLES.md` - Framework core principles (includes green coding philosophy)
- `continuous_quality_validation.md` - Quality checks (can include energy profiling)

