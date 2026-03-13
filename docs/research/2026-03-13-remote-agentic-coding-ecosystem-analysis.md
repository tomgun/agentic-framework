# Article Analysis: "Run Claude Code From Your iPhone" — Insights for Agentic Framework

**Date**: 2026-03-13
**Sources**:
- [Pete Sena — How to Run Claude Code From Your iPhone](https://petesena.medium.com/how-to-run-claude-code-from-your-iphone-using-tailscale-termius-and-tmux-2e16d0e5f68b)
- [Kareem F — On Agentic Coding From Anywhere](https://kareemf.com/on-agentic-coding-from-anywhere)
- [Andy Nu — Multi-agent Claude Code with tmux](https://gist.github.com/andynu/13e362f7a5e69a9f083e7bca9f83f60a)

---

## Key Insights & Framework Relevance

### 1. "Context is the expensive part" — VALIDATED by our architecture

**Article thesis**: Agentic coding makes *output* cheap; *context* is expensive. So build workflows that protect context.

**Our framework already does this** — and goes further:
- Three-layer architecture (Constitution > Playbooks > State) is exactly a context-protection system
- CONTEXT_PACK.md, STACK.md, STATUS.md = durable context that survives session boundaries
- `ag sync` rebuilds context on reconnect
- AGENTS.json checkpoints preserve per-agent progress
- Journal entries capture outcomes for future sessions

**No action needed** — this validates our design philosophy. Worth noting in marketing/docs.

### 2. Structured Pipeline: Idea > Spec > Plan > Approval > Build > PR > Ship

**Article**: Sena built this pipeline using custom slash commands and hooks.

**Our framework has a more rigorous version**:
- `ag kickoff "vision"` > OVERVIEW, FEATURES, AC stubs, BACKLOG (his "Idea > Spec")
- `ag plan F-XXXX` > dialectical review > APPROVED plan (his "Plan > Approval")
- `ag implement F-XXXX` > worktree + WIP tracking (his "Build")
- `ag commit` > pre-commit gates > PR (his "PR")
- `ag done` > version bump, cleanup (his "Ship")

**Our pipeline is more formalized** with spec-first enforcement, acceptance criteria, state machine transitions, and review gates. His is lighter-weight (discovery-profile-like).

**Insight**: Users want the *light* version too. Our `discovery` profile should be well-documented as the "Sena-style" rapid pipeline. People arriving from articles like this would expect something approachable.

### 3. Remote Session Persistence via tmux — WE SOLVE THIS DIFFERENTLY

**Article pattern**: tmux keeps Claude Code alive; phone SSH-attaches to running session.

**Our approach**: Worktrees + AGENTS.json + coordination server. Each agent gets isolated context, and state files (not tmux sessions) provide persistence.

**Key difference**: Their pattern is "one human reconnecting to one session." Ours is "multiple agents coordinated via shared state." Both are valid for different scales.

**Gap identified**: We don't have explicit guidance for the "solo developer, reconnecting from phone" use case. Our `ag sync` does context rebuild, but the *infrastructure setup* (how to keep Claude Code running and reconnect) is out-of-scope for the framework — it's an environment concern.

**No framework change needed**, but a doc/guide could help: "Running agentic-framework remotely" showing tmux + tailscale as the environment layer under our workflow layer.

### 4. Native Claude Remote Control

Claude will support native remote controlling soon (already in test).

**Impact on our framework**:
- Our coordination server (F-0185) becomes **more valuable, not less** — it's the orchestration layer *above* whatever transport Claude provides
- Native remote control replaces the tmux+tailscale hack for session access, but doesn't replace structured workflow (specs, plans, state machine, review gates)
- Our `ag coord` HTTP API is already positioned as the "control plane" — native Claude remote control would be a new *transport* that could call into it

**Opportunity**: When Claude's native remote API ships, we could add a thin adapter that maps their protocol to our coordination server's JSON-RPC. This would make our framework the structured workflow layer on top of Claude's native remote capabilities.

**Action**: Watch for Claude's remote control API. No framework change now — our architecture is already positioned correctly.

### 5. Multi-Agent via tmux (Andy Nu's Pattern) — WE'RE AHEAD

**Community pattern**: Launch parallel Claude Code sessions in separate tmux panes, each in a git worktree. Manual coordination — "isolation prevents conflicts."

**Our framework**: Worktrees + AGENTS.json + collision guards + coordination server + autonomous scheduler. We have *actual* coordination, not just isolation.

**Validation**: The community is reinventing (poorly) what we've already built. Our worktree-by-default + AGENTS.json registry is the mature version of what people are hacking together with tmux scripts.

### 6. Preview Deployments as Verification

**Article**: Sena uses Vercel preview URLs to review on phone — real software, not just diffs.

**Our framework**: `ag auto verify` runs tiered tests (unit > integration > e2e), but doesn't generate preview URLs.

**Potential enhancement**: An `ag preview` command or hook that triggers a preview deployment could close the loop for web projects. This is stack-specific (Vercel, Netlify, etc.) so it would be a quality profile extension, not core.

**Action**: Added as TODO T-0064.

### 7. "Low Activation Energy" (Kareem's Insight)

**Article**: The setup succeeds because it reduces friction to near-zero. You can start coding from any device without setup overhead.

**Our framework**: `ag start` + `ag sync` aim for this but require a terminal with Claude Code already running. The framework's activation energy is higher than "open phone, attach to tmux."

**Insight**: For the "check on your agents from your phone" use case, a lightweight status dashboard (read-only) would be valuable. Our `dashboard.sh` output is already structured — exposing it via the coordination server's HTTP API would be trivial.

**Potential enhancement**: Add a `GET /dashboard` endpoint to coord_server.py that returns dashboard.sh output as JSON or formatted text. This would let any HTTP client (phone browser, curl) check status without a full Claude Code session.

**Action**: Added as TODO T-0063.

---

## Summary

| Insight | Status | Action |
|---------|--------|--------|
| Context protection philosophy | Validated | None — mention in docs |
| Structured pipeline | We're more rigorous | Ensure `discovery` profile is well-documented (T-0065) |
| tmux session persistence | Different approach (better for multi-agent) | Optional doc/guide for solo remote setup |
| Native Claude remote control | Coming — complementary to our coord server | Watch & plan adapter when API ships |
| Multi-agent tmux hacks | We're significantly ahead | None — validation |
| Preview deployments | We don't do this | TODO T-0064: `ag preview` (low priority) |
| Low activation energy / mobile dashboard | Gap | TODO T-0063: HTTP dashboard endpoint on coord server |

## TODOs Created

- **T-0063**: HTTP dashboard endpoint on coord server
- **T-0064**: ag preview command (stack-specific preview deployments)
- **T-0065**: Discovery profile documentation
