# `agentic/`: Agentic Development Framework (Portable)

This folder is a **portable framework** you can copy into any repository to bootstrap **high-quality, test-driven, token-efficient** agentic development in **Cursor 2.2+** (and optionally alongside GitHub Copilot / Claude).

## What you get
- **A repo init protocol** (agent-guided) that creates stable context artifacts: `STACK.md`, `CONTEXT_PACK.md`, `STATUS.md`, `/spec/`, `/adr/`.
- **Technology-agnostic spec templates**: PRD, Tech Spec, Task, ADR, Status.
- **Quality playbooks**: Definition of Done, test strategy, design-for-testability, review checklist.
- **Token-efficiency playbooks**: context budgeting, change slicing, durable context packs.
- **Multi-agent compatibility**: a shared “agent operating contract” + thin entrypoints for Cursor/Copilot/Claude.
- **Optional lightweight enforcement**: PR checklist + a minimal GitHub Actions template to validate docs/spec conventions.

## Quick start (new repo)
1. Copy the **folder** `agentic/` into your repo root (don’t copy its contents into the root; keep the folder so links stay consistent).
2. Scaffold required files/folders:

```bash
bash agentic/init/scaffold.sh
```

3. Start your agent and point it to `agentic/init/init_playbook.md`.
4. If the topic is non-trivial, do a short research pass first, then write/upgrade `/spec/PRD.md` and `/spec/TECH_SPEC.md`.
5. Start development using `agentic/workflows/dev_loop.md` (small tasks, tests, updates to `STATUS.md`).
6. If you’re using multiple assistants (Cursor + Copilot + Claude), install entrypoints from `agentic/agents/installation.md`.

## Quick resume (after a break)
From repo root:

```bash
bash agentic/tools/brief.sh
```

## Reports (no LLM required)
From repo root:

```bash
bash agentic/tools/report.sh
```

## Where to read / edit “project truth”
- Vision + current state + architecture pointers: `spec/OVERVIEW.md`
- Current execution state: `STATUS.md`
- Requirements: `spec/PRD.md`
- Architecture + testing strategy: `spec/TECH_SPEC.md`
- Feature/requirement registry (IDs + status + acceptance + test notes): `spec/FEATURES.md`
- Acceptance criteria per feature: `spec/acceptance/F-####.md`
- Lessons learned / caveats: `spec/LESSONS.md` and `/adr/*`

## Minimal repo files this framework expects (created during init)
- `STACK.md`: tech stack + constraints (source of truth for “how to build here”).  
- `CONTEXT_PACK.md`: short durable context for agents (what matters, where to look).  
- `STATUS.md`: current progress, next steps, known issues, roadmap.  
- `/spec/`: PRD + Tech Spec(s) + tasks (living docs).  
- `/adr/`: Architecture Decision Records (only for real decisions).  

## Design principles (first principles)
See `agentic/principles/first_principles.md` for the “why”. The short version:
- **Feedback loops** beat cleverness: tests and small diffs reduce risk.
- **Entropy is real**: decisions must be recorded, status must be current.
- **Context is expensive**: durable artifacts reduce repeated token spend.
- **Agents need a contract**: consistent behavior across tools avoids thrash.

## Adoption notes
- This framework is intentionally **tech-agnostic**. Where stack specifics matter, use:
  - `STACK.md` (repo’s truth)
  - `agentic/support/stack_profiles/*` (guidance profiles to speed up init)
- The optional CI template is **opt-in**. It validates *presence/format* of the docs artifacts only.
  - To enable it, copy `agentic/support/ci/github_actions.template.yml` to `.github/workflows/agentic-spec-lint.yml`.


