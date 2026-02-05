# L-0001: Plan-review loop model selection matters

**Date**: 2026-02-05
**Related**: F-0120 (Plan-Review Loop)

---

## What happened

During F-0121 planning, used haiku for revision 2 review. Got pedantic, surface-level feedback that didn't improve the plan quality.

## Why it happened

Didn't check `agent_mode` in STACK.md before spawning the reviewer agent. Haiku is the economy model - good for simple tasks but lacks depth for critical review work.

## What to do next time

1. **Check STACK.md agent_mode before spawning reviewers**
   - `premium` mode → use opus for reviews
   - `balanced` mode → use sonnet for reviews
   - `economy` mode → use haiku (but expect lighter review)

2. **Match reviewer quality to task criticality**
   - Plan reviews need deeper reasoning
   - Surface-level (syntax, formatting) → haiku is fine
   - Architectural decisions → opus preferred

3. **The plan-review workflow guide already has this**
   - See `.agentic/workflows/plan_review_loop.md`
   - Model selection guidance is documented

## Key insight

Token savings don't matter if the review doesn't catch real issues. A cheap review that misses problems costs more in rework than an expensive review that catches them early.

---

## Links

- `.agentic/workflows/plan_review_loop.md` - Workflow documentation
- `.agentic/workflows/agent_mode.md` - Model selection guidance
- `STACK.md` - `agent_mode` configuration
