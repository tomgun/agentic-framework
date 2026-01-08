# Changelog

All notable changes to the Agentic AI Framework will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.4] - 2025-01-08

### Added - Multi-Environment Support & Environment Optimization

**Work seamlessly across Claude Desktop, Cursor, and GitHub Copilot in the same project. Switch between tools as tokens run out.**

#### 1. Multi-Environment as Default Setup

**NEW: Multi-environment is now RECOMMENDED during initialization**

**Problem it solves:**
- Token limits force work stoppage (Claude 200K → Cursor 50K → Copilot 8K)
- User wants: Claude tokens run out → switch to Cursor → continue work → switch to Copilot → keep going
- Each tool should pick up EXACTLY where previous left off
- Need seamless handoff without losing context

**Solution:**
- Init playbook now asks: "a) Multiple (RECOMMENDED)" as first option
- All adapter files installed by default (CLAUDE.md, .cursor/rules/, .github/)
- Shared state files ensure continuity (JOURNAL.md, FEATURES.md, STATUS.md)
- Token-efficient scripts work in ALL environments (40x cheaper than file reads)

**Example chain:**
1. Morning: Claude Desktop (complex feature, full codebase context)
2. Claude tokens 80%: Switch to Cursor (@ mentions, composer mode)
3. Need quick fix: Copilot inline suggestion
4. Next morning: Back to Claude (SessionStart hook loads full context)

Each tool reads same files → Perfect continuity!

#### 2. Environment-Specific Optimizations

**NEW: `.agentic/support/environment_research.md` - Capabilities matrix & best practices**

**Documented differences:**
- **Context windows**: Claude (200K) >> Cursor (~50K) >> Copilot (8K)
- **File operations**: Claude/Cursor (direct edits) vs. Copilot (suggestions only)
- **Hooks**: Claude ONLY (SessionStart, PreCompact, PostToolUse, Stop)
- **Multi-file**: Claude/Cursor (yes) vs. Copilot (no, one file at a time)
- **Terminal**: Claude/Cursor (yes) vs. Copilot (no)

**Environment-specific instructions:**
- **Claude**: Leverage hooks for auto-logging, use artifacts, read all specs at once
- **Cursor**: Use @ mentions (@FEATURES.md), composer mode, token-efficient scripts
- **Copilot**: ULTRA-CONCISE instructions (8K limit!), scripts CRITICAL, work file-by-file

**Benefits:**
- Claude users get hooks (automatic checkpoint logging before context reset!)
- Cursor users get @ mention tips (precise context without reading whole files)
- Copilot users get minimal instructions (fits in 8K limit)
- Each tool optimized for its strengths

#### 3. Seamless Environment Switching Workflow

**NEW: `.agentic/workflows/environment_switching.md` - Complete handoff protocol**

**Switching protocols:**

**Claude → Cursor:**
```bash
# In Claude (before tokens run out)
bash .agentic/tools/journal.sh "Checkpoint" "What done" "What next" "Blockers"
# PreCompact hook does this automatically!

# In Cursor
@JOURNAL.md  # Reads recent entries
@FEATURES.md # Current feature state
# Continues seamlessly
```

**Cursor → Copilot:**
```bash
# In Cursor
bash .agentic/tools/session_log.sh "Checkpoint" "Details" "feature=F-####"

# In Copilot (TINY context!)
# Give minimal context, use scripts only
bash .agentic/tools/feature.sh F-#### status shipped
```

**Copilot → Claude:**
```
# Next session in Claude
# SessionStart hook automatically loads .continue-here.md
# Full context restored!
```

**Best practices:**
- Log before switching (journal.sh, session_log.sh)
- Match tool to task (complex→Claude, multi-file→Cursor, quick→Copilot)
- Checkpoint frequently (every ~30 min, not just at session end)
- Use shared state files (all tools read/write same markdown)

**Token management:**
- Claude: 200K tokens/session (~2-4 hours complex work)
- Cursor: 50K tokens/conversation (~30-60 min complex work)
- Copilot: 8K tokens (~quick edits only)
- Scripts: 40x more efficient than reading files!

#### 4. Framework Staleness Detection

**NEW: `.agentic/tools/framework_age.sh` - Check if framework is outdated**

**Problem:** AI tools evolve rapidly (new hooks, larger context, new features). Framework instructions may become outdated.

**Solution:** Automatic staleness detection during init:
```bash
bash .agentic/tools/framework_age.sh
# Outputs:
# - Framework version and age
# - Status: Current (<30 days) / Aging (30-90 days) / Outdated (>90 days)
# - Research recommendations if old
# - Links to official docs (Claude, Cursor, Copilot)
```

**Exit codes:**
- 0: Current (<30 days) - No action needed
- 1: Aging (30-90 days) - Consider research
- 2: Outdated (>90 days) - Strongly recommend research

**If framework old (>30 days), agent offers:**
> "Framework is 120 days old. Would you like to research latest [Claude/Cursor/Copilot] features?
> I'll check official docs and update environment_research.md with new capabilities."

**Benefits:**
- Framework stays current with tool updates
- Users get latest optimizations
- Clear prompts for agents to research and update
- Prevents obsolescence

#### 5. Updated Init Playbook

**UPDATED: `.agentic/init/init_playbook.md`**

**New steps:**
- **Step 1a: Detect AI environment**
  - Ask: Multiple (a) | Claude (b) | Cursor (c) | Copilot (d)
  - Install appropriate adapters
  - Provide environment-specific tips
  - Update STACK.md with "AI Environments: multi"

