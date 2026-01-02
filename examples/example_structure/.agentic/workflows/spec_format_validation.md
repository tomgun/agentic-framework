# Spec Format & Validation

**Purpose**: Use structured, validatable formats for spec documents to prevent errors, enable tooling, and maintain consistency.

## The Problem with Plain Markdown

**Current state:**
```markdown
## F-0001: User authentication
- Status: in progress  <!-- Typo: should be "in_progress" -->
- Accepted: maybe      <!-- Invalid: should be "yes" or "no" -->
- Tests: Unit: done    <!-- Invalid: should be "complete" -->
```

**Problems:**
- ❌ Typos in field names/values go undetected
- ❌ Missing required fields not caught
- ❌ Invalid field values accepted
- ❌ Hard to query/analyze programmatically
- ❌ No IDE autocomplete/validation

## Solution: Hybrid Markdown + YAML Frontmatter

**Keep the best of both worlds:**
- ✅ Human-readable prose (Markdown)
- ✅ Machine-readable metadata (YAML frontmatter)
- ✅ Schema validation (JSON Schema)
- ✅ IDE support (autocomplete, inline errors)
- ✅ Tooling integration (queries, reports)

### Example: FEATURES.md with YAML Frontmatter

```yaml
---
# Machine-readable frontmatter (validated by schema)
features:
  - id: F-0001
    name: User authentication
    status: in_progress  # Validated against enum
    parent: null
    dependencies: []
    complexity: M  # Validated: S, M, L, XL
    prd: spec/PRD.md#authentication
    requirements: [R-0010, R-0011]
    nfrs: [NFR-0001]
    acceptance: spec/acceptance/F-0001.md
    verification:
      accepted: false  # Validated: boolean
      accepted_at: null
    implementation:
      state: partial  # Validated: none, partial, complete
      code:
        - lib/auth.ts
        - app/api/auth/route.ts
    tests:
      strategy: unit  # Validated enum
      unit: partial
      integration: todo
      acceptance: todo
      perf: n/a
    technical_debt: null
    lessons: []
    notes: Password hashing uses bcrypt

  - id: F-0002
    name: Profile management
    # ... (more features)
---

# Features

Human-readable documentation below this line.
Prose, diagrams, explanations can go here in regular Markdown.

The YAML frontmatter above is the source of truth for structured data.
```

### Benefits

**Validation:**
- Schema enforces field names (no typos)
- Enums validated (only valid status values)
- Required fields checked
- Type checking (dates, booleans, strings)

**Tooling:**
- Parse once, use everywhere
- Query features programmatically
- Generate reports automatically
- IDE autocomplete/validation

**Human-friendly:**
- Still readable as Markdown
- Prose explanations in body
- Diagrams, examples in Markdown

## Implementation Options

### Option 1: YAML Frontmatter (RECOMMENDED)

**Format**: Markdown files with YAML frontmatter

**Pros:**
- ✅ Human-readable (Markdown body)
- ✅ Machine-parseable (YAML frontmatter)
- ✅ Widely supported (Jekyll, Hugo, many tools)
- ✅ JSON Schema validation available
- ✅ IDE support (VS Code, etc.)

**Cons:**
- ⚠️ Need parser to extract/validate frontmatter
- ⚠️ Two formats in one file (YAML + Markdown)

**Tools:**
- Python: `python-frontmatter`, `pydantic`
- Node.js: `gray-matter`, `ajv` (JSON Schema)
- VS Code: YAML extension validates frontmatter

### Option 2: Pure YAML Files

**Format**: `.yaml` files with schema validation

**Pros:**
- ✅ Fully structured
- ✅ Easy validation
- ✅ Great IDE support
- ✅ Easy to query

**Cons:**
- ❌ Less readable for prose
- ❌ No Markdown formatting
- ❌ Separate docs needed for explanations

**When to use:**
- For data-heavy specs (FEATURES, NFR)
- When programmatic access is primary use

### Option 3: JSON Schema + Markdown (Hybrid)

**Format**: Separate `.json` (data) + `.md` (docs)

**Pros:**
- ✅ Clean separation
- ✅ JSON Schema validation
- ✅ Full Markdown for docs

**Cons:**
- ❌ Two files to maintain
- ❌ Can get out of sync
- ❌ More complex setup

### Recommendation: Start with Frontmatter

**Migrate incrementally:**
1. Start with critical specs (FEATURES.md, NFR.md)
2. Add YAML frontmatter with schema
3. Keep Markdown body for prose
4. Add validation to CI/tools

## JSON Schema for Validation

### Example: Feature Schema

