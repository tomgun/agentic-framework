# Plan: Tool-Specific Instructions Parity (F-0121)

**Goal**: Ensure Cursor, Codex, and Copilot templates have feature parity with Claude template for enforced gates.

**Revision**: 2 (addressed reviewer feedback)

---

## Definition of Parity

**Parity means**: All templates have the same **enforced gates** and **key workflow sections**.

| Required Element | Description |
|------------------|-------------|
| 6-gate table | Acceptance criteria, WIP, Test execution, Complexity limits, Pre-commit, Feature status |
| Escape hatches | `SKIP_TESTS=1`, `SKIP_COMPLEXITY=1` documented |
| Small batch development | "TOO BIG" trigger, max 5-10 files rule |
| "implement entire" trigger | Trigger word for scope detection |

**NOT in scope** (already present in Codex/Copilot):
- Token-efficient scripts (already there)
- Session protocols (already there)
- Agent boundaries (already there)

---

## Current State Analysis

| Tool | Template | Gates | Missing |
|------|----------|-------|---------|
| **Claude** | `.agentic/agents/claude/CLAUDE.md` | 6 | - |
| **Cursor** | `.agentic/agents/cursor/cursorrules.txt` | 3 | Test execution, Complexity, Feature status, Small batch, Escape hatches |
| **Codex** | `.agentic/agents/codex/codex-instructions.md` | 3 | Test execution, Complexity, Feature status, Small batch, Escape hatches |
| **Copilot** | `.agentic/agents/copilot/copilot-instructions.md` | 3 | Same as Codex |

**Root files**:
- `/CLAUDE.md` - Extends template with framework-dev specifics ✓
- `/CODEX.md` - 61-line stub, should extend template (not delete)
- `/.cursorrules` - Framework-dev only ✓
- `/.github/copilot-instructions.md` - Framework-dev only ✓

---

## Implementation Plan

### Step 1: Create Acceptance Criteria
**File**: `spec/acceptance/F-0121.md`

```markdown
## Acceptance Criteria

- [ ] AC-001: All 4 templates have 6-gate table with identical gate names
- [ ] AC-002: All templates have "Small Batch Development" section with "TOO BIG" response
- [ ] AC-003: All templates document escape hatches (SKIP_TESTS, SKIP_COMPLEXITY)
- [ ] AC-004: All templates have "implement entire" in trigger words table
- [ ] AC-005: /CODEX.md extends template (like /CLAUDE.md pattern)
- [ ] AC-006: validate_framework.sh includes gate parity check
```

### Step 2: Update Cursor Template
**File**: `.agentic/agents/cursor/cursorrules.txt`

Changes (~50 lines added):
- Expand gates table from 3 to 6 gates
- Add escape hatches line after gates table
- Add small batch development section (compact, ~10 lines)
- Add "implement entire" to trigger words

**Format consideration**: Keep Cursor compact. Target ~75-80 lines (not 120). Cursor prefers terse instructions.

### Step 3: Update Codex Template
**File**: `.agentic/agents/codex/codex-instructions.md`

Changes (~35 lines added):
- Update gates table: add 3 missing gates
- Add escape hatches line after gates table
- Add small batch development section
- Add "implement entire" to trigger words table

### Step 4: Update Copilot Template
**File**: `.agentic/agents/copilot/copilot-instructions.md`

Changes (~35 lines added):
- Same changes as Codex (templates are structurally similar)

### Step 5: Make /CODEX.md Extend Template
**File**: `/CODEX.md`

Instead of deleting, follow the `/CLAUDE.md` pattern:
- Keep framework-dev header
- Reference full template location
- Add framework-specific rules

New content (~40 lines):
```markdown
# Codex CLI Instructions - Framework Development

You are working ON the **Agentic Framework** itself.

**Full template**: `.agentic/agents/codex/codex-instructions.md`

## Framework-Specific Rules
[framework-dev rules here, similar to /.github/copilot-instructions.md]
```

### Step 6: Add Validation Check
**File**: `tests/validate_framework.sh`

Add check that all templates have 6 gates:
```bash
# Check template gate parity
for template in .agentic/agents/*/; do
  # Count gates in table
  # Fail if < 6
done
```

### Step 7: Add F-0121 to FEATURES.md
**File**: `spec/FEATURES.md`

Add feature entry with status: in_progress

---

## Files to Modify

| File | Action | Lines Changed |
|------|--------|---------------|
| `spec/acceptance/F-0121.md` | Create | +25 |
| `.agentic/agents/cursor/cursorrules.txt` | Update | +50 |
| `.agentic/agents/codex/codex-instructions.md` | Update | +35 |
| `.agentic/agents/copilot/copilot-instructions.md` | Update | +35 |
| `/CODEX.md` | Rewrite | ~40 (was 61) |
| `tests/validate_framework.sh` | Update | +15 |
| `spec/FEATURES.md` | Update | +25 |

**Total**: 7 files, ~225 lines changed

---

## Verification

1. `bash tests/validate_framework.sh` passes
2. Manual check: grep for 6 gates in each template
3. Verify each acceptance criterion met

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Templates diverge over time | validation check enforces gate count |
| Cursor format issues | Keep compact (~80 lines), test in Cursor |
| Breaking existing workflows | No removal of content, only additions |

---

## Addressed Reviewer Feedback

| Issue | Resolution |
|-------|------------|
| CODEX.md deletion risky | Changed to "extend template" pattern |
| Parity undefined | Added explicit definition table |
| No validation | Added Step 6 for validate_framework.sh |
| Token scripts already exist | Removed from scope, clarified what's missing |
| Cursor 120 lines too long | Reduced target to ~80 lines |

---

## Status

- [x] Acceptance criteria created
- [x] Cursor template updated
- [x] Codex template updated
- [x] Copilot template updated
- [x] /CODEX.md extends template
- [x] Validation check added
- [x] FEATURES.md updated

**IMPLEMENTATION COMPLETE** - All validation checks pass (162 passed, 0 failed)
