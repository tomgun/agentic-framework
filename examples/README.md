# Examples Index

This directory contains example projects demonstrating the Agentic Framework in action.

## 📁 Core Mode Example: `core_todo_cli/`

**Profile**: Core (no formal product management)  
**Project**: Simple Python CLI todo manager

**Demonstrates**:
- ✅ `PRODUCT.md` for lightweight planning (checkboxes track progress)
- ✅ Working with agents without formal specs
- ✅ Minimal ceremony, fast iteration
- ✅ Code annotations (`@feature`) for context
- ✅ Unit tests with pytest

**File Structure**:
```
core_todo_cli/
├── .agentic/           # Framework (same in both profiles)
├── AGENTS.md           # Agent entry point
├── STACK.md            # Profile: core
├── PRODUCT.md          # ← What we're building (lightweight)
├── CONTEXT_PACK.md     # Architecture
├── JOURNAL.md          # Session history
├── HUMAN_NEEDED.md     # Escalations
├── todo_cli/           # Implementation
└── tests/              # Unit tests
```

**How agents work in Core mode**:
1. Read `PRODUCT.md` to understand what's being built
2. Ask user: "Which capability should I work on?"
3. Implement, test, update `PRODUCT.md` (check off items)
4. Log progress in `JOURNAL.md`

---

## 📁 Core+PM Example: `core_pm_taskboard/`

**Profile**: Core + Product Management  
**Project**: Next.js task board web app

**Demonstrates**:
- ✅ Full `spec/` directory with formal requirements
- ✅ `STATUS.md` for project roadmap
- ✅ Feature tracking with stable IDs (F-0001, F-0002, etc.)
- ✅ Acceptance criteria per feature
- ✅ Cross-reference validation
- ✅ NFRs (performance, accessibility, reliability)
- ✅ Tools: `doctor.py`, `report.py`, `verify.py`

**File Structure**:
```
core_pm_taskboard/
├── .agentic/           # Framework
├── AGENTS.md           # Agent entry point
├── STACK.md            # Profile: core+product
├── PRODUCT.md          # High-level overview
├── STATUS.md           # ← Current focus, roadmap
├── CONTEXT_PACK.md     # Architecture
├── JOURNAL.md          # Session history
├── HUMAN_NEEDED.md     # Escalations
└── spec/
    ├── PRD.md          # Why (requirements)
    ├── TECH_SPEC.md    # How (architecture)
    ├── FEATURES.md     # ← Feature registry with F-#### IDs
    ├── NFR.md          # Non-functional requirements
    └── acceptance/
        ├── F-0001.md   # ← Acceptance criteria per feature
        ├── F-0002.md
        └── ...
```

**How agents work in Core+PM mode**:
1. Read `STATUS.md` to know current focus
2. Read `spec/FEATURES.md` to understand feature status
3. Read `spec/acceptance/F-####.md` for the specific feature
4. Implement, test, update `spec/FEATURES.md` with progress
5. Update `STATUS.md` when completing/starting features

---

## Comparing the Profiles

| Aspect | Core (`core_todo_cli/`) | Core+PM (`core_pm_taskboard/`) |
|--------|-------------------------|--------------------------------|
| **Planning doc** | `STATUS.md` + `PRODUCT.md` (optional) | `STATUS.md` + `PRODUCT.md` + `spec/` |
| **Feature tracking** | Checkboxes in `PRODUCT.md` | F-#### IDs in `spec/FEATURES.md` |
| **Acceptance criteria** | Informal (user approval) | Formal (`spec/acceptance/F-####.md`) |
| **Agent direction** | Asks user what to work on | Reads `STATUS.md` for focus |
| **Tools** | `doctor`, `verify` | `doctor`, `report`, `verify`, `feature_graph` |
| **Good for** | Small projects, prototypes | Long-term projects, teams |

---

## Old Examples

Previous examples (before Core/Core+PM split) are in `old/` for reference.

---

## Running the Examples

```bash
# Core mode
cd core_todo_cli/
python3 .agentic/tools/doctor.py
cat PRODUCT.md

# Core+PM mode
cd core_pm_taskboard/
python3 .agentic/tools/doctor.py
python3 .agentic/tools/report.py
cat STATUS.md
```

Both examples show realistic project states mid-development (not empty templates).
