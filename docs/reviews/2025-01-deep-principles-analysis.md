# Complete Framework Principles - Deep Analysis

## From ENTIRE Conversation (Chronological)

### Phase 1: Initial Critical Review & Foundation
**User Request**: Critical review to improve support for complex, avant-garde, technically demanding software

#### Principles Established:
1. **Token Economics as First-Class Concern**
   - Durable artifacts prevent repeated re-reading (CONTEXT_PACK, STATUS, JOURNAL)
   - Structured reading protocols (10-15K token budgets)
   - Summarize instead of scrolling
   - "Context is expensive" - core principle

2. **Developer-Friendliness Over Agent Convenience**
   - Humans define WHAT, agents handle HOW
   - Clear project status at all times
   - Easy to understand current state without asking agent
   - Humans can read/edit specs directly (not hidden from humans)

3. **Quality Outcome Focus**
   - Tests mandatory for new/changed logic
   - Definition of done includes quality gates
   - Design for testability (seams, boundaries)
   - Small, reviewable increments

4. **Up-to-Date Documentation as Requirement**
   - Documentation updated in SAME COMMIT as code
   - No stale placeholders ("(Not yet created)" gets replaced)
   - STATUS.md and FEATURES.md match reality
   - Architecture decisions recorded (ADRs)

