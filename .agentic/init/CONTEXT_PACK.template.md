# CONTEXT_PACK.md (Template)

Purpose: a compact, durable starting point for any agent/human so they don’t need to reread the whole repo.

## One-minute overview
- What this repo is: <!-- 1–2 sentences -->
- Main user workflow: <!-- 1–3 bullets -->
- Current top priorities: <!-- 1–5 bullets -->

## Where to look first (map)
- Entry points: <!-- e.g., src/main.ts, app/, cmd/, etc -->
- Core modules: <!-- bullets -->
- Specs: `/spec/`
- Features: `spec/FEATURES.md`
- Overview: `spec/OVERVIEW.md`
- Non-functional requirements: `spec/NFR.md`
- Lessons: `spec/LESSONS.md`
- Decisions: `spec/adr/`
- Status: `STATUS.md`

## How to run
- Setup: `<!-- fill -->`
- Run: `<!-- fill -->`
- Test: `<!-- fill -->`

## Architecture snapshot
- Components: <!-- bullets -->
- Data flow: <!-- short bullets -->
- External dependencies: <!-- APIs, DBs -->

## Code style examples

<!--
PURPOSE: Agents mimic these patterns. One snippet > many words of description.
MAINTENANCE: Update when code style changes. Review quarterly.
ALTERNATIVE: Reference actual files: "See src/utils/helpers.py for our style"
-->

### Function style
```
<!-- Replace with your language. Show: naming, typing, early returns, comments -->
function calculateTotal(items):
    // Early return for edge cases
    if items.isEmpty():
        return 0

    // Clear variable names, no abbreviations
    subtotal = sum(item.price for item in items)
    return subtotal
```

### Error handling
```
<!-- Show your preferred error pattern -->
if not user:
    raise NotFoundError("User {userId} not found")

// Don't swallow errors silently
```

### Test structure
```
<!-- Show how you organize tests -->
test "calculates total correctly":
    items = [Item(price=100), Item(price=50)]
    result = calculateTotal(items)
    expect(result).toBe(150)
```

<!--
WHEN TO UPDATE EXAMPLES:
- When you change coding standards
- When examples no longer match codebase
- During quarterly retrospectives

SIGNS EXAMPLES ARE STALE:
- Agent produces code that looks different from recent commits
- You keep correcting the same style issues

TIP: You can reference real files instead of inline examples:
- Function style: see src/services/billing.py:calculate_total()
- Tests: see tests/unit/test_billing.py
-->

## Quality gates (current)
- Unit tests required: yes
- Definition of Done: see `.agentic/workflows/definition_of_done.md`
- Review checklist: see `.agentic/quality/review_checklist.md`

## Documentation

<!-- List key docs in this project and what each covers. Keep short (5-8 entries).
     This helps agents know where new feature documentation should go.
     drift.sh --docs handles staleness detection separately. -->
- `README.md` — <!-- e.g., User-facing overview, install, usage -->
- `<!-- path -->` — <!-- purpose -->

## Known risks / sharp edges
- <!-- bullets -->


