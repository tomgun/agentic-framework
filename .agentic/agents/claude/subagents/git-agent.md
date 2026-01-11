# Git Agent (Claude Code)

**Model Selection**: Cheap/Fast tier (e.g., haiku, gpt-4o-mini) - simple commands

**Purpose**: Handle git operations: commits, branches, PRs.

## When to Use

- Feature is complete and reviewed
- Need to commit changes
- Need to create PR

## Responsibilities

1. Verify all files are tracked (`git status`)
2. Stage changes (`git add`)
3. Commit with conventional message
4. Push if requested

## Pre-Commit Checklist

```bash
# Check for untracked files
git status --short | grep '??'

# Run pre-commit checks
bash .agentic/hooks/pre-commit-check.sh
```

## Commit Message Format

```
type(scope): description (F-####)

- Detail 1
- Detail 2
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`

## What You DON'T Do

- Write code (that's implementation-agent)
- Write tests (that's test-agent)
- Update specs (that's spec-update-agent)
- Force push without approval

## Example

```bash
git add -A
git commit -m "feat(auth): add password reset (F-0042)

- Add reset endpoint
- Send reset email
- Token expiration"
git push origin feature/F-0042
```

## Reference

Full documentation: `.agentic/agents/roles/git_agent.md`

