Designing Persistent Instruction Frameworks for Multi-Agent Coding Systems
A Practical Guide for Orchestrator-Driven Agentic Architectures

(with cross-tool research and references)

A thorough research by ChatGPT 5.2

Abstract

Modern AI coding tools increasingly support agentic workflows, where a primary “orchestrator” agent delegates work to specialized subagents (planning, implementation, review, testing, git operations).
However, persistent framework-level instructions (e.g., “always update specs and tests”, “respect selected workflow modes”) are vulnerable to context loss, especially during long or complex tasks.

This paper presents a robust architectural approach for ensuring that critical instructions and user-selected modes are always enforced, regardless of context window size, subagent boundaries, or tool differences.

1. Core Problem Statement

Across all major tools (Claude Code, Cursor, Copilot, Codex, Gemini):

There is no guarantee that long-lived instructions will remain active purely by being placed in prompt context.

This is true even when:

Models advertise very large context windows (e.g., 200k–1M tokens)

Tools claim to “always read” files like CLAUDE.md or rules

Subagents are spawned programmatically by an orchestrator

Why this happens

All instructions compete for the same context budget
System prompts, files, code, tool outputs, and agent messages all consume tokens
→ truncation, summarization, or compaction occurs in long sessions
(Anthropic: “context may be compacted during extended interactions”).

Subagents are separate model invocations
Even if logically part of one workflow, each subagent call:

Has its own input context

May receive only a subset of the parent context

May not re-receive “global rules” unless explicitly injected

Tool UX ≠ model guarantees
IDEs suggest persistence, but models still operate on token windows.

2. Verified Context Behavior (Cross-Tool)
Claude Code (Sonnet / Opus incl. 4.x)

Officially supports ~200k token stable context

~1M token context exists, but:

Tier-dependent

API-specific

Still subject to compaction during long workflows

CLAUDE.md is loaded at session start, not magically pinned forever
📌 Source:

https://platform.claude.com/docs/build-with-claude/context-windows

https://claude.com/blog/using-claude-md-files

Cursor

Context = selected model (Claude, GPT-4.x, Gemini)

“Rules” are injected, but:

Large rulesets reduce effective space for code

Subagent calls do not inherently inherit full rule text
📌 Source: https://cursor.sh/docs/context/rules

GitHub Copilot / Codex

Smaller effective context (typically 64k–128k)

Repo instructions are not guaranteed in all sub-contexts

No native orchestrator memory model
📌 Source: https://docs.github.com/en/copilot/customizing-copilot

Google Gemini (Code Assist)

Supports very large context (up to ~1M tokens in some tiers)

Still stateless between calls unless memory is externalized
📌 Source: https://ai.google.dev/gemini-api/docs/long-context

3. Key Insight (Non-Negotiable)

If a rule must NEVER be forgotten, it must NOT rely on passive context retention.

This leads to a three-layer instruction architecture.

4. The Three-Layer Instruction Architecture
Layer 1: The Constitution (Always-In, Minimal)

Purpose:
Define invariant rules that must survive any task length, any agent, any tool.

Characteristics:

300–800 tokens (hard cap ~1k)

Checklist-style

No explanations, no examples

No tool-specific details

Examples:

“Behavior changes → update specs”

“All changes → tests required”

“Respect active workflow mode”

“Record decisions and version changes”

📌 This layer is:

Injected into every orchestrator call

Re-injected into every subagent call

Never replaced by summaries

Layer 2: Playbooks (Retrieved, Not Pinned)

Purpose:
Explain how to follow rules (TDD flow, spec format, release process).

Characteristics:

Stored externally (/AI/PLAYBOOKS/*)

Loaded only when relevant

Can be large (5k–20k tokens)

Key rule:

Playbooks are referenced by name in the Constitution, not embedded.

Layer 3: Project State (Machine-Readable Memory)

Purpose:
Persist user-selected modes and framework state independently of LLM memory.

Examples:

workflowMode: TDD | spec-first

gitMode: main | feature-branch+PR

releasePolicy: manual | auto

docPolicy: strict | minimal

Storage:

JSON / YAML file

Git-tracked or external store

Read by orchestrator before every task

📌 This is not prompt memory — it is state.

5. Orchestrator Responsibilities (Critical)

Your orchestrator agent must not trust the model to remember.

It must:

Load Constitution

Load Project State

Inject both into every agent call

Verify outputs against Constitution

Block completion if rules unmet

This makes the orchestrator the enforcement layer, not the LLM.

6. Mandatory Post-Task Enforcement Pattern

Every task ends with a forced validation step:

FINALIZATION CHECK:
- Were specs updated? (if behavior changed)
- Were tests added/updated?
- Was journal/changelog updated?
- Does output comply with workflowMode?


If any item fails:

Task is not considered complete

Orchestrator triggers corrective subagent

This pattern is tool-independent and survives context loss.

7. Why This Works (Even When Context Breaks)
Failure Mode	Why Framework Survives
Context truncation	Constitution is re-injected
Subagent isolation	Orchestrator enforces rules
Large codebases	Playbooks retrieved selectively
Tool differences	State externalized
Model hallucination	Post-task validation
8. What NOT to Do (Common Traps)

❌ One giant CLAUDE.md
❌ Relying on “the model will remember”
❌ Embedding workflow modes only in natural language
❌ Trusting IDE rules as enforcement
❌ Letting subagents decide when rules apply

9. References

Anthropic – Context windows and compaction
https://platform.claude.com/docs/build-with-claude/context-windows

Anthropic – Using CLAUDE.md
https://claude.com/blog/using-claude-md-files

Memory is best-effort. Policy must be enforced.



--------------


Concrete files below


1. Artifact 1 —

“Why LLMs forget rules in long sessions”
https://www.lesswrong.com/

“Context windows are not memory”
https://lilianweng.github.io/posts/2023-06-23-agent/

RAG vs prompt stuffing comparisons
https://www.pinecone.io/learn/retrieval-augmented-generation/

7. Final, Hard Recommendation

Never design a framework where correctness depends on memory.
Use:

Minimal, re-injected constitutions

Externalized state

Orchestrator-enforced policy

Machine-checkable gates

That architecture survives:

Opus 4.6 vs Sonnet differences

Cursor vs Copilot quirks

Context truncation

Subagent isolation

Future model changes