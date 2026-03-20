# Migration Guide: v1 to v2

## What Changed

The v2 workflow engine replaces instruction-file-based workflows with CLI-enforced state machine transitions.

### Removed (~130 files)
- `.agentic/lib/workflows/` (35 workflow docs)
- `.agentic/lib/checklists/` (10 checklists)
- `.agentic/lib/quality/` (9 quality standards — consolidated into `.agentic/conventions.md`)
- `.agentic/lib/agents/shared/` guidelines, auto_orchestration, agent_operating_guidelines
- `.agentic/lib/agents/claude/subagents/` (35 subagent definitions — replaced by 7 role prompts)
- Skill `references/` directories and helper scripts

### Added
- `.agentic/prompts/` — 7 role prompts loaded JIT by CLI transitions
- `.agentic/conventions.md` — project-configurable coding conventions
- `.agentic/work/` — per-feature work item directories
- v2 workflow engine (`.agentic/lib/auto/v2/`)

### Simplified
- Skills reduced to trigger-word stubs pointing to `ag` commands
- Tool templates (CLAUDE.md, cursorrules, copilot, codex) point to v2 workflow
- `memory-seed.md` reduced to 18 lines

## How to Upgrade

1. Set `engine: v2` in `.agentic/state_machine_af.yaml`
2. Run `bash .agentic/lib/tools/upgrade.sh` to clean up removed directories
3. Skills will route to `ag` commands automatically
4. Work items are created in `.agentic/work/F-XXXX/` instead of scattered locations

## v2 Workflow Commands

- `ag start F-XXXX "Title"` — begin a new feature
- `ag transition F-XXXX <state>` — advance the workflow
- `ag check F-XXXX` — validate artifacts
- `ag verify F-XXXX` — run tests
- `ag ship F-XXXX` — prepare for shipping
- `ag status` / `ag info` / `ag next` — view state

## Rollback

To revert to v1, set `engine: v1` in `state_machine_af.yaml` and re-run `upgrade.sh`.
The backup created during upgrade contains your original `.agentic/` directory.
