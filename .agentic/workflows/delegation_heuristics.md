# When to Use AI Agents vs. Do It Yourself

## Core Philosophy: Just Try It

Don't overthink delegation. The cost of trying is low:
- Agent succeeds → you saved time
- Agent fails → you learned what doesn't work, do it yourself

**Rule of thumb**: If explaining the task takes longer than doing it, just do it yourself.

---

## Quick Heuristics

### ✅ Delegate to Agent
- **Repetitive tasks**: CRUD operations, boilerplate, migrations
- **Clear specs exist**: Acceptance criteria are written
- **You can verify quickly**: Output is obviously right or wrong
- **Pattern exists**: Similar code already in codebase
- **Documentation tasks**: READMEs, comments, changelogs
- **Research**: Finding docs, comparing options, summarizing

### ❌ Do It Yourself
- **Explaining takes >2 minutes**: Complex context, many exceptions
- **Can't verify correctness**: Domain you don't understand
- **Failed twice already**: Agent keeps missing the point
- **Security-critical**: Auth, crypto, permissions (always review anyway)
- **Quick fix**: One-liner you can type faster than prompt
- **Highly creative**: Novel architecture with no precedent

### ⚠️ Try Agent, But Watch Closely
- **Unfamiliar domain**: Use agent to learn, but verify everything
- **Architectural decisions**: Get suggestions, but you decide
- **Refactoring**: Agent may miss subtle dependencies
- **Complex debugging**: Agent can help investigate, you diagnose

---

## Decision Flowchart

```
Is the task clear and well-defined?
├─ NO → Clarify requirements first, don't delegate ambiguity
└─ YES → Can you verify the output is correct?
         ├─ NO → Do it yourself (or pair with expert)
         └─ YES → Would explaining take >2 min?
                  ├─ YES → Probably faster to do yourself
                  └─ NO → Delegate to agent ✅
```

---

## Task-Type Examples

| Task | Delegate? | Why |
|------|-----------|-----|
| Write unit tests for existing function | ✅ Yes | Clear input/output, verifiable |
| Add CRUD endpoints | ✅ Yes | Repetitive, follows patterns |
| Write migration script | ✅ Yes | Mechanical, testable |
| Debug intermittent race condition | ⚠️ Partial | Agent helps investigate, you diagnose |
| Design new auth system | ⚠️ Partial | Get options, you decide architecture |
| Fix typo in README | ❌ No | Faster to do yourself |
| Implement novel algorithm | ⚠️ Partial | Agent helps, verify carefully |
| Review code for security issues | ⚠️ Partial | Agent flags, human confirms |

---

## Learning Loop

1. **Try the agent** for a new task type
2. **Evaluate the result** - was it usable?
3. **Note the pattern**:
   - Worked well → delegate similar tasks
   - Failed → add to "do yourself" list
4. **Share learnings** with team

---

## Anti-Patterns

❌ **Delegating ambiguity**
> "Make it better" → Agent guesses, you're disappointed
> Fix: Write clear acceptance criteria first

❌ **Sunk cost fallacy**
> Agent failed 3x, keep trying → Just do it yourself
> Fix: If it's not working after 2 attempts, take over

❌ **Over-prompting**
> 500-word prompt for simple task → Doing it was faster
> Fix: If prompt is longer than solution, just code it

❌ **Blind trust**
> Accept output without review → Bugs in production
> Fix: Always verify, especially for unfamiliar domains

❌ **Perfectionist prompting**
> Spend 20 min crafting perfect prompt → Could have coded it
> Fix: Start simple, iterate if needed

---

## When Agent Fails

If the agent produces unusable output:

1. **Check your prompt**: Was it clear? Did you provide enough context?
2. **Check complexity**: Is the task too big? Break it down.
3. **Check domain**: Do you understand enough to verify?
4. **Give up gracefully**: After 2 failed attempts, do it yourself. It's faster.

---

## Summary

| Situation | Action |
|-----------|--------|
| Clear spec, verifiable output | ✅ Delegate |
| Would take >2 min to explain | ❌ Do yourself |
| Agent failed twice | ❌ Do yourself |
| Security-critical | ⚠️ Agent helps, you review |
| Unfamiliar domain | ⚠️ Agent helps, verify everything |
| Quick one-liner | ❌ Do yourself |

**Remember**: The goal is shipping quality software, not maximizing AI usage.

---

## Meta-Insights About Agent Behavior

### Instructions Don't Change Agent Behavior

Behavioral instructions ("answer honestly", "consider alternatives") rarely change agent behavior. Structural constraints and automated verification do.

- Agents that over-engineer won't stop because you asked
- Self-reflection prompts get gamed or ignored
- "Should you do X?" becomes "yes" regardless of actual behavior

**What works instead**:
- Build verification scripts instead of guidelines
- Show information (diff stats) instead of asking questions
- Structural constraints (gates, hooks) beat behavioral instructions

### One Example Beats Three Paragraphs

Agents learn patterns from examples better than from prose descriptions.

- Examples are concrete; prose is abstract
- Agents pattern-match; lengthy explanations may be skimmed
- "Functions should be small" is vague; a 15-line function is concrete

**What works**:
- Code style examples beat style guidelines
- Reference real files: "See src/utils/example.py"
- Show before/after for transformations
