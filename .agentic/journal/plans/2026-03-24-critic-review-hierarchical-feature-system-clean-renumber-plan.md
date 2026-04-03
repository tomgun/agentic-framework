# CRITIC Review: Hierarchical Feature System + Clean Renumber

**Plan reviewed**: `/home/node/.claude/plans/vivid-meandering-teacup.md`
**Reviewer role**: Critic (find weaknesses, risks, missing pieces)
**Date**: 2026-03-24

---

## CRITICAL Issues (Must Fix Before Proceeding)

### C1. The Renumber Is Catastrophically Scoped — 10,672 Occurrences Across 1,499 Files

The plan says "grep -rn all old IDs across repo, replace with new" as if this is a simple find-and-replace. The actual numbers:

- **10,672 occurrences** of `F-XXXX` patterns across **1,499 files**
- **727 occurrences** in `validate_framework.sh` alone (96 test sections, many referencing pre-consolidation IDs like F-0002, F-0006, F-0013, F-0037, F-0055, F-0062, F-0066, etc.)
- **1,310 occurrences** across 121 journal files (historical records)
- **136 occurrences** in CHANGELOG.md (historical release notes)
- **246 DEV-XXXX occurrences** across 46 files

The plan calls this "the same mechanical process we just did for F-0122 to DEV-0122, but at scale." This dramatically understates the difference. The DEV-0122 rename touched maybe 20-30 files. This touches **1,499 files** with a combinatorial explosion of possible collisions. A single misfire in the regex (e.g., replacing F-0003 inside the string "F-0003, F-0005, F-0006" in a consolidated_from list) could corrupt contract metadata.

**Recommendation**: The renumber phase must NOT be a "just script it" operation. It needs:
1. A dry-run mode that shows every planned replacement
2. A rollback strategy (tag before renumber, verify after)
3. Explicit rules for what gets renamed vs what stays as-is (historical references)
4. Acceptance tests that run BEFORE and AFTER

### C2. `consolidated_from` Field Contains Dead IDs That Must NOT Be Renumbered

The plan says "consolidated_from semantics — historical, separate from live hierarchy" under "What stays the same." But it does not explicitly address what happens to the consolidated_from values during renumber.

Example from F-0004.yaml:
```yaml
consolidated_from: [F-0004, F-0042, F-0078, F-0109, F-0110, F-0177, F-0178, F-0197]
```

Under the renumber plan, F-0004 becomes F-003. But the consolidated_from list references **dead IDs** (F-0042, F-0078, etc.) that were never live contracts — they were absorbed during consolidation. A naive find-and-replace would:
- Replace `F-0004` inside the array with `F-003` (wrong: this is a historical reference)
- Leave F-0042, F-0078 unchanged (they have no mapping) — creating inconsistency

The schema currently requires `consolidated_from` items to match `^F-[0-9]{4,}$`. If the renumber changes the pattern to `^(F|DEV|E)-[0-9]{3,}(\.[0-9]+)*$`, the old 4-digit dead IDs would still validate, but the live IDs would not. This is a mess.

**Recommendation**: `consolidated_from` must be explicitly excluded from renumbering. The schema pattern for `consolidated_from` must remain `^F-[0-9]{4,}$` as a historical artifact pattern, OR a separate `legacy_id_pattern` must be defined.

### C3. 28 Shipped Contracts Have `protection: contract` — Renumber Triggers Mandatory Migrations

The plan mentions "Contract protection model — shipped contracts require migrations" under "What stays the same" but does NOT address that **28 of 39 contracts are protection: contract**. Renaming the `id` field in a protected contract is a breaking change that requires a formal migration entry.

This means:
- 28 migration entries must be created (one per protected contract)
- Each migration needs an `id`, `date`, `trigger`, `reason`, `changes` array
- The migration must be approved (by user, agent_review, or auto)
- The `_index.json` in migrations/ must be updated

The plan provides zero detail on this. It is not a minor bookkeeping task — it is 28 migration records that must be created atomically with the renumber.

**Recommendation**: Phase 2 must explicitly include migration generation as a required step, with a script that generates all 28 migration entries automatically.

### C4. Dotted IDs Break Shell Parsing Patterns in 52+ Files

The plan introduces `F-003.1.2` as a valid ID. This breaks numerous shell patterns:

1. **`ids.sh` ERE patterns**: `FEATURE_ID_ERE='F-[0-9]{4,}'` does NOT match `F-003.1`. After Phase 1, these become `F-[0-9]{3,}(\.[0-9]+)*` — but ERE does not support `\d`, so the shell regex needs careful rewriting.

2. **`is_feature_id()` bash function**: `[[ "$1" =~ ^F-[0-9]{4,}$ ]]` — this needs updating and the `{4,}` to `{3,}` change means **all existing 4-digit IDs stop matching** during the transition period between Phase 1 (schema change) and Phase 2 (renumber).

3. **File globbing with dots**: Contract files would be named `F-003.1.yaml`. Globs like `*.yaml` still work, but any script doing `basename -s .yaml "$file"` to extract the ID would get `F-003.1` — which is correct. However, any script using `cut -d. -f1` or similar dot-splitting would break.

