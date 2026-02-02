# Claude (Anthropic) Instructions

You are working in a repository that uses the **Agentic Framework** for AI-assisted development.

## Core Guidelines

1. **Read these files at session start**:
   - `AGENTS.md` (if present)
   - `.agentic/agents/shared/agent_operating_guidelines.md` (mandatory)
   - `CONTEXT_PACK.md` (where things are, how to run)
   - `STATUS.md` (current focus, next steps)
   - Relevant spec files for your task

2. **Follow programming standards** (`.agentic/quality/programming_standards.md`):
   - **Security first**: Validate all input, use parameterized queries, no hardcoded secrets
   - **Clear naming**: Descriptive names (not cryptic abbreviations)
   - **Small functions**: <50 lines ideal, single purpose
   - **Explicit error handling**: Fail fast with specific error types
   - **Performance**: Profile before optimizing, efficient data structures
   
3. **Follow testing standards** (`.agentic/quality/test_strategy.md`):
   - Test happy path + edge cases + invalid input
   - Test time-based behavior with mock clocks (not real delays)
   - Use descriptive test names: "should [behavior] when [condition]"
   - Coverage: Happy path (required) + Edge cases (required) + Errors (required)

4. **Development approach**:
   - Check `STACK.md` for `development_mode`:
     - `tdd` (RECOMMENDED): Write tests FIRST (see `.agentic/workflows/tdd_mode.md`)
     - `standard`: Tests required but can come during/after implementation
   - Check for sequential pipeline mode (`pipeline_enabled` in `STACK.md`)

5. **Never auto-commit**:
   - ALWAYS show changes to human first
   - ONLY commit when human says "commit" or explicitly approves
   - See `.agentic/workflows/git_workflow.md` for protocols

## Session End Checklist

Before ending a session, ensure:
- [ ] Code follows `programming_standards.md` (clear names, small functions, security checks)
- [ ] Tests follow `test_strategy.md` (edge cases, invalid input, mock clocks for time)
- [ ] Code formatted/linted (ESLint, black, etc.)
- [ ] `STATUS.md` updated
- [ ] Feature annotations added (`@feature F-####`, `@acceptance AC#`)
- [ ] Human told: what changed, what's next, what you need

## Key Workflows

- TDD mode: `.agentic/workflows/tdd_mode.md`
- Standard dev loop: `.agentic/workflows/dev_loop.md`
- Git workflow: `.agentic/workflows/git_workflow.md`
- Sequential pipeline: `.agentic/workflows/sequential_agent_specialization.md`

## Quality Standards

- Programming: `.agentic/quality/programming_standards.md` (1,200+ lines - security, performance, clarity)
- Testing: `.agentic/quality/test_strategy.md` (350+ lines - edge cases, time, errors)
- Review: `.agentic/quality/review_checklist.md`
- Design: `.agentic/quality/design_for_testability.md`

Follow these standards to produce secure, efficient, maintainable code.
