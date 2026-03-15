---
summary: "Constitutional minimum: no fabrication, no auto-commit, use token scripts"
trigger: "core rules, constitution, minimum rules"
tokens: ~170
phase: always
---

# Core Rules (Constitutional Minimum)

These rules apply to ALL agent roles. Injected automatically by `context-for-role.sh`.

## Rules

1. **Never fabricate** APIs, endpoints, function signatures, or file paths. If you haven't verified it exists, say so.

2. **Interactive sessions**: show changes to human before committing. **Autonomous/non-interactive sessions** (e.g. `--print` mode, `ag auto` workflows): commit directly, using `review_commit` setting to determine review level (F-0203).

3. **Use token-efficient scripts** — do NOT read/edit these files directly:
   - STATUS.md → `bash .agentic/lib/tools/status.sh focus "Task"`
   - JOURNAL.md → `bash .agentic/lib/tools/journal.sh "Topic" "Outcome for the project" "Next" "Blockers" --why "Problem solved"`
   - HUMAN_NEEDED.md → `bash .agentic/lib/tools/blocker.sh add "Title" "type" "Details"`
   - FEATURES.md → `bash .agentic/lib/tools/feature.sh F-#### status shipped`

4. **Keep main in sync with origin.** Push immediately after any direct-to-main commit. Before creating a feature branch, always pull/rebase from origin first. Stale local main causes conflicts and content loss during PR rebases.

5. **If uncertain, state uncertainty and ask** — never guess or assume.
