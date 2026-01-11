# Repo Init (Agent-Guided) Playbook

Goal: in one short planning session, produce **durable repo artifacts** so any agent can work effectively with minimal repeated context.

## Outputs (authoritative context)
Create/update these at repo root:
- `STACK.md` (from `.agentic/init/STACK.template.md`)
- `PRODUCT.md` (from `.agentic/init/PRODUCT.template.md`) - for Core mode
- `CONTEXT_PACK.md` (from `.agentic/init/CONTEXT_PACK.template.md`)
- `STATUS.md` (from `.agentic/init/STATUS.template.md`) - for Core+PM mode
- `/spec/` (from `.agentic/spec/*.template.md`) - for Core+PM mode
- `spec/adr/` (directory exists; can be empty at start)

## Step 0: scaffold files/folders (if not already done)
If `install.sh` was used, templates are already created. Otherwise, run:

```bash
bash .agentic/init/scaffold.sh
```

This creates all expected files/folders with templates/placeholders so you can start development immediately.

## Step 1: Choose profile (Core vs Core+PM)

**Ask the user which profile they want:**

> "Which profile would you like to use?
> 
> **a) Core (Simple Setup)**
> - Quality standards, multi-agent, research mode
> - Lightweight planning (PRODUCT.md with checkboxes)
> - Minimal ceremony, fast iteration
> - Good for: Small projects, prototypes, external PM tools (Jira/Linear), quick experiments
> 
> **b) Core + Product Management**
> - Everything in Core, plus formal specs & feature tracking
> - STATUS.md, spec/PRD.md, spec/FEATURES.md with F-#### IDs
> - Acceptance criteria, sequential pipeline, advanced tools
> - Good for: Long-term projects (3+ months), complex products, audit trails
> 
> Type 'a' for Core or 'b' for Core+PM"

### Core Profile (a)
- ✅ Quality standards (programming, testing, TDD)
- ✅ Multi-agent coordination
- ✅ Research mode
- ✅ `PRODUCT.md` for lightweight planning (checkboxes)
- ✅ Minimal ceremony, fast iteration
- **Good for**: 
  - Small/simple projects or prototypes
  - Projects with external PM tools (Jira, Linear, etc.)
  - Solo developers who don't need formal tracking
  - Quick experiments and MVPs

### Core + Product Management Profile (b)
- ✅ Everything in Core, plus:
- ✅ Formal specifications (`spec/PRD.md`, `TECH_SPEC.md`)
- ✅ Feature tracking with F-#### IDs
- ✅ `STATUS.md` for roadmap and metrics
- ✅ Acceptance criteria per feature
- ✅ Sequential pipeline (specialized agents)
- **Good for**: 
  - Long-term projects (3+ months of development)
  - Human-machine teams collaborating on product
  - Complex products requiring traceability
  - Projects needing audit trails and formal specs

**Update `STACK.md`** with the chosen profile:
```markdown
- Profile: core  <!-- if user chose 'a' -->
- Profile: core+product  <!-- if user chose 'b' -->
```

## Step 1a: Set up your AI tool(s)

**Ask the user which AI tool(s) they use:**

> "Which AI coding tool(s) will you use? (can pick multiple)
> 
> **a) Claude Code** - creates CLAUDE.md
> **b) Cursor** - creates .cursorrules
> **c) GitHub Copilot** - creates .github/copilot-instructions.md
> **d) Codex CLI** - uses AGENTS.md
> **e) Gemini** - creates GEMINI.md
> 
> Type the letters for tools you use (e.g., 'ab' for Claude + Cursor, or just 'b' for Cursor only)"

**Create files for ALL selected tools:**

```bash
# Examples based on user response:
# User typed 'a' → 
bash .agentic/tools/setup-agent.sh claude

# User typed 'ab' → 
bash .agentic/tools/setup-agent.sh claude
bash .agentic/tools/setup-agent.sh cursor

# User typed 'abc' → 
bash .agentic/tools/setup-agent.sh claude
bash .agentic/tools/setup-agent.sh cursor
bash .agentic/tools/setup-agent.sh copilot
```

**To add more tools later:**
```bash
bash .agentic/tools/setup-agent.sh <tool>
```

All tool files reference the same common rules (`.agentic/agents/shared/`), so switching is seamless.

