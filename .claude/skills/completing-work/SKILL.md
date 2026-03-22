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

## Post-Merge Steps

After every merge, run these steps (or let `ag done` handle them):

1. **Spec status**: mark feature shipped — `bash .agentic/lib/tools/feature.sh F-XXXX status shipped`
2. **Backlog**: advance queue — `ag backlog done`
3. **Journal**: log outcome — `bash .agentic/lib/tools/journal.sh "F-XXXX shipped" "Capability delivered" "Next" "None" --why "Reason"`
4. **Status**: update focus — `bash .agentic/lib/tools/status.sh focus "F-XXXX shipped"`
5. **VERSION + flush**: `ag done F-XXXX` bumps VERSION (patch) and commits state files
6. **Git tag** (if VERSION file exists): `git tag v$(cat VERSION) && git push origin v$(cat VERSION)`

### Framework development only (detected by FRAMEWORK_DEVELOPMENT.md)
`ag done` auto-runs dogfood sync. Additionally:
- Sync instruction files (DEVELOPER_GUIDE, HOW_IT_WORKS, cursor rules, etc.) with the merged changes
- Update memory-seed if workflow rules changed

## Before running `ag done`
1. Verify contract assertions: `ag contract check F-XXXX` (all assertions must pass)
2. Complete WIP: `bash .agentic/lib/tools/wip.sh complete`

## Rules
- All contract assertions in `spec/contracts/F-XXXX.yaml` must pass before shipping.
- If assertions not met, list what remains and ask user how to proceed.