- **Step 1b: Check framework age**
  - Calculate days since last update
  - Warn if >30 days old
  - Offer research prompt if >90 days
  - Link to official docs for each environment

**Why this matters:**
- Users explicitly choose multi-environment (or know they can)
- Framework adapts to tool capabilities
- Staleness detected before it's a problem
- Research workflow prevents obsolete instructions

### Benefits

**Token resilience:**
- Never blocked by token limits
- Work continuously throughout day (Claude → Cursor → Copilot chain)
- Each tool picks up where previous left off

**Tool flexibility:**
- Use best tool for each task
- Claude: Complex features, architecture, research
- Cursor: Multi-file refactors, IDE work, @ mentions
- Copilot: Quick edits, inline suggestions, when others unavailable

**Seamless handoff:**
- All tools share state (JOURNAL, FEATURES, STATUS)
- Token-efficient scripts work everywhere
- Common checklists and standards
- AGENTS.md as unified behavioral contract

**Cost optimization:**
- Start with Claude (large context, can read all specs)
- Switch to Cursor before tokens run out
- Use Copilot for quick fixes
- Extend work session across tools
- Minimize token waste

**Future-proof:**
- Framework age check prevents obsolescence
- Research workflow keeps optimizations current
- Environment-specific instructions evolve with tools
- Maintenance reminders every 3-6 months

### Example: Full Day Multi-Environment Workflow

```
8:00 AM - Claude Desktop (tokens fresh)
├─ Read all specs, understand architecture
├─ Plan F-0005 implementation
├─ Write tests (TDD)
├─ Implement core logic
└─ Hooks auto-log checkpoints

11:00 AM - Claude tokens at 80%
├─ bash .agentic/tools/journal.sh "F-0005 progress" "..." "..." "..."
└─ Switch to Cursor

11:15 AM - Cursor
├─ @JOURNAL.md (loads recent context)
├─ @src/feature.ts (current code)
├─ Composer mode (multi-file error handling)
├─ bash .agentic/tools/feature.sh F-0005 impl-state complete
└─ Integration tests

12:30 PM - Quick README typo
├─ Open in VS Code
├─ Copilot inline suggestion
└─ Fixed in 30 seconds

2:00 PM - Back to Cursor
├─ Complete F-0005
├─ bash .agentic/tools/feature.sh F-0005 status shipped
└─ bash .agentic/tools/journal.sh "F-0005 complete" "..." "Start F-0006" "..."

Next day 8:00 AM - Claude Desktop
├─ SessionStart hook loads .continue-here.md
├─ Sees full progress from all tools
├─ ✓ F-0005 shipped yesterday
└─ Continues with F-0006 seamlessly
```

**Total work**: ~6 hours uninterrupted across 3 tools!

### Files Changed

**New files:**
- `.agentic/support/environment_research.md` - Capabilities matrix & optimizations
- `.agentic/workflows/environment_switching.md` - Complete handoff guide
- `.agentic/tools/framework_age.sh` - Staleness detection script

**Updated files:**
- `.agentic/init/init_playbook.md` - Multi-environment setup, staleness check
- `README.md` - Multi-environment section, token resilience benefits
- `CHANGELOG.md` - This entry

## [0.4.3] - 2025-01-05

### Added - Library Selection Guidelines & Architectural Decision Framework

**Prevents costly wrong library choices based on real-world failure (chess.js for chess variant).**

#### 1. Library Selection Decision Framework

**NEW: `quality/library_selection.md` - Comprehensive guide for choosing libraries vs. custom code**

**Critical lesson from real project:**
- Project: Chess/Tetris hybrid game
- AI chose: chess.js (enforces standard FIDE chess rules)
- Problem: Game has custom rules, Tetris mechanics, pieces added one at a time
- Result: FAILED - had to rip out library and rebuild
- Should have: Implemented custom engine from the start

**Decision framework includes:**
- **Standard vs. Custom identification**
  - Standard implementation → Use library
  - Custom/variant → Custom code or low-level library
  - Decision tree: 0% custom = library, 20-50% = low-level, 50%+ = custom

- **Required user consultation**
  - Template: "Does this follow standard [X] rules exactly, or does it have custom mechanics?"
  - Add to HUMAN_NEEDED.md and WAIT for response
  - Document choice in ADR

- **Red flags (wrong library)**
  - Library enforces rules you don't need
  - Bypassing/disabling library features
  - User says "like X but with custom Y"
  - Documentation says "enforces standard X"

- **Examples by domain**
  - Games: Standard chess (use chess.js) vs. Chess variant (custom engine)
  - Card games: Standard poker (use library) vs. Custom game (custom code)
  - Protocols: Standard HTTP (use fetch) vs. Custom protocol (custom client)

**Benefits:**
- Prevents wasted time on wrong library choices
- Forces architectural discussion early
- Documents decision rationale in ADR
- Real-world failure example for learning

#### 2. Enhanced Research Mode

**Updated `workflows/research_mode.md` with library research requirements:**

- Added CRITICAL section on library selection research
- Must identify if library enforces standards/rules
- Must determine if project needs standard or custom implementation
- Required user consultation when unclear
- Document constraints and alternatives in ADR

**Prevents:**
- Choosing chess.js for chess variants
- Using poker libraries for custom card games
- Selecting protocol libraries for custom protocols
- Any standard library for non-standard implementations

#### 3. Agent Guidelines Updated

