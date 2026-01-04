# Retrospective Checklist

**Purpose**: Systematic project health review to improve quality and processes.

**Use**: When retrospective is triggered (time-based or feature-based milestone).

**Important**: Get human approval before running retrospective. This is analysis + recommendations, not autonomous changes.

---

## Before Starting Retrospective

- [ ] **Confirm retrospective is due**
  - Check trigger conditions (time-based or feature-count)
  - Run `bash .agentic/tools/retro_check.sh` to verify
  - Don't run retrospective too frequently (respect thresholds)

- [ ] **Get human approval**
  - Tell user: "Retrospective is due. Should I proceed?"
  - Wait for explicit approval
  - Don't start without permission

- [ ] **Allocate sufficient time/tokens**
  - Retrospectives require thoughtful analysis
  - Budget ~5K-10K tokens for thorough review
  - Not a quick task

---

## Review Period

- [ ] **Determine review period**
  - Since last retrospective
  - Or since project start (if first retro)
  - Document date range: "Reviewing 2025-12-01 to 2026-01-03"

- [ ] **Read all JOURNAL entries**
  - Every entry since last retro
  - Look for patterns
  - Note recurring issues
  - Identify successes

---

## Bug & Issue Analysis

- [ ] **List all bugs encountered**
  - From JOURNAL.md mentions
  - From HUMAN_NEEDED.md escalations
  - From git commit messages (fix: commits)
  - Categorize by type

- [ ] **Analyze each bug**
  - What was the root cause?
  - Did tests catch it? (If not, why not?)
  - Could quality checks have caught it?
  - Is it a pattern (similar bugs before)?

- [ ] **Identify test gaps**
  - What types of tests were missing?
  - Edge cases not covered?
  - Integration points not tested?
  - Time-based issues not tested?

---

## Quality Validation Review

- [ ] **Review current quality checks**
  - Read `quality_checks.sh` (if exists)
  - Are checks comprehensive?
  - Do they catch bugs that occurred?
  - Are they stack-appropriate?

- [ ] **Identify missing checks**
  - Based on bugs found:
    - Should linting rules be stricter?
    - Should there be DSP validation? (audio)
    - Should there be bundle size checks? (web)
    - Should there be memory leak detection?
  - Stack-specific: Are we using best practices for this tech?

- [ ] **Propose quality improvements**
  - New checks to add
  - Existing checks to enhance
  - Tools to integrate (pluginval, Lighthouse, etc.)
  - Concrete, actionable recommendations

---

## Process Effectiveness

- [ ] **Review what went well**
  - What processes helped?
  - What tools were useful?
  - What workflows were smooth?
  - Celebrate wins

- [ ] **Review what went poorly**
  - What caused friction?
  - What was confusing?
  - What took longer than expected?
  - What was repetitive/manual?

- [ ] **Identify improvement opportunities**
  - Automation opportunities
  - Documentation needs
  - Tool gaps
  - Process changes

---

## Documentation Health

- [ ] **Check documentation accuracy**
  - Is CONTEXT_PACK.md still accurate?
  - Is PRODUCT.md / spec/ current?
  - Are there stale placeholders?
  - Are READMEs up to date?

- [ ] **Check documentation completeness**
  - Missing documentation for complex areas?
  - New features not documented?
  - API changes not reflected?
  - Architecture drift from docs?

- [ ] **Propose documentation improvements**
  - Specific docs to create/update
  - Areas needing more detail
  - Outdated content to remove

---

## Test Coverage & Quality

- [ ] **Review test coverage**
  - Are critical paths tested?
  - Are edge cases covered?
  - Are error paths tested?
  - Is coverage adequate for risk level?

- [ ] **Review test quality**
  - Do tests actually validate behavior?
  - Are tests clear and maintainable?
  - Are there flaky tests?
  - Do tests run fast enough?

- [ ] **Consider mutation testing** (for critical code)
  - If critical code (auth, payments, data integrity)
  - Recommend running mutation tests
  - High-value areas to verify test quality

---

## Architecture & Code Quality

- [ ] **Review for technical debt**
  - Areas needing refactoring?
  - Code smells accumulating?
  - Architecture starting to strain?
  - Dependencies outdated?

- [ ] **Check for complexity growth**
  - Are files getting too large?
  - Are functions getting too complex?
  - Is coupling increasing?
  - Need better separation of concerns?

