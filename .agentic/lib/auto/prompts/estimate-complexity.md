---
purpose: Pre-flight complexity estimation for a single acceptance criterion
usage: Engine sends this prompt before starting AC implementation
expected_response: One word — SMALL, MEDIUM, or LARGE
---

# Complexity Estimation

Given this acceptance criterion and the current codebase, estimate implementation complexity.

## Acceptance Criterion

{ac_id}: {ac_text}

## Codebase Context

{codebase_summary}

## Classification

- **SMALL** (1-3 files, straightforward): Simple logic, obvious where to put it, no new infrastructure
- **MEDIUM** (4-8 files, some design needed): Touches multiple modules, may need new tests, clear approach
- **LARGE** (9+ files or new infrastructure): New subsystem, database changes, cross-cutting concerns, unclear approach

Reply with exactly one word: SMALL, MEDIUM, or LARGE.