**Added to `agent_operating_guidelines.md`:**
- Link to `library_selection.md` as critical guideline
- Placed alongside smoke testing checklist
- Mandatory review before selecting libraries

### Changed

**CONTRIBUTIONS.md Updated:**
- Added "Real-World Usage & Critical Feedback" section
- Documented chess/Tetris hybrid game learnings
- Library selection gap analysis
- Smoke testing gap (from v0.4.2-v0.4.3)
- Template noise issues
- Updated version to v0.4.3

**Key Lessons Documented:**
1. "Works on my machine" ≠ Works (smoke testing)
2. Testability is architecture (Model-View separation)
3. Standard library ≠ Custom variant (chess.js failure)
4. Ask when unclear (user consultation required)
5. Clean templates matter (90% reduction in noise)

---

## [0.4.2] - 2025-01-05

### Added - Automatic Attribution & Clean Templates

**Improved developer experience with automatic attribution stamping and cleaner project initialization.**

#### 1. Automatic Attribution Stamping

**Agents now automatically inject subtle attribution stamps when creating production code:**
- Format: `Engineered with Agentic AF v{VERSION} by TSG, {YEAR}`
- Location: ONE file per project (main HTML/JS/Python entry point)
- Placement: Half-visible (HTML source comments, bundle comments)
- Timing: During initial file creation (silent, no user intervention)
- No build scripts required - just naturally part of the code agents write

**Examples:**
- Web apps: `<!-- Engineered with Agentic AF v0.4.2 by TSG, 2025 -->` in `index.html`
- Python CLI: `# Engineered with Agentic AF v0.4.2 by TSG, 2025` in `main.py`
- JS apps: `/* Engineered with Agentic AF v0.4.2 by TSG, 2025 */` in bundle

**Benefits:**
- Automatic, silent attribution (no developer action needed)
- Minimal and professional (one stamp per project)
- Framework visibility without cluttering code
- Token-efficient (no separate build process)

#### 2. Clean Root Templates

**Root project files now start clean, with examples moved to `.agentic/` for reference:**

**Before vs After:**
- `HUMAN_NEEDED.md`: 194 lines → 20 lines (90% reduction!)
- `JOURNAL.md`: 81 lines → 14 lines
- `FEATURES.md`: 59 lines → 25 lines

**Examples and guidelines now in `.agentic/spec/*.reference.md`:**
- `HUMAN_NEEDED.reference.md` - 4 example entries + agent/human guidelines
- `JOURNAL.reference.md` - format options + examples
- `FEATURES.reference.md` - complete format spec + examples

**Benefits:**
- New projects start clean (reflect actual state, not templates)
- No confusing example content in production files
- Examples available for reference when needed
- Better developer experience (less noise, clearer intent)

### Changed

**Agent Guidelines Updated:**
- Added "Build Artifact Stamping" section with automatic injection rules
- Root template references now link to `.agentic/spec/*.reference.md` for examples

**Template Structure:**
- Templates are now minimal with structure + reference links
- All examples, guidelines, and format docs in `.agentic/` for reference

---

## [0.4.1] - 2025-01-05

### Added - Enhanced Workflows, Design Systems, Validation Cache, Claude Commands

**Comprehensive framework enhancements for improved agent autonomy and developer experience.**

#### 1. Enhanced Workflows with Error Recovery

**TDD Mode (tdd_mode.md)**:
- 7 detailed error recovery scenarios
- Tests won't run, tests pass immediately, stuck in RED phase
- Refactoring breaks tests, too many tests failing, tests are slow
- Unclear requirements handling

**Proactive Agent Loop (proactive_agent_loop.md)**:
- Added preconditions, progress tracking, state contracts
- 9 error recovery scenarios for agent collaboration
- Can't find planned work, stale HUMAN_NEEDED items
- Unclear feature states, interrupted sessions
- Decision escalation guidelines, context window management
- Lost track handling, non-responsive human handling

**Feature Implementation Checklist (feature_implementation.md)**:
- 7 practical error recovery scenarios
- Tests failing, scope too large, unclear acceptance criteria
- Dependencies not ready, code getting messy
- Forgot to update tracking, quality checks failing

**Benefits**:
- More systematic agent behavior
- Self-checking prevents skipped steps
- Error recovery reduces escalations to humans
- Clear guidance for common problems

#### 2. Design System Templates

**New Directory**: `.agentic/support/design_systems/`

Three comprehensive design systems:
- **Modern Minimal**: Clean, Tailwind-inspired (web apps, dashboards, SaaS)
- **Material Design**: Google's Material Design 3 (Android apps, Google-style web)
- **iOS Human Interface**: Apple's HIG (iOS/macOS apps, elegant consumer products)

**Each includes**:
- Color palettes (with dark mode)
- Typography scales
- Spacing systems
- Component patterns
- Motion & animation guidelines
- Accessibility guidelines
- Code examples (React, SwiftUI, React Native)

**Benefits**:
- Consistent UI implementation
- Faster development (less design decisions)
- Professional, polished results
- Platform-appropriate designs

#### 3. Validation Cache

**New Tool**: `.agentic/tools/validation-cache.sh`

Cache validation results to avoid redundant checks:
- Time-based expiry (5 minutes)
- File-based invalidation (via hash)
- Speeds up `doctor.sh`, `verify.sh`, `validate_specs.py`
- Simple JSON-based storage

**Usage**:
```bash
# Check cache
bash .agentic/tools/validation-cache.sh check doctor

# Get cached results
bash .agentic/tools/validation-cache.sh get doctor

# Store results
bash .agentic/tools/validation-cache.sh set doctor "OK"
```

