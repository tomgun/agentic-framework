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

### Core Profile (Simple Setup)
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

### Core + Product Management Profile
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
- Profile: core  <!-- or core+product -->
```

## Step 2: run init as an agent-guided planning session

Interview the user to understand:

1. **What are we building?** (1-2 sentence summary)
2. **Primary platform?** (web/mobile/desktop/cli/game/audio plugin/etc.)
3. **Tech stack?** (languages, frameworks, runtimes)
4. **Key constraints?** (performance, security, compliance, offline-first, etc.)
5. **Testing approach?** (TDD recommended, what test frameworks?)

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
