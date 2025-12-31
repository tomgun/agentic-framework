# Spec lint rules (CI template)

This is intentionally technology-agnostic. It validates that the repo maintains the **durable context artifacts** agents rely on.

## Required paths (must exist and be non-empty)
- `STACK.md`
- `CONTEXT_PACK.md`
- `STATUS.md`
- `spec/PRD.md`
- `spec/TECH_SPEC.md`

## Required directories (must exist)
- `spec/`
- `spec/adr/`

## Guidance
- This is not meant to police writing style.
- It’s meant to prevent “context rot” (missing/empty docs) that makes agent work expensive.