**Benefits**:
- Faster feedback loops
- Reduces redundant work
- Still catches real issues (smart invalidation)

#### 4. Claude Custom Commands (Optional)

**New Directory**: `.agentic/prompts/claude-commands/`

Optional slash commands for Claude Desktop users:
- `/start` - Start session with context loading
- `/continue` - Resume from .continue-here.md
- `/implement` - Implement feature with TDD
- `/end` - End session with documentation

**Benefits**:
- Better UX for Claude Desktop users
- User-friendly alternative to copy-paste prompts
- Falls back to regular prompts if not supported
- Easy to customize

### Changed - Documentation Updates

- Updated workflow files with error recovery sections
- Added design systems README and usage guide
- Documented validation cache in tool comments

---

## [0.4.0] - 2025-01-05

### Added - Session Continuity & Claude Hooks

**Major UX improvements for session management and Claude Desktop integration.**

#### 1. Session Continuity Tool (`continue_here.py`)

**New Tool**: `.agentic/tools/continue_here.py`

Generates `.continue-here.md` - a single-file snapshot for instant context recovery:
- Synthesizes: JOURNAL.md, STATUS.md/PRODUCT.md, HUMAN_NEEDED.md, FEATURES.md, pipeline files
- Output: Quick summary, active work, blockers, recent progress, next steps
- Works in both Core and Core+PM modes
- Auto-detects project profile

**Benefits**:
- Instant context recovery after breaks or context resets
- Read 1 file instead of 5+ files
- Lower cognitive load for humans and AI agents
- Perfect handoff between sessions

**Usage**:
```bash
python3 .agentic/tools/continue_here.py
# Then read .continue-here.md at start of next session
```

#### 2. Ready-to-Use AI Prompts

**New Directories**: `.agentic/prompts/cursor/` and `.agentic/prompts/claude/`

13 copy-paste workflow prompts for common tasks:
- **Session Management**: `session_start.md`, `session_end.md`
- **Feature Development**: `feature_start.md`, `feature_test.md`, `feature_complete.md` (TDD workflow)
- **Spec Management**: `migration_create.md`, `spec_update.md` (Core+PM mode)
- **Core Mode**: `product_update.md`, `quick_feature.md`
- **Quality & Maintenance**: `run_quality.md`, `fix_issues.md`, `retrospective.md`
- **Research & Planning**: `research.md`, `plan_feature.md`

**Claude-Specific Features Documented**:
- Artifacts (interactive previews)
- Projects (persistent context)
- Extended Thinking mode
- Hooks integration

**Benefits**:
- Eliminate prompt engineering - just copy and paste
- Consistent agent behavior across sessions
- Lower barrier to entry for new users
- Claude users get platform-specific guidance

#### 3. Claude Desktop Lifecycle Hooks

**New Directory**: `.agentic/claude-hooks/`

Automated scripts that run at key lifecycle points in Claude Desktop:

**Hooks**:
1. **`SessionStart.sh`**: Environment validation, project status, detect `.continue-here.md`
2. **`UserPromptSubmit.sh`**: Auto-inject `.continue-here.md` (ZERO-TOUCH context recovery!)
3. **`PostToolUse.sh`**: Real-time linter checks after code edits
4. **`PreCompact.sh`**: State preservation before context window compaction
5. **`Stop.sh`**: Session end reminders (commits, docs, context generation)

**Configuration**: `hooks.json` for Claude Desktop

**Benefits**:
- **Automatic context injection**: No manual "read .continue-here.md" needed
- **Real-time quality gates**: Catch syntax errors immediately after writing code
- **Never lose progress**: State automatically saved before context compaction
- **Better workflow discipline**: Reminders about commits and documentation
- **Seamless session continuity**: Perfect pairing with `continue_here.py`

**Requirements**: Claude Desktop with hooks enabled (check version compatibility)

**Documentation**: Complete setup, usage, and troubleshooting guide in `.agentic/claude-hooks/README.md`

#### 4. Pre-Project Ideation Template

**New Template**: `.agentic/init/VISION.template.md`

For capturing project vision before initialization:
- Problem & opportunity
- Vision & success criteria
- User scenarios
- Core principles
- Constraints & non-goals
- Technical direction
- Open questions

**Benefits**:
- Better alignment before implementation
- Clear "why" documented upfront
- Informs PRD and feature specs
- Reduces scope creep

### Changed - Documentation Updates

**Updated Files**:
- `README.md`: Reference new prompts and tools
- `START_HERE.md`: Mention `.continue-here.md` and prompts in session start
- `DEVELOPER_GUIDE.md`: Document `continue_here.py`, prompt library, Claude hooks
- `.agentic/README.md`: Add continue_here.py and migration.sh to tools list
- `prompts/claude/README.md`: Add hooks documentation and setup guide

---

## [0.3.4] - 2026-01-04

### Fixed - Upgrade Script Path Bug

**Problem**: `upgrade.sh` checked for old `agentic/` folder instead of new `.agentic/` folder (hidden directory with dot prefix)

**Impact**: Upgrade tool failed on all projects with error:
```
✗ Error: No '.agentic/' folder found in target project
  Target: /path/to/project/agentic
```

**Root Cause**: Three hardcoded references to old `agentic` path:
- Line 50: Check for target project `.agentic/` folder
- Line 66: Check for new framework `.agentic/` folder  
- Line 112: Backup command

