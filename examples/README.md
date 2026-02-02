# Agentic Framework Examples

This directory contains example projects demonstrating the Agentic Framework in action.

## Active Examples

### 📁 `traced_notes_app/` - Traceability Demo

**Focus**: Spec-Code Traceability (F-0109)
**Project**: Simple Python notes manager

**Demonstrates**:
- ✅ `@feature F-####` annotations in source code
- ✅ Test naming conventions (`test_F0001_*.py`)
- ✅ Import tracing for test→feature mapping
- ✅ Acceptance criteria files
- ✅ `coverage.py` with `--json`, `--reverse`, `--test-mapping`
- ✅ `ag trace` unified CLI

**File Structure**:
```
traced_notes_app/
├── README.md              # How to run traceability checks
├── src/
│   └── notes.py           # Code with @feature annotations
├── tests/
│   ├── test_F0001_*.py    # Explicit naming → F-0001 (high confidence)
│   ├── test_F0002_*.py    # Explicit naming → F-0002 (high confidence)
│   └── test_delete.py     # Import tracing → F-0003 (medium confidence)
└── spec/
    ├── FEATURES.md        # Feature definitions
    └── acceptance/        # Acceptance criteria
```

**Running traceability checks**:
```bash
cd traced_notes_app/

# Check annotation coverage
python3 ../../.agentic/tools/coverage.py

# See test→feature mapping
python3 ../../.agentic/tools/coverage.py --test-mapping

# What features does notes.py implement?
python3 ../../.agentic/tools/coverage.py --reverse src/notes.py
```

---

## Archived Examples

Previous examples have been archived to `archived/` for reference:

### `archived/core_todo_cli/`
**Profile**: Core (no formal product management)
**Project**: Python CLI todo manager
**Demonstrates**: `OVERVIEW.md` for lightweight planning, minimal ceremony

### `archived/core_pm_taskboard/`
**Profile**: Core + Product Management
**Project**: Next.js task board web app
**Demonstrates**: Full `spec/` directory, formal feature tracking with F-#### IDs

### `archived/old/`
Original example projects before the Core/Core+PM profile split.

---

## Profile Comparison

| Aspect | Core | Core+PM |
|--------|------|---------|
| **Planning doc** | `OVERVIEW.md` | `spec/FEATURES.md` + `spec/acceptance/` |
| **Feature tracking** | Checkboxes | F-#### IDs with status |
| **Acceptance criteria** | Informal | Formal (`spec/acceptance/F-####.md`) |
| **Tools** | `doctor`, `verify` | + `coverage`, `drift`, `trace` |
| **Good for** | Small projects, prototypes | Long-term projects, teams |

---

## Creating New Examples

When creating new examples, demonstrate at least one of:

1. **Core Profile**: `OVERVIEW.md` checkboxes, minimal ceremony
2. **Core+PM Profile**: Full `spec/` directory, F-#### feature tracking
3. **Traceability**: `@feature` annotations, test naming conventions

Ensure examples are:
- Self-contained (can run independently)
- Mid-development state (not empty templates)
- Well-documented (README explaining what's demonstrated)
