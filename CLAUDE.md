# Claude (Anthropic) Instructions

You are working in a repository that uses the **Agentic Framework** for AI-assisted development.

---

## Quick Start (READ THIS)

**Read `.agentic/agents/shared/AGENT_QUICK_START.md`** (~70 lines) - it has everything you need.

---

## The One Rule

Run `doctor.sh` at phase transitions. Gates enforce quality - you don't need to memorize checklists.

```bash
doctor.sh              # Quick health check
doctor.sh --full       # Comprehensive verification
doctor.sh --phase X    # Phase-specific check (start/planning/implement/complete/commit)
doctor.sh --pre-commit # Before committing
```

---

## Session Start Protocol

1. Check `WIP.md` (interrupted work?)
2. Read: `CONTEXT_PACK.md` → `STATUS.md` → `JOURNAL.md` (last 3 entries)
3. Greet user: "✓ Session started. Working on: [task]. Blockers: [none/list]"

---

## Feature Work

For "implement F-####":
1. Check acceptance exists: `spec/acceptance/F-####.md`
2. If missing, create it first (planning phase)
3. Use orchestrator for complex features: `.agentic/agents/roles/orchestrator-agent.md`

---

## Token-Efficient Tools (Use These!)

```bash
# Append to JOURNAL.md (don't read/rewrite!)
bash .agentic/tools/journal.sh "Topic" "Done" "Next" "Blockers"

# Update STATUS.md sections
bash .agentic/tools/status.sh focus "Current task"

# Update FEATURES.md
bash .agentic/tools/feature.sh F-0003 status shipped
```

---

## Session End

Run `.agentic/checklists/session_end.md` checklist.
Tell user: "✓ Session ending. Summary: [done]. Next: [next]. Blockers: [list]"

---

## Never Auto-Commit

ALWAYS show changes to human first. ONLY commit when human explicitly approves.

---

## When User Says "/verify"

The user is helping enforce quality. Immediately run:

```bash
bash .agentic/tools/doctor.sh --full
```

Then:
1. Report results clearly (passes, issues, suggestions)
2. Offer to fix issues automatically where possible
3. For decisions needed, add to HUMAN_NEEDED.md
4. Summarize: phase, what's working, what needs attention

**This is human-agent partnership** - acknowledge the user is actively helping maintain quality.

---

## Reference Material (Read When Needed)

- **Full guidelines**: `.agentic/agents/shared/agent_operating_guidelines.md` (detailed rationale)
- **Principles**: `.agentic/PRINCIPLES.md` (philosophy)
- **Checklists**: `.agentic/checklists/` (step-by-step when stuck)
- **Quality standards**: `.agentic/quality/` (testing, code review)

These are **reference** - gates handle enforcement, you don't need to memorize them.
