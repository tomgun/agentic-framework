# L-0004: Instruction Architecture Design — Plan-Review Process

**Date**: 2026-02-07
**Status**: Complete — design document published
**Related**: L-0002, L-0003, ADR-001

---

## Summary

Two independent research efforts (ChatGPT 5.2 and Claude Opus 4.6) investigated how AI coding tools handle instruction files, context, and subagents. Their findings converged, but the framework lacked a single authoritative design basis. This lesson documents the plan-review process that produced `docs/INSTRUCTION_ARCHITECTURE.md`.

## What the design document is

A single authoritative reference that:
- Synthesizes both research documents into a unified three-layer architecture
- Maps the architecture to the framework's existing mechanisms
- Identifies 4 specific gaps with actionable fixes
- Documents 10 testable assumptions for ongoing validation
- Distinguishes verified findings (with tool-specific evidence) from architectural proposals (without empirical basis)

## Plan-review findings

The design went through 3 rounds of plan-review critique. Key corrections:

### Round 1 (7 IMPORTANT + 8 suggestions)

1. **Line 94 blanket claim**: FRAMEWORK_DEVELOPMENT.md line 94 claimed "CLAUDE.md is auto-loaded for ALL agents including subagents" — factually wrong per both research documents. Fixed to tool-specific correction.

2. **Constitution size mismatch**: Initial draft didn't address the gap between ChatGPT's 300-800 token recommendation and the framework's ~1500 token (100 line) ceiling. Added explicit deviation note with rationale (competing high-priority rules dilute faster than single-purpose constitutions).

3. **Manifest injection mechanism**: Initial draft assumed context-for-role.sh had an always-inject feature. Investigation revealed injection is entirely manifest-declared (7 of 24 manifests include anti-hallucination.md). Corrected Gap 2 to describe actual mechanism.

4. **Evidence quality conflation**: Initial draft treated both research documents as equal evidence. Added quality distinction: Claude research cites specific URLs with per-tool confidence; ChatGPT research provides excellent reasoning but generic citations.

### Round 2 (1 IMPORTANT)

5. **Maintenance model**: Initial draft had no maintenance section. Added update triggers, process requirements, and the "no ad-hoc edits" rule to prevent future weakening.

### Round 3 (accepted)

6. **User-raised additions**: Cross-machine state persistence (status.json design property), permanent assumption tracking table (section 8), explicit note about Gemini being deferred to Open Questions.

## Key design decisions

- **Distributed enforcement**: Consciously diverges from ChatGPT's centralized orchestrator recommendation. Rationale: framework operates across 4+ tools — no single orchestrator process is possible.
- **100-line ceiling over 800-token cap**: Framework's empirical finding takes precedence over unsourced recommendation.
- **"Do not change" list**: Protects 11+ working mechanisms from well-intentioned "improvements."
- **Testable assumptions table**: Tracks 10 assumptions with validation status. Failed assumptions trigger amendments.

## What this preserves

The plan-review loop itself demonstrated the value of structured critique:
- Round 1 caught factual errors that would have weakened the design's authority
- Round 2 caught a structural gap (no maintenance model)
- Round 3 incorporated user domain knowledge (cross-machine workflows)
- Total: 3 rounds, progressively narrowing from 15 issues to 1 to acceptance

---

## Links

- Design document: `docs/INSTRUCTION_ARCHITECTURE.md`
- ChatGPT research: `docs/research/context_and_subagents_research_2026_02_06.md`
- Claude research: `docs/research/2026-02-07-subagent-context-inheritance.md`
- L-0002: Instruction bloat breaks compliance
- L-0003: Instruction file architecture (orchestrator vs subagents)