### If Claude Code (a):
```bash
# Set up Claude (creates CLAUDE.md automatically)
bash .agentic/tools/setup-agent.sh claude

# Enable Claude hooks (automatic checkpoints!)
mkdir -p .claude
cp .agentic/claude-hooks/hooks.json .claude/hooks.json

echo "✓ Claude Code optimized:"
echo "  - CLAUDE.md installed (instructions)"
echo "  - Hooks enabled (automatic logging at checkpoints)"
echo "  - Large context leveraged (can read all specs at once)"
```

### If Cursor (b):
```bash
# Modern Cursor (0.42+)
mkdir -p .cursor/rules
cp .agentic/agents/cursor/agentic-framework.mdc .cursor/rules/

# Fallback for older Cursor
cp .agentic/agents/cursor/cursorrules.txt .cursorrules

echo "✓ Cursor optimized:"
echo "  - .cursor/rules/agentic-framework.mdc installed"
echo "  - Use @ mentions for precise context (@FEATURES.md, @Codebase)"
echo "  - Use composer mode for multi-file edits"
echo "  - Token-efficient scripts recommended (smaller context than Claude)"
```

### If GitHub Copilot (c):
```bash
# Copilot instructions
mkdir -p .github
cp .agentic/agents/copilot/copilot-instructions.md .github/

echo "✓ Copilot optimized:"
echo "  - .github/copilot-instructions.md installed (ULTRA-CONCISE for 8K limit)"
echo "  - Token-efficient scripts CRITICAL (context very limited)"
echo "  - Work file-by-file (no multi-file operations)"
echo "  - User must apply suggestions (Copilot can't edit directly)"
```

### If Multiple (a) - RECOMMENDED:
```bash
# Install all tool adapters for seamless environment switching
bash .agentic/tools/setup-agent.sh all

# Enable Claude hooks for automatic checkpoints (optional but recommended)
mkdir -p .claude && cp .agentic/claude-hooks/hooks.json .claude/

echo "✓ Multi-environment setup complete:"
echo ""
echo "  You can now switch seamlessly between:"
echo "  - Claude Code (CLAUDE.md + hooks) → Large context, hooks"
echo "  - Cursor (.cursor/rules/) → @ mentions, composer"
echo "  - Copilot (.github/) → Quick edits, inline suggestions"
echo ""
echo "  All tools share:"
echo "  - AGENTS.md (common behavioral rules)"
echo "  - JOURNAL.md, FEATURES.md, STATUS.md (project state)"
echo "  - Token-efficient scripts (work for all tools)"
echo ""
echo "  Typical workflow:"
echo "  1. Start with Claude (large context, can read all specs)"
echo "  2. Switch to Cursor when Claude tokens run out"
echo "  3. Use Copilot for quick edits (when others unavailable)"
echo ""
```

**Multi-Environment Workflow:**

When switching between tools, the handoff is seamless because:
1. **Shared state files**: JOURNAL.md, FEATURES.md, STATUS.md, HUMAN_NEEDED.md
2. **Common scripts**: Token-efficient scripts work in all environments
3. **Unified checklists**: session_start.md, session_end.md work everywhere
4. **AGENTS.md**: Common behavioral contract

**Example: Claude → Cursor → Copilot chain:**

1. **Morning (Claude Code - tokens fresh)**:
   ```
   # Claude reads all specs, starts complex feature
   # Hooks auto-log checkpoints
   # Uses large context to understand entire codebase
   ```

2. **Afternoon (Claude tokens running low)**:
   ```
   # Switch to Cursor
   # Cursor reads SESSION_LOG.md to see what Claude did
   # Uses @FEATURES.md for context
   # Continues feature implementation
   ```

3. **Evening (Cursor tokens low, need quick fix)**:
   ```
   # Switch to Copilot
   # Copilot reads JOURNAL.md (last entry)
   # Makes quick inline edits
   # Uses blocker.sh to note any issues
   ```

4. **Next morning (back to Claude)**:
   ```
   # Claude SessionStart hook loads .continue-here.md
   # Sees full progress from all tools
   # Continues seamlessly
   ```

**Update STACK.md** with environment info:
```markdown
## Agentic framework
- Version: [version]
- Profile: [core | core+product]
- AI Environments: [multi | claude | cursor | copilot]  # NEW! "multi" = can use all
```

**Note**: "multi" means all environment adapters are installed. You can switch freely:
- Out of Claude tokens? → Open project in Cursor
- Out of Cursor tokens? → Use Copilot in VS Code
- Back home? → Continue with Claude Code
- All tools see same project state (JOURNAL, FEATURES, etc.)

