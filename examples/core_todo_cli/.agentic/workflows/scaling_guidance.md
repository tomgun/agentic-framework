# Scaling guidance (progressive complexity)

Purpose: lightweight guidance for agents to suggest reorganization when project complexity crosses useful thresholds.

## Philosophy

- **Not mandatory phases**: These are suggestions, not requirements
- **Check periodically**: Agents should check these thresholds occasionally and suggest reorganization
- **User decides**: Always present as "Consider doing X because Y", never force

## Complexity thresholds

### Feature count > 30

**Symptom**: `spec/FEATURES.md` is becoming hard to navigate.

**Consider**:
- Split features by domain/module
  - `spec/features/auth.md`
  - `spec/features/payments.md`
  - `spec/features/admin.md`
- Keep master index in `spec/FEATURES.md` with links
- Update tooling (report.py, doctor.py) to scan multiple files

**How to suggest**:
```
"spec/FEATURES.md has 35 features. Consider splitting by domain for easier navigation:
- spec/features/auth.md (F-0001 through F-0010)
- spec/features/core.md (F-0011 through F-0025)  
- spec/features/admin.md (F-0026 through F-0035)

Keep spec/FEATURES.md as an index with links."
```

### NFR count > 15

**Symptom**: `spec/NFR.md` covers many different concerns.

**Consider**:
- Split by category:
  - `spec/nfr/performance.md`
  - `spec/nfr/security.md`
  - `spec/nfr/reliability.md`
- Keep master index in `spec/NFR.md`

**How to suggest**:
```
"spec/NFR.md has 18 NFRs across multiple categories. Consider organizing by concern:
- spec/nfr/performance.md (NFR-0001, NFR-0005, NFR-0012)
- spec/nfr/security.md (NFR-0002, NFR-0008, NFR-0015)
- spec/nfr/reliability.md (remaining)

This improves focus when working on domain-specific features."
```

### Task backlog > 50

**Symptom**: Too many planned tasks, hard to prioritize.

**Consider**:
- Archive completed tasks to `spec/tasks/archive/`
- Create milestone-based organization
- Review and cancel obsolete tasks

**How to suggest**:
```
"spec/tasks/ has 60 task files. Consider:
1. Archive completed tasks to spec/tasks/archive/
2. Review and cancel obsolete tasks
3. Organize remaining by milestone

Current backlog size makes prioritization difficult."
```

### ADR count > 20

**Symptom**: `spec/adr/` directory is large, finding relevant ADRs is hard.

**Consider**:
- Create `spec/adr/README.md` with categorized index
- Categories: architecture, infrastructure, dependencies, api-design, testing
- Consider archiving superseded ADRs to `spec/adr/archive/`

**How to suggest**:
```
"spec/adr/ has 25 ADRs. Consider creating spec/adr/README.md with categorized index:
- Architecture decisions (5 ADRs)
- Infrastructure (8 ADRs)
- API design (7 ADRs)
- Testing strategy (5 ADRs)

Makes finding relevant context easier."
```

### Codebase > 100 files

**Symptom**: `CONTEXT_PACK.md` can't effectively summarize structure.

**Consider**:
- Create module-specific context docs
  - `docs/context/frontend.md`
  - `docs/context/backend.md`
  - `docs/context/database.md`
- Keep `CONTEXT_PACK.md` as high-level overview with pointers

**How to suggest**:
```
"Codebase has grown to 120 files. Consider splitting context:
- CONTEXT_PACK.md: high-level overview, how to run, key decisions
- docs/context/frontend.md: UI components, routing, state management
- docs/context/backend.md: API, services, data layer
- docs/context/database.md: schema, migrations, queries

Each module context can be read independently when working in that area."
```

### Team size > 3 developers

**Symptom**: Multiple people working concurrently, coordination issues.

**Consider**:
- Module ownership (CODEOWNERS file)
- Branch/PR conventions
- More structured STATUS.md with per-person sections
- Code review checklist enforcement

**How to suggest**:
```
"Team has grown to 4 developers. Consider:
1. Create CODEOWNERS file for module ownership
2. Add branch naming conventions to STACK.md
3. Structure STATUS.md with 'In progress by person' section
4. Enforce review checklist (.agentic/quality/review_checklist.md) in CI

Helps coordinate work and avoid conflicts."
```

### Test suite > 5 minutes

**Symptom**: Tests are slow, impacting development velocity.

