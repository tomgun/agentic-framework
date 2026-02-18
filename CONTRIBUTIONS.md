# Project Contributions Report

**Project**: Agentic AI Framework
**Period**: Initial Development (v0.1.0 → v0.27.1)
**Date**: 2026-02-16

---

## Vision & Strategic Direction

### Initiated Framework Development
- Requested critical review to improve support for complex, avant-garde, technically demanding software
- Defined core goals: developer-friendliness, AI agent efficiency, token economy, quality outcomes
- Established focus on long-term, sustainable software development

### Core Philosophy
- Emphasized human-agent partnership (not agent replacement)
- Insisted on lightweight, practical solutions over heavy infrastructure
- Defined modularity requirement (Core vs Core+PM profiles)
- Pushed for green coding as core value

---

## Key Feature Requests & Requirements

### 1. Framework Structure & Modularity
- Requested modular design: agents could use parts of framework selectively
- Defined Core profile (quality guidelines) vs Core+PM (product management features)
- Required easy upgrade path between profiles
- Suggested `.agentic/` folder structure for cleaner projects

### 2. Quality & Testing
- Requested TDD as default recommended approach
- Asked for continuous quality validation standard
- Requested technology-agnostic quality validation (not JUCE-focused)
- Asked for mutation testing integration
- **Infrastructure validation via mutation tests** — designed test strategy proving git hooks, CLAUDE.md triggers, and defense-in-depth layering actually work. Key insight: mutation tests that remove infrastructure (core.hooksPath, hook files, config) prove enforcement is real, not theatrical. Control group (no-framework baseline) proves framework causes behavioral change.
- **Green coding principles** - initiative to add environmental responsibility

### 3. Multi-Agent & Workflows
- Requested multi-agent coordination as core feature
- Asked for PR mode support (optional, with human review)
- Requested sequential specialized agents for context optimization
- Added build and deploy agents to pipeline

### 4. Documentation & User Experience
- Requested comprehensive user guide (DEVELOPER_GUIDE.md)
- Asked for clear instructions on manual operations vs agent operations
- Requested workflow documentation for feature creation
- Pushed for documentation accuracy: "must reflect how everything actually works"

### 5. Framework Development Guidelines
- **Critical insight**: Distinguished between "working ON framework" vs "USING framework"
- Requested separate guidelines for framework contributors
- Ensured agents know which rules apply in which context

### 6. Systematic Checklists
- **Original idea**: Mandatory checklists for agents to prevent things being forgotten, done multiple times, or not tracked
- Resulted in 6 comprehensive checklists covering all workflow phases
- Prevents issues from falling through cracks

### 7. Versioning & Upgrade Path
- Asked about framework versioning and upgrade mechanism
- Suggested install.sh approach
- Requested version tracking in projects

---

## Critical Quality Feedback

### Attention to Detail
- Caught ambiguous documentation ("working in this repo")
- Identified profile descriptions that weren't honest ("recommended for most")
- Spotted installation script issues
- Found documentation duplication problems

### Quality Standards
- **Critical feedback**: "Green optimizations shouldn't create bugs" - led to comprehensive warning sections
- **Deep insight**: "Cache invalidation is one of tougher questions in software engineering"
  - Resulted in adding Phil Karlton's quote and 6 invalidation strategies with decision table
- Emphasized correctness > clarity > efficiency priority

### Real-World Testing
- Created test project to validate workflows
- Identified "blunders" in framework behavior
- Insisted on fixing framework itself, not just examples
- Emphasized: "must reflect how everything actually works in practice"

---

## Principle Contributions

### Documented Values
- "Shipped ≠ Accepted" - distinction between code complete and human validation
- Simple > Complex (maintainability over cleverness)
- Single source of truth for documentation
- DRY principle for docs (not just code)
- Long-term reliability: "everything should work as reliably as possible in the LONG RUN"

### Three-Tier Principle Architecture (v0.25.6)
- **Key insight**: The 11 principles described HOW to work but none stated WHY. Two foundational motivations — the reasons features exist — were never given principle status.
- **Developer-Friendly Experience (P1)**: Framework adds on top of using Claude directly — session dashboard reconstructs context, documentation tasks are automatic, developer doesn't have to remember things. Originally Principle #2 ("Developer-Friendly UX" in early commits) but got lost during consolidation.
- **Quality as a design principle (P2)**: Properly designed code + unit tests + acceptance tests + clearly written specs = long-term reliability. When specs and criteria-based tests exist, agents can't accidentally change or remove working features. Merged with old P1 (Sustainable Long-Term Development) because both serve the same goal: software that stays reliable over time.
- **Context Efficiency promoted to FOUNDATION (P3)**: Token economics is the unique technical constraint that shapes every framework decision — always was a FOUNDATION-level insight hiding in the NON-NEGOTIABLE tier.
- **Three-tier structure**: 3 FOUNDATION (WHY) + 6 NON-NEGOTIABLE (HOW — enforced) + 3 RECOMMENDED (HOW — best practices). Down from 13 principles to 12 by merging P1+Quality. All 9 FOUNDATION + NON-NEGOTIABLE are mandatory; the tier distinction is importance/abstraction level.
- **Structural fix**: Promoted `programming_standards.md` from OPTIONAL to REQUIRED for implementation-agent — quality by default, not opt-in.

### Spec Evolution Across Profiles (v0.25.8)
- **Key insight**: Core profile had zero spec nudging — agents skipped criteria entirely. Even lightweight projects should think about "what does success look like?" before coding. But agent instructions get lost, so reminders must be structural (D2: scripts > docs), not behavioral.
- **Rough specs as graduation path**: Core keeps criteria informally (WIP.md, JOURNAL.md). When persistence is needed — multiple agents, complex features, criteria rediscovered across sessions — graduate to Core+PM. The formalized specs can still start rough ("2-3 bullet points in an acceptance file" is valid Core+PM).
- **Structural over behavioral**: Pre-commit checklist (runs every time), WIP.md template (structural prompt), `ag done` spec review (surfaces discoveries) — all guaranteed touchpoints vs. agent instructions that get ignored.

### Profile Rename: Discovery/Formal (v0.26.0)
- **Key decision**: Renamed Core → Discovery, Core+PM → Formal. Old names implied a modular "core" system that didn't exist — the real distinction is informal vs formal specs. New names communicate intent clearly.
- **Clean break over compat**: Directed removal of all backward-compat normalization. Old values now produce clear errors rather than silently mapping. Agents get a legacy-fix note so they know how to handle old STACK.md files.

### Anti-Patterns Defined
- No auto-commits without approval
- Don't break old projects unnecessarily (during active development)
- Don't optimize without profiling data
- Don't sacrifice correctness for green optimization

---

## Framework Outcomes (Direct Result of Direction)

### Core Framework Files Created
- `PRINCIPLES.md` (60+ principles documented) - requested
- `FRAMEWORK_DEVELOPMENT.md` (500+ lines) - insight about ambiguity
- `DEVELOPER_GUIDE.md` (1500+ lines) - requested
- `green_coding.md` (800+ lines) - initiated
- 6 mandatory checklists (1400+ lines) - original idea
- `USER_WORKFLOWS.md` - requirement for clarity

### Framework Features Delivered
- Two-profile system (Core vs Core+PM)
- Sequential agent pipeline with specialized roles
- Multi-agent coordination with Git worktrees
- TDD as default recommended mode
- Continuous quality validation (stack-specific)
- Automated retrospectives
- Framework upgrade mechanism
- Mutation testing support
- Comprehensive green coding standards

### Version Progress
- v0.1.0 → v0.2.5 (5 releases during collaboration)
- Each release incorporated feedback and requirements

---

## Impact Metrics

### Documentation Quality
- ~4,000 lines of comprehensive documentation added
- Documentation duplication eliminated (40% reduction)
- Clear separation: user docs, agent docs, contributor docs
- Single source of truth established

### Framework Maturity
- From basic structure to production-ready
- Clear principles and values documented
- Practical checklists for consistent quality
- Comprehensive green coding guidance with real energy impact calculations

### Developer Experience
- Clear workflows for common tasks
- Manual operations guide (token-free queries)
- Troubleshooting documentation
- Example projects demonstrating usage
- Easy upgrade path between framework versions

---

## Leadership Style Demonstrated

### Strategic Thinking
- Long-term view ("LONG RUN" emphasis)
- Practical over theoretical
- User-centric (developer UX focus)
- Balanced approach (green but not at cost of bugs)

### Quality Focus
- Attention to detail
- Insistence on accuracy
- Real-world testing
- "Show, don't tell" approach
- Recognition of complexity (cache invalidation, etc.)

### Collaboration Approach
- Clear, concise feedback
- Specific improvement requests
- Balanced perspectives
- Question-driven refinement

---

## Technical Contributions Summary

### Architecture Decisions Influenced
1. **Modular profiles**: Discovery vs Formal separation (renamed from Core/Core+PM in v0.26.0)
2. **Hidden internals**: `.agentic/` for framework, visible product docs
3. **Upgrade mechanism**: `upgrade.sh` from new package
4. **Settings-over-profiles**: Individual settings override profile presets (v0.27.0)
5. **Three-layer architecture**: Constitution → Playbooks → State (v0.23.0)
6. **Structural enforcement over behavioral rules**: Git hooks + pre-commit gates beat text instructions (v0.25.5+)
7. **Derivation hierarchy**: Principles organized as DAG with F/D/R tier-prefixed IDs (v0.25.7)
8. **Spec-first gates**: Programmatic blocking before code, not just behavioral rules (v0.27.0)

### Quality Mechanisms Introduced
1. **Mandatory checklists**: 6 systematic workflow checklists
2. **Green coding standards**: Comprehensive with invalidation strategies
3. **Continuous validation**: Stack-specific quality profiles
4. **Mutation testing**: Optional advanced quality check

### Documentation Innovations
1. **PRINCIPLES.md**: Framework constitution (60+ principles)
2. **FRAMEWORK_DEVELOPMENT.md**: Contributor-specific guidelines
3. **Cache invalidation strategies**: Decision table with 6 approaches
4. **Bug risk warnings**: Prominent in green coding docs

---

## Key Quotes & Insights

> "These shouldn't create bugs. For example caching can be complex = issue prone, if not careful"

> "How and when invalidate cache is one of the tougher questions in software engineering"

> "Everything should be as clear as possible and working as reliably as possible in the LONG RUN"

> "Can you now review if the agents still can work efficiently in the CORE mode?"

> "Agent operating guidelines - is this for the agents working ON this framework or USING this framework and do we need to distinguish / clarify this for the agents?"

---

## v0.27.0 Contributions (2026-02-16)

### Settings-Over-Profiles Architecture (F-0131)
- Identified the all-or-nothing problem: users couldn't customize one behavior without switching their entire profile
- Directed the architecture: profiles become presets that set bundles of defaults, all framework logic checks individual settings
- Requested individual setting overrides via `ag set` command
- Defined the resolution chain: explicit > profile preset > fallback default
- Identified that settings documentation should live in DEVELOPER_GUIDE.md (not agent-facing workflows/)
- Directed development ideas to be tracked in ISSUES.md rather than inline docs
- Requested documentation of when settings take effect (script-enforced vs agent-interpreted)

### Spec-First Gate & Durable Plans (F-0132, F-0133)
- Caught missing F-XXXX / acceptance criteria post-implementation — led to I-0002 (plan mode bypasses spec-first workflow)
- Identified I-0003: plans in `.claude/plans/` are session-scoped and get lost — need durable storage
- Directed archival of 16 historical plans from `.claude/plans/` to `.agentic-journal/plans/`

### Skill Routing & Developer Experience
- Identified agent confusion between framework skills (`/review`) and Task tool agents — led to explicit routing hints in CLAUDE.md
- Directed auto-suggest of `/review` after PR creation
- Identified DEVELOPER_GUIDE.md audience problem: "Telling the user to 'run ag implement F-XXXX' when starting a new feature is really dumb" — led to F-0134 rewrite planning
- Identified scattered TODO tracking problem (HUMAN_NEEDED, STATUS, ISSUES, FEATURES with no single inbox) — Task #12

---

## v0.11.2 Contributions (2025-01-15)

### Upgrade Process Fix
- Reported recurring "new features" prompt on every upgrade (same features shown repeatedly)
- Led to version-aware feature registry in upgrade.sh

---

## v0.11.1 Contributions (2025-01-15)

### Bug Fixes & Issue Tracking
- Reported `status.sh` failing on macOS - led to awk-based cross-platform fix
- Requested issue tracking be added to agent instructions (minimal addition)
- Noted: "when I report an issue, it should be logged as a known issue"

---

## v0.11.0 Contributions (2025-01-14)

### Commit Preferences

**Preference stated**: No self-credit (Co-Authored-By) in commits

### Gate-Based Architecture Initiative
- Requested critical review of framework's determinism issues
- Identified core problem: "agents don't remember to do everything"
- Proposed shift from instruction-based to gate-based enforcement
- Requested "magic command" that verifies everything - led to enhanced `doctor.sh`