**Environment-specific tips:**

**Claude Code users:**
- Hooks run automatically (SessionStart, PostToolUse, PreCompact)
- Large context = can read all specs simultaneously
- Use artifacts for diagrams/documentation drafts

**Cursor users:**
- Use `@FEATURES.md` to load specific docs
- Use `@Codebase "search"` for project-wide search
- Composer mode for multi-file edits

**Copilot users:**
- Context is TINY (8K tokens) - be ruthlessly efficient
- Use token-efficient scripts religiously
- Work one file at a time
- You apply suggestions (Copilot can't edit directly)

## Step 1b: Check framework age and offer research

**Check if framework is outdated:**

```bash
# Get framework version and age
FRAMEWORK_VERSION=$(cat .agentic/../VERSION 2>/dev/null || echo "unknown")
FRAMEWORK_DATE=$(git -C .agentic log -1 --format=%cd --date=short 2>/dev/null || echo "unknown")

# Calculate age in days (if git available)
if [[ "$FRAMEWORK_DATE" != "unknown" ]]; then
  CURRENT_TIMESTAMP=$(date +%s)
  FRAMEWORK_TIMESTAMP=$(date -d "$FRAMEWORK_DATE" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$FRAMEWORK_DATE" "+%s" 2>/dev/null || echo "0")
  DAYS_OLD=$(( (CURRENT_TIMESTAMP - FRAMEWORK_TIMESTAMP) / 86400 ))
  
  if [[ $DAYS_OLD -gt 90 ]]; then
    echo ""
    echo "⚠️  Framework is ${DAYS_OLD} days old (>3 months)"
    echo "   AI tool capabilities evolve rapidly. Framework may be outdated."
    echo ""
    echo "   STRONGLY RECOMMEND: Research current best practices"
    echo "   - Claude Code latest features (hooks, context, APIs)"
    echo "   - Cursor latest features (agentic mode, composer, @ mentions)"
    echo "   - Copilot latest features (context window, workspaces)"
    echo ""
    echo "   To research: Ask agent to check official docs and update"
    echo "                .agentic/support/environment_research.md"
    echo ""
  elif [[ $DAYS_OLD -gt 30 ]]; then
    echo ""
    echo "ℹ️  Framework is ${DAYS_OLD} days old (>1 month)"
    echo "   Consider researching latest AI tool features."
    echo ""
    echo "   OPTIONAL: Update environment optimizations"
    echo "   - Check for new [Claude/Cursor/Copilot] features"
    echo "   - Review .agentic/support/environment_research.md"
    echo ""
  else
    echo "✓ Framework is current (${DAYS_OLD} days old)"
  fi
fi
```

**If framework is old, offer research prompt:**

> "The framework was last updated ${DAYS_OLD} days ago. AI coding tools evolve rapidly.
> 
> Would you like to research latest capabilities for ${YOUR_ENVIRONMENT}?
> 
> If yes, I'll:
> 1. Check official docs for latest features
> 2. Update .agentic/support/environment_research.md
> 3. Adjust environment-specific instructions
> 4. Document any breaking changes
> 
> Research now? (y/n)"

**If user says yes:**
```markdown
## Research Task

Please research current best practices for [environment]:

### Claude Code
- Official docs: https://docs.anthropic.com/claude/desktop
- Check: Hooks, context window, new APIs, Claude 4 features
- Focus: Anything that impacts how agents should work

### Cursor
- Official docs: https://cursor.sh/docs
- Check: Agentic mode, composer updates, @ mentions, rules format
- Focus: New instruction capabilities, context improvements

### Copilot
- Official docs: https://docs.github.com/copilot
- Check: Context window size, workspace features, new capabilities
- Focus: Any changes to instruction format or capabilities

### Steps:
1. Research official documentation
2. Update .agentic/support/environment_research.md
3. Update environment-specific instruction files if needed
4. Document findings in JOURNAL.md
5. Note any breaking changes in HUMAN_NEEDED.md
```

## Step 2: run init as an agent-guided planning session

Interview the user to understand:

1. **What are we building?** (1-2 sentence summary)
2. **Primary platform?** (web/mobile/desktop/cli/game/audio plugin/etc.)
3. **Tech stack?** (languages, frameworks, runtimes)
4. **Key constraints?** (performance, security, compliance, offline-first, etc.)
5. **Testing approach?** (TDD recommended, what test frameworks?)
6. **Project license?** (See Step 2a below - IMPORTANT!)

### Step 2a: Ask about project licensing ⭐

**This is CRITICAL - affects what dependencies and assets you can use!**

Ask the user:

```
"What license do you want for this project?

**For Open Source:**
a) MIT - Maximum freedom (most popular, 65% of projects)
b) Apache 2.0 - Like MIT + patent protection (company-friendly)
c) GPL-3.0 - Free Software, copyleft (improvements must be shared)
d) AGPL-3.0 - Like GPL + applies to SaaS/cloud use
e) Other (LGPL, MPL, BSD, Unlicense)

**For Closed Source:**
f) Proprietary/Closed Source

**Not sure?** → Type 'help' for decision guide

Your choice (a/b/c/d/e/f/help):"
```

**If user types 'help'**, provide quick guide:

```
**Quick Guide:**

Choose **MIT (a)** if:
- You want maximum adoption and freedom
- OK with others making closed-source forks
- Building libraries, tools, frameworks
- Most business-friendly

Choose **Apache 2.0 (b)** if:
- Like MIT but want patent protection
- Company-backed project

Choose **GPL-3.0 (c)** if:
- You believe in Free Software philosophy
- Want to prevent proprietary forks
- Building desktop apps, tools

Choose **AGPL-3.0 (d)** if:
- Building web app / SaaS
- Want to prevent "SaaS loophole" (cloud hosting without sharing)

Choose **Proprietary (f)** if:
- Commercial software, no open source
- Want full control

**Most common**: MIT (65%), Apache (13%), GPL (8%)
```

**After user chooses**, create LICENSE file:

1. Download appropriate license text from https://choosealicense.com/
2. Save to `LICENSE` at repo root
3. Update with year and copyright holder (ask user for name/org)
4. Update `STACK.md` with license info (see Step 3)
5. Update `README.md` with license section

**IMPORTANT**: Record license choice for dependency validation:
- **MIT/Apache/BSD**: Can use MIT, Apache, BSD, LGPL deps. CANNOT use GPL!
- **GPL/AGPL**: Can use MIT, Apache, BSD, GPL, LGPL deps. CANNOT use proprietary!
- **Proprietary**: Can use MIT, Apache, BSD deps. CANNOT use GPL/AGPL!

**See**: `.agentic/workflows/project_licensing.md` for comprehensive licensing guide.

### Step 2b: Ask about development style (multi-agent)

Ask the user:

```
"How do you want to work with AI agents?

a) Single agent (default) - One agent handles everything
   Simple, no coordination overhead
   Good for: Most projects, getting started

b) Specialized agents - Different agents for research, testing, coding, review
   More context-efficient, better quality gates
   Requires: Pipeline tracking, handoff protocols
   Good for: Complex features with clear phases

c) Parallel features - Multiple agents on different features simultaneously
   Uses git worktrees for isolation
   Requires: AGENTS_ACTIVE.md coordination
   Good for: Large projects, team development

d) Not sure - Start simple, enable later
   You can always add multi-agent support with:
   bash .agentic/tools/setup-agent.sh pipeline

Type a/b/c/d:"
```

**If (b) Specialized agents chosen:**
1. Pipeline infrastructure already created by scaffold (Core+PM)
2. For Cursor, run: `bash .agentic/tools/setup-agent.sh cursor-agents`
3. Tell user about role definitions: `.agentic/agents/roles/`
4. Explain pipeline workflow: Research → Planning → Test → Implementation → Review → Spec Update → Docs → Git

**If (c) Parallel features chosen:**
1. Pipeline infrastructure already created by scaffold (Core+PM)
2. Explain git worktree workflow (see `.agentic/workflows/multi_agent_coordination.md`)
3. Show how to create worktrees:
   ```bash
   git worktree add ../project-F0042 -b feature/F-0042
   ```

**If (a) or (d) chosen:**
- No additional setup needed
- Multi-agent can be enabled later

## Step 3: Fill in the core documents

### For all profiles:
- **`STACK.md`**: Fill in tech stack, versions, how to run/test
- **`PRODUCT.md`**: What we're building, core capabilities (as checkboxes), technical approach, scope
- **`CONTEXT_PACK.md`**: Architecture overview, key decisions, how it works

### For Core+PM profile additionally:
- **`STATUS.md`**: Current focus, roadmap phases, known issues
- **`spec/PRD.md`**: Why we're building this, goals, requirements
- **`spec/TECH_SPEC.md`**: How we're building it, architecture, data models
- **`spec/FEATURES.md`**: Seed with 2-3 initial features (F-0001, F-0002, etc.)

## Step 4: Set up quality validation

1. **Ask user about their tech stack** (from STACK.md)
2. **Copy appropriate quality profile:**
   - Web/mobile: `.agentic/quality_profiles/web_mobile.sh`
   - Backend: `.agentic/quality_profiles/backend.sh`
   - Desktop: `.agentic/quality_profiles/desktop.sh`
   - CLI/server tools: `.agentic/quality_profiles/cli_server.sh`
   - Audio plugin: `.agentic/quality_profiles/audio_plugin.sh`
   - Game: `.agentic/quality_profiles/game.sh`
   - Generic: `.agentic/quality_profiles/generic.sh`

3. **Copy to project root** as `quality_checks.sh` and customize thresholds
4. **Ask if user wants a pre-commit hook** (recommended)

## Step 4: Update HUMAN_NEEDED.md with discovered blockers

**🚨 CRITICAL: Before ending init, check for blockers**

**Review what was set up and identify anything requiring human action:**

Common blockers discovered during init:
- [ ] **Manual dependency installation** (plugins, tools not installed via package manager)
- [ ] **Credentials needed** (API keys, database passwords, service accounts)
- [ ] **External accounts** (GitHub, cloud services, third-party APIs)
- [ ] **Design decisions pending** (UI framework, payment provider, database choice)
- [ ] **Hardware requirements** (specific devices, testing equipment)
- [ ] **Access permissions** (repo access, production systems, admin rights)

**For each blocker, add to `HUMAN_NEEDED.md`:**

```markdown
### HN-0001: [Short description of what's needed]
- **Type**: dependency | credential | decision | access
- **Added**: YYYY-MM-DD
- **Context**: [What this is for, why it's needed]
- **Why human needed**: [Specific reason - manual install, requires payment, needs approval, etc.]
- **Impact**: Blocking: [what features/work this blocks]
- **Next steps**: [Specific actions human should take]
```

**Example from Godot game init:**
```markdown
### HN-0001: Install GUT testing plugin
- **Type**: dependency
- **Added**: 2025-01-05
- **Context**: Godot game project using GUT for unit testing
- **Why human needed**: GUT plugin must be installed manually via Godot Asset Library
- **Impact**: Blocking: Cannot run tests until installed
- **Next steps**:
  1. Open Godot editor
  2. Go to AssetLib tab
  3. Search for "GUT"
  4. Install and enable plugin
```

**Rule**: If you mention something to the user in chat that requires their action, ADD IT TO HUMAN_NEEDED.md immediately!

## Step 5: Update JOURNAL.md with init session summary

**Before ending the init session, document what was done:**

```markdown
### Session: YYYY-MM-DD HH:MM - Project Initialization

**Accomplished**:
- Initialized [Project Name] with [Stack]
- Profile: [Core | Core+PM]
- Created STACK.md, PRODUCT.md/STATUS.md, CONTEXT_PACK.md
- Set up quality validation: [profile used]
- Documented [X] human-needed items

**Stack configured**:
- Platform: [web/mobile/desktop/game/etc.]
- Framework: [Framework name + version]
- Language: [Language + version]
- Testing: [Test framework + approach]

**Next steps**:
- Human: Review HUMAN_NEEDED.md and resolve blockers
- Human: [Any other immediate actions]
- Agent: [What can be done next after blockers resolved]

**Blockers**: [Reference to HUMAN_NEEDED.md items if any]
```

**Rule**: Always update JOURNAL.md before ending any significant session!

## Process rules (important)
- **Ask before assuming**: if a stack choice is unclear, ask.
- **Prefer constraints over opinions**: versions, platforms, hosting, data, security needs.
- **Make it testable**: ensure `STACK.md` explicitly states the testing approach and test command(s).
- **Keep tokens low**:
  - summarize the codebase rather than re-reading it repeatedly
  - maintain `CONTEXT_PACK.md` so future sessions can start there
- **For existing codebases**: Scan and understand before filling templates

## Updating init outputs over time
Init is not "one and done".
- When stack changes: update `STACK.md` and record an ADR if it's a real decision.
- When architecture changes: update `TECH_SPEC.md` (if Core+PM) or `CONTEXT_PACK.md` (if Core), and/or write an ADR.
- When progress changes: update `STATUS.md` (Core+PM) or `PRODUCT.md` (Core).
- When onboarding cost rises: improve `CONTEXT_PACK.md`.
