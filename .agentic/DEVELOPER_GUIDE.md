# Developer Guide: Working with Agentic AF

**Purpose**: Complete guide for developers using the Agentic AI Framework. Learn how to work manually, use automation tools, customize the framework, and collaborate effectively with AI agents.

---

## Table of Contents

1. [How You Help the Framework](#how-you-help-the-framework) **← Start here!**
2. [Getting Started](#getting-started)
3. [Daily Workflows](#daily-workflows)
4. [Working with Agents](#working-with-agents)
5. [Manual Operations](#manual-operations)
6. [Automation & Scripts](#automation--scripts)
7. [Customization](#customization)
8. [Troubleshooting](#troubleshooting)
9. [Best Practices](#best-practices)
10. [Advanced Topics](#advanced-topics)

---

## How It Works

**You describe what you want to build. The agent and framework handle the rest.**

The framework provides structure, quality gates, and tracking. The agent uses these automatically when you work together through conversation. You stay focused on decisions, direction, and code review.

### Talking to the Agent

Tell the agent what you want in plain language:

```
"Let's work on the CSV export feature"        → agent starts implementation workflow
"What's our current status?"                   → agent checks STATUS.md, blockers, WIP
"Are we in good shape to commit?"              → agent runs verification + commit gates
"Let's plan the authentication changes first"  → agent creates an implementation plan
"We're done with this feature"                 → agent runs completion checklist
```

The framework detects your profile (Discovery or Formal) automatically:

```
You say: "Let's implement the login feature"

# Formal profile → agent verifies specs exist, tracks feature IDs internally
# Discovery profile → agent starts simpler task tracking, no IDs needed
```

You can switch anytime: `ag set profile discovery`

### What the Framework Does Behind the Scenes

When you work with the agent, it uses `ag` commands to enforce quality automatically:

| When you say... | Agent runs | What happens |
|-----------------|-----------|--------------|
| "Let's build X" | `ag implement` / `ag work` | Verifies specs exist, starts WIP tracking |
| "Plan this first" | `ag plan` | Creates reviewable plan, saves to journal |
| "Commit this" | `ag commit` | Runs all quality gates, blocks if issues |
| "We're done" | `ag done` | Checks docs updated, tests pass, acceptance met |

You don't need to memorize these commands. The agent picks the right one.

### The Few Commands You Might Use Directly

Most of the time, conversation is enough. But a few commands are useful to run yourself:

```bash
ag start              # Quick orientation at session start
ag status             # See current focus and profile
ag set <key> <value>  # Change a setting (e.g., ag set feature_tracking no)
```

### Why 30+ Scripts Exist in a Chat-First Framework

The framework ships many scripts. You'll rarely run them directly — they exist for three reasons:

1. **The agent uses them** — when you say "commit this", the agent runs `ag commit` which triggers gates, checks, and state updates behind the scenes
2. **Transparency** — you can run any script yourself to see exactly what the agent would do
3. **Escape hatch** — if the agent is unavailable, every workflow works standalone from the terminal

```bash
# Available if you want them:
bash .agentic/tools/doctor.sh --full    # Comprehensive verification
bash .agentic/tools/wip.sh check        # Check interrupted work
bash .agentic/tools/journal.sh ...      # Log to JOURNAL.md
bash .agentic/tools/nfr.sh list         # List NFRs with status
ag tools                                # Discover all available tools
```

---

## Getting Started

### Installation

**Download and install the framework:**

```bash
# Download latest release
curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/v<VERSION>.tar.gz | tar xz
cd agentic-framework-<VERSION>
# Replace <VERSION> with the latest from: https://github.com/tomgun/agentic-framework/releases

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
2. Offer profile choice (a=Discovery, b=Formal)
3. Interview you about tech stack
4. Create all necessary files
5. Set up quality checks for your stack

**Profile Selection:**

- **a) Discovery (Simple Setup)**: Quality standards, multi-agent, research, lightweight planning (`OVERVIEW.md`)
  - Good for: Small projects, prototypes, external PM tools, quick experiments

- **b) Formal**: Everything in Discovery plus formal specs, feature tracking (`F-####` IDs), roadmap
  - Good for: Long-term projects (3+ months), complex products, audit trails

---

## Daily Workflows

Most of your interaction is through conversation with the agent. The framework handles structure and quality behind the scenes.

### Morning: Start Your Work Session

Open your AI tool and say hello — the agent reads STATUS.md, JOURNAL.md, and blockers automatically at session start.

Or if you prefer a quick self-check first: `ag start`

**Now you know**:
- Current focus
- What happened yesterday
- What's broken (if anything)
- What needs your decision

### During: Development Work

Tell the agent what you want to build. It picks the right workflow based on your profile:

**"Let's implement the CSV export feature"**
- Formal profile → agent runs `ag implement` (verifies acceptance criteria, starts WIP)
- Discovery profile → agent runs `ag work "Add CSV export"` (simpler tracking)

**"I've added a CSV export feature to the spec. Please implement it using TDD."**
- If you edited spec files yourself, the agent picks up your changes and implements from them

**"Let's plan the authentication changes before coding"**
- Agent runs `ag plan` to create and review an implementation plan first

### Evening: Wrap Up

Tell the agent: **"Let's wrap up and commit"**

The agent runs verification, updates JOURNAL.md, and prepares the commit for your approval.

### Accepting a Feature

When the agent says a feature is complete:

1. **Test it yourself** — try the feature, check acceptance criteria from `spec/acceptance/F-####.md`
2. **If it works**, tell the agent: *"F-#### looks good, mark it as accepted"*
3. Agent updates `spec/FEATURES.md` (Accepted: yes, date), `STATUS.md`, and `JOURNAL.md`

**Automated acceptance** (if tests exist):
```bash
bash .agentic/tools/accept.sh F-####
```
This marks the feature as accepted if all tests pass.

### Working Manually (Without Agent)

If you prefer direct control or the agent isn't available:

```bash
# Morning
ag start                          # Or: cat STATUS.md | head -30

# During
<test command from STACK.md>      # Run tests
<formatter from STACK.md>         # Format code
bash quality_checks.sh --pre-commit  # If you've created one (see Customization)

# Evening
bash .agentic/tools/doctor.sh --full  # Verify
vim JOURNAL.md                        # Add session summary
git add . && git commit -m "feat: add CSV export for user data"
git push
```

---

## Working with Agents

### When to Delegate vs. Do It Yourself

Not sure when to use the agent? See **[`.agentic/workflows/delegation_heuristics.md`](workflows/delegation_heuristics.md)** for practical guidance.

**Quick rules**:
- ✅ **Delegate**: Repetitive tasks, clear specs, verifiable output
- ❌ **Do yourself**: Explaining takes >2 min, agent failed twice, quick one-liner
- ⚠️ **Watch closely**: Unfamiliar domain, architectural decisions

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
- **`migration_create.md`** - Create spec migration (Formal)
- **`product_update.md`** - Update OVERVIEW.md (Discovery mode)
- **`quick_feature.md`** - Implement simple feature (Discovery mode)
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
5. Suggest next work based on STATUS.md

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
- ✅ **Context-aware suggestions**: Work suggestions from STATUS.md, not random
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
"Implement the CSV export feature using TDD."

"I've updated the acceptance criteria for the caching layer. Please review and update tests to match."

"Research Agent: Investigate authentication options for our Next.js app. We need OAuth support for Google and GitHub."

"Planning Agent: Plan the user notifications feature and create acceptance criteria."

"Continue working on the export feature — you left off at implementing the export function."
```

### Agent Modes

#### Standard Mode (Single Agent)

One agent does everything. Simple but uses more tokens.

```
You: "Implement the CSV export feature"
Agent: [researches, plans, writes tests, implements, reviews, updates docs, commits]
```

#### Sequential Pipeline (Specialized Agents)

**Enable in `STACK.md`:**
```yaml
- pipeline_enabled: yes
- pipeline_mode: manual
- pipeline_handoff_approval: yes
```

Then invoke specific agents (using feature names — the agent resolves IDs internally if you use Formal profile):

```
You: "Research Agent: investigate CSV export libraries for Python"
[Research Agent works, creates research doc]

You: "Planning Agent: plan the CSV export feature using pandas"
[Planning Agent creates acceptance criteria]

You: "Test Agent: write tests for CSV export"
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

**Use the worktree tool for parallel agent development:**

```bash
# Create worktree for second agent
bash .agentic/tools/worktree.sh create F-0006 "Dashboard feature"
# → Creates ../project-f-0006/ on branch feature/F-0006
# → Auto-registers in .agentic-state/AGENTS_ACTIVE.md

# Open new Claude/Cursor in that directory
cd ../project-f-0006/

# List all active worktrees
bash .agentic/tools/worktree.sh list

# When done, cleanup
bash .agentic/tools/worktree.sh remove F-0006
```

**Workflow:**
1. Agent 1 works in main directory on F-0005
2. `worktree.sh create F-0006` for Agent 2
3. Both work in parallel - no conflicts (different branches)
4. Each creates PR when done
5. Merge PRs, cleanup worktrees

See `.agentic/workflows/multi_agent_coordination.md` for full guide.

---

## Manual Operations

**📖 Quick commands for token-free operations**: [`MANUAL_OPERATIONS.md`](MANUAL_OPERATIONS.md)
— status checks, context gathering, finding information, dashboard script.

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

**Tell agent** (either works — you just created the spec, so you know the ID):
```
"I've added a CSV export feature to FEATURES.md. Please implement it using TDD."
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
"I updated the acceptance criteria for CSV export. Please adjust implementation to match."
```

---

## Automation & Scripts

The framework includes 30+ automation scripts in `.agentic/tools/`.

### Session Continuity

**Status:** Session continuity is now handled by standard framework files:
- `STATUS.md` - Current focus, phase, next steps
- `.agentic-state/WIP.md` - Interrupted work detection
- `JOURNAL.md` - Work history

Agents read these files at session start (via `ag start` or session_start.md checklist).

> **Migration:** `continue_here.py` / `.continue-here.md` are superseded by STATUS.md — delete if found in your project.

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

Profile: formal

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

#### `doctor.sh --full` - Comprehensive Verification (v0.11.0)

> **Note:** `verify.sh` is deprecated. Use `doctor.sh --full` instead.

**What it checks:**
- Everything from `doctor.sh` (quick mode)
- Cross-references between all spec files
- Broken links to features/NFRs/ADRs
- NFR content validation (non-placeholder fields, valid status/category, test file paths)
- Missing acceptance files

```bash
bash .agentic/tools/doctor.sh --full
```

**Other modes:**
```bash
doctor.sh --phase planning F-0001  # Phase-specific checks
doctor.sh --pre-commit             # Pre-commit gate checks
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
- Test→feature mapping (with `--test-mapping`)

```bash
bash .agentic/tools/coverage.sh              # Human-readable report
bash .agentic/tools/coverage.sh --json       # Machine-readable output
bash .agentic/tools/coverage.sh --reverse src/auth.py  # Features in this file
bash .agentic/tools/coverage.sh --test-mapping  # Infer test→feature mapping
```

**When to run:**
- Before major reviews
- To verify code traceability

#### `ag trace` - Unified Traceability CLI (NEW - v0.15.0)

**What it does:**
- Combines drift detection and coverage analysis
- Answers: "What specs lack code?", "What code lacks specs?", "What tests cover what?"

```bash
bash .agentic/tools/ag.sh trace              # Full report
bash .agentic/tools/ag.sh trace F-0001       # Files implementing F-0001
bash .agentic/tools/ag.sh trace src/auth.py  # Features in this file
bash .agentic/tools/ag.sh trace --gaps       # Missing implementations only
bash .agentic/tools/ag.sh trace --orphans    # Orphaned code/annotations
bash .agentic/tools/ag.sh trace --json       # Combined JSON output
```

**When to run:**
- Before completing a feature
- To find what needs documentation
- CI/CD integration (with `--json`)

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

#### `worktree.sh` - Parallel Agent Management (NEW - v0.11.3)

**What it does:**
- Creates git worktrees for parallel agent development
- Auto-registers agents in `.agentic-state/AGENTS_ACTIVE.md`
- Enables multiple Claude/Cursor windows without conflicts

```bash
# Create worktree for parallel work
bash .agentic/tools/worktree.sh create F-0001 "User auth"
# → ../project-f-0001/ on branch feature/F-0001

# List active worktrees and agents
bash .agentic/tools/worktree.sh list

# Show current status
bash .agentic/tools/worktree.sh status

# Cleanup when done
bash .agentic/tools/worktree.sh remove F-0001
```

**When to run:**
- Starting parallel agent work
- Opening second Claude/Cursor window
- Cleaning up after feature completion

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
- Query feature hierarchy (children, descendants)
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

# List direct children of a feature
python .agentic/tools/query_features.py --children=F-0001

# List all descendants (recursive) with tree format
python .agentic/tools/query_features.py --children=F-0001 --recursive

# Filter children by status
python .agentic/tools/query_features.py --children=F-0001 --status=shipped
```

**Example output:**
```
F-0002: Login UI [in_progress] (tags:auth,ui, layer:presentation, priority:high)
F-0010: Login Button [in_progress] (tags:auth,ui, layer:presentation)
F-0015: Auth Header Component [in_progress] (tags:auth,ui, layer:presentation)

Total: 3 features
```

**Example --children output:**
```
F-0101: Login UI [shipped]
  F-0110: Login Form [shipped]
  F-0111: Login Button [shipped]
F-0102: OAuth Integration [planned]

Summary: 4 descendants (2 shipped, 2 planned)
```

**When to use:**
- Finding specific features in large projects
- Planning sprints by layer/domain
- Tracking team member assignments
- Understanding feature hierarchy and relationships
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

### Session & Environment Scripts

#### `start.sh` - Project Initialization

**What it does:**
- Runs scaffold.sh to ensure project structure
- Shows instructions for init playbook
- Points to optional follow-up steps

```bash
bash .agentic/tools/start.sh
```

**When to run:**
- First time setting up a project
- After cloning framework into new project

#### `check-environment.sh` - Environment Detection

**What it does:**
- Detects which AI coding tools are installed (Claude, Cursor, Copilot)
- Suggests optimal setup for detected tools
- Checks for required dependencies

```bash
bash .agentic/tools/check-environment.sh
```

**When to run:**
- During project setup
- When switching development environments
- Troubleshooting tool integration

#### `framework_age.sh` - Framework Version Check

**What it does:**
- Checks if framework is outdated
- Compares local version to latest release
- Suggests upgrade if newer version available

```bash
bash .agentic/tools/framework_age.sh
```

**When to run:**
- Periodically (monthly)
- Before starting major features
- When experiencing issues

### Feature Management Scripts

#### `accept.py` - Feature Acceptance Runner

**What it does:**
- Runs tests specific to a feature
- Parses FEATURES.md to find related test files
- Reports acceptance status

```bash
python3 .agentic/tools/accept.py F-0005
```

**When to run:**
- Before marking feature as shipped
- During acceptance validation

#### `feature_stats.py` - Feature Statistics Dashboard

**What it does:**
- Shows feature distribution by status
- Calculates velocity metrics
- Reports health indicators

```bash
python3 .agentic/tools/feature_stats.py
python3 .agentic/tools/feature_stats.py --period=30  # Last 30 days
```

**When to run:**
- Sprint planning
- Retrospectives
- Progress reporting

#### `organize_features.py` - Feature Organization

**What it does:**
- Migrates FEATURES.md from flat to hierarchical format
- Organizes features by domain or layer

```bash
python3 .agentic/tools/organize_features.py --by domain --dry-run
python3 .agentic/tools/organize_features.py --by layer
```

**When to run:**
- When project grows beyond 50+ features
- Reorganizing project structure

#### `upgrade_spec_format.py` - Spec Format Upgrade

**What it does:**
- Detects spec format version
- Applies migrations to newer format versions

```bash
python3 .agentic/tools/upgrade_spec_format.py --dry-run
python3 .agentic/tools/upgrade_spec_format.py
```

**When to run:**
- After framework upgrade
- When format version warnings appear

### Agent Support Scripts

#### `context-for-role.sh` - Role-Based Context Assembly

**What it does:**
- Assembles minimal context for a specific agent role
- Loads only relevant files for the role

```bash
bash .agentic/tools/context-for-role.sh planning F-0005
bash .agentic/tools/context-for-role.sh implementation F-0005 --dry-run
```

**When to run:**
- Starting specialized agent work
- Optimizing context size

#### `suggest-agents.sh` - Agent Suggestions

**What it does:**
- Analyzes project structure
- Suggests useful custom agents based on tech stack

```bash
bash .agentic/tools/suggest-agents.sh
```

**When to run:**
- Initial project setup
- Adding new technologies

#### `generate-skills.sh` - Claude Skills Generator

**What it does:**
- Generates Claude Skills from subagent definitions
- Creates skill files for Claude Code integration

```bash
bash .agentic/tools/generate-skills.sh           # Generate all skills
bash .agentic/tools/generate-skills.sh planning  # Generate specific skill
```

**When to run:**
- After modifying subagent definitions
- Setting up Claude Code integration

#### `list-tools.sh` - Tool Discovery Menu

**What it does:**
- Lists all framework tools by category
- Shows brief descriptions and usage

```bash
bash .agentic/tools/list-tools.sh
```

**When to run:**
- Learning available tools
- Finding the right tool for a task

### Build & Performance Scripts

#### `validation-cache.sh` - Validation Caching

**What it does:**
- Caches validation results to avoid redundant checks
- Speeds up doctor.sh, verify.sh, validate_specs.py

```bash
bash .agentic/tools/validation-cache.sh check
bash .agentic/tools/validation-cache.sh clear
```

**When to run:**
- Automatically used by other tools
- Clear when validation seems stale

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
curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/v<VERSION>.tar.gz | tar xz
# Replace <VERSION> with the latest from: https://github.com/tomgun/agentic-framework/releases

# Run upgrade FROM new framework
bash /tmp/agentic-framework-<VERSION>/.agentic/tools/upgrade.sh /path/to/your-project
```

### Consistency Scripts

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

#### `whatchanged.sh` - What Changed Recently

```bash
bash .agentic/tools/whatchanged.sh --days 7
```

Shows all file changes in last N days with context.

---

## Customization

### Settings System

Profiles (`discovery`, `formal`) are presets that set bundles of defaults. You can override any setting independently.

```bash
ag set --show              # View all settings with sources
ag set --validate          # Check constraint rules
ag set feature_tracking yes  # Override a single setting
ag set profile formal      # Switch profile preset
```

**Resolution order** (highest priority wins):

1. **Explicit** — `## Settings` section in STACK.md (you set it directly)
2. **Profile preset** — from `.agentic/presets/profiles.conf` (set by your profile)
3. **Fallback default** — hardcoded in the calling script

Example: if your profile is `discovery` (which defaults `feature_tracking=no`) but you explicitly set `- feature_tracking: yes` in STACK.md, you get `yes`.

**Profile presets:**

| Setting | Discovery | Formal |
|---------|-----------|--------|
| `feature_tracking` | no | **yes** |
| `acceptance_criteria` | recommended | **blocking** |
| `wip_before_commit` | warning | **blocking** |
| `pre_commit_checks` | fast | **full** |
| `git_workflow` | direct | **pull_request** |
| `plan_review_enabled` | no | **yes** |
| `spec_directory` | no | **yes** |
| `max_files_per_commit` | 15 | 10 |
| `max_added_lines` | 1000 | 500 |
| `max_code_file_length` | 1000 | 500 |

**Switch from Discovery to Formal:**
```bash
bash .agentic/tools/enable-formal.sh
```

#### When Settings Take Effect

**Script-enforced settings** (immediate) — read fresh on every `ag` command or commit:

| Setting | Enforced by |
|---------|-------------|
| `wip_before_commit` | `pre-commit-check.sh` |
| `pre_commit_checks` | `pre-commit-check.sh` |
| `max_files_per_commit` | `pre-commit-check.sh` |
| `max_added_lines` | `pre-commit-check.sh` |
| `max_code_file_length` | `pre-commit-check.sh` |
| `git_workflow` | `pre-commit-check.sh` |
| `feature_tracking` | `ag` commands, `session-start.sh` |
| `spec_directory` | `ag` commands |

**Agent-interpreted settings** (session start only) — the agent reads STACK.md once at session start:

`acceptance_criteria`, `plan_review_enabled`, `agent_mode`, `development_mode`

If you change these mid-session, tell the agent: *"I changed X to Y"* or *"Please re-read STACK.md ## Settings"*.

#### Constraints

Some combinations are invalid. Run `ag set --validate` to check:

- `acceptance_criteria=blocking` requires `feature_tracking=yes` and `spec_directory=yes`
- `plan_review_enabled=yes` requires `feature_tracking=yes`
- `feature_tracking=yes` requires `spec_directory=yes`

### Customizing STACK.md

`STACK.md` is your project's configuration file. Settings live in the `## Settings` section:

```markdown
## Settings
<!-- Profile sets defaults. Override individual settings below. -->
- profile: formal
- feature_tracking: yes
- acceptance_criteria: recommended    # override: suggest, don't block
- max_files_per_commit: 20            # temporarily raised for refactor
```

Only settings you want to override need to be listed — unset settings use profile defaults. Projects without a `## Settings` section still work (backward-compatible whole-file search).

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
# PR mode (default for Formal, recommended)
- git_workflow: pull_request
# - pr_draft_by_default: true
# - pr_reviewers: ["github_username"]

# Or direct commits (solo developer, prototyping)
# - git_workflow: direct
```

#### Multi-Agent Coordination

```yaml
# Use worktree.sh tool for parallel agents:
# bash .agentic/tools/worktree.sh create F-0001 "Feature name"
# See: .agentic/workflows/multi_agent_coordination.md
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
- Update `OVERVIEW.md` with decisions and completed capabilities.
- Add to `HUMAN_NEEDED.md` when blocked.
- Keep `JOURNAL.md` current (session summaries).
- If Formal: keep `STATUS.md` and `/spec/*` truthful.

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
bash .agentic/tools/doctor.sh --full || exit 1
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
cat OVERVIEW.md  # or spec/OVERVIEW.md if Formal

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
bash .agentic/tools/doctor.sh --full

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
bash .agentic/tools/doctor.sh --full

# Check staleness
bash .agentic/tools/stale.sh --days 90

# Agent should update docs in same commit as code
# Check agent_operating_guidelines.md "Documentation Sync Rule"
```

### Common Questions

**Q: Can I edit FEATURES.md myself?**
A: Yes! Agents pick up your changes. Edit freely.

**Q: Will agents overwrite my changes?**
A: No. Agents treat human edits as source of truth. They might add information (like test status) but won't delete your content.

**Q: How do I change feature priority?**
A: Edit `STATUS.md` "Current focus" or tell your agent: *"Make F-#### the priority"*

**Q: Can I skip acceptance criteria?**
A: Not recommended in Formal mode. Acceptance criteria are how agents know when "done" is done. At minimum: 3-5 bullet points.

**Q: What if acceptance criteria are wrong?**
A: Edit `spec/acceptance/F-####.md` anytime. Tell agent: *"I updated F-#### acceptance, please adjust implementation"*

**Q: How do I know what's implemented?**
A: Run `bash .agentic/tools/report.sh` or check `spec/FEATURES.md` "Implementation: State" field.

**Q: What if agent gets stuck?**
A: Agent should add entry to `HUMAN_NEEDED.md`. Check there for blockers.

**Q: Can I work on code without agent?**
A: Yes! Just update `FEATURES.md` status and `JOURNAL.md` when done so agent knows what changed.

### Quality Checks Failing

**Problem:** Your project's `quality_checks.sh` (user-created — see Customization section) fails on commit.

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
curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/v<VERSION>.tar.gz | tar xz
# Replace <VERSION> with the latest from: https://github.com/tomgun/agentic-framework/releases
bash /tmp/agentic-framework-<VERSION>/.agentic/tools/upgrade.sh /path/to/your-project
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
bash .agentic/tools/doctor.sh --full

# Weekly
bash .agentic/tools/doctor.sh --full > weekly-health-check.txt
```

### 4. Use Feature IDs Consistently (Formal Profile)

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

### 7. Log Things in the Right Place

The framework provides multiple tracking files. Use this decision table to route items correctly:

| What you have | Where it goes | How |
|--------------|---------------|-----|
| Development idea, task, or reminder | `TODO.md` | `ag todo "description"` |
| Human blocker (PR review, credentials, decision needed) | `HUMAN_NEEDED.md` | `bash .agentic/tools/blocker.sh add "Title" "type" "Details"` |
| Bug or technical debt | `ISSUES.md` | `bash .agentic/tools/quick_issue.sh "Title" "Details"` |
| New capability to spec | `FEATURES.md` | `bash .agentic/tools/feature.sh add "Title"` |

**Do NOT** put development tasks in HUMAN_NEEDED.md — that file is reserved for items that genuinely require human action (approvals, credentials, external decisions). If an agent can act on it, it belongs in TODO.md.

### 8. Use Brief Context Loads

**Don't load entire codebase every session:**

```
Agent: "Read CONTEXT_PACK.md, STATUS.md, and JOURNAL.md (last 3 entries).
Then load the acceptance criteria for CSV export and continue implementation."
```

Not:
```
Agent: "Read all files in src/ and tell me what's happening"  ❌
```

### 9. Batch Related Changes

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

### 10. Review Before Merging

**Checklist before merge:**
- [ ] All tests pass
- [ ] `bash .agentic/tools/doctor.sh --full` passes
- [ ] FEATURES.md updated (implementation state, code paths, test status)
- [ ] JOURNAL.md updated
- [ ] Acceptance criteria met (check spec/acceptance/F-####.md)
- [ ] Quality checks pass (if you have a `quality_checks.sh` — see Customization section)

### 11. Run Retrospectives

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

**Use worktree.sh for parallel agents:**
```bash
# Create worktree for Agent 2
bash .agentic/tools/worktree.sh create F-0006 "Dashboard"
# → Creates ../project-f-0006/ on branch feature/F-0006
# → Registers in .agentic-state/AGENTS_ACTIVE.md

# Open new Claude/Cursor in ../project-f-0006/
# Agent 2 works there, Agent 1 continues here

# List active agents
bash .agentic/tools/worktree.sh list

# Cleanup when done
bash .agentic/tools/worktree.sh remove F-0006
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

**Pre-commit hook** (the framework uses `core.hooksPath` — install via `ag hooks install`):
```bash
# Installed automatically by: ag hooks install
# Runs framework checks + your quality_checks.sh (if it exists)
ag hooks install
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

### Daily Flow

```
Morning:  Open your AI tool → agent orients itself from STATUS.md + JOURNAL.md
During:   "Implement X" / "Fix Y" / "Plan Z" → agent handles workflows
Evening:  "Let's wrap up and commit" → agent verifies + commits with approval
```

### Manual Fallbacks (when you want direct control)

| Situation | Command |
|-----------|---------|
| Start work session | `ag start` |
| Before commit | `ag verify` or `bash .agentic/tools/doctor.sh --full` |
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
- `spec/FEATURES.md` - Feature list and status (Formal)
- `OVERVIEW.md` - Vision and capabilities (Discovery)

### Essential Agent Prompts

```
# Continue work
"Continue working on the CSV export feature"

# New feature
"Implement the user notifications feature using TDD"

# Plan first
"Let's plan the authentication changes before coding"

# Research
"Research Agent: investigate authentication options for Next.js (OAuth, JWT)"

# Review
"Review the CSV export implementation against acceptance criteria"

# Fix
"Fix the test failures in test_csv_export.py"

# Update
"I updated the acceptance criteria for CSV export. Please adjust implementation"

# Commit
"All tests pass. Please commit with appropriate message"
```

---

## Getting Help

**Framework Documentation:**
- Quick start: `.agentic/START_HERE.md`
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

**Version:** 0.28.1
**Last updated:** 2026-02-19

