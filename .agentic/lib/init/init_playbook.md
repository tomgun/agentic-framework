---
summary: "Agent-guided repo initialization: produce durable artifacts in one session"
tokens: ~5404
---

# Repo Init (Agent-Guided) Playbook

Goal: in one short planning session, produce **durable repo artifacts** so any agent can work effectively with minimal repeated context.

## Outputs (authoritative context)
Create/update these at repo root:
- `STACK.md` (from `.agentic/lib/init/STACK.template.md`)
- `.agentic/STATUS.md` (from `.agentic/lib/init/STATUS.template.md`) - required for both profiles
- `CONTEXT_PACK.md` (from `.agentic/lib/init/CONTEXT_PACK.template.md`)
- `.agentic/OVERVIEW.md` (from `.agentic/lib/init/OVERVIEW.template.md`) - product vision and goals
- `/spec/` (from `.agentic/spec/*.template.md`) - for Formal mode
- `.agentic/spec/adr/` (directory exists; can be empty at start)

## Step 0: scaffold files/folders (if not already done)
If `install.sh` was used, templates are already created. Otherwise, run:

```bash
bash .agentic/lib/init/scaffold.sh
```

This creates all expected files/folders with templates/placeholders so you can start development immediately.
If the project has existing code, scaffold will automatically run discovery and generate proposals.

**Git mode (F-0250)**: Git is deferred by default for discovery and formal profiles. The framework works fully without git via Claude hooks + state machine. Autonomous formal defaults to active (git initialized). The user can activate git anytime with `ag git-init`. During init, ask the user about their preference (see Step 1b below).

## Step 0.5: Review Discovery Results (brownfield projects only)

**If `.agentic/session/discovery_report.json` exists**, this is an existing project with auto-discovered data:

1. Read `.agentic/session/discovery_report.json`
2. Present a human-readable summary to the user:
   - **Detected stack**: language, framework, package manager, test framework, E2E framework (if any)
   - **Sub-projects**: detected sub-projects with their frameworks (e.g., frontend/React, functions/Azure Functions, mobile/React Native)
   - **Architecture**: entry points, components, monorepo status
   - **Project description**: extracted from README
   - **Discovered features** (Formal/Autonomous Formal only): modules, routes, packages
