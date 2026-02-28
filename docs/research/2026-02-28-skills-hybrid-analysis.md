# Skills Hybrid Analysis: Anthropic Skills Guide vs Agentic Framework

**Date**: 2026-02-28
**Source**: [The Complete Guide to Building Skills for Claude](anthropic-complete-guide-building-skill-for-claude.pdf)
**Status**: Analysis complete, planning next steps

## Context

Anthropic published an official guide for building "Skills" for Claude - structured instruction packages (SKILL.md + scripts/ + references/ + assets/) that teach Claude specific workflows. This analysis compares their approach with our framework and evaluates three strategic options.

## Where They Converge (Validated Insights)

Our framework independently discovered several patterns Anthropic now codifies:

| Anthropic Skills Concept | Our Framework Equivalent | Status |
|---|---|---|
| Progressive Disclosure (3 levels: frontmatter → body → linked files) | Three-Layer Architecture (Constitution → Playbooks → State) | Same insight, different names |
| Token efficiency is critical | F3 principle, token-efficient scripts, minimal viable context | We go deeper |
| Keep instructions concise | ~100 line constitution ceiling (empirically validated) | We quantified it |
| Composability (multiple skills coexist) | Multi-role context manifests (24 role-specific templates) | We operationalized it |
| Trigger-based activation (YAML description) | Trigger words table in CLAUDE.md | Same pattern |
| "Code is deterministic; language interpretation isn't" (p.26) | D2: Deterministic Enforcement (scripts enforce, docs guide) | Our core principle |

## Where They Diverge (Critical Differences)

| Dimension | Anthropic Skills | Our Framework |
|---|---|---|
| **Scope** | Task-specific recipes (make a doc, run a workflow) | Complete dev methodology (specs → code → test → commit → ship) |
| **Enforcement** | Language instructions + optional scripts | Structural gates (pre-commit-check.sh exits 1) |
| **State** | Stateless - each conversation starts fresh | Durable state (STATUS.md, JOURNAL.md, WIP.md survive sessions) |
| **Multi-env** | Claude.ai + Claude Code + API only | Claude + Cursor + Copilot + Codex |
| **Distribution** | Marketplace upload, org-wide deployment, API | upgrade.sh + git |
| **Complexity** | Single folder with SKILL.md | 40+ files, 11 gates, 24 manifests, orchestration scripts |

## Anthropic Skills Architecture

### What is a Skill?
A folder containing:
- **SKILL.md** (required): Instructions in Markdown with YAML frontmatter
- **scripts/** (optional): Executable code (Python, Bash, etc.)
- **references/** (optional): Documentation loaded as needed
- **assets/** (optional): Templates, fonts, icons used in output

### Progressive Disclosure (3 levels)
1. **YAML frontmatter**: Always loaded in system prompt. Tells Claude WHEN to activate.
2. **SKILL.md body**: Loaded when Claude thinks skill is relevant. Full instructions.
3. **Linked files**: Additional files Claude discovers only as needed.

### Skill Categories
1. **Document & Asset Creation** - Consistent output (docs, presentations, code)
2. **Workflow Automation** - Multi-step processes with validation gates
3. **MCP Enhancement** - Workflow guidance on top of MCP tool access

### Key Technical Details
- YAML frontmatter: name (kebab-case, required) + description (required, <1024 chars)
- No XML tags in frontmatter (security)
- No "claude" or "anthropic" in skill names (reserved)
- Skills are an **open standard** - designed for cross-platform adoption
- API support via `/v1/skills` endpoint and `container.skills` parameter
- Org-level deployment available (shipped Dec 2025)

### Patterns from the Guide
1. **Sequential workflow orchestration** - ordered steps with dependencies
2. **Multi-MCP coordination** - workflows spanning multiple services
3. **Iterative refinement** - quality checks with improvement loops
4. **Context-aware tool selection** - different tools based on context
5. **Domain-specific intelligence** - embedded expertise beyond tool access

### Key Quote (p.26)
> "For critical validations, consider bundling a script that performs the checks programmatically rather than relying on language instructions. Code is deterministic; language interpretation isn't."

This validates our D2 principle entirely.

## Three Strategic Options Evaluated

### Option A: New Claude-Only Framework via Skills
Rewrite everything as Claude Skills.

**Gains**: Native distribution, marketplace, simpler packaging, Agent SDK integration.
**Loses**: Multi-environment support, structural enforcement, durable state, `ag` orchestration.
**Verdict**: Skills are recipes, not a methodology. Can't express "block commit if specs not updated" in SKILL.md. **Too much lost.**

### Option B: Streamline Current Framework
Simplify what we have, adopt Skills-style patterns.

**Gains**: Keep everything that works, adopt progressive disclosure formalization.
**Loses**: Can't leverage Claude's native skill distribution/marketplace.
**Verdict**: Safe but misses the opportunity. **Not enough gained.**

### Option C: Hybrid (Recommended)
Package our framework methodology AS Claude Skills, backed by structural enforcement.

**Insight**: Skills are the **delivery mechanism** (UI layer), our scripts are the **runtime** (enforcement layer). They're different layers that compose naturally.

```
Claude Skills (UI layer)     → How users trigger workflows
├── .agentic/scripts/        → Structural enforcement (deterministic)
├── .agentic/playbooks/      → Detailed guidance (loaded by scripts)
└── State files              → Durable artifacts (survive sessions)

.cursorrules / copilot-instructions.md  → Non-Claude tools still work
```

**Proposed skill structure:**
```
.agentic/skills/
├── implementation/
│   ├── SKILL.md                          # Frontmatter + instructions
│   ├── scripts/ag-implement.sh           # Wraps existing scripts
│   └── references/feature_pipeline.md    # Points to existing playbooks
├── review/
│   ├── SKILL.md
│   └── references/review_checklist.md
├── commit/
│   ├── SKILL.md
│   ├── scripts/pre-commit-check.sh       # Structural gates
│   └── references/before_commit.md
├── planning/
│   ├── SKILL.md
│   └── references/acceptance_criteria.md
└── session-start/
    ├── SKILL.md
    └── scripts/wip-check.sh
```

## Issues Discovered During Analysis

- **T-0015**: Agent should auto-enter worktree when another agent is active (behavioral rule exists, not enforced)
- **T-0016**: AGENTS_ACTIVE.md referenced in 30+ files but never written to (dead feature)

Both are examples of the core problem: behavioral instructions without structural enforcement.

## Next Steps

- Plan the hybrid approach in detail
- Identify which framework workflows map to skills
- Prototype one skill (e.g., implementation) to validate the approach
- Determine if Skills format can coexist with current multi-env instruction files
