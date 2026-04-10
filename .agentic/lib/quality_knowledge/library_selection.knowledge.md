# Library Selection Guide

Decision framework for choosing between libraries, frameworks, and custom implementations.

## The Core Question

> "Should we use an existing library or write our own?"

### Default: Use a Library When
- The problem is well-understood and standardized (HTTP, dates, crypto, validation)
- The library is actively maintained (commits in last 6 months)
- The library has good TypeScript/type support (if using typed languages)
- Customization needs are <20% of the library's surface area

### Write Custom When
- Your requirements are a unique hybrid (50%+ customization needed)
- The library would be >10x what you need (pulling in 500KB for one function)
- The implementation is <50 lines and well-understood
- You need absolute control over behavior (real-time audio, game physics, crypto)

## Decision Matrix

| Customization Level | Recommendation | Example |
|---------------------|---------------|---------|
| 0-20% (standard use) | Use library as-is | Date formatting, HTTP client, validation |
| 20-50% (extended use) | Use library + wrappers | ORM with custom query builders |
| 50-80% (heavy customization) | Consider alternatives or fork | Game engine with custom physics |
| 80-100% (unique requirements) | Build custom | Domain-specific DSP algorithms |

## Evaluation Criteria

Before adding a dependency, evaluate:

### 1. Maintenance Health
- **Last commit**: >6 months ago = risk
- **Open issues**: Ratio of open to closed, response time
- **Contributors**: Bus factor (1 person = high risk)
- **License**: Compatible with your project (MIT/Apache = safe, GPL = viral)
- **Security**: Check `npm audit`, `pip audit`, Snyk advisories

### 2. Quality Signals
- **TypeScript types**: Built-in > @types/* > none
- **Test coverage**: Check the library's own test suite
- **Documentation**: API docs, examples, migration guides
- **Bundle size**: Use bundlephobia.com (JS) or equivalent
- **Peer dependencies**: Fewer = better (avoids version conflicts)

### 3. Fit
- **API design**: Does it match your coding style?
- **Escape hatches**: Can you drop down to lower-level APIs when needed?
- **Composability**: Can you use parts independently?

## The Custom Variant Trap

**Critical lesson**: When your project is a variant of a standard thing, standard libraries will fight you.

Example: Building a chess/Tetris hybrid game.
- chess.js handles standard chess perfectly
- But your game has custom piece movement, non-standard boards, special rules
- You spend more time working around the library than building the feature

**Signal words** that indicate custom code is likely better:
- "hybrid", "variant", "modified", "custom", "non-standard"
- "We need chess.js but with [fundamental change to how it works]"
- "The library almost works, but we need to monkey-patch [core behavior]"

**The test**: If you need to modify the library's core assumptions, write custom code that handles YOUR assumptions natively.

## Common Decisions by Category

### HTTP Client
| Language | Prefer | Why |
|----------|--------|-----|
| JS/TS (browser) | Native `fetch` | Built-in, no deps, streaming support |
| JS/TS (Node) | Native `fetch` (Node 18+) or `undici` | No deps, fast |
| Python | `httpx` | Async support, `requests`-compatible API |
| Go | `net/http` | Excellent stdlib |
| Rust | `reqwest` | De facto standard, async |

### Validation
| Language | Prefer | Why |
|----------|--------|-----|
| JS/TS | `zod` | Type inference, composable, fast |
| Python | `pydantic` v2 | Type-safe, fast (Rust core), FastAPI built-in |
| Go | `validator` | Struct tags, well-maintained |

### Date/Time
| Language | Prefer | Why |
|----------|--------|-----|
| JS/TS | `date-fns` or native `Intl` | Tree-shakeable, no mutable state |
| JS/TS | Avoid `moment.js` | Huge (329KB), mutable, deprecated |
| Python | `datetime` stdlib + `python-dateutil` | Stdlib is solid, dateutil for edge cases |

### State Management (Frontend)
- **Server state**: React Query / TanStack Query (caching, refetching, optimistic updates)
- **Client state**: Zustand (simple), Jotai (atomic), Redux Toolkit (complex)
- **Avoid**: Redux for new projects (unless you already know and need it)

### ORM / Database
- **TypeScript**: Prisma (type-safe, schema-first) or Drizzle (SQL-like, lightweight)
- **Python**: SQLAlchemy 2.0 (async support) or Django ORM (Django projects)
- **Go**: sqlc (generates type-safe Go from SQL) or GORM
- **Warning**: ORMs hide SQL. Know what queries they generate.

## Migration Cost

Before adopting, consider the cost of leaving:

| Lock-in Level | Examples | Migration Cost |
|---------------|----------|---------------|
| Low | Utility libraries (lodash, date-fns) | Replace calls incrementally |
| Medium | ORMs, validation libraries | Rewrite data layer |
| High | Frameworks (React, Django, Rails) | Full rewrite |
| Very High | Cloud services (AWS Lambda, Firebase) | Architecture change |

**Rule**: The higher the lock-in, the more evaluation is warranted before adopting.

## Red Flags

Don't use a library if:
- Last release was >2 years ago and issues are piling up
- It has a known unfixed security vulnerability
- It requires 50+ transitive dependencies for basic use
- The API forces you into a paradigm that conflicts with your architecture
- There's no way to gradually adopt/remove it (all-or-nothing)
- The license changed recently or is ambiguous