3. For each section, ask: "Does this look right? Want to edit anything?"
4. For confirmed sections: the proposal file from `.agentic/session/proposals/` is already copied to the project root
5. For rejected sections: user fills in manually during Step 2 interview
6. For "I don't know" answers: keep the discovery data as-is (it's still a proposal with `<!-- PROPOSAL -->` markers)
7. Skip interview questions in Step 2 for sections the user already confirmed

**Important**: All proposals have `<!-- PROPOSAL -->` markers and `<!-- confidence: high|medium|low -->` annotations.
After review, run `ag approve-onboarding` to strip markers from confirmed files.

**If no discovery report exists**, skip to Step 1 (standard init for new projects).

### Step 0.5b: Feature Discovery Deep Dive (Formal/Autonomous Formal only)

**If the report contains `feature_clusters`**, run this enhanced feature synthesis:

1. **Present feature clusters** to the user as candidate features:
   - Show each cluster with its name, frontend/backend/mobile paths, and confidence level
   - Group by type: user-facing features first, then admin, then infrastructure
   - Example: "I found 15 feature clusters. Here are the top ones:"

2. **For the top 5 clusters** (by total file count across tiers):
   - Read 1-2 key source files to understand what the feature actually does
   - Generate a meaningful feature name (not just the code prefix)
   - Write 3-5 Given/When/Then acceptance criteria based on what the code shows
   - Tag as user-facing / admin / infrastructure

3. **For remaining clusters**:
   - Generate criteria stubs from file paths only (no source reading)
   - Use the visible TODO directive in acceptance criteria files

4. **Ask the user about key workflows**:
   > "Code analysis found these features, but it can't infer business processes.
   > What are the main things a user does in this app? (e.g., 'sign up, browse products, checkout')
   > This helps me understand which features matter most."

5. **Ask user to confirm, merge, or split features**:
   > "Here are the discovered features. Would you like to:
   > - Confirm all as-is
   > - Merge any (e.g., 'User Settings' and 'Preferences' are the same feature)
   > - Split any (e.g., 'Admin' should be 'Admin Users' + 'Admin Settings')
   > - Remove any (e.g., infrastructure that shouldn't be tracked as a feature)"

6. **Write final output**:
   - Update FEATURES.md with confirmed/merged features using **heading format** (NOT table):
     ```markdown
     <!-- format: features-v2.0.0 -->
     <!-- REQUIRED: heading format. Tables break backlog, state machine, and crunch parsing. -->

     ## F-001: Feature Name
     **Status**: planned
     **Category**: domain-name
     **Priority**: medium
     **Complexity**: medium
     **Description**: ...
     **Acceptance**: See `spec/acceptance/F-001.md`
     ```
     Or use `bash .agentic/lib/tools/feature.sh F-XXXX add "Feature Name" domain` to add programmatically.
   - Write .agentic/spec/acceptance/F-####.md files with criteria
   - Features with user-confirmed criteria get `Accepted: yes`

### Step 0.5c: Size-Aware Routing (Formal/Autonomous Formal only)

After reviewing discovery results, evaluate whether the project is small or large:

**Spec generation approach** (based on discovery results):
- **Small**: 1 domain AND ≤ 8 clusters → continue with quick inline spec generation (current Steps 0.5a/0.5b above)
- **Large**: > 1 domain OR > 8 clusters → suggest `ag specs` for systematic domain-by-domain approach

Examples:
- 1 domain + 5 clusters = **small** (inline)
- 2 domains + 3 clusters = **large** (ag specs)
- 1 domain + 12 clusters = **large** (ag specs)

If large, tell the user:
> "This project has multiple domains (or many feature clusters). I recommend using `ag specs` for
> systematic domain-by-domain spec generation. This lets us work through each domain methodically,
> potentially over multiple sessions. Run `ag specs` to start."

**Token cost** (evaluated after features exist):
- > 50 features in FEATURES.md → suggest `organize_features.py --by domain` for hierarchical splitting

## Step 1: Choose profile (Discovery vs Formal vs Autonomous Formal)

**Ask the user which profile they want:**

> "Which profile would you like to use?
>
> **a) Discovery (Full Framework, Lightweight Planning)**
> - All framework capabilities: context optimization, multi-agent, TDD, quality gates
> - Session continuity, token efficiency, green coding, /verify command
> - STATUS.md for project phase and current focus
> - Optional OVERVIEW.md for detailed vision
> - Good for: Small projects, prototypes, external PM tools (Jira/Linear)
>
> **b) Formal (Formal Specs)**
> - Everything in Discovery, PLUS formal specifications
> - Feature tracking with F-#### IDs (.agentic/spec/FEATURES.md)
> - Acceptance criteria per feature (.agentic/spec/acceptance/)
> - STATUS.md, NFR.md, ADRs, cross-reference validation
> - Good for: Long-term projects (3+ months), complex products, audit trails
>
> **c) Autonomous Formal (Agent-Driven Reviews)**
> - Same rigor as Formal, but most review checkpoints delegated to `critical_agent`
> - Only `review_merge` (final merge) stays human
> - `critical_agent` spawns adversarial AI reviewer for automated review
> - Good for: Autonomous agent workflows, CI/CD pipelines, batch processing
>
> Type 'a' for Discovery, 'b' for Formal, or 'c' for Autonomous Formal"

### Discovery Profile (a)
**Full framework capabilities with lightweight planning:**
- ✅ Context optimization (CONTEXT_PACK.md)
- ✅ Session continuity (JOURNAL.md)
- ✅ Quality standards (programming, testing, TDD)
- ✅ Multi-agent coordination
- ✅ Token efficiency guidelines
- ✅ Green coding principles
- ✅ Quality gates (doctor.sh with --full, --phase, --pre-commit)
- ✅ Human escalation (HUMAN_NEEDED.md)
- ✅ Research mode
- ✅ `/verify` command for human-assisted quality
- ✅ `.agentic/STATUS.md` for project phase and current focus
- ✅ `.agentic/OVERVIEW.md` for product vision and goals
- ✅ Minimal ceremony, fast iteration
- **Good for**:
  - Small/simple projects or prototypes
  - Projects with external PM tools (Jira, Linear, etc.)
  - Solo developers who don't need formal tracking
  - Quick experiments and MVPs

