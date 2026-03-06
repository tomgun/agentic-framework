# Plan Review Decisions: Autonomous Workflow Mode

Date: 2026-03-06
Plan: `2026-03-06-autonomous-workflow-mode-analysis-plan.md`

## Decisions from Review

### 1. Scope: Confirmed as-is
The full scope (verify -> task -> crunch + pre-implementation pipeline) is correct. Do not reduce.

### 2. GUI: Deferred, but design for it
GUI/dashboard is a later feature. But the reason it's in the plan is to verify how we present tasks being processed — real-time tracking. The engine's state model must support this from day one even if the UI comes later.

### 3. Implementation Language: Python over Shell
Shell won't hold up for JSON parsing, structured state, subprocess management, and signal handling. Switch the engine to Python (stdlib only, zero dependencies). Existing shell scripts (`worktree.sh`, `pre-commit-check.sh`, `settings.sh`, etc.) remain as-is — Python calls them via `subprocess`.

Rationale: Python's `json`, `subprocess`, `signal`, `pathlib` are more reliable than shell equivalents (`jq` dependency, platform-specific `sed`, fragile `trap` handling).

### 4. Verification Agent: Per-batch, not per-AC
Do NOT run verification after each acceptance criterion. Instead:
- Run the **test suite** after each AC (deterministic, fast)
- Run the **verification agent once per batch** (after all ACs for a feature)
- Verification reviews: work done vs. the plan, and vs. the existing codebase
- This preserves the two-agent pattern at ~1/N the cost

### 5. Token/Cost: Friendly warnings, not hard limits
Assume the user has a subscription that handles the usage. The framework should:
- Warn friendly to check subscription/billing before starting an auto run
- Show estimated invocation count before starting
- Do NOT build hard budget caps or cost tracking in v1

### 6. Permissions: Three-tier trust model
```
Tier 1: Sandboxed (Docker/VM)
  - --dangerously-skip-permissions
  - Full autonomy, containerized safety

Tier 2: Scoped (no sandbox)
  - settings.json with explicit permissions:
    a) Web search
    b) File/script operations within repo directory only
    c) Git operations (branch, commit, push, PR creation)
  - Recommended for most users

Tier 3: Interactive (default)
  - Normal Claude approval prompts
  - Engine pauses when approval needed
  - Safest but slowest
```

Advise users toward Tier 2 (scoped settings.json) as the default recommendation. Provide a template `settings.json` that covers the common operations.

### 7. Control Mechanism: Strengthen
The control file approach needs hardening. Consider:
- Signals (`USR1`/`USR2`) for simple pause/resume/stop (race-free, immediate)
- Named pipe or file for structured commands (feedback text)
- Hybrid approach: signals for control flow, pipe/file for data
- Detail to resolve during implementation

### 8. Feature ordering
1. F-0160: Foundation (engine core, Python, state model)
2. F-0161: `ag auto verify` (test-fix loop — highest value, lowest risk)
3. F-0162: `ag auto task` (single feature implementation)
4. F-0163: `ag auto crunch` (multi-feature batch)
5. GUI/dashboard: After core modes are stable and dogfooded

## Open Questions
- Exact signal vs pipe vs file design for control mechanism
- settings.json template — what exact permissions to include
- How to handle ACs that are too large for one context window (detection + splitting)
