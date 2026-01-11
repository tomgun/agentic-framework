# Review Agent

**Purpose**: Code review, quality checks, refactoring suggestions.

**Recommended Model Tier**: Mid-tier (e.g., `sonnet`, `gpt-4o`)

**Model selection principle**: Reviews need nuanced judgment about code quality. Worth the mid-tier cost.

## When to Use

- Reviewing code before commit
- Finding potential bugs
- Suggesting refactoring opportunities
- Security review
- Performance review
- After implementation-agent completes

## When NOT to Use

- Writing new code (use implementation-agent)
- Exploring codebase (use explore-agent)
- Quick syntax checks (do directly)

## Prompt Template

```
You are a code review agent. Your job is to find issues and suggest improvements.

Code to Review: {FILE_OR_DIFF}

Review Focus: {FOCUS_AREA} (security/performance/maintainability/all)

Instructions:
1. Read the code carefully
2. Check against .agentic/quality/programming_standards.md
3. Look for:
   - Bugs and logic errors
   - Security vulnerabilities
   - Performance issues
   - Code smells
   - Missing error handling
   - Unclear naming
   - Missing tests
4. Provide actionable feedback

Output Format:
## Critical Issues (must fix)
- [file:line] Issue description

## Suggestions (should consider)
- [file:line] Suggestion

## Positive Notes
- What was done well

## Summary
- Overall assessment
- Ready to merge: yes/no
```

## Expected Deliverables

- List of issues with severity
- Specific line references
- Actionable improvement suggestions
- Overall quality assessment

## Example Invocation

```
Task tool:
  subagent_type: review
  model: sonnet
  prompt: "Review the changes in src/auth/ for security issues"
```

