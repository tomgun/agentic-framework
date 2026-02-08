# L-0003: Instruction file architecture — orchestrator vs subagents

**Date**: 2026-02-06
**Status**: Confirmed for Claude Code and Cursor; strongly suggested for Codex; unclear for Copilot
**Related**: L-0002, ADR-001, F-0120

---

## The tension

Three framework constraints pull in different directions:

1. **L-0002 attention budget**: CLAUDE.md compliance degrades past ~100 lines (empirical). At ~300 lines, agents ignore most instructions.
2. **ADR-001 self-containment**: CLAUDE.md must be self-contained. Agents skip "read file X for details" references.
3. **Rich workflows**: Plan-review (F-0120), orchestration, delegation, and quality gates need to reach the agent somehow.

Keeping CLAUDE.md short (L-0002) conflicts with making it comprehensive enough to trigger workflows (ADR-001). Adding workflow instructions bloats it past the attention budget.

## Critical finding: subagents do NOT inherit CLAUDE.md

Official Claude Code documentation states:
> "Subagents receive only this system prompt (plus basic environment details like working directory), not the full Claude Code system prompt."

**This means**: CLAUDE.md serves ONLY the orchestrating agent. Subagents spawned via Task tool get only their task prompt. The "subagent context multiplier" described in L-0002 was based on an incorrect assumption (see L-0002 addendum).

**Implications**:
- CLAUDE.md can be optimized purely for the orchestrator without worrying about subagent bloat
- Subagent efficiency depends on what the orchestrator passes in the Task prompt, not CLAUDE.md size
- L-0002's 100-line budget recommendation still holds — but for orchestrator attention quality, not subagent cost

## Cross-tool confirmation (2026-02-07 research)

Context isolation is an industry-wide pattern, not Claude-specific:

| Tool | Instruction File | Subagent Inherits It? | Evidence |
|------|-----------------|----------------------|----------|
| Claude Code | CLAUDE.md | **NO** | Official docs: "Subagents receive only this system prompt" |
| Cursor 2.4+ | .cursorrules | **NO** | Docs: subagents "use their own context", tools inherited but not instructions |
| GitHub Copilot | copilot-instructions.md | **Unclear** | "Attached to every session" but subagents are "context-isolated" — contradictory |
| OpenAI Codex | AGENTS.md | **N/A** | Subagent support experimental (issue #2604); instructions loaded once per main session |

**Sources**:
- Cursor: https://cursor.com/docs/context/subagents, https://cursor.com/changelog/2-4
- Copilot: https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-coding-agent
- Codex: https://developers.openai.com/codex/guides/agents-md/, https://github.com/openai/codex/issues/2604

**Implication**: Instruction files are read ONLY by the orchestrating/principal agent across all major tools. Subagent quality depends on what the orchestrator passes in the task/subagent prompt, not instruction file content.

## Official size guidance vs framework observation

- **Anthropic recommendation**: ~500 lines for CLAUDE.md (from costs documentation)
- **Framework observation (L-0002)**: Compliance degrades noticeably past ~100 lines, breaks past ~300
- **Current approach**: Keep to ~100 lines. The 500-line official limit may work for simpler instruction sets, but our CLAUDE.md has many competing high-priority rules (gates, triggers, protocols) that dilute each other faster.

## What we know works

- **Trigger table format**: Tests 003 and 010 pass — agents DO stop for acceptance criteria when the trigger table is in CLAUDE.md
- **Token-efficient scripts**: Tests 004/019 pass — agents use `journal.sh` instead of reading JOURNAL.md directly
- **Short, hierarchical CLAUDE.md**: After L-0002 slimdown from ~300 to ~80 lines, compliance returned

## What doesn't work

- **Expanding CLAUDE.md past ~300 lines**: L-0002 empirical finding — compliance breaks
- **"Read file X for details" references**: ADR-001 finding — agents skip these

## Hypothesis: ag commands as just-in-time context delivery

The `ag` commands (`ag plan`, `ag implement`, `ag commit`, `ag done`) print detailed task-specific instructions to stdout. This COULD serve as a just-in-time context mechanism:
- CLAUDE.md stays minimal (trigger table + essential rules)
- Trigger table routes agent to run the right `ag` command
- Command output delivers rich, task-specific instructions at the moment they're needed

**This is untested.** Key open questions:
1. Does command stdout have higher salience than file content? (No evidence either way)
2. Is running `ag plan` fundamentally different from reading a file? ADR-001 says agents skip "see file X" — running a command is also an indirection the agent must choose to follow.
3. Would prose triggers ("Before implementing, always run ag plan first") work better than table format?

## Open questions

- What is the true attention budget sweet spot between 100 and 500 lines?
- Could the budget safely be relaxed to 150-200 lines now that subagent bloat isn't a concern?
- Does table format (current trigger words) have higher compliance than prose format?
- Would a "router" CLAUDE.md (purely dispatch, no rules) outperform the current hybrid?

## What NOT to do

- Don't restructure CLAUDE.md as a "router" without empirical evidence
- Don't claim the ag-command pattern is proven — it's a hypothesis
- Don't expand CLAUDE.md past 100 lines based on official 500-line limit alone

---

## Resolution

See `docs/INSTRUCTION_ARCHITECTURE.md` for the definitive design that synthesizes this lesson's findings with the cross-tool research. This lesson (L-0003) is retained as historical context for how the architecture was discovered.

## Links

- **Design document**: `docs/INSTRUCTION_ARCHITECTURE.md` (authoritative)
- L-0002: Instruction bloat breaks LLM compliance (attention budget finding)
- L-0004: Plan-review process for the design document
- ADR-001: CLAUDE.md Must Be Self-Contained
- F-0120: Plan-review loop (the workflow that prompted this analysis)
- Claude Code docs: Task tool subagent context (source of inheritance finding)
