# Generic default profile

Use this when you don’t yet know the full stack, or when the project is standard.

## `STACK.md` checklist
- Language/runtime versions are explicit
- One build/test command per test layer exists (even if `TODO` at first)
- Dependencies manager is chosen
- Repo conventions are stated (`/spec`, `spec/adr`, `STATUS.md`)

## Testing defaults
- Unit tests: required for all new/changed logic
- Integration tests: cover DB/network boundaries if present
- Acceptance tests: only for critical workflows

## Structure defaults (tech-agnostic)
- Keep a clear “core logic” area separate from IO/UI
- Introduce seams for mocking external dependencies