**Consider**:
- Separate fast/slow tests
- Run fast tests in pre-commit, slow tests in CI
- Parallelize test execution
- Review integration test database strategy

**How to suggest**:
```
"Test suite takes 7 minutes. Consider:
1. Split tests: `npm run test:fast` (<1 min) vs `npm run test:integration`
2. Run only fast tests in pre-commit hook
3. Parallelize tests in CI
4. Profile tests to identify slow spots

Document test organization in STACK.md."
```

## Agent behavior

### When to check thresholds

Check during these activities:
- **After major feature completion**: natural point to assess organization
- **When STATUS.md becomes unclear**: too much happening simultaneously
- **When session start is slow**: reading context is taking >5 minutes
- **User reports confusion**: "I can't find X", "Where is Y documented?"

**Don't check every session** - only when there are signals that organization could improve.

### How to suggest reorganization

**Good suggestion**:
1. State the symptom: "spec/FEATURES.md has 35 entries"
2. Explain the impact: "Making navigation and focused work harder"
3. Propose specific action: "Consider splitting by domain: auth, core, admin"
4. Offer to help: "I can help create the split if you'd like"

**Bad suggestion**:
- "This is getting complex" (too vague)
- "You must reorganize now" (too forceful)
- Without explaining why or how (not actionable)

### Presenting options

Always frame as options, not requirements:

```markdown
**Optional: Consider reorganizing features**

The feature count has reached 35, which may make spec/FEATURES.md harder to navigate.

Options:
A. Keep as-is (works fine if you're familiar with all features)
B. Split by domain (easier navigation, slightly more files to maintain)
C. Add better indexing at top of file (middle ground)

I can implement any of these if you choose. Or we can revisit later.
```

## Lifecycle indicators (not phases)

These aren't rigid phases but helpful mental models:

### Prototype stage (< 10 features, single developer)
- Minimal ceremony OK
- STATUS.md might be brief
- ADRs optional for obvious choices
- Focus: speed over structure

**Agent behavior**: Don't suggest much reorganization, keep things simple.

### MVP stage (10-30 features, 1-3 developers)
- Standard framework structure sufficient
- ADRs for non-obvious decisions
- Tests required
- Documentation matters

**Agent behavior**: Follow framework as designed, suggest optimizations when clear.

### Production stage (>30 features, team, real users)
- Consider thresholds above
- More ceremony justified
- Documentation critical
- Tooling/automation valuable

**Agent behavior**: Actively suggest improvements when thresholds crossed.

## Examples of good suggestions

### Example 1: Feature split
```
**Observation**: spec/FEATURES.md now has 40 features spanning authentication, 
payments, admin tools, and content management.

**Impact**: When working on payments feature, I need to scan through unrelated 
auth and admin features to find relevant context.

**Suggestion**: Consider splitting into domain files:
- spec/features/auth.md (F-0001 through F-0012)
- spec/features/payments.md (F-0013 through F-0025)
- spec/features/admin.md (F-0026 through F-0035)
- spec/features/content.md (F-0036 through F-0040)

Keep spec/FEATURES.md as index with high-level summary and links.

I can create this structure if helpful, or we can keep as-is if current 
organization works for you.
```

### Example 2: Context splitting
```
**Observation**: CONTEXT_PACK.md is 2000 lines and describes 8 distinct modules.

**Impact**: Session startup is slow (~8 minutes reading), and most context is 
irrelevant for focused work on single module.

**Suggestion**: Consider module-specific context docs:
- CONTEXT_PACK.md: high-level (where things are, how to run, top decisions)
- docs/context/api.md: API layer details
- docs/context/frontend.md: UI component structure
- docs/context/database.md: schema and queries

Agent workflow would become: read CONTEXT_PACK → identify module → read module 
context. Estimated time saving: 5 minutes per session.

Would you like me to create this structure?
```

## Anti-patterns to avoid

### Don't prematurely optimize
- Suggesting splits at 15 features (wait until 30+)
- Suggesting complex tooling for simple projects
- Creating process that slows down small teams

### Don't be dogmatic
- User preference matters
- Some teams prefer one big file
- Thresholds are guidelines, not laws

### Don't reorganize without asking
- Always suggest, never just do it
- User might have reasons for current structure
- Reorganization is a breaking change (relative to habits)

## Related resources
- Agent operating guidelines: `.agentic/agents/shared/agent_operating_guidelines.md`
- Token efficiency: `.agentic/token_efficiency/context_budgeting.md`
- Tool documentation: `.agentic/tools/*.sh`

