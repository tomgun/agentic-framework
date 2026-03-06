---
summary: "Spec naming conventions and document lifecycle rules"
tokens: ~215
---

# Spec naming & lifecycle

**⚠️ For the canonical schema defining valid values, field types, and validation rules, see [`SPEC_SCHEMA.md`](SPEC_SCHEMA.md).**

## Where things live (recommended)
- `/spec/PRD.md`: the “why/what”
- `/spec/TECH_SPEC.md`: the “how”
- `/.agentic/spec/tasks/`: small tasks (optional, but recommended for non-trivial work)
- `.agentic/spec/adr/`: decisions with tradeoffs
- `.agentic/STATUS.md`: the living truth of current state

## Lifecycle
- Draft: incomplete, exploratory
- Active: used for implementation and kept current
- Shipped: completed scope; keep for reference
- Archived: moved to an archive folder if it becomes noise

## Naming conventions (machine-friendly)
- Files: use uppercase canonical names for top-level specs: `PRD.md`, `TECH_SPEC.md`, `.agentic/STATUS.md`, `STACK.md`
- Task files (if used): `/.agentic/spec/tasks/TASK-YYYYMMDD-short-title.md` or `/.agentic/spec/tasks/TASK-0001-short-title.md`
- ADR files: `.agentic/spec/adr/ADR-0001-short-title.md`

## Update rules (keep entropy down)
- If code changes behavior, update the relevant spec section(s) or add an ADR.
- If you finish a task, update `.agentic/STATUS.md` to keep “resume” easy.
- Avoid duplicating truth across many docs; link instead of copy.


