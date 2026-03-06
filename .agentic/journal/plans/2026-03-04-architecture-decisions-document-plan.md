# Plan: Create Architecture Decisions Document

## Context

The team needs a comprehensive document explaining **why** the next-gen-fa-new architecture makes the choices it does — compared to the legacy OmaLumme/functions approach. This is for team communication, onboarding, and evaluating the decisions. The document should cover all structural, tooling, and pattern decisions with clear rationale.

## Deliverable

Create `docs/architecture-decisions.md` — a long-form document covering all major decisions with "why" explanations.

## Document Outline

### 1. Azure Functions v4 Programming Model (No function.json)
- **Old**: Each function had a `function.json` + root-level directory. Bindings declared in JSON, handler in `index.ts`.
- **New**: Programmatic registration via `app.http(name, { route, handler })` in code. No function.json files at all.
- **Why**: Type-safety, no config drift, functions discoverable via code, easier refactoring. Azure Functions v4 model.

### 2. Monorepo with pnpm Workspaces (vs Yarn)
- **Why pnpm over yarn**: Strict dependency isolation (no phantom deps), faster installs via content-addressable store, native workspace support, deterministic lockfile. Yarn v1 had hoisting issues; Yarn v3+ PnP has ecosystem compat problems.
- **Why monorepo**: Shared code (`packages/shared`) without publishing to npm. Apps share types, middleware, clients. Single `pnpm install`, single CI pipeline.
- Workspace linking via `"@next-gen-fa/shared": "workspace:*"`.

### 3. Three Separate Function Apps (api-fa, jobs-fa, bus-fa)
- **Old**: Single monolithic Function App with all triggers.
- **New**: Separate apps per trigger type.
- **Why**: Independent scaling (HTTP vs timer vs message), independent deployment, isolated failure domains, clearer ownership.

### 4. ESM Throughout + esbuild Bundling
- **Why ESM**: Modern module system, native top-level await, better tree-shaking, aligns with Node.js direction.
- **Why esbuild**: Single `dist/main.js` bundle for api-fa reduces cold-start time. Only api-fa bundles (most endpoints); jobs-fa/bus-fa use plain `tsc`.
- `createRequire` banner for CJS interop with Azure SDK packages.

### 5. Three-Layer Architecture (HTTP → Application → Infrastructure)
- **Why layers**: HTTP layer is version-specific (schemas, mappers, handlers). Application layer is version-shared (business logic, caching). Infrastructure is version-unaware (clients, auth, logging).
- **Why this matters**: Adding a new API version only touches the HTTP layer unless business logic diverges.

### 6. Composable Middleware vs Monolithic endpointWrapper
- **Old**: `endpointWrapper(fn, options)` — single function doing logging, auth, error handling, cache metadata. All-or-nothing configuration via boolean flags.
- **New**: `compose(withErrorHandling(), withCorrelation(), withRequestLogging(), withAuth(policy), withValidation(schemas))(handler)`.
- **Why**: Single responsibility per middleware. Each independently testable. Pipeline order is explicit and visible. Policies are declarative (`Policies.customerAccess('customerId')` vs `{ securityParams: { contractField, reqParam } }`).
- Explain the onion model: compose order, request vs response flow.

### 7. API Versioning Strategy
- URL-based versioning (`/api/v1/`, `/api/v2/`, `/api/v3/`).
- Each version has its own schema + handler + mapper files.
- **Key rule**: Only create version-specific use-cases when business logic diverges (v3 fetches extra data), not just when response shape differs (v2 nests fields differently — handled by mapper alone).
- Walk through the GET /customers/{id} example across v1 → v2 → v3.

### 8. Version-Unaware Caching
- Cache keys: `customer:{id}` not `api:v1:customer:{id}`.
- **Why**: Same domain object serves all versions. Mappers transform on every request (cheap). Avoids cache duplication.
- Exception: version-specific enriched data uses distinct key (`customer:v3-enriched:{id}`).

### 9. Cache Interface + NullCache Fallback
- `Cache` interface with `RedisCache` and `NullCache` implementations.
- **Why interface**: Testable (NullCache in unit tests, no Redis needed). Graceful degradation (Redis down → app still works, just slower).
- Tag-based invalidation with TTL on tag sets (prevents Redis memory leaks).
- `shouldCache` predicate for conditional caching.

