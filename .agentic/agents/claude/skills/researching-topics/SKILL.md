---
name: researching-topics
description: >
  Web search, documentation lookup, and technology evaluation. Use when user
  says "research", "look up", "find docs", "what is", "compare options",
  "evaluate", or needs information from outside the codebase.
  Do NOT use for: codebase exploration (use exploring-codebase), implementing
  features (use implementing-features).
compatibility: "Requires Claude Code with web access."
allowed-tools: [WebSearch, WebFetch, Read, Write]
metadata:
  author: agentic-framework
  version: "${VERSION}"
---

# Researching Topics

Web search, documentation lookup, and technology evaluation.

## Instructions

### Step 1: Clarify the Research Question

Understand what information the user needs:
- Specific API documentation?
- Technology comparison?
- Best practices for a technique?
- Bug/error resolution?

### Step 2: Search and Gather

Use web search for current information:
- Official documentation first
- Stack Overflow for common issues
- GitHub issues for library-specific problems
- Blog posts for best practices (prefer recent sources)

### Step 3: Synthesize Findings

Present findings organized by relevance:
- Direct answer to the question
- Supporting evidence and sources
- Trade-offs or alternatives if applicable
- Recommended approach with justification

### Step 4: Save if Valuable

If the research informs a decision, save it:
```
docs/research/YYYY-MM-DD-topic.md
```

## Examples

**Example 1: Technology evaluation**
User says: "Should we use Redis or Memcached for caching?"
Steps taken:
1. Search for current comparisons and benchmarks
2. Check project's existing infrastructure (STACK.md)
3. Compare: persistence, data structures, clustering, ease of setup
Result: Recommendation with trade-offs table and links to sources.

**Example 2: API documentation lookup**
User says: "How does the Stripe webhook verification work?"
Steps taken:
1. Fetch Stripe's official webhook docs
2. Extract key steps: signature verification, event handling
3. Provide code example matching project's language
Result: Step-by-step guide with code snippet and security notes.

## Troubleshooting

**Outdated information found**
Cause: Search results may include old articles.
Solution: Check publication dates. Prefer official docs. Cross-reference multiple sources.
