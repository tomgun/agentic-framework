# Pre-Phase-0 Spike: Primitive Validation Results

> **Outcome: All three load-bearing primitives validated. Phase 0 is unblocked. Several v5 reviewer concerns dissolved.**
> **Date:** 2026-04-26
> **Effort:** ~30 minutes (vs. 1 week budgeted)
> **Sources:** Direct empirical test + canonical Claude Code documentation at `code.claude.com/docs/en/`

---

## Primitive 1: Agent tool `model` parameter — **CONFIRMED**

**Test:** Spawned an Explore subagent with `model: "haiku"` parameter and asked it to self-report its model.

**Result:** Subagent successfully launched and self-reported as `claude-haiku-4-5-20251001`. Invocation succeeded; the model parameter took effect.

**Implication for v5 plan:**
- Tier 2 heterogeneous critic invocation **works as designed**. No fallback to pre-defined `.claude/agents/critic-haiku.md` configs needed (though those remain optional for static role-defining).
- The Claude-expert reviewer's concern was based on incomplete PDF documentation. The leaked architecture paper apparently didn't enumerate the `model` field in the Agent tool input schema, but the field exists and works in the current production Claude Code.
- **Tier 2 critic dispatch is straightforward:** invoke `Agent` tool with `model: "haiku" | "sonnet" | "opus"` and an adversarial role prompt. Done.

---

## Primitive 2: Stop hook + PreToolUse semantics — **CONFIRMED, with bonus**

**Source:** `https://code.claude.com/docs/en/hooks` (canonical documentation).

**Findings:**

1. **Stop hook fires reliably once per turn, when Claude finishes responding.** Supports exit code 2 blocking and structured `{"decision": "block", "reason": "..."}` return. **Tier 2 harness-fired verification works as designed.**

2. **PreToolUse fires for the Read tool** (explicitly listed alongside Bash, Edit, Write, Glob, Grep, Agent, WebFetch, WebSearch, AskUserQuestion, ExitPlanMode, and MCP tools). **Anatomy PreToolUse:Read hook design is valid.**

3. **PostToolUse fires for all built-in tools.** This means the user's empirical observation that `on-plan-mode-exit.sh` (a PostToolUse:ExitPlanMode hook) never fired in the production session was probably a different bug — perhaps timing, hook registration, or the `--include-partial-messages` interaction — not a structural absence of PostToolUse for built-in tools. Worth a separate investigation, but **does not block the v5 architecture** since Tier 0 fires at the git layer regardless.

4. **PreToolUse supports `if` field with permission rule syntax** — e.g., `"if": "Edit(*.ts)"` matches on `file_path`. **The Tier 0 path-based deny mechanism the Claude expert flagged as unverified is in fact supported.** Restore as a primary defense layer alongside git-hook integrity checks.

5. **Hooks can return:**
   - Block actions (exit 2 or `decision: "block"`)
   - Modify input (`updatedInput` for PreToolUse, PermissionRequest)
   - Inject context (`additionalContext` for UserPromptSubmit, SessionStart, PostToolUse)
   - Allow/deny/ask (PreToolUse: `permissionDecision: "allow"|"deny"|"ask"|"defer"`)

**Hook count correction:** docs list **28 hook events**, not 27 (v5 plan number was inherited from the leaked PDF; updated source has one more).

---

## Primitive 3: Anthropic Agent Teams — **CONFIRMED EXPERIMENTAL, BUT FULLY DOCUMENTED**

**Source:** `https://code.claude.com/docs/en/agent-teams` (canonical documentation).

**Findings:**

1. **Status: experimental, disabled by default.** Activation: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `settings.json` or env var.
2. **Minimum version: Claude Code v2.1.32+**.
3. **Hooks shipping today:** `TeammateIdle`, `TaskCreated`, `TaskCompleted`. All support exit code 2 to block + send feedback. **Tier 3 design is correct.**
4. **Subagent definitions are reusable as teammate types** — `.claude/agents/critic-haiku.md` works as either a subagent or a teammate. This validates v5's design choice to reuse the same agent definition format for both Tier 2 and Tier 3.
5. **Tier 3 architecture as documented:**
   - Lead session ≠ teammate sessions, separate context windows
   - Shared task list at `~/.claude/tasks/{team-name}/` with file-locking for concurrent claim safety
   - Mailbox messaging (teammates can talk to each other directly, not just through lead)
   - Tasks have dependencies; pending+blocked tasks unclaimable until dependencies complete
6. **Documented limitations (must surface in v5 plan + user-facing docs):**
   - No session resumption with in-process teammates
   - Task status can lag (teammates sometimes fail to mark complete)
   - Shutdown can be slow
   - One team per session (no nested teams)
   - Lead is fixed for team lifetime
   - Permissions set at spawn (no per-teammate runtime mode change)
   - Split-pane mode requires tmux or iTerm2 (not VS Code terminal, Windows Terminal, Ghostty)

