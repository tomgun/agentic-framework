# Agentic Development Framework — Capability Spec

## Purpose

Enable reliable, long-term software development with AI coding agents across sessions, days, and months.

## Key Insight

~90% of the effort building this framework was compensating for unreliable agent behavior — not solving the actual development problems. Most of the complexity (behavioral tests, redundant instruction files, reinforcement layers, pre-commit gates) exists because agents kept not doing what they were told.

The 15 capabilities below are the real problems worth solving. If an agent could reliably follow instructions, the implementation of each would be dramatically simpler than what exists today.

Building the initial features took ~1-2 weeks. The remaining ~2 months of development was iterating, testing, and working around LLM unreliability.

---

## Problems

1. **Context amnesia** — New sessions start blank. The agent doesn't know what happened yesterday.

2. **No definition of "done"** — Features get declared complete when code compiles, not when they actually satisfy requirements.

3. **Quality drift** — Old features break silently over time. Tests cover happy paths. Shortcuts accumulate.

4. **Token waste** — Agents repeatedly re-read entire codebases and rewrite entire files to change one line.

5. **Stale documentation** — Code ships, docs don't update. They quickly describe a system that no longer exists.

6. **No scaling** — One agent, one task, one context window. No parallelism or handoff.

7. **All-or-nothing control** — Some developers want to approve everything. Others want to hand off entirely. No spectrum.

8. **Spec drift** — Requirements change but there's no way to evolve them without silently breaking shipped behavior.

9. **Unreviewed plans** — Agent plans and immediately executes. Flaws aren't caught until code is written.

10. **Work chaos** — No clear "what's next." Multiple things start, nothing finishes.

---

## Required Capabilities

### 1. Session Continuity
A new session has full project awareness without re-exploring the codebase. Knows what's in progress, what's done, what's blocked, what the architecture looks like.

### 2. Spec-Driven Development
Features have testable acceptance criteria before code is written. "Done" means criteria are satisfied, not "code exists." Criteria have priority tiers — must-haves require 100% completion.

### 3. Atomic Delivery
Spec, code, tests, and documentation update together. Not as separate follow-ups.

### 4. Autonomy Profiles
User chooses their involvement level:
- **Hands-on**: Approve every change (prototyping, learning)
- **Guided**: Full rigor, human at key checkpoints (production work)
- **Autonomous**: AI handles everything, human only merges (CI/CD, batch work)

Smooth transition between profiles as a project matures.

### 5. Configurable Review Points
Plan review, code review, commit approval, and merge approval are each independently set to: require human, delegate to AI review, or skip.

### 6. Ordered Backlog
One thing at a time. Clear next item. Separate idea capture from committed work queue. Can't skip ahead.

### 7. Adversarial Plan Review
Plans are challenged before implementation. Fresh perspective finds flaws, missing edge cases, risks. Not self-review.

### 8. Spec Contracts & Migration
Shipped acceptance criteria are protected. Changing shipped behavior requires an explicit, tracked change — not a silent edit.

### 9. Autonomous Workflows
Implement a feature end-to-end, break down and execute an epic, run test-fix loops — all unattended, all respecting configured review settings.

### 10. Context Efficiency
Agents load only what's relevant to the current task. State updates are surgical. Sub-tasks get fresh, focused context.

### 11. Multi-Agent Safety
Multiple agents on one project: isolated workspaces, collision awareness, one feature per agent.

### 12. Quality Gates
Criteria exist before coding. Tests pass before commit. Batch sizes stay small. Session state stays current.

### 13. Documentation Co-Evolution
Detect when code changes make docs stale. Track coverage. Update together or defer-and-batch.

### 14. Idea-to-Ship Pipeline
Vision → feature breakdown → backlog → plan → implement → test → ship. Each stage has a clear input and output. Can be run manually step-by-step or autonomously end-to-end.

### 15. Project Kickoff
Turn a high-level vision statement into a structured set of features, acceptance criteria, and an ordered backlog. Review before committing.

---

## User Experience

```
"Start"            → Full awareness of project state
"Plan X"           → Plan created and reviewed before coding
"Build X"          → Criteria first, then code + tests + docs together
"Review"           → See changes before commit, or delegate
"Ship"             → Completeness verified, PR created
"Done"             → Criteria validated, next item surfaces
"Do it yourself"   → Autonomous end-to-end, human merges
"What's next?"     → One clear answer
```

---

## Design Constraints Worth Preserving

- **Spec → AC → Code → Test → Docs** ordering is non-negotiable
- Shipped specs are contracts — changes require migrations
- "Done" is measurable via acceptance criteria, not vibes
- Users choose their level of involvement per review point
- Session state must survive context resets
- One feature at a time prevents chaos
- Small batches (5-10 files) keep changes reviewable
