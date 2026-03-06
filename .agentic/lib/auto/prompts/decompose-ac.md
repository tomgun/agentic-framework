---
purpose: Decompose a large acceptance criterion into smaller sub-tasks
usage: Engine sends this when an AC is estimated LARGE or exhausts context
expected_response: JSON array of 2-5 sub-tasks
---

# Decompose Acceptance Criterion

This acceptance criterion is too large for a single implementation pass.
Break it into 2-5 sequential sub-tasks, each small enough to implement in
one focused session (1-3 files, straightforward changes).

## Acceptance Criterion

{ac_id}: {ac_text}

## Codebase Context

{codebase_summary}

## Rules

- Each sub-task should be independently testable
- Sub-tasks should be ordered so each builds on the previous
- The UNION of all sub-tasks must fully satisfy the original AC
- Do NOT change the AC itself — these are internal implementation steps
- Keep sub-task descriptions concrete and actionable

## Response Format

Reply with ONLY a JSON array:
```json
[
  {"text": "Set up the database schema for users table with email/password columns"},
  {"text": "Implement the POST /login endpoint with credential validation"},
  {"text": "Add JWT token generation and return in response body"},
  {"text": "Write integration tests for login success and failure cases"}
]
```
