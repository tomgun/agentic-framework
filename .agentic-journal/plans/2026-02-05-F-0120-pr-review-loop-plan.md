# PR Review: #22 - Plan-Review Loop (F-0120)

## Summary

This PR adds iterative planning with critical review before implementation - a two-agent loop (planner + reviewer) that catches issues before code is written. Overall, this is a well-designed feature with good documentation.

**Stats**: +1155 / -5 lines, 16 files changed, 4 commits

---

## Strengths

1. **Solid conceptual design** - Two-perspective approach (solution-optimizer vs problem-finder) is sound
2. **Comprehensive documentation** - `plan_review_loop.md` is thorough with clear instructions for both agents
3. **Good anti-pattern coverage** - Explicitly warns against rubber-stamping, bike-shedding, perfectionism
4. **Multi-platform support** - Both Claude Code and Cursor agents defined
5. **Configurable** - Max iterations, enable/disable, auto_for options in STACK.md
6. **Escalation path** - Clear human intervention when max iterations hit or ESCALATE verdict

---

## Issues Found

### IMPORTANT

1. **Workflow doc shows unimplemented option** (`plan_review_loop.md:183`)
   - Doc shows `ag plan F-XXXX --review 1` but only `--no-review` is implemented in `ag.sh`
   - Either implement the option or remove from docs

2. **Config format inconsistency**
   - STACK.template.md uses flat keys: `plan_review_enabled: yes`
   - Workflow doc shows nested YAML: `plan_review:\n  enabled: true`
   - Should be consistent

3. **2 acceptance criteria incomplete** (per `F-0120.md`):
   - AC-6: "If no approved plan, runs plan-review loop before implementation" - only shows warning
   - AC-8: "Orchestrator can coordinate the loop" - marked future enhancement
   - If these are intentional deferrals, PR body should note this

4. **Manual testing incomplete**
   - PR test plan shows: `[ ] Manual test: Run actual plan-review loop with agents`
   - Has the loop been tested end-to-end?

### SUGGESTIONS

1. **CODEX.md could reference CLAUDE.md more**
   - Currently ~61 lines, largely duplicates structure
   - Consider: "For full details, see CLAUDE.md" to reduce drift

2. **Consider adding `--iterations N` flag**
   - Workflow doc mentions `--review 1` for single iteration
   - Useful for quick validation without full loop

3. **Reviewer agent subagent_type inconsistency**
   - `plan-creator-agent.md` says: `subagent_type: Plan`
   - `plan-reviewer-agent.md` says: `subagent_type: general-purpose`
   - Consider using a dedicated `Review` subagent_type for consistency (or document why general-purpose)

---

## Questions for Author

1. Were the incomplete acceptance criteria intentional deferrals to a follow-up PR?
2. Has the full plan-review loop been tested manually with actual agents?
3. Should the issue count increment in `spec/ISSUES.md` be in this PR? (0→1)

---

## Verdict

**APPROVE with minor fixes** - The core implementation is solid. Recommend addressing:
- Fix doc/implementation mismatch for `--review N` option
- Confirm manual testing is complete
- Clarify intentional deferrals in PR description

The feature adds real value by catching issues during planning rather than implementation.
