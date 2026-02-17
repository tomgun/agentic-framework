# Plan: Create .agentic-journal/ Directory Structure

**Goal**: Implement the planned `.agentic-journal/` directory for project history artifacts (JOURNAL, manifests, lessons).

**Revision**: 2 (addressed reviewer feedback)

---

## Context

The plan to create `.agentic-journal/` was noted in `status.json` but not yet implemented. This directory should consolidate:
- **JOURNAL.md** - Session log (currently at project root, move later)
- **manifests/** - Change manifests (currently in `.agentic-state/manifests/`)
- **lessons/** - Operational learnings (new)

This separates **transient state** (`.agentic-state/`: WIP.md, plans/, AGENTS_ACTIVE.md) from **persistent history** (`.agentic-journal/`: accumulated knowledge).

---

## Implementation

### Step 1: Create .agentic-journal/ structure
```
.agentic-journal/
├── README.md          # Documentation of directory purpose
├── manifests/         # Move from .agentic-state/manifests/
└── lessons/           # New: operational learnings
    └── .gitkeep       # Keep empty dir in git
```

### Step 2: Move manifests (preserve git history)
```bash
mkdir -p .agentic-journal/manifests
git mv .agentic-state/manifests/* .agentic-journal/manifests/
```

### Step 3: Create lessons directory
- Create `.agentic-journal/lessons/.gitkeep`
- Add L-0001 about plan-review model selection

### Step 4: Update ALL tools referencing old path
- `.agentic/tools/manifest.sh` - MANIFEST_DIR variable
- `.agentic/tools/drift.sh` - manifest path references
- `.agentic/tools/ag.sh` - lines ~630, 637

### Step 5: Update ALL docs referencing old path
- `spec/FEATURES.md` (F-0119 section)
- `spec/acceptance/F-0119.md`
- `.agentic/checklists/feature_complete.md`
- `.agentic/FRAMEWORK_QUICK_START.md`
- `CONTEXT_PACK.md`
- `.agentic-state/.gitkeep` (remove manifests reference)
- `.gitignore` (update comment about committed files)

### Step 6: Verify no stale references
```bash
grep -r "agentic-state/manifests" . --include="*.md" --include="*.sh"
```

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `.agentic-journal/README.md` | Create - directory documentation |
| `.agentic-journal/manifests/*` | Move via git mv |
| `.agentic-journal/lessons/.gitkeep` | Create |
| `.agentic-journal/lessons/L-0001-plan-review-model-selection.md` | Create |
| `.agentic/tools/manifest.sh` | Update MANIFEST_DIR |
| `.agentic/tools/drift.sh` | Update manifest paths |
| `.agentic/tools/ag.sh` | Update manifest paths |
| `spec/FEATURES.md` | Update F-0119 paths |
| `spec/acceptance/F-0119.md` | Update paths |
| `.agentic/checklists/feature_complete.md` | Update paths |
| `.agentic/FRAMEWORK_QUICK_START.md` | Update paths |
| `CONTEXT_PACK.md` | Update paths |
| `.agentic-state/.gitkeep` | Remove manifests reference |
| `.gitignore` | Update comment |

**Total: 14 files**

---

## Rollback Plan

If issues occur mid-migration:
```bash
git checkout HEAD -- .agentic-state/manifests/
git checkout HEAD -- .agentic/tools/manifest.sh
git checkout HEAD -- .agentic/tools/drift.sh
rm -rf .agentic-journal/
```

---

## First Lesson Content

```markdown
# L-0001: Plan-review loop model selection matters

- **Related**: F-0120 (Plan-Review Loop)
- **What happened**: Used haiku for revision 2 review, got pedantic feedback
- **Why it happened**: Didn't check agent_mode - haiku is economy, should use opus for premium
- **What to do next time**:
  - Check STACK.md agent_mode before spawning reviewers
  - Use opus for reviews in premium mode
  - Use sonnet for reviews in balanced mode
- **Links**: F-0121 implementation, `.agentic/workflows/plan_review_loop.md`
```

---

## Verification

1. `ls .agentic-journal/` shows manifests/ and lessons/
2. `manifest.sh` generates to new location
3. `drift.sh --docs` still works
4. Existing manifests preserved in new location
5. L-0001 lesson file exists

---

## Out of Scope (This Change)

- Creating lessons.sh tool (manual creation is fine for now)
- Feature spec for this change (small infrastructure improvement)

---

## TODO: Next Step

**Move JOURNAL.md to `.agentic-journal/`** - to complete the consolidation:
- Move `JOURNAL.md` → `.agentic-journal/JOURNAL.md`
- Update `journal.sh` to write to new location
- Add symlink or redirect from root for backwards compatibility
- Update all tool/doc references

This should be tracked separately (new task or feature).
