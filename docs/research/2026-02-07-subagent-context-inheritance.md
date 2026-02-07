# Research: Subagent Context Inheritance Across AI Coding Tools

**Date**: 2026-02-07
**Researcher**: Claude (Opus 4.6), directed by project lead
**Related**: L-0002, L-0003, ADR-001

---

## Research Question

Do AI coding tool subagents inherit the project instruction file (CLAUDE.md, .cursorrules, copilot-instructions.md, AGENTS.md)?

## Summary

**Context isolation is an industry-wide pattern.** Subagents across all major AI coding tools operate with their own context, not the parent agent's. The instruction file serves only the orchestrating/principal agent. Subagent quality depends on what the orchestrator passes in the task prompt, not instruction file content.

---

## Findings by Tool

### Claude Code

**Verdict: Subagents do NOT inherit CLAUDE.md**

Official Claude Code documentation explicitly states:

> "Subagents receive only this system prompt (plus basic environment details like working directory), not the full Claude Code system prompt."

Subagents spawned via the Task tool get only:
- Their task prompt (what the orchestrator passes)
- Basic environment details (working directory)
- The subagent's own system prompt

They do NOT receive: CLAUDE.md content, conversation history, or the orchestrator's full system prompt.

**Source**: Claude Code official documentation (Task tool description in system prompt)

**Confidence**: HIGH — direct quote from official docs

---

### Cursor (2.4+)

**Verdict: Subagents do NOT inherit .cursorrules**

Cursor 2.4 introduced subagents as first-class feature. Key findings:

- Subagents are "independent agents specialized to handle discrete parts of a parent agent's task"
- They "run in parallel, use their own context, and can be configured with custom prompts, tool access, and models"
- Subagents **inherit tools** from the parent by default (including the Task tool for nesting)
- Subagents **do not inherit the parent's context** — they are context-isolated

Additional context:
- A security concern was filed about subagents inheriting `allow_sensitive_data` configuration, suggesting some CONFIG is inherited but not instruction content
- A bug was reported where `model: inherit` didn't work correctly, showing that inheritance is opt-in and not always reliable
- Custom subagents can be defined with explicit prompts, tool access, and model selection

Cursor also evolved from single `.cursorrules` file to modular `.cursor/rules/` folder with `.mdc` files. Rules can be scoped with triggers (manual, auto, always-on).

**Sources**:
- https://cursor.com/docs/context/subagents
- https://cursor.com/changelog/2-4
- https://forum.cursor.com/t/cursor-2-4-subagents/149403
- https://forum.cursor.com/t/subagent-with-model-inherit-doesnt-actually-inherit-parent-model-uses-composer-1-instead/150469/7

**Confidence**: HIGH — official docs + changelog + community reports consistent

---

### GitHub Copilot

**Verdict: UNCLEAR — contradictory signals**

Copilot has two relevant mechanisms:

1. **copilot-instructions.md**: "automatically attached to the context of every Copilot session in that repository" — suggests ALL sessions, including subagent sessions, get it
2. **Subagent context isolation**: Subagents are described as "context-isolated agents (or agentic sessions) that can be invoked by the main agent to perform specific tasks, with their own context window"

These contradict each other. If copilot-instructions.md is "attached to every session" AND subagents are "context-isolated sessions," it's unclear whether subagents get copilot-instructions.md or not.