**File**: `.agentic/schemas/feature.schema.json`

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["id", "name", "status", "acceptance", "verification", "implementation", "tests"],
  "properties": {
    "id": {
      "type": "string",
      "pattern": "^F-[0-9]{4}$",
      "description": "Feature ID in format F-####"
    },
    "name": {
      "type": "string",
      "minLength": 3,
      "maxLength": 100
    },
    "status": {
      "type": "string",
      "enum": ["planned", "in_progress", "shipped", "deprecated"]
    },
    "parent": {
      "type": ["string", "null"],
      "pattern": "^F-[0-9]{4}$"
    },
    "dependencies": {
      "type": "array",
      "items": {
        "type": "string",
        "pattern": "^F-[0-9]{4}$"
      }
    },
    "complexity": {
      "type": "string",
      "enum": ["S", "M", "L", "XL"]
    },
    "prd": {
      "type": "string"
    },
    "requirements": {
      "type": "array",
      "items": {
        "type": "string",
        "pattern": "^R-[0-9]{4}$"
      }
    },
    "nfrs": {
      "type": "array",
      "items": {
        "type": "string",
        "pattern": "^NFR-[0-9]{4}$"
      }
    },
    "acceptance": {
      "type": "string"
    },
    "verification": {
      "type": "object",
      "required": ["accepted"],
      "properties": {
        "accepted": {
          "type": "boolean"
        },
        "accepted_at": {
          "type": ["string", "null"],
          "format": "date"
        }
      }
    },
    "implementation": {
      "type": "object",
      "required": ["state", "code"],
      "properties": {
        "state": {
          "type": "string",
          "enum": ["none", "partial", "complete"]
        },
        "code": {
          "type": "array",
          "items": {
            "type": "string"
          }
        }
      }
    },
    "tests": {
      "type": "object",
      "required": ["strategy", "unit", "integration", "acceptance"],
      "properties": {
        "strategy": {
          "type": "string",
          "enum": ["unit", "integration", "e2e", "manual", "mixed"]
        },
        "unit": {
          "type": "string",
          "enum": ["todo", "partial", "complete", "n/a"]
        },
        "integration": {
          "type": "string",
          "enum": ["todo", "partial", "complete", "n/a"]
        },
        "acceptance": {
          "type": "string",
          "enum": ["todo", "partial", "complete", "n/a"]
        },
        "perf": {
          "type": "string",
          "enum": ["todo", "partial", "complete", "n/a"]
        }
      }
    },
    "technical_debt": {
      "type": ["string", "null"]
    },
    "lessons": {
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "notes": {
      "type": ["string", "null"]
    }
  }
}
```

## Validation Tools

### Tool 1: Validate Script

**File**: `.agentic/tools/validate_specs.py`

```python
#!/usr/bin/env python3
"""Validate spec files against JSON schemas."""

import sys
import yaml
import frontmatter
import json
from pathlib import Path
from jsonschema import validate, ValidationError, Draft7Validator

def validate_features(features_file: Path, schema_file: Path) -> list[str]:
    """Validate FEATURES.md against schema."""
    errors = []
    
    # Parse frontmatter
    with open(features_file, 'r') as f:
        post = frontmatter.load(f)
    
    # Load schema
    with open(schema_file, 'r') as f:
        schema = json.load(f)
    
    # Validate each feature
    features = post.metadata.get('features', [])
    for feature in features:
        try:
            validate(instance=feature, schema=schema)
        except ValidationError as e:
            errors.append(f"Feature {feature.get('id', 'unknown')}: {e.message}")
    
    return errors

def main():
    root = Path.cwd()
    features_file = root / "spec" / "FEATURES.md"
    schema_file = root / "agentic" / "schemas" / "feature.schema.json"
    
    if not features_file.exists():
        print("No spec/FEATURES.md found")
        return 0
    
    if not schema_file.exists():
        print("No schema file found, skipping validation")
        return 0
    
    errors = validate_features(features_file, schema_file)
    
    if errors:
        print("❌ Validation errors:")
        for error in errors:
            print(f"  - {error}")
        return 1
    else:
        print("✅ All features valid")
        return 0

if __name__ == "__main__":
    sys.exit(main())
```

**Usage:**
```bash
python3 .agentic/tools/validate_specs.py
```

### Tool 2: IDE Integration

**VS Code Settings** (`.vscode/settings.json`):

```json
{
  "yaml.schemas": {
    "./.agentic/schemas/feature.schema.json": [
      "spec/FEATURES.md"
    ],
    "./.agentic/schemas/nfr.schema.json": [
      "spec/NFR.md"
    ]
  },
  "yaml.customTags": [
    "!include scalar"
  ]
}
```

**Benefits:**
- Inline validation errors
- Autocomplete for fields
- Hover documentation
- Jump to schema

### Tool 3: Pre-commit Hook

**File**: `.git/hooks/pre-commit`

```bash
#!/usr/bin/env bash
# Validate specs before commit

python3 .agentic/tools/validate_specs.py
if [ $? -ne 0 ]; then
  echo "❌ Spec validation failed. Fix errors before committing."
  exit 1