### Formal Profile (b)
- ✅ Everything in Discovery, plus:
- ✅ Formal specifications (`spec/PRD.md`, `TECH_SPEC.md`)
- ✅ Feature tracking with F-#### IDs
- ✅ `.agentic/STATUS.md` for roadmap and metrics
- ✅ Acceptance criteria per feature
- ✅ Sequential pipeline (specialized agents)
- **Good for**:
  - Long-term projects (3+ months of development)
  - Human-machine teams collaborating on product
  - Complex products requiring traceability
  - Projects needing audit trails and formal specs

### Autonomous Formal Profile (c)
- ✅ Everything in Formal, with review delegation:
- ✅ `review_code` and `review_regression` → `critical_agent` (instead of human)
- ✅ Only `review_merge` stays human (final merge always needs human approval)
- ✅ `critical_agent` spawns adversarial AI reviewer for automated review (F-0182)
- **Good for**:
  - Autonomous agent workflows (ag auto task, ag auto crunch)
  - CI/CD pipelines with minimal human intervention
  - Batch feature processing

**Update `STACK.md`** with the chosen profile:
```markdown
- Profile: discovery          <!-- if user chose 'a' -->
- Profile: formal             <!-- if user chose 'b' -->
- Profile: autonomous_formal  <!-- if user chose 'c' -->
```

### Step 1b: Git Configuration (F-0250)

After profile selection, **always ask the user about git** — even for Autonomous Formal. Scaffold defers git initialization to this step so the user confirms before `git init` runs.

> "Would you like to set up git version control now?
>
> **a) Yes** — Initialize git repository immediately. Required for: branches, PRs, `ag commit`, `ag auto task/epic`.
> **b) Later** — Start without git. The framework works fully via Claude hooks and the state machine. Activate anytime with `ag git-init`.
>
> Default: `Yes` for Autonomous Formal, `Later` for Discovery and Formal."

**Note**: If `.git/` already exists (e.g., cloned repo), skip this question and set `git_mode: active`.

Based on the answer, update `STACK.md`:
```markdown
- git_mode: active     <!-- if user chose 'a' (Yes) -->
- git_mode: deferred   <!-- if user chose 'b' (Later) -->
```

If the user chose `active`, ensure git is initialized:
```bash
git init  # if .git/ does not already exist
git config core.hooksPath .agentic/hooks
```

If the user chose `deferred`, print:
> "Git deferred. The framework works without git — Claude hooks enforce your workflow.
> Run `ag git-init` anytime to enable version control, branches, and PRs."

### Step 1 (cont.): Greenfield Domain Question (Formal only, new projects)

**Skip this for brownfield projects** (discovery handles domains automatically).

For **new/greenfield Formal projects**, ask:

> "Does your project have distinct domains? Examples:
> - Frontend web app + Backend API
> - Mobile app + Backend + Admin dashboard
> - Monorepo with multiple packages
>
> If yes, list the domain names. If no, we'll use a single domain."

**If yes**: Record domain names. When creating initial feature stubs in Step 3 (FEATURES.md),
add `- Domain: {type}` metadata to each feature. Map user-provided names to types:
- frontend, web, ui → `frontend`
- backend, api, server → `backend`
- mobile, app → `mobile`
- infra, infrastructure, devops → `infrastructure`
- other → `shared`

**If no**: Skip. Single implicit domain, no `- Domain:` tag needed.

## Step 1a: Verify AI tool setup

The scaffold pre-installed configuration files for all supported AI tools.
Now verify which tools the user actually uses and offer to clean up the rest.

**Use AskUserQuestion** to ask which tools the user uses (multi-select):

```json
{
  "questions": [{
    "question": "Which AI coding tool(s) do you use? (scaffold pre-installed all — we'll clean up unused ones)",
    "header": "AI Tools",
    "multiSelect": true,
    "options": [
      {"label": "Claude Code", "description": "CLAUDE.md + hooks + skills (already active)"},
      {"label": "Cursor", "description": ".cursorrules (already installed)"},
      {"label": "GitHub Copilot", "description": ".github/copilot-instructions.md (already installed)"},
      {"label": "Codex CLI", "description": ".codex/instructions.md (already installed)"}
    ]
  }]
}
```

