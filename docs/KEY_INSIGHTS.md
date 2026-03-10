# Key Insights: What Actually Works for AI Agent Control

**Purpose**: Strategic lessons from v0.1.0 through v0.53.2 (~1400 commits) of framework development. Not tactical mistakes (those are in `FRAMEWORK_DEVELOPMENT.md` § Lessons Learned) — these are the **design patterns that make AI agents reliably productive**.

**Audience**: Anyone building an agentic coding workflow — whether using this framework or designing their own.

**Contributor**: These insights were discovered by Tomas through hands-on building, testing, breaking, and rebuilding across 53 framework versions and ~1400 commits. Each pattern was earned through real failures — lost plans, ignored rules, corrupted state, skipped workflows — and the stubborn insistence on understanding *why* things failed, not just fixing them.

---

## At a Glance

| # | Insight | Core Idea | Token Impact |
|---|---------|-----------|-------------|
| 1 | [Tiny Instruction File + Memory](#1-tiny-instruction-file--memory-reinforcement) | Main file <50 lines; memory as redundant reinforcement | ~1K always-loaded vs ~10K+ if everything inline |
| 2 | [Skills with Frontmatter](#2-skills-with-frontmatter-descriptions) | Workflow bundles loaded just-in-time by intent match | ~900 tokens always vs ~24K if all loaded |
| 3 | [Scripts Over Instructions](#3-scripts-over-instructions--token-savings--determinism) | Deterministic scripts replace read-modify-write | ~50 tokens vs ~3K+ per state update |
| 4 | [Structural Gates via Hooks](#4-git-hooks-and-structural-gates) | Rules enforced by exit codes, not hope | Zero tokens — enforcement is automatic |
| 5 | [Keyword + Intent Triggers](#5-trigger-tables-keywords--intent--reliable-routing) | STOP → workflow routing via trigger tables + skill descriptions | ~20 lines in instruction file |
| 6 | [Durable Git-Tracked State](#6-durable-plans-and-state--or-they-dont-exist) | If it's not in git, it doesn't survive | N/A — architectural principle |
| 7 | [Distributed Enforcement](#7-distributed-enforcement-over-central-orchestrator) | Each script enforces its own phase, no central orchestrator | N/A — works across all AI tools |
| 8 | [LLM Behavioral Testing](#8-llm-behavioral-testing--verify-what-agents-actually-do) | Instruction files are code — they need tests | N/A — verification mechanism |
| 9 | [Deliberate Context Management](#9-deliberate-context-management) | Curated context beats "read everything" — CONTEXT_PACK, specs, role manifests, fresh subagents | 5–10K focused vs 100K+ bloated |
| 10 | [Dialectical Plan Review](#10-dialectical-plan-review--trust-only-the-critics-words) | Multi-round Critic + Advocate review; trust only the Critic | Catches design flaws before implementation |
| 11 | [Revision Guidance — Don't Trust the Critic Blindly](#11-revision-guidance--dont-trust-the-critic-blindly) | Critic finds real issues but proposes wrong fixes — planner must judge | Prevents removing features that were the whole point |
| 12 | [LLM-Optimized Formats](#12-llm-optimized-formats-for-everything) | Structure all files so LLMs parse them efficiently — frontmatter, markdown, tables | Faster parsing, fewer misunderstandings, less re-reading |
| 13 | [Plans Are Never Done After One Pass](#13-plans-are-never-done-after-one-pass) | AI plans are impressive but always have gaps — multi-round review is essential, not optional | Catches flaws that cost 10x more to fix in code |

**Meta-lesson**: structural enforcement > behavioral instructions > hope.

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

**What works**: Claude Code's Skills system — each workflow is a self-contained bundle (instructions + scripts + references) with a YAML frontmatter description. Only the descriptions (~900 tokens total for 13 skills) are loaded at session start. When a user says "implement feature X", Claude matches the intent to the `implementing-features` skill and loads ONLY that skill's full instructions.

**Why this is powerful**:
- **Intent matching, not keyword matching**: Frontmatter descriptions use natural language. "build", "create", "add feature" all trigger `implementing-features` without explicit keyword lists in the instruction file.
- **Progressive disclosure**: 13 skills × ~2K tokens each = ~26K of workflow instructions. Only ~900 tokens loaded always. The rest loads just-in-time. ~96% token savings.
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

**What works**: `pre-commit-check.sh` as a git hook. It runs 16 checks automatically on every commit attempt. The agent literally cannot commit if the journal is stale, if acceptance criteria files are missing, if there's active WIP from another agent, or if complexity limits are exceeded. No instruction needed — the commit just fails with a clear error message telling the agent what to fix.

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

**See**: `.agentic/lib/PRINCIPLES.md` D2 (Deterministic Enforcement), `docs/INSTRUCTION_ARCHITECTURE.md` §5

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

**What works**: A test suite (62+ tests) that runs real LLM prompts against the framework's instruction files and checks agent behavior. "Given this instruction file, when the user says 'implement feature X', does the agent run `ag implement`?" (LLM-003). "When asked to commit, does the agent check for human approval?" (LLM-005).

**The key insight**: Instruction files are code. They need tests. Without tests, you're guessing whether your instructions work. With tests, you can refactor instruction files, slim them down, move content to skills — and verify nothing broke.

**See**: `tests/llm/` test suite, `docs/INSTRUCTION_ARCHITECTURE.md` §8 (Testable Assumptions)

---

## 9. Deliberate Context Management

**The problem**: AI agents default to reading everything they can find. A new session starts, the agent reads 20 source files, 5 config files, the entire README — and burns 80K tokens before doing any work. Then mid-task it reads more files, context fills up, early instructions get compressed out, and the agent loses the plot. Worse: subagents spawned via the Task tool inherit NONE of the parent's context — they start completely blank.

**What works**: A layered context management system where every agent — main or sub — receives exactly the context it needs, no more:

**Layer 1 — CONTEXT_PACK.md** (~2–5K tokens): A curated architecture snapshot that every agent reads first. Where things are, how they connect, key decisions. This single file replaces the "let me explore the codebase" phase that burns 20–50K tokens. Updated in the same commit as code changes (Living Documentation principle).

**Layer 2 — Spec files as context**: Acceptance criteria files (`spec/acceptance/F-XXXX.md`) aren't just contracts — they're the most token-efficient way to tell an agent what a feature should do. Instead of reading the implementation to understand intent, read the 20-line spec. FEATURES.md provides the index.

**Layer 3 — Role-specific context manifests**: `context-for-role.sh` assembles context packages for 24 different agent roles (reviewer, tester, implementer, etc.). Each manifest declares exactly which files that role needs. A review agent gets the spec + changed files + quality standards. An implementer gets the spec + architecture + relevant source. No role gets everything.

**Layer 4 — Fresh subagents over bloated sessions**: When context grows past ~50K tokens, spawn a subagent with fresh, focused context (5–10K) instead of continuing in the degraded main session. The subagent does one job well — review, test, research — and returns results. This is why `context-for-role.sh` exists: it builds the context injection that makes subagents immediately productive without inheriting the parent's accumulated drift.

**The key principle**: Context is a budget, not a buffet. Every token loaded is a token of attention diluted from everything else. Curate aggressively.

**See**: `.agentic/lib/PRINCIPLES.md` F3 (Token Optimization), `context-for-role.sh`, CONTEXT_PACK.md

---

## 10. Dialectical Plan Review — Multi-Round Critic + Advocate

**The problem**: A single review pass — whether human or AI — catches surface issues but misses structural flaws. The planner is biased toward their own design. A single reviewer is biased by their review lens. Plans that "look good" at first glance often have fundamental problems that only emerge when examined from opposing perspectives.

**What works**: A dialectical review process with three distinct roles:

1. **Critic agent** (fresh context): Attacks the plan. Looks for missing edge cases, violated principles, over-engineering, under-engineering, security gaps, scalability issues. The Critic's job is to find problems — they have no investment in the plan.
2. **Advocate agent** (fresh context): Defends the plan's strengths. Explains why design decisions make sense. Catches cases where the Critic is wrong or overly conservative. The Advocate prevents good ideas from being killed by excessive caution.
3. **Planner** (original context): Synthesizes both perspectives. Decides which Critic findings are real issues vs. false positives. Revises the plan.

**Why fresh context matters**: Both Critic and Advocate are spawned as subagents with ONLY the plan + project context — they haven't seen the conversation that led to the plan. This prevents groupthink. They evaluate the plan on its merits, not on the social dynamics of the conversation.

**Multi-round**: If the Critic finds serious issues and the plan is revised, the revised plan gets a fresh review cycle. This continues until the plan is clean or the user decides to proceed. Typically 1–3 rounds.

**The setting**: `plan_review_enabled: yes` in STACK.md activates this. Discovery profile skips it (lightweight). Formal profile uses it (rigorous).

**See**: `.agentic/journal/plans/` (reviewed plans), `ag plan` workflow

---

## 11. Revision Guidance — Don't Trust the Critic Blindly

**The problem**: The dialectical review (insight #10) works well at finding problems. But there's a subtle trap: the Critic is good at identifying *what's wrong* but often bad at proposing *how to fix it*. Specifically, the Critic tends to recommend removing features or simplifying to the point where the plan no longer achieves its original purpose. The Critic optimizes for "no risk" — the planner must optimize for "right tradeoffs."

**What actually happened**: In multiple framework planning sessions, the Critic correctly identified real concerns (complexity, scope, edge cases) but then recommended removing the very capabilities that were the entire motivation for the feature. Left unchecked, following the Critic's suggested fixes would produce a plan that's "safe" but pointless — all the ambition surgically removed.

**What works**: A **Revision Guidance** step between the review and the revision:

1. Critic and Advocate deliver their findings
2. Before the planner revises, a synthesis step explicitly separates: **(a)** problems the Critic found (these are usually valid) from **(b)** solutions the Critic proposed (these often miss the point)
3. The planner addresses each problem with their own solution that preserves the plan's intent
4. The revision explicitly notes: "Accepted finding X, but used a different fix because the Critic's suggestion would have removed [core capability]"

**The meta-lesson**: In AI-assisted review, treat findings and fixes as independent. Accept the diagnosis, prescribe your own treatment. This applies beyond plan review — code review, spec review, any multi-agent review process where one agent evaluates another's work.

**See**: `CONTRIBUTIONS.md` § Critical Review Agent (F-0182)

---

## 12. LLM-Optimized Formats for Everything

**The problem**: LLMs process text sequentially. A 500-line unstructured log, a deeply nested JSON config, or a prose paragraph explaining a feature's status all cost the same tokens to read — but yield vastly different comprehension. Most project files are written for humans (or for machines via JSON/YAML). Neither format is optimized for what LLMs actually need: structured, scannable, self-describing content with clear semantic boundaries.

**What works today**: The framework already uses LLM-friendly patterns in many places:

- **YAML frontmatter on everything**: 168 of 212 `.agentic/` files have frontmatter with `summary` and `tokens` fields. An agent can read the 2-line summary (~20 tokens) instead of the full file (~2K tokens) to decide if it's relevant. This enables ~96% discovery savings.
- **Structured markdown with clear headings**: FEATURES.md, JOURNAL.md, STATUS.md all use consistent heading hierarchies and field patterns (`**Status**: shipped`, `**Added**: date`). LLMs can grep/parse these reliably without understanding natural language.
- **Tables over prose**: The trigger word table (insight #5) works because it's a compact lookup structure, not a paragraph. Same for the summary table at the top of this document — an LLM can route to the right section without reading 250 lines.
- **Token-efficient scripts as interfaces**: Instead of "read this file and understand its format", the agent calls `journal.sh` with structured arguments. The format is hidden behind a script API.

**What's still missing** (future work):
- **Spec files**: Acceptance criteria are free-form markdown. A structured format (e.g., each AC as a YAML block with `id`, `description`, `testable`, `checked` fields) would enable automated parsing, dependency graphing, and progress tracking without LLM interpretation.
- **State files**: STATUS.md and JOURNAL.md use markdown that requires some parsing intelligence. Machine-readable structured formats (with markdown rendering for humans) would make agent access more deterministic.
- **Config consolidation**: Settings are split across STACK.md (grep-parsed), profiles.conf, and various script defaults. A single structured config (YAML/TOML) with schema validation would reduce the "where is this setting?" problem for both agents and humans.
- **Conversation-to-artifact extraction**: Much valuable context lives in conversation transcripts (design decisions, rejected alternatives, rationale). No systematic format exists for extracting and persisting these as structured, LLM-queryable artifacts.

**The principle**: Every file an LLM reads should be structured for LLM consumption. Frontmatter for discovery. Clear field patterns for parsing. Tables for lookup. Prose only for content that genuinely requires natural language (explanations, rationale, design discussion).

**See**: `docs/research/2026-03-01-frontmatter-context-impact.md`, `.agentic/lib/PRINCIPLES.md` F3 (Token Optimization)

---

## 13. Plans Are Never Done After One Pass

**The problem**: Modern AI models produce impressively detailed implementation plans. A single Claude or Cursor planning session can generate a multi-phase plan with file lists, dependency ordering, and risk analysis in minutes. It *looks* complete. It *feels* authoritative. And in our experience, it is **always still wrong in important ways**.

**What we've seen repeatedly**: Every single plan in 53 versions of this framework — without exception — had issues that only surfaced after review:

- **Missing integration points**: The plan describes component A and component B perfectly, but doesn't wire them together. Functions are defined but never called from entry points. Gates are created but never registered in the CLI. F-0177 had 65 passing unit tests and a completely unwired state machine.
- **Contradicting the project's own rules**: The plan proposes a solution that violates existing principles or shipped specs. The AI doesn't have full context of every rule, and plans are where these gaps surface.
- **Over-engineering**: The plan adds abstractions, configurability, and future-proofing that nobody asked for. Left unchecked, a 3-file feature becomes a 15-file architecture.
- **Under-specifying edge cases**: The happy path is detailed. Error handling, concurrency, cleanup on failure — these are hand-waved or missing entirely.
- **Scope creep disguised as thoroughness**: The plan includes "while we're at it" items that seem logical but double the implementation effort.

**What works**: Treat every plan as a **first draft**, no matter how impressive it looks. The dialectical review process (insight #10) exists precisely because of this pattern. But even without formal review, the minimum discipline is:

1. **Read the plan skeptically**: Ask "what's missing?" not "does this look good?"
2. **Check wiring**: For every new function/gate/endpoint, verify the plan shows where it's called from
3. **Check against existing constraints**: Does this plan respect shipped specs? Existing principles? Current architecture?
4. **Size check**: Count the files. If it's >10 for what seemed like a simple feature, the plan has scope creep
5. **Multiple rounds**: Plan → review → revise → review again. Two rounds minimum for anything non-trivial

**The meta-lesson**: AI plans are a massive productivity multiplier — they compress hours of human design into minutes. But they're a starting point, not a finished product. The value isn't in the first plan; it's in the second or third revision after adversarial review. Building this review loop into your workflow (not as an optional step but as a structural requirement) is what separates projects that ship from projects that debug.

**See**: Insights #10 (Dialectical Review) and #11 (Revision Guidance), `FRAMEWORK_DEVELOPMENT.md` § "Plans given as user messages don't auto-save"

---

## Summary: The Pattern

These insights form a coherent pattern:

```
Tiny instruction file (50 lines)     → agent reads it all, reliably
  + Memory reinforcement             → survives context compression
  + Skills with frontmatter          → right instructions at right time
  + Scripts for deterministic ops    → cheap, reliable, portable
  + Git hooks / structural gates     → rules that can't be ignored
  + Keyword + intent triggers        → reliable workflow routing
  + Git-tracked durable artifacts    → state that survives sessions
  + Distributed enforcement          → works across all AI tools
  + LLM behavioral tests             → verify it actually works
  + Deliberate context management    → right context to right agent
  + Dialectical plan review          → opposing perspectives catch flaws
  + Revision guidance                → accept findings, prescribe your own fixes
  + LLM-optimized formats            → structure files for AI consumption
  + Plans are never done in one pass → review loop is essential, not optional
```

The meta-lesson: **structural enforcement > behavioral instructions > hope**. Anything important enough to be a rule is important enough to be enforced by code, not by documentation.

---

**Related documents**:
- `FRAMEWORK_DEVELOPMENT.md` § Lessons Learned — tactical mistakes and fixes
- `docs/INSTRUCTION_ARCHITECTURE.md` — formal three-layer architecture design
- `.agentic/lib/PRINCIPLES.md` — foundational principles (WHY)
- `CONTRIBUTIONS.md` — design insights from specific features
