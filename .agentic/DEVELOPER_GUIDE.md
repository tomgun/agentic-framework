# Developer Guide: Working with Agentic AF

**Purpose**: Complete guide for developers using the Agentic AI Framework. Learn how to work manually, use automation tools, customize the framework, and collaborate effectively with AI agents.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Daily Workflows](#daily-workflows)
3. [Working with Agents](#working-with-agents)
4. [Manual Operations](#manual-operations)
5. [Automation & Scripts](#automation--scripts)
6. [Customization](#customization)
7. [Troubleshooting](#troubleshooting)
8. [Best Practices](#best-practices)
9. [Advanced Topics](#advanced-topics)

---

## Getting Started

### Installation

**Download and install the framework:**

```bash
# Download latest release
curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/v0.4.3.tar.gz | tar xz
cd agentic-framework-0.4.3

# Install into your project
bash install.sh /path/to/your-project

# Navigate to your project
cd /path/to/your-project
```

### Initialization

**Tell your AI agent:**

> "Read `.agentic/init/init_playbook.md` and help me initialize this project"

The agent will:
1. Ask what you're building
2. Offer profile choice (a=Core, b=Core+PM)
3. Interview you about tech stack
4. Create all necessary files
5. Set up quality checks for your stack

**Profile Selection:**

- **a) Core (Simple Setup)**: Quality standards, multi-agent, research, lightweight planning (`PRODUCT.md`)
  - Good for: Small projects, prototypes, external PM tools, quick experiments
  
- **b) Core + Product Management**: Everything in Core plus formal specs, feature tracking (`F-####` IDs), roadmap
  - Good for: Long-term projects (3+ months), complex products, audit trails

---

## Daily Workflows

### Morning: Start Your Work Session

```bash
# 1. Quick context recovery (recommended)
python3 .agentic/tools/continue_here.py  # Generates .continue-here.md

# 2. Read the summary
cat .continue-here.md

# 3. Check blockers
cat HUMAN_NEEDED.md
```

**Or manually:**

```bash
# 1. Check what's happening (30 seconds)
cat STATUS.md | head -30  # or cat PRODUCT.md in Core mode

# 2. See recent progress (30 seconds)
tail -30 JOURNAL.md

# 3. Health check (1 minute)
bash .agentic/tools/doctor.sh

# 4. Check blockers
cat HUMAN_NEEDED.md
```

**Now you know**:
- Current focus
- What happened yesterday
- What's broken (if anything)
- What needs your decision

**💡 Using AI prompts**: Copy a prompt from [`.agentic/prompts/cursor/`](prompts/cursor/) or [`.agentic/prompts/claude/`](prompts/claude/) to quickly start your session with the agent. Example: use `session_start.md` to get oriented automatically.

### During: Development Work

#### Working with Agent

**Option 1: Continue existing work**
```
Agent: "Continue working on F-0005"
```

**Option 2: Start new feature**
```
Agent: "Add new feature: user can export data to CSV.
Create F-#### entry in FEATURES.md with acceptance criteria."
```

**Option 3: Direct spec editing (faster!)**
```bash
# Edit spec/FEATURES.md yourself - add F-0010
# Create spec/acceptance/F-0010.md with criteria
```
Then tell agent:
```
Agent: "I've added F-0010. Please implement it using TDD."
```

#### Working Manually (Without Agent)

```bash
# Run tests
<test command from STACK.md>

# Format code
<formatter from STACK.md>

# Quality check
bash quality_checks.sh --pre-commit

# Update docs yourself
vim STATUS.md          # Update "Current focus"
vim JOURNAL.md         # Add session entry
vim spec/FEATURES.md   # Update implementation status
```

### Evening: Wrap Up Session

```bash
# 1. Verify everything is correct
bash .agentic/tools/verify.sh

# 2. Check test coverage
bash .agentic/tools/coverage.sh

# 3. Update JOURNAL.md if agent didn't
# (Add session summary: what done, what's next, blockers)

# 4. Commit your work
git add .
git commit -m "feat: implemented F-0005 CSV export"
git push
```

---

## Working with Agents

### Ready-to-Use AI Prompts

**Don't want to write prompts from scratch?** Use our pre-made workflow prompts:

**For Cursor**: [`.agentic/prompts/cursor/`](prompts/cursor/)
**For Claude**: [`.agentic/prompts/claude/`](prompts/claude/)

#### Available Prompts:
- **`session_start.md`** - Start session, load context, get oriented
- **`session_end.md`** - Document work, update specs, commit
- **`feature_start.md`** - Begin implementing a feature (TDD workflow)
- **`feature_test.md`** - Create comprehensive tests
- **`feature_complete.md`** - Mark feature done, verify quality
- **`migration_create.md`** - Create spec migration (Core+PM)
- **`product_update.md`** - Update PRODUCT.md (Core mode)
- **`quick_feature.md`** - Implement simple feature (Core mode)
- **`research.md`** - Deep research session
- **`plan_feature.md`** - Plan complex feature
- **`run_quality.md`** - Run quality checks
- **`fix_issues.md`** - Fix linter/test errors
- **`retrospective.md`** - Project health check

**How to use**: Open the prompt file, copy the text, paste into your AI chat. The agent will follow the workflow automatically.

### How Agents Use This Framework (Proactive Operating Loop)

**Agents follow a proactive operating loop** to make collaboration fluent. See [`.agentic/workflows/proactive_agent_loop.md`](workflows/proactive_agent_loop.md) for full details.

**At Session Start**:
1. Load context efficiently (~2-3K tokens)
2. Check for blockers (HUMAN_NEEDED.md)
3. Check for incomplete work from last session
4. Present structured summary with prioritized options
5. Suggest next work based on STATUS.md/PRODUCT.md

**During Work**:
- Update you on progress periodically
- Escalate blockers immediately (don't wait)
- Ask clarifying questions early
- Follow TDD or standard development mode

**At Session End**:
- Summarize what changed
- Suggest next steps (based on project plan)
- Update docs automatically
- Ask about committing

**Key behaviors that make collaboration fluent**:
- ✅ **Proactively surface blockers**: HUMAN_NEEDED.md items presented at session start
- ✅ **Context-aware suggestions**: Work suggestions from STATUS.md/PRODUCT.md, not random
- ✅ **Resume incomplete work**: Checks JOURNAL.md for stale/unfinished tasks
- ✅ **Provide recaps**: When you return after a break, agent summarizes current state
- ✅ **Make "what's next" obvious**: Always provides 2-3 prioritized options

**Example Session Start**:
```
📊 **Session Context**
**Current Focus**: Login system (F-0010)
**Recent Progress**: Form component complete, API integration 50% done

⚠️ **Blocker**: H-0042 (API auth method unclear) blocks F-0010

**Planned Next** (from STATUS.md):
1. Resolve H-0042 (unblocks current work)
2. Complete F-0010 (Login UI) - 30 min remaining
3. Start F-0012 (Password reset) - next planned feature

**What would you like to tackle?**
```

### Agent Checklists (How Agents Work Systematically)

Agents use **mandatory checklists** to ensure systematic, thorough work:

**📋 Core Checklists:**
- [`checklists/session_start.md`](checklists/session_start.md) - Starting every work session
- [`checklists/feature_implementation.md`](checklists/feature_implementation.md) - Implementing features  
- [`checklists/before_commit.md`](checklists/before_commit.md) - Before every commit (no exceptions!)
- [`checklists/feature_complete.md`](checklists/feature_complete.md) - Marking features "shipped"
- [`checklists/session_end.md`](checklists/session_end.md) - Ending work sessions
- [`checklists/retrospective.md`](checklists/retrospective.md) - Running retrospectives

**Why checklists help you:**
- ✅ Nothing falls through cracks (agents are systematic)
- ✅ Consistent quality across sessions
- ✅ Clear audit trail (you see what was checked)
- ✅ Prevents redundant work (visible checkmarks)
- ✅ You can point agents to checklists if they miss something

**You can read these** to understand what agents should be doing. If something's missing, reference the relevant checklist.

### Understanding Agent Behavior

Agents are trained to:
- ✅ Read specs at session start
- ✅ Pick up your manual edits
- ✅ Follow TDD by default (write tests first)
- ✅ Update documentation automatically
- ✅ Ask for approval before committing
- ❌ Never auto-commit without permission

### Effective Agent Prompts

**❌ Bad Prompts:**
```
"Fix the bug"
"Make it better"
"Add tests"
"Update everything"
```

**✅ Good Prompts:**
```
"Implement F-0005 using TDD. The acceptance criteria are in spec/acceptance/F-0005.md."

"I've updated acceptance criteria for F-0003. Please review and update tests/implementation to match."

"Research Agent: Investigate authentication options for our Next.js app. We need OAuth support for Google and GitHub."

"Planning Agent: Plan F-0008 (user notifications) and create acceptance criteria."

"Continue working on F-0005 - you left off at implementing the export function."
```

### Agent Modes

#### Standard Mode (Single Agent)

One agent does everything. Simple but uses more tokens.

```
You: "Implement F-0005"
Agent: [researches, plans, writes tests, implements, reviews, updates docs, commits]
```

#### Sequential Pipeline (Specialized Agents)

**Enable in `STACK.md`:**
```yaml
- pipeline_enabled: yes
- pipeline_mode: manual
- pipeline_handoff_approval: yes
```

Then invoke specific agents:

```
You: "Research Agent: investigate CSV export libraries for Python"
[Research Agent works, creates research doc]

You: "Planning Agent: plan F-0010 CSV export using pandas"
[Planning Agent creates acceptance criteria]

You: "Test Agent: write tests for F-0010"
[Test Agent writes failing tests]

You: "Implementation Agent: make tests pass"
[Implementation Agent implements feature]

You: "Review Agent: review the implementation"
[Review Agent checks quality]

You: "Git Agent: commit this"
[Git Agent commits with your approval]
```

**Benefits**:
- Lower token usage per step
- Clearer context per agent
- Easier to pause/resume
- Each agent focuses on expertise

### Multi-Agent Coordination (Parallel Work)

**Enable in `STACK.md`:**
```yaml
- multi_agent_enabled: yes
```

**Use Git worktrees:**
```bash
# Agent 1 works on F-0005 in main worktree
# Agent 2 works on F-0006 in separate worktree
git worktree add ../project-feature-6 feature-6

# Agents coordinate via AGENTS_ACTIVE.md
```

See `.agentic/workflows/multi_agent_coordination.md` for full guide.

---

## Manual Operations

### Philosophy: Save Tokens, Read Docs Yourself

**The agent maintains documentation. You can read it directly instead of asking the agent.**

This is:
- ✅ Faster
- ✅ Costs zero tokens
- ✅ Gives you full context

**📖 For focused token-saving quick reference, see [`MANUAL_OPERATIONS.md`](MANUAL_OPERATIONS.md)**

That guide provides:
- Quick grep/cat patterns for instant information
- Token-free dashboard script
- When to look vs. when to ask agent

### Quick Information Retrieval

```bash
# Current status
cat STATUS.md

# Recent work
tail -50 JOURNAL.md

# How to build/test
cat STACK.md

# Architecture overview
cat CONTEXT_PACK.md

# Feature list
grep "^## F-" spec/FEATURES.md

# Optional: Check spec migrations (if using)
bash .agentic/tools/migration.sh list

# What needs your attention
cat HUMAN_NEEDED.md

# Framework version
grep "Version:" STACK.md
```

### Editing Specs Directly

**You can edit ANY spec file**. Agents pick up your changes.

#### Add a Feature

**Option 1: Direct Edit (Simple)**

**Edit `spec/FEATURES.md`:**
```markdown
## Feature index
- F-0001: API Client
- F-0002: Caching
- F-0010: CSV Export  <!-- ADD THIS -->

---

## F-0010: CSV Export
- Parent: none
- Dependencies: F-0001
- Complexity: S
- Status: planned
- Acceptance: spec/acceptance/F-0010.md
- Verification:
  - Accepted: no
- Implementation:
  - State: none
  - Code:
- Tests:
  - Test strategy: unit
  - Unit: todo
  - Integration: n/a
- Notes:
  - Export user data to CSV format
  - Include all user fields
```

**Create `spec/acceptance/F-0010.md`:**
```markdown
# Acceptance: F-0010 - CSV Export

## Happy path
- [ ] User clicks "Export to CSV" button
- [ ] System generates CSV with all user data
- [ ] File downloads automatically
- [ ] CSV includes headers (name, email, joined_date)

## Edge cases
- [ ] Handles special characters in data (commas, quotes)
- [ ] Shows error if no data to export
- [ ] Limits export to 10,000 rows (show warning for larger datasets)

## Non-functional
- [ ] Export completes in <5s for 1000 rows
- [ ] CSV is properly formatted (RFC 4180)
```

**Tell agent:**
```
"I've added F-0010 to FEATURES.md. Please implement it using TDD."
```

**Option 2: Migration-Based (Advanced)** 🆕

If your project uses spec migrations (for projects with 50+ features), you can create atomic change records:

```bash
# Create migration
bash .agentic/tools/migration.sh create "Add CSV Export feature"

# Edit the generated migration file
# spec/migrations/042_add_csv_export_feature.md
```

**Benefits**:
- Smaller context windows for AI (read 3-5 migrations vs entire FEATURES.md)
- Natural audit trail of WHY changes were made
- Better for parallel agent work

**Note**: Migrations are optional and complementary to FEATURES.md.

See: `.agentic/workflows/spec_migrations.md` for details.
**Credits**: Migration concept by Arto Jalkanen, hybrid approach by Tomas Günther & Arto Jalkanen

#### Update Priorities

**Edit `STATUS.md`:**
```markdown
## Current focus
- F-0010: CSV Export (HIGH PRIORITY - customer request)

## Next up
- F-0011: PDF reports
- F-0012: Email notifications
```

#### Add Acceptance Criteria

**Edit `spec/acceptance/F-####.md`** directly with new criteria.

Then tell agent:
```
"I updated acceptance criteria for F-0005. Please adjust implementation to match."
```

### Finding Information

**📖 Also see [`MANUAL_OPERATIONS.md#finding-specific-information`](MANUAL_OPERATIONS.md#finding-specific-information) for more grep patterns**

```bash
# Find where feature is implemented
grep -r "@feature F-0005" src/

# Find acceptance criteria
cat spec/acceptance/F-0005.md

# Find decisions
ls spec/adr/ | grep -i "auth"
grep -i "authentication" spec/adr/*.md

# Check test coverage for feature
grep -A 20 "^## F-0005:" spec/FEATURES.md | grep -A 5 "^- Tests:"

# Find why something was done
grep -i "authentication" JOURNAL.md
```

---

## Automation & Scripts

The framework includes 30+ automation scripts in `.agentic/tools/`.

### Session Continuity

#### `continue_here.py` - Generate Quick Context Recovery

**What it does:**
- Synthesizes `JOURNAL.md`, `STATUS.md`/`PRODUCT.md`, `HUMAN_NEEDED.md`, `FEATURES.md`, and pipeline files
- Creates a single `.continue-here.md` file with:
  - Quick summary of current state
  - Active features and pipelines
  - Blockers requiring human attention
  - Recent work summary
  - Recommended next steps
  - Key files to review

**When to run:**
- At the end of each work session
- Before taking a break
- When context window is about to reset
- Before switching to a different project

```bash
python3 .agentic/tools/continue_here.py
```

**Output:** `.continue-here.md` in your project root.

**Next session:** Just read `.continue-here.md` for instant context recovery, or ask your AI agent to read it.

### Health Check Scripts

#### `doctor.sh` - Project Structure Validation

**What it checks:**
- All required files exist
- Files aren't empty or still template content
- Feature IDs in STATUS.md actually exist
- NFR cross-references are valid

**When to run:**
- After setup
- Before starting work
- When something feels off

```bash
bash .agentic/tools/doctor.sh
```

**Example output:**
```
=== agentic doctor ===

Profile: core+product

✓ AGENTS.md exists
✓ STACK.md exists
✓ STATUS.md exists
✓ CONTEXT_PACK.md exists
✓ JOURNAL.md exists
...

Missing (run scaffold):
- spec/OVERVIEW.md

Validation issues:
- F-0005: acceptance file not found
```

#### `verify.sh` - Comprehensive Verification

**What it checks:**
- Everything from doctor.sh
- Cross-references between all spec files
- Broken links to features/NFRs/ADRs
- Missing acceptance files
- Optionally runs test suite

```bash
bash .agentic/tools/verify.sh
```

**When to run:**
- Before committing
- Before deployments
- Weekly health check

#### `report.sh` - Feature Status Summary

**What it shows:**
- Count of features by status
- Features missing acceptance criteria
- Features needing acceptance validation
- Features with dependency issues

```bash
bash .agentic/tools/report.sh
```

**Example output:**
```
=== agentic report ===

Features by status:
  Shipped: 5
  In progress: 2
  Planned: 8

Missing acceptance criteria: F-0007, F-0010

Needs acceptance validation:
  F-0005 (shipped but not accepted)
  F-0006 (shipped but not accepted)
```

### Analysis Scripts

#### `coverage.sh` - Code Annotation Coverage

**What it shows:**
- Which features have `@feature F-####` annotations
- Implemented features lacking annotations
- Orphaned annotations (non-existent features)
- Coverage percentage

```bash
bash .agentic/tools/coverage.sh
```

**When to run:**
- Before major reviews
- To verify code traceability

#### `feature_graph.sh` - Feature Dependencies

**What it shows:**
- Mermaid diagram of feature dependencies
- Which features depend on which
- Status visualization (✓ shipped, ⚙ in progress)

```bash
bash .agentic/tools/feature_graph.sh
# Or save to file:
bash .agentic/tools/feature_graph.sh --save
```

**When to run:**
- Planning next features
- Understanding blockers

#### `arch_diff.sh` - Architecture Changes

**What it shows:**
- Changes to TECH_SPEC.md since last tag
- Changes to architecture diagrams
- What evolved and when

```bash
bash .agentic/tools/arch_diff.sh
# Or compare specific commits:
bash .agentic/tools/arch_diff.sh HEAD~5
```

#### `deps.sh` - Dependency Analysis

**What it shows:**
- External dependencies used
- Versions and update status
- Security vulnerabilities (if scanner available)

```bash
bash .agentic/tools/deps.sh
```

#### `stale.sh` - Staleness Detector

**What it shows:**
- Files not updated in >N days
- Potentially outdated documentation
- Old research that might need refreshing

```bash
bash .agentic/tools/stale.sh --days 90
```

#### `query_features.py` - Feature Query & Search (NEW - v0.3.0)

**What it does:**
- Fast filtering of features by any attribute
- Count features by status, layer, domain, tags
- Essential for large projects (200+ features)

```bash
# Find all in-progress features
python .agentic/tools/query_features.py --status=in_progress

# Find auth-related features
python .agentic/tools/query_features.py --tags=auth

# Find critical UI features currently in progress
python .agentic/tools/query_features.py --tags=ui --priority=critical --status=in_progress

# Show counts by category
python .agentic/tools/query_features.py --count

# Filter by owner
python .agentic/tools/query_features.py --owner=alice@example.com

# Combine multiple filters
python .agentic/tools/query_features.py --layer=presentation --domain=auth --tags=ui
```

**Example output:**
```
F-0002: Login UI [in_progress] (tags:auth,ui, layer:presentation, priority:high)
F-0010: Login Button [in_progress] (tags:auth,ui, layer:presentation)
F-0015: Auth Header Component [in_progress] (tags:auth,ui, layer:presentation)

Total: 3 features
```

**When to use:**
- Finding specific features in large projects
- Planning sprints by layer/domain
- Tracking team member assignments
- Generating custom reports

#### Enhanced `feature_graph.py` - Filtered Dependency Graphs (NEW - v0.3.0)

**What's new:**
- Filter graphs by status, layer, tags
- Focus mode: show single feature + neighbors
- Hierarchy-only mode
- Essential for visualizing large projects

```bash
# All features (default)
python .agentic/tools/feature_graph.py

# Only in-progress features
python .agentic/tools/feature_graph.py --status=in_progress --save

# Only presentation layer
python .agentic/tools/feature_graph.py --layer=presentation

# Features with specific tags
python .agentic/tools/feature_graph.py --tags=auth --tags=ui

# Focus on one feature and its immediate neighbors
python .agentic/tools/feature_graph.py --focus=F-0042 --depth=1

# Show parent-child hierarchy only (no dependencies)
python .agentic/tools/feature_graph.py --hierarchy-only

# Combine filters
python .agentic/tools/feature_graph.py --layer=business-logic --status=planned --save
```

**When to use:**
- Visualizing dependencies in large projects (200+ features)
- Understanding feature relationships
- Planning feature implementation order
- Documenting architecture decisions

#### `validate_specs.py` - Spec Validation (Enhanced - v0.3.0)

**What's new:**
- Circular dependency detection
- Cross-reference validation
- Pre-commit hook integration

```bash
# Validate all specs
python .agentic/tools/validate_specs.py

# Runs automatically before commits (if pre-commit hook installed)
```

**What it checks:**
- Circular dependencies (F-0001 → F-0002 → F-0001)
- Invalid feature references (parent/dependencies don't exist)
- Schema validation (if using YAML frontmatter)

**Example output:**
```
=== Spec Validation ===

Validating spec/FEATURES.md...
  Checking for circular dependencies...
  ✅ No circular dependencies
  Checking cross-references...
  ❌ 2 cross-reference error(s):
     - F-0005: Parent F-0099 does not exist
     - F-0007: Dependency F-0088 does not exist

❌ Total errors: 2
Fix errors in spec files and run again.
```

### Acceptance & Quality Scripts

#### `accept.sh` - Mark Feature Accepted

```bash
# Mark single feature as accepted (runs tests first)
bash .agentic/tools/accept.sh F-0005

# Mark as accepted without running tests
bash .agentic/tools/accept.sh F-0005 --skip-tests
```

#### `mutation_test.sh` - Mutation Testing

**What it does:**
- Mutates code to verify tests catch bugs
- Reports mutation score

```bash
bash .agentic/tools/mutation_test.sh
# Or specific path:
bash .agentic/tools/mutation_test.sh src/auth
```

**When to use:**
- Critical business logic
- High-value functions
- After fixing bugs tests didn't catch

### Retrospective & Research

#### `retro_check.sh` - Check if Retrospective Due

```bash
bash .agentic/tools/retro_check.sh
```

**Output:**
```
Last retrospective: 2025-12-15 (20 days ago)
Features since: 12
Threshold: 14 days or 10 features

⚠ Retrospective overdue!
```

### Utility Scripts

#### `brief.sh` - Quick Project Brief

```bash
bash .agentic/tools/brief.sh
```

**Shows:** Current focus, recent work, health status (1-page summary)

#### `dashboard.sh` - Comprehensive Dashboard

```bash
bash .agentic/tools/dashboard.sh
```

**Shows:** Everything from brief plus feature breakdown, dependencies, quality checks

#### `task.sh` - Create Task

```bash
bash .agentic/tools/task.sh "Implement retry logic for API calls"
```

Creates `spec/tasks/T-####-<slug>.md` from template.

#### `sync_docs.sh` - Generate Doc Scaffolding

```bash
bash .agentic/tools/sync_docs.sh
```

Creates empty doc templates in `docs/` for architecture, debugging, operations.

### Pipeline Scripts (if Sequential Pipeline enabled)

#### `pipeline_status.sh` - View Pipeline State

```bash
bash .agentic/tools/pipeline_status.sh F-0005
```

**Shows:**
- Which agents completed work
- Current agent
- Next agent
- Handoff notes

#### `pipeline_list.sh` - List All Active Pipelines

```bash
bash .agentic/tools/pipeline_list.sh
```

### Version & Upgrade Scripts

#### `version_check.sh` - Verify Dependency Versions

```bash
bash .agentic/tools/version_check.sh
```

Checks if versions in `package.json` / `requirements.txt` match `STACK.md`.

#### `upgrade.sh` - Upgrade Framework

```bash
# Download new framework version
cd /tmp
curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/v0.2.4.tar.gz | tar xz

# Run upgrade FROM new framework
bash /tmp/agentic-framework-0.2.4/.agentic/tools/upgrade.sh /path/to/your-project
```

### Consistency Scripts

#### `consistency.sh` - Check Spec Consistency

```bash
bash .agentic/tools/consistency.sh
```

**Checks:**
- Feature IDs referenced in STATUS.md exist
- NFR IDs referenced in FEATURES.md exist
- ADR IDs referenced exist
- No duplicate IDs

#### `validate_specs.py` - Validate Spec Format

```bash
python3 .agentic/tools/validate_specs.py
```

**Checks:**
- YAML frontmatter is valid
- Required fields present
- Status values are valid (`planned`, `in_progress`, `shipped`)
- Cross-references follow format

### Search & Navigation

#### `search.sh` - Smart Search Across Specs

```bash
bash .agentic/tools/search.sh "authentication"
```

Searches across all spec files, ADRs, JOURNAL, CONTEXT_PACK.

#### `whatchanged.sh` - What Changed Recently

```bash
bash .agentic/tools/whatchanged.sh --days 7
```

Shows all file changes in last N days with context.

---

## Customization

### Choosing a Profile

**Two profiles available:**

1. **Core (Simple Setup)**
   - Lightweight planning (`PRODUCT.md`)
   - No formal feature tracking
   - Fast iteration
   
2. **Core + Product Management**
   - Formal specs (`spec/FEATURES.md`)
   - Feature IDs (`F-####`)
   - Roadmap and status tracking

**Switch from Core to Core+PM:**
```bash
bash .agentic/tools/enable-product-management.sh
```

This creates:
- `spec/` directory with templates
- `STATUS.md`
- Updates `STACK.md` profile

**The agent will then help you migrate `PRODUCT.md` content into formal specs.**

### Customizing STACK.md

`STACK.md` is your project's configuration file.

#### Development Mode

```yaml
# TDD mode (recommended - tests first)
- development_mode: tdd

# Standard mode (tests required but can come after)
# - development_mode: standard
```

#### Sequential Pipeline

```yaml
# Enable specialized agents
- pipeline_enabled: yes
- pipeline_mode: manual     # manual | auto
- pipeline_agents: standard  # minimal | standard | full
- pipeline_handoff_approval: yes
```

#### Git Workflow

```yaml
# Direct commits (solo developer)
- git_workflow: direct

# Or Pull Request mode (teams)
# - git_workflow: pull_request
# - pr_draft_by_default: true
# - pr_reviewers: ["github_username"]
```

#### Multi-Agent Coordination

```yaml
# Enable multiple agents working in parallel
# - multi_agent_enabled: yes
```

#### Retrospectives

```yaml
# Periodic project health checks
# - retrospective_enabled: yes
# - retrospective_trigger: both  # time | features | both
# - retrospective_interval_days: 14
# - retrospective_interval_features: 10
```

#### Research Mode

```yaml
# Deep investigation into topics
# - research_enabled: yes
# - research_cadence: 90  # days between field updates
# - research_depth: standard
```

#### Quality Validation

```yaml
# Automated quality gates
- quality_checks: enabled
- profile: python_cli_tool  # or webapp_fullstack, ios_app, etc
- run_command: bash quality_checks.sh --pre-commit
```

### Creating Custom Quality Profile

**If your tech stack isn't covered, create custom `quality_checks.sh`:**

```bash
#!/usr/bin/env bash
# quality_checks.sh - Custom quality validation

MODE="${1:---pre-commit}"

if [[ "$MODE" == "--pre-commit" ]]; then
  echo "=== Pre-commit checks ==="
  
  # Your stack-specific checks:
  echo "Running linter..."
  npm run lint
  
  echo "Running unit tests..."
  npm test
  
  echo "Checking bundle size..."
  npm run build
  MAX_SIZE=500  # KB
  ACTUAL=$(du -k dist/bundle.js | cut -f1)
  if [ "$ACTUAL" -gt "$MAX_SIZE" ]; then
    echo "❌ Bundle too large: ${ACTUAL}KB (max: ${MAX_SIZE}KB)"
    exit 1
  fi
  
elif [[ "$MODE" == "--full" ]]; then
  echo "=== Full validation suite ==="
  
  # More comprehensive checks
  npm run lint
  npm test
  npm run test:integration
  npm run build
  npm run lighthouse
fi

echo "✅ All checks passed"
```

**Document in `STACK.md`:**
```yaml
- quality_checks: enabled
- profile: custom
- run_command: bash quality_checks.sh --pre-commit
- full_suite_command: bash quality_checks.sh --full
```

### Customizing Agent Behavior

**Edit project-level `AGENTS.md`** to add project-specific rules:

```markdown
# AGENTS.md

This repo uses the agentic framework located at `.agentic/`.

## Non-negotiables
- Add/update tests for new or changed logic.
- Keep `CONTEXT_PACK.md` current when architecture changes.
- Update `PRODUCT.md` with decisions and completed capabilities.
- Add to `HUMAN_NEEDED.md` when blocked.
- Keep `JOURNAL.md` current (session summaries).
- If Core+Product: keep `STATUS.md` and `/spec/*` truthful.

## Project-Specific Rules
- NEVER expose API keys in logs or error messages
- All database queries must use parameterized statements (no string concatenation)
- UI components must have accessibility tests
- New endpoints require rate limiting

Full rules: `.agentic/agents/shared/agent_operating_guidelines.md`
```

### Adding Custom Scripts

**Create scripts in your project root or `scripts/` folder:**

```bash
#!/usr/bin/env bash
# scripts/deploy-staging.sh

echo "Deploying to staging..."
bash .agentic/tools/verify.sh || exit 1
npm run build
aws s3 sync dist/ s3://staging-bucket/
echo "✅ Deployed to https://staging.example.com"
```

**Document in `STACK.md`:**
```yaml
## Deployment
- Target environment: AWS S3 + CloudFront
- Staging: bash scripts/deploy-staging.sh
- Production: bash scripts/deploy-production.sh
```

### Using Stack Profiles

**Browse available profiles:**
```bash
ls .agentic/support/stack_profiles/
```

Profiles include:
- `webapp_fullstack.md` - Next.js, React, Node.js
- `mobile_ios.md` - Swift, UIKit/SwiftUI
- `mobile_react_native.md` - React Native
- `backend_go_service.md` - Go microservices
- `ml_python_project.md` - Python ML/AI
- `systems_rust.md` - Rust systems programming
- `juce_vstplugin.md` - JUCE audio plugins
- `generic_default.md` - Generic starting point

**Use during init:**

When agent asks about tech stack, mention the profile:

```
Agent: "What are you building?"
You: "A full-stack web app. Use the webapp_fullstack profile."
```

Agent will:
- Pre-fill sensible defaults
- Create appropriate quality checks
- Set up correct testing strategy

**Or reference later:**

```
Agent: "Read .agentic/support/stack_profiles/mobile_ios.md and adapt 
our quality_checks.sh to include those iOS-specific validations."
```

---

## Troubleshooting

### Agent Keeps Re-Reading Everything

**Problem:** Agent loads entire codebase every session.

**Fix:**
1. Update `CONTEXT_PACK.md` with structure summaries
2. Use `@feature` annotations in code
3. Tell agent: "Follow `.agentic/token_efficiency/reading_protocols.md`"

### Lost Track of What We're Building

**Problem:** Unclear project direction.

**Fix:**
```bash
# Read vision
cat PRODUCT.md  # or spec/OVERVIEW.md if Core+PM

# Check current status
cat STATUS.md

# Review features
cat spec/FEATURES.md
```

### Tests Are Missing or Broken

**Problem:** Features shipped without tests.

**Fix:**
```bash
# Check which features need tests
bash .agentic/tools/report.sh

# Run comprehensive verification
bash .agentic/tools/verify.sh

# Review test strategy
cat .agentic/quality/test_strategy.md
```

### Don't Know What to Work On Next

**Problem:** No clear priorities.

**Fix:**
```bash
# Check STATUS.md "Next up"
cat STATUS.md

# Check planned features
grep "Status: planned" spec/FEATURES.md

# Check blockers
cat HUMAN_NEEDED.md

# Visualize dependencies
bash .agentic/tools/feature_graph.sh
```

### Agent Context Reset Mid-Task

**Problem:** Agent lost context during long session.

**Fix:**
```bash
# Check precise next step
cat STATUS.md | grep -A 10 "Current session state"

# Check recent work
tail -50 JOURNAL.md

# Agent should update these BEFORE context resets
```

### Project Getting Complex and Hard to Navigate

**Problem:** Codebase outgrew initial structure.

**Fix:**
1. Read `.agentic/workflows/scaling_guidance.md`
2. Consider splitting large files (FEATURES.md, NFR.md)
3. Reorganize into modules
4. Update CONTEXT_PACK.md with new structure

### Documentation Out of Sync with Code

**Problem:** Docs don't reflect reality.

**Fix:**
```bash
# Run verification
bash .agentic/tools/verify.sh

# Check staleness
bash .agentic/tools/stale.sh --days 90

# Agent should update docs in same commit as code
# Check agent_operating_guidelines.md "Documentation Sync Rule"
```

### Quality Checks Failing

**Problem:** `quality_checks.sh` fails on commit.

**Fix:**
```bash
# Run checks yourself
bash quality_checks.sh --pre-commit

# See specific failure
# Fix the issue or update quality_checks.sh if check is too strict

# Update thresholds in STACK.md if needed
```

### Framework Version Mismatch

**Problem:** Using old framework version.

**Fix:**
```bash
# Check current version
grep "Version:" STACK.md

# Check latest version
curl -s https://api.github.com/repos/tomgun/agentic-framework/releases/latest | grep '"tag_name"'

# Upgrade (see UPGRADING.md)
cd /tmp
curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/v0.2.4.tar.gz | tar xz
bash /tmp/agentic-framework-0.2.4/.agentic/tools/upgrade.sh /path/to/your-project
```

---

## Best Practices

### 1. Use TDD Mode

**Why:** Better token economics, clearer progress, forces testability.

```yaml
# In STACK.md
- development_mode: tdd
```

Then agents write tests FIRST (red-green-refactor).

### 2. Keep Specs Updated

**Update specs in the same commit as code:**
- Update `STATUS.md` when focus changes
- Update `FEATURES.md` when implementation progresses
- Update `JOURNAL.md` at session end
- Update `CONTEXT_PACK.md` when architecture changes

### 3. Run Verification Regularly

```bash
# Before commits
bash .agentic/tools/verify.sh

# Weekly
bash .agentic/tools/verify.sh > weekly-health-check.txt
```

### 4. Use Feature IDs Consistently

**In code:**
```python
# @feature F-0005
def export_to_csv(data):
    """Export user data to CSV format."""
    # ...
```

**In commits:**
```bash
git commit -m "feat(F-0005): implement CSV export with headers"
```

**In pull requests:**
```markdown
## F-0005: CSV Export

Implements acceptance criteria from spec/acceptance/F-0005.md

- [x] User can click export button
- [x] CSV includes all user fields
- [x] Handles special characters
```

### 5. Document Decisions in ADRs

**When making architectural decisions, create ADR:**

```bash
# Agent creates this automatically
# Or create manually:
cp .agentic/spec/ADR.template.md spec/adr/ADR-0005-use-postgresql.md
```

**ADRs should record:**
- What decision was made
- Why (tradeoffs, context)
- Alternatives considered
- Consequences

### 6. Escalate Blockers Promptly

**Add to `HUMAN_NEEDED.md` immediately:**
```markdown
### HN-0003: Choose authentication provider

**Context**: Need to decide between Auth0 and AWS Cognito

**Options**:
1. Auth0: Easier setup, $23/mo
2. AWS Cognito: Free tier, more complex

**Needed by**: 2026-01-15 (blocking F-0008)
**Priority**: High
```

### 7. Use Brief Context Loads

**Don't load entire codebase every session:**

```
Agent: "Read CONTEXT_PACK.md, STATUS.md, and JOURNAL.md (last 3 entries).
Then load spec/acceptance/F-0005.md and continue implementation."
```

Not:
```
Agent: "Read all files in src/ and tell me what's happening"  ❌
```

### 8. Batch Related Changes

**One feature = one commit with all updates:**
```bash
# Bad: Multiple commits for one feature
git commit -m "add CSV export function"
git commit -m "add tests for CSV export"
git commit -m "update FEATURES.md for F-0005"

# Good: One commit with everything
git add src/ tests/ spec/
git commit -m "feat(F-0005): implement CSV export with tests and spec updates"
```

### 9. Review Before Merging

**Checklist before merge:**
- [ ] All tests pass
- [ ] `bash .agentic/tools/verify.sh` passes
- [ ] FEATURES.md updated (implementation state, code paths, test status)
- [ ] JOURNAL.md updated
- [ ] Acceptance criteria met (check spec/acceptance/F-####.md)
- [ ] Quality checks pass (`bash quality_checks.sh --full`)

### 10. Run Retrospectives

**Enable in STACK.md:**
```yaml
- retrospective_enabled: yes
- retrospective_interval_days: 14
- retrospective_interval_features: 10
```

**When triggered:**
```bash
bash .agentic/tools/retro_check.sh
```

Tell agent:
```
"Let's run a retrospective. Follow .agentic/workflows/retrospective.md"
```

---

## Advanced Topics

### Sequential Agent Pipeline

**Full guide:** `.agentic/workflows/sequential_agent_specialization.md`

**Pipeline:**
```
Research → Planning → Test → Implementation → Build → Review → 
Spec Update → Documentation → Git → Deploy
```

**Each agent:**
- Loads only 30-50K tokens (vs 150-200K for general agent)
- Focuses on expertise
- Hands off to next agent
- Updates pipeline state file

**Enable:**
```yaml
# STACK.md
- pipeline_enabled: yes
- pipeline_mode: manual  # or auto
- pipeline_agents: standard
```

**Usage:**
```
You: "Research Agent: investigate payment gateways for e-commerce"
[Research Agent creates docs/research/payment-gateways-2026-01-03.md]

You: "Planning Agent: plan F-0015 (Stripe integration)"
[Planning Agent creates spec/acceptance/F-0015.md]

You: "Test Agent: write tests for F-0015"
[Test Agent writes failing tests]

You: "Implementation Agent: make tests pass"
[Implementation Agent implements Stripe integration]
```

### Multi-Agent Parallel Work

**Full guide:** `.agentic/workflows/multi_agent_coordination.md`

**Use Git worktrees for isolation:**
```bash
# Main worktree: Agent 1 works on F-0005
git worktree add ../project-feat-6 feat-6
# Worktree: Agent 2 works on F-0006

# Agents coordinate via AGENTS_ACTIVE.md
```

**Enable:**
```yaml
# STACK.md
- multi_agent_enabled: yes
```

### Pull Request Workflow

**For teams, use PR mode:**
```yaml
# STACK.md
- git_workflow: pull_request
- pr_draft_by_default: true
- pr_auto_request_review: true
- pr_reviewers: ["teammate1", "teammate2"]
```

**Agent will:**
1. Create feature branch
2. Commit changes
3. Create draft PR
4. Request reviews
5. Wait for approval before marking ready

### Research Mode

**Deep investigation into technologies:**

```yaml
# STACK.md
- research_enabled: yes
- research_cadence: 90  # days
- research_depth: standard
```

**Trigger:**
```
"Research Agent: investigate WebAssembly for our use case. 
Research: performance, browser support, build tooling, team learning curve."
```

**Agent creates:**
- `docs/research/webassembly-evaluation-2026-01-03.md`
- Updates `spec/REFERENCES.md`
- Recommends decision or escalates to `HUMAN_NEEDED.md`

### Documentation Verification

**Ensure agents use correct docs:**

```yaml
# STACK.md
- doc_verification: context7  # or manual
- context7_enabled: yes
- strict_version_matching: yes
```

**Full guide:** `.agentic/workflows/documentation_verification.md`

### Mutation Testing

**Advanced test quality validation:**

```bash
bash .agentic/tools/mutation_test.sh src/payment
```

**Mutates code and checks if tests fail.**

**Good mutation score:**
- 80%+: Strong test suite
- 60-80%: Decent, but gaps exist
- <60%: Tests may pass but not catch bugs

**Use for:**
- Critical business logic (payments, auth)
- High-value functions
- After fixing bugs tests didn't catch

**Full guide:** `.agentic/quality/test_strategy.md#mutation-testing`

### Continuous Quality Validation

**Stack-specific quality gates:**

```yaml
# STACK.md
- quality_checks: enabled
- profile: webapp_fullstack
- run_command: bash quality_checks.sh --pre-commit
```

**Pre-commit hook:**
```bash
# .git/hooks/pre-commit
#!/bin/bash
bash quality_checks.sh --pre-commit || exit 1
```

**Full guide:** `.agentic/workflows/continuous_quality_validation.md`

### Scaling Guidance

**When project grows complex:**

1. Read `.agentic/workflows/scaling_guidance.md`
2. Consider:
   - Splitting FEATURES.md by domain
   - Creating module-specific CONTEXT_PACK files
   - Using sub-specs (spec/auth/, spec/payments/)
   - Documenting patterns in TECH_SPEC.md

### Context7 Integration

**Version-specific documentation:**

```yaml
# STACK.md
- doc_verification: context7
- context7_config: .context7.yml
```

**Create `.context7.yml`:**
```yaml
documentation:
  - name: Next.js
    version: "15.1.0"
    source: https://nextjs.org/docs
  - name: React
    version: "19.0.0"
    source: https://react.dev
```

**Agent will:**
- Use exact version docs
- Never assume APIs exist
- Verify before using new features

---

## Quick Reference

### Daily Commands

```bash
# Morning
cat STATUS.md | head -30
tail -30 JOURNAL.md
bash .agentic/tools/doctor.sh

# During
bash quality_checks.sh --pre-commit
bash .agentic/tools/verify.sh

# Evening
bash .agentic/tools/verify.sh
bash .agentic/tools/coverage.sh
```

### When to Run What

| Situation | Command |
|-----------|---------|
| Start work session | `cat STATUS.md`, `tail -30 JOURNAL.md` |
| Before commit | `bash .agentic/tools/verify.sh` |
| Check feature status | `bash .agentic/tools/report.sh` |
| Find blockers | `cat HUMAN_NEEDED.md` |
| Check test coverage | `bash .agentic/tools/coverage.sh` |
| Visualize dependencies | `bash .agentic/tools/feature_graph.sh` |
| Check health | `bash .agentic/tools/doctor.sh` |
| Check staleness | `bash .agentic/tools/stale.sh --days 90` |
| Mark feature accepted | `bash .agentic/tools/accept.sh F-####` |
| Check retro due | `bash .agentic/tools/retro_check.sh` |

### Key Files to Bookmark

- `STATUS.md` - Current focus, next up, roadmap
- `JOURNAL.md` - Session history (tail -50)
- `HUMAN_NEEDED.md` - Blockers and decisions
- `STACK.md` - How to build/test/run
- `CONTEXT_PACK.md` - Architecture overview
- `spec/FEATURES.md` - Feature list and status (Core+PM)
- `PRODUCT.md` - Vision and capabilities (Core)

### Essential Agent Prompts

```
# Continue work
"Continue working on F-0005"

# New feature
"Implement F-0010 using TDD. Acceptance criteria in spec/acceptance/F-0010.md"

# Research
"Research Agent: investigate authentication options for Next.js (OAuth, JWT)"

# Review
"Review the implementation of F-0005 against acceptance criteria"

# Fix
"Fix the test failures in test_csv_export.py"

# Update
"I updated acceptance criteria for F-0005. Please adjust implementation"

# Commit
"All tests pass. Please commit with appropriate message"
```

---

## Getting Help

**Framework Documentation:**
- Quick start: `.agentic/START_HERE.md`
- User workflows: `.agentic/workflows/USER_WORKFLOWS.md`
- Manual operations: `.agentic/MANUAL_OPERATIONS.md`
- All workflows: `.agentic/workflows/`
- All tools: `.agentic/tools/` (each has inline help)

**Framework Map:**
- Visual overview: `.agentic/FRAMEWORK_MAP.md`

**Upgrading:**
- Upgrade guide: `UPGRADING.md` (in framework root)

**Issues:**
- GitHub: https://github.com/tomgun/agentic-framework/issues

**Community:**
- (Add community links when available)

---

**Version:** 0.2.4  
**Last updated:** 2026-01-03

