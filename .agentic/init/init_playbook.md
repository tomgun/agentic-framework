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
