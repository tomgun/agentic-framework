# Plan: Systematic Frontmatter Coverage for .agentic/ Files
Feature: F-0144
Date: 2026-03-01

## Context

F-0143 added YAML frontmatter to 79 playbook/subagent files for progressive disclosure (~50x discovery savings). But only 97/212 `.agentic/` markdown files have frontmatter — 115 don't. The coverage is inconsistent: workflows have it, but roles, support docs, token efficiency guides, prompts, and root docs don't. The ROI.md claims "79 files" which is already stale.

**Goal**: Systematic frontmatter on every file that agents might scan for discovery. Skip only files where frontmatter is inappropriate (templates copied to user repos, instruction files parsed by tools, READMEs).

## What gets frontmatter, what doesn't

**YES (~71 files)** — agents benefit from scanning summaries before loading:
- Agent roles (13): `.agentic/agents/roles/*.md` (excluding README)
- Agent shared (4): auto_orchestration.md, agent_operating_guidelines.md, AGENT_QUICK_START.md, doc_types.md
- Root docs (8): DEVELOPER_GUIDE, PRINCIPLES, ROI, START_HERE, FRAMEWORK_MAP, DIRECT_EDITING, EMERGENCY, MANUAL_OPERATIONS
- Token efficiency (5): all files in `.agentic/token_efficiency/`
- Cursor prompts (13): `.agentic/prompts/cursor/*.md` (non-README)
- Claude commands prompt (1): analyze-agents.md
- Init operational (3): init_playbook.md, init_questions.md, memory-seed.md
- Spec operational (2): SPEC_SCHEMA.md, naming_and_lifecycle.md
- Support docs (19): stack profiles (8), design systems (3), docs templates (6), ci (1), environment_research.md
- Misc (3): installation.md, sub-agents.md, workflows/retrospective.md (missed by original script)

**NO (~44 files)** — frontmatter inappropriate or harmful:
- Templates (24): `*.template.md`, `*.reference.md` — copied to user projects by scaffold.sh
- READMEs (14): directory index files — not discovered via scanning
- Instruction files (4): CLAUDE.md, codex-instructions.md, copilot-instructions.md, agents-setup.md — auto-loaded by tools
- State file (1): AGENTS_ACTIVE.md — runtime state tracker
- Archived (1): tools/archived/README.md
- acceptance/README.template.md (1): template file

## Frontmatter schema — keep it simple

Two schemas only. The point is progressive disclosure, not a type system.

**Schema 1: Playbook** (existing, for operational/guidance files)
```yaml
---
summary: "One-line description"
trigger: "comma-separated keywords"
tokens: ~NNNN
phase: session|planning|implementation|commit|completion|reference
---
```

**Schema 2: Minimal** (new, for reference docs / support / prompts)
```yaml
---
summary: "One-line description"
tokens: ~NNNN
---
```

**Schema 3: Prompt** (existing, for claude-commands/cursor prompts)
```yaml
---
command: /command-name
description: "One-line description"
---
```

## Implementation

### Single new script: `.agentic/tools/add-remaining-frontmatter.sh`

Follow the same pattern as `add-frontmatter.sh`:
- Idempotent (skip files with existing frontmatter)
- `--dry-run` flag to preview
- Auto-calculate `tokens:` from `wc -w` (words × 4/3 ≈ tokens)
- Colored output with counts

### Commit batches (stay under 15-file limit)

**Commit 1** (1 file): Create `add-remaining-frontmatter.sh` script

**Commit 2** (~15 files): Run script — agent roles (13) + agent shared (4)

**Commit 3** (~15 files): Run script — root docs (8) + token efficiency (5) + init (3)

**Commit 4** (~15 files): Run script — cursor prompts (13) + spec (2) + analyze-agents (1)

**Commit 5** (~15 files): Run script — support docs (19 files, but 1-line changes each)

**Commit 6** (3 files): Run script — misc stragglers + update ROI.md + validate_framework.sh coverage check

### ROI.md + docs updates
- Update "79 files" → actual count (~168)
- Update "~197,500 tokens" → recalculated for actual file count
- Add frontmatter coverage check to `validate_framework.sh`

## Verification

1. `head -3 .agentic/agents/roles/implementation_agent.md` — has `---` frontmatter
2. `grep -rl "^---" .agentic/ | wc -l` — ~168 files
3. No `.template.md` or `.reference.md` files have frontmatter
4. `bash tests/validate_framework.sh` — passes with new coverage check
5. ROI.md numbers match actual counts
