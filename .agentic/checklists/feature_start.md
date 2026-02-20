# FEATURE START CHECKLIST (MANDATORY)

**🛑 STOP! Read this BEFORE any feature work.**

---

## GATE 1: Acceptance Criteria (BLOCKING)

```
□ Does spec/acceptance/F-####.md exist?
  ├─ YES → Check: does it have a ## Tests section?
  │         ├─ YES → Proceed to Gate 2
  │         └─ NO  → Add ## Tests section before coding (see template)
  └─ NO  → 🛑 STOP. Create acceptance criteria FIRST.
           DO NOT write any code until criteria exist.
```

**If no acceptance criteria:**
1. Draft criteria using `.agentic/spec/acceptance.template.md`
2. Fill in the `## Tests` section — what tests will verify each criterion?
3. Show to user for approval
4. Create `spec/acceptance/F-####.md`
5. ONLY THEN proceed

**The `## Tests` section is required.** Tests are part of the feature definition, not a follow-up task. An acceptance file without a tests section is incomplete.

---

## GATE 2: Scope Check (BLOCKING)

```
□ Is this a SMALL batch? (max 5-10 files)
  ├─ YES → Proceed
  └─ NO  → 🛑 STOP. Split into smaller features first.

□ Declare scope when starting work:
  - When running `wip.sh start`, files are captured
  - Pre-commit will warn if you change files outside declared scope
  - This helps catch unintended side effects
```

---

## GATE 3: Delegate or Do? (EFFICIENCY)

```
□ Can this be delegated to a specialized agent?

  EXPLORATION needed?
  └─ Spawn explore-agent (cheap/fast model)
  
  TESTS needed?
  └─ Spawn test-agent (mid-tier model)
  
  IMPLEMENTATION needed?
  └─ Spawn implementation-agent (mid-tier model)
  
  RESEARCH needed?
  └─ Spawn research-agent (cheap/fast model)
```

**Why delegate?** Fresh context = smaller = faster = cheaper (60-83% token savings)

---

## GATE 4: Context Handoff (IF DELEGATING)

Pass to subagent ONLY:
- Feature ID and name
- Acceptance criteria (from spec/acceptance/F-####.md)
- Relevant file paths (max 3-5 files)
- STACK.md technology info

DO NOT pass:
- Full conversation history
- Unrelated code
- Previous session context

---

## After Gates Pass

```
□ Gates 1-4 passed
□ Run `ag implement F-XXXX` (creates WIP) or start WIP manually
□ Will smoke test after
□ Will update specs when done
```

**Next**: Follow `.agentic/checklists/feature_implementation.md` for the implementation phase.

---

## Quick Reference

| User Says | You MUST Do First |
|-----------|-------------------|
| "build X" | Check acceptance criteria exist |
| "implement X" | Check acceptance criteria exist |
| "add feature X" | Check acceptance criteria exist |
| "create X" | Check acceptance criteria exist |
| "let's do X" | Check acceptance criteria exist |

**NO EXCEPTIONS. Criteria before code.**

