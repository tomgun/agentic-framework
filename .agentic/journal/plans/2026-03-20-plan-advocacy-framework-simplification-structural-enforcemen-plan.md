# Plan Advocacy: Framework Simplification & Structural Enforcement

## 1. Core Thesis Validation

**The fundamental approach is correct and well-grounded.** The plan's thesis -- that a state machine with hard artifact preconditions should replace instruction-based enforcement -- directly addresses all four diagnosed failures. Here is the evidence chain:

### Problem-to-Solution Mapping

| Diagnosed Problem | Why instructions fail | How state machine fixes it |
|---|---|---|
| Agent doesn't save plan after plan mode | PostToolUse hook output is advisory; agent ignores in long sessions (INSTRUCTION_ARCHITECTURE.md Section 5 confirms: "behavioral instructions fade over time within a session") | `ag transition` to `plan_review` requires `plan.md` to exist. No file = hard error. Agent cannot proceed. |
| Agent skips dialectical review | Agent rationalizes "plan is simple" (documented in MEMORY.md feedback_autonomous_workflow.md) | `ag transition` to `spec` requires `review.md` with gate status. The gate is a code path, not a suggestion. |
| Agent doesn't update docs | drift.sh runs at commit time -- too late; agent says "done" before checks | `ag transition` to `ready_to_ship` requires `docs_updated` precondition. Cannot reach shipping state without it. |
| Agent starts coding without spec | `ag implement` has escape hatches (`SKIP_SPEC_CHECK=1`), confirmed in pre-commit-check.sh lines 86-93 | Formal mode: `skip_transitions: []`. No bypass mechanism. Lean mode: explicit allowed skip paths are declared, not env vars. |

### Alignment with Framework's Own Principles

The plan is not proposing something alien -- it is fulfilling promises the framework already made:

- **Principle D2 (Deterministic Enforcement)**: "When principles conflict, specificity wins: Rules override Design Principles." The plan makes D2 the primary enforcement mechanism rather than a defense-in-depth backup.
- **INSTRUCTION_ARCHITECTURE.md Section 5, Principle 1**: "Never rely on memory -- if a rule must always apply, enforce it structurally." The current framework violates this for its most critical workflows (plan saving, review, docs).
- **INSTRUCTION_ARCHITECTURE.md "The Compression Problem"**: "Only structural enforcement (scripts with exit codes) survives the entire session reliably." This is the exact insight the plan operationalizes.

### Research Validation

The external research document (`2026-03-20-minimal-reliable-agentic-development.md`) provides independent confirmation from SWE-agent, ReAct, and Reflexion research that "interfaces and scaffolding matter" more than prompt engineering. The plan's state machine is precisely the kind of "agent-computer interface" that SWE-agent attributes its gains to. This is not a speculative claim -- it is the dominant finding across multiple research programs.

**Verdict**: The core thesis is sound. The framework's own documents, principles, and empirical findings all point to the same conclusion. The plan is the logical next step.

---

## 2. Strongest Aspects of the Plan

### 2.1 The Phasing Strategy is Genuinely Conservative

Phase 1 explicitly states: "Phase 1 Does NOT Remove Anything." Old `ag` commands and all 554 files remain. New engine is opt-in via `engine: v2`. This is the right call for three reasons:

1. **Reversibility**: If the new engine has unforeseen problems, the old system still works.
2. **Incremental validation**: Each phase can be tested against the old system's behavior.
3. **No big-bang migration**: Users of the framework never face a "everything changed" moment.

### 2.2 The `state_machine_af.yaml` Configuration is Well-Designed

The YAML schema elegantly captures the three orthogonal axes (states/transitions, modes, profiles) in a single declarative file. Key strengths:

- **Modes (formal/lean) are about artifact rigor**, not workflow shape. Both share the same state machine, just different `required_artifacts` and `skip_transitions`. This is simpler than having two separate workflows.
- **Profiles (hands_on/guided/autonomous) are about gate approval**, not workflow shape. Same state machine, different `gates` config. Clean separation.
- **skip_transitions in lean mode are explicitly declared**, not env-var escape hatches. You can see exactly which shortcuts lean mode allows. This is dramatically better than the current `SKIP_SPEC_CHECK=1` pattern where escape hatches are hidden in bash scripts.

### 2.3 Per-Work-Item Directories Solve Real Pain

