---
name: researching-topics
description: >
  Web search, documentation lookup, and technology evaluation. Use when user
  says "research", "look up", "find docs", "what is", "compare options",
  "evaluate", or needs information from outside the codebase.
  Do NOT use for: codebase exploration (use exploring-codebase), implementing
  features (use implementing-features).
compatibility: "Requires Cursor Agent mode with web access."
allowed-tools: [WebSearch, WebFetch, Read, Write]
metadata:
  author: agentic-framework
  version: "${VERSION}"
---
# Researching Topics

Use WebSearch and WebFetch for information outside the codebase. No ag command needed.

Steps:
1. Clarify the research question (API docs? technology comparison? best practices?)
2. Search official documentation first, then Stack Overflow, GitHub issues
3. Synthesize findings: direct answer, evidence, trade-offs, recommendation
4. Save valuable research to `docs/research/YYYY-MM-DD-topic.md`