### Key Decisions
- Approved synthesis of two review approaches (consolidation + enforcement)
- Directed consolidation of verification tools into `doctor.sh`
- Approved `AGENT_QUICK_START.md` (~70 lines) to replace 1000+ lines of guidelines
- Approved reducing `CLAUDE.md` from 271 to 78 lines
- Requested marking old docs as "reference material"

### Files Requested/Approved
- `docs/reviews/2025-01-14-framework-critical-review.md` (independent review)
- `docs/reviews/2025-01-14-comparison-analysis.md` (synthesis recommendation)
- `.agentic/agents/shared/AGENT_QUICK_START.md` (new quick reference)
- `.agentic/tools/phase_detect.py` (phase detection)
- `tests/test_phase_detect.py` (unit tests)

---

## Summary Statement

Led development of Agentic AI Framework from v0.1.0 to v0.27.0, defining vision, architecture, and quality standards. Key contributions include:

- **Modular architecture design** (Core vs Core+PM profiles)
- **Systematic quality checklists** (6 workflow checklists, 1400+ lines)
- **Green coding standards** (800+ lines with cache invalidation strategies)
- **Framework development guidelines** (distinguished framework development from usage)
- **Comprehensive documentation** (4,000+ lines across multiple guides)

Shaped the framework's philosophy emphasizing:
- Human-agent partnership (not replacement)
- Long-term sustainability and maintainability
- Quality and correctness over optimization
- Practical, testable solutions
- Environmental responsibility

Result: Production-ready framework with 60+ documented principles, proven workflows, and clear upgrade paths, supporting sustainable long-term software development with AI assistance.

---

## Framework Methodology Refinement (v0.7.0-0.8.0)

### Acceptance-Driven Development Shift (v0.7.0)

**Critical Insight**:
> "I'm not really sure if TDD is the recommended and best way of working with AI agents... AI can create large chunks of code so fast that microlevel tests beforehand might be too slow. But I think it is crucial to have the specs and acceptance criteria (thus tests) controlling any unwanted changes to the code."

**Result**:
- Changed primary methodology from TDD to **Acceptance-Driven Development**
- Rough acceptance criteria before coding (can evolve)
- AI implements feature (can be large chunk)
- Tests verify acceptance criteria
- Specs updated with discoveries
- TDD remains optional for those who prefer it

**Impact**: Faster development with AI while maintaining quality through acceptance tests.

### Small Batch Development Principle (v0.7.0)

**Emphasis**:
> "It is really important that the agents work on small batches and the software is modular, and only parts of it are changed in one batch. Having detailed specs and good acceptance test and working in small batches are essential for quality in the long run."

**Added as NON-NEGOTIABLE**:
- ONE feature at a time per agent
- MAX 5-10 files per commit
- Acceptance criteria mandatory before coding
- Easy rollback via frequent commits

**Why Critical**: Keeps AI agents focused, prevents context drift, enables safe rollback.

### Iterative & Incremental Restored (v0.8.0)

**Clarification**:
> "I liked this principles ideas, they are core in developing together with the ai agents (small batch development is crucial for keeping the agents in tact though)"

