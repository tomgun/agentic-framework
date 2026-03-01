# Plan: Spec-Writing Workflow with Delta Tracking & Plan-Review Gate

## Context

**Why specs exist**: Specs are **contracts that protect working features from AI agents accidentally changing them**. Once shipped, acceptance criteria and tests are the proof it works. Modifying them requires justification and tracking.

**What's broken**:
1. No delta tracking — 1 migration across 108+ features, no change history
2. No spec-writing workflow — `managing-specs` skill only handles status updates
3. No plan-review enforcement — `plan_review_enabled: yes` in STACK.md but unchecked
4. NFRs disconnected from feature spec workflow
5. Agents can modify shipped specs without justification or migration
6. No pre-commit gate blocks changes to shipped specs — protection is purely advisory
7. Existing Check 2 in pre-commit-check.sh has a grep bug: `Status: shipped` doesn't match `**Status**: shipped` format in FEATURES.md — silently passes with "No shipped features to check"

**What works** (we build on this, not replace):
- `pre-commit-check.sh` (13 gates), `drift.sh`, `consistency.py`, `nfr_validator.py`
- `migration.sh` (fully functional, just unused)
- `[Discovered]` marker convention

**Multi-tool requirement**: The framework supports Claude Code, Cursor, Copilot, and Codex:
- **`.agentic/`** = tool-agnostic canonical source (workflows, tools, checklists)
- **`.claude/skills/`** = Claude Code-specific wrappers that bundle `.agentic/` content
- **`ag` commands** = tool-agnostic gateway (works from any terminal)
- **`auto_orchestration.md`** = playbook for non-Claude tools

**Workflow logic lives in `.agentic/` first**, then gets wrapped as a Claude skill.

**FEATURES.md format note**: Status is stored as `**Status**: shipped` (markdown bold), NOT `Status: shipped`. All grep patterns must account for the `**` wrapping.

---

## Architecture: Two Layers

### Layer A: Tool-Agnostic (`.agentic/`) — works with ANY tool

| Component | File | Purpose |
|-----------|------|---------|
| **Workflow doc** | `.agentic/workflows/spec_writing.md` | Canonical spec-writing workflow with protection levels, NFR integration, delta tracking |
| **Checklist** | `.agentic/checklists/spec_writing.md` | Step-by-step checklist agents can follow |
| **Health script** | `.agentic/tools/check-spec-health.sh` | Validation combining existing validators |
| **Pre-commit gate** | `.agentic/hooks/pre-commit-check.sh` (edit) | **Deterministic enforcement**: block shipped spec changes without migration |
| **`ag spec` command** | `.agentic/tools/ag.sh` (edit) | Tool-agnostic entry point |
| **Auto-orchestration** | `.agentic/agents/shared/auto_orchestration.md` (edit) | Add spec-writing pipeline for non-Claude tools |
| **Acceptance template** | `.agentic/spec/acceptance.template.md` (edit) | Add NFR Compliance section |

### Layer B: Claude Code-Specific (`.claude/skills/`)

| Component | File | Purpose |
|-----------|------|---------|
| **Skill definition** | `.claude/skills/writing-specs/SKILL.md` | Claude skill wrapper with triggers |
| **Skill definition (template)** | `.agentic/agents/claude/skills/writing-specs/SKILL.md` | Canonical source (dogfooding) |
| **References** | `.claude/skills/writing-specs/references/` | Copies of `.agentic/` workflow docs |
| **Gate script** | `.claude/skills/implementing-features/scripts/check-gates.sh` (edit) | Plan-review gate |

---

## Changes

### 0. Prerequisite: Fix migration index integrity

**File**: `spec/migrations/`

There are two files with `001_` prefix (`001_add_f0101_...` and `001_add_realtime_notifications.md`). Fix the numbering and update `_index.json` before building on top of migration.sh.

### 1. Create `.agentic/workflows/spec_writing.md` (NEW — canonical workflow)

Tool-agnostic source of truth for how specs are written and protected.

**Five scenarios with protection levels**:

| Scenario | Protection Level | Key Rules |
|----------|-----------------|-----------|
| **New Feature Spec** | None — creating fresh | Check NFRs, create FEATURES.md entry + acceptance file + migration |
| **Update Planned/In-Progress Spec** | Low | Show existing, update, migration if significant |
| **Evolve Shipped Feature Spec** | **HIGH — contract** | NEVER delete criteria, additive-only with markers, justification required, migration mandatory, human approval |
| **Spec Evolution During Implementation** | Medium | Additive `[Discovered]` entries only, migration, journal entry |
| **Audit** | Read-only | Run health checks + drift detection |

**Contract protection rules** (shipped features):
- NEVER delete existing acceptance criteria — only add with markers
- NEVER modify existing test expectations without justification
- NEVER weaken criteria — if a criterion is wrong, mark `[Revised in M-NNN: was "X" now "Y"]` preserving old text
- Every change creates a migration with: what changed, why, impact on tests
- Human must approve shipped-spec modifications

**NFR integration**:
- Read `spec/NFR.md` and identify applicable NFRs for any new feature
- Add `Related NFRs:` to FEATURES.md entry
- Add `### NFR Compliance` section to acceptance criteria
- For shipped features, check if spec change would violate linked NFRs

**New feature workflow**:
1. Find next F-XXXX ID
2. Check NFR.md for applicable constraints
3. Create FEATURES.md entry (Status: planned) with Related NFRs
4. Create `spec/acceptance/F-XXXX.md` (Tests, Acceptance Criteria, Out of Scope, NFR Compliance)
5. Show draft to user for approval
6. `migration.sh create "Add F-XXXX [Name]"` → fill template
7. Validate with `check-spec-health.sh F-XXXX`
8. Handoff: "Run `ag plan F-XXXX` before implementing"

### 2. Create `.agentic/checklists/spec_writing.md` (NEW)

Concise checklist version of the workflow (follows pattern of `feature_implementation.md`, `before_commit.md`). This is what `ag spec` prints to stdout for non-Claude tools.

### 3. Create `.agentic/tools/check-spec-health.sh` (NEW)

Lives in `.agentic/tools/` so ALL tools can use it.

Validates:
- Feature exists in FEATURES.md
- Acceptance file has required sections (Tests, Acceptance Criteria, Out of Scope)
- Related NFRs listed if applicable
- Migration exists for feature (info for old, required for new going forward)
- For shipped features: all criteria checked (`[x]`), test files referenced in `## Tests` section exist
- Calls `consistency.py` and `nfr_validator.py` for deep checks
- Supports `--all` flag and `F-XXXX` for single feature

### 4. Add shipped-spec protection gates to `pre-commit-check.sh` (CRITICAL)

**File**: `.agentic/hooks/pre-commit-check.sh`

**This is the most important change** — makes shipped-spec protection deterministic, not advisory.

**PREREQUISITE**: Fix the grep pattern bug in existing Check 2. The current pattern `Status: shipped` does NOT match `**Status**: shipped` in FEATURES.md. The correct pattern for detecting shipped features is:
```bash
# CORRECT: matches "**Status**: shipped" format
grep -A5 "^## ${FID}:" spec/FEATURES.md | grep -i "status.*shipped"
```
Fix Check 2 first, then add new checks using the correct pattern.

**Also update check counter** from `/13]` to `/16]` in all echo strings and the header comment.

**Check 14: Shipped spec changes require migration**
```bash
SHIPPED_SPEC_STAGED=$(git diff --cached --name-only | grep -E "^spec/acceptance/(F|NFR)-[0-9]+\.md$")
if [[ -n "$SHIPPED_SPEC_STAGED" ]]; then
    for spec_file in $SHIPPED_SPEC_STAGED; do
        FID=$(basename "$spec_file" .md)
        # Use pattern that matches **Status**: shipped format
        IS_SHIPPED=$(grep -A5 "^## ${FID}:" spec/FEATURES.md | grep -i "status.*shipped")
        if [[ -n "$IS_SHIPPED" ]]; then
            MIGRATION_STAGED=$(git diff --cached --name-only | grep -E "^spec/migrations/[0-9]+.*\.md$")
            if [[ -z "$MIGRATION_STAGED" ]] || ! git diff --cached -- $MIGRATION_STAGED | grep -q "$FID"; then
                echo "FAIL Shipped feature $FID acceptance criteria modified without migration"
                echo "  Create: bash .agentic/tools/migration.sh create 'Update $FID ...'"
                FAILURES=$((FAILURES + 1))
            fi
        fi
    done
fi
```
Note: regex covers both `F-XXXX` and `NFR-XXXX` acceptance files.