Additional context:
- Copilot reads AGENTS.md, .github/copilot-instructions.md, .github/instructions/**.instructions.md, CLAUDE.md, and GEMINI.md
- Nested AGENTS.md files apply to specific subdirectories (nearest file wins)
- Custom agents return "only the summary" to the main agent — confirms subagent context isolation for outputs
- The Copilot CLI (2026-01-14) includes specialized agents (Explore, Task) that delegate automatically

**Sources**:
- https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-coding-agent
- https://github.blog/changelog/2025-08-28-copilot-coding-agent-now-supports-agents-md-custom-instructions/
- https://github.blog/changelog/2026-01-14-github-copilot-cli-enhanced-agents-context-management-and-new-ways-to-install/
- https://code.visualstudio.com/docs/copilot/customization/custom-instructions
- https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/

**Confidence**: LOW — contradictory official docs, needs empirical testing

---

### OpenAI Codex CLI

**Verdict: N/A — subagent support is experimental**

Codex CLI reads AGENTS.md at session start via an instruction chain:

1. **Global scope**: `~/.codex/AGENTS.override.md` or `~/.codex/AGENTS.md` (first non-empty)
2. **Project scope**: walks from project root to CWD, checking each directory for AGENTS.override.md → AGENTS.md → fallback names
3. Instructions loaded **once per run** (in TUI, once per launched session)

Subagent support is still experimental:
- GitHub issue #2604 tracks subagent support
- Changelog mentions "reduced high CPU usage by eliminating busy-waiting on subagents" (so some subagent mechanism exists internally)
- No public documentation on subagent context inheritance

**Sources**:
- https://developers.openai.com/codex/guides/agents-md/
- https://developers.openai.com/codex/cli/
- https://developers.openai.com/codex/cli/reference/
- https://github.com/openai/codex/issues/2604
- https://developers.openai.com/codex/changelog/

**Confidence**: MEDIUM for instruction loading; LOW for subagent behavior (experimental)

---

## Cross-Tool Comparison Table

| Aspect | Claude Code | Cursor 2.4+ | Copilot | Codex CLI |
|--------|-------------|-------------|---------|-----------|
| **Instruction file** | CLAUDE.md | .cursorrules / .cursor/rules/ | copilot-instructions.md + AGENTS.md | AGENTS.md |
| **Subagent inherits it?** | NO | NO | Unclear | N/A (experimental) |
| **Tools inherited?** | Task prompt only | YES (all tools) | Unclear | N/A |
| **Config inherited?** | NO | Partially (security concern) | Unclear | N/A |
| **Custom subagents?** | Via Task tool prompt | YES (SKILL.md, .mdc) | YES (custom agents) | Experimental |
| **Confidence** | HIGH | HIGH | LOW | LOW |

---

## Implications for the Framework

### 1. Instruction files serve the orchestrator only
CLAUDE.md, .cursorrules, copilot-instructions.md, and codex-instructions.md should be optimized for the orchestrating agent. Subagent concerns (L-0002's "context multiplier") do not apply.

### 2. Subagent quality depends on orchestrator delegation
Since subagents don't inherit instruction files, the quality of subagent work depends entirely on:
- What the orchestrator passes in the task/subagent prompt
- The subagent's own definition file (for tools that support custom subagents)
- The framework's context manifests (`.agentic/agents/context-manifests/`)

### 3. Subagent definitions must be self-contained
Because subagents can't "read file X" from instruction file references, each subagent definition must contain all critical instructions inline. "Full documentation: see file X" footers are unreliable.

### 4. The context-for-role.sh tool is the right mechanism
The framework's existing `context-for-role.sh` tool assembles minimal, role-specific context for subagents. This is architecturally correct — it's the orchestrator's responsibility to assemble and pass context, not the subagent's responsibility to discover it.

### 5. Copilot needs empirical testing
The contradictory signals from Copilot docs mean we should run an empirical test: create a copilot-instructions.md with a distinctive instruction, spawn a subagent, and check whether the subagent follows it.

---

## Actions Taken

Based on this research:
- **L-0002**: Corrected — "subagent context multiplier" section marked as wrong with addendum
- **L-0003**: Updated with cross-tool evidence table
- **CLAUDE.md**: Replaced "Pass to subagent ONLY" with `context-for-role.sh` reference
- **Subagent definitions**: Removed 5 "Full documentation: see file X" footers
- **CONTRIBUTIONS.md**: Research finding credited

## Open Questions

1. Does Copilot actually load copilot-instructions.md into subagent sessions? (Needs empirical test)
2. When Codex stabilizes subagent support, will AGENTS.md be inherited? (Monitor issue #2604)
3. Cursor's partial config inheritance (security concern) — does this affect instruction content too?
4. As tools evolve, will they converge on a standard for subagent context? (AGENTS.md format is gaining adoption across tools)
