# Plan: Organize Auto-Memory + Enforce Agent-Agnostic Principle

## Context

During the session dashboard PR, I placed `dashboard.sh` exclusively in `.claude/skills/`. The user corrected: "nothing in this framework is Claude-only." This exposed two problems:

1. **The practical rule is missing from canonical files**: PRINCIPLES.md has D7 (Multi-Environment Portability) as design philosophy, but the practical consequence — "scripts/tools go in `.agentic/`, not exclusively in `.claude/`" — isn't stated where framework developers actually read it: `FRAMEWORK_DEVELOPMENT.md`.

2. **Auto-memory files need cleanup**: My `patterns.md` has no header explaining what it is, contains a premature lesson about the dashboard, and the agent-agnostic entry restates the rule instead of pointing to the canonical source. `MEMORY.md` references patterns.md with bare "See `patterns.md`" without explaining its role.

## Changes

### Part 1: Move dashboard.sh to `.agentic/` (apply the principle)

| # | File | Change |
|---|------|--------|
| 1 | `.agentic/lib/tools/dashboard.sh` | **NEW** — move current `.claude/skills/session-start/scripts/dashboard.sh` here |
| 2 | `.claude/skills/session-start/scripts/dashboard.sh` | **DELETE** |
| 3 | `.claude/skills/session-start/SKILL.md` | Update path to `bash .agentic/lib/tools/dashboard.sh` |
| 4 | `.claude/skills/session-start/scripts/quick-scan.sh` | Update delegation path to `.agentic/lib/tools/dashboard.sh` |

### Part 2: Add practical rule to FRAMEWORK_DEVELOPMENT.md

| # | File | Change |
|---|------|--------|
| 5 | `FRAMEWORK_DEVELOPMENT.md` | Add to "Canonical Source" section (near the dogfooding rule): practical rule that tools/scripts belong in `.agentic/`, `.claude/skills/` reference them but don't originate logic |

This is the ONE canonical place. Not memory-seed (that's for end-users, "reinforces not originates"). Not the CLAUDE.md template (that's for users of the framework). FRAMEWORK_DEVELOPMENT.md is the framework developer's guide.

### Part 3: Clean up auto-memory files

| # | File | Change |
|---|------|--------|
| 6 | `memory/MEMORY.md` | Fix references to patterns.md — explain its role ("detailed lessons learned and design case studies"). Clean agent-agnostic rule to point at FRAMEWORK_DEVELOPMENT.md + PRINCIPLES.md D7 instead of restating the full rule inline. |
| 7 | `memory/patterns.md` | Add header explaining purpose. Update agent-agnostic entry to reference canonical source. Remove premature dashboard lesson (it was written before the fix). Mark "JOURNAL.md and plans" pending item as done (it is). |

## Implementation Details

### FRAMEWORK_DEVELOPMENT.md addition (Part 2)
Insert after the dogfooding rule / anti-pattern block (around line 118), before "Memory Seed Maintenance":

```markdown
#### Agent-Agnostic by Default

The framework supports Claude, Cursor, Copilot, Codex equally. **Practical consequence for framework developers:**

- Scripts and tools go in `.agentic/lib/tools/`, NOT in `.claude/skills/*/scripts/`
- `.claude/skills/` are a "works even better in Claude Code" enhancement layer — they reference `.agentic/` tools, they don't contain the tools
- Each agent tool has its own delivery mechanism (`.claude/skills/`, `.cursor/rules/`, `copilot-instructions.md`), but the shared infrastructure lives in `.agentic/`
- If a capability only exists in one tool's directory, other agents can't use it

**Anti-pattern**: ❌ Putting a scanner script in `.claude/skills/session-start/scripts/` instead of `.agentic/lib/tools/`.
**Correct**: Script in `.agentic/lib/tools/dashboard.sh`, Claude skill calls it via `bash .agentic/lib/tools/dashboard.sh`.

Design basis: PRINCIPLES.md D7 (Multi-Environment Portability).
```

### Auto-memory cleanup (Part 3)

**MEMORY.md changes:**
- Replace `See patterns.md for detailed notes` with `See patterns.md — detailed lessons learned, design case studies, and framework-dev-specific technical debt`
- Replace the full agent-agnostic paragraph with: `**Agent-agnostic by default**: See FRAMEWORK_DEVELOPMENT.md "Agent-Agnostic by Default" section + PRINCIPLES.md D7. Core logic in .agentic/, .claude/skills/ are enhancement layer only.`

**patterns.md changes:**
- Add header: `# Patterns & Lessons Learned\n\nDetailed design decisions, case studies, and lessons from framework development. Quick-reference: see MEMORY.md. Canonical rules: see FRAMEWORK_DEVELOPMENT.md and PRINCIPLES.md.`
- Agent-agnostic section: keep the lesson text but add reference: `Canonical rule: FRAMEWORK_DEVELOPMENT.md "Agent-Agnostic by Default"`
- Remove the premature "dashboard initially Claude-only" lesson (the fix is shipping in this same PR)
- Mark "JOURNAL.md and plans — DONE" pending item done (already noted as done)

## Verification

1. `bash .agentic/lib/tools/dashboard.sh` works from new location
2. SKILL.md references `.agentic/lib/tools/dashboard.sh`
3. `quick-scan.sh` delegates to new path
4. `bash tests/validate_framework.sh` passes
5. FRAMEWORK_DEVELOPMENT.md contains the practical agent-agnostic rule
6. `grep -r "claude/skills/session-start/scripts/dashboard" .` returns no hits (old path fully removed)
7. Memory files have proper headers and canonical references
