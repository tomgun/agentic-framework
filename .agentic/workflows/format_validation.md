# Format Validation & Expectations

**Purpose**: Document expected formats for files parsed by framework tools, and provide validation to catch format inconsistencies early.

## Problem

Tools parse markdown files using regex/sed to extract structured data. Format inconsistencies cause:
1. Tools failing silently or showing errors
2. Data not being extracted correctly
3. Reports showing "No data found" when data exists

## Solution

Define explicit format expectations and provide validation tools.

---

## Files Parsed by Tools

### 1. FEATURES.md

**Format expectation:**
```markdown
## F-####: Feature name
- Status: shipped | in_progress | planned | deprecated
- Dependencies: F-####, F-####
- Acceptance: spec/acceptance/F-####.md
- Implementation:
  - State: complete | partial | not_started
  - Code: path/to/file.ext
- Tests:
  - Unit: complete | partial | none
  - Integration: complete | partial | none
  - Acceptance: complete | partial | none
```

**Parsed by:**
- `report.py`: Feature status summary
- `doctor.py`: Feature validation
- `verify.py`: Cross-reference checking
- `consistency.py`: Code/spec alignment
- `deps.py`: Dependency analysis
- `feature_graph.py`: Dependency visualization
- `coverage.py`: Test coverage per feature

**Critical patterns:**
- Feature headers: `^## (F-\d{4}):` (level 2 heading)
- Key-value pairs: `^- Key: value` (bullet list with colon)
- Status values: Must be one of: shipped, in_progress, planned, deprecated

---

### 2. JOURNAL.md

**Format expectation (TWO FORMATS SUPPORTED):**

**Format A (Template default):**
```markdown
### Session: YYYY-MM-DD HH:MM
**Feature**: F-####
**Accomplished**:
- Item 1
- Item 2
**Next steps**:
- Item 1
**Blockers**:
- Item 1
```

**Format B (Examples use):**
```markdown
## YYYY-MM-DD HH:MM - Description (Session N)

**Feature**: F-####

**What was done:**
- Item 1
- Item 2

**Tests added:**
- Test 1

**What's next:**
- Item 1

**Blockers:**
- Item 1

**Lessons:**
- Lesson 1
```

**Parsed by:**
- `dashboard.sh`: Extract last session for display
- `whatchanged.py`: Parse all sessions for changelog

**Critical patterns:**
- Session headers: `^### Session:` OR `^## \d{4}-\d{2}-\d{2}`
- Date formats: `YYYY-MM-DD HH:MM` or `YYYY-MM-DD-HHMM` or `YYYY-MM-DD`
- Bold sections: `**Accomplished**:`, `**What was done:**`, etc.

**Issue found**: Template shows `### Session:` but examples use `## YYYY-MM-DD`. Tools now support both.

---

### 3. STATUS.md

**Format expectation:**
```markdown
## Current focus
- What we're doing now

## In progress
- F-#### or tasks

## Next up
- F-#### or tasks

## Roadmap (lightweight)
- Near-term: items
- Later: items

## Retrospectives (optional)
- Last retrospective: YYYY-MM-DD (docs/retrospectives/RETRO-YYYY-MM-DD.md)
- Features shipped since last: [N]
```

**Parsed by:**
- `dashboard.sh`: Extract "Current focus" and "Next up" sections
- `retro_check.sh`: Extract retrospective dates and feature counts
- `consistency.py`: Extract "In progress" section

**Critical patterns:**
- Section headers: `^## Section Name` (level 2 heading)
- Sections end at next `##` or EOF
- Retrospective date: `Last retrospective: YYYY-MM-DD`
- Feature count: `Features shipped since last: [N]`

---

### 4. HUMAN_NEEDED.md

**Format expectation:**
```markdown
## Active items needing attention

### HN-####: Short description
- **Type**: decision | bug | refactor | security | external
- **Added**: YYYY-MM-DD
- **Context**:
  - Details
- **Why human needed**:
  - Reason
```

**Parsed by:**
- `dashboard.sh`: Count and list HN-#### items

**Critical patterns:**
- Item headers: `^### HN-\d{4}:` (level 3 heading)
- Must be under "## Active items" section

---

### 5. STACK.md

**Format expectation:**
```yaml
# YAML-like key-value pairs in markdown

## Section
- key: value
- another_key: value with spaces

## Retrospectives (optional)
- retrospective_enabled: yes
- retrospective_trigger: both
- retrospective_interval_days: 14
- retrospective_interval_features: 10
```

**Parsed by:**
- `retro_check.sh`: Extract retrospective configuration
- (Other tools read but don't parse structure)

**Critical patterns:**
- Key-value pairs: `^\s*-?\s*key:\s*value`
- Boolean values: `yes` or `no`
- Trigger values: `time`, `features`, or `both`

---

### 6. NFR.md

**Format expectation:**
```markdown
## NFR-####: NFR name
- **Requirement**: description
- **Metric**: measurable criterion
- **Affected features**: F-####, F-####
- **Verification**: how to verify
- **Status**: met | not_met | in_progress
```

**Parsed by:**
- `doctor.py`: Validate NFR IDs exist
- `verify.py`: Check NFR references

**Critical patterns:**
- NFR headers: `^## (NFR-\d{4}):` (level 2 heading)

---

## Format Validation Tool

See: `.agentic/tools/validate_formats.py` (to be created)

**What it checks:**
1. FEATURES.md: Feature headers, status values, required fields
2. JOURNAL.md: Session headers (both formats), date formats
3. STATUS.md: Required sections present
4. HUMAN_NEEDED.md: HN-#### items properly formatted
5. NFR.md: NFR headers valid

**When to run:**
- Before commits (optional git hook)
- Via `bash .agentic/tools/doctor.sh` (includes format check)
- In CI (catch format regressions)

---

## Migration Guide

### If you're using old format:

**JOURNAL.md:**
- Old: `### Session: YYYY-MM-DD HH:MM`
- New: `## YYYY-MM-DD HH:MM - Description (Session N)` OR keep old (both work)
- **Action**: None required (both formats supported)

**STATUS.md:**
- Old: Free-form sections
- New: Structured sections with `##` headers
- **Action**: Ensure sections use `##` level 2 headings

**FEATURES.md:**
- Old: Free-form feature descriptions
- New: Structured key-value pairs
- **Action**: Use `- Key: value` format for all metadata

---

## Recommendations

### For New Projects:
- Use templates as-is (they follow correct format)
- Run `python3 .agentic/tools/validate_formats.py` after init

### For Existing Projects:
- Run format validation tool to identify issues
- Fix critical issues (FEATURES.md structure)
- Non-critical issues (JOURNAL format) can wait

### For Framework Maintainers:
- Keep templates and tools in sync
- Document all format changes in CHANGELOG
- Update validation tool when adding new parsers

---

## Future Improvements

1. **YAML Frontmatter** (already planned for FEATURES.md via spec validation)
2. **JSON Schema** for all structured files
3. **Format auto-fix** tool (not just validation)
4. **IDE plugins** to validate formats in real-time
5. **Template linting** in CI to catch template/tool mismatches