**For selected tools**: Verify files are present. If missing (manual setup without scaffold), run:
```bash
bash .agentic/lib/tools/setup-agent.sh <tool>
```

**For tools NOT selected** (optional cleanup):
```bash
# Only remove if user confirms — these are harmless to keep
# Example: user only uses Claude, offer to remove cursor/copilot/codex
rm -f .cursorrules                        # Cursor
rm -f .github/copilot-instructions.md     # Copilot
rm -rf .codex/                            # Codex
```
If user declines cleanup or isn't sure, skip — all configs are harmless to keep.

### If Claude Code selected:
```bash
# Verify Claude setup (scaffold already installed these)
if [[ -f .claude/hooks.json ]]; then
  echo "✓ Claude Code hooks: active (installed by scaffold)"
else
  bash .agentic/lib/tools/setup-agent.sh claude
fi
echo "  - CLAUDE.md installed (instructions)"
echo "  - Hooks active (enforcement + automatic checkpoints)"
echo "  - Skills available (.claude/skills/)"
```

**Seed persistent memory**: Read `.agentic/lib/init/memory-seed.md` and write its key patterns to Claude's persistent memory (`~/.claude/projects/*/memory/MEMORY.md`). This ensures workflow patterns survive across sessions even when CLAUDE.md gets compressed.

### If Cursor (b):
```bash
# Modern Cursor (0.42+)
mkdir -p .cursor/rules
cp .agentic/lib/agents/cursor/agentic-framework.mdc .cursor/rules/

# Fallback for older Cursor
cp .agentic/lib/agents/cursor/cursorrules.txt .cursorrules

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
cp .agentic/lib/agents/copilot/copilot-instructions.md .github/

echo "✓ Copilot optimized:"
echo "  - .github/copilot-instructions.md installed (ULTRA-CONCISE for 8K limit)"
echo "  - Token-efficient scripts CRITICAL (context very limited)"
echo "  - Work file-by-file (no multi-file operations)"
echo "  - User must apply suggestions (Copilot can't edit directly)"
```

### If Codex CLI (d):
```bash
# Codex instructions
bash .agentic/lib/tools/setup-agent.sh codex

echo "✓ Codex CLI optimized:"
echo "  - .codex/instructions.md installed"
echo "  - Auto-loaded by Codex CLI on every run"
```

**Optional — seed user-level memory**: Codex supports `~/.codex/AGENTS.md` for cross-project behavioral patterns. Ask the user before writing to user-level files (they affect all projects). If they agree, append the key patterns from `.agentic/lib/init/memory-seed.md`.

### If Windsurf (e):
```bash
# Windsurf rules
bash .agentic/lib/tools/setup-agent.sh windsurf  # if supported, else:
cp .agentic/lib/agents/shared/agent_operating_guidelines.md .windsurfrules

echo "✓ Windsurf optimized:"
echo "  - .windsurfrules installed (project-level instructions)"
```

**Optional — seed global memory**: Windsurf supports `~/.codeium/windsurf/memories/global_rules.md` for cross-project patterns. Ask the user before writing to user-level files. If they agree, append the key patterns from `.agentic/lib/init/memory-seed.md`.

### If Multiple (a) - RECOMMENDED:
```bash
# Install all tool adapters for seamless environment switching
bash .agentic/lib/tools/setup-agent.sh all

# Enable Claude hooks for automatic checkpoints (optional but recommended)
mkdir -p .claude && cp .agentic/lib/claude-hooks/hooks.json .claude/

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
   # Claude SessionStart hook checks STATUS.md
   # Sees current focus and progress
   # Continues seamlessly
   ```

**Update STACK.md** with environment info:
```markdown
## Agentic framework
- Version: [version]
- Profile: [discovery | formal]
- AI Environments: [multi | claude | cursor | copilot]  # NEW! "multi" = can use all
```

**Note**: "multi" means all environment adapters are installed. You can switch freely:
- Out of Claude tokens? → Open project in Cursor
- Out of Cursor tokens? → Use Copilot in VS Code
- Back home? → Continue with Claude Code
- All tools see same project state (JOURNAL, FEATURES, etc.)

**Environment-specific tips:**

**Claude Code users:**
- Hooks run automatically (PreToolUse, SessionStart, UserPromptSubmit, PostToolUse, PreCompact, Stop)
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