fi
```

### Tool 4: CI Integration

**GitHub Actions** (`.github/workflows/validate-specs.yml`):

```yaml
name: Validate Specs

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - name: Install dependencies
        run: pip install pyyaml python-frontmatter jsonschema
      - name: Validate specs
        run: python3 .agentic/tools/validate_specs.py
```

## Adoption for New Projects

**This validation system is designed for new projects initialized with the agentic framework.**

When you initialize a new project:
1. Agent runs scaffold script
2. Creates spec templates with YAML frontmatter already included
3. `validate_specs.py` is ready to use
4. Validation can be enabled in pre-commit hooks or CI

**For existing projects:**
- There is currently no framework upgrade/migration path
- You can continue using plain Markdown specs (works fine)
- If you want validation, you'd need to manually add YAML frontmatter
- We may add migration tools in a future framework version

**Recommendation:** Use this for new projects. Don't try to retrofit existing projects unless you're willing to do manual conversion.

## Alternative: Keep Markdown, Add Linter

**If full validation is too heavy:**

Create a lightweight Markdown linter:

```python
# .agentic/tools/lint_specs.py
"""Lint spec Markdown for common issues."""

import re
from pathlib import Path

def lint_features(file_path: Path) -> list[str]:
    errors = []
    content = file_path.read_text()
    
    # Check for valid status values
    status_pattern = r'- Status:\s*(\w+)'
    for match in re.finditer(status_pattern, content):
        status = match.group(1)
        if status not in ['planned', 'in_progress', 'shipped', 'deprecated']:
            errors.append(f"Invalid status: '{status}'")
    
    # Check for valid feature IDs
    id_pattern = r'## (F-\d{4}):'
    feature_ids = re.findall(id_pattern, content)
    if len(feature_ids) != len(set(feature_ids)):
        errors.append("Duplicate feature IDs found")
    
    # Check for required fields
    feature_blocks = content.split('## F-')
    for block in feature_blocks[1:]:  # Skip intro
        if '- Status:' not in block:
            errors.append(f"Feature missing Status field")
    
    return errors
```

**Pros:**
- ✅ Simpler than full schema validation
- ✅ Still catches common errors
- ✅ No format change needed

**Cons:**
- ⚠️ Less comprehensive than schema
- ⚠️ Custom code to maintain
- ⚠️ No IDE integration

## Recommendation: Start Simple

**For most projects, the current plain Markdown approach is sufficient.**

Use YAML frontmatter validation when:
- ✅ Starting a new project with complex feature dependencies
- ✅ Team project with multiple developers/agents
- ✅ Need programmatic queries of spec data
- ✅ Want IDE autocomplete and inline validation
- ✅ Building tooling on top of specs

**Don't bother with validation if:**
- ❌ Simple solo project with <20 features
- ❌ Existing project (no migration path yet)
- ❌ Prototyping/exploration phase
- ❌ Markdown-only workflow is working fine

The framework works great with plain Markdown specs. Validation is an **optional enhancement**, not a requirement.

1. **Now**: Use current Markdown + `SPEC_SCHEMA.md` documentation
2. **Soon**: Add lightweight linter (`lint_specs.py`) to catch errors
3. **Later**: Migrate critical specs to frontmatter + JSON Schema
4. **Future**: Full validation in CI/pre-commit

**Criteria for full adoption:**
- Team size >3 (coordination benefits)
- >20 features (data benefits)
- Frequent spec errors (validation benefits)
- Need for programmatic queries (tooling benefits)

## Configuration

**In STACK.md:**

```markdown
## Spec format (optional)
- spec_format: markdown_yaml  # markdown | markdown_yaml | yaml
- spec_validation: enabled
- schema_dir: .agentic/schemas
- validate_on_commit: yes
```

**In agent guidelines:**

```markdown
## When editing specs

- If `spec_validation: enabled` in STACK.md:
  - Preserve YAML frontmatter structure
  - Run `python3 .agentic/tools/validate_specs.py` after editing
  - Fix validation errors before continuing
- If frontmatter exists, update it (not just Markdown body)
```

## Benefits Summary

| Benefit | Plain Markdown | Markdown + Linter | Markdown + YAML + Schema |
|---------|----------------|-------------------|--------------------------|
| Human-readable | ✅ | ✅ | ✅ |
| Catch typos | ❌ | ✅ | ✅ |
| Validate enums | ❌ | ✅ | ✅ |
| Type checking | ❌ | ⚠️ | ✅ |
| Required fields | ❌ | ⚠️ | ✅ |
| IDE integration | ❌ | ❌ | ✅ |
| Programmatic query | ⚠️ | ⚠️ | ✅ |
| Setup complexity | Low | Medium | High |

## See Also

- Spec schema: `.agentic/spec/SPEC_SCHEMA.md`
- Validation tools: `.agentic/tools/validate_specs.py`, `lint_specs.py`
- Agent guidelines: `.agentic/agents/shared/agent_operating_guidelines.md`

