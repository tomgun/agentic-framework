# Key Insights: What Actually Works for AI Agent Control

**Purpose**: Strategic lessons from 50+ versions of framework development. Not tactical mistakes (those are in `FRAMEWORK_DEVELOPMENT.md` § Lessons Learned) — these are the **design patterns that make AI agents reliably productive**.

**Audience**: Anyone building an agentic coding workflow — whether using this framework or designing their own.

---

## 1. Tiny Instruction File + Memory Reinforcement

**The problem**: AI agents read their instruction file (CLAUDE.md, .cursorrules, etc.) at session start. Past ~100 lines, attention degrades measurably — rules at the bottom get ignored. But a real project has hundreds of rules.

**What works**: Keep the main instruction file under 50 lines. It contains ONLY what can't be enforced any other way: trigger words ("implement" → run `ag implement`), behavioral rules ("never auto-commit"), and pointers to deeper docs. Everything else lives in scripts, skills, or state files loaded on demand.

**The reinforcement layer**: Rules fade as context grows during a session. Persistent memory (Claude Code's `MEMORY.md`, Cursor's `.mdc` rules) acts as a second copy. Same rules, different delivery path. If the instruction file gets compressed away mid-session, memory still holds the pattern. Neither is sufficient alone; together they're robust.

**Empirical finding (L-0002)**: Compliance degrades past ~100 lines. Our production templates are 38–54 lines. The research suggested 300–800 tokens (~15–40 lines); we found ~800–1000 tokens (~40–50 lines) is the practical sweet spot when you need competing high-priority rules.

**See**: `docs/INSTRUCTION_ARCHITECTURE.md` §2 (Three-Layer Architecture), §8 (Testable Assumptions, A3/A8)

---

## 2. Skills with Frontmatter Descriptions

**The problem**: Agents need different instructions for different tasks — implementing a feature requires different workflow than committing code or reviewing a PR. You can't put all workflows in the instruction file (see insight #1). Loading everything at start wastes context.

**What works**: Claude Code's Skills system — each workflow is a self-contained bundle (instructions + scripts + references) with a YAML frontmatter description. Only the descriptions (~900 tokens total for 12 skills) are loaded at session start. When a user says "implement feature X", Claude matches the intent to the `implementing-features` skill and loads ONLY that skill's full instructions.

**Why this is powerful**:
- **Intent matching, not keyword matching**: Frontmatter descriptions use natural language. "build", "create", "add feature" all trigger `implementing-features` without explicit keyword lists in the instruction file.
- **Progressive disclosure**: 12 skills × ~2K tokens each = ~24K of workflow instructions. Only ~900 tokens loaded always. The rest loads just-in-time. ~96% token savings.
- **Composable**: Each skill is independent. Adding a new workflow doesn't bloat the main instruction file or interfere with others.
- **Testable**: You can verify skill triggering with LLM behavioral tests (does "fix this bug" activate the test-first workflow?).

**For non-Claude-Code tools**: Same principle via `auto_orchestration.md` + `ag` commands. `ag implement` prints the relevant workflow instructions to stdout. Different delivery mechanism, same just-in-time pattern.

**See**: `docs/INSTRUCTION_ARCHITECTURE.md` §2 (Skills subsection), `.claude/skills/*/SKILL.md`

---

## 3. Scripts Over Instructions — Token Savings + Determinism

**The problem**: Telling an agent "update JOURNAL.md by appending a new entry with today's date under the last entry" costs ~500 tokens of instruction, then ~2K tokens to read the file, then variable tokens for the agent to figure out the edit. The agent might format it wrong, put it in the wrong section, or hallucinate the date format. Total: ~3K+ tokens with unreliable results.

**What works**: `bash journal.sh "Topic" "Done" "Next" "Blockers"` — one line, ~50 tokens. The script handles file format, date, section placement, deduplication. Zero ambiguity, zero read cost, identical result every time. ~40x more efficient than read-modify-write.

**The principle**: Anything that can be a script SHOULD be a script. Scripts are:
- **Deterministic**: Same input → same output, regardless of which AI model runs them
- **Token-efficient**: No need to read the file, understand its format, compose the edit
- **Portable**: Works in Claude Code, Cursor, Copilot, Codex — any tool that can run bash
- **Testable**: Unit-testable without LLM, assertions on exit codes and output