## Step 1c: Git Workflow Preference (Discovery profile only, when git active)

**SKIP this step if `git_mode: deferred`** — the git workflow question is deferred until `ag git-init` is run.
**SKIP this step for Formal/Autonomous Formal profiles** - both default to `pull_request` (formal tracking implies formal review).

**For Discovery profile, ask the user:**

> "How do you prefer to work with Git?
>
> **a) Direct commits** (default for Discovery - fast iteration)
> - Commit directly to main/master
> - No PR overhead
> - Good for: solo projects, prototypes, speed
>
> **b) Pull Request workflow** (adds review step)
> - Create feature branches
> - Review changes before merging
> - Good for: safety net, audit trail, collaboration
>
> Type 'a' for direct or 'b' for pull_request"

**After user chooses, update STACK.md:**

```markdown
## Git workflow
- git_workflow: direct    <!-- if user chose 'a' -->
- git_workflow: pull_request  <!-- if user chose 'b' -->
```

**Important notes:**
- The pre-commit hook will **BLOCK** commits to main/master when `git_workflow: pull_request` is set
- Users can always bypass with `git commit --no-verify` for hotfixes
- This is about **user choice**, not enforcement - both workflows are valid

## Step 2: run init as an agent-guided planning session

Use **AskUserQuestion** in 2 calls. Call 2 is **dynamic** — adapt options based on Call 1 answers.

**Call 1 — Project identity** (4 questions, user will often pick "Other" for free-text):
```json
{
  "questions": [
    {
      "question": "What are we building?",
      "header": "Project",
      "multiSelect": false,
      "options": [
        {"label": "Web app", "description": "Browser-based application"},
        {"label": "Mobile app", "description": "iOS/Android native or hybrid"},
        {"label": "CLI tool", "description": "Command-line utility"},
        {"label": "Game", "description": "Interactive game or simulation"}
      ]
    },
    {
      "question": "Primary platform?",
      "header": "Platform",
      "multiSelect": false,
      "options": [
        {"label": "Web", "description": "Browser-based"},
        {"label": "Mobile", "description": "iOS/Android"},
        {"label": "Desktop", "description": "Electron, Tauri, native"},
        {"label": "CLI", "description": "Terminal application"}
      ]
    },
    {
      "question": "What's the tech stack?",
      "header": "Stack",
      "multiSelect": false,
      "options": [
        {"label": "TypeScript + Node", "description": "JS ecosystem"},
        {"label": "Python", "description": "Django, FastAPI, Flask, etc."},
        {"label": "Rust", "description": "Systems programming"},
        {"label": "Go", "description": "Cloud-native, microservices"}
      ]
    },
    {
      "question": "Project license?",
      "header": "License",
      "multiSelect": false,
      "options": [
        {"label": "MIT (Recommended)", "description": "Maximum freedom, most popular"},
        {"label": "Apache 2.0", "description": "Like MIT + patent protection"},
        {"label": "GPL-3.0", "description": "Copyleft — improvements must be shared"},
        {"label": "Proprietary", "description": "All rights reserved"}
      ]
    }
  ]
}
```

**Call 2 — Constraints & testing** (DYNAMIC — build based on Call 1 answers):

Adapt the testing and E2E options to the stack/platform from Call 1:

| Call 1 stack | Testing options | E2E options |
|---|---|---|
| TypeScript/Node | jest, vitest, mocha | Playwright, Cypress |
| Python | pytest, unittest | Playwright, Selenium |
| Rust | cargo test | skip (no UI) |
| Go | go test | skip (no UI) |
| Game (any stack) | framework-specific (e.g. Phaser test utils) | visual regression |

**Only include E2E question if the platform has a UI** (web, mobile, game, desktop). Skip for CLI/API-only projects.

