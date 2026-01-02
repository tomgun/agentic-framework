# Document Format Specifications

**Purpose**: Define format expectations for all durable artifacts to ensure tool compatibility and enable future evolution.

**Format Version**: v0.1.0 (matches framework version)

---

## Documents with Validated Formats

### Level 1: Strict Format (Schema-Validated)

**Documents**: `spec/FEATURES.md`, `spec/NFR.md`

**Validation**: JSON Schema + optional YAML frontmatter  
**Tools**: `validate_specs.py`, `verify.py`, `doctor.py`  
**Required fields**:
- FEATURES.md: Feature ID (`## F-####`), Status, Dependencies, Acceptance, Tests
- NFR.md: NFR ID (`## NFR-####`), Requirement, Metric, Status

**Format indicator**: Optional YAML frontmatter
```yaml
---
format_version: "0.1.0"
schema: "feature" | "nfr"
---
```

**Evolution**: If format changes, increment version, provide schema for each version

---

### Level 2: Structured Format (Tool-Parsed)

**Documents**: `STATUS.md`, `JOURNAL.md`, `HUMAN_NEEDED.md`, `STACK.md`

**Validation**: Pattern matching by tools (regex-based)  
**Tools**: Multiple tools depend on these formats  
**Format indicators**: HTML comments for versioning

---

#### STATUS.md

**Format version**: 0.1.0

**Required sections** (tools depend on headers):
```markdown
<!-- format: status-v0.1.0 -->

## Current focus
...

## In progress
...

## Next up
...

## Roadmap (lightweight)
...

## Known issues / risks
...

## Decisions needed
...
```

**Tools that parse**:
- `dashboard.sh`: Extracts "Current focus" and "Next up" sections
- `verify.py`: Checks feature ID references
- `doctor.py`: Validates structure

**Format rules**:
- Section headers must be `## [Title]` (H2 level)
- Feature references must be `F-####` format
- Bullet lists use `-` (not `*` or `+`)

---

#### JOURNAL.md

**Format version**: 0.1.0

**Supported entry formats** (choose one per project):

**Format A: Simple**
```markdown
<!-- format: journal-v0.1.0 -->

### Session: YYYY-MM-DD HH:MM
**Feature**: F-####
**Accomplished**:
- ...
**Next steps**:
- ...
**Blockers**:
- ...
```

**Format B: Detailed**
```markdown
<!-- format: journal-v0.1.0 -->

## YYYY-MM-DD HH:MM - Description (Session N)

**Feature**: F-####

**What was done:**
- ...

**Tests added:**
- ...

**What's next:**
- ...

**Blockers:**
- ...

**Lessons:**
- ...
```

**Tools that parse**:
- `dashboard.sh`: Extracts last session (searches for `^## [0-9]` or `^### Session:`)
- `whatchanged.py`: Parses all sessions to show changes by feature
- `report.py`: Aggregates session counts

**Format rules**:
- Session marker must be H2 (`##`) or H3 (`###`) level
- Date must be ISO-ish (`YYYY-MM-DD`)
- Feature references must be `F-####` format
- **Consistency**: Pick one format and stick to it within a project

---

#### HUMAN_NEEDED.md

**Format version**: 0.1.0

**Required structure**:
```markdown
<!-- format: human-needed-v0.1.0 -->

## Active items needing attention

### HN-####: [Title]
- **Type**: decision | bug | refactor | security | external
- **Added**: YYYY-MM-DD
- **Context**:
  - ...
- **Why human needed**:
  - ...
- **Impact**:
  - Blocking: F-####, F-####
  - Affects: ...
```

**Tools that parse**:
- `dashboard.sh`: Counts `### HN-` entries, shows first 5
- `verify.py`: Checks HN ID uniqueness
- `doctor.py`: Validates structure

**Format rules**:
- Entry headers must be `### HN-####: Title` (H3 level, 4-digit ID)
- Required fields: Type, Added, Context, Why human needed, Impact
- Blocking must reference feature IDs (`F-####`)

---

#### STACK.md

**Format version**: 0.1.0

**YAML-like configuration sections**:
```markdown
<!-- format: stack-v0.1.0 -->

## Agentic framework
- Version: X.Y.Z
- Installed: YYYY-MM-DD
- Source: URL

## Testing (required)
- Unit test framework: ...
- Test commands:
  - Unit: `command`
  - Integration: `command`

## Development approach (optional)
- development_mode: tdd | standard

## Git workflow (required)
- git_workflow: direct | pull_request

## Quality validation (recommended)
- quality_checks: enabled | disabled
- profile: profile_name
- run_command: command
```

**Tools that parse**:
- `doctor.py`: Extracts test commands to verify
- `verify.py`: Checks stack configuration validity
- `retro_check.sh`: Reads retrospective settings
- `version_check.sh`: Reads framework version

**Format rules**:
- Configuration as Markdown bullet lists (not actual YAML)
- Boolean values: `yes`/`no` or `enabled`/`disabled`
- Commands must be backtick-quoted
- Framework version tracking required (agentic framework section)

---

### Level 3: Recommended Structure (Not Tool-Parsed)

**Documents**: `CONTEXT_PACK.md`, `spec/OVERVIEW.md`, `spec/LESSONS.md`, ADRs, Retrospectives, Research docs

**Validation**: Template matching only  
**Tools**: `doctor.py` warns if they look like unfilled templates  
**Format indicators**: Not needed (free-form)

**Guidelines**:
- Follow templates for consistency
- No strict validation
- Humans and AI read these holistically

---

## ADRs (Architectural Decision Records)

**Format version**: 0.1.0

**Required structure**:
```markdown
<!-- format: adr-v0.1.0 -->

# ADR-####: [Title]

**Status**: Proposed | Accepted | Deprecated | Superseded  
**Date**: YYYY-MM-DD  
**Deciders**: [Who was involved]

## Context
...

## Decision
...

## Consequences
...

## Related
...
```

