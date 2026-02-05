# Documentation Overlap Analysis

## Executive Summary

**Status**: ⚠️ **MODERATE OVERLAP DETECTED**

We have some duplication, particularly around:
1. Script explanations (doctor.sh, verify.sh, report.sh)
2. Quick commands
3. Manual operations vs. agent operations

## Detailed Analysis

### 1. DEVELOPER_GUIDE.md (1,532 lines)
**Purpose**: Comprehensive daily usage guide
**Unique Content**:
- Daily workflows (morning/during/evening routines)
- Full script reference (30+ scripts with examples)
- Customization deep-dive
- Troubleshooting section
- Best practices
- Advanced topics

**Overlaps**:
- ❌ Script explanations (doctor.sh, verify.sh, report.sh) - ALSO in MANUAL_OPERATIONS.md
- ❌ Quick commands - ALSO in START_HERE.md
- ❌ Manual operations philosophy - ALSO in MANUAL_OPERATIONS.md

### 2. MANUAL_OPERATIONS.md (415 lines)
**Purpose**: Token-free information retrieval
**Unique Content**:
- Philosophy (save tokens)
- Quick grep/cat commands
- Dashboard script

**Overlaps**:
- ❌ doctor.sh, verify.sh, report.sh explanations - ALSO in DEVELOPER_GUIDE.md
- ❌ Feature finding commands - ALSO in DEVELOPER_GUIDE.md
- ❌ "When to ask agent vs look yourself" - Similar in DEVELOPER_GUIDE.md

### 3. USER_WORKFLOWS.md (700 lines)
**Purpose**: Working with agents (adding features, updating specs)
**Unique Content**:
- Feature creation workflows
- Spec editing workflows
- Agent behavior expectations
- TDD workflow
- Sequential pipeline usage

**Overlaps**:
- ⚠️ Minor: Some "how to add feature" in DEVELOPER_GUIDE too, but much briefer
- ⚠️ Minor: Brief mentions of scripts (doctor, verify) but not detailed

### 4. START_HERE.md (390 lines)
**Purpose**: Quick navigation for newcomers
**Unique Content**:
- Document index
- Framework overview
- Visual structure explanation

**Overlaps**:
- ❌ Quick command reference - ALSO in DEVELOPER_GUIDE.md
- ❌ Script listings (doctor, report, verify) - ALSO in DEVELOPER_GUIDE.md and MANUAL_OPERATIONS.md

### 5. README.md (.agentic/) (300 lines)
**Purpose**: Framework feature list and overview
**Unique Content**:
- Profile comparison
- Feature list
- Workflow list

**Overlaps**:
- ⚠️ Minor: Brief script mentions, but not detailed explanations

## Specific Duplications Found

### 🔴 HIGH: Script Explanations (doctor.sh, verify.sh, report.sh)

**Duplicated in**:
- DEVELOPER_GUIDE.md (lines 397-462+) - DETAILED
- MANUAL_OPERATIONS.md (lines 84-120) - DETAILED
- START_HERE.md (lines 281-286) - BRIEF

**Recommendation**: 
- Keep DETAILED in DEVELOPER_GUIDE.md ONLY
- MANUAL_OPERATIONS.md should REFERENCE DEVELOPER_GUIDE.md
- START_HERE.md should just list commands, not explain

### 🔴 HIGH: Quick Commands

**Duplicated in**:
- DEVELOPER_GUIDE.md (lines 1436-1448) - Full table
- START_HERE.md (lines 353-356) - Full listing
- MANUAL_OPERATIONS.md (lines 333-347) - Full table

**Recommendation**:
- Keep ONE authoritative table in DEVELOPER_GUIDE.md
- Others should reference it

### 🟡 MEDIUM: Manual Operations Philosophy

**Duplicated in**:
- DEVELOPER_GUIDE.md (section "Manual Operations")
- MANUAL_OPERATIONS.md (section "Philosophy")