7. **Anthropic's own caveat (verbatim from docs, validates sibling §4.1):** *"The lead makes approval decisions autonomously. To influence the lead's judgment, give it criteria in your prompt."* — this is the same-model rubber-stamp risk the sibling doc flagged. The docs themselves recommend mitigation via explicit acceptance criteria in lead spawn prompts.

8. **Token cost is significant** (docs explicitly: "Agent teams use significantly more tokens than a single session"). Anthropic's published guidance: 3–5 teammates is the practical sweet spot.

---

## Bonus findings (not part of original spike scope)

### a. Agent Teams ↔ subagents architectural distinction

The docs clarify a distinction the v5 plan was conflating: **subagents** (Agent tool) and **agent teams** are *different mechanisms*, not just scale variants.

- Subagents: own context window, results return to caller only, no inter-subagent communication, lower token cost.
- Agent teams: own context windows, fully independent, teammates message each other directly, higher token cost.

**Implication for v5 Tier 2 vs Tier 3 boundary:**
- Tier 2 (heterogeneous critic) uses Agent tool / subagents — correct (cheap, results back to caller).
- Tier 3 (`--teams` flag, Mode 3) uses agent teams — correct (orchestrator/worker, shared tasks, mailbox).
- The two tiers naturally use Anthropic's two distinct primitives. Clean architectural fit.

### b. Subagent definition portability

Subagent definitions in `.claude/agents/*.md` work in BOTH contexts:
- As subagent (called via Agent tool)
- As teammate (called by team lead at spawn time)

The `tools` allowlist + `model` field carry over. The `skills` and `mcpServers` frontmatter fields don't apply when running as teammate (teammates load these from project + user settings). Worth noting for v5 implementation.

### c. Subscription cost anchoring

Anthropic's docs at `/en/costs#agent-team-token-costs` (referenced from agent-teams page) is the canonical source for cost guidance. v5's "7–15× tokens" claim is consistent with sibling-doc citations of Anthropic Agent Teams. For subscription users, this means ~7–15× of Pro/Max session quota burn during agent team runs — same conclusion, different framing.

### d. Worktree isolation for parallel teammates

Agent teams support concurrent operation. Documented locking behavior: "Task claiming uses file locking to prevent race conditions when multiple teammates try to claim the same task simultaneously."

**Implication:** v5 Phase 4's plan to use worktrees for parallel teammates is supported. File-locking already in place for shared task list; adding worktree isolation per teammate is layered on top.

---

## Plan revisions enabled by this spike

The Pre-Phase-0 caveats in the v5 plan can be **removed**. Specifically:

1. ~~"Agent tool `--model` parameter unverified — fallback to pre-defined configs"~~ → **Validated; use `model` parameter directly.**

2. ~~"Stop hook file I/O semantics undocumented"~~ → **Documented. Stop fires once per turn, supports exit code 2 + structured returns. Tier 2 harness-fired verification design works.**

3. ~~"PreToolUse path-based deny may not be supported"~~ → **Supported via `if` field with permission rule syntax. Restore as Tier 0 primary defense alongside hash-based hook integrity.**

4. ~~"Anthropic Agent Teams stability/timeline unverified"~~ → **Confirmed experimental (still); v2.1.32+; documented limitations; design is final-shape and stable enough for Phase 4 prototyping. Treat as experimental in production, but architecture is validated.**

5. **Update hook count from "27" to "28"** (one new hook event in current docs that wasn't in the leaked PDF).

6. **Add Anthropic's own rubber-stamp caveat to v5 docs** — verbatim quote validates sibling §4.1's heterogeneity argument.

7. **Document Tier 2 vs Tier 3 cleanly:** Tier 2 = Agent tool / subagent (cheap, summary-back); Tier 3 = Agent Teams (`--teams`, mailbox, shared tasks). They use Anthropic's two distinct primitives by design, not the same primitive at different scale.

8. **Surface Agent Teams limitations in v5 user-facing docs:**
   - No `/resume` or `/rewind` for in-process teammates
   - Task status can lag → manually nudge
   - One team per session, no nesting
   - Permissions set at spawn (no per-teammate runtime change)
   - Split-pane requires tmux/iTerm2

---

## Recommendation: proceed with Phase 0

**The pre-Phase-0 spike completed in ~30 minutes (not 1 week) with all primitives confirmed.** The reviewer-flagged risks were largely artifacts of working from incomplete leaked PDF rather than current Anthropic docs. The v5 architecture is more solid than the review round suggested.

**Next action:** begin Phase 0 (Tier 0 hardening + observability spine + Phase 0 UX additions). Estimated 4–5.5 weeks solo per engineering review's realistic forecast.

The transform-vs-greenfield decision is now informed by real data: **transform is the right call.** Greenfield was justified only as a hedge against architecture-level uncertainty; the spike removes that uncertainty.
