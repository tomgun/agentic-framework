# Dialectical Review — Skill Reference

**Source**: `.agentic/lib/workflows/dialectical_review.md`

## When to Trigger

- As the review mechanism within the plan-review loop
- When `plan_review_enabled: yes` in STACK.md
- Each iteration: after Planner creates/revises, before user decides

## Synthesis Format

After both Critic and Advocate return, synthesize using this format:

```markdown
# Dialectical Review: F-XXXX (Iteration N)

**Plan**: `.agentic/journal/plans/F-XXXX-plan.md`
**Conducted**: YYYY-MM-DD

## High-Confidence Findings
[Where both critic and advocate agree — strongest signals]

## Points of Contention
| Topic | Critic Position | Advocate Position |
|-------|----------------|-------------------|

## Uncontested Critic Concerns
[Raised by critic, not addressed by advocate]

## Uncontested Advocate Strengths
[Highlighted by advocate, not challenged by critic]

## Revision Guidance (if user chooses to revise)
1. [Most critical — from High-Confidence Findings]
2. [Important — from Uncontested Critic Concerns]
3. [Consider — from Points of Contention where Critic has stronger case]

## Summary
[Neutral: what the user should pay attention to before deciding]
```

## Synthesis Rules

1. **Agreement = high confidence**: Both sides see it → strong signal
2. **Disagreement = user judgment**: Present both positions fairly
3. **Never add your own opinion**: Neutral reporter only
4. **No verdicts**: The user decides, not the system
5. **Revision Guidance is actionable**: Gives the Planner direction if user chooses to revise

## User Decision

After reading synthesis, user chooses:
- **Proceed**: Set plan status to APPROVED. Ready for `ag implement`.
- **Revise**: Tell Planner what to change. Fresh Critic + Advocate run on revised plan.
- **Reject**: Abandon plan.

## Cross-Tool Notes

| Tool | Approach |
|------|----------|
| **Claude Code** | Agent tool spawns both in parallel (fresh context) — best quality |
| **Cursor** | Orchestrator dispatches sequentially or background agents |
| **Copilot** | Self-play: agent plays both roles sequentially (same context, less independent) |
| **Codex** | Task dispatch similar to Claude Code |
