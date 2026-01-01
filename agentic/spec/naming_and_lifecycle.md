# Spec naming & lifecycle

**⚠️ For the canonical schema defining valid values, field types, and validation rules, see [`SPEC_SCHEMA.md`](SPEC_SCHEMA.md).**

## Where things live (recommended)
- `/spec/PRD.md`: the “why/what”
- `/spec/TECH_SPEC.md`: the “how”
- `/spec/tasks/`: small tasks (optional, but recommended for non-trivial work)
- `spec/adr/`: decisions with tradeoffs
- `STATUS.md`: the living truth of current state

## Lifecycle
- Draft: incomplete, exploratory
- Active: used for implementation and kept current
- Shipped: completed scope; keep for reference
- Archived: moved to an archive folder if it becomes noise

## Naming conventions (machine-friendly)
- Files: use uppercase canonical names for top-level specs: `PRD.md`, `TECH_SPEC.md`, `STATUS.md`, `STACK.md`
- Task files (if used): `/spec/tasks/TASK-YYYYMMDD-short-title.md` or `/spec/tasks/TASK-0001-short-title.md`
- ADR files: `spec/adr/ADR-0001-short-title.md`

## Update rules (keep entropy down)
- If code changes behavior, update the relevant spec section(s) or add an ADR.
- If you finish a task, update `STATUS.md` to keep “resume” easy.
- Avoid duplicating truth across many docs; link instead of copy.