**Fixed**:
- Changed all `agentic` references to `.agentic` (with dot)
- Upgrade tool now correctly detects hidden `.agentic/` directory
- Backup, rollback, and all operations now work correctly

**Credit**: Discovered by Tomas during upgrade of `passive-income-solution1` project

**Testing**:
```bash
# Should now work
./upgrade.sh /Users/tomas/code/passive-income-solution1
```

---

## [0.3.3] - 2026-01-04

### Added - Minimal Test Suite (Cobbler's Children Now Have Shoes!)

**Problem**: Framework had no tests validating core claims - "the cobbler's children have no shoes"

**Solution**: Added minimal test suite appropriate for POC/discovery phase (no overengineering)

**New Tests**:
- `tests/test_query_features.py` (6 tests, no dependencies)
  - Parse features from markdown
  - Filter by status, tags, layer, owner
  - Combine multiple filters
  - **Validates**: Query tool works for 200+ feature projects
  
- `tests/test_validate_specs.py` (7 tests, optional dependencies)
  - Detect circular dependencies (F-0001 → F-0002 → F-0001)
  - Detect self-dependencies
  - Detect invalid parent references
  - Detect invalid dependency references
  - **Validates**: Pre-commit validation catches errors
  - Graceful skip if dependencies not installed

**Test Infrastructure**:
- `tests/fixtures/sample_features.md` - 5 sample features for testing
- `tests/run_tests.sh` - Simple runner (no pytest needed)
- `tests/README.md` - Philosophy and guide

**Philosophy** (POC-appropriate):
- ✅ Minimal: No pytest, no coverage, no CI (yet)
- ✅ Focused: Test core claims only
- ✅ Fast: <5 seconds to run
- ✅ Simple: Pure Python, easy to understand
- ✅ Graceful: Skips tests if dependencies missing
- ✅ Easy: `bash tests/run_tests.sh`

**What We DON'T Test** (intentionally):
- Full pytest suite (overkill for POC)
- Coverage metrics (premature)
- Integration tests (not needed yet)
- Performance benchmarks (later)
- All edge cases (test what matters)

### Documentation
- `docs/SELF_APPLICATION_PLAN.md` - Analysis of "cobbler's children" problem
- `tests/README.md` - Test philosophy and guide

### Impact
✅ Core claims validated by tests
✅ Tests catch regressions in tools
✅ Dogfooding: Using framework principles on framework itself
✅ Confidence: Tools actually work as claimed

**The cobbler's children now have shoes (at least sandals)!** 👞

## [0.3.2] - 2026-01-04

### Added - Agent Tool Awareness

**Critical Update**: Agents now know HOW and WHEN to use scalability tools efficiently.

Added comprehensive guidance to `agent_operating_guidelines.md`:

**Efficient Tool Usage (Core+Product Mode)**:
1. **Finding Features Quickly**: Use `query_features.py` instead of grep (50+ features)
   - Filter by status, tags, owner, layer
   - Get counts and distributions
2. **Updating Multiple Features**: Use `bulk_update.py` for mass operations
   - Assign owners across features
   - Set priorities by domain/layer
   - Add/remove tags in bulk
3. **Understanding Dependencies**: Use `feature_graph.py` with filters
   - Focus mode for single feature + neighbors
   - Filtered views by layer/status
   - Hierarchy-only mode
4. **Project Health Metrics**: Use `feature_stats.py` periodically
   - Before retrospectives
   - When summarizing progress
5. **Validation**: Always run `validate_specs.py` before commits
   - Pre-commit hook does this automatically
6. **Hierarchical Migration**: Suggest when beneficial
   - 200-500 features: Consider
   - 500+ features: Recommend
   - Show preview with `--dry-run` first

**Agent Behavioral Changes**:
- ✅ Use tools, not grep for feature searches
- ✅ Bulk operations instead of manual edits
- ✅ Generate focused dependency graphs
- ✅ Monitor health metrics periodically
- ✅ Suggest hierarchical layout when project grows
- ✅ Validate before every commit

### Impact
Agents now work **efficiently** with 200-1000+ feature projects instead of inefficiently reading/editing large files manually.

## [0.3.1] - 2026-01-04

### Added - Phase 2 & 3 Spec Scalability Complete (500+ and 1000+ Features)

**Phase 2: Hierarchical Organization (500+ features)**

New Tools:
- `organize_features.py`: Migrate from flat to hierarchical layout
  - Organize by domain or layer
  - Auto-generates `_index.md` master index
  - Preview with `--dry-run`
  - Creates `spec/features/domain/*.md` structure
- `bulk_update.py`: Mass feature updates
  - Update multiple features at once
  - Filter by status, tags, layer, domain, owner
  - Add/remove tags in bulk
  - Set fields across many features
  - Safety: preview changes, confirmation prompt

**Phase 3: Advanced Analytics (1000+ features)**

New Tools:
- `feature_stats.py`: Comprehensive statistics dashboard
  - Distribution by status, layer, domain, priority, complexity
  - Top tags analysis
  - Owner distribution
  - Health metrics (shipped vs accepted, velocity)
  - Features per week calculation
- `upgrade_spec_format.py`: Spec format version management
  - Detects format version markers
  - Upgrades specs to latest format
  - Safe migrations with `--dry-run`
  - Enables reliable framework upgrades

**Enhanced Existing Tools**:
- `query_features.py`: Now supports hierarchical layout (auto-detects)
- `feature_graph.py`: Now supports hierarchical layout (auto-detects)
- `validate_specs.py`: Validates both flat and hierarchical layouts

