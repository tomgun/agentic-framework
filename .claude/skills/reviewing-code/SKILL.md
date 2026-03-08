---
name: reviewing-code
description: >
  Code review for quality, bugs, security, and conventions. Use when user says
  "review", "/review", "check this code", "look at my changes", "code review",
  "is this good", "any issues", or asks for feedback on code.
  Do NOT use for: implementing features (use implementing-features), writing
  tests (use writing-tests), committing code (use committing-changes).
compatibility: "Requires Claude Code with file access."
allowed-tools: [Read, Grep, Glob, Bash, Agent]
metadata:
  author: agentic-framework
  version: "0.50.2"
---

# Reviewing Code

Systematic code review delegated to a fresh-context subagent for token efficiency.

## Instructions

### Step 1: Determine Review Scope

Figure out what needs reviewing. Do NOT read diffs or files yourself — just determine the scope:

- **PR review**: Extract the PR number from the user's message (e.g., "/review PR #42" → PR 42)
- **Branch review**: If on a feature branch (not main), review all commits on the branch vs origin/main
- **Staged/unstaged changes**: On main with no PR number → review current working tree changes
- **Specific files**: If the user names specific files, note them

### Step 1b: Check for Associated Plan

Extract feature IDs (F-XXXX patterns) from the user's message, current branch name, or recent commits. Check if a plan file exists:

```bash
git branch --show-current
ls .agentic/journal/plans/ 2>/dev/null
```

Note the plan file path if found — you'll pass it to the subagent.

### Step 2: Launch Review Subagent

Use the **Agent tool** to spawn a subagent that performs the actual review. This keeps all diff content, file reads, and checklist processing out of the main context.

Build the subagent prompt with:
1. **What to review** (PR number, or "current working tree changes", or specific files)
2. **Plan file path** (if found in Step 1b, tell the subagent to read it)
3. **The full review protocol** (copy the review protocol below into the prompt)

**Subagent prompt template** (adapt based on scope):

~~~
You are a code reviewer. Perform a systematic review and return a structured findings report.

## What to Review

[INSERT one of:
- "Run `gh pr diff <NUMBER>`" (PR review)
- "Run `git diff origin/main` and `git diff origin/main --stat`" (branch review)
- "Run `git diff` for unstaged and `git diff --cached` for staged changes" (working tree review)
- "Review these files: <list>" (specific files)]

## Review Protocol

### 1. Understand the Changes
Read the diff to understand what was modified. Run `git diff --stat` (or `gh pr diff <N> --stat`) first for an overview.

### 2. Check for Plan File
[IF plan path found: "Read `.agentic/journal/plans/<filename>` and compare implementation against it."]
[IF no plan: "No plan file found — skip plan alignment."]

### 3. Review Against Checklist

Check each dimension:

1. **Plan Alignment** (only if plan file exists): Does implementation match the plan?
   - Missing deliverables (planned but not implemented)
   - Unplanned additions (implemented but not in plan)
   - Deviations (different approach, files, or scope)
   - Note: not every deviation is wrong — flag for human judgment
2. **Correctness**: Does the code do what it claims? Edge cases handled?
3. **Security**: Input validation, injection risks, auth checks?
4. **Performance**: Unnecessary loops, N+1 queries, missing caching?
5. **Style**: Follows project conventions? Consistent naming?
6. **Tests**: Are changed paths covered by tests?
7. **Documentation**: If `.agentic/lib/tools/docs.sh` exists, run `bash .agentic/lib/tools/docs.sh --list` and `bash .agentic/lib/tools/drift.sh --docs` to check for drift. Check CHANGELOG updated for behavior changes. Check if new user-facing artifacts need adding to `## Docs` in STACK.md. Flag missing doc updates as "Must Fix" when `docs_gate: blocking`.

### 4. Return Structured Report

Return findings in EXACTLY this format:

## Review Summary
[1-2 sentence overview of the changes and overall quality]

## Must Fix
[Bugs, security issues, breaking changes. For each: what, why, concrete fix]

## Should Fix
[Code quality, missing tests, unclear naming. For each: what, why, suggestion]

## Consider
[Style preferences, optimization opportunities]

## Verdict
[APPROVE / REQUEST_CHANGES / NEEDS_DISCUSSION]

If there are no changes to review, report: "No changes found to review."
~~~

### Step 3: Present Results

When the subagent returns, present its findings report to the user as-is. The report is already structured — do not reformat or summarize further.

## Examples

**Example 1: Reviewing a PR**
User says: "/review PR #42"
Steps taken:
1. Scope: PR #42
2. Check branch for F-XXXX, find plan file `.agentic/journal/plans/F-0150-plan.md`
3. Launch subagent with: review `gh pr diff 42`, read plan file, follow protocol
4. Subagent returns structured report → present to user
Result: Token-efficient review — main context only has the compact summary.

**Example 2: Reviewing current changes**
User says: "/review"
Steps taken:
1. Scope: current working tree (git diff)
2. No plan file found
3. Launch subagent with: review `git diff` and `git diff --cached`, no plan, follow protocol
4. Subagent returns findings → present to user
Result: Diffs and file reads stay in subagent context, main context stays clean.

**Example 3: Quick code check (small scope — inline is fine)**
User says: "Is this function okay?" (pointing at a specific small function)
For very small, targeted questions about a single function or snippet, you MAY review inline
without a subagent — use judgment. The subagent approach is for reviewing changesets/PRs.

## Troubleshooting

**Subagent returns empty or unclear results**
Cause: Scope wasn't specific enough in the prompt.
Solution: Ensure the subagent prompt includes the exact command to get the diff (PR number or git diff variant).

**Too many issues found**
Cause: Large changeset or many quality issues.
Solution: The subagent already prioritizes by severity. Focus on Must Fix items first. Suggest breaking the review into smaller pieces.

## References

- For review checklist: see `references/review_checklist.md`
- For code standards: see `references/programming_standards.md`