**Where we apply this**:
- State file updates: `journal.sh`, `status.sh`, `feature.sh`, `blocker.sh`, `todo.sh`
- Project health checks: `doctor.sh`, `check-spec-health.sh`, `spec-analyze.sh`
- Context assembly: `context-for-role.sh` (builds role-specific context for subagents)
- Session orchestration: `dashboard.sh`, `ag sync`, `ag start`
- Quality gates: `pre-commit-check.sh` (17 structural checks)

**The boundary**: Scripts handle deterministic operations. The AI handles judgment calls (code review, architecture decisions, debugging). Don't try to script what requires reasoning; don't rely on AI for what can be computed.

**See**: `.agentic/lib/PRINCIPLES.md` D2 (Deterministic Enforcement), F3 (Token Optimization)

---

## 4. Git Hooks and Structural Gates

**The problem**: You can write "never commit without updating the journal" in the instruction file. The agent will follow it... sometimes. Under context pressure, after long sessions, with competing priorities — behavioral rules get dropped. The more rules you add, the less reliably any single rule is followed.

**What works**: `pre-commit-check.sh` as a git hook. It runs 17 checks automatically on every commit attempt. The agent literally cannot commit if the journal is stale, if acceptance criteria files are missing, if there's active WIP from another agent, or if complexity limits are exceeded. No instruction needed — the commit just fails with a clear error message telling the agent what to fix.

**The hierarchy**:
1. **Structural gates** (script exit codes): Cannot be bypassed. Agent must fix the issue. Examples: pre-commit hook, `ag implement` requiring spec files, `ag done` validation.
2. **Behavioral rules + LLM tests**: Agent should follow, and we verify empirically that it does. Examples: "never auto-commit" (LLM-005), "test-first for bugs" (LLM-048).
3. **Behavioral rules only**: Agent should follow, but we can't verify easily. Examples: smoke testing before "done", reading CONTEXT_PACK first.

**The insight**: Move rules DOWN this hierarchy whenever possible. If you can make it a gate, don't leave it as an instruction. Gates survive context compression, model differences, and session fatigue. Instructions don't.

**Beyond git hooks**: The same principle applies to any enforcement point:
- `ag implement` gates: checks for spec files, approved plans, backlog order
- `ag commit` gates: journal freshness, STATUS.md currency, feature tracking
- `ag done` gates: acceptance criteria verification, test passage
- Session start: `wip.sh check` detects interrupted work before new work begins

**The counterbalance**: Not everything should be a hard gate. Soft warnings (scope drift, change size, advisory checks) are better for signals that require human judgment. Hard gates for invariants; soft warnings for heuristics.

**See**: `.agentic/lib/PRINCIPLES.md` D2 (Deterministic Enforcement), `docs/INSTRUCTION_ARCHITECTURE.md` §5.1

---

## 5. Trigger Tables: Keywords + Intent = Reliable Routing

**The problem**: AI agents are general-purpose. When a user says "implement the login page", the agent needs to know this means "run `ag implement`, check for specs, follow the acceptance-driven workflow" — not just start writing code. How do you route user intent to the right workflow?

**What works**: A trigger table — a compact mapping from user words/intent to framework actions. Two evolution stages:

**Stage 1 — Keyword triggers** (in instruction files, all tools):
```
"build/implement/add/create" → STOP. Spec first, then ag plan, then ag implement
"fix/debug/repair"           → STOP. Write failing test FIRST, then fix
"commit/push/ship/finalize"  → STOP. Pre-commit sequence, then ag commit
"done/complete/finished"     → STOP. Run ag done F-XXXX
```
This works because it's explicit and compact. The agent sees "implement" in the user's message, matches it to the table, runs the prescribed workflow. Fits in ~20 lines of the instruction file. Empirically validated (LLM tests 003/010 pass).

**Stage 2 — Intent-based triggers** (Claude Code Skills, frontmatter descriptions):
```yaml
# implementing-features/SKILL.md frontmatter:
description: >
  Use when the user wants to build new functionality — e.g. "build",
  "implement", "add feature", "create [thing]", "develop", "wire up",
  "implement F-XXXX", "ag implement", or any description of new work to do.
  Match intent, not exact words.
```
Intent-based triggers go beyond keyword matching. "Can you make the sidebar collapsible?" doesn't contain "implement" or "build", but the intent is clearly "new functionality" — and the skill triggers correctly. The frontmatter description tells the AI both the keywords AND the intent pattern to match.

**Why both matter**:
- Keywords are reliable anchors (agent definitely matches "implement")
- Intent descriptions catch natural language variations the keyword list misses
- Together they provide robust routing without requiring the user to use magic words
- The "Do NOT use for" section in skill descriptions prevents false triggers ("fix a bug" → `fixing-bugs`, not `implementing-features`)

