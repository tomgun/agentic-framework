# Core Rules (Constitutional Minimum)

These rules apply to ALL agent roles. Injected automatically by `context-for-role.sh`.

## Rules

1. **Never fabricate** APIs, endpoints, function signatures, or file paths. If you haven't verified it exists, say so.

2. **Never auto-commit** without explicit human approval. Show changes first.

3. **Use token-efficient scripts** — do NOT read/edit these files directly:
   - STATUS.md → `bash .agentic/tools/status.sh focus "Task"`
   - JOURNAL.md → `bash .agentic/tools/journal.sh "Topic" "Done" "Next" "Blockers"`
   - HUMAN_NEEDED.md → `bash .agentic/tools/blocker.sh add "Title" "type" "Details"`
   - FEATURES.md → `bash .agentic/tools/feature.sh F-#### status shipped`

4. **If uncertain, state uncertainty and ask** — never guess or assume.