### 10. Error Handling: AppError + RFC 9457 Problem Details
- **Old**: `ClientError(status, message)` → flat `{ message }` JSON.
- **New**: `AppError.badRequest(safe, unsafe)` → RFC 9457 Problem Details with `type`, `title`, `status`, `detail`, `code`, `correlationId`, structured `errors[]`.
- **Why**: Industry standard format. Machine-readable error codes. Safe/unsafe message separation prevents information leakage. Structured validation errors enable better client UX.

### 11. Logging: Pino with Auto-Redaction
- **Old**: Handwritten LoggerService, keyword-based debug filtering, 5 masking strategies.
- **New**: Pino structured JSON, path-based redaction, correlation ID binding.
- **Why Pino**: Structured JSON queryable in App Insights via KQL. Automatic redaction of sensitive paths. No manual logger threading (each layer creates own logger with correlationId).
- **Why not keyword filtering**: Structured logs + KQL queries replace the need. Can filter by logger name, correlation ID, or any field.

### 12. HTTP Clients: ResilientClient + OAuth2Client
- **Old**: Direct axios calls, no retry, manual API key headers.
- **New**: ResilientClient (retry + exponential backoff + jitter + timeout) composed with OAuth2Client (token caching + dedup).
- **Why**: Production resilience. Thundering herd prevention. Connection reuse across invocations.
- **Why caching at application layer, not service layer**: Caching is a use-case concern. Same client can be used with or without cache.

### 13. Auth: Custom Middleware over Azure EasyAuth
- `authLevel: 'anonymous'` on all routes. Auth handled by `withAuth(policy)` middleware.
- **Why**: Fine-grained policies (public, authenticated, requireRole, requireScope, requireAnyRole, customerAccess). EasyAuth is too coarse. Keycloak JWKS verification via jose library.
- Auth decision logging (OWASP 2.12): all granted/denied decisions logged for audit trail.

### 14. Dependency Injection: Promise-Cached getDeps()
- **Old**: Module-level singletons, no coordination.
- **New**: `getDeps()` caches the initialization Promise (not result).
- **Why Promise caching**: Prevents concurrent cold-start requests from creating duplicate Redis connections / OAuth2 clients. Single initialization, multiple awaiters.
- `resetDepsForTesting()` for test isolation.

### 15. Testing: Vitest + Test Helpers + NullCache
- **Why Vitest over Jest**: Faster, ESM-native, better `vi.mock()` ergonomics.
- **Unit tests**: Mock `getDeps()` for handler tests. Use `NullCache` for application tests. `setTokenVerifier()` for auth mocking.
- **E2e tests**: Spawn real Functions host, make HTTP requests, verify full contract.
- Test helpers: `mockRequest()`, `mockInvocationContext()`, `mockPrincipal()`.
- 80% coverage threshold.

### 16. Environment Validation: Zod Fail-Fast
- All env vars validated at startup with Zod schema. App crashes on invalid config.
- **Why**: Fail fast, not fail confusing. Missing `KEYCLOAK_ISSUER` discovered at startup, not on first auth request.
- Key Vault references in production (`@Microsoft.KeyVault(SecretUri=...)`).

### 17. OpenAPI Generation from Zod Schemas
- Schemas defined once in Zod → OpenAPI spec generated automatically.
- **Why**: Single source of truth. API docs can't drift from implementation. Type inference + runtime validation + documentation from one definition.

### 18. Security Headers (OWASP Defense-in-Depth)
- Applied on ALL responses (success + error paths).
- **Why baked into middleware**: Can't forget to add them. Applied even when handler throws.
- Headers: nosniff, DENY framing, HSTS, no-store, CSP lockdown.

### 19. Feature Flags
- `FeatureFlagProvider` interface with `EnvFeatureFlagProvider` (JSON env var) and `AppConfigFeatureFlagProvider` placeholder.
- **Why interface**: Swap implementations without changing consumers. Start simple (env var), upgrade later (Azure App Config) without code changes.

## Files to Create
- `docs/architecture-decisions.md`

## Verification
- Review document for accuracy against actual codebase
- Ensure all "why" explanations are present, not just "what"
- Run `pnpm typecheck && pnpm test` to confirm no side effects (doc-only change)