**The STOP pattern**: Every trigger starts with STOP. This is critical. Without it, the agent's default behavior is to just start coding. STOP forces a workflow check first: do specs exist? Is there a plan? Is the backlog in order? This single word prevents the most common failure mode — agents skipping process because they're eager to produce code.

**See**: `.claude/skills/*/SKILL.md` (intent-based), `memory-seed.md` § Trigger Words (keyword-based), LLM tests 003/010

---

## 6. Durable Plans and State — Or They Don't Exist

**The problem**: Plans created in Claude Code's plan mode live in `~/.claude/plans/` with random filenames. Session ends → plan is effectively gone. We lost multiple reviewed, approved plans this way before learning the lesson. Same for any session-scoped state.

**What works**: Every artifact that matters must be git-tracked. Plans go to `.agentic/journal/plans/F-XXXX-plan.md`. Status goes to `STATUS.md`. Progress goes to `JOURNAL.md`. If it's not in git, it doesn't survive.

**The broader principle**: AI agent sessions are ephemeral. Context windows compress. Sessions end. Machines change. The ONLY things that reliably persist are:
- Git-tracked files (survive everything)
- Tool-specific persistent memory (survives sessions, not machines)
- Nothing else

Design your workflow around this reality. Every valuable output must reach a git-tracked file before the session ends. `ag sync` scans for ephemeral plans and copies them. `pre-commit-check.sh` blocks if journal/status are stale. These are structural responses to the ephemeral nature of AI sessions.

**See**: `FRAMEWORK_DEVELOPMENT.md` § "Plans given as user messages don't auto-save"

---

## 7. Distributed Enforcement Over Central Orchestrator

**The problem**: Academic research (and common sense) suggests a central orchestrator that validates all agent actions. But this framework runs across Claude Code, Cursor, Copilot, and Codex — there IS no single orchestrator process.

**What works**: Each script enforces its own phase. `ag implement` checks planning prerequisites. `pre-commit-check.sh` checks commit prerequisites. `ag done` checks completion prerequisites. No central coordinator needed. Each gate is independently reliable.

**Why this matters**: It means enforcement works in ANY tool that can run bash. Adding a new AI tool doesn't require integrating with an orchestrator — just point it at the same scripts. The `ag` gateway provides a unified entry point, but each underlying script is independently functional.

**See**: `docs/INSTRUCTION_ARCHITECTURE.md` §2 (Orchestrator Enforcement)

---

## 8. LLM Behavioral Testing — Verify What Agents Actually Do

**The problem**: You write an instruction. Does the agent follow it? You don't know unless you test. Different models interpret the same instruction differently. Updates to instruction files can silently break compliance.

**What works**: A test suite (48+ tests) that runs real LLM prompts against the framework's instruction files and checks agent behavior. "Given this instruction file, when the user says 'implement feature X', does the agent run `ag implement`?" (LLM-003). "When asked to commit, does the agent check for human approval?" (LLM-005).

**The key insight**: Instruction files are code. They need tests. Without tests, you're guessing whether your instructions work. With tests, you can refactor instruction files, slim them down, move content to skills — and verify nothing broke.

**See**: `tests/llm/` test suite, `docs/INSTRUCTION_ARCHITECTURE.md` §8 (Testable Assumptions)

---

## Summary: The Pattern

These insights form a coherent pattern:

```
Tiny instruction file (50 lines)     → agent reads it all, reliably
  + Memory reinforcement             → survives context compression
  + Skills with frontmatter          → right instructions at right time
  + Scripts for deterministic ops    → cheap, reliable, portable
  + Git hooks / structural gates     → rules that can't be ignored
  + Git-tracked durable artifacts    → state that survives sessions
  + Distributed enforcement          → works across all AI tools
  + LLM behavioral tests             → verify it actually works
```

The meta-lesson: **structural enforcement > behavioral instructions > hope**. Anything important enough to be a rule is important enough to be enforced by code, not by documentation.

---

**Related documents**:
- `FRAMEWORK_DEVELOPMENT.md` § Lessons Learned — tactical mistakes and fixes
- `docs/INSTRUCTION_ARCHITECTURE.md` — formal three-layer architecture design
- `.agentic/lib/PRINCIPLES.md` — foundational principles (WHY)
- `CONTRIBUTIONS.md` — design insights from specific features
