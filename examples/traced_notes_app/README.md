# Traced Notes App Example

This example demonstrates the spec-code traceability features of the Agentic Framework.

## Features Demonstrated

1. **@feature Annotations** - `src/notes.py` has `@feature F-XXXX` comments linking code to specs
2. **Test Naming Convention** - `tests/test_F0001_*.py` files are auto-mapped to features
3. **Import Tracing** - `tests/test_delete.py` is mapped via imports (no explicit naming)

## Project Structure

```
traced_notes_app/
├── src/
│   └── notes.py           # Code with @feature annotations
├── tests/
│   ├── test_F0001_create_notes.py  # Explicit naming → F-0001
│   ├── test_F0002_list_notes.py    # Explicit naming → F-0002
│   └── test_delete.py              # Import tracing → F-0003
└── spec/
    ├── FEATURES.md                  # Feature definitions
    └── acceptance/
        ├── F-0001.md               # Acceptance criteria
        ├── F-0002.md
        ├── F-0003.md
        └── F-0004.md               # Planned feature (no code yet)
```

## Running Traceability Checks

From this directory:

```bash
# Check annotation coverage
python3 ../../.agentic/tools/coverage.py

# Check with test mapping
python3 ../../.agentic/tools/coverage.py --test-mapping

# What features does a file implement?
python3 ../../.agentic/tools/coverage.py --reverse src/notes.py

# JSON output for CI/tooling
python3 ../../.agentic/tools/coverage.py --json
```

## Expected Output

### Coverage Check
```
✓ Features with code annotations (4):
  F-0001: 1 file(s) - src/notes.py
  F-0002: 1 file(s) - src/notes.py
  F-0003: 1 file(s) - src/notes.py
  F-0004: 1 file(s) - src/notes.py (planned, has annotation as placeholder)
```

### Test Mapping
```
Test→Feature Mapping:
  F-0001: tests/test_F0001_create_notes.py (explicit_naming) [high]
  F-0002: tests/test_F0002_list_notes.py (explicit_naming) [high]
  F-0003: tests/test_delete.py (import_tracing) [medium]
```

## Traceability Questions Answered

| Question | How to Answer |
|----------|---------------|
| What tests cover F-0001? | `coverage.py --test-mapping` |
| What features does notes.py implement? | `coverage.py --reverse src/notes.py` |
| What features have no tests? | `coverage.py --test-mapping --json` (check unmapped) |
| What code implements F-0002? | `grep -r "@feature F-0002" src/` |

## Test Inference Methods

1. **Explicit Naming (High Confidence)**
   - Pattern: `test_F####_*.py` or `test_F-####_*.py`
   - Example: `test_F0001_create_notes.py` → F-0001

2. **Import Tracing (Medium Confidence)**
   - Test imports a file that has `@feature` annotations
   - Example: `test_delete.py` imports `notes.py` which has `@feature F-0003`
