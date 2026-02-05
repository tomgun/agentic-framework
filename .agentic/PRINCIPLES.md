# Framework Principles

**Purpose**: Core values and principles that guide the Agentic AI Framework. Every design decision traces back to these principles.

**For New Contributors**: Understand these before proposing changes. **For Agents**: These are non-negotiable guidance.

**Structure**: 8 NON-NEGOTIABLE principles (the framework breaks without them) + 3 RECOMMENDED principles (highly valuable, adaptable to context).

---

## NON-NEGOTIABLE Principles

### 1. Sustainable Long-Term Development

**What**: This framework optimizes for projects lasting months or years, not quick prototypes.

**Why**: Complex software takes time. Context windows reset. Teams evolve. AI alone cannot sustain long-term projects. Without deliberate structure, AI-assisted projects collapse after a few sessions.

**Key Practices**:
- Durable artifacts survive context resets (CONTEXT_PACK, STATUS, JOURNAL)
- Documentation evolves with code (same commit)
- Clear project state is always visible to both humans and agents
- **Observable Progress**: STATUS.md, JOURNAL.md, and feature tracking provide unambiguous progress signals. Humans can check project state without starting an agent session (zero tokens). Agents can resume work without human explanation.

**Anti-pattern**: ❌ Optimizing for quick demos that break after context is lost. ❌ No persistent documentation, re-learning every session.

---

### 2. Human-Agent Partnership

**What**: Humans and AI agents collaborate as partners. Humans define WHAT, agents handle HOW. Neither alone is optimal.

**Why**: Humans have domain knowledge and judgment. AI has execution speed and consistency. Specs (markdown files) are the collaboration interface — readable and editable by both. Human oversight is a feature, not a bug.

**Key Practices**:
- Humans can directly edit specs (FEATURES.md, acceptance criteria, STATUS.md)
- Agents honor human edits as source of truth
- Framework makes human review efficient (diff stats, scope drift warnings) — but never tries to eliminate review
- Agent presents useful information; human makes judgment calls
- Agents escalate uncertainty to humans (HUMAN_NEEDED.md)

**Anti-pattern**: ❌ "Agent-driven development" where humans just watch. ❌ Hiding specs in formats only agents can edit. ❌ Trying to make agents "need less supervision" through more rules.

---

### 3. Context Efficiency

**What**: Limited context windows are the fundamental constraint of AI-assisted development. Every framework decision respects this constraint.

**Why**: Reading entire codebases repeatedly is prohibitive. Context resets would kill projects without strategy. Token costs compound over months. This is the #1 unique technical insight of this framework.