**Tools that parse**:
- `verify.py`: Checks ADR ID references
- `doctor.py`: Validates ADR directory structure

---

## Retrospectives

**Format version**: 0.1.0

**Required structure**:
```markdown
<!-- format: retro-v0.1.0 -->

# Retrospective: YYYY-MM-DD

**Duration**: N minutes  
**Scope**: Features F-#### through F-####

## Summary
...

## Metrics
- Features shipped: N
- Tests: N% coverage

## What Went Well
...

## What Needs Improvement
...

## Action Items
| ID | Action | Owner | Due | Status |
|----|--------|-------|-----|--------|
| A-### | ... | ... | ... | ... |

## Next Retrospective
...
```

**Tools that parse**:
- `retro_check.sh`: Reads retrospective date from STATUS.md
- `verify.py`: Validates action item tracking

---

## Format Evolution Strategy

### Version Numbering

**Approach**: Format versions match framework versions

- Format version `0.1.0` → Framework v0.1.0
- Format version `0.2.0` → Framework v0.2.0 (minor format changes)
- Format version `1.0.0` → Framework v1.0.0 (major format changes)

### Version Indicators

**Where to add**:
```markdown
<!-- format: [document-type]-v[X.Y.Z] -->
```

**Examples**:
```markdown
<!-- format: status-v0.1.0 -->
<!-- format: journal-v0.1.0 -->
<!-- format: features-v0.1.0 -->
```

**Placement**: First line or in frontmatter (if using YAML frontmatter)

### Backward Compatibility

**Tools should**:
1. Check format version if present
2. Default to latest format if no version specified
3. Support at least 2 versions back (N, N-1, N-2)
4. Warn if format is too old or too new

**Example validation logic**:
```python
def get_format_version(content: str) -> str:
    """Extract format version from document, default to current if not found."""
    match = re.search(r'<!-- format: \w+-v(\d+\.\d+\.\d+) -->', content)
    if match:
        return match.group(1)
    return CURRENT_VERSION  # e.g., "0.1.0"

def is_compatible(doc_version: str, tool_version: str) -> bool:
    """Check if document format is compatible with tool."""
    # Allow: same major, within 2 minor versions
    # Example: Tool v0.3.0 can read v0.1.0, v0.2.0, v0.3.0
    # But not v0.4.0 or v1.0.0
    ...
```

### Migration

**For new framework versions with format changes**:

1. **Document changes** in `CHANGELOG.md`:
   ```markdown
   ## [0.2.0] - YYYY-MM-DD
   ### Changed
   - JOURNAL.md: Added required "Lessons" field (format: journal-v0.2.0)
   - FEATURES.md: New optional "Performance" section (format: features-v0.2.0)
   ```

2. **Provide migration script** (if needed):
   ```bash
   bash .agentic/tools/migrate_formats.sh --from 0.1.0 --to 0.2.0
   ```

3. **Update templates** with new version indicators

4. **Update tools** to support both old and new formats during transition period

---

## Validation Tool

**New tool**: `validate_formats.py`

```bash
python3 .agentic/tools/validate_formats.py [--strict] [--file PATH]
```

**Checks**:
- Format version compatibility
- Required sections present
- Field formats correct
- Cross-references valid
- Consistency within document type

**Output**:
```
✓ STATUS.md: format-v0.1.0, all sections present
✓ JOURNAL.md: format-v0.1.0, 12 valid entries
✓ FEATURES.md: format-v0.1.0, 8 features validated
⚠ STACK.md: No format version (assuming v0.1.0)
✗ HUMAN_NEEDED.md: Missing required field "Type" in HN-0003
```

---

## Summary Table

| Document | Format Level | Validation | Version Required | Tools Parsing |
|----------|-------------|------------|------------------|---------------|
| FEATURES.md | Strict | JSON Schema | Optional (YAML frontmatter) | verify.py, doctor.py, report.py, consistency.py, validate_specs.py |
| NFR.md | Strict | JSON Schema | Optional (YAML frontmatter) | verify.py, doctor.py |
| STATUS.md | Structured | Regex patterns | Recommended (HTML comment) | dashboard.sh, verify.py, doctor.py |
| JOURNAL.md | Structured | Regex patterns | Recommended (HTML comment) | dashboard.sh, whatchanged.py, report.py |
| HUMAN_NEEDED.md | Structured | Regex patterns | Recommended (HTML comment) | dashboard.sh, verify.py, doctor.py |
| STACK.md | Structured | Key-value parsing | Recommended (HTML comment) | doctor.py, verify.py, retro_check.sh, version_check.sh |
| ADR-*.md | Structured | Header matching | Recommended (HTML comment) | verify.py, doctor.py |
| RETRO-*.md | Structured | Table parsing | Recommended (HTML comment) | retro_check.sh, verify.py |
| CONTEXT_PACK.md | Free-form | Template check | Not needed | doctor.py (template check only) |
| OVERVIEW.md | Free-form | Template check | Not needed | doctor.py (template check only) |
| LESSONS.md | Free-form | Template check | Not needed | doctor.py (template check only) |

---

## Implementation Checklist

For framework v0.1.0:
- [x] FEATURES.md: Schema validation exists (spec_format_validation.md)
- [x] NFR.md: Schema validation exists
- [ ] Add format version indicators to all templates
- [ ] Update tools to check/warn on format versions
- [ ] Create validate_formats.py tool
- [ ] Document format specs (this file)
- [ ] Test format validation in CI

For future versions:
- [ ] Version negotiation logic in tools
- [ ] Migration script framework
- [ ] Format changelog documentation
- [ ] Backward compatibility tests

