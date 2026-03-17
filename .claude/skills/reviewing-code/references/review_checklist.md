---
summary: "Code review checklist: correctness, security, performance, style"
trigger: "review, code review, checklist, PR review"
tokens: ~320
phase: review
---

# Review checklist

Use this for self-review and PR review.

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

## Plan Alignment
- Does the implementation match the approved plan (`.agentic/journal/plans/`)?
- Are all planned deliverables present? Any unplanned additions?
- If deviations exist, are they justified and documented?

## Docs & project truth
- Is `.agentic/STATUS.md` updated?
- Are specs/ADRs updated when behavior/decisions changed?


