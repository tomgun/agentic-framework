---
summary: "Code review checklist: correctness, security, performance, style"
trigger: "review, code review, checklist, PR review"
tokens: ~380
phase: review
---

# Review checklist

Use this for self-review and PR review.

## Plan Alignment (if plan file found in `.agentic/journal/plans/`)
- Does the implementation deliver what the plan specified?
- Are there missing deliverables (planned but not implemented)?
- Are there unplanned additions (implemented but not in plan)?
- Do approach/files/scope match the plan, or are there deviations?
- If deviations exist: are they improvements or oversights?

## Correctness
- Does it meet the acceptance criteria?
- Are edge cases covered?
- Are failures handled well (errors/timeouts/retries)?

## Tests
- Are unit tests present for new/changed logic?
- Are tests meaningful (fail before fix, pass after)?
- If the domain needs non-unit tests (plugin/perf/UI), are they covered or planned?

## Design
- Are responsibilities clear and boundaries explicit?
- Is the change as small as it reasonably can be?
- Is there unnecessary coupling?

## Performance & reliability
- Any obvious hot paths impacted?
- Any new resource usage or concurrency hazards?

## Security
- Any new inputs validated?
- Any secrets or sensitive data handled appropriately?

## Docs & project truth
- Is `.agentic/STATUS.md` updated?
- Are specs/ADRs updated when behavior/decisions changed?


