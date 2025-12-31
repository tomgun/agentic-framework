# Repo Init (Agent-Guided) Playbook

Goal: in one short planning session, produce **durable repo artifacts** so any agent can work effectively with minimal repeated context.

## Outputs (authoritative context)
Create/update these at repo root:
- `STACK.md` (from `agentic/init/STACK.template.md`)
- `CONTEXT_PACK.md` (from `agentic/init/CONTEXT_PACK.template.md`)
- `STATUS.md` (from `agentic/init/STATUS.template.md`)
- `/spec/` (seed with at least `PRD.md` and `TECH_SPEC.md`)
- `spec/adr/` (directory exists; can be empty at start)

## Step 0: scaffold files/folders (recommended)
Run (from repo root):

```bash
bash agentic/init/scaffold.sh
```

This creates all expected files/folders with templates/placeholders so you can start development immediately.

## Step 1: run init as an agent-guided planning session (recommended prompt)
Open a fresh agent session and paste:

1. “We are initializing this repo using the `agentic/` framework.”
2. “Follow `agentic/init/init_questions.md`.”
3. “Start by planning at the product/system level: choose the app type (webapp/game/vstplugin/mobileapp/app+backend) and write the initial PRD/Tech Spec outline.”
4. “Then finalize the stack details and fill `STACK.md`.”
5. “Use a stack profile if present (default: `agentic/support/stack_profiles/generic_default.md`).”
6. “Your job is to write/update: `STACK.md`, `CONTEXT_PACK.md`, `STATUS.md`, and seed `/spec/` + `spec/adr/`.”
7. “Keep everything short; prefer bullet points; avoid deep implementation detail.”

## Process rules (important)
- **Ask before assuming**: if a stack choice is unclear, ask.
- **Prefer constraints over opinions**: versions, platforms, hosting, data, security needs.
- **Make it testable**: ensure `STACK.md` explicitly states the testing approach and test command(s) once known.
- **Keep tokens low**:
  - summarize the codebase rather than re-reading it repeatedly
  - maintain `CONTEXT_PACK.md` so future sessions can start there

## Updating init outputs over time
Init is not “one and done”.
- When stack changes: update `STACK.md` and record an ADR if it’s a real decision.
- When architecture changes: update `TECH_SPEC.md` and/or write an ADR.
- When progress changes: update `STATUS.md` (always).
- When onboarding cost rises: improve `CONTEXT_PACK.md`.


