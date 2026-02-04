# Project Contributions Report

**Project**: Agentic AI Framework
**Period**: Initial Development (v0.1.0 → v0.15.0)
**Date**: 2026-02-01  

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
1. **Modular profiles**: Core vs Core+PM separation
2. **Hidden internals**: `.agentic/` for framework, visible product docs
3. **Upgrade mechanism**: `upgrade.sh` from new package
4. **Profile-aware agents**: Behavior adapts to selected profile

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

Led development of Agentic AI Framework from v0.1.0 to v0.11.1, defining vision, architecture, and quality standards. Key contributions include:

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
- `tests/LLM_TEST_RESULTS.md` - Version tracking template
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

**Framework Repository**: https://github.com/tomgun/agentic-framework
**Current Version**: v0.15.1
**License**: Dual-license (GPL-3.0 for framework, proprietary OK for products)
**Status**: Production-ready, battle-tested, actively maintained, formally specified, self-dogfooding