The current framework scatters artifacts across 4+ directories:
- `spec/acceptance/F-XXXX.md` (criteria)
- `.agentic/journal/plans/*F-XXXX-plan.md` (plans, date-prefixed)
- `.agentic/journal/evidence/F-XXXX-smoke.*` (evidence)
- `.agentic/spec/FEATURES.md` (central registry entry)

The plan consolidates to `.agentic/work/F-XXXX/` with everything co-located. Benefits:
- **Session handoff**: New session reads one directory to understand everything about a feature.
- **Completeness checking**: `ls .agentic/work/F-XXXX/` immediately shows what's missing.
- **Cleanup**: Archive one directory when done.

### 2.4 The "CLI Prints Role Prompts" Pattern is Clever

Instead of relying on the agent to remember which skill to load (the current 12-skill system), the CLI prints the appropriate role prompt when a transition happens. This converts a memory problem into a stimulus-response pattern. The agent does not need to recall "I should now be in implementer mode" -- the CLI tells them.

### 2.5 Backlog Impact Assessment is Thorough

The plan correctly identifies 7 features that are absorbed, 5 that remain, 3 that become later phases, and 6+ TODOs that become moot. This shows deep familiarity with the existing backlog and prevents wasted effort on features the refactor supersedes.

---

## 3. Where the Critic Will Likely Overreach

### 3.1 "Too ambitious -- a rewrite this large will fail"

**Counter**: This is not a rewrite. It is a refactor with four phases, each independently valuable. Phase 1 adds a new engine alongside the old one. Phase 3 is the only phase that removes files, and it happens last, after the new system is proven. The plan explicitly preserves:
- Token-efficient scripts (journal.sh, status.sh, etc.)
- Pre-commit hooks (simplified to call `ag check`)
- Feature IDs
- Core Python modules (state_machine.py, gates.py, intents.py)

The plan reuses the existing 606-line `state_machine.py` and 469-line `gates.py` as its foundation. This is extension, not rewrite.

### 3.2 "Auto system can't be done in 1 week"

**Counter**: The auto system refactor (Phase 2) is scoped as "internal plumbing change." The 7 files being refactored (192KB total) are large, but the change is the same pattern repeated: replace ad-hoc state management with `TransitionOrchestrator` calls. This is a mechanical refactor, not a design challenge. The hard design work (the state machine itself) is done in Phase 1.

However, I will note that "1 week" is aggressive. See Section 4 for genuine concerns about timeline.

### 3.3 "4 role prompts can't replace 12 skills"

**Counter**: Let's examine what the 12 skills actually do:

| Skill | What it teaches | Role prompt equivalent |
|---|---|---|
| implementing-features | Plan check, spec check, code, tests, docs | implementer.md |
| writing-tests | Test writing patterns | implementer.md (testing section) |
| fixing-bugs | Write failing test first, then fix | implementer.md (bug-fix section) |
| updating-documentation | When/what to update | implementer.md (docs section) |
| planning-features | How to write plans | planner.md |
| writing-specs | How to write specs | planner.md (spec section) |
| reviewing-code | How to review adversarially | reviewer.md |
| committing-changes | Pre-commit sequence | verifier.md |
| completing-work | AG done workflow | verifier.md |
| session-start | Dashboard, context load | Absorbed by CLI (`ag status`) |
| exploring-codebase | How to navigate code | Not role-specific; general guidance in CLAUDE.md |
| researching-topics | How to research | Not needed if CLI handles workflow |

The consolidation makes sense because the current skills overlap significantly. `implementing-features` already covers most of what `writing-tests`, `fixing-bugs`, and `updating-documentation` teach separately. The 4 role prompts map to 4 workflow phases, which is the actual structure. 12 skills mapped to an arbitrary decomposition that does not match the state machine.

The key insight: **skills compensate for missing structural enforcement.** When the CLI enforces the workflow, the skills' procedural content becomes unnecessary. What remains is "how to do the work well" (quality guidance), which fits in 4 focused prompts.

### 3.4 "The ~30-line CLAUDE.md is too thin"

**Counter**: The research document explicitly finds that instruction bloat reduces adherence (citing Claude Code docs recommending concise CLAUDE.md). The framework's own INSTRUCTION_ARCHITECTURE.md validates this empirically (L-0002: compliance degrades past ~100 lines). A 30-line CLAUDE.md that says "use `ag` commands" is MORE effective than a 40-line constitution pointing to a 442-line playbook, because:

1. The agent has one thing to remember: run `ag` commands.
2. The CLI delivers context just-in-time via printed output.
3. No attention budget is wasted on workflow instructions the CLI enforces anyway.

---

## 4. Genuine Concerns I Share with the Critic

### 4.1 Timeline Estimates Are Optimistic

The plan estimates ~4 weeks total. Based on the actual codebase:
- Phase 1 involves creating `workflow.py`, `preconditions.py`, `artifacts.py`, `transitions.py`, updating `state_machine.py` (606 lines), `gates.py` (469 lines), JSON schemas, YAML config, and the `ag.sh` dispatcher. **Realistic: 1.5-2 weeks**, not 1 week.
- Phase 2 touches 192KB of auto system Python across 7 files. Even as a mechanical refactor, testing this thoroughly with the existing auto test suite takes time. **Realistic: 1.5-2 weeks**, not 1 week.
- Phase 3 (instruction consolidation) is the most variable. Writing 4 good role prompts and validating that agents actually follow them (LLM testing) is iterative. **Realistic: 1-2 weeks**, roughly as estimated.
- Phase 4 (MCP) is correctly estimated at 1-2 weeks.

**Total realistic: 5-8 weeks, not 3-5.** The plan should acknowledge this and set expectations accordingly.

### 4.2 The Plan Says "No Escape Hatches in Formal Mode" But Doesn't Address the Legitimate Use Cases

The current escape hatches exist for reasons:
- `SKIP_TESTS` on feature branches for WIP commits
- `SKIP_COMPLEXITY` for large refactors with review
- `SKIP_TDD` for established codebases with existing test suites

The plan eliminates these in formal mode. This is directionally correct (the current system leaks because escape hatches on feature branches erode discipline), but the plan should specify how WIP commits work in the new system. Does the state machine allow partial-progress commits? If I am in `implementation` state, can I commit without tests yet?

**Suggestion**: The plan needs a "WIP commit" concept -- perhaps commits within a state don't require the next state's artifacts, only transitions do. This distinction is implicit but should be explicit.

### 4.3 Risk of Losing Battle-Tested Edge Case Handling

The 37 bash command modules (plan says to replace, though actual count is 12 modules per `ls` output) and 12 skills contain accumulated edge-case handling. For example:
- `implement.sh` handles worktree creation, agent registration, backlog order enforcement
- `done.sh` handles VERSION bumping, PR creation, FEATURES.md updates
- `commit.sh` handles pre-commit sequences, journal staleness checks

The plan's `workflow.py` must absorb all this logic, not just the state transitions. The risk is that the new Python engine handles the happy path beautifully but misses 20 edge cases that the bash scripts learned over months of use.

**Suggestion**: Before Phase 3 removes anything, create an edge-case inventory from the existing bash scripts. Document every conditional branch that exists for a reason.

### 4.4 LLM Testing Gap

