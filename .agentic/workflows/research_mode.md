# Research Mode (Deep Investigation)

**Purpose**: Structured, deep research into specific topics to inform decisions, discover alternatives, and stay current with field developments.

## What is Research Mode?

Research Mode is when an agent dedicates focused time (30-90 minutes) to thoroughly investigate a topic:
- Read documentation, papers, articles
- Compare alternatives
- Analyze pros/cons
- Summarize findings
- Make recommendations

**Output**: Structured research document in `docs/research/` that informs decisions.

## When to Enter Research Mode

### Automatic Triggers (from retrospective)

During retrospectives, agent suggests research mode for:

1. **Outdated dependencies**: Major version updates available (>1 year old)
2. **Test framework updates**: New testing approaches/tools in ecosystem
3. **Architecture questions**: When scaling thresholds are hit
4. **Performance issues**: When NFRs are at risk
5. **Security updates**: When vulnerabilities detected
6. **New field developments**: Every 3-6 months for major dependencies

### Manual Triggers

Developer can request:
- "Research alternatives to [technology]"
- "What's new in [framework] ecosystem?"
- "Investigate [performance issue]"
- "Research best practices for [pattern]"

### Proactive Suggestions

Agent suggests research when:
- Critical dependency hasn't been reviewed in 6 months
- New major version of framework released
- Community discussing significant changes
- Architecture decision needed with multiple options

## Research Mode Protocol

### Phase 1: Define Research Question (5 min)

**Clarify:**
- What specific question are we answering?
- What decision will this inform?
- What's the scope? (technology, pattern, architecture, etc.)
- How deep should we go? (quick scan vs. comprehensive)

**Document in research file header:**
```markdown
# Research: [Topic]

**Date**: YYYY-MM-DD
**Researcher**: Agent
**Triggered by**: [Retrospective / Manual / Proactive]
**Time budget**: [30 min / 60 min / 90 min]

## Research Question
[Specific question to answer]

## Decision Context
[What decision this will inform - link to F-####, ADR-####, or HUMAN_NEEDED.md]

## Scope
- Technology comparison: yes/no
- Best practices: yes/no
- Field updates: yes/no
- Performance analysis: yes/no
- Security analysis: yes/no
```

### Phase 2: Information Gathering (15-45 min)

**🚨 CRITICAL: Library Selection Research**

**Before choosing ANY library that enforces rules/standards (chess, poker, protocols, etc.), research:**

1. **Does the library enforce standard rules?**
   - Read documentation for phrases like "enforces standard X", "FIDE-compliant", "RFC-compliant"
   - Check if library validates/restricts behavior

2. **Do we need standard or custom implementation?**
   - Standard: Use library (faster, well-tested)
   - Custom/variant: DON'T use library (will fight constraints)
   - **See `.agentic/quality/library_selection.md` for decision framework**

3. **If unclear, ASK THE USER:**
   ```
   "Does this follow standard [chess/poker/HTTP] rules exactly,
    or does it have custom mechanics?"
   ```
   - Add to HUMAN_NEEDED.md and WAIT for response

4. **Document decision in ADR:**
   - Why library was chosen/rejected
   - What constraints it adds
   - Alternatives considered

**Real failure example:**
- Project: Chess/Tetris hybrid
- Chose: chess.js (enforces standard chess rules)
- Result: FAILED (game has custom rules, pieces, starting position)
- Should have: Implemented custom engine

---

**General research sources:**

1. **Official documentation**
   - Latest release notes
   - Migration guides
   - Best practices
   - Changelog highlights
   - **Constraints and rule enforcement** ⬅️ CRITICAL

2. **Community discussions**
   - GitHub issues/discussions
   - Reddit, HackerNews threads
   - Stack Overflow trends
   - Developer blogs

3. **Comparative analysis**
   - Alternative technologies
   - Benchmark comparisons
   - Feature matrices
   - **Customization/extensibility** ⬅️ CRITICAL

4. **Academic/Industry**
   - Research papers (if relevant)
   - Conference talks
   - Industry reports

5. **Real-world usage**
   - Case studies
   - Production experiences
   - Known issues/gotchas