**Check 15: Deleting test files referenced by shipped features**
```bash
DELETED_TEST_FILES=$(git diff --cached --diff-filter=D --name-only | grep -E "^tests/")
if [[ -n "$DELETED_TEST_FILES" ]]; then
    for test_file in $DELETED_TEST_FILES; do
        REFERENCING_SPECS=$(grep -rl "$test_file" spec/acceptance/ 2>/dev/null)
        for spec in $REFERENCING_SPECS; do
            FID=$(basename "$spec" .md)
            IS_SHIPPED=$(grep -A5 "^## ${FID}:" spec/FEATURES.md | grep -i "status.*shipped")
            if [[ -n "$IS_SHIPPED" ]]; then
                echo "FAIL Cannot delete $test_file — referenced by shipped feature $FID"
                FAILURES=$((FAILURES + 1))
            fi
        done
    done
fi
```

**Check 16: Status downgrade protection for shipped features**

Prevents the attack vector where an agent changes `shipped` → `in_progress` to bypass Check 14:
```bash
if git diff --cached --name-only | grep -q "^spec/FEATURES.md$"; then
    # Look for lines where "shipped" was removed (- line) for any feature
    DOWNGRADED=$(git diff --cached spec/FEATURES.md | grep -E "^-.*Status.*shipped" | grep -oE "F-[0-9]+")
    if [[ -n "$DOWNGRADED" ]]; then
        echo "FAIL Shipped feature status downgraded: $DOWNGRADED"
        echo "  Shipped features cannot be un-shipped without explicit migration"
        FAILURES=$((FAILURES + 1))
    fi
fi
```

### 5. Update acceptance template with NFR section

**File**: `.agentic/spec/acceptance.template.md`

Add `### NFR Compliance` section so new specs get it from the start:
```markdown
### NFR Compliance
<!-- List any NFRs that constrain this feature. Remove if none apply. -->
- [ ] NFR-XXXX: Description
```

### 6. Add `spec` command to `ag.sh`

**File**: `.agentic/tools/ag.sh`

Follow the pattern of existing `cmd_specs` function (line ~1839):
```
ag spec              → Print spec_writing checklist, prompt for new feature
ag spec F-XXXX       → Show spec status, prompt for updates
ag spec --check      → Run check-spec-health.sh --all
```

### 7. Add spec-writing pipeline to `auto_orchestration.md`

**File**: `.agentic/agents/shared/auto_orchestration.md`

Add a full pipeline (following the Feature Pipeline pattern at lines 126-180):

```markdown
### Spec-Writing Pipeline

**Triggers**: "write spec", "create spec", "add acceptance criteria", "spec for F-XXXX", "update spec", "evolve spec", "ag spec"

1. IDENTIFY SCENARIO
   - New feature (no F-XXXX exists) → go to 2
   - Existing feature → check Status field
     - planned/in_progress → Low protection, go to 3
     - shipped → HIGH protection (contract modification), go to 4

2. NEW FEATURE SPEC
   a. Find next F-XXXX ID
   b. Read spec/NFR.md → identify applicable NFRs
   c. Create FEATURES.md entry (Status: planned, Related NFRs)
   d. Create spec/acceptance/F-XXXX.md from template
   e. Show to user for approval
   f. Run: migration.sh create "Add F-XXXX [Name]"
   g. Run: check-spec-health.sh F-XXXX
   h. Handoff: "ag plan F-XXXX"

3. UPDATE PLANNED/IN-PROGRESS SPEC
   a. Read current acceptance criteria
   b. Update criteria
   c. Migration if significant (adding/removing criteria, scope change)
   d. Show to user for approval

4. EVOLVE SHIPPED SPEC (CONTRACT MODIFICATION)
   a. Read current acceptance criteria + linked tests + NFR references
   b. Show current state to user
   c. NEVER delete existing criteria — additive only with [Discovered]/[Revised] markers
   d. Require justification (captured in migration)
   e. Run: migration.sh create "Evolve F-XXXX: [reason]"
   f. Run: drift.sh --check
   g. Show changes to user — human MUST approve
```

