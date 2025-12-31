# Webapp + backend profile

## Typical choices to decide early
- Frontend framework (React/Vue/Svelte/etc)
- Backend style (server-rendered, API service, BFF)
- Auth (sessions/JWT/OAuth)
- Persistence (Postgres/SQLite/etc)

## Testing recommendations
- Unit: business logic, validation, pure utilities
- API integration: request/response contracts (DB mocked or containerized depending on setup)
- UI acceptance: a small set of critical flows
- Performance: basic budgets (page load, API latency) if relevant

## `STACK.md` specifics
- Local dev commands: install/run/test
- How to run DB locally (if any)
- CI commands for unit + integration layers


