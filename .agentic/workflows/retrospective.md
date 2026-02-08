# Project Retrospective (Automated Health Check)

**Purpose**: Periodic agent-led review of project health, suggesting improvements to architecture, testing, specs, and development practices.

## When to Run a Retrospective

Agents should **proactively suggest** running a retrospective when:

### Automatic Triggers

1. **Feature milestone**: Every 5-10 features shipped
2. **Time-based**: After 14 days of active development
3. **Complexity threshold**: When scaling_guidance.md thresholds are hit
4. **Test debt**: When >3 features have incomplete tests
5. **Documentation drift**: When consistency.py reports >5 issues

### Manual Trigger

Developer can request: "Run a project retrospective"

## Retrospective Checklist

When running a retrospective, the agent should:

### 1. Project Health Check (5 min)

**Run automated tools:**
```bash
bash .agentic/tools/verify.sh      # Comprehensive checks
bash .agentic/tools/drift.sh      # Spec/code drift
bash .agentic/tools/stale.sh       # Stale documentation
bash .agentic/tools/version_check.sh # Version mismatches
```

**Review outputs and note issues.**

### 2. Testing Strategy Review (10 min)

**Questions to investigate:**
- Are test frameworks still current? (Check release notes, community updates)
- Are we using best practices? (Research latest patterns)
- Is test coverage adequate? (Check FEATURES.md test status)
- Are tests running fast enough? (Check test execution time)
- Do we need integration/e2e tests we're missing?

**Trigger research mode if:**
- Major framework updates available (>6 months old)
- Community discussing significant changes
- Performance issues detected (tests >30s)
- New testing approaches emerged

**Research if needed:**
- For quick checks: Scan official docs (5 min)
- For detailed investigation: Enter **Research Mode** (see `.agentic/workflows/research_mode.md`)
  - Example: "Research: Testing framework v2.0 migration" (60 min)
  - Example: "Research: Test performance optimization strategies" (60 min)

**Suggest:**
- New testing approaches to adopt
- Test debt to address
- Testing tools to add

### 3. Specification Quality Review (10 min)

**Review these files:**
- `spec/FEATURES.md`: Are features well-structured? Too many/too few?
- `spec/NFR.md`: Are NFRs still relevant? Any missing?
- `spec/PRD.md`: Is product direction still clear?
- `spec/TECH_SPEC.md`: Is architecture documentation current?
- `spec/acceptance/*.md`: Are acceptance criteria clear and testable?

**Check for:**
- Inconsistencies between specs
- Missing acceptance criteria
- Outdated requirements
- Features stuck in 'in_progress' for too long

**Suggest:**
- Spec improvements (clearer criteria, better organization)
- Missing specs or sections
- Specs that could be archived

### 4. Architecture Evolution Review (10 min)

**Questions to investigate:**
- Has architecture diverged from TECH_SPEC.md?
- Are there emerging patterns we should document?
- Are there better libraries/frameworks for our needs?
- Is technical debt accumulating?

**Run:**
```bash
bash .agentic/tools/drift.sh --check  # Spec/code drift
```

**Trigger research mode if:**
- Major dependency updates available
- Architecture scaling issues
- Performance/security concerns
- New architectural patterns emerged

**Research if needed:**
- For quick checks: Review official docs and changelog (5 min)
- For detailed investigation: Enter **Research Mode** (see `.agentic/workflows/research_mode.md`)
  - Example: "Research: [Framework] v2.0 migration path" (60 min)
  - Example: "Research: Alternative databases for [use case]" (90 min)
  - Example: "Research: Event sourcing patterns in [domain]" (60 min)

**Suggest:**
- Architecture improvements
- Technical debt to address
- Libraries to upgrade or replace
- Patterns to adopt

### 5. Development Workflow Review (5 min)

**Questions to ask:**
- Is TDD working well for this project?
- Are commits appropriately sized?
- Is JOURNAL.md being maintained?
- Are we following Definition of Done?

**Check:**
- Recent commits (are they small and focused?)
- JOURNAL.md entries (are sessions being logged?)
- FEATURES.md (are statuses being updated?)

**Suggest:**
- Workflow improvements
- Better commit practices
- Documentation habits

### 7. Quality Validation Review (5 min)

**Check quality_checks.sh effectiveness:**
- Is `quality_checks.sh` set up? If not, suggest creating it.
- Have any quality checks failed recently? What patterns?
- Were bugs caught by checks or slipped through?
- Are checks too slow? (>2 min for pre-commit)
- Are checks too strict or too lenient?
- New failure modes discovered since last retro?