### 8. Rename `managing-specs` → `writing-specs` Claude skill (BOTH locations)

**Dirs to rename**:
- `.claude/skills/managing-specs/` → `.claude/skills/writing-specs/`
- `.agentic/agents/claude/skills/managing-specs/` → `.agentic/agents/claude/skills/writing-specs/`

Rewrite SKILL.md as Claude-native wrapper:
- YAML frontmatter with trigger descriptions (covers BOTH spec writing AND status management)
- References canonical `.agentic/workflows/spec_writing.md`
- Bundles in `references/`:
  - `spec_writing.md` ← from `.agentic/workflows/spec_writing.md`
  - `spec_evolution.md` ← from `.agentic/workflows/spec_evolution.md`
  - `spec_protection.md` ← **NEW** (see below)

**`spec_protection.md`** content outline:
- What "shipped" means for spec mutability
- What an agent CAN do (add `[Discovered]` criteria, add tests, add NFR references)
- What an agent CANNOT do (delete criteria, weaken tests, modify shipped expectations without migration)
- The marker system: `[Discovered]`, `[Revised in M-NNN: was "X" now "Y"]`, `[Future]`
- How tests lock acceptance criteria (test deletion blocked by pre-commit)
- NFR cross-references and compliance
- The pre-commit gate: shipped spec changes blocked without migration

### 9. Add plan-review gate to `implementing-features`

**File**: `.claude/skills/implementing-features/scripts/check-gates.sh`

New Gate 4. **Note**: Plan files use two naming conventions (`2026-02-09-F-0123-plan.md` and `F-0143-skills-primary-plan.md`), so use `find` with glob pattern instead of hardcoded path:
```bash
# Gate 4: Approved plan required (if plan_review_enabled in STACK.md)
PLAN_REVIEW=$(grep "plan_review_enabled:" STACK.md 2>/dev/null | head -1 | awk '{print $NF}')
if [[ "$PLAN_REVIEW" == "yes" ]]; then
    PLAN_FILE=$(find .agentic-journal/plans/ -name "*${FEATURE_ID}*plan*.md" -print -quit 2>/dev/null)
    if [[ -n "$PLAN_FILE" ]] && grep -q "Status.*APPROVED" "$PLAN_FILE"; then
        echo "OK Approved plan exists: $PLAN_FILE"
    else
        echo "FAIL plan_review_enabled but no approved plan for $FEATURE_ID"
        echo "  Run: ag plan $FEATURE_ID"
        ERRORS=$((ERRORS + 1))
    fi
fi
```

Enforces: **spec → plan (with review) → implement**. No skipping.

---

## Files Summary

