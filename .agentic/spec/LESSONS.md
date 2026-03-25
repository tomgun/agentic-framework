# Lessons & Caveats

<!-- reviewed: 2026-03-25 -->
Purpose: prevent repeating mistakes and capture "sharp edges" for future work (humans + agents).

## Format
- Prefer linking a lesson to a feature ID (`F-####`) and/or ADR.
- Keep it short and actionable.

---

## L-0001: BSD sed behaves differently from GNU sed
- Related: F-0141 (explicit settings)
- What happened: `sed -i.bak "${line}a\\"` append command concatenated lines on macOS instead of inserting newlines
- Why it happened: BSD sed `a\` command and `\s` shorthand behave differently than GNU sed; `\+` in ERE is metachar not literal
- What to do next time: Use `head`/`tail` for cross-platform line insertion. Use `[[:space:]]` not `\s`, `[+]` not `\+` in sed -E
- Links: PR #48, PR #49

## L-0002: Never run upgrade.sh with source = target
- Related: upgrade.sh
- What happened: Smoke test accidentally passed framework dir as both source and target; Step 5 deleted .agentic/ then tried to copy from it
- Why it happened: upgrade.sh takes 1 arg (target), not 2. Passing 2 args made $1 = source framework
- What to do next time: Always verify upgrade.sh invocation: `bash path/to/framework/.agentic/tools/upgrade.sh /path/to/target-project`
- Links: PR #48 development notes

## L-0003: Settings library masks legacy profile names
- Related: F-0141
- What happened: `get_setting "profile"` returned "discovery" for `Profile: core+product` because settings.sh only accepts "discovery"|"formal"
- Why it happened: The settings library has strict validation that rejects old names, falling through to directory-structure inference
- What to do next time: When adding migrations, trace through the full resolution chain (settings lib → STACK.md → directory inference)
- Links: PR #48

## L-0004: Unix domain socket stale detection needs broad exception handling
- Related: F-030 (Autonomous Engine Foundation)
- What happened: Test created a regular file where a socket was expected; `socket.connect()` raised `OSError: [Errno 38] Socket operation on non-socket` instead of `ConnectionRefusedError`
- Why it happened: Stale socket cleanup only caught `ConnectionRefusedError` and `FileNotFoundError`
- What to do next time: When detecting stale Unix sockets, catch `OSError` broadly — non-socket files, permission errors, and broken symlinks all produce different errno values
- Links: F-030 implementation

## L-0005: Fresh Claude instances per task unit prevent context degradation
- Related: F-030–F-0163 (Autonomous Workflow Mode)
- What happened: Design decision to spawn `claude --print` per AC instead of keeping one long session
- Why it happened: Research showed context degradation causes compounding errors when one long session implements multiple features
- What to do next time: For autonomous workflows, prefer fresh instances per logical unit. Context isolation > context continuity for implementation tasks
- Links: Autonomous mode research, ADR in journal/plans/

