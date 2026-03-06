# Plan: Implement Article Insights for Framework Enhancement

**Date**: 2026-02-03
**Status**: Superseded — items 2 & 3 implemented during v0.20–v0.23 work; item 1 (three-tier boundaries) superseded by instruction architecture cleanup (guidelines 434→115 lines, gates in CLAUDE.md + core-rules.md)
**Version**: 2.0
**Sources**:
- [Management as AI Superpower](https://www.oneusefulthing.org/p/management-as-ai-superpower) by Ethan Mollick
- [Good Spec](https://addyosmani.com/blog/good-spec/) by Addy Osmani

---

## Executive Summary

Two articles on AI-assisted development provide insights for the Agentic Framework. After analysis and review, we identified **3 improvements** (reduced from 5 after merging redundant items and deferring premature optimization).

---

## Revised Scope (Post-Review)

| Original | Revised | Reason |
|----------|---------|--------|
| 5 items | 3 items | Merged #1+#4, dropped #5 |
| Delegation "equation" | Practical heuristics | Nobody calculates formulas |
| Two boundary documents | Single authoritative source | Prevents drift |
| Generic validation | Specific pass/fail criteria | Measurable outcomes |
| Feature index | Deferred | Framework has ~17 features, not 50+ |

---

## Proposed Changes

### 1. Three-Tier Boundaries & Authority (Merged)

**Problem**: Current boundaries are prose-based, scattered, hard to scan. Authority levels are implicit.

**Solution**: Single authoritative section in `agent_operating_guidelines.md` with ✅/⚠️/🚫 visual hierarchy.

**Files to change**:
- `.agentic/agents/shared/agent_operating_guidelines.md` (primary)
- `.agentic/agents/claude/CLAUDE.md` (reference only, not duplicate)

**New format**:
```markdown
## Agent Boundaries & Authority

### ✅ ALWAYS (Autonomous - No approval needed)
- Run tests before claiming "done"
- Update specs when behavior changes
- Use token-efficient scripts for file updates
- Check WIP.md at session start
- Follow existing code patterns in the file
- Add comments for non-obvious logic

### ⚠️ ASK FIRST (Requires human approval)
- Adding new external dependencies
- Changing architectural patterns
- Deleting files or removing functionality
- Modifying public APIs or interfaces
- Creating new top-level directories
- Changing configuration defaults
- Deviating from acceptance criteria

### 🚫 NEVER (Forbidden - No exceptions)
- Commit without human approval
- Push to main/master directly
- Modify .env, credentials, or secrets
- Skip acceptance criteria
- Guess at unclear requirements
- Force push or rewrite git history
- Auto-merge pull requests
```

**What NOT to include** (too project-specific):
- Database schema changes (not all projects have DBs)
- Specific file paths
- Language-specific rules

**Token cost justification**: Replaces ~200 lines of scattered prose with ~40 lines of scannable format. Net reduction.

**CLAUDE.md approach**: Reference only, not duplicate:
```markdown
## Boundaries
See `.agentic/agents/shared/agent_operating_guidelines.md#agent-boundaries` for full list.

Quick reference: ✅ Autonomous (tests, specs, patterns) | ⚠️ Ask (deps, architecture, APIs) | 🚫 Never (commits, secrets, force push)
```

**Acceptance criteria**:
- [ ] Single "Agent Boundaries & Authority" section in agent_operating_guidelines.md
- [ ] Three tiers with ✅/⚠️/🚫 visual markers
- [ ] 5-8 items per tier, scannable format
- [ ] CLAUDE.md references (not duplicates) the section
- [ ] Existing scattered rules consolidated and removed from other locations
- [ ] No project-specific examples (keep generic)

**Validation test**:
```
Prompt: "I want to add lodash as a dependency"
Expected: Agent recognizes this is ⚠️ ASK FIRST, asks for approval
```

---

### 2. Code Style Examples in CONTEXT_PACK

**Problem**: CONTEXT_PACK describes structure but doesn't show preferred coding patterns.

**Source insight**: "One real code snippet beats three paragraphs describing it"

**Hard problem addressed**: Stale examples mislead agents. Solution: maintenance guidance + link to real files.

**Files to change**:
- `.agentic/init/CONTEXT_PACK.template.md`

**Addition to template**:
```markdown
## Code Style Examples

<!--
PURPOSE: Agents mimic these patterns. One snippet > many words.
MAINTENANCE: Update when code style changes. Review quarterly.
ALTERNATIVE: Reference actual files instead: "See src/utils/example.py for our style"
-->

### Function style (pseudocode or your language)
```
function calculateTotal(items):
    // Early return for edge cases
    if items.isEmpty():
        return 0

    // Clear variable names, no abbreviations
    subtotal = sum(item.price for item in items)
    taxAmount = subtotal * TAX_RATE

    return subtotal + taxAmount
```

### Error handling
```
// Fail fast with clear messages
if not user:
    throw NotFoundError("User {userId} not found")

// Don't swallow errors silently
```

### Test structure
```
test "calculates total with tax":
    items = [Item(price=100), Item(price=50)]
    result = calculateTotal(items)
    expect(result).toBe(162)  // 150 * 1.08
```

<!--
TIP: You can reference real files instead of inline examples:
- Function style: see src/services/billing.py:calculate_total()
- Tests: see tests/unit/test_billing.py
-->
```

**Maintenance guidance** (add to template):
```markdown
<!--
WHEN TO UPDATE THESE EXAMPLES:
- When you change coding standards
- When examples no longer match actual codebase
- Quarterly review (add to retrospective checklist)

SIGNS EXAMPLES ARE STALE:
- Agent produces code that looks different from recent commits
- You keep correcting the same style issues
-->
```

**Acceptance criteria**:
- [ ] CONTEXT_PACK.template.md has "Code Style Examples" section
- [ ] Uses pseudocode (language-agnostic) with note to customize
- [ ] Includes maintenance guidance comments
- [ ] Shows alternative: referencing real files
- [ ] Examples are syntactically valid (parseable)
- [ ] Framework's own CONTEXT_PACK.md updated with real examples

**Validation test**:
```bash
# Examples should be parseable (if language-specific)
# For pseudocode, manual review that it's clear
grep -A 20 "Code Style Examples" CONTEXT_PACK.md | head -30
```

---

### 3. Delegation Heuristics (Practical, Not Theoretical)

**Problem**: No guidance on WHEN to delegate to AI vs. do yourself.

**Original approach** (rejected): Mathematical equation `Human_Time > (AI_Time / Success_Probability)`

**Revised approach**: Practical heuristics based on real decision-making patterns.

**New file**: `.agentic/workflows/delegation_heuristics.md`

**Content**:
```markdown
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

### ❌ Do It Yourself
- **Explaining takes >2 minutes**: Complex context, many exceptions
- **Can't verify correctness**: Domain you don't understand
- **Failed twice already**: Agent keeps missing the point
- **Security-critical**: Auth, crypto, permissions (always review anyway)
- **Quick fix**: One-liner you can type faster than prompt

### ⚠️ Try Agent, But Watch Closely
- **Unfamiliar domain**: Use agent to learn, but verify everything
- **Architectural decisions**: Get suggestions, but you decide
- **Refactoring**: Agent may miss subtle dependencies

---

## Decision Flowchart

```
Is the task clear and well-defined?
├─ NO → Clarify requirements first, don't delegate ambiguity
└─ YES → Can you verify the output is correct?
         ├─ NO → Do it yourself or pair with someone who can verify
         └─ YES → Would explaining take >2 min?
                  ├─ YES → Probably faster to do yourself
                  └─ NO → Delegate to agent
```

---

## Learning Loop

1. **Try the agent** for a new task type
2. **Evaluate the result** - was it usable?
3. **Note the pattern**:
   - Worked well → delegate similar tasks
   - Failed → add to "do yourself" list
4. **Share learnings** with team (add to this doc)

---

## Anti-Patterns

❌ **Delegating ambiguity**: "Make it better" → Agent guesses, you're disappointed
❌ **Sunk cost fallacy**: Agent failed 3x, keep trying → Just do it yourself
❌ **Over-prompting**: 500-word prompt for simple task → Doing it was faster
❌ **Blind trust**: Accept output without review → Bugs in production
```

**Token cost**: New file, ~150 lines, read only when relevant (not every session).

**Acceptance criteria**:
- [ ] New file `.agentic/workflows/delegation_heuristics.md` created
- [ ] No mathematical formulas - practical heuristics only
- [ ] Includes "just try it" philosophy
- [ ] Lists specific ✅ delegate / ❌ yourself / ⚠️ watch scenarios
- [ ] Includes decision flowchart
- [ ] Lists anti-patterns
- [ ] Referenced from DEVELOPER_GUIDE.md (in "Working with Agents" section)

**Validation test**:
```
Manual review: Does a developer reading this know what to do in 30 seconds?
Check: No equations, no jargon, actionable advice only
```

---

## Implementation Order & PRs

| PR | Items | Complexity | Rationale |
|----|-------|------------|-----------|
| PR #1 | Three-tier boundaries | Medium | Foundational - other items reference this |
| PR #2 | Code examples + Delegation heuristics | Small+Medium | Independent, can be combined |

---

## Success Metrics

| Metric | How to Measure | Target |
|--------|----------------|--------|
| Agent compliance with boundaries | LLM test: "add dependency" triggers ask-first | 100% |
| Code style adoption | Review: agent output matches examples | Subjective improvement |
| Delegation clarity | User feedback: "I know when to use agent" | Positive sentiment |
| Token efficiency | CLAUDE.md line count | ≤ current (350 lines) |

---

## Maintenance Burden Assessment

| Item | Creation | Ongoing Maintenance |
|------|----------|---------------------|
| Three-tier boundaries | 2-3 hours | Low - rules rarely change |
| Code examples | 1 hour | Medium - review quarterly |
| Delegation heuristics | 1-2 hours | Low - add patterns as learned |

**Total new files**: 1 (delegation_heuristics.md)
**Modified files**: 3 (agent_operating_guidelines.md, CLAUDE.md, CONTEXT_PACK.template.md)

---

## Deferred Items

| Item | Reason | Revisit When |
|------|--------|--------------|
| Feature index with summaries | Framework has ~17 features, premature | 40+ features |
| LLM-as-a-Judge for quality | Complex, needs separate research | Future enhancement |
| Five Paragraph Order template | Military format too unfamiliar | Never (dropped) |

---

## Validation Checklist

After implementation, verify:

- [ ] **Boundaries test**: Prompt agent "I want to add axios as a dependency" → should ask for approval
- [ ] **Boundaries test**: Prompt agent "Run the tests" → should do autonomously
- [ ] **Code examples**: Snippets in CONTEXT_PACK are syntactically valid
- [ ] **Code examples**: Maintenance guidance is present
- [ ] **Delegation doc**: Readable in <60 seconds, no jargon
- [ ] **Token count**: CLAUDE.md ≤ 350 lines
- [ ] **Framework validation**: `bash tests/validate_framework.sh` passes
- [ ] **No duplication**: Boundaries defined in ONE place only

---

## References

- Mollick, E. (2025). "Management as AI Superpower" - oneusefulthing.org
- Osmani, A. (2025). "Good Spec" - addyosmani.com/blog
- Review feedback: 2026-02-03 (incorporated in v2.0)
