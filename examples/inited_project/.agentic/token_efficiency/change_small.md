# Change small (to save tokens and reduce risk)

## Why
Small changes:
- reduce required context
- reduce merge conflicts
- make review and debugging faster

## Slicing checklist
- Can this be done behind a flag?
- Can you ship plumbing first, behavior later?
- Can you split refactor vs behavior change?
- Can you add tests first, then implement?

## Good task size
- One clear behavior change
- One test suite impacted
- One PR-sized diff

## When to stop and re-plan
- You need to touch more than 5–10 files for “one task”
- The design is unclear
- You can’t describe acceptance criteria succinctly


