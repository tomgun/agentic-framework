---
name: completing-work
description: >
  Feature completion workflow: verify contract assertions, mark done, update
  specs, cleanup WIP. Use when user says "done", "complete", "finished",
  "merged", "PR merged", "shipped", "landed", "wrapped up", "ag done",
  "mark as done", "it's in", or indicates work is finished. Also triggered
  automatically after merging a PR. Do NOT use for: committing code (use
  committing-changes), starting new features (use implementing-features).
compatibility: "Requires Claude Code with shell access and ag commands."
allowed-tools: [Read, Edit, Bash, Glob, Grep]
metadata:
  author: agentic-framework
  version: "0.68.0"
---
# Completing Work

## Merging a PR

Use `ag merge <pr#> [F-XXXX]` — it wraps `gh pr merge` + `ag done` in one command.
NEVER use `gh pr merge` directly — it skips the post-merge workflow.

If PR was already merged (via `gh pr merge` or GitHub UI):
1. `git checkout main && git pull --rebase origin main`
2. Run the post-merge steps below manually

## What's Enforced Automatically (hooks — you can't bypass these)
- **Merge without done blocks stop** → Stop.sh denies session end when feature merged but not shipped
- **Feature branch without PR blocks stop** → Stop.sh denies when commits exist but no PR
- **Merge bypass detection** → PostToolUse warns if `gh pr merge` used directly (use `ag merge` instead)
- **Doc freshness gate (Gate 4)** → `ag done` blocks if docs stale (formal, docs_gate: blocking)
- **Contract assertion verification** → `ag done` verifies all assertions pass

## Post-Merge Steps

Run `ag done F-XXXX` on main — this is the single required post-merge action. It handles:
- Spec status (mark shipped), backlog advancement, journal, status updates
- VERSION bump (patch) and state file flush
- **Gate 4: doc freshness safety net** — if docs were updated in the PR (as they should be), this passes automatically. If it blocks, go back and update stale docs.
- Contract assertion verification
- Git tag: `git tag v$(cat VERSION) && git push origin v$(cat VERSION)`

### Framework development only (detected by FRAMEWORK_DEVELOPMENT.md)
`ag done` auto-runs dogfood sync. Additionally:
- Sync instruction files (DEVELOPER_GUIDE, HOW_IT_WORKS, cursor rules, etc.) with the merged changes
- Update memory-seed if workflow rules changed

## Before running `ag done`
1. Verify contract assertions: `ag contract check F-XXXX` (all assertions must pass)
2. Complete WIP: `bash .agentic/lib/tools/wip.sh complete`
3. Verify doc freshness: `bash .agentic/lib/tools/docs.sh --check-freshness --trigger feature_done --manifest F-XXXX`
4. If design choices were made, update OVERVIEW.md (current state) and log with `journal.sh --decision` (include reasoning and alternatives in the outcome text)

## Rules
- NEVER skip `ag done`. It runs doc freshness gates, contract checks, and VERSION bump.
- All contract assertions in `spec/contracts/F-XXXX.yaml` must pass before shipping.
- If assertions not met, list what remains and ask user how to proceed.