**Recommendation**:
- MANUAL_OPERATIONS.md can keep brief philosophy
- DEVELOPER_GUIDE.md should REFERENCE MANUAL_OPERATIONS.md for details

### 🟡 MEDIUM: Finding Information

**Duplicated in**:
- DEVELOPER_GUIDE.md (section "Finding Information")
- MANUAL_OPERATIONS.md (section "Finding Specific Information")

**Recommendation**:
- Keep in MANUAL_OPERATIONS.md (that's its purpose)
- DEVELOPER_GUIDE.md should REFERENCE it

## Proposed Refactoring

### DEVELOPER_GUIDE.md (Master Guide)
**Keep**:
- Daily workflows (unique)
- Customization (unique)
- Troubleshooting (unique)
- Best practices (unique)
- Advanced topics (unique)
- Full script reference (this is OK to keep - it's the comprehensive guide)

**Change**:
- Add: "For token-free quick commands, see MANUAL_OPERATIONS.md"

### MANUAL_OPERATIONS.md (Quick Reference)
**Keep**:
- Philosophy (unique angle: save tokens)
- Quick grep/cat commands (core purpose)
- Finding information (core purpose)
- Dashboard script

**Remove**:
- Detailed script explanations (doctor, verify, report)

**Replace with**:
- "For detailed script documentation, see DEVELOPER_GUIDE.md#automation--scripts"
- Keep ONLY the command itself: `bash .agentic/tools/doctor.sh`

### START_HERE.md (Navigation)
**Keep**:
- Document index (unique)
- Framework overview (unique)
- "What files mean" (unique)

**Remove**:
- Detailed quick command reference

**Replace with**:
- "For quick commands: MANUAL_OPERATIONS.md"
- "For comprehensive guide: DEVELOPER_GUIDE.md"

### USER_WORKFLOWS.md (Agent Workflows)
**Status**: ✅ GOOD - Minimal overlap
**Keep as is** - focused on its unique purpose

## Summary of Changes Needed

### Priority 1 (High Impact)
1. ❌ **MANUAL_OPERATIONS.md**: Remove detailed explanations of doctor.sh, verify.sh, report.sh
   - Replace with: "See DEVELOPER_GUIDE.md for detailed script documentation"
   - Keep only: command itself + one-line description

2. ❌ **MANUAL_OPERATIONS.md**: Remove duplicate quick commands table
   - Replace with: "See DEVELOPER_GUIDE.md#quick-reference for full command table"

### Priority 2 (Medium Impact)
3. ⚠️ **START_HERE.md**: Remove quick command reference section
   - Replace with pointers to DEVELOPER_GUIDE.md and MANUAL_OPERATIONS.md

4. ⚠️ **DEVELOPER_GUIDE.md**: Add cross-reference
   - In "Manual Operations" section, add: "For a focused token-saving quick reference, see MANUAL_OPERATIONS.md"

### Priority 3 (Low Impact)
5. 📝 **DEVELOPER_GUIDE.md**: Add note in "Finding Information"
   - "Also see MANUAL_OPERATIONS.md for more quick grep patterns"

## Impact Assessment

**Before Changes**:
- 🔴 3 places explain doctor.sh in detail
- 🔴 3 places have full quick command tables
- 🔴 2 places have detailed "finding information" sections

**After Changes**:
- ✅ 1 place explains doctor.sh in detail (DEVELOPER_GUIDE)
- ✅ 1 place has full quick command table (DEVELOPER_GUIDE)
- ✅ 1 place focused on token-free operations (MANUAL_OPERATIONS)
- ✅ Clear cross-references between docs

**Maintenance Benefit**:
- Update script explanation: 1 place instead of 3
- Add new quick command: 1 place instead of 3
- Less confusion about "which doc is authoritative"

## Recommendation

**Should we proceed with refactoring?**

This will:
- ✅ Reduce duplication by ~40%
- ✅ Make each doc more focused
- ✅ Easier maintenance (single source of truth)
- ⚠️ Requires updating 3 files
- ⚠️ Adds cross-references (need to keep these updated)

**Your call!**