4. **52 shell scripts** import from `ids.sh` or define their own feature ID patterns. Each must be audited.

5. **FEATURES.md header pattern**: `FEATURE_HEADER_RE = re.compile(r"^##\s+(F-\d{4,}):\s*(.+?)\s*$")` — this would need to become `r"^##\s+(F-\d{3,}(?:\.\d+)*):\s*(.+?)\s*$"` but the dot-group makes the regex more complex and error-prone.

**Recommendation**: Create a comprehensive compatibility matrix showing every file that parses feature IDs and what changes are needed. Phase 1 MUST support both old 4-digit and new 3-digit+dotted patterns simultaneously during the transition window.

### C5. The 4-Digit to 3-Digit Change Has a Transition Gap

Phase 1 changes the schema pattern from `{4,}` to `{3,}`. Phase 2 does the actual renumber. Between these two PRs, the system must accept BOTH 4-digit (existing) and 3-digit (new) IDs. But:

- `format_feature_id()` currently zero-pads to 4 digits: `f"F-{n:04d}"`. After Phase 1 it presumably changes to 3-digit padding. But existing IDs are still 4-digit.
- `get_next_feature_id()` scans for `r"^## F-(\d{4,}):"` — this would miss 3-digit IDs.
- The `_ID_PATTERN` in contracts.py is `r"^(F|NFR)-\d{4,}$"` — note it does NOT include DEV, which is already a bug. But changing to `{3,}` means F-001 through F-099 become valid, which they currently are not.

**Recommendation**: Phase 1 must be a **backward-compatible extension only** — accept 3-digit OR 4-digit. The format functions must NOT change until Phase 2 is ready to land. This requires careful sequencing that the plan does not address.

---

## IMPORTANT Concerns (Should Address)

### I1. validate_framework.sh References 96 Pre-Consolidation Feature IDs

The plan's renumber table maps ~35 consolidated features. But `validate_framework.sh` still has 96 test sections referencing individual pre-consolidation IDs (F-0002, F-0006, F-0013, F-0037, F-0055, F-0062, F-0066, F-0071, F-0073, F-0074, F-0078, F-0080, F-0083, F-0084, F-0091, etc.). These are NOT in the renumber mapping because they were absorbed into consolidated features.

The renumber script would try to replace these IDs but has no mapping for them. Either:
- They get left as-is (broken references)
- They get mapped to their consolidated parent (loss of granularity)
- They get removed (loss of test coverage)

**Recommendation**: Phase 2 must include a strategy for `validate_framework.sh` — likely a separate task to restructure tests around consolidated contract IDs rather than a mechanical rename.

### I2. Planned/Unshipped Features Are Missing from the Renumber Table

The plan's mapping table covers ~35 features. But FEATURES.md and BACKLOG.json contain unshipped features that also need renumbering:

- F-0211: Project-Specific Customization Layer
- F-0212: Project Customization Auto-Sync
- F-0220: Protected Main Branch Support
- F-0228: Workflow Definition File
- F-0230: MCP Coordination Server
- F-0231: Multi-Repo Umbrella
- F-0232: Full Autonomous Scheduling

These have no entries in the renumber mapping. They need new 3-digit IDs assigned. The plan should include them explicitly.

### I3. The `component` Field vs `category` — Redundancy Not Addressed

The plan adds a `component` field to contracts. But `category` already exists and serves a similar organizational purpose. From the schema:
- `category`: "Feature grouping for display and filtering" (e.g., "core-workflow", "quality")
- `component` (proposed): "Project component this feature belongs to (e.g., backend, frontend, infra)"

For the framework itself, `category` IS the component. "core-workflow" could be "workflow-engine", "quality" could be "enforcement", etc. The plan says "Cross-cutting features have no component; subfeatures are component-scoped" — but the same is true of category.

The risk is: agents and scripts now have two overlapping organizational axes to maintain, with no clear rule about when to use which.

**Recommendation**: Either (a) repurpose `category` for component scoping and deprecate the separate `component` field, or (b) clearly document the distinction with examples showing when they differ (e.g., "category=quality but component=cli-hooks").

### I4. `subfeature` Annotation Is an Unnecessary Intermediate Step

The plan adds a `subfeature` field to the assertion definition so ACs can be annotated before extraction. The workflow is: annotate ACs with subfeature names, then run `ag decompose --extract "name"` to split them into child contracts.

But this is just a staging step. If you already know which ACs belong together (enough to annotate them), you can directly create the child contract. The annotation step adds schema complexity (a new nullable field on every assertion) for a transitional purpose.

The `tags` field on assertions (not currently in schema, but `tags` exists on contracts) could serve this purpose without schema changes — or the decomposition could simply take AC IDs as arguments: `ag decompose F-003 --acs AC-001,AC-002,AC-003 --name "Skills System"`.

**Recommendation**: Drop the `subfeature` assertion annotation. Use an AC-list argument to the decompose command instead. This avoids polluting the assertion schema with temporary metadata.

### I5. `depth` Field Is Unnecessary — Computable from ID

