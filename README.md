# Agentic AI Framework

> ## 📦 ARCHIVED (2026-08-23)
> This repo is preserved as read-only design history. Active development moved to
> **[agentic-af-for-claude](https://github.com/tomgun/agentic-af-for-claude)** — a ground-up
> v6 rebuild (Claude Code–first plugin + small deterministic checker) that distills this
> repo's specs and lessons. The why, the architecture, and the multi-agent review record
> live in the new repo's `product/plans/2026-08-founding-plan.md`.

**Portable, token-efficient, spec-and-test-driven framework for agentic/assisted software development.**

*Shortname: Agentic AF*
*Alternative name: Agentic Spec-Driven Framework, short: ASDF*


[![Latest Release](https://img.shields.io/github/v/release/tomgun/agentic-framework?label=version)](https://github.com/tomgun/agentic-framework/releases/latest)

**📖 Quick Links:**
- [**WTF.md**](WTF.md) ⭐ - Welcome to the Framework — concise overview with diagrams
- [**DEVELOPER_GUIDE.md**](.agentic/DEVELOPER_GUIDE.md) ⭐ - Complete usage guide (daily workflows, scripts, customization)
- [**PRINCIPLES.md**](.agentic/PRINCIPLES.md) ⭐ - Framework values & why we do what we do
- [**CREDITS.md**](CREDITS.md) - Contributors and acknowledgments
- [START_HERE.md](.agentic/START_HERE.md) - Quick start in 5 minutes
- [MANUAL_OPERATIONS.md](.agentic/MANUAL_OPERATIONS.md) - Token-free information retrieval
- [DEVELOPER_GUIDE.md → Working with Agents](.agentic/DEVELOPER_GUIDE.md#working-with-agents) - Agent workflows & common questions
- [Example Projects](examples/) - See it in action
- 🚨 [**FRAMEWORK_DEVELOPMENT.md**](FRAMEWORK_DEVELOPMENT.md) - For contributors working on the framework itself

## What is this?

The Agentic AI Framework enables **sustainable long-term software development with AI agents**. It provides structure, conventions, and tooling that keep both humans and AI agents aligned as projects evolve from prototypes to production systems.

## Why not just a `.cursorrules` or `CLAUDE.md`?

A custom rules file is a great start. This framework builds on the same idea but solves problems that emerge after weeks and months of AI-assisted development:

| Problem | `.cursorrules` / `CLAUDE.md` | This Framework |
|---------|------------------------------|----------------|
| **Context resets** | Agent forgets everything each session | Durable artifacts (CONTEXT_PACK, STATUS, JOURNAL) survive resets |
| **Inconsistent behavior** | Guidelines agents may or may not follow | Enforced gates — scripts with exit codes that block bad commits |
| **Token waste** | Agents re-read entire codebases each session | Token-efficient tools (40x savings measured), structured reading protocols |
| **Tool lock-in** | Rules file works in one tool only | Works across Claude, Cursor, Copilot, and Codex — same project state |
| **Quality drift** | No enforcement mechanism for rules | Pre-commit hooks, WIP tracking, acceptance criteria validation |
| **Hallucinated code** | No verification system | Anti-hallucination rules with LLM behavioral tests that verify compliance |
| **Scaling** | One agent, one context window | Multi-agent coordination with worktrees, sequential agent pipelines |

**What's battle-tested** (proven through months of dogfooding this framework):
- Durable artifacts, token-efficient scripts, session continuity, acceptance-driven development, pre-commit gates, WIP recovery, multi-environment switching

**What's designed for** (implemented with tooling, growing in real-world usage):
- Multi-agent coordination at scale, sequential agent pipelines, automated retrospectives
- Autonomous workflow modes: test-fix loops, per-AC feature implementation, multi-feature batch processing

**How we know it works**: 750+ acceptance tests + 107 LLM behavioral tests verify that agents actually follow the rules. See [TRACEABILITY_MATRIX.md](tests/TRACEABILITY_MATRIX.md) for principle → feature → test mapping.

**📖 Detailed problem analysis**: [FRAMEWORK_VALUE_PROPOSITION.md](docs/FRAMEWORK_VALUE_PROPOSITION.md)

**Two profiles available** (profiles are presets — override any setting with `ag set <key> <value>`):

- **Discovery**: Full framework capabilities with lightweight planning
  - Context optimization (CONTEXT_PACK.md)
  - Session continuity (JOURNAL.md)
  - Multi-agent coordination
  - Test-driven development support
  - Token efficiency guidelines
  - Green coding principles
  - Quality gates (doctor.sh)
  - Human escalation (HUMAN_NEEDED.md)
  - Lightweight planning (OVERVIEW.md)

- **Formal**: Everything in Discovery, plus formal specs
  - Feature tracking with F-#### IDs
  - Acceptance criteria per feature (priority tiers P1/P2, Behavior section)
  - STATUS.md for current focus
  - spec/FEATURES.md, NFR.md, ADRs
  - Cross-reference validation
  - Semantic spec analysis (ambiguity detection, AC↔test coverage gaps, NFR measurability)
  - Component registry for monorepos (`## Components` in STACK.md — scoped context, test commands, feature tracking)
  - User-extension directory (`.agentic/local/extensions/` for custom skills and gates)

- **Intelligence Engine** (both profiles):
  - Enforced anti-patterns checked at write-time (`ag intel learn/check`)
  - Project knowledge from user decisions and corrections (`ag intel remember` → project-memory.yaml)
  - Stack-specific quality checklists and test strategies (`ag intel bootstrap`)
  - Phase-aware queries surface relevant intelligence at each workflow phase (`ag intel architecture|spec|implement|test`)
  - File anatomy with token estimates for smarter context loading (`ag intel scan/file`)
  - Session + lifetime token metrics for usage awareness (`ag intel stats`)

**🔄 Multi-Tool Support:**
Works best with Claude Code (full hook integration, skills, intelligence engine). Instruction files also generated for Cursor, Copilot, and Codex — CLI commands and state files work in any tool. Intelligence files (`.agentic/intel/`) are agent-agnostic.

## Installation

### One-liner install (Recommended)

```bash
# Run from your project directory
curl -fsSL https://raw.githubusercontent.com/tomgun/agentic-framework/main/remote-install.sh | bash
```

Options:
```bash
# Install specific version
VERSION=v0.64.0 curl -fsSL https://raw.githubusercontent.com/tomgun/agentic-framework/main/remote-install.sh | bash

# Install to different directory
TARGET=/path/to/project curl -fsSL https://raw.githubusercontent.com/tomgun/agentic-framework/main/remote-install.sh | bash
```

### Manual install

```bash
# Download latest release (auto-redirects to newest version)
curl -sL https://api.github.com/repos/tomgun/agentic-framework/releases/latest | \
  grep tarball_url | cut -d '"' -f 4 | xargs curl -L | tar xz
cd tomgun-agentic-framework-*

# Install into your project
bash install.sh /path/to/your-project
```

The install script will:
1. Copy `.agentic/` folder with correct version number
2. Run scaffold script (creates template files)
3. Update `STACK.md` with framework version and install date

**After installation**, tell your agent:

> "Read `.agentic/lib/init/init_playbook.md` and help me initialize this project by filling in STACK.md, OVERVIEW.md, and CONTEXT_PACK.md based on what we're building."

The agent will:
- Ask what you're building
- **Ask which profile to use** (Discovery or Formal)
- Interview you about tech stack, constraints, etc.
- Fill in all project-specific details
- Set up quality checks

### Alternative: Copy .agentic/ directly

```bash
# Download and extract latest
curl -sL https://api.github.com/repos/tomgun/agentic-framework/releases/latest | \
  grep tarball_url | cut -d '"' -f 4 | xargs curl -L | tar xz

# Copy .agentic/ into your project
cp -r tomgun-agentic-framework-*/.agentic /path/to/your-project/
```

Then follow the same agent initialization process above. The agent will run `scaffold.sh` for you.

## Design Principles

**📖 Full detail with rationale: [`PRINCIPLES.md`](.agentic/PRINCIPLES.md)** ⭐

3 FOUNDATION + 7 DESIGN PRINCIPLES + 3 OPERATIONAL RULES (13 total, all mandatory). Each non-foundation principle traces back to parent foundations via a derivation DAG.

#### FOUNDATION (WHY — the reasons this framework exists)

### F1. Developer-Friendly Experience
**The framework makes the developer's life easier.**
Session dashboard reconstructs context, documentation is automatic, state carries across sessions. The developer doesn't have to remember what happened — the framework remembers for them.

### F2. Sustainable Long-Term Development & Quality Software
**Properly designed, tested, documented software that stays reliable over time.**
When specs, criteria, and tests exist, agents can't silently regress working features. Programming standards loaded by default, durable artifacts survive context resets, observable progress visible to both humans and agents.

### F3. Token & Context Optimization
**The #1 unique technical insight: tokens cost money, context is limited.**
Structured reading protocols with token budgets. Agent delegation for fresh context. Sequential agents load only role-specific context. Token-efficient scripts (40x cheaper than read-modify-write). Manual operations for zero-token information retrieval. See `.agentic/token_efficiency/` for quantified savings (60-83% typical).

#### DESIGN PRINCIPLES (HOW — strategies that serve the foundations)

### D1. Human-Agent Partnership
**Humans define WHAT, agents handle HOW. Neither alone is optimal.**
Humans edit specs directly (markdown), agents honor edits as source of truth. Framework makes review efficient (diff stats, scope warnings) but never eliminates it. `HUMAN_NEEDED.md` for escalation.

### D2. Deterministic Enforcement
**Scripts and gates enforce behavior, not documentation and hope.**
Pre-commit hooks block if WIP exists or acceptance files missing. `feature.sh` enforces valid status transitions. Hard gates for hard rules, soft warnings for judgment calls. Works the same regardless of which AI model runs them.

### D3. Durable Artifacts
**Living documents readable by both humans and agents.**
`CONTEXT_PACK.md` (architecture), `STATUS.md` (current state), `JOURNAL.md` (progress history), `HUMAN_NEEDED.md` (decisions needed). Agents read these first; humans can `cat STATUS.md` for instant awareness (zero tokens). The core mechanism for surviving context resets.

### D4. Small Batch + Acceptance-Driven Development
**One feature at a time, acceptance criteria before code.**
MAX 5-10 files per commit. Specs evolve during implementation. Shipped ≠ Accepted (human validation is final gate). TDD available as option.

### D5. Living Documentation
**Docs updated in same commit as code. Single source of truth.**
No stale placeholders. DRY (cross-reference, don't duplicate). Explicit over implicit — agents need explicitness.

### D6. Green Coding
**Efficient software reduces energy consumption and cost.**
Token efficiency IS green for framework ops. For project code: algorithms, caching, event-driven patterns. See [green_coding.knowledge.md](.agentic/lib/quality_knowledge/green_coding.knowledge.md) for comprehensive guidelines.

### D7. Multi-Environment Portability
**Work seamlessly across Claude Code, Cursor, Copilot, and Codex.**
Same project state, same conventions, same enforcement — regardless of which tool runs the session. Instruction parity, distributed enforcement via scripts, tool-agnostic state files.

#### OPERATIONAL RULES (WHAT — concrete, testable constraints)

### R1. Anti-Hallucination
**Agents NEVER make things up — accuracy over speed.**
"I don't know" is explicitly encouraged. Verify against version-specific docs. Wrong code that looks right is worse than no code. See [agent guidelines](.agentic/lib/agents/shared/agent_operating_guidelines.md) for complete rules.

### R2. No Auto-Commits
**Human approval required before every commit.** The safety gate that prevents compounding mistakes.

### R3. Check Before Creating
**Search before creating any file, test, doc, or component.** Duplication wastes effort and causes inconsistency. A 30-second search prevents hours of duplicate work.

## How It Works: Three-Layer Architecture

AI coding tools have limited context windows. Stuffing everything into a `.cursorrules` or `CLAUDE.md` file doesn't scale — agents lose focus as instruction files grow, and structurally-enforced content (like pre-commit hooks) doesn't need to be in the context window at all.

The framework uses a **three-layer architecture** that respects context limits while ensuring consistent behavior:

### Layer 1: Constitution (Always Loaded)
Instruction files (`CLAUDE.md`, `.cursorrules`, `copilot-instructions.md`) — kept under **100 lines**. Only behavioral rules that *cannot* be enforced structurally. These are the only files that compete for the agent's attention budget.

### Layer 2: Playbooks (Just-in-Time)
Skills, checklists, and quality knowledge (`skills/`, `checklists/`, `quality_knowledge/`) — loaded by `ag` commands when needed, never pinned in the instruction file. This keeps the constitution small while providing deep guidance for specific tasks.

### Layer 3: State (Durable Artifacts)
Project truth that survives context resets (`STACK.md`, `STATUS.md`, `CONTEXT_PACK.md`, `JOURNAL.md`). Git-tracked files work cross-machine; gitignored files (`.agentic/session/`) are session-local. Agents read these first; humans can `cat STATUS.md` for instant awareness at zero token cost.

### Distributed Enforcement
Three scripts enforce behavior regardless of which AI tool runs them:
- **`ag.sh`** — CLI that loads the right playbook for each task
- **`pre-commit-check.sh`** — gates that block bad commits (exit codes, not advice)
- **`context-for-role.sh`** — assembles minimal context per subagent (60-80% token savings)

This works across Claude Code, Cursor, Copilot, and Codex — no single orchestrator process required.

**Deep dive**: [`docs/INSTRUCTION_ARCHITECTURE.md`](docs/INSTRUCTION_ARCHITECTURE.md) — the authoritative design document.

## Quick Start

### Agent-driven initialization

**After installation**, tell your agent:

> "Read `.agentic/lib/init/init_playbook.md` and help me initialize this project."

**Or use a ready-made prompt**: Copy from `.agentic/prompts/cursor/session_start.md` or `.agentic/prompts/claude/session_start.md`

The agent will:
1. Ask what you're building
2. **Ask which profile you want** (a=Discovery or b=Formal) and explain the differences
3. Interview you about your tech stack and requirements
4. Fill in `STACK.md`, `OVERVIEW.md`, `CONTEXT_PACK.md` (and `spec/` if Formal)
5. Set up quality validation for your stack

**Now you're ready!** The agent understands your project and can start building.

**New to the framework?** → Tell your agent: *"Read `.agentic/START_HERE.md` and explain how to use this framework"*

**Pre-project planning?** → See `.agentic/lib/init/VISION.template.md` for ideation-phase template.

### Upgrading existing projects

```bash
# Run from your project directory
curl -fsSL https://raw.githubusercontent.com/tomgun/agentic-framework/main/remote-upgrade.sh | bash
```

Or manually:
```bash
curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/v0.64.0.tar.gz | tar xz
bash agentic-framework/install.sh /path/to/your-project
```

The upgrade script will:
- Backup your existing `.agentic/` folder
- Copy new framework files
- Preserve your customizations
- Update version in `STACK.md`
- Run validation

See `UPGRADING.md` for detailed instructions.

### For evaluating the framework

- **Full documentation**: [`.agentic/README.md`](.agentic/README.md)
- **Quick tour**: [`.agentic/START_HERE.md`](.agentic/START_HERE.md)
- **Visual guide**: [`.agentic/FRAMEWORK_MAP.md`](.agentic/FRAMEWORK_MAP.md)
- **Example projects**: [`examples/`](examples/) (Discovery and Formal modes)

See [CHANGELOG.md](CHANGELOG.md) for version history.

## Multi-Environment Support 🔄

**Work seamlessly across Claude Code, Cursor, and GitHub Copilot in the same project.**

### Why Multi-Environment?

**Token limits exist:** Claude Code (200K) → Cursor (50K) → GitHub Copilot (8K)

Instead of stopping when tokens run out, **switch to another tool and keep working**. The framework makes handoff seamless because all tools share the same project state.

### How It Works

**All environments read/write the same files:**
- `JOURNAL.md` - Session history and decisions
- `FEATURES.md` - Feature status and acceptance criteria
- `STATUS.md` - Current project state
- `HUMAN_NEEDED.md` - Blockers requiring human action
- Token-efficient scripts - Work in all environments (40x cheaper than file reads!)

**Example workflow:**
1. **Morning (Claude Code)**: Complex feature with full codebase context
2. **Afternoon (Claude tokens low)**: Switch to Cursor, continue implementation
3. **Quick fix needed**: Use Copilot for inline suggestions
4. **Next morning**: Back to Claude, seamless continuation

### Setting Up Multi-Environment

During `init_playbook.md`, choose **"a) Multiple (RECOMMENDED)"** and the framework will:
- Install Claude instructions (`CLAUDE.md` + hooks)
- Install Cursor rules (`.cursor/rules/*.mdc`)
- Install Copilot instructions (`.github/copilot-instructions.md`)
- Configure shared state files
- Set up token-efficient scripts

**Learn more:**
- [Environment Research](.agentic/support/environment_research.md) - Capabilities & optimizations

### Best Tool for Each Task

**Claude Code** (200K context):
- ✅ Complex features requiring full codebase understanding
- ✅ Architectural decisions and planning
- ✅ Research and documentation (artifacts)
- ✅ Initial project setup

**Cursor** (50K context):
- ✅ Multi-file refactors
- ✅ Feature implementation across modules
- ✅ IDE-integrated work with @ mentions
- ✅ Composer mode for batch edits

**GitHub Copilot** (8K context):
- ✅ Quick inline suggestions
- ✅ Single-file edits
- ✅ Small bug fixes
- ✅ When other tools unavailable

**Switching between tools?** Each tool automatically picks up where the previous left off via shared markdown files!

## What You Get

### Discovery Framework (Always Included)
- **Agent operating guidelines**: Consistent behavior across AI tools
- **Quality standards**: Programming, testing, review, design-for-testability
- **Development workflows**: TDD mode, dev loop, debugging, git workflow
- **Multi-agent coordination**: Multiple agents working in parallel
- **Research mode**: Deep investigation workflows
- **Token efficiency guides**: Reading protocols, context budgeting
- **Basic tools**: doctor.sh (with --full, --phase, --pre-commit modes), dashboard, phase_detect

### Optional: Formal Profile Add-On
- **Specification templates**: PRD, Tech Spec, Features, NFR, ADR, Tasks
- **Feature tracking**: Stable IDs, dependencies, status tracking
- **Sequential pipeline**: Specialized agents per feature (Research → Plan → Test → Implement → Review)
- **Project status**: STATUS.md for roadmap and current focus
- **Advanced tools**: Feature graphs, consistency checks, staleness detection
- **Quality automation**: Stack-specific pre-commit validation
- **Retrospectives**: Periodic project health checks

Enable later: `bash .agentic/lib/tools/enable-formal.sh` | Customize settings: `ag set --show`

### For Complex Projects
- **Session continuity**: JOURNAL.md tracks progress across context resets
- **Dependency tracking**: Feature dependencies with visualization
- **Human escalation**: HUMAN_NEEDED.md for decisions requiring judgment
- **Architecture evolution**: Track changes with CONTEXT_PACK.md snapshots
- **Research trails**: Structured documentation of research findings
- **Scaling guidance**: Suggestions when complexity crosses thresholds
- **Project retrospectives**: Periodic agent-led health checks
- **Research mode**: Deep investigation into technologies and best practices
- **Documentation verification**: Ensures agents use current, version-correct docs
- **Spec validation**: Automatic validation of spec files against schemas
- **Continuous quality validation**: Stack-specific quality gates before commits
- **Multi-agent coordination**: Multiple AI agents working simultaneously with Git worktrees
- **PR workflow**: Optional pull request mode for team collaboration
- **Autonomous workflow modes**: Test-fix loops (`ag auto verify`), per-feature implementation (`ag auto task`), multi-feature batch processing (`ag auto crunch`) with three-tier trust model

### Tooling
```bash
# Project health & verification (v0.11.2: doctor.sh is THE verification command)
bash .agentic/lib/tools/doctor.sh              # Quick health check
bash .agentic/lib/tools/doctor.sh --full       # Comprehensive verification
bash .agentic/lib/tools/doctor.sh --phase X    # Phase-specific (start/planning/implement/complete/commit)
bash .agentic/lib/tools/doctor.sh --pre-commit # Pre-commit gate checks
bash .agentic/lib/tools/report.sh              # Feature status summary
python3 .agentic/lib/tools/phase_detect.py     # Detect current development phase

# Retrospectives & version checking
bash .agentic/lib/tools/retro_check.sh    # Check if retrospective is due
bash .agentic/lib/tools/version_check.sh  # Check dependency versions

# Context & analysis
bash .agentic/lib/tools/brief.sh       # Quick project brief
bash .agentic/lib/tools/dashboard.sh   # Comprehensive dashboard
bash .agentic/lib/tools/coverage.sh    # Code annotation coverage
bash .agentic/lib/tools/feature_graph.sh   # Dependency visualization
ag qa                                  # QA Registry — feature-to-test coverage map

# Autonomous workflow modes
ag auto verify                    # Test-fix loop until green
ag auto task F-XXXX               # Implement single feature autonomously
ag auto crunch                    # Batch implement planned features
ag auto init --tier 2             # Generate scoped permissions

# Manual operations (token-free)
bash .agentic/lib/tools/whatchanged.sh # Recent changes
bash .agentic/lib/tools/deps.sh        # Feature dependencies
bash .agentic/lib/tools/accept.sh      # Run acceptance tests
bash .agentic/lib/tools/sync.sh --check # Check doc staleness + drift
bash .agentic/lib/tools/task.sh        # Create task files

# Advanced quality (optional)
bash .agentic/lib/tools/mutation_test.sh [path]  # Mutation testing for critical code
```

### Stack Profiles
Quick-start guidance for common technology stacks:
- Generic/default, Full-stack webapp, Native iOS
- Go backend services, Python ML projects
- Rust systems programming, React Native mobile

## Key Artifacts

### Discovery Profile Files
**Project State:**
- `STACK.md` - How to build, test, run, and deploy (with profile setting)
- `.agentic/journal/JOURNAL.md` - Session-by-session progress log
- `CONTEXT_PACK.md` - Durable context (architecture, where things are)
- `HUMAN_NEEDED.md` - Items requiring human decision/intervention

### Formal Profile Adds
**Specifications:**
- `STATUS.md` - Current focus, roadmap, known issues
- `spec/PRD.md` - Requirements (why, what)
- `spec/TECH_SPEC.md` - Architecture (how)
- `spec/FEATURES.md` - Feature registry with IDs, status, tests
- `spec/NFR.md` - Non-functional requirements
- `spec/acceptance/F-####.md` - Acceptance criteria per feature
- `spec/adr/` - Architecture Decision Records

## Examples

- **Traced Notes App**: [`examples/traced_notes_app/`](examples/traced_notes_app/) - Example project with full framework integration
- **Archived examples**: [`examples/archived/`](examples/archived/) - Discovery Todo CLI and Formal Taskboard examples (historical)

## For Existing Projects

Already have a project? The framework integrates non-invasively:

1. Download release and extract `.agentic/` folder into your repo
2. Tell your agent: "Initialize the agentic framework for this existing project"
3. Agent analyzes existing code and fills in specs
4. Adopt practices incrementally (tests first, then specs, then workflows)

## Upgrading

**Already using the framework?** Upgrade to the latest version:

```bash
# One-liner (run from your project directory)
curl -fsSL https://raw.githubusercontent.com/tomgun/agentic-framework/main/remote-upgrade.sh | bash
```

Or manually:
```bash
cd /tmp
curl -sL https://api.github.com/repos/tomgun/agentic-framework/releases/latest | \
  grep tarball_url | cut -d '"' -f 4 | xargs curl -L | tar xz
bash /tmp/tomgun-agentic-framework-*/.agentic/tools/upgrade.sh /path/to/your-project
rm -rf /tmp/tomgun-agentic-framework-*
```

**Why from the new framework?** The new upgrade script has the latest bug fixes and knows about new structure changes.

See **[`UPGRADING.md`](UPGRADING.md)** for complete upgrade guide, version compatibility, and troubleshooting.

## License & Contributing

**Agentic AI Framework** is proprietary software by **Tomas Günther / Kipinä Software Oy**.

### Three Licensing Options:

1. **Free Tier (with Attribution)** ⭐
   - Use in any personal, open source, or commercial project
   - Must include visible attribution in your product
   - Example: "Built with Agentic AI Framework"

2. **Commercial Tier (White-Label)**
   - €499 one-time OR €99/year per product
   - Remove all attribution requirements
   - Priority support included

3. **Kipinä Software Oy & Employees**
   - Free use without attribution
   - Any projects (personal, commercial, client work)

**See [LICENSE](LICENSE) for complete terms.**

### Attribution Examples (Free Tier)

**Web app footer:**
```html
Built with <a href="https://github.com/tomgun/agentic-framework">Agentic AI Framework</a>
```

**Desktop/Mobile app "About":**
```
Built with Agentic AI Framework
```

**CLI tool `--version`:**
```
Built with Agentic AI Framework (https://github.com/tomgun/agentic-framework)
```

### Commercial License

To purchase white-label license: **tomas@kipina.fi**

---

### Contributing

[Add your contribution guidelines]

## Getting Help

- **Documentation**: Start at [`.agentic/START_HERE.md`](.agentic/START_HERE.md)
- **Examples**: See [`examples/`](examples/) directory
- **Issues**: [GitHub Issues](https://github.com/tomgun/agentic-framework/issues)

---
