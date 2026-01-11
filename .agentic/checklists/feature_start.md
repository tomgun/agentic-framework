# FEATURE START CHECKLIST (MANDATORY)

**🛑 STOP! Read this BEFORE any feature work.**

---

## GATE 1: Acceptance Criteria (BLOCKING)

```
□ Does spec/acceptance/F-####.md exist?
  ├─ YES → Proceed to Gate 2
  └─ NO  → 🛑 STOP. Create acceptance criteria FIRST.
           DO NOT write any code until criteria exist.
```

**If no acceptance criteria:**
1. Draft criteria (rough is OK)
2. Show to user for approval
3. Create `spec/acceptance/F-####.md`
4. ONLY THEN proceed

---

## GATE 2: Scope Check (BLOCKING)

```
□ Is this a SMALL batch? (max 5-10 files)
  ├─ YES → Proceed
  └─ NO  → 🛑 STOP. Split into smaller features first.
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
□ Ready to implement (or delegate)
□ Will smoke test after
□ Will update specs when done
```

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

