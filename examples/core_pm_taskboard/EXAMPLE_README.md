# Task Board (Next.js) - Core+PM Example

This folder demonstrates the Agentic Framework in **Core + Product Management** mode.

## What This Shows

- ✅ `STATUS.md` - Project roadmap and current focus
- ✅ `spec/` directory - Formal specifications (PRD, TECH_SPEC, FEATURES, NFR)
- ✅ Feature tracking with stable IDs (F-0001, F-0002, etc.)
- ✅ Acceptance criteria per feature (`spec/acceptance/F-####.md`)
- ✅ Cross-references validated by tools
- ✅ Progress metrics via `report.py`

## Running the Example

```bash
# Check project health
python3 .agentic/tools/doctor.py

# View feature status
python3 .agentic/tools/report.py

# See current focus
cat STATUS.md

# View specific feature
cat spec/FEATURES.md  # Full registry
cat spec/acceptance/F-0001.md  # Specific acceptance criteria
```

## Key Files

**Core files** (same as Core mode):
- `PRODUCT.md` - What we're building (lightweight overview)
- `STACK.md` - Tech stack (Next.js 15, React 19, Tailwind)
- `CONTEXT_PACK.md` - Architecture overview
- `JOURNAL.md` - Session history

**Product Management additions**:
- `STATUS.md` - Current focus, roadmap, metrics
- `spec/PRD.md` - Why we're building this
- `spec/TECH_SPEC.md` - How we're building it
- `spec/FEATURES.md` - Feature registry with F-#### IDs
- `spec/NFR.md` - Non-functional requirements
- `spec/acceptance/F-####.md` - Acceptance criteria per feature

## For Agents

This project uses **Core + Product Management** profile. When resuming work:

1. Read `STATUS.md` first (current focus, what's next)
2. Read `spec/FEATURES.md` to understand feature status
3. Read specific `spec/acceptance/F-####.md` for the feature you're working on
4. Update `spec/FEATURES.md` after making progress
5. Update `STATUS.md` if you complete or start new features

Agents have formal requirements and can work autonomously following the spec.

