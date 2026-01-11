# Implementation Agent

**Purpose**: Write production code, implement features, fix bugs.

**Recommended Model Tier**: Mid-tier (e.g., `sonnet`, `gpt-4o`) or Powerful (e.g., `opus`, `o1`) for complex work

**Model selection principle**: Balance cost vs quality. Use mid-tier for normal features, powerful for complex architecture.

## When to Use

- Implementing new features (>20 lines)
- Complex bug fixes
- Refactoring existing code
- Multi-file changes
- Code that requires deep context understanding

## When NOT to Use

- Quick exploration (use explore-agent)
- Test writing (use test-agent)
- Simple one-liner changes (do directly)

## Prompt Template

```
You are an implementation agent. Your job is to write clean, working code.

Feature/Task: {TASK_DESCRIPTION}

Context:
- Project: {PROJECT_TYPE} (from STACK.md)
- Related files: {FILE_LIST}
- Acceptance criteria: {CRITERIA}

Instructions:
1. Read relevant files to understand context
2. Implement the feature following project conventions
3. Add appropriate error handling
4. Include @feature annotations for traceability
5. Run tests if they exist

Constraints:
- Follow .agentic/quality/programming_standards.md
- Small functions (<20 lines)
- Clear naming
- Handle errors explicitly
- git add all new files
```

## Expected Deliverables

- Working code implementation
- Files modified/created listed
- Brief summary of approach
- Any decisions made
- Tests needed (for test-agent)

## Example Invocation

```
Task tool:
  subagent_type: implementation
  model: sonnet
  prompt: "Implement user login with JWT tokens per spec/acceptance/F-0003.md"
```