**Document findings:**
```markdown
## Sources Reviewed

### Official Documentation
- [Framework v2.0 Release Notes](url) - Key changes: ...
- [Migration Guide v1→v2](url) - Breaking changes: ...

### Community Discussions
- [GitHub Issue #1234](url) - Performance concerns discussed
- [HN Thread](url) - Community sentiment: positive/mixed/negative

### Alternatives Considered
- **Alternative A**: [url] - Pros: ... Cons: ...
- **Alternative B**: [url] - Pros: ... Cons: ...

### Benchmarks/Comparisons
- [Benchmark Study](url) - Results: ...
```

### Phase 3: Analysis & Synthesis (10-20 min)

**Key findings:**
```markdown
## Key Findings

### What's New
- Feature 1: [Impact on our project: high/medium/low]
- Feature 2: [Impact: ...]

### Breaking Changes
- Change 1: [Affects us: yes/no] - [Migration effort: small/medium/large]

### Best Practices Evolution
- Practice 1: [We're doing this: yes/no]
- Practice 2: [Should we adopt: yes/no/maybe]

### Alternatives Analysis
| Criteria | Current | Alternative A | Alternative B |
|----------|---------|---------------|---------------|
| Performance | Good | Better | Similar |
| Complexity | Low | Medium | Low |
| Community | Large | Medium | Growing |
| Migration | N/A | Medium | Easy |
| Recommendation | Keep | Consider | Maybe future |

### Security/Performance Concerns
- Issue 1: [Severity: critical/high/medium/low] - [Affects us: yes/no]
```

### Phase 4: Recommendations (5-10 min)

**Generate actionable recommendations:**
```markdown
## Recommendations

### Immediate Actions (High Priority)
1. **[Action]** - [Why] - [Effort: small/medium/large] - [Create task: F-#### or TASK-####]
2. **[Action]** - [Why] - [Effort] - [Task]

### Near-term (Medium Priority)
1. **[Action]** - [Why] - [Effort] - [Timeline]

### Future Considerations (Low Priority)
1. **[Action]** - [Why] - [Revisit when: ...]

### Decisions Needed
- [ ] **Decision**: [Question] - [Options] - [Recommendation] - [Create: ADR-#### or H-####]

## Next Steps

### For Developer
1. [Review findings]
2. [Prioritize recommendations]
3. [Create tasks/ADRs as needed]

### For Agent (if approved)
1. [Implement action 1]
2. [Create task files]
3. [Update affected specs]

## Revisit
- **Next review**: [Date or milestone]
- **Triggers**: [What would trigger re-research]
```

### Phase 5: Documentation & Integration (5-10 min)

**Save research document:**
- Filename: `docs/research/RESEARCH-YYYYMMDD-topic-slug.md`
- Link from `spec/REFERENCES.md`
- Link from related ADRs, features, or HUMAN_NEEDED items

**Update project docs:**
- Add to `spec/REFERENCES.md` if external resources are key
- Update `STATUS.md` if decisions are needed
- Create `HUMAN_NEEDED.md` entry if human decision required
- Create task files for implementation

## Research Topics by Category

### Technology Stack
- "Latest [framework] features and migration path"
- "Alternatives to [library] for [use case]"
- "[Technology] performance benchmarks"
- "Security best practices for [technology]"

### Architecture & Patterns
- "Best practices for [architecture pattern]"
- "Scaling strategies for [workload type]"
- "Microservices vs monolith for [context]"
- "Event sourcing patterns in [domain]"

### Testing & Quality
- "Modern testing approaches for [framework]"
- "[Test framework] v2 changes and benefits"
- "Integration testing best practices"
- "Property-based testing for [language]"

### Performance & Optimization
- "Performance optimization for [technology]"
- "Caching strategies for [use case]"
- "Database indexing best practices"
- "Real-time requirements in [domain]"

### Security & Compliance
- "Security best practices for [framework]"
- "[Technology] vulnerability landscape"
- "GDPR compliance for [feature]"
- "Authentication patterns 2026"

### Field Updates
- "What's new in [ecosystem] 2026"
- "[Conference] key takeaways"
- "Emerging trends in [domain]"
- "[Technology] roadmap analysis"

## Research Depth Levels

### Quick Scan (30 min)
- Official docs only
- Key changes/features
- High-level recommendation
- Use for: routine updates, minor decisions

### Standard Research (60 min)
- Official docs + community
- Alternatives comparison
- Detailed recommendations
- Use for: most decisions, technology choices

### Deep Dive (90 min)
- Comprehensive source review
- Benchmarks/testing
- Detailed migration planning
- Use for: major decisions, architecture changes, critical issues

## Integration with Retrospective

During retrospective, agent identifies research topics:

