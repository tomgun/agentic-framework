---
name: implementing-features
description: >
  Implements features using contract-driven workflow with structural gates.
  Use when user says "build", "implement", "add feature", "create [thing]",
  "implement F-XXXX", "ag implement", or describes new functionality to build.
  Do NOT use for: one-line fixes (use fixing-bugs), writing tests only
  (use writing-tests), code review (use reviewing-code), documentation-only
  changes (use updating-documentation).
compatibility: "Requires Claude Code with shell access and ag commands."
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, Agent]
metadata:
  author: agentic-framework
  version: "${VERSION}"
---
# Implementing Features

Run `ag start F-XXXX "Title"` to begin, then follow the CLI prompts.
The CLI checks artifacts, enforces transitions, and emits role-specific guidance.

Key commands:
- `ag start F-XXXX "Title"` — create work item, begin planning
- `ag transition F-XXXX <state>` — advance when artifacts ready
- `ag check F-XXXX` — see what's missing
- `ag verify F-XXXX` — run tests
- `ag done F-XXXX` — post-merge: doc gate, VERSION bump, state flush
- `ag contract check F-XXXX` — verify contract assertions pass

## TDD mode (`development_mode: tdd` in STACK.md)

When TDD mode is active, the PreToolUse hook **blocks source code edits** until a RED phase checkpoint exists. Follow the RED→GREEN→REFACTOR cycle per acceptance criterion:

1. **RED** — Write a failing test for the AC, run it, confirm it fails
   `bash .agentic/lib/tools/wip.sh checkpoint --phase RED "test for [AC description] fails"`
2. **GREEN** — Write minimal code to make the test pass
   `bash .agentic/lib/tools/wip.sh checkpoint --phase GREEN "[AC description] passes"`
3. **REFACTOR** — Clean up without changing behavior
   `bash .agentic/lib/tools/wip.sh checkpoint --phase REFACTOR "extracted [helper/pattern]"`

Repeat for each AC. The hook allows test file edits at any time — only source files require a RED checkpoint first.

## Preconditions
- Feature must have a YAML contract at `spec/contracts/F-XXXX.yaml` with assertions
- Contract lifecycle must be `specifying` or later (not `exploring`)
- If pending `user_input` exists on the contract, process it first (write tests → implement → migrate → clear)

## Contract & test impact check
After making code changes, grep `spec/contracts/` for assertions related to the changed behavior. If any are affected, **STOP** — present the affected assertions to the user and wait for approval before modifying any contract or test. Contracts protect shipped behavior; silently updating them to match new code defeats that protection.

## Documentation (before creating PR)
Docs are part of the deliverable — update them alongside code, not after merge.
1. Check freshness: `bash .agentic/lib/tools/docs.sh --check-freshness --trigger feature_done --manifest F-XXXX`
2. Update each stale doc relevant to your feature
3. Include doc changes in the same PR as code
4. For complex doc work, use the `updating-documentation` skill