**Key Practices**:
- **Minimal Viable Context**: Load the minimum context needed for the task. Don't frontload "just in case."
- **Structured reading protocols**: Explicit token budgets per task type (3-5K for a focused feature, not 50K)
- **Agent delegation**: Spawn subagents with fresh, focused context (5-10K tokens) instead of accumulating drift (100K+)
- **Sequential agents**: Specialized agents load only role-specific context (Research Agent doesn't load implementation code)
- **Manual operations**: Humans read STATUS.md and JOURNAL.md directly (zero tokens) instead of asking agents
- **Token-efficient scripts**: `journal.sh`, `status.sh`, `feature.sh` — 40x more efficient than read-modify-write
- Token efficiency IS green coding for framework operations — every token saved reduces compute energy

**Anti-pattern**: ❌ Reading all files in src/ at session start. ❌ "Load all spec files to understand the project." ❌ Keeping everything in one long session until context overflows.

**Reference**: `.agentic/token_efficiency/`, `reading_protocols.md`, `MANUAL_OPERATIONS.md`

---

### 4. Deterministic Enforcement

**What**: Critical behavior is enforced by scripts and gates, not by documentation and hope. This is what makes the framework actually work.

**Why**: Documentation can be ignored. Guidelines can be misunderstood. Different AI models interpret rules differently. Critical workflows must be reliable, not "usually" reliable. Scripts enforce the same behavior regardless of which agent runs them.

**Key Practices**:
- **Scripts > Documentation**: `wip.sh check` returns exit code, doesn't just advise
- **Hard gates for hard rules**: Pre-commit hooks block if WIP.md exists or acceptance files missing
- **Soft warnings for soft signals**: Scope drift, change size — WARN, don't block (human judges)
- **Machine-readable specs**: YAML frontmatter enables automated validation (not just human reading)
- **Graceful degradation**: Advisory guidelines may be skipped by some agents; script-enforced rules cannot be. Framework remains functional even with partial guideline compliance.
- **Fail fast, recover gracefully**: Catch problems early (pre-commit, WIP check) but always provide clear recovery options (Continue | Review | Rollback)

**Enforcement Mechanisms**:
1. `session_start.md` — first step is `wip.sh check` (detects interrupted work)
2. `pre-commit-check.sh` — validates before commit allowed (exit 1 blocks)
3. `feature.sh` — enforces valid status transitions (planned → in_progress → shipped)
4. Token-efficient tools — surgical edits, no full-file rewrites

**Anti-pattern**: ❌ "Agents should..." without enforcement (hope-based development). ❌ Commit first, validate later. ❌ Blocking on soft signals that require human judgment.

---

### 5. Durable Artifacts

**What**: Living documents that capture project truth, readable by both humans and agents. The core mechanism for surviving context resets.

**Why**: Without persistent state, every new session starts from scratch. Re-reading the same code every session wastes tokens and time. These artifacts serve dual purpose: agents read them for context; humans read them for project awareness (zero tokens).

**The Artifacts**:
- **CONTEXT_PACK.md**: Architecture snapshot — where things are, how they connect. Read this first.
- **STATUS.md**: Current state, next steps, blockers. Always up to date.
- **JOURNAL.md**: Session-by-session progress log. Append-only via `journal.sh`.
- **HUMAN_NEEDED.md**: Items requiring human decision or action.

**Key Practices**:
- Agents read these FIRST at session start (reading protocols)
- Updated in same commit as code changes (Living Documentation)
- Token-efficient tools prevent full-file rewrites when updating
- Humans can `cat STATUS.md && tail -30 JOURNAL.md` for instant project state (zero tokens)

**Anti-pattern**: ❌ Starting every session with "let me read all files in src/". ❌ Empty or stale CONTEXT_PACK.md. ❌ "What are we working on?" when STATUS.md has the answer.

---

### 6. Anti-Hallucination (NON-NEGOTIABLE)

**What**: Agents must NEVER fabricate information — APIs, function signatures, endpoints, library behavior, or technical claims.

**Why**: Hallucinated code causes runtime errors and security vulnerabilities. Guessed API signatures waste hours of debugging. One hallucination can cascade into systemic problems. This undermines ALL other quality principles.

**Key Practices**:
- NEVER make things up — state uncertainty, look it up, or ask
- Verify technical claims against version-specific documentation
- Use HUMAN_NEEDED.md when uncertain
- "I don't know" is explicitly encouraged
- Wrong code that looks right is worse than no code — accuracy > speed

**Anti-pattern**: ❌ Guessing API signatures. ❌ "It probably works like..." ❌ Assuming library behavior from training data. ❌ Fabricating function names or parameters.

**Reference**: `agent_operating_guidelines.md` Anti-Hallucination Rules

---

### 7. No Auto-Commits Without Approval (NON-NEGOTIABLE)

**What**: Agents NEVER commit changes without explicit human approval.

**Why**: Humans need to review what changed and why. This is the safety gate that prevents compounding mistakes. Agents present changes, wait for approval, then commit.

**Exception**: User may grant blanket approval for a session.

**Anti-pattern**: ❌ "I've committed your changes" (past tense, no approval). ❌ Blanket auto-commit by default.

**Reference**: `git_workflow.md`

---

### 8. Check Before Creating (NON-NEGOTIABLE)

**What**: Before creating any file, test, document, or component, agents MUST check if equivalent functionality already exists.

**Why**: Duplication wastes effort and creates maintenance burden. Existing implementations may have edge cases already handled. "I didn't know that existed" is not an excuse — checking is mandatory. Proven by real-world discovery (duplicate test 020/025).

**What to Check**:
| Creating | Check First |
|----------|-------------|
| New test | Existing tests in same area (`grep`, test_definitions.json) |
| New doc | Existing docs on topic (`grep`, list docs/) |
| New component | Similar components in codebase |
| New utility | Existing utilities with similar names/functions |
| New principle | PRINCIPLES.md for existing coverage |

**Anti-pattern**: ❌ Creating without searching. ❌ "I'll just add a new one, it's faster." ❌ Creating auth.js when AuthService.ts exists.

---

## RECOMMENDED Principles

### 9. Small Batch + Acceptance-Driven Development

**What**: Work in small, isolated batches at the feature level. Define acceptance criteria before implementation. Specs evolve with discoveries.

**Why**: AI agents lose focus in large batches — context drift is real. Small changes are easy to verify and rollback. Acceptance criteria define "done" before code is written. But specs aren't perfect upfront — they evolve during implementation.

**Small Batch Rules**:
- ONE feature at a time per agent (multi-agent teams use worktrees for parallel work)
- MAX 5-10 files per commit (stop and re-plan if more)
- COMMIT when feature's acceptance tests pass
- STOP and re-plan if >10 files touched, >1 hour without commit, or multiple features in progress

**Acceptance-Driven Flow**:
1. Define feature + acceptance criteria (rough OK initially)
2. AI implements feature
3. Write/update tests to verify acceptance criteria
4. Update specs with discoveries (new requirements, edge cases)
5. Commit when acceptance tests pass → next feature

**Quality Gates**:
- Acceptance files mandatory for shipped features (spec/acceptance/F-####.md)
- Shipped ≠ Accepted: agents mark shipped, humans mark accepted (human validation is final gate)
- TDD available as option (set `development_mode: tdd` in STACK.md) for those who prefer tests-first

**Anti-pattern**: ❌ Working on auth, sessions, and password reset all at once. ❌ Starting with no acceptance criteria. ❌ Commits with 30 files. ❌ Marking feature "done" without human validation.

---

### 10. Living Documentation

**What**: Documentation stays current, has one authoritative location per topic, and is explicit enough for any agent to follow.

**Why**: Stale docs are worse than no docs. Duplicated information drifts apart. Agents interpret ambiguity differently. Clear, current, single-source documentation is the foundation of sustainable AI-assisted development.

**Key Practices**:
- **Same commit rule**: Documentation updated in same commit as code changes (MANDATORY)
- **Single source of truth**: Every topic has ONE authoritative location. Cross-reference, don't duplicate.
- **Explicit over implicit**: All behavior documented. No "magic" or implicit understanding required. Agents need explicitness.
- **Accurate > complete**: Documentation describes what ACTUALLY works, not aspirations
- **DRY**: Don't Repeat Yourself — refactor when duplication found

**Document Hierarchy**:
| Document | Purpose | Audience |
|----------|---------|----------|
| START_HERE.md | Quick start (5 min) | New users |
| DEVELOPER_GUIDE.md | Comprehensive reference | Daily use |
| MANUAL_OPERATIONS.md | Token-free commands | Quick lookups |
| PRINCIPLES.md | Why we do what we do | Contributors |
| agent_operating_guidelines.md | Agent behavior rules | AI agents |

**Anti-pattern**: ❌ Code committed, docs updated "later" (never). ❌ Same explanation in 3 files. ❌ Relying on conventions not documented.

---

### 11. Green Coding

**What**: The framework helps projects produce environmentally efficient software through practical guidance and awareness.

**Why**: Energy-efficient code is usually faster, cheaper, and more maintainable. Green principles align with performance optimization. Developer responsibility extends to environmental impact.

**Two Aspects**:
1. **Framework operations**: Token efficiency (Principle #3) inherently reduces compute energy
2. **Project output**: Practical guidance for writing efficient code — algorithms, caching, event-driven patterns, resource optimization

**Reference**: See `.agentic/quality/green_coding.md` for comprehensive guidelines covering algorithms, caching, lazy loading, event-driven patterns, resource optimization, and infrastructure choices.

**Anti-pattern**: ❌ Polling every second when webhooks would work. ❌ Loading entire datasets when pagination would suffice. ❌ Unoptimized algorithms causing excessive CPU usage.

---

## Summary

**This framework assumes**: Complex software takes months or years to build. It requires sustained effort, context continuity, human judgment, quality by design, living documentation, and token efficiency.

**Therefore**: Every principle optimizes for **sustainable long-term AI-assisted development of real products**, not quick prototypes or demos.

---

## Using These Principles

**For Developers**: Understand "why" behind framework decisions. Question features that violate principles.

**For Contributors**: Propose changes consistent with principles. Challenge principles if context has changed (with strong rationale).

**For Agents**: These principles guide all work. When uncertain, return to principles. NON-NEGOTIABLE means NON-NEGOTIABLE.

---

**Last Updated**: 2026-02-05
**Framework Version**: 0.19.0

**Note**: Principles evolve, but slowly. Major changes require strong justification.

**Detailed Reference**: Features, configuration options, and advanced capabilities removed from this document are documented in their respective feature specs, DEVELOPER_GUIDE.md, and agent guidelines. This document captures the WHY; implementation docs capture the HOW.
