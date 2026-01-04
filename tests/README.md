# Framework Tests

**Purpose**: Minimal test suite validating core claims without overengineering.

**Philosophy**: Framework is in POC/discovery phase - keep tests focused on what we claim the tools do.

---

## Quick Start

```bash
# Run all tests
bash tests/run_tests.sh
```

---

## What We Test

### 1. query_features.py (Core Claim: Fast Filtering)
- ✅ Parse features from markdown
- ✅ Filter by status
- ✅ Filter by tags
- ✅ Filter by layer
- ✅ Combine multiple filters
- ✅ Filter by owner

**Validates**: Query tool works as advertised for 200+ feature projects

### 2. validate_specs.py (Core Claims: Validation)
- ✅ Detect circular dependencies (F-0001 → F-0002 → F-0001)
- ✅ Detect self-dependencies
- ✅ Detect invalid parent references
- ✅ Detect invalid dependency references

**Validates**: Pre-commit validation catches errors before they enter codebase

---

## Test Structure

```
tests/
  fixtures/
    sample_features.md       # Test data (5 features)
  test_query_features.py     # Query tool tests (no deps)
  test_validate_specs.py     # Validation tests (needs yaml)
  run_tests.sh               # Simple runner
  README.md                  # This file
```

---

## Dependencies

**query_features tests**: None (pure Python stdlib)

**validate_specs tests**: Requires:
- `pyyaml`
- `python-frontmatter`
- `jsonschema`

Install if needed:
```bash
pip install pyyaml python-frontmatter jsonschema
```

**Note**: Tests skip gracefully if dependencies not available.

---

## What We DON'T Test

To avoid overengineering in POC phase:
- ❌ Full pytest suite
- ❌ Coverage metrics
- ❌ Integration tests
- ❌ End-to-end tests
- ❌ Performance benchmarks
- ❌ All edge cases

**Why**: Framework is still evolving. Test core claims only.

---

## Adding Tests

When adding new tools, add tests that validate **core claims**:

1. Create `test_<tool_name>.py`
2. Write 3-5 focused tests
3. Test what you claim the tool does
4. Keep it simple (no pytest needed)

**Example**:
```python
#!/usr/bin/env python3
"""Tests for new_tool.py - validates core claim."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "tools"))
from new_tool import some_function

def test_core_claim():
    result = some_function("input")
    assert result == "expected", "Core claim failed"
    print("✓ test_core_claim")

if __name__ == "__main__":
    print("Running new_tool tests...")
    test_core_claim()
    print("\n✅ All new_tool tests passed!")
```

---

## Running Individual Tests

```bash
# Query features only
python3 tests/test_query_features.py

# Validation only
python3 tests/test_validate_specs.py
```

---

## Future (When Framework Matures)

If/when framework moves beyond POC:
- Consider full pytest suite
- Add coverage metrics
- Add performance benchmarks
- Add more edge case tests
- Add CI/CD integration

**For now**: Keep it minimal, test core claims only.

---

## Success Criteria

✅ Core claims validated by tests
✅ Tests run in <5 seconds
✅ No external dependencies for basic tests
✅ Easy to add new tests
✅ Tests catch regressions

**The cobbler's children now have shoes (at least sandals!)** 👞