Example for a TypeScript web app:
```json
{
  "questions": [
    {
      "question": "Key project constraints?",
      "header": "Constraints",
      "multiSelect": true,
      "options": [
        {"label": "Performance", "description": "Low latency, high throughput"},
        {"label": "Security", "description": "Auth, encryption, OWASP"},
        {"label": "Compliance", "description": "GDPR, HIPAA, SOC2"},
        {"label": "Offline-first", "description": "Works without network"}
      ]
    },
    {
      "question": "Testing framework?",
      "header": "Testing",
      "multiSelect": false,
      "options": [
        {"label": "vitest (Recommended)", "description": "Fast, Vite-native, ESM-first"},
        {"label": "jest", "description": "Mature, large ecosystem"},
        {"label": "mocha + chai", "description": "Flexible, configurable"}
      ]
    },
    {
      "question": "E2E testing?",
      "header": "E2E",
      "multiSelect": false,
      "options": [
        {"label": "Playwright (Recommended)", "description": "Cross-browser, best DX"},
        {"label": "Cypress", "description": "Mature, large community"},
        {"label": "None", "description": "Skip E2E for now"}
      ]
    }
  ]
}
```

Example for a Python CLI tool (no E2E question):
```json
{
  "questions": [
    {
      "question": "Key project constraints?",
      "header": "Constraints",
      "multiSelect": true,
      "options": [
        {"label": "Performance", "description": "Low latency, high throughput"},
        {"label": "Security", "description": "Auth, encryption, OWASP"},
        {"label": "Compliance", "description": "GDPR, HIPAA, SOC2"},
        {"label": "Offline-first", "description": "Works without network"}
      ]
    },
    {
      "question": "Testing framework?",
      "header": "Testing",
      "multiSelect": false,
      "options": [
        {"label": "pytest (Recommended)", "description": "De facto Python standard"},
        {"label": "unittest", "description": "Built-in, no dependencies"},
        {"label": "hypothesis", "description": "Property-based testing"}
      ]
    }
  ]
}
```

After collecting answers, proceed with the detailed steps below:
- **License**: See Step 2a
- **Quality constraints / NFRs**: See Step 2c

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

**See**: `.agentic/lib/workflows/project_licensing.md` for comprehensive licensing guide.

### Step 2c: NFR Discovery (quality constraints)

**After the interview questions**, use the answers to suggest relevant NFRs.

1. **Run NFR generation**: `bash .agentic/lib/tools/nfr-generate.sh --limit 8` (auto-detects project type from STACK.md `Primary platform:`, outputs top 4-8 P1/P2 recommendations filtered by priority tier)
   - Override detection: `--project-type web` or `--project-type api`
   - Include structural: `--all` (adds P3 entries)
   - Custom limit: `--limit N` (default: shows all; `ag nfr discover` uses `--limit 8`)
   - Machine output: `--machine` (pipe-delimited, for piping to `nfr-write-batch.sh`)
   - Supported types: web, api, mobile, game, audio, cli, desktop, library, data-pipeline

4. **Formalize any constraints from question 4** ("Key constraints?"):
   - If the user mentioned performance/security/compliance constraints earlier, map them to catalog entries or create custom NFRs

5. **Ask the developer to pick and customize**:

```
"Based on your stack, here are suggested quality constraints (NFRs).
Pick the ones that matter and adjust thresholds:

Performance:
  [ ] Response time p95 < 200ms (default: 200ms, adjust?)
  [ ] Bundle size < 250KB (default: 250KB, adjust?)

Security:
  [ ] XSS protection on user inputs
  [ ] CSRF protection on state-changing endpoints

Process:
  [ ] Small batch commits (max 10 files)
  [ ] Spec-first development

Which do you want? (e.g., 'all', '1,3,5', or 'none for now')"
```

6. **Write selected NFRs** using the batch writer:
   - All: `bash nfr-generate.sh --machine --limit 8 | bash nfr-write-batch.sh`
   - Selective: filter machine output to desired entries, then pipe to batch writer
   - The batch writer auto-assigns collision-free NFR-XXXX IDs and appends to `.agentic/spec/NFR.md`
   - Create acceptance files for each: `.agentic/spec/acceptance/NFR-XXXX.md`

7. **Profile behavior**:
   - **Formal** (required): NFRs link to acceptance criteria, formally tracked in specs
   - **Discovery** (optional but recommended): NFRs serve as quality guidelines without formal linking. Captured early so they're ready when/if transitioning to Formal.

**If user says "none for now"**: That's fine. NFRs can be added anytime via `ag nfr discover`.

### Step 2d: Retrospective cadence (Formal profile only)

If Formal profile, ask:

```
"How often should we do quality retrospectives?

a) After every 10 features shipped (default)
b) Every 2 weeks of active development
c) Both time and feature triggers
d) Manual only — I'll say when
e) Disable retrospectives

Retros review spec quality, test coverage, NFR health, and process improvements."
```

Write choice to STACK.md Settings:
- `retrospective_enabled: yes|no`
- `retrospective_trigger: time|features|both` (if enabled)
- `retrospective_interval_days: 14` (if time-based)
- `retrospective_interval_features: 10` (if feature-based)

**Discovery profile**: Skip — retros are disabled by default. Can be enabled later via `ag set retrospective_enabled yes`.

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
   Requires: AGENTS.json coordination
   Good for: Large projects, team development

d) Not sure - Start simple, enable later
   You can always add multi-agent support with:
   bash .agentic/lib/tools/setup-agent.sh pipeline

Type a/b/c/d:"
```

**If (b) Specialized agents chosen:**
1. Pipeline infrastructure already created by scaffold (Formal)
2. For Cursor, run: `bash .agentic/lib/tools/setup-agent.sh cursor-agents`
3. Tell user about role definitions: `.agentic/lib/agents/roles/`
4. Explain pipeline workflow: Research → Planning → Test → Implementation → Review → Spec Update → Docs → Git

**If (c) Parallel features chosen:**
1. Pipeline infrastructure already created by scaffold (Formal)
2. Explain git worktree workflow (see `.agentic/lib/workflows/multi_agent_coordination.md`)
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
- **`.agentic/STATUS.md`**: Project phase, current focus, what's next
- **`CONTEXT_PACK.md`**: Architecture overview, key decisions, how it works
- **`.agentic/OVERVIEW.md`**: Product vision, why it matters, core capabilities, success criteria

### For Formal profile additionally:
- **`spec/TECH_SPEC.md`**: How we're building it, architecture, data models
- **`.agentic/spec/FEATURES.md`**: Seed with 2-3 initial features (F-001, F-0002, etc.)

## Step 4: Set up quality validation

1. **Ask user about their tech stack** (from STACK.md)
2. **Copy appropriate quality profile:**
   - Web app with E2E: `.agentic/lib/quality_profiles/webapp_with_e2e.sh` (if Playwright/Cypress detected or configured)
   - Web/mobile: `.agentic/quality_profiles/web_mobile.sh`
   - Backend: `.agentic/quality_profiles/backend.sh`
   - Desktop: `.agentic/quality_profiles/desktop.sh`
   - CLI/server tools: `.agentic/quality_profiles/cli_server.sh`
   - Audio plugin: `.agentic/quality_profiles/audio_plugin.sh`
   - Game: `.agentic/quality_profiles/game.sh`
   - Generic: `.agentic/quality_profiles/generic.sh`
   - See also: `.agentic/lib/quality/e2e_testing_contract.md` for E2E integration contract

3. **Copy to project root** as `quality_checks.sh` and customize thresholds
4. **Pre-commit hook** — verify installation, then configure mode:
   ```bash
   # Verify git hooks are installed (scaffold should have done this)
   actual=$(git config core.hooksPath 2>/dev/null || echo "")
   if [ "$actual" != ".agentic/hooks" ]; then
     echo "WARNING: git hooks not installed — installing now"
     git config core.hooksPath .agentic/hooks
   fi
   echo "core.hooksPath = $(git config core.hooksPath)"
   ```
   - Default mode is `fast` (structural checks only, skips slow tests)
   - Ask user if they want `full` mode (runs tests on every commit) or `no` (disable)
   - Update `pre_commit_hook:` in STACK.md accordingly
   - Check with `ag hooks status`, manage with `ag hooks install|disable`

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

**For each blocker, add to `.agentic/HUMAN_NEEDED.md`:**

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

**What changed**:
- Initialized [Project Name] with [Stack]
- Profile: [Discovery | Formal]
- Created STACK.md, STATUS.md, OVERVIEW.md (optional), CONTEXT_PACK.md
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
- When architecture changes: update `TECH_SPEC.md` (if Formal) or `CONTEXT_PACK.md` (if Discovery), and/or write an ADR.
- When progress changes: update `.agentic/STATUS.md`.
- When onboarding cost rises: improve `CONTEXT_PACK.md`.
