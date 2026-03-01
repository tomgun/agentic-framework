# Research: Does Frontmatter Rot the Context?

**Date**: 2026-03-01
**Context**: After adding frontmatter to 168 `.agentic/` files (F-0144), we investigated whether this metadata pollutes Claude's context window.
**Status**: Analysis complete — no context rot risk identified

## TL;DR

Two completely separate frontmatter systems exist. Only one touches the system prompt:

| System | Files | In system prompt? | Token cost |
|--------|-------|-------------------|------------|
| `.claude/skills/*/SKILL.md` frontmatter | 12 files | **YES** — always loaded | ~900 tokens (descriptions only) |
| `.agentic/**/*.md` frontmatter | 168 files | **NO** — never auto-loaded | 0 tokens (read only on-demand) |

The 168 files we added frontmatter to are in `.agentic/` — they **never touch the system prompt**.

## What DOES Get Loaded Into the System Prompt

Per the Anthropic Skills spec (see `2026-02-28-skills-hybrid-analysis.md`):

> 1. **YAML frontmatter**: Always loaded in system prompt. Tells Claude WHEN to activate.
> 2. **SKILL.md body**: Loaded when Claude thinks skill is relevant.
> 3. **Linked files**: Additional files Claude discovers only as needed.

For our 12 skills in `.claude/skills/`:

| Level | What | When | Token cost |
|-------|------|------|------------|
| Frontmatter (name + description) | 12 skill descriptions | **Always** | ~900 tokens |
| SKILL.md body | Full instructions | When skill matches task | ~6,800 tokens (5,103 words) |
| `references/*.md` | 11 playbook copies | On-demand, if skill navigates | ~24,000 tokens (18,018 words) |

**Worst case** (all 12 skills triggered + all references read): ~31,700 tokens. Unlikely — typical session triggers 2-3 skills.

## What Does NOT Get Loaded

The 168 `.agentic/**/*.md` files with frontmatter:

- **Not auto-loaded** by Claude Code (it only auto-discovers CLAUDE.md + `.claude/skills/`)
- **Not scanned** by any framework mechanism
- Only read when an agent explicitly opens a file (e.g., `Read .agentic/workflows/tdd_mode.md`)
- Frontmatter sits there as metadata at the top of the file — identical to a comment

The frontmatter on `.agentic/` files was designed for a **future optimization** (agents scan summaries before loading full files). No scanning code exists yet. Currently it's inert metadata.

## The Real Context Rot Question: Skills

The 12 skill descriptions ARE always in the system prompt (~900 tokens). For a **non-framework project** using this framework, all 12 are relevant (they cover the universal dev workflow: implement, test, commit, review, etc.). No rot here.

However, if someone added 50+ domain-specific skills (e.g., "Kubernetes deployment", "iOS App Store submission", "JUCE plugin build") to a project that only uses 3 of them — that would be mild context rot (~50 × 75 tokens = ~3,750 tokens of irrelevant descriptions always loaded). Still small relative to a 200K context window, but not zero.

## Conclusion

**The `.agentic/` frontmatter we added is completely inert.** It doesn't enter the system prompt, doesn't get scanned, doesn't cost tokens until someone explicitly reads the file. No context rot risk.

The only context cost is the 12 skill descriptions in `.claude/skills/` (~900 tokens always loaded), which are all relevant to any project using the framework.

## Key Files Traced

- `docs/research/2026-02-28-skills-hybrid-analysis.md:45` — Anthropic spec: "YAML frontmatter: Always loaded in system prompt"
- `.claude/skills/*/SKILL.md` — 12 skills, ~5,103 words total body
- `.claude/skills/*/references/*.md` — 11 reference files, ~18,018 words total (on-demand)
- `.agentic/tools/context-for-role.sh` — manifest-based loading, no frontmatter scanning
- `.agentic/agents/context-manifests/*.yaml` — explicit file lists, not discovery-based