The plan adds a `depth` field to contracts: "Nesting depth (advisory, computed from parent chain)." But the depth is trivially derivable from the dotted ID: `F-003` = depth 0, `F-003.1` = depth 1, `F-003.1.2` = depth 2. The plan even shows a `get_depth()` function that computes this.

Storing a computed value creates a maintenance burden: if a feature is reparented, the depth field must be updated. If it gets out of sync, it creates confusion about which is authoritative.

**Recommendation**: Drop the `depth` field from the schema. Use `get_depth(id)` at runtime. If depth enforcement is needed (max 3), do it in validation code, not schema.

### I6. Git History Becomes Unreadable After Renumber

Every git commit, PR description, code review comment, and GitHub issue that references F-0004, F-0081, etc. will become orphaned. `git log --grep=F-0004` will find historical commits but the feature is now F-003. `git blame` on FEATURES.md will show a massive renumber commit that obscures actual feature changes.

The CHANGELOG.md has 136 feature ID references — all historical. These should NOT be renamed (they were correct at the time). But if they stay as-is, searching for "what changed for feature F-003" requires knowing it was previously F-0004.

**Recommendation**:
1. Add an `old_id` or `aliases` field to contracts that preserves the old ID for search
2. Create a machine-readable renumber map (JSON) that tools can use for lookup
3. Do NOT rename historical references in CHANGELOG, journal entries, or git commit messages
4. Consider whether the renumber is worth the history cost at all

### I7. Four-Phase Plan Is Overambitious — Phase 2 Alone Is a Major Effort

The plan has 4 phases. Phase 1 (schema + code) is reasonable. Phase 2 (renumber) is enormous — touching 1,499 files. Phase 3 (decomposition demo) depends on both. Phase 4 is optional.

Realistically, Phase 2 could take multiple sessions and PRs. The renumber script needs to be built, dry-run tested, reviewed, and executed. Then every test must pass. This is not a single PR's worth of work.

**Recommendation**: Break Phase 2 into sub-phases:
- 2a: Build the renumber script with dry-run mode
- 2b: Renumber code files only (contracts, FEATURES.md, BACKLOG.json, etc.)
- 2c: Update test infrastructure (validate_framework.sh, test files)
- 2d: Update documentation and historical references (selective)

---

## MINOR Notes (Nice to Address)

### M1. The `E-` Prefix in Patterns Is Unused

The schema pattern includes `E-` (for epics): `^(F|DEV|E)-[0-9]{4,}$`. But there are zero `E-XXXX` IDs in the codebase. The plan's new pattern includes it: `^(F|DEV|E)-[0-9]{3,}(\.[0-9]+)*$`. Consider whether `E-` should be removed or if it serves a future purpose.

### M2. NFR IDs Not Addressed

The schema has `NFR-XXXX` IDs (3 exist: NFR-0001, NFR-0003, NFR-0004). The plan does not mention whether NFRs get renumbered too. The current pattern `^NFR-[0-9]{4,}$` would presumably also need the `{3,}` change. But NFRs are not in the renumber table.

### M3. The contracts.py `_ID_PATTERN` Already Has a Bug

Line 315: `_ID_PATTERN = re.compile(r"^(F|NFR)-\d{4,}$")` — this does NOT match `DEV-XXXX` IDs, which are valid contracts (4 exist). The plan's changes should fix this existing bug as part of Phase 1.

### M4. `format_feature_id` Only Handles F- Prefix

The function `format_feature_id(n)` formats as `F-XXXX`. There is no `format_dev_id(n)` or generic `format_id(prefix, n)`. The plan should add a generic formatter, especially since DEV-XXX IDs also need 3-digit formatting.

### M5. FEATURES.md Format for Children

The plan says "FEATURES.md uses flat ## F-XXX headers (no nested markdown)" — this means F-003.1 gets the same `## F-003.1:` format as top-level features. With potentially dozens of dotted children, FEATURES.md could become very long and hard to navigate. Consider a different rendering for children (e.g., collapsed sections, or only listing children under their parent).

---

## Summary Assessment

| Aspect | Rating | Notes |
|--------|--------|-------|
| Phase 1 (Schema + Code) | Feasible with fixes | Drop `subfeature` annotation and `depth` field; fix backward compatibility gap |
| Phase 2 (Renumber) | High risk | 10,672 replacements across 1,499 files; 28 migration entries; validate_framework.sh has 96 legacy sections; history disruption |
| Phase 3 (Decompose demo) | Low risk | Straightforward if Phase 1 lands correctly |
| Phase 4 (Optional) | N/A | Not enough detail to evaluate |

**Overall**: Phase 1 is sound in concept but has several schema design issues (unnecessary fields, transition gap). Phase 2 is the highest-risk part of the entire plan and is dramatically underscoped — the plan treats it as a mechanical operation but it is actually a complex migration affecting git history, test infrastructure, external references, and 28 contract-protected migrations. I recommend either (a) deferring Phase 2 until the hierarchy system proves its value with new features using dotted IDs, or (b) scoping Phase 2 down to renumber only the contract YAML files and FEATURES.md, leaving test files and historical references untouched with a compatibility layer that maps old IDs to new.
