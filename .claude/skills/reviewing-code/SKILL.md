---
name: reviewing-code
description: >
  Code review for quality, bugs, security, and conventions. Use when user says
  "review", "/review", "check this code", "look at my changes", "code review",
  "is this good", "any issues", or asks for feedback on code.
  Do NOT use for: implementing features (use implementing-features), writing
  tests (use writing-tests), committing code (use committing-changes).
compatibility: "Requires Claude Code with file access."
allowed-tools: [Read, Grep, Glob, Bash, Agent]
metadata:
  author: agentic-framework
  version: "0.62.0"
---
# Reviewing Code

Run `ag transition F-XXXX plan_review` to trigger a structured review via the CLI.
For ad-hoc reviews without a feature ID, spawn a review subagent.

Key commands:
- `ag transition F-XXXX plan_review` — trigger plan/code review
- `ag check F-XXXX` — see current state and what's missing

For quick reviews (PR or working tree), use the Agent tool to spawn a subagent:
- Give it the diff command (`gh pr diff N` or `git diff`)
- Ask it to check: correctness, security, performance, style, tests, docs
- Have it return a structured report (Must Fix / Should Fix / Consider / Verdict)

Quality knowledge references (read for detailed guidance):
- `.agentic/lib/quality_knowledge/review_checklist.knowledge.md` — structured review checklist
- `.agentic/lib/quality_knowledge/security.knowledge.md` — OWASP patterns, injection, XSS, auth
- `.agentic/lib/quality_knowledge/testing.knowledge.md` — test quality, coverage, methodology
- `.agentic/lib/quality_knowledge/code_quality.knowledge.md` — clarity, error handling, design
- `.agentic/lib/quality_knowledge/green_coding.knowledge.md` — performance, caching, resources
