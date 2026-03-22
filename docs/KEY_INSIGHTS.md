# Key Insights: What Actually Works for AI Agent Control

**Purpose**: Strategic lessons from v0.1.0 through v0.65.0 (~800 commits) of framework development. Not tactical mistakes (those are in `FRAMEWORK_DEVELOPMENT.md` § Lessons Learned) — these are the **design patterns that make AI agents reliably productive**.

**Audience**: Anyone building an agentic coding workflow — whether using this framework or designing their own.

**Contributor**: These insights were discovered by Tomas through hands-on building, testing, breaking, and rebuilding across 65+ framework versions and ~800 commits. Each pattern was earned through real failures — lost plans, ignored rules, corrupted state, skipped workflows — and the stubborn insistence on understanding *why* things failed, not just fixing them.

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
| 14 | [Cross-Turn Workflows Need Artifact-Embedded Enforcement](#14-cross-turn-workflows-need-artifact-embedded-enforcement) | Instruction files lose effect at turn boundaries — embed enforcement in the artifact itself | Prevents agents from skipping multi-turn workflows |
| 15 | [Context Provenance Awareness](#15-agents-cannot-distinguish-context-provenance) | Agents can't tell if context came from the user, a prior session, or automation — default to system-provided | Prevents misattributing intent and skipping gates |
| 16 | [Retroactive Planning Defeats Forward-Looking Gates](#16-retroactive-planning-defeats-forward-looking-gates) | Gates designed for plan→implement flow become dead code when agent implements first, plans after | Gates must check actual state, not assume ordering |
| 17 | [CLI State Machines — The Endgame for Workflow Enforcement](#17-cli-state-machines--the-endgame-for-workflow-enforcement) | LLMs are probabilistic; no amount of instruction files makes them deterministic. CLI enforcement does. | ~3K lines replaces ~34K — 90% reduction, 100% enforcement |
| 18 | [End-to-End Enforcement Wiring](#18-end-to-end-enforcement-wiring--existence--activation) | Enforcement code that exists but isn't wired into the activation path is theater | Zero — the enforcement literally doesn't fire |
| 19 | [Test Projects Are the Only Honest System Feedback](#19-test-projects-are-the-only-honest-system-feedback) | Synthetic tests verify components; test projects verify the system under real pressure | N/A — validation methodology |
| 20 | [Context Window Decay in Autonomous Sessions](#20-context-window-decay-in-autonomous-sessions) | Context fills monotonically, instructions degrade, agents can't self-clear — architect around it | 5–10K per subagent vs degraded 100K+ main session |

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

## 14. Cross-Turn Workflows Need Artifact-Embedded Enforcement

**The problem**: Multi-step workflows that span turn boundaries (plan mode exit → user's next message → skill re-matching) are the hardest thing to enforce with instruction files alone. Each turn boundary is a potential discontinuity — the agent may not have the same instructions active when Phase N+1 starts as when Phase N ended. The plan-review gate was the hardest behavioral fix in the framework: despite the rule existing in 9+ instruction files, the agent would exit plan mode and immediately start coding, completely skipping the mandatory dialectical review.

**What failed**: Adding the rule to more instruction files (skills, memory-seed, checklists, CLAUDE.md, agent guidelines — 9+ files total), adding anti-pattern warnings, and relying on a script gate that had a sequencing bug. Each approach was insufficient alone. The detailed case study with all 4 failed attempts and the specific fixes is in `FRAMEWORK_DEVELOPMENT.md` § "LLM agents lose continuity at turn boundaries."

**What finally worked (three changes together — no single one was sufficient):**

1. **Fix the plumbing first.** A sequencing bug in the script gate meant it checked for the plan file before auto-saving it from the session-scoped directory. Fix the infrastructure before adding more signs — no amount of instruction text can compensate for a structurally broken gate.
2. **Embed enforcement in the artifact.** Added mandatory next-steps directly into the plan output itself (status: DRAFT, 4 steps to follow). The artifact survives turn boundaries because it's the work product, not guidance about the work product.
3. **Name the rationalizations.** Listed the 6 specific excuses the agent invents to skip review ("plan mode exit = approval", "simple plan, review unnecessary", etc.) as explicitly wrong in CLAUDE.md. Named rationalizations are harder to use than unnamed ones.

**The meta-lesson**: For workflows that span turn boundaries, enforcement must live in three layers simultaneously: (a) a working script gate (structural — cannot be bypassed), (b) instructions embedded in the work artifact itself (survives turn boundaries), and (c) named rationalization rebuttals (makes self-deception harder). Instruction files alone — no matter how many — are insufficient because they exist outside the artifact and may not be active when the next turn begins. When the same textual instruction fails 3+ times, the fix is architectural, not editorial.

**See**: `FRAMEWORK_DEVELOPMENT.md` § "LLM agents lose continuity at turn boundaries" (full case study), `docs/INSTRUCTION_ARCHITECTURE.md` §5 (principle 8)

---

## 15. Agents Cannot Distinguish Context Provenance

**The problem**: LLM agents see all context in their conversation as a flat stream — they cannot reliably distinguish between (a) what the user explicitly typed in this session, (b) context carried over from a prior agent in the same session, and (c) output from automated tools (dashboard, system messages). This leads to misattribution of actions: an agent in a new session may claim "the user explicitly said X and pasted the plan" when actually the plan was created by a prior agent in plan mode, the user accepted it, and the prior agent failed to save it durably or run dialectical review — then the new session inherited that context.

**Observed case (F-0222)**: A plan was created in plan mode, reviewed in plan mode, and accepted by the user. The agent then skipped saving the plan durably and skipped dialectical review, jumping straight to implementation. When a new session started, the new agent saw the plan in context and claimed "the user explicitly pasted the plan" — fabricating a narrative about who did what rather than recognizing the plan came from a prior agent session's unsaved work.

**Why it matters**: Misattribution affects workflow gates and trust. If the agent invents a false narrative about what the user did, it may use that narrative to justify skipping gates (e.g., "user provided it, so it's reviewed"). It also erodes user trust — the user knows they were AFK and the agent is confidently wrong about what happened.

**Mitigations**:

1. **Don't fabricate provenance narratives.** If you don't know exactly how context arrived, don't invent a story. Say what you observe ("a plan exists in context") without asserting who put it there or why.
2. **Default to system-provided.** When unsure who initiated something, treat it as system-provided context — not user action. This is the safe default: it triggers review gates rather than skipping them.
3. **Don't infer intent from presence.** The existence of a plan in context doesn't mean the user wants to implement it. The existence of a feature ID doesn't mean the user is working on it. Context presence ≠ user intent.

**Relationship to §14**: Cross-turn enforcement (§14) addresses instructions losing effect across turns — which is the root cause of the unsaved plan in the observed case. This insight addresses the *compounding* failure: when a new agent inherits the consequences of a §14 failure and then fabricates a false explanation for how the context arrived, making the situation worse.

**See**: `FRAMEWORK_DEVELOPMENT.md` § "Agents misattribute actions to the user"

---

## 16. Retroactive Planning Defeats Forward-Looking Gates

**The problem**: Workflow gates are designed for a forward flow: plan → review → approve → implement. But agents sometimes do things out of order — implement first, then go back to plan retroactively (often after being caught skipping the planning step). When this happens, all forward-looking gates become dead code:

- **POST-PLAN-MODE block** (§14's artifact-embedded enforcement): The block says "Do NOT code, read implementation files, or explore." But the code is already written. The agent has no motivation to append instructions about what to do "next" — "next" is already done. So it skips Step 4.5 of the planning skill entirely.
- **`ag implement` gate**: Checks for an approved plan before proceeding. But the agent never runs `ag implement` after retroactive planning — implementation already happened. The gate exists but is never reached.
- **Dialectical review**: Supposed to catch flaws before implementation. When planning is retroactive, flaws are already in the code. The review becomes academic — the agent treats it as optional documentation rather than a blocking gate.

**Observed case (F-0222)**: Agent implemented without a plan. User caught it and directed the agent to plan retroactively. Agent entered plan mode, created the plan, user accepted it. Agent exited plan mode but skipped: (a) appending the POST-PLAN-MODE block (Step 4.5), (b) saving the plan durably, (c) running dialectical review. All three are forward-looking gates that assume implementation hasn't happened yet.

**Why agents do this**: When the agent has already implemented, the planning workflow feels like a formality. Every instruction that says "before you implement" or "do NOT code" is irrelevant — the code exists. The agent rationally (from its perspective) skips steps that prevent an action already taken.

**Systematic detection**: The feature's state in FEATURES.md is observable. `ag plan` could check: if the feature is already at `implementing` or later, this is retroactive planning. Possible responses:

1. **Warn explicitly**: "⚠ Feature is at `implementing` — this is retroactive planning. All review gates still apply."
2. **Reframe the POST-PLAN-MODE block**: Instead of "Do NOT code", say "Code exists but plan is NOT approved. Save → dialectical review → approval required before continuing."
3. **Make `ag implement` re-check**: Even if the feature is already `implementing`, `ag implement` could verify an approved plan exists and block if not — catching the retroactive case.
4. **State machine gate**: Add a transition gate on `implementing` that requires an approved plan file. If the agent implemented without planning, the next state transition (`ag done`) would catch it.

**The meta-lesson**: Forward-looking gates only work when the workflow runs in order. When agents can execute steps out of order (and they will), gates must check *actual state* (does an approved plan exist?), not *assumed ordering* (the agent must be about to implement). State-based checks are order-independent; workflow-position checks are fragile.

**Relationship to §4 and §14**: Structural gates (§4) work because they check concrete conditions (`exit 1` if file missing). Artifact-embedded enforcement (§14) works because it survives turn boundaries. But both assume forward flow. This insight says: make gate conditions state-based ("approved plan exists") rather than position-based ("you're about to implement"), so they work regardless of execution order.

**See**: `FRAMEWORK_DEVELOPMENT.md` § "Retroactive planning defeats forward-looking gates"

---

## 17. CLI State Machines — The Endgame for Workflow Enforcement

**The problem**: Insights #1–#16 document an escalating arms race: agents skip behavioral rules → add more instruction files → agents still skip → add structural gates → agents route around them → add artifact-embedded enforcement → agents skip the artifacts. By v0.65.0, the framework had accumulated ~130 instruction files (~34K lines) telling agents WHAT to do. Skills, checklists, workflow docs, quality standards, subagent definitions, memory-seed — all attempting to make probabilistic LLMs follow deterministic processes. It wasn't working reliably. The same agent following the same instructions would sometimes skip plan review, sometimes forget doc updates, sometimes commit without quality checks. Not because the instructions were bad — because LLMs are fundamentally probabilistic. They can decide to skip steps regardless of how many files tell them not to.

**The insight**: Stop trying to make instructions detailed enough that LLMs follow them. Instead, make the CLI enforce the workflow so LLMs *cannot* skip steps. A state machine with artifact-based preconditions turns workflow compliance from a probability into a certainty.

**How it works**: A single YAML file (`state_machine_af.yaml`) defines 10 states, valid transitions, required artifacts, and gate reviewers. The CLI (`ag start`, `ag transition`, `ag check`) is the only way to advance a feature through the workflow. Want to move from `planning` to `plan_review`? The CLI checks that `plan.md` exists. Want to move from `implementation` to `verification`? The CLI checks that tests exist. No instruction file needed — the transition simply fails if preconditions aren't met.

**Why this is fundamentally different from all previous approaches**:
- **Instructions** (insights #1, #5): Tell agents what to do → agents may or may not comply
- **Scripts** (insight #3): Replace read-modify-write → deterministic for data operations, but agents still have to *call* the scripts
- **Git hooks** (insight #4): Block bad commits → enforcement at commit time, but agents can do work in the wrong order before committing
- **Artifact embedding** (insight #14): Embed next steps in artifacts → survives turn boundaries, but agents can ignore the embedded instructions
- **CLI state machine** (this insight): Agents cannot advance the workflow without meeting preconditions → enforcement at every state transition, not just commit time

The CLI doesn't tell agents what to do — it tells them what they *can't* do. This is a fundamental shift from opt-in compliance to opt-out impossibility.

**The evidence**: 130 instruction files (34K lines) replaced by 7 role prompts (347 lines) + 1 conventions file (78 lines) + CLI enforcement. The role prompts provide quality guidance (what makes a *good* plan, not the process of creating one). The CLI handles process enforcement. Clear separation of concerns: LLMs do what they're good at (judgment, creativity, quality); deterministic code does what it's good at (process, sequencing, validation).

**The deeper lesson**: The entire history of insights #1–#16 is a journey toward this realization. Each insight added a layer of enforcement to compensate for the previous layer's gaps. The state machine doesn't replace those insights — it provides the backbone they were all approximating. Skills (#2) become thin stubs that route to CLI commands. Scripts (#3) still handle state file updates. Gates (#4) still enforce commit-time checks. But the workflow itself — the sequence of plan → review → implement → verify → ship — is no longer a suggestion in an instruction file. It's a state machine that the agent navigates, one validated transition at a time.

**Status**: v2 engine shipped in Phases 1-3 (PRs #177-#182), Phase 4 (tool adapters + MCP) remaining. Early results suggest the approach works — agents follow the workflow because they have no alternative. Comprehensive empirical comparison against v1 instruction-based workflows is planned (QA Observatory, F-0242) to measure the quality and reliability differences at scale.

**See**: `.agentic/state_machine_af.yaml`, `.agentic/lib/auto/v2/`, `.agentic/prompts/`, `CONTRIBUTIONS.md` § "v2 Workflow Engine"

---

## 18. End-to-End Enforcement Wiring — Existence ≠ Activation

**The problem**: You write the enforcement code. Unit tests verify the logic works. You ship. But the enforcement never fires in a real project. The code exists, the tests pass, and the system is completely unprotected.

**What happened**: `gate_pretool` (`gate.py:484-523`) had correct Write/Edit blocking logic for formal modes — tested, working, shipped. Hook scripts at `.agentic/hooks/claude/*.sh` existed and were copied to projects during init. But `.claude/settings.json` — where Claude Code reads hook registrations — was never created by the scaffold or init process. The hook scripts existed on disk. The gate logic existed in Python. The registration that connects them was missing. Additionally, Claude Code requires a session restart to pick up newly registered hooks — so even if registration were added mid-session, the hooks wouldn't activate until the agent restarts. Two compounding wiring failures, either of which alone would have silenced the entire enforcement layer.

**The result**: The Street Fury test project (autonomous_formal + git_mode=deferred) ran a full multi-feature development session — 1,925 LOC across 15 features — with zero enforcement. Not because enforcement was weak, but because it was disconnected.

**The insight**: An enforcement chain has multiple links: code → configuration → registration → activation → execution → denial. Component tests verify individual links ("does `gate_pretool` return deny?"). They don't verify the chain is connected ("does writing to a source file in a fresh project actually get blocked?"). A break at *any* link — missing registration, missing restart, missing config file — makes all downstream links irrelevant.

**What works**: Integration tests that exercise the full enforcement path end-to-end. Not "does gate.py work?" but "initialize a fresh project, start a Claude session, attempt a Write to a source file without an active work item — does it get denied?" These are harder to write but they're the only tests that catch wiring gaps.

**The corollary**: When enforcement fails in production, check wiring before checking logic. The instinct is to debug the gate code ("is the condition wrong?"). In both test project failures, the gate code was correct — the activation path was broken. `is_installed() && is_registered() && is_activated()` — all three must be true, and only the first was being tested.

**Evidence**: F-0300 (Street Fury evaluation). `setup-agent.sh` created `.claude/hooks.json` but scaffold/init never created `.claude/settings.json` with hook entries. `init.py:310-311` documents the restart requirement. Combined: hooks existed, were unregistered, and even if registered mid-session would have been inert until restart.

**See**: `docs/INSTRUCTION_ARCHITECTURE.md` §2 (Defense-in-Depth), F-0300 plan (R0: Hook Installation)

---

## 19. Test Projects Are the Only Honest System Feedback

**The problem**: Unit tests pass. Framework validation passes. LLM behavioral tests pass. The framework still fails catastrophically in real use. How?

**Why synthetic tests miss it**: Component tests verify individual mechanisms in isolation. They test "does this script check for X?" and "does this gate block Y?" But they can't test "when an agent with 15 features to build and a clear task-completion goal operates under a specific configuration combination, does the framework actually constrain behavior?" The failure modes that matter emerge from the *interaction* of components under real conditions — configuration combinations, workflow sequencing, agent behavioral patterns under task pressure.

**What test projects revealed that synthetic tests didn't**:

1. **Configuration matrix gaps**: The Street Fury project combined `autonomous_formal + git_mode=deferred + batch work`. Each setting worked individually. The combination produced complete workflow bypass — `ag auto` hard-gated on active git, hooks were unregistered, and no trigger caught "churn all tasks." No unit test exercises configuration combinations.

2. **Init determines everything downstream**: The Algebra Rush project created FEATURES.md in table format instead of heading format. `ag backlog add` couldn't parse it. The agent had to rewrite it manually. One wrong format at init cascaded into workflow failures hours later. Init is the highest-leverage moment — and the hardest to test without actually initializing a real project.

3. **Agents under task pressure ≠ agents in test prompts**: LLM behavioral tests ask "what would you do if the user says X?" The agent gives the correct answer. But in the Street Fury session, the agent had a clear goal (build a game), 15 features to implement, and a configuration that made the "correct" path (ag auto) unavailable. It found the path of least resistance — direct Write/Edit calls — and never self-corrected. Task pressure + blocked correct path + available bypass = certain bypass. No behavioral test captures this dynamic.

4. **Agents are water, not soldiers**: They flow toward task completion along the path of least resistance. If there's an unblocked path that skips your workflow, they'll take it. Not maliciously — they're optimizing for the goal the user gave them. Once the Street Fury agent started direct-writing, it continued for all 15 features without pausing to question the approach. Momentum compounds. Advisory warnings ("you should use ag auto") are noise to an agent with momentum — only hard denials (tool-call rejection) create course correction.

**What works**: Periodically spin up test projects with different profile/git/workflow combinations and run real multi-feature development sessions. Vary the configurations systematically — especially the edge combinations nobody uses in daily development. Treat test project failures as framework bugs, not user errors.

**The testing hierarchy** (each level catches things previous levels miss):

1. **Unit tests**: Verify component logic (fast, cheap, narrow)
2. **Framework validation** (`validate_framework.sh`): Verify structural invariants (fast, broader)
3. **LLM behavioral tests** (`tests/llm/`): Verify instruction compliance in isolation (slower, behavioral)
4. **Simulation testing** (F-0242, `PhaseChecker` + JSONL analysis): Parse execution logs from real sessions, detect violation patterns (code_before_review, skipped_planning, stopped_after_plan_exit) against scenario definitions. Bridges the gap between isolated tests and full test projects.
5. **Autonomous verify + self-heal** (F-0215, `ag auto verify-framework`): Spawn agents to build example projects from scratch using `ag` commands, verifying the full lifecycle end-to-end. When the agent hits a framework bug, the system classifies the failure (framework_bug vs agent_error vs external), spawns a fix agent in a verification worktree, validates the fix, and restarts. Accumulated fixes delivered as a single PR.
6. **Manual test projects**: Spin up real projects with specific configuration combinations (profile × git_mode × workflow) and run multi-feature sessions. The most expensive level but the only one that captures emergent behavior under real task pressure and configuration edge cases.

Most framework development stops at level 2 or 3. Levels 4–5 automate what level 6 reveals. Level 6 is still irreplaceable for discovering *new* failure modes — the Street Fury session exposed gaps that no existing simulation scenario or verify-framework definition would have caught, because the failure modes (unregistered hooks + deferred git + batch work) weren't in any scenario definition yet.

**Evidence**: Street Fury (v0.69.0, autonomous_formal + deferred git) — 15 features, 1,925 LOC, zero plans, zero state transitions, zero verification. All synthetic tests passing. Algebra Rush (autonomous_formal + active git) — init format issues cascading into workflow failures.

**See**: F-0300 plan, `.agentic/journal/plans/2026-03-21-algebra-rush-onboarding-analysis.md`

---

## 20. Context Window Decay in Autonomous Sessions

**The problem**: LLM context windows fill monotonically during a conversation. Every tool call, every file read, every response adds tokens. The agent cannot clear its own context — `/clear` is a user action, not an agent capability. As context fills, the system performs **automatic compression**: older messages are summarized to make room. This compression is lossy. Instructions, skills loaded mid-session, earlier design decisions, and nuanced rules get compressed into summaries that lose fidelity. The agent doesn't know what was lost. This is **context rot** — a gradual degradation of the agent's ability to follow its own rules.

**Why autonomous sessions are especially vulnerable**: In interactive mode, humans naturally create context breaks (switching tasks, `/clear`, new sessions). In autonomous mode (`ag auto task`, `ag auto epic`, `ag auto crunch`), the session can run for extended periods without human intervention. A long autonomous session accumulates context from dozens of file reads, tool calls, test runs, and commits. By the end, the constitutional rules from CLAUDE.md and the workflow instructions from skills may have been compressed into vague summaries — or compressed away entirely.

**What compression loses and what survives**:

| Context element | Loaded when | Survives compression? |
|---|---|---|
| System prompt (CLAUDE.md, memory) | Session start | YES — system prompt is never compressed |
| Skill instructions | Mid-session (on trigger) | NO — compressed like any message |
| File contents from Read | Mid-session | NO — early reads compressed first |
| Tool call results | Mid-session | NO — older results summarized |
| Agent's own reasoning | Mid-session | NO — loses detail progressively |
| State files on disk | Always available | YES — can be re-read |
| Git-tracked artifacts | Always available | YES — durable by design |

The critical asymmetry: **instructions loaded at session start (system prompt) survive; instructions loaded mid-session (skills, playbooks, file reads) do not**. This is why the framework's Constitution layer (CLAUDE.md, ~50 lines) is kept small and front-loaded — it's the only instruction delivery mechanism that reliably survives the entire session.

**The framework's architectural mitigations**:

1. **Fresh subagents for each unit of work** (`ag auto task`). Each acceptance criterion gets its own Claude instance with a clean context window. The subagent receives exactly the context it needs via `context-for-role.sh` (5–10K focused tokens), does one job, and returns. Context rot is bounded to the scope of a single AC, not the entire feature.

2. **External state files as persistent memory**. JOURNAL.md, STATUS.md, AGENTS.json, `item.yaml`, `verification.json` — these persist on disk, outside the context window. When a fresh subagent spins up, it reads current state from files, not from conversation history. The files ARE the memory; the context window is just the working scratchpad.

3. **Dashboard as session rehydration**. `dashboard.sh` at session start re-derives the full project state from files. A brand new conversation can pick up where the previous one left off without needing the old context. This makes `/clear` + new session a zero-cost recovery mechanism for humans.

4. **Just-in-time playbook loading** (Skills + role prompts). Instructions aren't all loaded upfront — they're loaded when triggered. This keeps the context leaner for longer, delaying the onset of compression. A session that loads 2 skills uses ~4K of playbook tokens; loading all 13 would use ~26K.

5. **Memory system as redundant reinforcement**. Persistent memory (`MEMORY.md`) is loaded at session start as part of the system prompt. Even if skill instructions from mid-session are compressed away, the memory-seed patterns (trigger words, workflow rules, anti-patterns) remain in the system prompt. Memory reinforces what compression erodes.

6. **CLI state machine as compression-proof enforcement**. The v2 workflow engine (insight #17) enforces workflow transitions via CLI exit codes, not instructions in the context window. It doesn't matter if the agent's context has degraded — `ag transition` either succeeds or fails based on artifact preconditions checked by Python, not by the LLM. Structural enforcement is immune to context rot.

**What the framework CANNOT do**:

- **Agents cannot self-clear**. There is no tool to reset the context window. The agent cannot invoke `/clear`.
- **Agents cannot detect their own degradation**. An agent with a compressed context doesn't know what was compressed. It may confidently follow a workflow it's partially forgotten.
- **Automatic compression is not selective**. The system compresses older messages uniformly — it can't preserve "important" skill instructions while compressing "unimportant" file reads.
- **Single long conversations without subagents will degrade**. If you avoid `ag auto` and manually drive a 50-message implementation session, context will rot. The framework can't prevent this — it can only make the consequences manageable by keeping state on disk.

**Practical guidance for autonomous sessions**:

| Strategy | Why it works |
|---|---|
| Use `ag auto epic` / `ag auto crunch`, not manual loops | Each task gets a fresh subagent — context rot is bounded per task |
| Keep individual tasks small (5–10 files) | Shorter context per task → less compression → better rule compliance |
| Journal between tasks | External state survives context loss — fresh subagents read the journal |
| Human checkpoints at natural breaks | `/clear` + new session resets context; `dashboard.sh` rehydrates state |
| Prefer 3 focused sessions over 1 marathon | Fresh context windows > degraded long sessions |
| Trust structural enforcement over behavioral | CLI gates work at token 1 and token 100K identically |

**The meta-lesson**: Context windows are a depletable resource, not an infinite buffer. The framework can't prevent depletion, but it's architecturally designed so that each unit of work is short enough that depletion doesn't matter. External state files + fresh subagents + structural enforcement = a system that stays reliable even as individual context windows degrade. The agent's context rots; the project's state doesn't.

**Authoritative design reference**: `docs/INSTRUCTION_ARCHITECTURE.md` §2 (Context Window Decay in Autonomous Sessions) — contains the full architectural analysis including the survival table, mitigation details, design implications, and relationship to the three-layer architecture.

**See also**: Insight #9 (Deliberate Context Management), Insight #17 (CLI State Machines), `context-for-role.sh`, `.agentic/lib/auto/`

---

## 21. Fail-Open Error Handling Defeats Blocking Enforcement

**The problem**: An enforcement gate can be correctly coded and still be inert if the shell wrapper that invokes it treats "gate crashed" the same as "gate allowed." A Python error, import failure, or timeout silently converts a blocking gate into a permission.

**How it plays out**: A PreToolUse hook calls a Python gate that returns exit 2 for "deny." The shell only checks for exit 2 — when the gate errors with exit 1, the shell falls through to `exit 0` (allow). In a test project under the strictest enforcement mode (`state_enforcement: blocking`), an agent built 10 features simultaneously with zero gates firing.

**Why LLM agents are especially vulnerable**: When an agent expects resistance and gets silence, it interprets absence of friction as permission. One unblocked Write call triggers sunk-cost escalation — 15 more files follow in minutes. Silence is permission.

**The fix pattern**: Fail-closed when enforcement is blocking. Check the enforcement level with a mechanism that doesn't share the gate's failure mode (e.g., `grep` on a config file instead of another Python call).

**Design principles**:
1. **Enforcement chains must fail-closed under blocking mode.** Fail-open is fine for casual projects; it's catastrophic for strict enforcement.
2. **Test the error path, not just the happy path.** Gate logic was tested; the shell's handling of a gate that *can't run* was not.
3. **Defense-in-depth layers must be truly independent.** If three layers all depend on Python, one Python failure disables all three.
4. **Regex-based intent detection has a ceiling.** Lexical matching ("build everything") misses semantic equivalents ("work autonomously and come back with the working game"). Structural state checks are the backstop.

**See also**: Insight #18 (End-to-End Enforcement Wiring), Insight #19 (Test Projects). Full analysis: `FRAMEWORK_DEVELOPMENT.md` § "Fail-open error handling is incompatible with blocking enforcement"

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
  + Artifact-embedded enforcement    → cross-turn workflows survive boundaries
  + Context provenance awareness     → don't misattribute automated context to users
  + State-based gates over position  → work regardless of execution order
  + CLI state machine enforcement    → workflow compliance as certainty, not probability
  + End-to-end enforcement wiring   → existence ≠ activation; test the full chain
  + Test projects as system feedback → synthetic tests verify components, test projects verify truth
  + Context window decay           → depletable resource; architect around it with subagents + external state
  + Fail-closed error handling     → enforcement chains must deny on error, not silently allow
```

The meta-lesson: **structural enforcement > behavioral instructions > hope**. Anything important enough to be a rule is important enough to be enforced by code, not by documentation. And the meta-meta-lesson from #18–#19: **you don't know if your enforcement works until you test the full system under real conditions**. And from #21: **you don't know if your enforcement survives failure until you test the error path**.

---

**Related documents**:
- `FRAMEWORK_DEVELOPMENT.md` § Lessons Learned — tactical mistakes and fixes
- `docs/INSTRUCTION_ARCHITECTURE.md` — formal three-layer architecture design
- `.agentic/lib/PRINCIPLES.md` — foundational principles (WHY)
- `CONTRIBUTIONS.md` — design insights from specific features