```markdown
### Research Topics Identified

**High Priority** (research now or within 1 week):
1. [Framework] v2.0 released - breaking changes may affect us
2. [Security] vulnerability in [dependency] - assess impact
3. [Performance] our tests are slow - investigate alternatives

**Medium Priority** (research within 1 month):
1. [Architecture] consider event sourcing for audit log
2. [Testing] explore property-based testing

**Low Priority** (research in 3+ months):
1. [Field update] what's new in [ecosystem]
```

**Agent asks:**
```
Research topics identified during retrospective:

HIGH PRIORITY:
1. [Framework] v2.0 breaking changes (30-60 min)
2. [Security] vulnerability assessment (30 min)

Should I enter research mode now to investigate these?

Options:
1. Yes, research high priority items now (60-90 min total)
2. Yes, but only [specific topic]
3. No, add to tasks for later
4. Let me review retrospective report first
```

## Research Mode Tracking

### In STATUS.md

```markdown
## Active Research
- Topic: [Framework] v2.0 migration
  - Started: YYYY-MM-DD
  - Time budget: 60 min
  - Doc: docs/research/RESEARCH-20260115-framework-v2.md
  - Status: in_progress

## Completed Research
- [Topic] - YYYY-MM-DD - [Key finding] - [Action taken]
```

### In JOURNAL.md

```markdown
## Session: 2026-01-15-1400 (Research Mode)
- Research topic: Testing framework alternatives
- Time spent: 60 minutes
- Sources reviewed: 12 (official docs, 3 blogs, 5 discussions, 2 benchmarks)
- Key findings:
  - Alternative A: 2x faster but less mature
  - Alternative B: similar speed, better DX
  - Current framework: v2 adds features we need
- Recommendation: Upgrade to v2, revisit alternatives in 6 months
- Actions created:
  - TASK-20260115-upgrade-test-framework
  - Updated spec/REFERENCES.md
- Doc: docs/research/RESEARCH-20260115-test-frameworks.md
```

## Example Research Session

**Trigger**: Retrospective identifies test suite is slow

**Research question**: "How can we improve test performance?"

**Phase 1: Define**
```markdown
# Research: Test Performance Optimization

**Date**: 2026-01-15
**Time budget**: 60 min
**Research Question**: How can we reduce test execution time from 45s to <10s?
**Decision Context**: Tests are slowing down development loop (affects developer UX)
```

**Phase 2: Gather (30 min)**
- Review vitest performance guide
- Check for parallel execution options
- Research test splitting strategies
- Look for benchmark comparisons

**Phase 3: Analyze (15 min)**
- Current: Serial execution, no mocking strategy
- Option A: Parallel execution (2x faster, easy)
- Option B: Better mocking (3x faster, medium effort)
- Option C: Test splitting (4x faster, more setup)

**Phase 4: Recommend (10 min)**
- Immediate: Enable parallel execution (1 line change)
- Near-term: Improve mocking strategy (refactor 5 tests)
- Future: Consider test splitting when >100 tests

**Phase 5: Document (5 min)**
- Save to `docs/research/RESEARCH-20260115-test-performance.md`
- Create `TASK-20260115-parallel-tests.md`
- Update `spec/TECH_SPEC.md` testing strategy

## Configuration

### In STACK.md

```markdown
## Research mode (optional)
<!-- Enable proactive research suggestions -->
<!-- - research_enabled: yes -->
<!-- - research_cadence: 90  # days between field update research -->
<!-- - research_depth: standard  # quick | standard | deep -->
<!-- - research_budget: 60  # minutes per session -->
```

### Agent Behavior

If `research_enabled: yes`:
- Agent tracks last research date per technology
- Suggests research when dependencies >90 days old or major versions released
- Checks for research needs during retrospectives
- Proactively monitors for security advisories

## Benefits

✅ **Stay current**: Proactive awareness of ecosystem changes  
✅ **Better decisions**: Informed by comprehensive research  
✅ **Reduce risk**: Security/performance issues caught early  
✅ **Competitive advantage**: Leverage new tools/patterns  
✅ **Knowledge capture**: Research documented for team reference  
✅ **Token-efficient**: Structured approach maximizes research quality per token

## See Also

- Retrospective workflow: `.agentic/workflows/retrospective.md`
- Research templates: `.agentic/support/docs_templates/research_RESEARCH_TOPIC.md`
- External references: `spec/REFERENCES.md`
- Architecture decisions: `spec/adr/`