**Suggest improvements:**
- Add new checks for recent bug types (e.g., "We had a NaN bug, add NaN detection")
- Remove/relax checks causing false positives
- Optimize slow checks (run subset in pre-commit, full in CI)
- Update thresholds based on actual measurements
- Add missing stack-specific checks

**Update quality_checks.sh if needed.**

**Trigger research mode if:**
- New testing tools/approaches available
- Performance benchmarks need updating
- Quality standards need revision

### 8. Innovation & Improvements (10 min)

**Explore:**
- Are there new tools that would help? (linters, formatters, CI tools)
- Are there emerging best practices we should adopt?
- Could we automate more with scripts?
- Are there better ways to organize the project?
- What's new in our technology ecosystem?

**Trigger research mode if:**
- >3 months since last field update research
- Major ecosystem changes detected
- Competitive products using new approaches
- Developer productivity could be improved

**Research:**
- For quick scan: Check "[ecosystem] 2026 updates" (10 min)
- For deep investigation: Enter **Research Mode** (see `.agentic/workflows/research_mode.md`)
  - Example: "Research: What's new in [ecosystem] 2026" (60 min)
  - Example: "Research: Developer productivity tools for [domain]" (60 min)
  - Example: "Research: Emerging patterns in [field]" (90 min)

**Suggest:**
- New tools to adopt
- Automation opportunities
- Quality-of-life improvements

### 7. Generate Retrospective Report

**Create:** `docs/retrospectives/RETRO-YYYY-MM-DD.md`

**Template:**

```markdown
# Project Retrospective: YYYY-MM-DD

**Trigger**: [Feature milestone / Time-based / Manual]
**Duration**: [X minutes]
**Features shipped since last retro**: [N]

## Health Check Summary

### Automated Tools
- verify.sh: [PASS/FAIL - summary]
- drift.sh: [X issues found]
- stale.sh: [X stale docs]

### Key Metrics
- Features shipped: [N]
- Features in progress: [N]
- Test coverage: [%]
- Documentation drift: [issues]

## Findings & Recommendations

### 🧪 Testing Strategy
**Status**: [Good / Needs attention / Critical]

**Findings**:
- [Finding 1]
- [Finding 2]

**Recommendations**:
1. [Recommendation 1 - Priority: High/Med/Low]
2. [Recommendation 2]

**Research conducted**:
- [Link to research: docs/research/RESEARCH-YYYYMMDD-topic.md]
- [Or: "Quick scan, no deep research needed"]

### 📋 Specification Quality
**Status**: [Good / Needs attention / Critical]

**Findings**:
- [Finding 1]

**Recommendations**:
1. [Recommendation 1]

### 🏗️ Architecture
**Status**: [Good / Needs attention / Critical]

**Findings**:
- [Finding 1]

**Recommendations**:
1. [Recommendation 1]

**Research conducted**:
- [Link to research]

### 🔄 Development Workflow
**Status**: [Good / Needs attention / Critical]

**Findings**:
- [Finding 1]

**Recommendations**:
1. [Recommendation 1]

### 💡 Innovation Opportunities
**New tools/practices to consider**:
1. [Tool/Practice 1] - [Why it's relevant]
2. [Tool/Practice 2]

**Research conducted**:
- [Link to research]

## Action Items

**High Priority** (address in next 1-2 sprints):
- [ ] [Action item 1]
- [ ] [Action item 2]

**Medium Priority** (address in next month):
- [ ] [Action item 1]

**Low Priority** (consider for future):
- [ ] [Action item 1]

## Next Retrospective

**Suggested trigger**: [5-10 features / 14 days / milestone]
**Estimated date**: [YYYY-MM-DD]

---

**Note**: This retrospective was agent-generated. Human review and prioritization recommended.
```

## Agent Workflow for Retrospective

### Phase 1: Propose Retrospective (1 min)

When trigger is met:

```
🔍 **Project Retrospective Suggested**

It's been [14 days / 10 features shipped] since the last retrospective.

I can perform a comprehensive project health check covering:
- Testing strategy and tools
- Specification quality
- Architecture evolution
- Development workflow
- Innovation opportunities

This will take approximately 50 minutes and includes:
- Running automated health checks
- Reviewing specs and code
- Identifying areas needing deeper research
- Generating actionable recommendations

**If deeper research is needed** (e.g., major framework updates, architecture decisions), I can enter **Research Mode** (30-90 min per topic) to:
- Thoroughly investigate new developments
- Compare alternatives
- Analyze best practices
- Create detailed research documents

**Would you like me to proceed?**

Options:
1. Yes, run full retrospective now (may identify research needs)
2. Yes, but skip deeper research suggestions (faster, ~20 min)
3. No, remind me in [X days / Y features]
4. No, disable automatic suggestions
```

### Phase 2: Execute Retrospective (20-50 min)

If approved, work through checklist systematically:

1. **Run tools** → Note results
2. **Review each area** → Research if needed → Document findings
3. **Generate report** → Save to `docs/retrospectives/`
4. **Update tracking** → Record in JOURNAL.md

### Phase 3: Present Results (5 min)

```
✅ **Retrospective Complete**

Report saved: docs/retrospectives/RETRO-2026-01-15.md

**Quick Summary**:
- Health: [Overall status]
- High priority actions: [N]
- Research needs identified: [N topics]

**Top 3 Recommendations**:
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

**Research Topics Identified**:
- HIGH: [Framework] v2.0 migration assessment (60 min research suggested)
- MED: Testing performance optimization strategies (30 min)

**Would you like me to:**
1. Enter Research Mode for high-priority topics now
2. Implement high-priority recommendations (no additional research)
3. Create tasks for action items (add to spec/tasks/)
4. Just review the report (no action yet)
```

## Tracking Retrospectives

### In STATUS.md

Add section:

```markdown
## Retrospectives
- Last retrospective: YYYY-MM-DD (RETRO-2026-01-15.md)
- Next suggested: YYYY-MM-DD (or after [N] more features)
- Action items from last retro: [X completed] / [Y total]
```

### In JOURNAL.md

Log retrospective sessions:

```markdown
## Session: 2026-01-15-1000 (Retrospective)
- Type: Project Retrospective
- Trigger: 14 days since last retro
- Duration: 45 minutes
- Accomplished:
  - Ran automated health checks
  - Reviewed testing strategy (researched vitest v2)
  - Reviewed specs (found 3 stale features)
  - Generated 8 actionable recommendations
- High-priority actions:
  - Upgrade to vitest v2 for better performance
  - Add missing integration tests for F-0042
  - Archive 3 deprecated features
- Next retrospective: 2026-01-29 or after 10 more features
```

## Configuration

### Enable/Disable in STACK.md

```markdown
## Retrospectives (optional)
- retrospective_enabled: yes
- retrospective_trigger: time  # time | features | both
- retrospective_interval_days: 14
- retrospective_interval_features: 10
- retrospective_depth: full  # full (with research) | quick (no research)
```

### Agent Checks Configuration

Agent reads `STACK.md` for settings and `STATUS.md` for last retrospective date.

## Example Retrospective Triggers

### Time-based

```python
# Agent logic (pseudocode)
last_retro_date = parse(STATUS.md "Last retrospective")
days_since = today - last_retro_date
interval_days = STACK.md "retrospective_interval_days" or 14

if days_since >= interval_days:
    suggest_retrospective("time-based", days_since)
```

### Feature-based

```python
# Agent logic (pseudocode)
last_retro_features = STATUS.md "Last retrospective features shipped"
current_features = count(FEATURES.md where status == "shipped")
features_since = current_features - last_retro_features
interval_features = STACK.md "retrospective_interval_features" or 10

if features_since >= interval_features:
    suggest_retrospective("feature-based", features_since)
```

## Benefits

✅ **Proactive improvement**: Don't wait for problems to accumulate  
✅ **Research built-in**: Agent investigates current best practices  
✅ **Structured review**: Comprehensive checklist ensures nothing is missed  
✅ **Actionable output**: Clear recommendations with priorities  
✅ **Knowledge capture**: Research findings documented for future reference  
✅ **Token-efficient**: Periodic investment prevents larger fixes later

## Human Involvement

**Agent proposes** → **Human approves** → **Agent executes** → **Human prioritizes actions**

The agent never makes changes without approval, only generates recommendations.

## See Also

- Health checks: `.agentic/tools/doctor.py`, `verify.sh`
- Scaling guidance: `.agentic/workflows/scaling_guidance.md`
- Development loop: `.agentic/workflows/dev_loop.md`, `tdd_mode.md`