The plan mentions "Phase 3 Tests: Agent compliance -- New 30-line CLAUDE.md session, agent uses `ag` commands without full workflow instructions." But this is the highest-risk test, and the plan treats it as a Phase 3 activity. If the 30-line CLAUDE.md proves insufficient (agent doesn't reliably use `ag` commands), Phase 3's entire file reduction is compromised.

**Suggestion**: Run a proof-of-concept LLM test in Phase 1 -- before any files are removed. Validate that an agent with minimal instructions + CLI output actually follows the workflow.

### 4.5 The 12 Command Modules vs. 37 Discrepancy

The plan states "37 bash command modules" but the actual `commands/` directory contains 12 files. The plan may be counting other tool scripts (journal.sh, status.sh, etc.) that it explicitly says will be preserved. This discrepancy should be clarified to avoid scope confusion.

---

## 5. What the Plan Gets Right About the Framework's Future

### 5.1 `state_machine_af.yaml` is the Right Choice for Tool-Agnostic Workflows

YAML is readable by humans and parseable by every language. The research document independently converges on the same structure (`adf.yaml` with states, transitions, modes, gates, verification). The fact that the plan and the research arrived at nearly identical schemas validates the design.

Critically, YAML config means:
- Cursor, Copilot, Codex, and Gemini adapters can all read the same file
- The workflow is inspectable (humans can read it) and testable (JSON Schema validation)
- New states or transitions are config changes, not code changes

This is definitively superior to the current approach where workflow logic is distributed across `ag.sh` dispatch, 12 command modules, `state_machine.py`, `auto_orchestration.md`, and 9 checklists.

### 5.2 Per-Work-Item Directories is the Right Structural Choice

The research document recommends `work_items/FEAT-0001/` with co-located artifacts. The plan implements exactly this as `.agentic/work/F-0244/`. This is the right choice because:

1. **Atomic unit**: Everything about a feature is one directory. Move, archive, or inspect as a unit.
2. **Context loading**: New agent session reads `item.yaml` + relevant artifacts. No searching across directories.
3. **Completeness checking**: File existence IS the precondition check. No database, no parsing FEATURES.md.
4. **Git-friendly**: Each work item directory can be branched independently. Merge conflicts are localized.

The current scattered layout (spec/acceptance, journal/plans, journal/evidence, FEATURES.md) is the result of organic growth, not design. The plan corrects this.

### 5.3 MCP in Phase 4 is the Right Timing

The research document explicitly recommends: "build ADF as a CLI first (minimal), then add an optional MCP server wrapper." The plan follows this exactly. Reasons this is correct:

1. **CLI-first means the enforcement works without MCP.** MCP is an optimization, not a requirement.
2. **MCP adoption is still uneven.** Claude Code, Cursor, and VS Code support it well. Gemini and Codex support is newer. Building on CLI means no tool is excluded.
3. **MCP adds the strongest enforcement.** When an agent can ONLY interact through MCP tools (no direct file editing), skipping truly becomes impossible. But this requires Phase 1-3 to be stable first.
4. **Phase 4 can be scoped based on Phase 1-3 learnings.** If the CLI proves sufficient, MCP becomes a nice-to-have rather than a must-have.

---

## 6. Suggested Improvements (Strengthening, Not Redirecting)

### 6.1 Add a "WIP Commit" Concept to the State Machine

The plan's transitions require artifacts for state changes but doesn't address in-state commits. Add explicit guidance:

```yaml
workflow:
  # Commits within a state don't require next-state artifacts
  # Only transitions check preconditions
  in_state_commits: allowed
  commit_gate: [clean_git, journal_updated]  # Minimal commit requirements
```

### 6.2 Run a Proof-of-Concept LLM Test Before Phase 3

Create a minimal CLAUDE.md + CLI setup and test with an actual agent in Phase 1. This validates the core bet ("30 lines + CLI output is enough") before removing 475 files in Phase 3.

### 6.3 Create an Edge-Case Inventory from Existing Scripts

Before Phase 3 removes bash command modules, extract every conditional branch that handles a non-obvious case. The `implement.sh`, `done.sh`, and `commit.sh` scripts have accumulated hard-won edge case handling that must migrate to `workflow.py`.

### 6.4 Adjust Timeline Expectations

Revise to 5-8 weeks total, with Phase 1 at 1.5-2 weeks and Phase 2 at 1.5-2 weeks. Under-promising and over-delivering is better than the reverse, especially for a foundational refactor.

### 6.5 Clarify the Command Module Count

The plan says "37 bash command modules" but `commands/` has 12 files. Clarify whether the plan means to replace only the 12 command modules or also touch the 20+ tool scripts. The token-efficient scripts (journal.sh, status.sh, etc.) should remain explicitly out of scope for replacement.

### 6.6 Define the Migration Path for `item.yaml` from FEATURES.md

The plan creates per-item `item.yaml` files but does not specify how existing features in FEATURES.md are migrated. A simple `ag migrate` command that reads FEATURES.md and creates `.agentic/work/F-XXXX/item.yaml` for each entry would make the transition smooth.

---

## Summary Verdict

**This plan should be approved with the timeline and edge-case suggestions incorporated.** The core architecture is sound, well-researched, and directly addresses the framework's most persistent failures. The phasing is genuinely conservative (new alongside old, remove only after proven). The design aligns with both the framework's own principles and independent research.

The strongest single argument for this plan: **the framework's own INSTRUCTION_ARCHITECTURE.md, PRINCIPLES.md, and empirical findings (L-0002, the escape hatch pattern, the compression problem) all point to exactly this solution.** The plan is not introducing a new philosophy -- it is making the framework live up to its existing philosophy.

The Critic will find legitimate issues with timeline and edge cases. Those are refinements, not objections to the direction. The fundamental bet -- "1 config file + 1 CLI that makes skipping impossible + 4 role prompts" replacing "554 files of instructions that agents must remember" -- is the right bet.