| # | File | Action | Layer |
|---|------|--------|-------|
| 0a | `spec/migrations/` | Fix duplicate 001_* numbering | Prerequisite |
| 0b | `.agentic/hooks/pre-commit-check.sh` | **Fix** Check 2 grep pattern (`Status:` → `status.*shipped`) | Prerequisite |
| 1 | `.agentic/workflows/spec_writing.md` | **Create** | Tool-agnostic |
| 2 | `.agentic/checklists/spec_writing.md` | **Create** | Tool-agnostic |
| 3 | `.agentic/tools/check-spec-health.sh` | **Create** | Tool-agnostic |
| 4 | `.agentic/hooks/pre-commit-check.sh` | **Edit** (Checks 14-16 + counter update) | Tool-agnostic |
| 5 | `.agentic/spec/acceptance.template.md` | **Edit** (NFR section) | Tool-agnostic |
| 6 | `.agentic/tools/ag.sh` | Edit (add `spec` cmd) | Tool-agnostic |
| 7 | `.agentic/agents/shared/auto_orchestration.md` | Edit (spec pipeline) | Tool-agnostic |
| 8a | `.claude/skills/managing-specs/` → `writing-specs/` | Rename + rewrite | Claude-specific |
| 8b | `.agentic/agents/claude/skills/managing-specs/` → `writing-specs/` | Rename + rewrite | Claude-specific (template) |
| 8c | `.claude/skills/writing-specs/references/spec_protection.md` | **Create** | Claude-specific |
| 8d | `.claude/skills/writing-specs/references/spec_writing.md` | Create (copy) | Claude-specific |
| 8e | `.claude/skills/writing-specs/references/spec_evolution.md` | Create (copy) | Claude-specific |
| 9 | `.claude/skills/implementing-features/scripts/check-gates.sh` | Edit (Gate 4) | Claude-specific |
| 10 | `.agentic/tools/generate-skills.sh` | **Edit** (rename mapping + references) | Build tooling |
| 11 | `tests/validate_skills.sh` | **Edit** (expected skills list) | Tests |
| 12 | `spec/FEATURES.md` | **Edit** (add F-XXXX for this feature) | Meta |
| 13 | `spec/acceptance/F-XXXX.md` | **Create** (this feature's acceptance criteria) | Meta |
| 14 | `VERSION` | **Edit** (patch bump) | Meta |

---

## Implementation Order (3 phases for manageable commits)

### Phase 1: Enforcement (highest value, fixes existing bugs)
1. Fix migration index integrity (duplicate 001_*)
2. Fix Check 2 grep pattern in pre-commit-check.sh
3. Add Checks 14-16 to pre-commit-check.sh (shipped spec protection, test protection, status downgrade)
4. Create `check-spec-health.sh`
5. Update acceptance template with NFR section
- **~5 files, commit boundary here**

### Phase 2: Workflow (tool-agnostic content)
6. Create `spec_writing.md` workflow
7. Create `spec_writing.md` checklist
8. Add `ag spec` to `ag.sh` (note: `ag specs` already exists for brownfield — name with care)
9. Add pipeline to `auto_orchestration.md`
- **~4 files, commit boundary here**

### Phase 3: Claude integration + meta
10. Rename and rewrite Claude skill (both locations)
11. Update `generate-skills.sh` (skill rename mapping + new references)
12. Update `validate_skills.sh` (expected skills list)
13. Add Gate 4 to `check-gates.sh`
14. Track as feature in FEATURES.md + acceptance criteria
15. VERSION bump
- **~7 files, commit boundary here**

---

## What This Does NOT Change

- `planning-features` skill — already has the plan-review loop
- `implementing-features` SKILL.md — unchanged (only check-gates.sh gets Gate 4)
- `migration.sh`, `drift.sh`, `manifest.sh` — used as-is
- `consistency.py`, `verify.py`, `nfr_validator.py` — called by check-spec-health.sh
- FEATURES.md format — unchanged
- Cursor/Copilot/Codex instruction files — they already reference auto_orchestration.md

---

## Known Design Decisions

- **No escape hatch for Checks 14-16**: Deliberate. Shipped spec protection should not be skippable. If an internal refactor needs to modify shipped specs, it must create a migration documenting the change — this is actually valuable, not just overhead.
- **`[Revised in M-NNN]` marker**: New convention (not yet in tooling). Start as advisory in spec_protection.md; add validation to check-spec-health.sh later if adoption warrants it.
- **`ag spec` vs `ag specs`**: Existing `ag specs` is for brownfield spec generation. Consider naming the new command `ag spec` (singular = one feature) vs `ag specs` (plural = batch). Document the distinction in ag.sh help text.
- **Backward compat**: `check-spec-health.sh --all` will produce info-level messages for 100+ features without migrations. These are INFO, not ERROR. Only features added after this feature ships require migrations.
- **WIP check**: Add a warning (not a block) in spec_writing workflow when WIP.md exists for the feature being modified.

---

## Verification

1. **Pre-commit grep fix**: Verify Check 2 now correctly detects shipped features (was silently passing before)
2. **Shipped spec enforcement**: Modify a shipped feature's acceptance criteria without creating a migration → verify commit is BLOCKED
3. **Test protection**: Delete a test file referenced by a shipped feature → verify commit is BLOCKED
4. **Status downgrade**: Change a shipped feature to in_progress → verify commit is BLOCKED
5. **New feature flow**: Say "write spec for X" → verify FEATURES.md entry + acceptance file + migration, NFRs checked
6. **Multi-tool**: Run `ag spec` from plain terminal → verify checklist prints and guides user
7. **Plan-review gate**: `ag implement F-XXXX` without approved plan → blocks
8. **Health check**: `ag spec --check` → runs validators and reports issues
9. **Skill generation**: `bash .agentic/tools/generate-skills.sh` succeeds with renamed skill
10. **Framework validation**: `bash tests/validate_framework.sh` passes
