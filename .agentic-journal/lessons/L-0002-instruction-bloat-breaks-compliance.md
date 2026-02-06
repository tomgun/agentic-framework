# L-0002: Instruction bloat breaks LLM compliance

**Date**: 2026-02-06
**Related**: CLAUDE.md, session start protocol

---

## What happened

The session start protocol stopped triggering reliably. Claude would greet the user casually instead of running the mandatory session start sequence (check WIP, read STATUS.md, greet with context).

## Why it happened

CLAUDE.md grew from ~50 lines to ~300 lines over several commits. The session start protocol, originally in the first 10 lines, got buried at line ~127 behind:
- Enforced gates table
- Framework development warning
- Trigger-word mapping table
- Token-efficient scripts table
- Feature request gate
- Agent boundaries table
- Delegation tables
- Checklist references

When everything is marked "MANDATORY", "STOP", and "NON-NEGOTIABLE", nothing stands out. The model processes 120+ lines of competing high-priority instructions before reaching the session start protocol. By that point, attention is diluted.

## Root cause

This is a recurring pattern: instructions accumulate organically, each addition seems small, but the cumulative effect degrades LLM compliance with ALL instructions - not just the buried ones.

## What to do next time

1. **Keep CLAUDE.md under 100 lines** - treat it like a budget. Adding something means removing or moving something else.
2. **First 20 lines = highest priority behaviors** - session start, the one thing the model must always do. Everything else is secondary.
3. **Defer to referenced files** - CLAUDE.md should be an index/router, not a comprehensive manual. The old version worked: "Read AGENT_QUICK_START.md" + 3-line session protocol.
4. **Test after every CLAUDE.md change** - run LLM behavioral tests to catch compliance regressions.
5. **Watch for the "just one more section" pattern** - each addition is small but the cumulative effect is what breaks things.

## Key insight

LLM instruction files have an effective attention budget. Doubling the length doesn't halve compliance - it can destroy it entirely, because the model satisfices across competing priorities rather than following any single instruction reliably. Shorter instructions with clear hierarchy beat comprehensive instructions every time.

## Subagent context multiplier

CLAUDE.md is auto-loaded for EVERY subagent spawned via Task tool, not just the top-level agent. A 277-line CLAUDE.md means every implementation agent, test agent, and explore agent burns context on 200+ lines of irrelevant instructions (delegation tables, session start protocol). At balanced mode with haiku subagents, this context waste is proportionally even more expensive since haiku has a smaller effective context budget. The slimdown to ~80 lines benefits both top-level agents (critical instructions not buried) and subagents (less irrelevant context waste).

---

## Links

- Commit `e7fd59e` - where CLAUDE.md expanded from ~50 to ~300 lines
- Commit `115efd5` - the last working short version
- `tests/llm/tests/001_session_start.sh` - LLM test for this behavior
