# Plan: Skills-Primary Architecture for Claude Code

## Context

Anthropic published "The Complete Guide to Building Skills for Claude" — an official spec for packaging instructions as Skills (SKILL.md + scripts/ + references/ + assets/). Our framework has 10 auto-generated skills in `.claude/skills/`, but they're thin stubs that violate multiple spec requirements. A deep gap analysis found **30 issues** vs the Anthropic guide. This plan addresses them.

**Problem**: Dual trigger systems (CLAUDE.md table + skill descriptions), skills missing required fields (`name`), using non-standard fields (`model`), no progressive disclosure, unresolved `{PLACEHOLDER}` syntax, no negative triggers, no examples, no error handling.

**Goal**: Spec-compliant Claude Skills as the primary workflow delivery, backed by structural enforcement. Other tools unchanged.

## Approach

```
Skills (UI layer)     → YAML frontmatter triggers + SKILL.md instructions
Scripts (Runtime)     → Structural enforcement (deterministic gates)
References (Knowledge) → Playbooks with YAML frontmatter for progressive disclosure
```

## Implementation Phases

### Phase 0: YAML frontmatter on all playbook files
Added machine-parseable frontmatter to every file in `.agentic/checklists/`, `.agentic/workflows/`, `.agentic/agents/shared/guidelines/`, `.agentic/quality/`. Enables progressive disclosure — Claude scans summaries (~50 tokens each) instead of loading full files (~2500 each). Script: `add-frontmatter.sh`.

### Phase 1: Hand-craft 12 skill sources
Created `.agentic/agents/claude/skills/` as source of truth with 12 skills:
implementing-features, committing-changes, reviewing-code, session-start, fixing-bugs, completing-work, writing-tests, planning-features, exploring-codebase, researching-topics, updating-documentation, managing-specs.

Each skill has: SKILL.md (frontmatter + instructions + examples + troubleshooting), scripts/ (thin wrappers), and references are assembled by the generator.

### Phase 2: Rewrite generate-skills.sh
Changed from "generate from subagent definitions" to "copy from hand-crafted sources + assemble references." Validates all spec requirements.

### Phase 3: Thin CLAUDE.md template
Reduced from ~54 to ~40 lines. Trigger words table moved to skills. Kept: session start, quick commands, core rules, token-efficient scripts, skills reference.

### Phase 4: Update upgrade.sh migration
Detects old skills by "Generated from: .agentic/agents/claude/subagents" marker AND "author: agentic-framework", removes them, regenerates from new source.

### Phase 5: Header note on auto_orchestration.md
"Claude Code users: Workflow triggers are primarily handled by Skills in `.claude/skills/`. This file serves Cursor, Copilot, Codex, and other non-Claude tools."

### Phase 6: Validation script
Created `tests/validate_skills.sh` checking all 13 spec requirements.

### Phase 7a: Coverage gap fixes
- Added "Quick capture" one-liner to Core Rules in both CLAUDE.md files
- Added post-merge tagging (Step 7) to committing-changes SKILL.md
- Plan-exit durable-save already in planning-features SKILL.md (Step 4)

### Phase 7b: Subagent definition frontmatter
Added YAML frontmatter (role, model_tier, summary, use_when, tokens) to all 27 subagent definition files. Script: `add-subagent-frontmatter.sh`.

### Phase 8: Plan and acceptance criteria
Saved this full plan. Checked off all acceptance criteria.

## 12 Skills Summary

| Skill | Trigger phrases | Negative triggers |
|---|---|---|
| implementing-features | build, implement, add feature, create, ag implement | one-line fixes, test writing, code review, docs-only |
| committing-changes | commit, push, ship, finalize, create PR, ag commit | writing code, running tests, reviewing |
| reviewing-code | review, /review, check this code | implementing, writing tests, committing |
| session-start | first message, start, where were we, ag start | mid-session tasks |
| fixing-bugs | fix, debug, repair, troubleshoot | new features, refactoring |
| completing-work | done, complete, finished, ag done | committing (use committing-changes) |
| writing-tests | write tests, add tests, /test | running existing tests, implementing |
| planning-features | plan, design, ag plan, how should we build | implementing (after plan) |
| exploring-codebase | find, where is, explore, show me | modifying code |
| researching-topics | research, look up, find docs, evaluate | codebase exploration |
| updating-documentation | update docs, write readme, sync docs | code changes |
| managing-specs | update spec, mark shipped, feature status | acceptance criteria |

## What did NOT change
- auto_orchestration.md (serves Cursor/Copilot/Codex)
- Subagent definitions (remain for Task-tool delegation)
- Context manifests
- `ag` commands
- Other tool instruction files
- Structural enforcement scripts
