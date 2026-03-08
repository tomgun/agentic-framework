---
name: reviewing-code
description: >
  Code review for quality, bugs, security, and conventions. Use when user says
  "review", "/review", "check this code", "look at my changes", "code review",
  "is this good", "any issues", or asks for feedback on code.
  Do NOT use for: implementing features (use implementing-features), writing
  tests (use writing-tests), committing code (use committing-changes).
compatibility: "Requires Claude Code with file access."
allowed-tools: [Read, Grep, Glob, Bash]
metadata:
  author: agentic-framework
  version: "0.46.1"
---

# Reviewing Code

Systematic code review for quality, correctness, security, and conventions.

## Instructions

### Step 1: Understand the Changes

Read the changed files to understand what was modified and why:

```bash
git diff --stat
git diff
```

Or if reviewing a PR:
```bash
gh pr diff <number>
```

### Step 1b: Check for Associated Plan

Extract feature IDs (F-XXXX patterns) from the PR title, branch name, or diff content. Search for matching plan files:

```bash
ls .agentic/journal/plans/*F-XXXX* 2>/dev/null
```

Also check for plans matching the PR date or description if feature IDs aren't obvious.

**If a plan file is found**: Read it. Use it as the primary review input — the plan defines what _should_ have been built. You will compare plan vs implementation in Step 2.

**If no plan file is found**: Skip silently — proceed with standard review.

### Step 2: Review Against Checklist

Check each dimension:

1. **Plan Alignment** (if plan found): Does the implementation match the plan?
   - **Missing deliverables**: Items the plan specified but the diff doesn't include
   - **Unplanned additions**: Changes in the diff not mentioned in the plan
   - **Deviations**: Implementation differs from what the plan specified (different approach, different files, different scope)
   - Note: not every deviation is wrong — plans evolve. Flag them for human judgment.
2. **Correctness**: Does the code do what it claims? Edge cases handled?
3. **Security**: Input validation, injection risks, auth checks?
4. **Performance**: Unnecessary loops, N+1 queries, missing caching?
5. **Style**: Follows project conventions? Consistent naming?
6. **Tests**: Are changed paths covered by tests?
7. **Documentation**: Are comments and docs updated?

### Step 3: Report Findings

Present findings organized by severity:
- **Must Fix**: Bugs, security issues, breaking changes
- **Should Fix**: Code quality, missing tests, unclear naming
- **Consider**: Style preferences, optimization opportunities

### Step 4: Suggest Specific Fixes

For each issue, provide:
- What the problem is
- Why it matters
- A concrete fix (code snippet)

## Examples

**Example 1: Reviewing a PR**
User says: "/review PR #42"
Steps taken:
1. Run `gh pr diff 42` to see changes
2. Read modified files for context
3. Found: SQL injection risk in user input handler
4. Report: "Must Fix: Line 45 of api/users.js concatenates user input into SQL query. Use parameterized queries instead."
Result: Actionable review with specific fix suggestions.

**Example 2: Quick code check**
User says: "Is this function okay?"
Steps taken:
1. Read the function and surrounding context
2. Check error handling, edge cases, naming
3. Found: missing null check on optional parameter
Result: "Looks good overall. One issue: `data` parameter could be null — add a guard."

## Troubleshooting

**Too many issues found**
Cause: Large changeset or many quality issues.
Solution: Prioritize by severity. Focus on Must Fix items first. Suggest breaking the review into smaller pieces.

## References

- For review checklist: see `references/review_checklist.md`
- For code standards: see `references/programming_standards.md`