- [ ] **Recommend improvements**
  - Specific refactorings
  - Architectural changes
  - Code quality improvements
  - Concrete, prioritized recommendations

---

## Create Retrospective Document

- [ ] **Create retro document**
  - File: `docs/retrospectives/retro_YYYY-MM-DD.md`
  - Use template if available
  - Comprehensive but concise

### Document Structure

```markdown
# Retrospective - YYYY-MM-DD

**Period**: [date range reviewed]
**Features completed**: [count or list]
**Bugs encountered**: [count]

## What Went Well
- [bullet points]

## What Went Poorly
- [bullet points]

## Bugs & Issues Encountered
- Bug 1: [description] - Root cause: [cause] - Test gap: [gap]
- Bug 2: ...

## Quality Check Improvements
### Proposed additions to quality_checks.sh:
- [ ] Add [specific check] to catch [specific issue]
- [ ] Add [tool integration] for [purpose]

### Rationale:
- [explanation of why these checks matter]

## Process Improvements
- [ ] [Specific process change]
- [ ] [Automation opportunity]

## Documentation Improvements
- [ ] Update [specific doc] to reflect [what]
- [ ] Create [new doc] to explain [what]

## Technical Debt to Address
- [ ] [Specific refactoring] - Priority: [High/Medium/Low]
- [ ] [Architectural change] - Priority: [High/Medium/Low]

## Action Items
- [ ] [Concrete action] - Owner: [Human/Agent] - By when: [date]
- [ ] [Concrete action] - Owner: [Human/Agent] - By when: [date]

## Metrics (if applicable)
- Test coverage: X%
- Features completed this period: Y
- Bugs found: Z
- Quality checks added: N
```

---

## Present to Human

- [ ] **Summarize findings**
  - Key insights (3-5 bullets)
  - Most important improvements
  - Prioritized recommendations

- [ ] **Show full retrospective document**
  - Let them read complete analysis
  - Point out sections of particular interest

- [ ] **Discuss action items**
  - What should be done now?
  - What can wait?
  - Who does what?
  - Any disagreements with analysis?

- [ ] **Get approval for changes**
  - Which quality checks to add?
  - Which docs to update?
  - Which technical debt to tackle?
  - Don't make changes without approval

---

## Implement Approved Changes

**Only after human approval:**

- [ ] **Update quality_checks.sh** (if approved)
  - Add new checks
  - Test they work
  - Document what each check does
  - Commit: `chore(quality): add [checks] based on retrospective`

- [ ] **Update documentation** (if approved)
  - Make agreed-upon doc updates
  - Ensure accuracy
  - Commit: `docs: update [docs] based on retrospective`

- [ ] **Address technical debt** (if approved and time permits)
  - Tackle highest-priority items
  - With tests and proper commits
  - Don't rush - quality matters

- [ ] **Update STACK.md**
  - Set `last_retrospective_date: YYYY-MM-DD`
  - So next retro knows when to trigger

---

## After Retrospective

- [ ] **Update JOURNAL.md**
  - Note retrospective was completed
  - Date and key findings
  - Actions taken

- [ ] **Link retro in appropriate docs**
  - Add to docs/retrospectives/ index (if exists)
  - Reference in JOURNAL if significant changes

- [ ] **Schedule next retrospective**
  - Based on triggers in STACK.md
  - Human knows when next one is due

---

## Anti-Patterns

❌ **Don't** run retrospective without human approval  
❌ **Don't** make changes without discussing findings first  
❌ **Don't** do shallow analysis (invest the time)  
❌ **Don't** forget to update quality_checks.sh if bugs found  
❌ **Don't** create retro doc without concrete actions  
❌ **Don't** ignore patterns in bugs/issues  

✅ **Do** thorough analysis of all journal entries  
✅ **Do** identify concrete, actionable improvements  
✅ **Do** update quality checks based on real bugs  
✅ **Do** celebrate what went well  
✅ **Do** get human buy-in for changes  
✅ **Do** follow up on action items  

---

## Retrospective Complete

**After all items checked:**

1. Retro document created and saved
2. Human reviewed and approved findings
3. Agreed changes implemented
4. STACK.md last_retrospective_date updated
5. JOURNAL.md documents retro completion
6. Next retro scheduled

**Remember**: Retrospectives are about **continuous improvement**. Use real data (bugs, issues, friction) to make the project better. Not a formality - a genuine health check.

**Quality bar**: Did this retrospective result in concrete improvements to quality checks, processes, or documentation? If not, dig deeper.