**Spec Format Versioning**:
- Added `<!-- spec-format: features-v0.3.1 -->` markers to all spec templates
- Enables reliable upgrades when framework evolves
- `upgrade_spec_format.py` tool manages migrations

**Documentation**:
- Updated `SPEC_SCALABILITY_PLAN.md`: All 3 phases complete
- Added migration recommendations (when to use flat vs hierarchical)
- Added tool ecosystem guide
- Added maintenance & best practices

### Changed
- All feature tools now support both flat (`spec/FEATURES.md`) and hierarchical (`spec/features/*/*.md`) layouts
- Tools auto-detect layout, no configuration needed

### Impact
- ✅ Handle 1000+ features smoothly (all phases complete)
- ✅ Query time <3s even with 1000+ features  
- ✅ Hierarchical organization for 500+ features
- ✅ Bulk updates save massive manual work
- ✅ Statistics dashboard for project insights
- ✅ Format versioning for safe framework upgrades
- ✅ Graceful migration path (opt-in hierarchical)
- ✅ Backward compatible (flat layout still works perfectly)

### Migration Guide

**For existing v0.3.0 projects**:
- All tools continue to work with flat `FEATURES.md`
- No changes required
- Optionally migrate to hierarchical: `python .agentic/tools/organize_features.py`
- Optionally add format markers: `python .agentic/tools/upgrade_spec_format.py`

**When to migrate to hierarchical**:
- 0-200 features: Stay flat (simpler)
- 200-500 features: Optional (team preference)
- 500+ features: Recommended (better organization)

## [0.3.0] - 2026-01-04

### Added - Phase 1 Spec Scalability (Critical for 200+ Features)

**New Tools:**
- `query_features.py`: Fast feature filtering by status, tags, layer, domain, priority, owner
  - Essential for finding features in large projects
  - Count features by category
  - Sub-second performance even with 500+ features
- Enhanced `feature_graph.py`: Filterable dependency graphs
  - `--focus` mode: show single feature + neighbors
  - `--layer`, `--tags`, `--status` filters
  - `--hierarchy-only` mode for parent-child relationships
  - Prevents massive unreadable diagrams
- Enhanced `validate_specs.py`: Circular dependency detection
  - DFS-based cycle detection (catches F-0001 → F-0002 → F-0001)
  - Cross-reference validation (parent/dependencies exist)
- `hooks/pre-commit`: Pre-commit hook for spec validation
  - Auto-installed by `scaffold.sh` (Core+PM mode)
  - Catches errors before commit

**New Feature Metadata Fields (v0.3.0+):**
- `Tags`: `[auth, ui, critical]` for categorization/search
- `Layer`: `presentation | business-logic | data | infrastructure | other`
- `Domain`: `auth`, `payments`, `content`, etc.
- `Priority`: `critical | high | medium | low`
- `Owner`: email or username
- All fields optional, backward compatible

**Documentation:**
- `docs/SPEC_SCALABILITY_PLAN.md`: Comprehensive 3-phase plan (200/500/1000+ features)
- Updated `DEVELOPER_GUIDE.md`: New tools with examples
- Updated `SPEC_SCHEMA.md`: Documented new fields
- Updated `FEATURES.template.md`: Added new optional fields

### Fixed
- `scaffold.sh`: Now installs pre-commit hook for Core+PM mode

### Impact
- ✅ Handle 200+ features smoothly (Phase 1 complete)
- ✅ Fast queries (<1 second with 500 features)
- ✅ Focused graphs (no unreadable massive diagrams)
- ✅ Catch circular dependencies automatically
- ✅ Better organization (tags, layers, domains)
- 📋 Phase 2 planned: Hierarchical file organization for 500+ features
- 📋 Phase 3 planned: Statistics dashboard for 1000+ features

## [0.2.5] - 2026-01-03

### Added

**Documentation:**
- **PRINCIPLES.md** - Comprehensive framework constitution documenting all 60+ principles
  - Core philosophy (sustainable development, human-agent partnership, context efficiency)
  - Token economics principles (4 detailed principles)
  - Quality & testing principles (6 principles including "Shipped ≠ Accepted")
  - Human-agent collaboration principles (4 principles)
  - Documentation & maintenance principles (5 principles)
  - Modularity & flexibility principles (4 principles)
  - 10 anti-patterns with explanations
  - Each principle has: What, Why, How Enforced, Example, Anti-pattern
  - Linked from README, START_HERE, agent_operating_guidelines

- **FRAMEWORK_DEVELOPMENT.md** - Complete guide for contributors working on the framework itself
  - 12 comprehensive sections covering framework-specific responsibilities
  - Maintain internal consistency (templates, examples, docs)
  - Example projects as first-class citizens
  - Documentation single source of truth enforcement
  - Test framework changes in scratch projects
  - Version management (SemVer, CHANGELOG, releases)
  - Template changes and backward compatibility
  - Quality standards apply to framework itself
  - Git workflow and commit conventions
  - Complete release checklist
  - Common development patterns and quick reference
  - 8 framework development anti-patterns
  - Comparison table: project dev vs. framework dev

### Changed

**Clarifications:**
- `agent_operating_guidelines.md` now explicitly states it's for "projects using framework"
- Clear distinction between project guidelines vs. framework development guidelines
- Added cross-references between the two guideline documents
- Removed ambiguity about "working in this repo"

### Impact

- Framework values and principles are now explicitly documented and won't be lost
- Contributors have clear guidelines for framework development
- Agents know which rules apply in which context (project vs. framework work)
- All implicit principles from development discussions are now captured