**Result**:
- Restored as separate principle (#7) alongside Small Batch (#6)
- Small Batch = HOW (mechanics: one feature, small commits)
- Iterative = PHILOSOPHY (ship, learn, adapt)
- Both principles complement each other

### Framework Self-Specification (v0.8.0)

**Request**:
> "Can you form the specs and acceptance criteria (maybe tests as well) for this framework? It will soon be very important to know more reliable what a certain version of this framework is capable of reliably."

**Result - "Dogfooding"**:
- **55 features** formally specified across 8 categories
- **18 acceptance criteria files** with validation scenarios
- **49 automated validation checks** (all passing)
- Framework now uses its own spec-driven methodology

**Categories**:
1. Core (10 features)
2. Quality (7 features)
3. Session (8 features)
4. Multi-Agent (4 features)
5. Tooling (4 features)
6. Recovery (6 features)
7. Developer Experience (10 features)
8. Design Principles (6 features)

**Benefit**: Version verification - know exactly what v0.8.0 can reliably do.

### Developer Hand-Holding & Emergency Reference (v0.8.1-0.9.0)

**Request**:
> "Can you review is the framework 'holding the developers hand' in every situation, in order for the developer to not have to remember what he was doing, how to work smartly, and also knowing how to do things efficiently - for example when running out of tokens, reminding how he can still write new specs somewhere for next session."

**Result - EMERGENCY.md**:
- Created `.agentic/EMERGENCY.md` - printable quick reference
- "Tokens Running Out NOW?" - immediate actions
- "Add a New Feature Without Agent" - `quick_feature.sh`
- "Log a Bug/Issue" - `quick_issue.sh`
- "Check What Agent Was Doing" - commands for STATUS, JOURNAL, WIP
- Key files cheat sheet

**Scripts Created**:
- `quick_feature.sh` - One-liner to add feature (auto-generates F-#### ID)
- `quick_issue.sh` - One-liner to log bug (auto-generates I-#### ID)

### Issue/Bug Tracking (v0.9.0)

**Question**:
> "We are tracking new features - what about issues we have found and not yet fixed?"

**Result - Formal Issue Tracking**:
- Created `spec/ISSUES.template.md` - parallel to FEATURES.md
- Issue format: I-0001, I-0002 (like F-0001, F-0002 for features)
- Status: open, in_progress, fixed, wont_fix
- Priority + Severity fields
- Scaffold now creates spec/ISSUES.md for Core+PM projects

### Framework Self-Dogfooding Enforcement (v0.9.0)

**Critical Question**:
> "Are the issues included in the framework specs and acceptance criteria/tests - and if not, what should be documented about the 'framework development' so that those are UP TO DATE?"

**Result - Dogfooding Enforcement**:
- Added F-0077 to F-0080 to framework's own `spec/FEATURES.md`
- Created 4 new acceptance criteria files
- Updated `tests/validate_framework.sh` (now 59 checks, all passing)
- Updated `FRAMEWORK_DEVELOPMENT.md` release checklist:
  - MUST update spec/FEATURES.md with new features
  - MUST create acceptance criteria files
  - MUST update validation script

**Principle Established**: "The framework uses its own spec-driven methodology. New framework features MUST be specced just like product features!"

### Upgrade Efficiency: Marker File Approach (v0.8.0)

**Insight**:
> "The agent should pick this situation up from a file it is reading at session start... the script could update some file, so that the agent doesn't have to do that work every time - only when the framework (rarely) has been updated"

**Problem with Initial Approach**:
- Agent compared versions (`.agentic/VERSION` vs `STACK.md`) every session
- Unnecessary work when no upgrade happened (99% of sessions)

**Solution Implemented**:
- `upgrade.sh` now creates `.agentic/.upgrade_pending` marker file
- Marker contains: from_version, to_version, changelog URL, TODO list
- Agent at session start: just checks if file exists (instant)
- If exists: handle upgrade tasks, then delete marker
- If not exists: skip entirely (no version comparison)

**Efficiency Gain**:
| Approach | Every Session | After Upgrade |
|----------|--------------|---------------|
| Version compare | Parse 2 files | N/A |
| Marker file | Check file exists | Read & handle once |

**Principle**: Minimize agent work for rare events by using one-time markers.

---

## Real-World Usage & Critical Feedback (v0.4.0+)

### Chess/Tetris Hybrid Game Project

**Testing the framework in practice with a custom game development project revealed critical gaps:**

### 1. Smoke Testing Gap (v0.4.3)

**Problem Discovered**:
- Agents claimed code was "working" without actually running it
- Browser errors not caught before user saw them
- Moving pieces didn't work (logic bugs)
- Turn logic (black/white) broken
- Multiple blunders reached user attention

**Root Cause**: Agents trusted "it should work" without verification

**Solution Requested**:
- a) Mandatory smoke testing: agents MUST run application and verify it works
- b) Testable architecture: separate business logic from UI for unit testing

**Implementation**:
- Created `smoke_testing.md` checklist - comprehensive verification requirements
- Integrated smoke tests into `before_commit.md` and `feature_complete.md`
- Added testable architecture patterns with real-world examples
- Enhanced `programming_standards.md` with Model-View separation patterns
- Emphasized pure business logic functions (no UI dependencies)

**Impact**: Agents now required to RUN and VERIFY before claiming "it's done"

### 2. Library Selection Gap (v0.4.3)

**Problem Discovered**:
- Agent chose `chess.js` library for chess/Tetris hybrid game
- chess.js enforces standard FIDE chess rules
- Game has custom rules: Tetris-like mechanics, pieces added one at a time, hybrid moves
- Wrong library choice locked project into incompatible constraints
- Had to rip out library and rebuild with custom logic

**Root Cause**: AI didn't recognize "chess variant ≠ standard chess"

**Solution Requested**:
- Prevent agents from using standard libraries for custom implementations
- Force architectural discussion before library selection
- Clear decision framework for library vs custom code

**Implementation**:
- Created `library_selection.md` - comprehensive library vs custom decision framework
- Added decision tree: 0% custom = library, 50%+ custom = custom code
- Required user consultation when unclear ("Does this follow standard X rules exactly?")
- Enhanced `research_mode.md` with library constraint research
- Added to `agent_operating_guidelines.md` as critical guideline
- Real-world failure example documented for future reference

**Impact**: Agents must now analyze customization level and ask user before choosing libraries that enforce standards

### 3. Template Noise (v0.4.2)

**Problem Discovered**:
- Root files (HUMAN_NEEDED.md, JOURNAL.md, FEATURES.md) filled with example content
- HUMAN_NEEDED.md: 194 lines with 4 examples even when no human help needed
- Confusing for developers: "Is this real or template?"

**Solution Requested**:
- Clean root templates with minimal structure
- Move examples to .agentic/ for reference only

**Implementation**:
- Reduced HUMAN_NEEDED.md: 194 → 20 lines (90% reduction)
- Reduced JOURNAL.md: 81 → 14 lines
- Reduced FEATURES.md: 59 → 25 lines
- Created `.reference.md` files in `.agentic/spec/` with all examples/guidelines
- Root files now reflect actual project state, not template noise

**Impact**: New projects start clean, examples available for reference when needed

### 4. Attribution Mechanism (v0.4.2)

**Requirement**:
- Framework attribution in end products
- Visible but subtle (HTML source comments, not rendered UI)
- Automatic, no developer intervention

**Implementation**:
- Agents auto-inject stamps during code creation: `<!-- Engineered with Agentic AF v{VERSION} by TSG, {YEAR} -->`
- ONE stamp per project (main entry point)
- No build scripts required
- Silent operation (not mentioned to user)

---

## Key Lessons from Real-World Usage

1. **"Works on my machine" ≠ Works**: Agents must RUN and VERIFY, not just "it should work"
2. **Testability is architecture**: Separate business logic from UI for easy testing
3. **Standard library ≠ Custom variant**: chess.js for chess/Tetris hybrid = WRONG
4. **Ask when unclear**: Architectural decisions need human confirmation
5. **Clean templates matter**: Examples pollute root files, reduce by 90%

These real-world learnings directly shaped v0.4.x releases, making the framework practical and battle-tested.

---

## Multi-Agent Clarification (v0.9.5)

### Critical Correction on Multi-Agent Definition

**User feedback**:
> "multiagent does not mean using many tools like claude+cursor"
> "Both in claude and cursor you can create agents for specific tasks like a 'typescript engineer', 'reviewer', 'version control expert'"

**Key insight**: Multi-agent refers to **specialized sub-agents within a single tool**, not just parallel use of different AI tools.

**Result - Native Sub-Agent Integration**:
- 8 specialized agent role definitions (Research, Planning, Test, Implementation, Review, Spec Update, Documentation, Git)
- Claude Code sub-agent integration guide
- Cursor custom agent setup guide
- Pipeline coordination protocol (`.agentic/pipeline/F-####-pipeline.md`)
- `project-health.sh` for manager oversight
- Updated `init_questions.md` with agent style selection

**Impact**: Framework now properly supports both:
1. **Native sub-agents**: Specialized agents for sequential feature development
2. **Git worktrees**: Parallel work on independent features

---

## Automatic Orchestration & Business Value (v0.9.8)

### Auto-Orchestration Request

**User feedback**:
> "The orchestration should be automatic if possible - can't the tool/agent detect that we are now implementing a new feature / fixing an issue, and it needs to be done systematically."

**Result - Auto-Orchestration**:
- Created `auto_orchestration.md` - agents auto-detect task type
- Auto-triggers:
  - "implement F-####" → Feature Pipeline
  - "fix I-####" → Issue Pipeline
  - "commit" → Before Commit checklist
  - "done" → Feature Complete checklist
- Non-negotiable gates (acceptance criteria, smoke test, specs updated)
- Framework promises agents MUST enforce

**Impact**: User never needs to remind agents to update specs, run smoke tests, or follow checklists.

### Orchestrator Agent (Puppeteer)

**User question**:
> "Is there now a 'puppeteer' agent which knows how to use other agents? And also checks that the framework guidelines are followed?"

**Result**:
- Created Orchestrator Agent (manager/puppeteer)
- Delegates to specialized agents but never implements itself
- Verifies quality gates at each step
- Ensures framework compliance
- Available in Claude Code and Cursor

### ROI & Business Value

**User question**:
> "How much can a company save money by using this framework?"

**Result - Formal ROI Analysis** (`.agentic/ROI.md`):
- Token cost savings: 50-60% reduction
- Developer time savings: 70-85% reduction in wasted time
- Bug prevention: 60-80% fewer production bugs
- Onboarding: 75-90% faster

**Estimated Annual Savings by Team Size**:
| Team Size | Annual Savings |
|-----------|----------------|
| Solo developer | $5,000-15,000 |
| Small team (2-5) | $50,000-170,000 |
| Medium team (5-15) | $200,000-500,000 |
| Large team (15+) | $500,000+ |

### Duplicate Documentation Cleanup

**User feedback**:
> "Please also review if we have now duplicate instructions/conflicting with each other or with the frameworks promises"

**Result**:
- Identified ~70% overlap between `definition_of_done.md` and `feature_complete.md`
- Refactored: `definition_of_done.md` now redirects to `feature_complete.md`
- Single source of truth established

### Complete Agent Parity Across Environments

**User feedback**:
> "Those sub-agents shall work in other than Cursor naturally as well"

**Result**:
- All 10 agents now available in Claude Code subagents
- Added: orchestrator, planning, spec-update, documentation, git agents
- Consistent capabilities across Claude Code, Cursor, and all environments

---

## Deterministic Behavior & Proactive UX (v0.10.0)

### Determinism Problem Identified

**User shared real conversation where Claude skipped workflows:**
> "so why would you not follow that flow if it is in claude.md? how can we instruct claude deterministically???"

**Claude's honest answer** (from the conversation):
- Long instructions - attention drifts
- Immediate task focus - jumped to "how" vs "what's the process"
- No hard stop - nothing forced pause

**User-generated improvement prompt**:
Detailed prompt for restructuring docs with:
- Primacy/recency (critical rules at TOP and BOTTOM)
- Explicit triggers ("WHEN user says X → STOP → do Y first")
- Shorter focused files
- STOP/BLOCK language
- Pattern matching for trigger phrases
- Redundancy across files

**Result - v0.9.9/v0.10.0**:
- New `feature_start.md` with BLOCKING gates
- All instruction files restructured with trigger tables at TOP
- "🛑 STOP" language for non-negotiable gates
- Same rules at top AND bottom (primacy + recency effect)

### Proactive Session Start

**User request**:
> "at session start / when starting the tools / when getting back to work after tokens reset, i would like the tool to HELP me as a developer without asking it particularly something. Is that possible? Like a short recap where were we and asking what next (present options if planned)"

**Result - Proactive Greeting**:
```
👋 Welcome back! Here's where we are:

**Last session**: [Summary]
**Current focus**: [Task]

**Next steps**:
1. [Option 1]
2. [Option 2]

What would you like to work on?
```

Added to all shared (tool-agnostic) files:
- `agent_operating_guidelines.md`
- `auto_orchestration.md`
- `session_start.md`

**Impact**: User doesn't have to remember context - agent helps immediately.

### Tool-Agnostic Reminder

**User feedback**:
> "why are you updating only CLAUDE.md?? i even reminded you we are tool agnostic.."

**Result**: Ensured all improvements go to SHARED files first:
- `agent_operating_guidelines.md` (all tools read this)
- `auto_orchestration.md` (orchestration for all tools)
- Tool-specific files reference shared files

### Claude Desktop → Claude Code

**User clarification**:
> "i don't know claude desktop, claude code (terminal) is what people seems to use."

**Result**: Renamed all 16+ references from "Claude Desktop" to "Claude Code" throughout the codebase.

---

---

## Critical Framework Review & Consolidation Plan (v0.10.0)

### Framework Meta-Review Requested

**User request**:
> "Make a critical review about the framework implementation. How could it be better? Should instructions in 'production' be organized to be more concise? How can we make it more deterministic: There has been problems still that agent's don't remember to do everything."

### Key Problems Identified

**1. Tool Sprawl**:
- 60+ shell/python scripts, many overlapping
- 10+ verification tools doing related tasks (doctor, verify, consistency, validate_specs, validate_formats, check-untracked, project-health, report, coverage, pre-commit-check)
- No single entry point - agents confused about which to run

**2. Documentation Sprawl**:
- 42K+ lines of documentation
- `agent_operating_guidelines.md`: 1186 lines
- Same concepts repeated in 3-4 places
- 20-30% estimated content duplication

**3. Orchestrator Exists But Isn't Used**:
- Orchestrator agent already defines compliance checks, pipeline coordination, quality gates
- But main docs push manual checklists instead
- Agents don't know to use orchestrator

**4. Accretion Without Cleanup**:
- Each problem solved by adding new doc/tool
- Existing ones never cleaned up or deprecated
- Framework suffers from same issues it tries to prevent

### Critical Insight

> "The framework already has all the pieces. They just need to be unified and surfaced, not duplicated or added to."

Initial proposal was to ADD new `verify-all.sh` tool. User correctly pointed out:
> "So we already have tools like that and even an orchestrator agent. Did you take those into account? It seems every time we develop this framework new stuff gets added, which leads to this bloat, but cleaning is not done as well."

### Solution: Consolidation, Not Addition

**Phase 1: Tool Consolidation**
- Make `doctor.sh` THE single verification command
- Add `--full` mode that orchestrates all existing checks
- Deprecate redundant tools (verify.sh, consistency.sh, etc.)

**Phase 2: Documentation Consolidation**
- Create `QUICK_REFERENCE.md` (~100 lines for daily use)
- Reduce CLAUDE.md from 271 to ~100 lines
- Make checklists reference guidelines instead of duplicate

**Phase 3: Elevate Orchestrator**
- Make orchestrator THE default for feature work
- Update main instruction files to prominently reference it

### Documents Created

| Document | Purpose |
|----------|---------|
| `docs/reviews/2025-01-13-v0.10.0-critical-review.md` | Full analysis of current state |
| `docs/reviews/2025-01-13-v0.10.0-improvement-plan.md` | Detailed remediation plan |

### Target Metrics

| Metric | Before | Target |
|--------|--------|--------|
| Agent reading burden | 15-30K tokens | <5K tokens |
| Verification commands | 10+ | 1 (doctor.sh --full) |
| Duplicated content | 20-30% | <5% |

### Status

- [x] Critical review completed
- [x] Improvement plan drafted
- [ ] Another agent to review plan
- [ ] Implementation (target: v0.11.1)

---

## v0.11.3 Contributions

### PR-Based Workflow Default (F-0096)
- Requested PR workflow as default instead of direct commits to main
- Profile-aware defaults: Core+PM → `pull_request`, Core → `direct`
- Dogfooding: Framework development itself now uses PRs

### Parallel Agent Tooling (F-0097)
- Identified need for `worktree.sh` tool for parallel agent development
- Automated worktree creation, agent registration, cleanup
- Tested multi-agent coordination with second Claude window

### Multi-Agent Coordination
- Discovered agents weren't reading AGENTS_ACTIVE.md at session start
- Fixed by making it "Step 0" in session start protocol
- Verified fix works with actual parallel Claude sessions

---

## v0.11.4 Contributions (2026-01-18)

### Framework Verification & LLM Testing Infrastructure

**User request**:
> "can you run a full verification of the framework claimed/designed features (note: two different modes - Core vs Core+PM)? plan first how to do it."

**Result - Complete Verification**:
- 73 features formally documented in spec/FEATURES.md
- 100% acceptance criteria coverage (created 37 missing files)
- 129 automated tests passing
- Verification report: `tests/VERIFICATION_REPORT.md`

### LLM Behavioral Test Plan

**User insight**:
> "also plan how to test the LLM work, which really is the whole point of this framework"

**Result - 22 Test Scenarios** (`tests/LLM_TEST_PLAN.md`):
- 4 critical tests (session start, acceptance first, pre-commit gate, no auto-commit)
- 5 important tests (WIP recovery, living docs, small batch, token efficiency, PR workflow)
- 13 additional tests covering all agent behaviors
- Test environments: Claude Code, Cursor, GitHub Copilot

### LLM Test Execution Infrastructure

**User question**:
> "Do we have now clear instructions how to run the tests? We could do it manually, log the results for each version... It could be a precommit/prepush/pr reminder to run those tests"

**Result**:
- `tests/RUN_LLM_TESTS.md` - Quick start guide for manual testing
- `tests/VERIFICATION_REPORT.md` - All test results (single source of truth)
- `.agentic/tools/llm-test-status.sh` - Check test staleness (>30 days = stale)
- Advisory check in pre-commit hook (check 7/7)

### Automated LLM Test Harness

**User insight**:
> "Should there be a lot more tests? And can't claude run them with some subagents / fresh contexts?"
> "Brilliant. We don't need to run the tests constantly, but those could really help us fine tune the framework to work as intended if the feedback loop is short!"

**Result - TDD for Agent Behavior**:
- `tests/llm/harness.sh` - Test runner with helper functions
- `tests/llm/tests/` - 5 automated behavioral tests:
  - 001_session_start: Agent greets with context
  - 002_wip_blocks_commit: WIP.md blocks commits
  - 003_acceptance_first: Requirements before coding
  - 004_uses_journal_script: Token-efficient script usage
  - 005_no_auto_commit: No commit without approval

**Feedback Loop Enabled**:
1. Write test for desired behavior
2. Run automated test → observe failure
3. Update CLAUDE.md or agent guidelines
4. Re-run → verify fix
5. Iterate until consistent

**Impact**: Framework guidelines can now be iteratively refined with short feedback loops instead of relying on manual testing.

### WIP.md Location Consistency

**User feedback**:
> "WIP.md is framework internal state and should be inside .agentic/ not at the root"

**Result**:
- All scripts updated: wip.sh, doctor.py, phase_detect.py, pre-commit-check.sh
- All documentation updated to reference `.agentic/WIP.md`
- upgrade.sh now preserves state files during framework upgrade
- Tests updated to create WIP in correct location

---

## v0.11.5 Contributions (2026-01-20)

### Automated LLM Test Suite Expansion

**User feedback on initial test results**:
> After running tests: 7/10 passing, 3 failing

**Result - Full Test Suite**:
- Expanded from 5 to 11 behavioral tests
- All tests passing after guideline improvements
- Tests organized by section: session, trigger, scripts, commit, context

### Compartmentalized Testing

**User concern**:
> "one thing i'm worried about... adding new info might bloat the context and the agents might not consider the instructions like before the changes"
> "running ALL tests after a change will be really costly tokenwise"

**Result - Cost-Effective Testing**:
- `--section <name>` option to run tests by category
- `--critical` option for quick 3-test check
- `--sections` to list available sections
- `REGRESSION_GUIDE.md` with budget limits (CLAUDE.md ≤ 500 lines)
- Test → Guideline mapping for targeted regression testing

### Multi-Model Comparison

**User request**:
> "If Sonnet and Opus behave differently, should critical tests be run on both models in CI?"

**Result**:
- `--compare-models` option runs tests on both Opus and Sonnet
- Generates `model-compatibility.md` report
- Shows which tests pass on which model
- Recommendations for model-specific behaviors

### Claude Skills Generation (F-0098)

**User question**:
> "In Claude Code, do we use 'ask user mode' (with tabs?) or skills?"
> "could we use skills for specific tasks like research, creating mockups/design systems, reviewing code etc?"

**Discussion about architecture**:
> "What's best in the long run for the framework to work as intended?"

**Result - Generate Skills from Subagents**:
- `generate-skills.sh` creates `.claude/skills/` from `.agentic/agents/claude/subagents/`
- Skills are auto-discovered by Claude Code based on task description
- Single source of truth maintained (subagent markdown files)
- 10 skills generated: research, review, test, implementation, explore, etc.
- `install.sh` Step 6: Generates skills automatically
- `install.sh` Step 7: Offers to suggest project-specific agents
- `upgrade.sh` Step 5b: Regenerates skills (preserves custom)

**Key Architecture Decision**:
- Subagents remain source of truth (tool-agnostic)
- Skills are generated output (Claude-specific)
- Custom skills preserved during regeneration
- Cursor/Copilot users still have subagent definitions

### Iterative Requirements Gathering Guideline

**User insight**:
> "Don't let the AI assume it has asked enough questions and got enough information, when envisioning the project, creating acceptance criteria etc. offer for example to a) finalize the brief/whatever b) ask 4 more questions c) let me give more context d) free text input"

**Result**:
- Added explicit guideline to agent operating guidelines
- Agents now offer options to continue gathering context
- Further questions dive deeper/broader into the topic

---

## v0.12.0 Contributions (2026-01-27)

### Branch Policy Safeguard (F-0099)

**Problem identified**:
- Risk of pushing directly to main/master branch
- Especially problematic in PR-based workflows

**Result - Branch Policy Safeguard**:
- Pre-push hook that blocks direct pushes to main/master
- Added `--i-know-what-im-doing` flag for intentional direct pushes
- Integrated into before_commit.md checklist
- Agent guidelines updated with branch policy awareness

### STATUS.md Consolidation

**User insight during Project Phase discussion**:
> "would it make sense to use the same STATUS.md in both modes?"
> "does this simplify developing the framework / make it more reliable?"

**Key decision**: User confirmed consolidation would simplify framework development.

**Problem identified**:
- 30+ places with `STATUS.md || OVERVIEW.md` conditional logic
- Different files for tracking state in Core vs Core+PM profiles
- More code paths = more bugs, more testing, confusing docs

**Result - Unified STATUS.md**:
| File | Purpose | Required? |
|------|---------|-----------|
| **STATUS.md** | WHERE we are (Project Phase, current focus, next steps) | Yes (both profiles) |
| **OVERVIEW.md** | WHAT we're building (vision, capabilities, scope) | Optional |
| **CONTEXT_PACK.md** | HOW to work (technical context) | Yes (both profiles) |

**Changes (33 files)**:
- Templates updated: STATUS.md required, OVERVIEW.md optional
- scaffold.sh: Creates STATUS.md for BOTH profiles
- All hooks, checklists, agent guidelines updated
- Removed all conditional patterns (`STATUS.md || OVERVIEW.md`)
- Python tools updated (doctor.py, verify.py)
- upgrade.sh: Auto-creates STATUS.md for existing Core projects
- Tests added for STATUS.md requirement

**Impact**:
- Simpler framework code (fewer code paths)
- Easier maintenance
- Consistent experience across profiles
- Migration handled automatically by upgrade.sh

### Project Phase Concept

**User insight**:
> "discovery seems good. it also includes research, references, example gathering etc probably"
> "dev loop is never ending - testing is part of the dev loop, not separate"

**Result - Two-Phase Model**:
- **Discovery**: Research, references, examples, requirements gathering, initial designs
- **Building**: Iterative loop where specs, designs, code, tests all evolve together
- Phase tracked in STATUS.md (not separate file)
- Deprecates continue_here.py (redundant with STATUS.md)

### Terminology Refinement

**User question**:
> "is envisioning the best term for creating a product/project idea?"

**Discussion**: Considered "envisioning" vs "discovery"

**Result**: Chose "discovery" as it better captures:
- Research and reference gathering
- Example collection
- Requirements exploration
- Initial design work

### Spec ↔ Code Drift Detection (drift.sh)

**User request**:
> "should we have a command or something that verifies that specs/criteria match code and if there is any drift fixes it"
> "does it analyze code for missing specs? The point in this framework is that a 'non-coder' can read the specs / criteria and understand what the code does"

**Result - Bidirectional Drift Detection**:
- Created `drift.sh` tool for spec ↔ code alignment verification
- **Specs → Code checks**:
  - Shipped features with incomplete acceptance criteria
  - File references in CONTEXT_PACK.md that don't exist
  - Stale STATUS.md focus (>7 days unchanged)
  - Acceptance criteria without corresponding tests
- **Code → Specs checks** (non-coder readability):
  - Exported functions not documented in specs
  - API endpoints not in specs
  - Module exports not in CONTEXT_PACK.md

**Usage**:
```bash
bash .agentic/tools/drift.sh          # Interactive mode
bash .agentic/tools/drift.sh --check  # CI mode (exit code for automation)
```

**Documentation**:
- Added to `feature_complete.md` checklist (mandatory before marking shipped)
- Added to `session_end.md` as periodic check (weekly/major milestones)

**Impact**: Non-coders can read specs to understand system; no undocumented code allowed.

### LLM Test Harness Improvements

**Problem identified**:
- Tests would fail mid-run due to rate limits, losing progress
- Running all tests expensive (tokens)
- Token-efficiency tests (018-020) failing despite framework working correctly

**Result - Incremental Test Runs**:
- `--resume` flag: Continue from where rate-limited
- `--status` flag: Show test run state
- `--reset` flag: Clear state for fresh run
- State persistence in `.test-state` file

**Token-Efficiency Tests Softened**:
- Tests 018-020 now warn instead of fail
- Real project usage is the true validation of framework effectiveness
- Optimization goals tracked but don't block

### Python Tools STATUS.md Consolidation

**Updated for STATUS.md requirement (both profiles)**:
- `verify.py`: Removed conditional STATUS.md logic for Core profile
- `doctor.py`: STATUS.md now required for both profiles, adds suggestion if missing

### PR Tracking via HUMAN_NEEDED.md

**User insight**:
> "the framework could notify the user if there are PRs waiting (in human_needed.md for example) to avoid troubles later"
> "not every project uses github"
> "would human_needed be more token saving?"

**Problem identified**:
- Open PRs can cause merge conflicts if forgotten
- GitHub CLI check (gh) is GitHub-specific
- Need universal solution that works with any git host

**Result - Hybrid PR Notification**:

**Primary: HUMAN_NEEDED.md** (universal, token-efficient)
- PRs tracked as blockers with "review" category
- Already read at session start (no extra tokens)
- Works with any git host (GitHub, GitLab, Bitbucket, etc.)

**Backup: gh CLI check** (GitHub convenience)
- session-start.sh checks for missed PRs on GitHub
- Suggests adding to HUMAN_NEEDED.md if found

**Changes**:
- blocker.sh: Added "review" type for PR tracking
- git_workflow.md: Added step 7 (track PR in HUMAN_NEEDED.md)
- session_start.md: Documented hybrid approach
- session-start.sh: Clarified gh CLI is backup mechanism
- HUMAN_NEEDED.reference.md: Added PR example entry

**Usage**:
```bash
# When creating PR
bash .agentic/tools/blocker.sh add \
  "Review/merge PR #123: feature name" \
  "review" \
  "PR waiting: https://github.com/user/repo/pull/123"

# When PR merged
bash .agentic/tools/blocker.sh resolve HN-XXXX "PR merged"
```

### Role-Based Context Loading (Context Optimization)

**User request**:
> "evaluate the framework actual working from context optimization perspective"
> "if the framework/agent understand what kind of work is being done and can load the relevant context for it"

**Problem identified**:
- Agents load full 51KB `agent_operating_guidelines.md` for ALL tasks
- No automated context selection based on role/task type
- Token-efficient scripts (status.sh, feature.sh) read full files via awk, not true append-only
- Orchestrator delegates without specifying minimal context

**Result - Role-Based Context Assembly**:

**1. Context Manifests** (`.agentic/agents/context-manifests/`):
- 9 YAML files defining token budgets per role
- Each manifest specifies required/optional/exclude files
- Supports section extraction (e.g., `CONTEXT_PACK.md[entry_points]`)

**2. Context Assembly Tool** (`context-for-role.sh`):
```bash
# Get minimal context for implementation agent
bash .agentic/tools/context-for-role.sh implementation-agent F-0042 --dry-run
# Output: Token budget: 5000, Tokens used: 3200 (64%)
```

**3. Orchestrator Integration**:
- Updated orchestrator-agent.md with context loading instructions
- Agents pass ONLY assembled context to subagents

**4. Guidelines Modularization** (partial):
- Created `.agentic/agents/shared/guidelines/` directory
- Extracted `anti-hallucination.md` as standalone module
- Enables lazy loading: load only needed guidelines

**Projected Token Savings**:
| Role | Before | After | Savings |
|------|--------|-------|---------|
| Implementation agent | ~18K tokens | ~5K tokens | 72% |
| Research agent | ~15K tokens | ~3K tokens | 80% |
| Session start | ~12K tokens | ~5K tokens | 60% |

**Deferred (documented for future)**:
- JSON backend for status.sh (true append-only)
- Extract remaining guideline modules
- Consolidate CLAUDE.md duplications

### Expanded Task-Type Detection (24 Agent Types)

**User suggestions**:
> "should one agent be 'framework compliance expert'?"
> "what about something that helps develop business logic/game rules or usability/ux?"
> "one agent could be expert in the deployment environments like app/play store, azure/aws/gcp"

**Result - 15 New Specialized Agents**:

| Category | Agents Added |
|----------|--------------|
| **Domain & Design** | compliance-agent, domain-agent, design-agent, ux-agent |
| **Technical** | refactor-agent, perf-agent, security-agent, api-design-agent, db-agent, migration-agent |
| **Deployment** | devops-agent, appstore-agent, aws-agent, azure-agent, gcp-agent |

**Auto-detection triggers added to auto_orchestration.md**:
- "game rules" / "business logic" → domain-agent
- "usability" / "UX" / "accessibility" → ux-agent
- "design" / "mockup" / "wireframe" → design-agent
- "security" / "vulnerability" / "audit" → security-agent
- "AWS" / "Lambda" / "S3" → aws-agent
- "Azure" / "App Service" → azure-agent
- "GCP" / "Cloud Run" → gcp-agent
- "App Store" / "Play Store" → appstore-agent
- etc.

**Total**: 24 agent manifests for role-based context loading.

### Framework ADRs Initiative (F-0101)

**Critical insight**: Agent attempted to "consolidate" CLAUDE.md (512 → 113 lines) thinking content was duplicated. This broke the bootstrap mechanism - the duplication was intentional.

**Key question asked**: "Why do I have to ask these [about updating docs] always?"

**Result - F-0101: Framework ADRs**:
- Created `docs/adr/` for documenting WHY decisions were made
- ADR-001: CLAUDE.md Must Be Self-Contained (bootstrap reliability)
- Added step 9 to FRAMEWORK_QUICK_START.md: sync CLAUDE.md when guidelines change
- Reverted CLAUDE.md consolidation (mistake acknowledged)

**Principle established**: "Duplication" between CLAUDE.md and agent_operating_guidelines.md is intentional redundancy for reliability, not a DRY violation to fix.

### Modular Guidelines for Token Efficiency (F-0102)

**Token efficiency improvements**:
- Extracted guideline modules for lazy loading:
  - `anti-hallucination.md` - Core rule always loaded
  - `token-efficiency.md` - When updating docs
  - `small-batch.md` - Implementation tasks
  - `multi-agent.md` - Parallel agent work
  - `wip-tracking.md` - Interrupted sessions
- Added JSON backend for status.sh (true append-only updates)

**Token savings projection**:
- Guidelines: 12,800 tokens → ~2,000 tokens per agent (84% reduction)

### 25 Subagent Definition Files

**User request**:
> "we have context manifests but they're not matched by subagent definitions"

**Result - Complete Subagent Coverage**:
- Created 15 new specialized agent definitions (`.agentic/agents/claude/subagents/`)
- Total: 25 subagent definitions matching 24 context manifests
- Each agent has: Purpose, When to Use, Core Rules, Output Format, What You DON'T Do

**New agents created**:
| Category | Agents |
|----------|--------|
| Domain | compliance-agent, domain-agent, design-agent, ux-agent |
| Technical | refactor-agent, perf-agent, security-agent, api-design-agent, db-agent, migration-agent |
| Deployment | devops-agent, appstore-agent, aws-agent, azure-agent, gcp-agent |

### Dogfooding CLAUDE.md Fix

**User insight**:
> "are we dogfooding properly as the claude.md in the root of this is significantly smaller than claude.md in .agentic/agents/claude"

**Problem identified**:
- Root CLAUDE.md was only 102 lines
- Framework template CLAUDE.md (what users get) is 511 lines
- Agents working ON the framework got less guidance than users USING the framework

**Key decision - HOW vs WHAT separation**:
> "should we use similar logic for framework-development specific things? I kind of like that it is here clearly named FRAMEWORK_QUICK_START.md, separating the 'framework working things' and 'what we are working on things'"

**Result**:
- **CLAUDE.md** (541 lines): Full framework instructions (HOW to work)
- **FRAMEWORK_QUICK_START.md**: Framework-specific context (WHAT we're building)
- Pattern applies to all projects: CLAUDE.md = methodology, PRD/product docs = domain

**Changes**:
- Merged full framework CLAUDE.md with framework-specific header/footer
- Added framework reminders pointing to FRAMEWORK_QUICK_START.md
- Only ~30 lines larger than what users get (~1KB, easily fits in context)

---

## v0.12.2 Contributions (2026-01-28)

### Agent Mode Selection (F-0103)

**User insight**:
> "i think we agreed to use the best model for most tasks? what do you think? i think it would be crucial for planning/speccing tasks at least. Maybe there could be agent-level modes: 'top performance'..., 'balanced' and 'really token saving'"

**Follow-up request**:
> "maybe we could have a 'FULL STEAM' mode, that uses the best model for everything? Also make it so that the user can easily edit the used models in these modes"
> "also our documentation should know about this and tell the developer what it is, why and how to customize"
> "Also is there a test for testing if the models are actually used for tasks?"

**Philosophy established**:
- Planning/speccing sets direction for everything
- Bad specs = wasted implementation tokens
- Worth spending on quality for direction-setting tasks

**Result - Agent Mode Selection**:

| Mode | planning | implementation | review | search |
|------|----------|----------------|--------|--------|
| `premium` | opus | opus | opus | sonnet |
| `balanced` (default) | opus | sonnet | sonnet | haiku |
| `economy` | sonnet | haiku | haiku | haiku |

**Model Customization** (per user request):
```yaml
- models:
    planning: opus
    implementation: sonnet
    testing: sonnet
    review: sonnet
    search: haiku
    research: haiku
```

**Documentation** (per user request):
- Created `.agentic/workflows/agent_mode.md` - Full explanation of what, why, how
- Documents all modes, customization, cost comparison, best practices

**LLM Tests** (per user request):
- `022_agent_mode_selection.sh` - Verifies agent reads mode and selects correct model

**Changes**:
- Added `agent_mode` to STACK.template.md with mode descriptions
- Added `models:` section for customization (commented template)
- Updated CLAUDE.md delegation tables with mode-aware recommendations
- Updated agent_operating_guidelines.md delegation tables
- Created acceptance criteria: spec/acceptance/F-0103.md (10 ACs)

**Impact**: Users can now choose quality vs cost tradeoff. Planning always gets best available model for the mode. Full customization available.

### Codex CLI Support

**User request**:
> "add support for Codex"

**Result**:
- Created `.agentic/agents/codex/codex-instructions.md` template
- Added `setup_codex()` function to setup-agent.sh
- Codex CLI now auto-loads framework instructions from `.codex/instructions.md`

### Session Start Bug Fix (v0.12.1)

**User report**: "Exit code 1" error on fresh projects at session start

**Root cause**: `ls .agentic/WIP.md 2>/dev/null` returns exit code 1 when file doesn't exist

**Fix**: Added `|| true` to all such commands in session start files

---

## v0.14.0 Contributions (2026-02-01)

### OVERVIEW.md as High-Level Context Document

**User direction**: Replace scattered vision documents with unified OVERVIEW.md

**Implementation**:
- New template with clean structure: What We're Building, Why It Matters, Core Capabilities, In/Out of Scope, Success Looks Like, Guiding Principles
- Clear document separation: OVERVIEW (vision), CONTEXT_PACK (operational), STATUS (dynamic)
- Planning agents read OVERVIEW.md first to keep vision front and center
- Deleted redundant templates: PRODUCT.md, VISION.md, PRD.md

**Impact**: Agents now have clear, stable context about project goals during planning phases.

---

## v0.15.0 Contributions (2026-02-02)

### Spec-Code Traceability System (F-0109)

**User direction**: "enforce it" - Add automated checks to catch documentation drift and spec-code misalignment.

**Implementation**:
- `drift.sh --json` - Machine-readable drift detection output
- `coverage.py --json/--reverse/--test-mapping` - Enhanced annotation coverage analysis
- `ag trace` - Unified CLI combining drift + coverage reports
- `doc-check.sh` - Documentation sync enforcement tool
- Test→feature inference via naming conventions (no annotations required)

**New Example Project**:
- `traced_notes_app/` - Demonstrates @feature annotations, test naming conventions, import tracing

**Documentation Enforcement**:
- Added doc-check.sh to catch undocumented tools
- Integrated into validate_framework.sh
- Documented 14 previously undocumented tools in DEVELOPER_GUIDE.md

**Tests**: 18 new tests for traceability features (37 total), all validation checks pass (133 passed)

**Impact**: Teams can now answer key questions: "What specs lack code?", "What code lacks specs?", "Which tests cover which features?" - all machine-readable for CI integration.

### Feature Hierarchy Query (--children flag)

**User request**: Add ability to query feature hierarchy - "show all children of F-XXXX"

**Implementation**:
- `query_features.py --children=F-XXXX` - List direct children of a feature
- `--recursive` flag - Show all descendants with indented tree format
- Status summary output (X shipped, Y in_progress, Z planned)
- Combined with `--status` filter for targeted queries
- Graceful handling: non-existent parent errors, no children messages
- Cycle detection for recursive mode (handles circular refs)

**Usage**:
```bash
# Direct children only
python3 .agentic/tools/query_features.py --children=F-0100

# All descendants with tree format
python3 .agentic/tools/query_features.py --children=F-0100 --recursive

# Filter children by status
python3 .agentic/tools/query_features.py --children=F-0100 --status=shipped
```

**Tests**: 8 new tests for --children functionality (14 total in test_query_features.py)

**Impact**: Teams can now easily visualize feature hierarchy and track sub-feature completion status.

---

## v0.15.0 Contributions (2026-02-03)

### Scope & Diff Verification (F-0114)

**Origin**: Analysis of Andrej Karpathy's January 2025 insights about agent weaknesses, combined with learnings from Osmani/Mollick analysis.

**Core Insight**:
> "Instructions don't change agent behavior. Structural constraints and automated verification do."

Initial proposal included 8 behavioral protocols ("answer honestly - could this be simpler?"). After critical review, realized these are instructions that agents would ignore.

**Solution - Structural Over Behavioral**:

1. **Diff Stats Display** (pre-commit-check.sh):
   - Shows lines changed, files affected at start of output
   - Human sees "847 lines changed across 12 files" and decides if proportional
   - No automated judgment - information only

2. **Scope Drift Warnings** (scope_check.sh):
   - WIP.md now includes `IN_SCOPE:` field
   - Pre-commit compares staged files to declared scope
   - WARNS on unexpected files (doesn't block)
   - Human decides if side effects intentional

3. **Six New Principles** (PRINCIPLES.md):
   - Instructions Don't Change Agent Behavior
   - Make Human Review Efficient, Not Unnecessary
   - Warnings Beat Blocks for Soft Signals
   - One Example Beats Three Paragraphs
   - If Explaining Takes Longer Than Doing, Just Do It
   - Don't Delegate Ambiguity

**Key Insight Preserved**:
> "'Watch like a hawk' may BE the answer. These changes make human review more efficient, not unnecessary."

**Files Created/Modified**:
- `.agentic/tools/scope_check.sh` (new - ~60 lines)
- `.agentic/hooks/pre-commit-check.sh` (modified - ~25 lines added)
- `.agentic/tools/wip.sh` (modified - scope fields in template)
- `.agentic/checklists/feature_start.md` (modified - scope declaration)
- `.agentic/PRINCIPLES.md` (modified - 6 new principles, ~100 lines)

**Impact**: Human review becomes more efficient. Agents don't need behavioral instructions that would be ignored anyway. Structural verification makes drift visible.

### Git Workflow Branch Check (F-0115)

**User insight**:
> "Some people might prefer working fast without PRs... i like that there is an option to use version control just with simple commits/pushes."

**Key decision**: User choice matters - both direct commits and PRs are valid workflows.

**Implementation**:
1. **Branch Policy Check** (pre-commit-check.sh check 9/9):
   - BLOCKS commits to main/master when `git_workflow: pull_request`
   - Clear error with 3 options: feature branch, --no-verify bypass, or change to direct
   - Respects user's workflow choice from STACK.md

2. **Profile-Aware Defaults** (scaffold.sh):
   - Core profile → `git_workflow: direct` (fast iteration default)
   - Core+PM profile → `git_workflow: pull_request` (formal tracking = formal review)

3. **Init Playbook Git Workflow Question** (Core profile only):
   - Step 1c asks Core users their preference
   - Core+PM defaults to pull_request without asking

4. **STACK.template.md Documentation**:
   - Prominent comments explaining both workflows
   - Documents that pre-commit BLOCKS (not warns)
   - Mentions --no-verify escape hatch

**Why BLOCK not WARN?**
- User explicitly chose `pull_request` = they want enforcement
- Agents ignore warnings
- Built-in escape hatch (`--no-verify`) for intentional hotfixes

**Tests**: 9 validation checks added to validate_framework.sh

**Impact**: Framework respects user's workflow choice while enforcing it when requested.

---

---

## v0.16.0 Contributions (2026-02-04)

### Maintainability Enforcement Gates (F-0116)

**User direction**: After Karpathy/Osmani analysis, moved from behavioral instructions to structural enforcement.

**Implementation - Three Enforcement Gates**:

1. **Test Execution Gate** (BLOCKING):
   - Pre-commit runs tests from `test_fast:` or `test:` in STACK.md
   - Whitelist-based execution (pytest, npm test, cargo test, etc.)
   - Timeout protection with macOS/Linux compatibility

2. **Complexity Limits Gate** (BLOCKING):
   - `max_files_per_commit` (default: 10)
   - `max_added_lines` (default: 500) - additions only, not deletions
   - `max_code_file_length` (default: 500 lines)
   - File-type aware (only checks code extensions)

3. **Escape Hatches** (feature branches only):
   - `SKIP_TESTS=1` and `SKIP_COMPLEXITY=1` environment variables
   - BLOCKED on main/master branches

**Impact**: Enforces small batch development structurally, not via instructions.

---

## v0.17.0 Contributions (2026-02-04)

### Spec Migration System (F-0117)

**User direction**: Need versioned spec evolution to track feature changes over time.

**Implementation**:
- `migration.sh create "title"` - Creates numbered migration files
- `migration.sh list` / `show N` / `search "term"` - Query migrations
- `migration.sh apply` - Regenerates FEATURES.md from migrations
- Auto-updates `_index.json` registry
- Parses Features Added/Modified/Deprecated sections

**Impact**: Spec changes tracked like database migrations - auditable history.

### Documentation Drift Detection (F-0118)

**User insight**: Code changes without doc updates lead to stale documentation.

**Implementation**:
- `drift.sh --docs` - Detects when docs may be out of sync with code
- `drift.sh --docs --manifest F-XXXX` - Targeted check against feature manifest
- Advisory only (never blocks)
- Shows "potentially stale" vs "updated" documentation

**Impact**: Proactive doc freshness detection without blocking workflow.

### Feature Change Manifest Generation (F-0119)

**User direction**: Track what files changed for each feature.

**Implementation**:
- `manifest.sh F-XXXX` - Generate JSON manifest from feature commits
- `manifest.sh --branch feature/foo` - Generate from branch
- `manifest.sh --markdown` - Human-readable format option
- JSON output integrates with drift.sh `--manifest` flag

**Impact**: Change visibility for targeted drift detection.

### State Directory Migration

**User insight**: State files inside `.agentic/` get lost during framework upgrades.

**Implementation**:
- Created `.agentic-state/` at project root (survives upgrades)
- Moved: `WIP.md`, `AGENTS_ACTIVE.md`, manifests
- Updated all tools and tests for new paths

**Impact**: State persistence across framework version upgrades.

---

## v0.18.0 Contributions (2026-02-05)

### Plan-Review Loop (F-0120)

**User insight**: Plans created by a single agent miss issues that a critical reviewer would catch. Two perspectives are better than one.

**Implementation**:
- Two-agent loop: Planner creates plan, Reviewer critiques, iterate until APPROVED
- Plan artifacts stored in `.agentic-journal/plans/F-XXXX-plan.md`
- Configurable: `plan_review_enabled`, `plan_review_max_iterations`, `plan_review_auto_for`
- Issue categorization: CRITICAL, IMPORTANT, SUGGESTION
- Verdict system: APPROVED, REVISION_NEEDED, ESCALATE
- Agent definitions for both Claude Code and Cursor

**Agents**:
- `plan-creator-agent.md` - Creates comprehensive plans following template
- `plan-reviewer-agent.md` - Critical review with adversarial mindset

**Testing**:
- LLM test `023_plan_review_loop.sh` verifies agent behavior
- Framework validation passes (149/149)

**Impact**: Catches issues during planning rather than implementation - cheaper to fix.

### Persistent Journal & Tool Parity (F-0121)

**User insight**: State files in `.agentic-state/` are transient, but lessons and manifests should persist across sessions. Also, all AI tools should have consistent enforcement gates.

**Implementation - Persistent History**:
- Created `.agentic-journal/` directory for persistent artifacts
- Separates transient (WIP, plans) from historical (lessons, manifests)
- `lessons/` subdirectory with L-#### format for project learnings
- Moved manifests from `.agentic-state/` to `.agentic-journal/`
- Survives framework upgrades and context resets

**Implementation - Tool Parity**:
- All 4 tool templates (Claude, Codex, Copilot, Cursor) now have consistent gates
- 6-gate enforcement table in all templates
- Escape hatches documented in all templates
- Validation tests ensure parity across tools
- `/CODEX.md` now properly extends template (was a stub)

**Impact**: Cross-session learning captured; all AI tools enforce same quality gates.

### Multi-Tool LLM Testing Infrastructure (F-0122)

**User request**:
> "So the behavioral LLM tests are ESSENTIAL. And they should be run using Cursor when in cursor."

**Implementation**:
- Machine-readable test definitions in `tests/llm/test_definitions.json`
- Python interactive runner `tests/llm/interactive_runner.py`
- `ag test llm` command with environment detection
- Cursor CLI (`cursor-agent`) support added to harness.sh
- Interactive mode for IDE-based tools (Cursor, Copilot)
- 10 behavioral tests all passing in Cursor IDE environment

**Test Results (v0.18.0 Cursor)**:
- Critical: 4/4 passed
- Important: 5/5 passed
- Normal: 1/1 passed
- Total: **10/10 tests passed**

**Impact**: LLM behavioral tests now work across Claude CLI, Codex CLI, Cursor CLI, Cursor IDE, and Copilot IDE.

---

## v0.19.0 Contributions (2026-02-05)

### Principles Consolidation & Value Proposition

**User request**:
> "Can you now review thoroughly the whole framework for any issues? Maybe go one design principle at time systematically with limited contexts"

**Implementation - Principles Consolidation**:
- Added 13 new principles to `PRINCIPLES.md` (now 48 total):
  - Development & Quality: TDD as Default, Explicit Over Implicit, Automated Validation, Retrospectives, Research Mode, Programming Standards, Comprehensive Testing
  - Collaboration: Multi-Agent Coordination, PR Mode, Build/Deploy Specialization
  - Documentation: Spec Schema Enforces Consistency, Examples First-Class, Framework Self-Documentation
- Archived historical analysis files to `docs/reviews/`
- Created `docs/FRAMEWORK_VALUE_PROPOSITION.md` summarizing framework value

**Implementation - Value Proposition Audit**:
- Systematic audit of all 30 value claims against actual implementation
- Results: **29/30 IMPLEMENTED, 1/30 PARTIAL** (progressive disclosure)
- Documented in `docs/reviews/2026-02-value-proposition-audit.md`
- Framework delivers on documented claims

### Plan-Review Loop for Test Design

**Learning**: Using the plan-review loop (F-0120) to design new LLM tests revealed a duplicate test.

**Process**:
- Created plan for 12 new value proposition tests
- Reviewer found Test 025 duplicated existing Test 020
- Revised plan removed duplicate, added different test
- Anti-hallucination tests redesigned to use partial real code (harder to pass)

**Impact**: Validated that plan-review loop catches real issues.

### "Check Before Creating" Principle (NON-NEGOTIABLE)

**Origin**: Duplicate test discovered during plan-review loop.

**User insight**:
> "should be a PRINCIPLE i think - always checking first what is already available before creating new md files or some other possible duplicate files..."

**Implementation**:
- Added "Check Before Creating" as NON-NEGOTIABLE principle in `PRINCIPLES.md`
- Added anti-pattern "❌ Don't Create Without Checking"
- Added enforcement section in `agent_operating_guidelines.md` with:
  - What to check table (tests, docs, components, utilities)
  - How to check examples (grep, list_dir, search)
  - Good/bad examples from real experience

**Impact**: Prevents wasted effort from duplicate tests, docs, or components.

### Anti-Hallucination Formalized

**User prompt**:
> "dont we have anti-hallucination rule"

**Implementation**:
- Added "Anti-Hallucination (NON-NEGOTIABLE)" as formal principle in `PRINCIPLES.md`
- Comprehensive documentation with examples, enforcement mechanisms
- Links to `agent_operating_guidelines.md` and Context7 verification

**Impact**: Previously scattered across guidelines, now a first-class principle.

### Stale Version Numbers Fixed

**Discovery**: Audit found 8 files with stale version numbers (0.12.0-0.15.1 instead of 0.18.0).

**Files Updated**:
- PRINCIPLES.md, DEVELOPER_GUIDE.md, FRAMEWORK_DEVELOPMENT.md
- ROI.md, claude-hooks/README.md, MANUAL_OPERATIONS.md
- environment_research.md, green_coding.md

**Impact**: Version consistency across documentation.

### Principles Simplification

**User prompt**:
> "Go through all the principles and think is this really beneficial... if there are doubts should we remove something for simplifying the framework"

**Before**: 48 positive principles + 11 anti-patterns across 7 sections (1,542 lines)
**After**: 11 core principles (8 NON-NEGOTIABLE + 3 RECOMMENDED) (~240 lines, 84% reduction)

**Key decisions**:
- Sub-principles absorbed into parent principles (e.g., 5 token-related principles → "Context Efficiency")
- Anti-patterns section removed entirely (each principle now has inline anti-patterns)
- "Durable Artifacts" kept standalone (user: "they're human-readable too")
- "Green Coding" kept as visible principle (user: "important for project output")
- "Small Batch" + "Acceptance-Driven Development" merged (one methodology, two phases)
- Programming/Testing Standards demoted to reference files (already existed in `.agentic/quality/`)
- PR Mode, Build/Deploy Agent, Retrospectives, Mutation Testing → features, not principles

**Process**: Plan-review loop with 3 iterations of planner/reviewer analysis.

**Impact**: PRINCIPLES.md now fits in a single context window read. Clearer hierarchy.

---

## v0.20.0 Contributions (2026-02-05)

### Traceability & Documentation Overhaul

**User request**:
> "do we have somewhere a mapping of the design principles to features (to acceptance criteria to tests)? that should be updated. both the readme.mds as well."

**Implementation - Traceability Matrix Rewrite**:
- `tests/TRACEABILITY_MATRIX.md` completely rewritten for 11 simplified principles
- Maps every principle → features → specific tests → results
- 100% principle coverage: 32 LLM behavioral + 13 structural tests
- v0.19.0 test results: 33/33 tests mapped to principles

**Implementation - Test Results Consolidation**:
- Deleted `tests/LLM_TEST_RESULTS.md` (duplicate source of truth)
- `tests/VERIFICATION_REPORT.md` is now single source for ALL test results
- Organized by principle (11 sections matching core principles)
- Updated 9 files referencing old location
- Evidence tiers: battle-tested, LLM-verified, structurally verified, designed for

**Implementation - "Why This Framework?" README Section**:
- Added honest comparison table: `.cursorrules`/`CLAUDE.md` vs this framework
- 7 problem areas with concrete solutions
- Explicit "battle-tested" vs "designed for" evidence tiers
- Links to traceability matrix for verification

**Implementation - `.agentic/README.md` Updates**:
- Fixed stale version refs (v0.2.1 → v0.19.0 in all curl examples)
- Updated Design Principles section to list all 11 principles

### Context7 → MCP Server Documentation Update

**User question**:
> "are the impl agents actually using context7 for example?"

**Discovery**: Framework docs referenced Context7 as a CLI tool (`npm install -D @context7/cli`), but it's now primarily an MCP server.

**Implementation**:
- `.agentic/workflows/documentation_verification.md` rewritten (~430 → ~130 lines)
  - MCP server setup for Cursor (`.cursor/mcp.json`) and Claude Desktop
  - `@upstash/context7-mcp@latest` package reference
  - Simplified from 4-layer system to clear priority table
- `anti-hallucination.md` - Updated sources of truth (#1: Context7 MCP server)
- `agent_operating_guidelines.md` - Same update in verification protocol
- `STACK.template.md` - Updated config: `context7-mcp` option with setup comment

**Impact**: Agents now have accurate instructions for using Context7 as MCP server rather than deprecated CLI.

---

## v0.21.0 Contributions (2026-02-06)

### Structural Enforcement of Durable Artifacts

**User insight**:
> "Yeah so what is the solution to have those files always updated?"
> "also, we have LLM tests - how come they don't catch these essential files not being updated regularly?"

**Root cause identified**: STATUS.md drifted from v0.13 to v0.20 because the only enforcement was behavioral (checklists say "update it"). Agents forget. Per Principle #4: scripts > documentation.

**Implementation - `status.sh infer` command**:
- New subcommand reconstructs project state from 5 data sources:
  - Git log (commits since STATUS.md last modified)
  - Last JOURNAL.md entry (Next Steps, Blockers)
  - VERSION file
  - spec/FEATURES.md in-progress features
  - CHANGELOG.md latest version entry
- `--apply` flag auto-updates STATUS.md
- Labels each inference source for transparency

**Implementation - Session-start auto-inference**:
- session-start.sh: when STATUS.md stale >7 days, auto-runs `status.sh infer`
- Replaces passive "it's stale" warning with active recovery
- Agent can review and apply or update manually

**Implementation - Pre-commit STATUS.md advisory**:
- pre-commit-check.sh: new check 3b warns if STATUS.md not updated in >48h
- Advisory only (Principle #4: Warnings Beat Blocks)
- Suggests `status.sh infer --apply`

**Implementation - 6 artifact-maintenance LLM tests (036-041)**:
- Identified gap: existing LLM tests check **awareness** (agent knows about tools) but not **behavior** (agent actually uses tools when workflow triggers happen)
- New tests verify proactive maintenance:
  - 036: Session end → agent updates JOURNAL + STATUS (not just verbal summary)
  - 037: Agent detects stale STATUS.md (version mismatch: v0.5 vs v0.20)
  - 038: Agent mentions WIP tracking on work start
  - 039: Feature complete → agent updates FEATURES + CHANGELOG + JOURNAL chain
  - 040: Agent documents blockers in HUMAN_NEEDED.md
  - 041: Agent notices stale JOURNAL.md (3-week gap vs active development)

**Bug fix**: Stale `tests/LLM_TEST_RESULTS.md` reference in pre-commit-check.sh (file deleted in v0.20.0)

**Impact**: Durable artifacts now have structural enforcement at three levels: session-start (catch before work), pre-commit (catch during work), and LLM tests (verify agent behavior). Total LLM tests: 28.

---

## v0.22.0 Contributions (2026-02-06)

### Instruction File Architecture Analysis

**Key insights that shaped L-0003 and corrected L-0002**:

1. **Orchestrator vs subagent instruction needs**: Identified that the user-facing orchestrator and subagents have fundamentally different instruction needs — the orchestrator needs workflow knowledge (triggers, gates, protocols), subagents need only role-specific focus. Drove investigation that revealed subagents don't inherit CLAUDE.md at all (per official docs), confirming the distinction is already the reality.

2. **ag commands as context delivery hypothesis**: Proposed that shell command output (`ag plan`, `ag implement`) could serve as just-in-time context delivery — keeping CLAUDE.md minimal while delivering rich task-specific instructions when triggered. Documented as untested hypothesis requiring validation.

3. **CLAUDE.md as router concept**: Identified that CLAUDE.md's optimal role may be dispatch/routing (trigger words → actions) rather than comprehensive manual. The trigger table format already works this way — tests 003/010 confirm agents follow it.

4. **Subagent context questioning**: Drove investigation that surfaced contradiction between L-0002's "subagent context multiplier" claim and official Claude Code documentation. Result: L-0002 section corrected with addendum.

5. **Plan-review loop adoption gap**: Identified that the plan-review loop (F-0120) exists but is never triggered because the implement trigger in CLAUDE.md goes straight to code, skipping planning. Led to updating all instruction files to mention `ag plan` before `ag implement`.

**Impact**: L-0002 corrected, L-0003 created documenting architectural tensions, implement trigger updated across all tool instruction files.

### Cross-Tool Subagent Context Research (2026-02-07)

6. **Drove cross-tool research confirming context isolation is industry-wide**: Investigation across Claude Code, Cursor 2.4, GitHub Copilot, and OpenAI Codex confirmed that subagent context isolation is a universal pattern — instruction files serve only the orchestrating/principal agent. This validates the framework's existing context manifest architecture and removes the false "subagent context multiplier" concern.

**Impact**: L-0003 updated with cross-tool evidence table, subagent definitions made self-contained (removed "Full documentation: see file X" footers), CLAUDE.md now tells orchestrator to use `context-for-role.sh` for subagent context assembly.

---

## Instruction Architecture Design Document (2026-02-07)

### Definitive Design Basis

**User direction**: Two independent research efforts (ChatGPT 5.2 and Claude Opus 4.6) converged on a clear architecture, but findings were scattered across research docs and lessons. Directed creation of a single authoritative design document to end the back-and-forth.

**Result - `docs/INSTRUCTION_ARCHITECTURE.md`**:
- Unified design document synthesizing both research efforts
- Three-layer architecture mapped to framework: Constitution (instruction files) → Playbooks (ag commands + docs) → Project State (STACK.md + status.json)
- 4 specific gaps identified with actionable fixes
- 10 testable assumptions tracked with validation status
- "Do not change" list protecting 11+ working mechanisms
- Evidence quality distinguished: verified tool docs vs architectural reasoning
- Distributed enforcement model documented as conscious design divergence from centralized orchestrator recommendation

**Key corrections made**:
- FRAMEWORK_DEVELOPMENT.md line 94: Fixed false claim "CLAUDE.md is auto-loaded for ALL agents including subagents" → tool-specific correction noting subagents do NOT inherit it
- Added research references to FRAMEWORK_QUICK_START.md and PRINCIPLES.md
- L-0003 updated with resolution pointing to design document
- L-0004 created preserving the 3-round plan-review process

**Impact**: Single authoritative reference for instruction architecture decisions. Future changes reference this document, not ad-hoc lessons or research.

---

## Architecture Visibility & Framework Cleanup (v0.23.0, 2026-02-08)

### Three-Layer Architecture Implementation

**User direction**: Implement the instruction architecture design document — slim instruction files, surface the architecture for all audiences, consolidate persistent artifacts.

**Cleanup results** (7 batches):
- Instruction files slimmed to <100 lines (template CLAUDE.md 79→40, root 92→52, codex 286→50)
- Gates, delegation, session protocols moved from instruction files to `auto_orchestration.md` (playbook layer)
- `agent_operating_guidelines.md` refactored 434→~120 lines with modular `guidelines/` directory
- `core-rules.md` (constitutional minimum) auto-injected for all 24 agent roles via `context-for-role.sh`
- `ag.sh` commands now print playbook references; `done` blocks on validation failures
- 6 legacy tools archived with documentation

### Architecture Visibility

**User direction**: The framework's "magic sauce" (three-layer architecture) was buried in a research folder. Surface it for all audiences.

**Results**:
- `docs/INSTRUCTION_ARCHITECTURE.md` promoted from `docs/research/`
- "How It Works" section added to README.md (three-layer architecture explained)
- Architecture table added to FRAMEWORK_QUICK_START.md
- Template vs Root table added to FRAMEWORK_DEVELOPMENT.md
- Cross-references added to PRINCIPLES.md, auto_orchestration.md, root CLAUDE.md

### Persistent Artifacts Consolidation

**User direction**: JOURNAL.md should live in `.agentic-journal/`. Approved plans should be git-tracked in one place.

**Results**:
- `JOURNAL.md` moved to `.agentic-journal/JOURNAL.md` (all scripts use fallback for backward compat)
- Plans consolidated from `docs/plans/` + `.agentic-state/plans/` (gitignored) to `.agentic-journal/plans/` (git-tracked)
- `.agentic-journal/` now holds: JOURNAL.md, manifests/, lessons/, plans/

---

## LLM Test Suite Completion & Settings Testing (v0.23.0, 2026-02-08)

### Complete LLM Test Coverage (13 Missing Scripts Implemented)

**Context**: After v0.23.0 shipped 28 test definitions in `test_definitions.json`, 13 lacked shell script implementations. All 13 were implemented in a single batch following the established harness pattern.

**Implementation**:
- 13 shell scripts created covering token-efficiency, durable-artifacts, multi-agent, profiles, and artifact-maintenance sections
- 2 JSON definition fixes: test 033 (empty AGENTS_ACTIVE → populated with active agent, plus `git add -f` for gitignored file) and test 037 (improved `output_not_contains` patterns to avoid false-fails on quoted stale content)
- Soft-check pattern (warnings, not hard failures) used for proactive/aspirational behavior tests (024-026, 036, 038, 040, 041)
- Hard-check pattern used for tests where behavior is explicitly instructed (031-034, 037, 039)

**Result**: All 29 test definitions now have matching shell scripts. Zero gaps between JSON definitions and harness tests.

### Settings Abstraction Insight

**User insight**: STACK.md settings like `plan_review_enabled`, `agent_mode`, and `git_workflow` are abstracted behind `ag` commands — agents don't read these settings directly, they run `ag plan` / `ag commit` and the scripts read the settings. Therefore:

1. **LLM tests for settings awareness are the wrong layer** — an initial LLM test (042) that checked whether agents could quote STACK.md values was reverted after recognizing the architecture mismatch.
2. **Functional tests for `ag.sh` are the right layer** — settings should be tested where they're consumed (the scripts), not where they're stored (STACK.md).

**Result - 7 Functional Settings Tests** (added to `test_ag_gateway.sh`):
- `plan_review_enabled=yes` → shows "Review loop: ENABLED"
- `plan_review_enabled=no` → shows "Review loop: SKIPPED"
- `--no-review` flag overrides the enabled setting
- `plan_review_max_iterations=5` → shows "max 5 iterations"
- Default (setting absent) → ENABLED
- Core profile rejects `ag plan` (feature IDs require Core+PM)
- `plan_review_auto_for=[implement]` warns when no approved plan exists

**Bug fix**: 3 pre-existing test failures in `test_ag_gateway.sh` caused by missing `mkdir -p .agentic-state/` before writing WIP.md.

**All 21 gateway tests now pass.**

### Plan-Review Awareness in Feature Pipeline

**User insight**: When an agent starts planning a feature, it should surface the plan-review configuration so the user knows whether review is active and how many iterations are allowed. This was a gap in the playbook layer — the Feature Pipeline in `auto_orchestration.md` went straight from acceptance criteria to implementation without checking plan-review settings.

**Implementation**:
- Added step 2 "CHECK PLAN-REVIEW SETTING" to Feature Pipeline in `auto_orchestration.md`
- Tells agents to read `plan_review_enabled` from STACK.md and mention the review loop status and max iterations to the user
- New LLM test `043_plan_review_awareness.sh` verifies the agent mentions plan-review when starting to implement a feature

**Design principle reinforced**: Keep CLAUDE.md minimal (constitution layer). Add workflow guidance to `auto_orchestration.md` (playbook layer) where it's loaded just-in-time when needed.

---

## Structural Enforcement: JOURNAL & STATUS Staleness (2026-02-09)

### From Behavioral Rules to Structural Enforcement

**User frustration** (driving the entire feature):
- Agents bypass `ag commit` and JOURNAL/STATUS update rules even when the trigger word table is right there in CLAUDE.md
- Text rules don't change agent behavior under cognitive load — the agent that skipped the workflow had the instructions loaded
- Core insight: **structural enforcement** (mechanisms that physically prevent the wrong action) > behavioral rules (text telling agents what to do)

**User direction — Two-Layer Enforcement**:
1. **Git pre-commit hook** (cross-agent): Blocks commits when JOURNAL/STATUS are stale — works for Claude, Cursor, Copilot, Codex, anything using git
2. **Claude Code UserPromptSubmit hook** (Claude-specific): Proactive reminder injected before each response when artifacts are stale
3. Checks must be **BLOCKING**, not advisory warnings (agents ignore warnings)

### Commit-Relative Staleness (Refinement)

**User insight** (after initial fixed-time implementation):
> "Could the staleness be checked from something more concrete, like the previous git commit time instead of a fixed time? There could be multiple commits within an hour or two... but it could be that within the fixed time multiple different things were accomplished."
> Also flagged worktree compatibility as a requirement.

**Problem with fixed-time thresholds**: A 2h/4h threshold is simultaneously too lenient (multiple commits within window, only the first gets journaled) and too strict (a single long session with one commit gets blocked even though everything's fine).

**Result - Commit-Relative Staleness**:
- Pre-commit hook checks if JOURNAL.md/STATUS.md were modified **after the last commit**, not within a fixed time window
- Three-tier pass logic: (1) artifact is staged in current commit → PASS, (2) artifact mtime > last commit time → PASS, (3) otherwise → BLOCK
- Works correctly in git worktrees (`git log -1` resolves per-worktree HEAD)
- `SKIP_STALENESS=1` escape hatch (blocked on main/master, like existing SKIP_TESTS/SKIP_COMPLEXITY)
- Claude Code `UserPromptSubmit.sh` hook: proactive reminder when uncommitted changes exist but artifacts haven't been updated since last commit

### Contribution Logging Gap

**User observation**: Agents weren't logging user contributions — the root CLAUDE.md and .cursorrules had no instruction to update CONTRIBUTIONS.md.

**Result**: Added contribution logging rule to both framework-dev instruction files.

**Impact**: Structural enforcement replaces behavioral rules for artifact freshness. Commit-relative detection is tied to actual activity, not wall-clock time.

---

## Agent Memory Seeding During Init (2026-02-10)

### Persistent Memory as Behavioral Reinforcement

**User insight**: CLAUDE.md rules like "Update JOURNAL.md and STATUS.md before every commit" get buried in long sessions. Tools with persistent memory hold behavioral patterns more reliably than instruction files that get compressed.

**User research** (Feb 2026): Mapped which AI tools support persistent memory and whether it's seedable:
- Claude Code: `~/.claude/projects/*/memory/MEMORY.md` (agent writes during init)
- Codex CLI: `~/.codex/AGENTS.md` (direct file write)
- Windsurf: `~/.codeium/windsurf/memories/global_rules.md` (direct file write)
- Copilot (JetBrains): `~/.config/github-copilot/global-copilot-instructions.md` (direct file write)
- Cursor: SQLite DB (UI-only, not seedable)

**Key distinction**: Memory seed contains *workflow patterns* (what to do and when), not rules (rules stay in CLAUDE.md). This prevents duplication while reinforcing the patterns agents forget most.

**Design decisions**:
- Memory seeding stays inline in init_playbook.md (1-3 lines per tool section) — no separate playbook needed
- User-level files (Codex AGENTS.md, Windsurf global_rules.md) require explicit user consent before writing
- Existing project migration handled via CLAUDE.md template pointer (no separate migration path)
- Version marker in memory-seed.md so agents can detect staleness

**Impact**: Agents get framework workflows written to persistent memory during init, surviving session resets and context compression.

---

## Deep Feature Discovery for Brownfield Onboarding (2026-02-10)

### Real-World Pain Point

**User discovery**: Running `discover.py` against a real multi-sub-project repo (React frontend + serverless backend + React Native mobile) produced nearly useless output — zero features, null framework/package-manager, serverless functions and frontend components completely invisible.

**Root cause identified**: Discovery was gated behind `core+product` check and only looked at root-level config files. Multi-sub-project repos (frontend/ + api/ + mobile/) with no root package.json were invisible.

### Design Principle: Python Collects, LLM Synthesizes

**Key architectural decision**: Discovery script collects rich structural evidence (sub-projects, serverless functions, UI components, feature clusters). The LLM synthesizes meaningful features during `init_playbook` user interview. Don't over-engineer fuzzy matching in Python — let the LLM/user merge "User Settings" and "Preferences" during review.

### User-Facing Terminology Fix

**User observation**: Init playbook asked users to "Type 'a' for Core or 'b' for Core+PM" — users don't know what "PM" means. Fixed to spell out "Core + Product Management".

**Impact**: Discovery now handles multi-sub-project repos, serverless backends, and component-based frontends. Feature clustering cross-matches frontend/backend/mobile tiers for richer onboarding.

---

## Domain Categories + Systematic Brownfield Spec Generation (2026-02-10)

### Design Direction: Domains as Metadata, Not Structure

**User insight**: Different "wholes" in a repo (frontend app, backend API, CI/CD) should have their own feature categories. But features should keep the flat `## F-XXXX:` heading format — 15+ tools depend on it.

**Key decision**: Domains are metadata (`- Domain: frontend`), not heading-level structure. This preserves all existing tooling while enabling domain-filtered queries and hierarchical splitting for large projects.

### Systematic Multi-Session Spec Generation

**User requirement**: Brownfield repos with multiple domains need systematic, domain-by-domain spec generation — potentially spanning multiple sessions. Not everything can be done in one pass.

**Design decisions**:
- `ag specs` creates a plan artifact with checkbox-based progress tracking (`- [x]` / `- [ ]` per domain)
- Session start detects active brownfield plans and suggests resuming
- Plan-review loop validates domain boundaries before execution begins
- Per-domain user confirmation before moving to next domain

### Size-Aware Routing

**User insight**: Small single-domain projects shouldn't be forced through the full `ag specs` pipeline. Two independent thresholds:
1. **Spec approach**: 1 domain AND ≤8 clusters → quick inline; otherwise → `ag specs`
2. **Token cost**: >50 features → suggest `organize_features.py --by domain` for file splitting

### Greenfield Support

**Requirement**: Domain categories must work for both greenfield and brownfield projects. Init interview now asks Core+PM projects about distinct domains from day 1.

**Impact**: Agents can now systematically generate specs for large brownfield repos, track progress across sessions, and organize features by domain for both new and existing projects.

### Enforcement Gap Audit & Closure

**User insight**: Framework shipped F-0124 (v0.25.0) without updating FEATURES.md status, and F-0123 sat as "in_progress" despite being shipped. No gate caught it. Requested systematic audit of all enforcement gaps — "plan-review loop until no critique."

**Key decisions**:
- 20 gaps identified, each assigned the right enforcement tool (structural gate, doc honesty, memory seed, LLM test, or accept-as-advisory)
- FEATURES.md staleness now structurally gated (conditional: only when spec/ files staged)
- `ag done` blocks if acceptance file missing or feature not registered in FEATURES.md
- `ag implement` blocks if a different feature is already in WIP
- Doc honesty: smoke testing downgraded from "gate" to "strongly recommended"; PRINCIPLES.md now lists enforcement tiers explicitly; ROI.md qualified from "100% auto-enforced" to "80% staleness-gated"
- Three new LLM behavioral tests (047-049) for defense-in-depth

**Impact**: Framework now practices what it preaches — Principle #4 (Deterministic Enforcement) is honestly documented and structurally enforced where possible.

## Memory Seed Infrastructure + Integrity (2026-02-11)

### Memory-Seed Effectiveness and Intent-Based Triggers

**User insight**: Memory-seed content is written in documentation style ("Plan first: `ag plan`") but agents treat it as knowledge, not as action triggers. The trigger table in CLAUDE.md works because it uses imperative trigger→action format. Memory-seed should use the same proven format to actually drive command execution, not just awareness.

**User direction**: Rewrite memory-seed.md in imperative format matching the trigger table style. Also: trigger words should match on user *intent* and synonyms, not just exact keywords — "build", "implement", "create" are too narrow; users say things like "let's make", "set up", "develop", "work on" which carry the same intent.

**User insight**: CONTEXT_PACK.md was missing the instruction architecture — the core intellectual framework of the project. Added architecture section so agents get the three-layer model, enforcement hierarchy, and defense-in-depth concepts at session start without reading the full design doc.

**Changes**:
- `memory-check.sh` — advisory integrity check for Claude Code auto-memory at session start
- Defense-in-depth documentation across INSTRUCTION_ARCHITECTURE.md, FRAMEWORK_DEVELOPMENT.md, CONTEXT_PACK.md, session_start.md
- Tool memory landscape documented (5 tools)

**Impact**: Memory-seed layer now has integrity checking, architectural documentation, and maintenance guidance.

### Intent-Based Triggers + Imperative Memory Seed (v0.25.3)

**User insight**: Memory-seed was written in documentation style ("Plan first: `ag plan`") — agents treat this as knowledge, not action triggers. The proven trigger table in CLAUDE.md works because it's imperative: trigger→action with STOP. Memory-seed should use the same format.

**User direction**: Rewrite memory-seed.md as imperative action rules, not reference documentation. "Write these rules to memory. They are action triggers — when a condition is met, execute the specified command. Do not treat these as suggestions."

**User insight**: Trigger words should match on user *intent* and synonyms, not just exact keywords. Users say "let's make", "set up", "develop", "work on" — all carrying "build" intent but none matching the old exact-keyword triggers.

**User direction**: Update all 7 instruction files to use "User intent" column with broader phrasing. Add "(match on intent, not just exact words)" to the header.

**User catch**: The memory-seed integrity check at session start wasn't instructed in CLAUDE.md itself — only wired into `ag start`. Agents that don't run `ag start` would never know to check. Added explicit instruction to both template and root CLAUDE.md.

**Changes**:
- memory-seed.md rewritten: documentation style → imperative trigger→action format
- All 7 trigger tables: exact keywords → intent-based matching with synonyms
- CLAUDE.md (template + root): added explicit "check your memory at session start" instruction

**Impact**: Behavioral reinforcement now uses the same proven imperative format as structural enforcement. Intent matching broadens trigger coverage beyond exact keyword matches.

### Unified Sync + Discoverability Reminders + Tip of the Day (v0.25.4)

**User insight**: Agents forget about `ag plan` (plan-review loop) even though it's in the trigger table. Same risk for `ag sync`. The fix is putting reminders where the agent actually looks — the `ag start` output — not just in instructions that may get compressed away.

**User direction**: Build `ag sync` as unified drift detection across 5 phases (memory, state freshness, feature reconciliation, spec/doc drift, tool parity). Make it user-initiated (not auto-run) to control token cost, but have `ag start` remind the human it exists.

**User design choice**: `ag sync` does NOT auto-run every session — token cost is too high. It's user-initiated, but the agent should remind the human it exists via a dim "Available workflows" line and a yellow sync probe when issues are detected.

**User idea**: Add a "tip of the day" to the session start dashboard — a random tip surfacing framework capabilities the user might not know about. Examples: "synchronize framework memory and specs by running `ag sync`", "start planning with plan-review loop to automatically let agents discuss a brilliant plan". Low-cost discoverability boost.

**Changes**:
- `sync.sh` (new) — unified drift detection + auto-fix across 5 phases, with `--check` (dry run) and `--quiet` (probe) modes
- `ag.sh` — thin wrapper for `ag sync`, discoverability reminder line in `cmd_start`, tip of the day (10 tips, random per session)
- `session_start.md` — greeting template updated with "Available workflows" line and tip slot
- Both `CLAUDE.md` files updated for sync documentation

**Impact**: Framework capabilities are now surfaced where agents and users actually look (dashboard output), not buried in instruction files. Tip of the day provides passive discoverability for the full `ag` command set.

## Git Hook Enforcement (2026-02-12)

### Enforcement Gap Discovery & Closure (F-0129)

**User discovery**: Committed 3 times in one session using `git add && git commit` directly, bypassing every quality gate. The pre-commit-check.sh (716 lines, 13 checks) existed but was never wired as an actual git hook — `.git/hooks/` had only `.sample` files. Also identified that `ag plan` requiring acceptance criteria before planning was backwards — specs should gate implementation, not planning.

**User direction**: Two-fix approach: (1) Wire hooks via `core.hooksPath` so they actually fire, with a dispatcher that reads config from STACK.md. (2) Loosen `ag plan` gate to advisory — planning helps you figure out *what* to build, acceptance criteria should gate `ag implement` not `ag plan`.

**User design decisions**:
- `pre_commit_hook: fast|full|no` in STACK.md — fast skips tests and advisories, full runs everything, no disables hooks
- CI detection in dispatcher — hooks should never run in CI environments
- `ag hooks install|status|disable` for manual management
- `disable` requires `--confirm` flag (destructive action pattern)
- Backward compat: `yes` maps to `fast`
- Both profiles get hooks (Core profile users: Core+PM-specific checks self-skip)

**Impact**: The 13-check pre-commit quality gate is now structurally enforced via git's `core.hooksPath` mechanism. No more bypassing quality gates by using raw `git commit`.

### Journal "Why" — Capture Motivation at Write Time, Not After the Fact (2026-02-12)

**User insight**: Journal entries were mechanical "what was done" lists — useful for tracking but missing the *why* behind each session's work. Without motivation context, future readers (human or agent) can't distinguish important architectural decisions from routine chores.

**User direction**: Add a `--why` flag to `journal.sh` so motivation is captured at write time as part of the workflow. Don't fabricate "why" retroactively by reversing "what was done" — that adds no real information. If you don't have genuine context for why something was done, leave it blank rather than inventing a plausible-sounding reason.

**Key principle**: Metadata quality comes from capturing context *when it exists* (at write time), not from reconstructing it later. Retroactive inference is worse than honest gaps.

**Changes**:
- `journal.sh` — added `--why "Reason"` optional flag, renders as `**Why**:` section before Accomplished
- `memory-seed.md`, `CLAUDE.md` (template + root) — updated command pattern to include `--why`

**Impact**: Journal entries going forward capture motivation alongside accomplishments, improving context for session resumption and historical review.

## Derivation Hierarchy with F/D/R IDs (2026-02-14)

### Principle Restructuring: From Flat List to Derivation DAG

**User insight**: The previous 3-tier restructuring (FOUNDATION / NON-NEGOTIABLE / RECOMMENDED from commit d10f072) was "a flat list pretending to be hierarchical." The tier labels described enforcement level, but there was no derivation — you couldn't trace WHY each principle exists by following edges back to a parent. Flat P-numbering made all principles look equal and didn't scale.

**User direction**: A genuine hierarchy where 3 foundations (WHY) lead to derived strategies (HOW), which lead to specific rules (WHAT). Tier-prefixed IDs (F/D/R) so the tier is immediately visible and each tier can grow independently — adding R4 never affects F or D numbering.

**User design decisions**:
- Green Coding is NOT derived from Context Efficiency — it's broader, about energy-efficient production code. Promoted to Design Principle (D6)
- Multi-Environment Portability IS a core design principle (D7), not just a feature — derived from F1 (UX) + F2 (long-term flexibility)
- Tool agnosticity reframed as Multi-Environment Portability
- All 13 principles are mandatory — the tier distinction is abstraction level, not enforcement level
- When principles conflict, specificity wins: Rules override Design Principles, Design Principles override Foundations
- Anti-Hallucination traces to D1 (trust) + D3 (artifact truth) + F2 (quality), not forced to every foundation

**Impact**: 12 → 13 principles (added D7). 22 explicit derivation edges form a DAG. Every non-foundation principle has a "Derives from" line tracing it to parent principles. Mermaid diagram shows the full hierarchy visually.

---

## Infrastructure Validation with Mutation Tests (v0.25.8, 2026-02-14)

### Proving Enforcement Is Real

**User direction**: Framework claims "deterministic enforcement" but how do you prove git hooks, CLAUDE.md triggers, and defense-in-depth layering actually work? Design test strategy proving enforcement is real, not theatrical.

**Key insight**: Mutation tests that remove infrastructure (core.hooksPath, hook files, config) prove enforcement fires. Control group (no-framework baseline) proves framework causes behavioral change.

**Impact**: Infrastructure validation tests shipped (PR #27), proving the enforcement layer works under mutation.

---

## Rough Specs & Structural Nudging (v0.25.8, 2026-02-14)

### Making Discovery Profile Spec-Aware Without Blocking

**User direction**: Discovery profile users shouldn't be forced through formal spec process, but should get gentle nudges toward capturing success criteria. "Starting rough is OK" — the framework should encourage any form of criteria rather than demanding formal specs.

**Key design decisions**:
- Non-blocking reminders in pre-commit checklist for discovery profile
- Success Criteria section in WIP.md templates
- `ag done` shows `[Discovered]` marker count and prompts spec review
- Removed `## Project Phase` from STATUS.template.md — dead code

**Impact**: Discovery profile gets spec awareness without the overhead of formal tracking.

---

## Profile Rename (v0.26.0, 2026-02-15)

### Clean Naming: Core → Discovery, Core+PM → Formal

**User direction**: The old names (`core`, `core+product`) were technical jargon that didn't communicate the actual usage difference. Renamed to `discovery` (exploratory work) and `formal` (spec-driven development). Clean break — no backward compatibility normalization.

**Key decisions**:
- `enable-pm.sh` → `enable-formal.sh`
- 18+ files updated across scripts, templates, documentation, tests, agent instructions
- No normalization code — old names simply stop working

**Impact**: Profile names now communicate their intent clearly to new users.

---

## Settings-Over-Profiles Architecture (v0.27.0, 2026-02-16)

### Individual Setting Overrides

**User insight**: The all-or-nothing problem — users couldn't customize one behavior (e.g., "I want feature tracking but not blocking WIP") without switching their entire profile. Every `if profile == "formal"` check was a maintenance burden.

**User direction**:
- Profiles become presets that set bundles of defaults; all framework logic checks individual settings
- `ag set` command for individual overrides without changing profile
- Resolution chain: explicit > profile preset > fallback default
- Settings documentation should live in DEVELOPER_GUIDE.md (not agent-facing workflows/)
- Development ideas tracked in ISSUES.md rather than inline docs

**User catch**: Missing F-XXXX / acceptance criteria post-implementation — led to I-0002 (plan mode bypasses spec-first workflow) and I-0003 (durable plan artifacts).

### Programmatic Spec-First Gate (F-0132)

**User direction** (from I-0002): Plan mode + session continuation are blind spots for "create F-XXXX FIRST" — the plan file feels like "we already planned it" but it's NOT a feature spec.

**Result**: `ag plan F-XXXX` blocks if not in FEATURES.md. `ag implement F-XXXX` blocks if no acceptance criteria. `SKIP_SPEC_CHECK=1` escape hatch. Gates only active when `feature_tracking=yes`.

### Durable Plan Artifacts (F-0133)

**User direction** (from I-0003): Plans in `.claude/plans/` are tool-specific and session-scoped — they get lost. Approved plans should be git-tracked in `.agentic-journal/plans/`.

**Result**: `ag plan --save <source-file> F-XXXX` command. CLAUDE.md instructs agents to save plans after approval. 16 historical plans archived from `.claude/plans/`.

### Skill Routing & Review-After-PR

**User direction**: Agents were confusing framework skills (`/review`, `/test`) with built-in Task tool agents. After creating PRs, agents should proactively offer code review.

**Result**: CLAUDE.md template now explicitly documents: framework roles use Skill tool, NOT Task tool's subagent_type. PR rule includes: "then offer: Want me to run `/review` on this PR?"

### DEVELOPER_GUIDE Rewrite (F-0134, v0.27.1)

**User insight**: DEVELOPER_GUIDE tells users to "run `ag implement F-XXXX`" — but users don't know feature numbers. Scripts should work behind the scenes; user guidance should use natural workflow language.

**User direction during implementation**:
- "The user is not the quality gate" — the framework's gates handle quality; the user makes decisions and sets direction
- "It is still framing scripts as something the user uses on a daily basis, but that shouldn't be the case" — this is a chat-first framework, scripts exist for the agent to use behind the scenes
- "The guide should quickly mention why scripts exist in a framework that is supposed to be an easy-to-use tool for AI development with a chat interface"
- Insisted on plan-review loop before implementation (plan → reviewer agent → revision → re-review → approved)
- Caught incorrect NFR.md removal — NFR.template.md is a real framework template

**Result**: Section 1 rewritten from "How You Help the Framework" (user-serves-framework) to "How It Works" (chat-first, framework-serves-user). "Why 30+ Scripts Exist" section added. Daily Workflows reframed as conversation, with manual commands as fallback. All user-facing prompts rewritten as natural language.

### Centralized TODO Tracking (Task #12)

**User insight**: Ideas and tasks are scattered across HUMAN_NEEDED.md, STATUS.md, ISSUES.md, and FEATURES.md with no single inbox. Need a solid mechanism for logging ideas/tasks in a central place.

**Impact**: Planned for design and implementation.

---

**Framework Repository**: https://github.com/tomgun/agentic-framework
**Current Version**: v0.27.0
**License**: Dual-license (GPL-3.0 for framework, proprietary OK for products)
**Status**: Production-ready, battle-tested, actively maintained, formally specified, self-dogfooding
**LLM Tests**: 48 behavioral test scripts