5. **Iterative Development with Clear Specs**
   - Specs are living documents
   - Clear acceptance criteria before coding
   - Feature IDs (F-####) provide stable references
   - Traceability from requirements → code → tests

### Phase 2: Agent Partnership & Collaboration
**Key Discussion**: Humans AND agents can edit specs

#### Principles Established:
6. **Agent Partnership, Not Agent-Only**
   - Humans can directly edit FEATURES.md
   - Humans can add acceptance criteria
   - Agents MUST honor human spec edits
   - Specs are VISIBLE (not hidden in .agentic/)
   - "Human-machine team" not "agent-driven team"

7. **Explicit Over Implicit**
   - Clear documentation structure (spec schema)
   - Format specifications prevent accidental changes
   - Version indicators in templates
   - No magical behavior - everything documented

### Phase 3: TDD & Quality Automation
**Key Discussions**: TDD as default, continuous quality validation

#### Principles Established:
8. **Test-Driven Development as Default**
   - TDD is RECOMMENDED (not just option)
   - Better token economics (smaller increments, clearer progress)
   - Forces testability by design
   - Red-green-refactor cycle

9. **Stack-Specific Quality Over Generic Tests**
   - Audio plugins need pluginval, DSP validation
   - Web apps need Lighthouse, bundle size, a11y
   - Each technology has unique failure modes
   - Quality profiles match tech stack

10. **Automated Validation Before Commits**
    - quality_checks.sh runs automatically
    - Pre-commit hooks catch issues early
    - Stack-specific checks catch real problems
    - "Fail fast" philosophy

### Phase 4: Retrospectives & Research
**Key Discussion**: Automated project health checks

#### Principles Established:
11. **Continuous Improvement Through Retrospectives**
    - Periodic health checks (time-based or feature-based)
    - Agent-led but human-approved
    - Update quality checks based on bugs found
    - Framework evolves with project

12. **Research Mode for Complex Decisions**
    - Deep investigation before implementation
    - Document findings for future reference
    - Compare options (pros/cons)
    - Recommend or escalate to human

13. **Documentation Verification**
    - Agents must use correct version of docs
    - Never assume API exists without checking
    - Context7 integration for version-specific docs
    - "NEVER assume" - verify first

### Phase 5: Multi-Agent & Scaling
**Key Discussions**: Sequential agents, multi-agent coordination

#### Principles Established:
14. **Sequential Specialization for Context Efficiency**
    - Research Agent (30K tokens) → Planning (40K) → Test (35K) → Impl (45K)
    - Each agent focuses on expertise
    - Clear handoffs between agents
    - Total context < single general agent

15. **PR Mode for Team Collaboration**
    - Optional PR workflow
    - Human review required (no auto-merge)
    - CI checks before suggesting merge
    - Supports team development

16. **Multi-Agent Coordination**
    - Multiple agents work in parallel
    - Git worktrees for isolation
    - AGENTS_ACTIVE.md for coordination
    - File lock protocol prevents conflicts

### Phase 6: Modularity & Flexibility
**Key Discussions**: Core vs Core+PM profiles

#### Principles Established:
17. **Modularity Over Monolith**
    - Core profile: Minimal ceremony, essential features
    - Core+PM profile: Add formal tracking when needed
    - "Not for smaller coding projects" - explicit use cases
    - Can upgrade Core → Core+PM anytime

18. **Opt-In Complexity**
    - Start simple (Core), add features later
    - Sequential pipeline: optional
    - Retrospectives: optional
    - Research mode: optional
    - "Enable after reviewing workflow"

19. **Product Management Features Are Separate**
    - OVERVIEW.md for Core (lightweight)
    - spec/ and STATUS.md for Core+PM (formal)
    - Different workflows for different needs
    - enable-product-management.sh for upgrade

### Phase 7: Framework Versioning & Upgrades
**Key Discussion**: Framework version tracking, upgrade mechanism

#### Principles Established:
20. **Version Tracking**
    - Every project knows framework version
    - Stored in STACK.md
    - Helps with troubleshooting
    - Enables upgrade path

21. **Safe Upgrade Path**
    - Run upgrade.sh FROM new framework (not old)
    - Upgrade script is always latest version
    - Projects can upgrade to new framework
    - No abandoned projects on old versions

22. **GitHub Releases for Distribution**
    - Semantic versioning (0.1.0, 0.2.0, etc.)
    - CHANGELOG.md documents all changes
    - Release packages via GitHub
    - Clear version history

### Phase 8: Hidden Framework, Visible Product
**Key Discussion**: agentic/ → .agentic/

#### Principles Established:
23. **Framework Internals Are Hidden**
    - .agentic/ hidden folder
    - Cleaner project root
    - Framework doesn't clutter user's repo
    - BUT: critical files remain visible

24. **Product Information Stays Visible**
    - STATUS.md, JOURNAL.md, CONTEXT_PACK.md in root
    - spec/ visible (it's product documentation)
    - docs/ visible (product documentation)
    - "Optimize for agent work without hiding product info"

### Phase 9: User Workflows & Direct Editing
**Key Documentation**: USER_WORKFLOWS.md

#### Principles Established:
25. **Humans Can Edit Specs Directly**
    - Edit FEATURES.md yourself
    - Create acceptance files yourself
    - Update priorities in STATUS.md
    - Agents pick up your changes reliably

26. **Two Ways to Add Features**
    - Option 1: Edit spec yourself (faster!)
    - Option 2: Ask agent to add it
    - Both work reliably
    - Humans have choice

27. **Clear Workflows for Common Tasks**
    - Adding features documented
    - Updating specs documented
    - Working with agents documented
    - No guessing required

### Phase 10: Documentation Standards
**Key Discussion**: Format validation, schema

#### Principles Established:
28. **Spec Schema Enforces Consistency**
    - Valid status values (planned, in_progress, shipped)
    - Required fields defined
    - Cross-reference formats specified
    - Humans and agents follow same schema

29. **Format Validation Prevents Drift**
    - YAML frontmatter in specs
    - Format version indicators
    - validate_specs.py checks structure
    - Three levels: Strict, Structured, Free-form

30. **Format Versions Allow Evolution**
    - <!-- format: stack-v0.1.0 --> in templates
    - Can update format without breaking old projects
    - Non-intrusive version indicators
    - Future-proof

### Phase 11: Programming & Testing Standards
**Key Discussion**: Quality and maintainable code

#### Principles Established:
31. **Clear Programming Standards**
    - Descriptive names (no cryptic abbreviations)
    - Small functions (<50 lines ideal)
    - Explicit error handling (fail fast)
    - Avoid magic numbers
    - Avoid deep nesting (<4 levels)

32. **Comprehensive Testing Standards**
    - Happy path + edge cases
    - Invalid input + time-based errors
    - Concurrency + resource exhaustion
    - Network failures + security
    - NOT "just basic tests"

33. **Security & Performance by Default**
    - Secure code patterns documented
    - Efficient code (but not simplistic)
    - Green coding principles
    - Caching when appropriate (not always first)

### Phase 12: Build & Deploy Agents
**Key Discussion**: Specialized agents for build and deploy

#### Principles Established:
34. **Build Agent for Verification**
    - Verify build/bundle/compile after implementation
    - Catch build issues before commit
    - Platform-specific build checks
    - Part of sequential pipeline

35. **Deploy Agent for Automation**
    - Deploy to staging/production
    - Triggered by PR merge or manual
    - Automated but with guardrails
    - Optional (not all projects need)

### Phase 13: Mutation Testing
**Key Discussion**: Advanced test quality

#### Principles Established:
36. **Mutation Testing for Critical Code**
    - Verify tests catch real bugs
    - Use for critical business logic
    - Optional advanced quality check
    - 80%+ score = strong test suite

37. **Selective, Not Universal**
    - Don't mutation test everything
    - Focus on high-value functions
    - Use after fixing bugs tests didn't catch
    - Cost-benefit consideration

### Phase 14: Profiles & Modularity
**Key Discussion**: Making framework less intimidating

#### Principles Established:
38. **Core Features Always Available**
    - Quality standards: always
    - Multi-agent: always
    - Research mode: always
    - OVERVIEW.md: always in Core

39. **Product Management Features Optional**
    - Specs (F-####): only in Core+PM
    - Feature tracking: only in Core+PM
    - STATUS.md: only in Core+PM
    - Sequential pipeline: only in Core+PM

40. **Easy to Upgrade**
    - enable-product-management.sh
    - Detects OVERVIEW.md, converts to specs
    - All framework files always present
    - Agent helps with migration

### Phase 15: Example Projects
**Key Discussion**: Real examples showing framework

#### Principles Established:
41. **Examples Must Work**
    - Run scripts, generate reports
    - Store output for demo
    - Link to outputs in READMEs
    - Not just placeholder code

42. **Examples Show Different Profiles**
    - Core example (todo CLI)
    - Core+PM example (taskboard)
    - Different technologies
    - Real implementations

### Phase 16: Today's Additions (Most Recent)

#### Principles from Recent Work:
43. **Single Source of Truth for Documentation**
    - Script explanations: ONE place (DEVELOPER_GUIDE)
    - Command tables: ONE place (DEVELOPER_GUIDE)
    - Update in 1 place, not 3
    - Cross-references instead of duplication

44. **Acceptance Files Are MANDATORY**
    - NEVER define feature without acceptance file
    - Agents MUST create it immediately
    - If unclear, escalate to HUMAN_NEEDED.md
    - "How do we know when done is done?"

45. **Shipped ≠ Accepted Distinction**
    - Shipped = code complete, tests pass, committed
    - Accepted = human validated it works
    - Both states tracked in FEATURES.md
    - Human validation is final gate

46. **Implementation State Must Match Reality**
    - NEVER `State: none` if code exists
    - Change to `partial` or `complete` when adding code
    - Check EVERY time updating FEATURES.md
    - Prevents confusion about what's implemented

47. **Maintainability Over Cleverness**
    - Simple, clear code > complex "smart" code
    - Future you needs to understand it
    - New agents need to maintain it
    - Long-term > short-term optimization

48. **Easy Choices Reduce Friction**
    - a/b profile selection
    - Clear options presented
    - Single-letter choice
    - No analysis paralysis

49. **Documentation Must Reflect Reality**
    - Test workflows in example projects
    - Verify scripts actually work
    - Fix broken instructions immediately
    - Accurate > complete

50. **Profile Descriptions Must Be Honest**
    - Not "recommended for most" if it's not
    - Clear use cases for each profile
    - Core for simple, Core+PM for complex
    - External PM tools are valid approach

## Implicit Meta-Principles (The "How We Decide")

### 51. **User Feedback Drives Evolution**
- Listen to real usage problems
- Fix confusing docs immediately
- Admit when something doesn't work
- Iterate based on actual experience

### 52. **Break Old Projects If Needed**
- "Breaking older projects...is not a problem now"
- Get it right > maintain backward compat (while building)
- Will add versioning later
- Framework quality > project stability (during development)

### 53. **Ask Clarifying Questions**
- "would it be more logical..."
- "I wonder if..."
- "can we separate this..."
- Propose, don't assume

### 54. **Optimize for Long-Term Maintainability**
- "everything should be as clear as possible"
- "working as reliably as possible in the LONG RUN"
- Refactor when duplication is found
- Single source of truth

### 55. **Agents Should Work Efficiently**
- "optimize the agentic work"
- Don't hide things if it breaks agent knowing what to do
- Token economics matter
- Context efficiency is feature

### 56. **Humans and Agents Are Partners**
- Not "agent-driven" development
- Humans can work manually OR with agents
- Specs are human-readable
- Both parties contribute

### 57. **Fail Fast with Clear Errors**
- doctor.py reports specific issues
- verify.sh shows what's wrong
- Error messages are actionable
- No silent failures

### 58. **Progressive Disclosure of Complexity**
- Start simple (Core)
- Add features when needed (Core+PM)
- Optional advanced features (mutation testing, research mode)
- Don't overwhelm beginners

### 59. **Examples Are First-Class Citizens**
- Example projects maintained
- Examples demonstrate best practices
- Examples verify workflows work
- Examples are documentation

### 60. **Framework Should Be Self-Documenting**
- DEVELOPER_GUIDE for comprehensive reference
- START_HERE for navigation
- MANUAL_OPERATIONS for quick tasks
- USER_WORKFLOWS for agent collaboration
- Each doc has clear purpose

## The Missing "Why"

### What's NOT in Current Docs:

1. **Why token economics?**
   - Not just cost - also enables longer projects
   - Context resets would kill projects without durable artifacts
   - Enables solo developer + AI to build complex software

2. **Why human-agent partnership?**
   - Humans have domain knowledge AI lacks
   - AI has execution speed humans lack
   - Together > either alone
   - Specs are the collaboration interface

3. **Why mandatory acceptance files?**
   - Test project showed: "shipped" but no validation
   - How do you know when feature is actually done?
   - Human validation is irreplaceable
   - Tests pass ≠ solves user problem

4. **Why single source of truth for docs?**
   - Update in 3 places = errors
   - Maintenance burden kills long-term projects
   - Clear "authoritative" source needed
   - DRY applies to documentation too

5. **Why shipped ≠ accepted?**
   - Code complete ≠ user validated
   - Final gate is human approval
   - Prevents "works on my machine" syndrome
   - Clear audit trail of validation

6. **Why stack-specific quality?**
   - Audio plugins: NaN/Inf values crash systems
   - Web apps: Memory leaks, poor a11y
   - Each domain has specific failure modes
   - Generic tests miss domain-specific bugs

7. **Why modularity (Core vs Core+PM)?**
   - Small projects don't need heavyweight PM
   - External PM tools (Jira, Linear) are valid
   - Don't force decisions upfront
   - Can upgrade when project grows

8. **Why TDD as default?**
   - Better token economics (smaller increments)
   - Forces testability (cleaner code)
   - Clear stopping points (each passing test)
   - Less rework (catch issues early)

9. **Why sequential agents?**
   - Research doesn't need implementation code (30K vs 200K tokens)
   - Planning doesn't need test details
   - Each agent optimized for its task
   - Total context < general agent

10. **Why PR mode optional?**
    - Solo developers don't need PRs
    - Teams need code review
    - Adds overhead for simple projects
    - Optional = flexibility

## Summary: The Core Philosophy

**Sustainable Long-Term AI-Assisted Development**

This isn't about:
- Making AI do everything
- Replacing developers
- Clever automation tricks
- Maximum AI autonomy

This IS about:
- **Partnership**: Humans + AI working together effectively
- **Sustainability**: Projects that survive months/years of development
- **Context Efficiency**: Making limited context windows work for complex software
- **Quality**: Shipping working, tested, maintainable code
- **Clarity**: Always knowing project state
- **Flexibility**: Adapting framework to project needs
- **Maintainability**: Code and docs that future-you can understand
- **Reality**: Documentation and workflows that actually work

**The Unstated Assumption**: Complex software takes months/years. Framework must support long-term development, context resets, team changes, and evolving requirements. Not optimized for quick prototypes - optimized for shipping and maintaining real products.