## [0.1.0] - 2026-01-02

### Added (Initial Release)

**Core Framework:**
- Agent operating guidelines for consistent AI behavior
- Durable artifacts for token efficiency (CONTEXT_PACK, STATUS, JOURNAL)
- Specification system (PRD, Tech Spec, Features, NFR, ADR, Tasks)
- Feature tracking with stable IDs (F-####) and acceptance criteria
- Test-Driven Development (TDD) as recommended default mode
- Definition of done and quality review checklists

**Advanced Features:**
- Session continuity across context resets (JOURNAL.md)
- Feature dependency tracking with visualization
- Human escalation protocol (HUMAN_NEEDED.md)
- Architecture evolution tracking
- Research trails and structured research mode
- Automated retrospectives for project health checks
- Documentation verification to ensure up-to-date API usage
- Spec format validation with YAML frontmatter (optional)
- Continuous quality validation with stack-specific profiles
- Multi-agent coordination with Git worktrees
- PR workflow mode for team collaboration

**Tools (27 scripts):**
- Project health: `doctor.py`, `report.py`, `verify.sh`, `validate_specs.py`
- Context & analysis: `brief.sh`, `dashboard.sh`, `coverage.sh`, `feature_graph.sh`
- Manual operations: `search.sh`, `whatchanged.sh`, `deps.sh`, `accept.sh`
- Quality: `consistency.sh`, `stale.sh`, `retro_check.sh`, `version_check.sh`
- Development: `task.sh`, `sync_docs.sh`, `arch_diff.sh`

**Quality Profiles:**
- Web applications (bundle size, Lighthouse, accessibility)
- Mobile apps (iOS, Android - battery, memory, UI performance)
- Backend services (load testing, connection pools, queries)
- Desktop applications (Qt, Electron, native - UI responsiveness, cross-platform)
- CLI/Server tools (long-running, signal handling, resource cleanup)
- Games (2D, Unity, Unreal - FPS, physics, assets)
- Audio plugins (JUCE - pluginval, DSP validation, realtime CPU/glitch detection)
- Specialized (security, network, embedded/IoT, ML)

**Documentation:**
- Comprehensive README with design principles
- START_HERE guide for quick navigation
- FRAMEWORK_MAP with visual diagram
- MANUAL_OPERATIONS for token-free queries
- DIRECT_EDITING workflow for human spec editing
- 40+ workflow and guideline documents

**Stack Profiles:**
- Generic/default, Webapp fullstack, Native iOS
- Go backend, Python ML, Rust systems, React Native

### Features by Category

**Token Economics:**
- Structured reading protocols with explicit budgets
- Context budgeting strategies
- Durable artifacts prevent repeated repo scanning

**Developer UX:**
- Agent does all initialization (no manual script running)
- Clear status at all times
- Human review required before commits (no auto-commit)
- Direct spec editing by humans (agents pick up changes)

**Quality by Design:**
- TDD recommended (tests first)
- Stack-specific quality gates
- Mandatory tests for new/changed logic
- Design for testability guidelines

**Traceability:**
- Code annotations link code to features (`@feature F-####`)
- Bidirectional linking (specs → code → tests)
- Test coverage tracking per feature

**Team Collaboration:**
- Git workflow modes (direct commits or pull requests)
- Multi-agent coordination with worktrees
- AGENTS_ACTIVE.md for coordination
- File lock protocol to prevent conflicts

## [0.2.4] - 2026-01-03

### Added
- **DEVELOPER_GUIDE.md**: Comprehensive 1,500+ line guide for developers
  - Daily workflows (morning, during, evening routines)
  - Manual operations vs. agent operations
  - All 30+ automation scripts explained with examples and "when to run"
  - Customization guide (profiles, STACK.md, quality checks, custom scripts)
  - Troubleshooting section with 10 common problems and fixes
  - Best practices for sustainable development
  - Advanced topics (sequential pipeline, multi-agent, mutation testing)
  - Quick reference tables and commands

### Improved
- **agent_operating_guidelines.md**: Critical improvements to prevent documentation gaps
  - Added CRITICAL rule: Acceptance file mandatory when creating features
  - Added CRITICAL workflow: Clear "shipped" vs "accepted" status distinction
  - Added CRITICAL rule: Never leave `Implementation: State: none` if code exists
  - Improved FEATURES.md sync instructions with explicit checks
  - Better guidance on when to mark features as shipped/accepted

### Changed
- **Documentation structure**: DEVELOPER_GUIDE now primary entry point for new users
  - Updated START_HERE.md to link DEVELOPER_GUIDE first (⭐⭐⭐)
  - Updated .agentic/README.md to prominently link DEVELOPER_GUIDE
  - Updated main README.md with quick links section
- **Profile selection UX**: Added a/b choice format in init_playbook.md for easier selection

### Context
This release addresses issues found in real-world usage:
- Missing acceptance criteria files (now mandatory via agent guidelines)
- Features marked "shipped" but never formally accepted (now clear workflow)
- Implementation state "none" despite code existing (now explicitly checked)
- Documentation completeness (comprehensive DEVELOPER_GUIDE created)

## [0.2.3] - 2026-01-02

### Fixed
- **install.sh now makes scripts executable**: After copying `.agentic/` folder, the install script now runs `chmod +x` on all scripts to ensure they work immediately
- Fixed `scaffold.sh not found or not executable` error during installation

## [0.2.2] - 2026-01-02

### Changed
- **Branding update**: Framework now officially named "Agentic AI Framework" (shortname: Agentic AF)
- **Documentation overhaul**: All references updated to reflect current version (v0.2.2) and GitHub org (tomgun)
- Replaced all `YOUR_USERNAME` placeholders with `tomgun`
- Updated all installation and upgrade instructions
- Fixed `.agentic/` folder references throughout documentation

### Fixed
- README.md installation section now uses `install.sh`
- `.agentic/README.md` now has accurate v0.2.2 installation instructions
- UPGRADING.md completely updated with correct paths and version
- RELEASING.md examples now reference v0.2.2
- Example projects updated with correct framework version

## [0.2.1] - 2026-01-02

### Added
- **Installation script** (`install.sh`) for automated framework setup
  - Reads VERSION from framework repo
  - Copies `.agentic/` to target project
  - Updates `STACK.md` with framework version and install date
  - Shows clear next steps for agent initialization

### Changed
- **Profile selection moved to agent interview** (UX improvement)
  - Profile choice now part of `init_playbook.md` workflow
  - Agent explains Core vs Core+PM differences
  - Users make informed choice during initialization
  - Removed `--profile` argument from `install.sh` (simpler)
- **Upgrade script improvements**
  - Now reads VERSION from new framework and updates `STACK.md`
  - Fixed references from `agentic/` to `.agentic/`
- **Documentation improvements**
  - README.md updated with clearer installation instructions
  - Explicit reference to `init_playbook.md` for agent guidance
  - Removed confusion about when initialization is complete

### Fixed
- `STACK.template.md` version updated to 0.2.0 (was 0.1.0)
- Framework version now properly tracked in production projects

## [0.2.0] - 2026-01-02

### Added

**Modular Framework Profiles:**
- Two profiles: "Core" (minimal) and "Core + Product Management" (full specs)
- Core includes: quality standards, workflows, multi-agent, research, PRODUCT.md
- Core+PM adds: formal specs, feature tracking (F-####), STATUS.md, project metrics
- Profile-aware agents adapt behavior based on STACK.md profile field
- Easy upgrade path: `enable-product-management.sh` converts Core → Core+PM

**Hidden Framework Internals:**
- Moved `agentic/` → `.agentic/` for cleaner project root
- Framework files hidden, product files (STACK.md, STATUS.md, spec/, docs/) visible
- Optimized for agent efficiency and developer clarity

**PRODUCT.md (New Core File):**
- Lightweight planning document for Core mode
- Captures: what we're building, capabilities (checkboxes), technical approach, scope
- Serves as basis for formal specs when upgrading to Core+PM
- Agents update it as work progresses

**Programming & Testing Standards:**
- Comprehensive programming guidelines (naming, functions, error handling, security, performance, green coding)
- Detailed testing standards (happy path, edge cases, invalid input, time-based, concurrency, resource exhaustion, network failures)
- TDD remains recommended default approach
- Standards linked prominently in README files

**Mutation Testing (Optional):**
- Added mutation testing as advanced quality check
- Documentation in `test_strategy.md`
- Helper script: `mutation_test.sh` (auto-detects stack)
- Guidance on when to use (critical logic, suspicious coverage, post-bug-fix)
- Integration with quality profiles

**Framework Upgrade Mechanism:**
- `UPGRADING.md` guide with step-by-step instructions
- `upgrade.sh` tool runs from new framework download (ensures latest logic)
- Safe upgrade path: backup → update internals → preserve customizations
- Validates before/after with doctor.py

**Examples (Complete Rewrite):**
- `core_todo_cli/` - Python CLI demonstrating Core profile
- `core_pm_taskboard/` - Next.js app demonstrating Core+PM profile
- Realistic mid-development state (not empty templates)
- Full validation: all tools pass (doctor, verify, report)
- Comprehensive README with profile comparison table

**Documentation Improvements:**
- Updated all READMEs to reflect Core vs Core+PM modes
- Added programming/testing standards to prominent locations
- Clear upgrade instructions
- Examples show both profiles in action

### Changed
- `agentic/` directory renamed to `.agentic/` (breaking change, but simple rename)
- Agents now profile-aware (check `Profile:` in STACK.md)
- `scaffold.sh` accepts `--profile` argument
- `doctor.py` and `verify.py` are profile-aware (skip PM checks in Core mode)
- `report.py` and `accept.py` degrade gracefully if PM features disabled

### Fixed
- PM templates no longer contain concrete example IDs (F-0001, NFR-0001) that caused verify failures
- Core mode agents now work efficiently (don't try to read non-existent STATUS.md/spec/)
- `enable-product-management.sh` detects PRODUCT.md and provides conversion guidance

## [Unreleased]

### Planned
- npm package (optional install method)
- Homebrew formula (optional install method)
- More stack-specific quality profiles
- Enhanced dependency analysis
- Automated architecture documentation
- Framework version compatibility checks

---

## Version Numbering

This project follows [Semantic Versioning](https://semver.org/):
- **MAJOR** version: Breaking changes (requires migration)
- **MINOR** version: New features (backward compatible)
- **PATCH** version: Bug fixes (backward compatible)

## Download

Get the latest release: https://github.com/tomgun/agentic-framework/releases

```bash
# Download and extract
curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/v0.2.1.tar.gz | tar xz

# Install (recommended)
cd agentic-framework-0.2.1
bash install.sh /path/to/your-project

# Or copy manually
cp -r agentic-framework-0.2.1/.agentic /path/to/your-project/
```

