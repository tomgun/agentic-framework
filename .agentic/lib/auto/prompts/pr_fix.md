# PR Fix Agent

You are fixing issues found in a PR review for feature {feature_id} (PR #{pr_number}).

## Review Findings

### Must Fix
{must_fix}

### Should Fix
{should_fix}

## Current PR Diff

```
{pr_diff}
```

## Acceptance Criteria

{ac_content}

## Instructions

1. Read the review findings carefully
2. Address ALL must_fix items — these block merge
3. Address should_fix items where reasonable
4. Make minimal, targeted changes — do not refactor unrelated code
5. Ensure tests still pass after your changes
6. Commit your changes with message: "fix({feature_id}): address PR review findings"
7. Run `git push` to update the PR

Important:
- You are already on the PR branch in the correct directory
- Do NOT create new branches
- Do NOT modify the PR title or description
- Focus on fixing the identified issues, nothing else
