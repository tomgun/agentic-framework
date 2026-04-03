# ADVOCATE Review: Hierarchical Feature System + Clean Renumber

**Reviewer role**: Advocate (strengths, alignment, opportunities)
**Plan location**: `/home/node/.claude/plans/vivid-meandering-teacup.md`
**Date**: 2026-03-24

---

## KEY STRENGTHS

### 1. Exceptional reuse of existing infrastructure

This plan is not building a hierarchy system from scratch -- it is completing one that is already 70% built. The evidence is overwhelming:

- **`parent` and `children` fields already exist** in `contract.schema.json` (lines 71-85) and in the `Contract` dataclass (`contracts.py` lines 151-152). The plan adds `component` and `depth` as lightweight metadata alongside what is already there.

- **`derive_epic_status()` and `_recompute_parent_if_needed()`** already implement recursive status rollup. The state machine (`state_machine.py` line 472) already calls parent recomputation after every child transition. The plan explicitly states "What stays the same" and lists these -- this shows the author deeply understands the codebase.

- **`decompose()` in `epic.py`** already proposes child features, creates child contracts, wires parent/children fields, and routes through review checkpoints. The plan extends this (via `extract_subfeature()` and subfeature annotations) rather than replacing it.

- **DEV-0001 is a living proof-of-concept.** It already has three children (DEV-0122, DEV-0199, DEV-0243) tracked via the `children:` field in its contract YAML. The plan generalizes what is already working for dev-infrastructure to all features.

- **The test suite (`test_epic.py`, 680+ lines)** already validates decomposition, parent-child wiring, status derivation, and contract creation. The plan builds on tested, shipped code.

**Why this matters**: Plans that reuse existing mechanisms have dramatically lower risk than plans that introduce parallel systems. There is no "old way vs new way" split. There is only an extension of what already works.

### 2. Component-as-metadata is the correct architectural decision

The plan explicitly chose `component:` as a metadata field on the contract rather than encoding it in the ID (e.g., `F-003-api`). This is the right call for three reasons:

**a) Cross-cutting features exist.** The framework has features like F-0081 (Agent System & Instructions) that span multiple components (Claude skills, Cursor rules, Copilot instructions, Codex). Encoding component in the ID would force a false choice for these features. Metadata allows `component: null` for cross-cutting concerns naturally.

**b) Components change; IDs should not.** If a team renames "api" to "backend" or splits "web" into "web-app" and "web-admin", only the metadata field needs updating -- not the feature ID, not the filenames, not the cross-references. This is the same reasoning behind why databases use surrogate keys rather than natural keys.

**c) Filtering is orthogonal to hierarchy.** `ag list --component backend` is a query, not a structural relationship. The plan correctly separates the organizational dimension (component) from the lifecycle dimension (parent/child hierarchy). This means you can have `F-003.1` (a subfeature) that belongs to component `backend` without the two concepts interfering.

**Comparison**: Jira uses components as metadata on issues, not as part of the issue key. Azure DevOps uses Area Paths as metadata. The industry consensus supports this decision.

### 3. Dotted ID notation is information-dense and human-friendly

`F-003.1.2` communicates three things at a glance: (a) it is a feature, (b) it belongs to F-003, (c) it is two levels deep. No lookup required. This is superior to flat IDs with a separate parent field because:

- **Conversation-friendly**: A developer can say "I'm working on F-024.3" and everyone instantly knows it is a subfeature of F-024 (Agent System), specifically the third child. With flat IDs like F-0310, that relationship is invisible without a database query.

- **Sort-stable**: `F-003.1`, `F-003.2`, `F-003.10` sort correctly with standard string sorting when zero-padded. Children naturally group next to their parent in any sorted listing.

- **Regex-parseable**: The pattern `^(F|DEV|E)-\d{3,}(\.\d+)*$` is clean, handles arbitrary depth, and the plan provides utility functions (`get_parent_id`, `get_depth`, `get_next_child_id`) that make it trivial to work with programmatically.

- **Backwards compatible**: The old pattern `^(F|DEV|E)-\d{4,}$` is a subset of the new pattern. Existing IDs like `F-0001` match the new regex. No existing code breaks if it only matches against the new regex.

### 4. "Parent ACs are independent of children" is a crucial design insight

The plan states: "Parent defines business outcome; children define implementation. Effective ACs = own + children's (computed at query time, never stored)."

This solves a real problem. Currently, F-0081 (Agent System & Instructions) has 12 consolidated concerns. If it were decomposed and the parent's ACs were deleted or moved to children, you would lose the high-level business outcome. The plan says: keep both. The parent's AC says "Multi-tool agent support works" and the child's ACs say exactly how (Claude integration, Cursor integration, etc.).

Computing "effective ACs" at query time (via `get_effective_assertions()`) rather than materializing them avoids data duplication and the synchronization bugs that come with it.

### 5. The 4-phase sequencing is well-ordered

**Phase 1 (Schema + Core Code)** delivers the infrastructure with no disruption. All new schema fields have defaults. All new regex patterns are supersets of old ones. You could merge Phase 1 and the only visible change would be new `ag` command flags and a `subfeature` annotation option. This is a textbook example of backward-compatible extension.

**Phase 2 (Clean Renumber)** is correctly isolated as a separate PR. Renumbering is a mechanical, high-touch-count operation that changes every file referencing a feature ID. Keeping it separate from code changes means: (a) the PR is reviewable (all changes are renames, no logic changes), (b) if something goes wrong, you revert one PR, not a mixed code+rename PR, (c) the renumber mapping table can be reviewed independently.

**Phase 3 (Demonstrate)** is marked optional, which is honest. It is also strategically valuable -- decomposing F-024 (12 consolidated concerns) would immediately validate the system and produce a visible artifact (the tree view) for the project documentation.

**Phase 4 (implicit: adopt over time)** is the right long-term strategy. Not every feature needs decomposition. The system should be available for features that grow too large, not imposed on every feature at creation time.

### 6. Clean renumber rationale

The renumber from 4-digit chronological to 3-digit categorical is the right call **now** because:

**a) The consolidation just happened.** The framework went from 217 features to ~33 contracts. The IDs are artifacts of the old numbering -- F-0001, F-0003 (where is F-0002?), F-0081 (which is really the 24th feature by importance). Post-consolidation is the natural inflection point for renumbering.

**b) Category grouping aids navigation.** Knowing that F-007 through F-013 are all Quality features, F-016 through F-017 are Multi-Agent, etc., means a developer can estimate a feature's domain from its ID number alone. This is the same principle behind HTTP status codes (2xx = success, 4xx = client error, 5xx = server error).

**c) 3-digit IDs are denser.** F-001 is 5 characters; F-0001 is 6. Over hundreds of references across FEATURES.md, contracts, CLAUDE.md, memory-seed, and conversation logs, this adds up. More importantly, 3 digits communicate "we have ~30 features" honestly, while 4 digits suggest "we have ~1000 features" which is misleading.

**d) The migration script already exists in miniature.** The DEV-0122 rename (from F-0122) was just completed on this branch. The plan correctly notes: "This is the same mechanical process we just did for F-0122->DEV-0122, but at scale." The tooling is proven.

**e) Renumbering gets harder over time.** Every new feature, every new PR reference, every new conversation log makes the rename more expensive. Doing it now, when the consolidation is fresh and the reference count is minimized, is optimal.

---

## OPPORTUNITIES ENABLED

### 1. Tree-based dashboards and reporting

With hierarchical IDs, the dashboard (`dashboard.sh`) can render feature status as a tree:

```
F-024  Agent System               shipped
  .1   Instruction Architecture   shipped
  .2   Skills System              shipped
  .3   Memory Seed                implementing  <-- next action
  .4   Multi-Tool Support         shipped
```

This immediately communicates both progress and scope. Today's flat list requires mental grouping. The tree view is automatic.

### 2. Component health metrics

With `component:` metadata, the framework can compute per-component metrics:
- "Backend: 12 features, 10 shipped, 2 implementing"
- "Frontend: 5 features, 3 shipped, 1 blocked"

This enables `ag health --component backend` -- a view that does not exist today and cannot be built without component metadata.

### 3. Scoped parallel work

With subfeatures as first-class entities, `ag auto epic F-024` can assign `F-024.1` through `F-024.4` to separate agents in parallel. Today, decomposition creates flat child IDs (F-0101, F-0102) that happen to have a parent field but are not visually or structurally grouped. Dotted IDs make the grouping explicit, which improves coordination server task assignment.

### 4. Better onboarding

A new contributor reading FEATURES.md today sees 30+ flat features of varying importance. With hierarchy:
- Top-level features (F-001 through F-031) provide the executive summary
- Drilling into F-024 reveals 4 subfeatures that explain the scope
- This is the difference between a table of contents and a book index

### 5. Team-scoped views

For larger projects using the framework, `ag list --component api --mine` becomes possible. Combined with `ag coord status`, a team lead can see: "Agent 1 is working on F-024.2 (Skills System, component: agent-infra), Agent 2 is working on F-003.1 (Contract Schema, component: spec-system)."

### 6. Multi-repo coordination foundation

The planned F-0231 (Multi-Repo Umbrella) needs a way to say "this feature in repo A depends on that subfeature in repo B." Hierarchical IDs make this natural: `repoA:F-010.2` depends on `repoB:F-003.1`. Without hierarchy, cross-repo references are all flat and require full context to understand.

### 7. Progressive elaboration

Today, you either have a single contract with 12 ACs (overwhelming) or you decompose into separate features (heavyweight). Subfeature annotations (`subfeature: "auth"` on an AC) provide a middle ground: group ACs within a single contract, then extract when ready. This matches how real development works -- you start with a rough grouping and formalize as you learn.

### 8. Deprecation without loss

If F-024.3 (Memory Seed) becomes obsolete, deprecating it automatically reflects in the parent's effective ACs without anyone manually editing the parent. The `derive_epic_status()` already handles deprecated children correctly (they are filtered out).

---

## RISKS WORTH ACCEPTING

### 1. Renumbering breaks external references (ACCEPTABLE)

Any PR comments, Slack messages, or documentation outside the repo that reference "F-0184" will become stale. This is acceptable because:

- The consolidation already invalidated 200+ old feature IDs. External references to F-0073, F-0149, etc. are already broken. Adding 30 more is marginal.
- The `consolidated_from` field and CONSOLIDATION_MAP.md provide a lookup path.
- The renumber happens once. Every day you delay, more external references accumulate.

### 2. Depth limit of 3 may need adjustment (ACCEPTABLE)

The plan caps nesting at 4 levels (Component grouping -> Feature -> Subfeature -> Sub-subfeature). For the current framework with ~30 features, this is generous. If a future project needs deeper nesting, the depth field is advisory and the ID regex supports arbitrary depth. The limit is a guardrail, not a wall.

### 3. `subfeature` field on assertions adds schema complexity (ACCEPTABLE)

Adding `subfeature: str | None` to every assertion is a small conceptual cost for a large organizational benefit. The field defaults to `null`, existing contracts are untouched, and it enables the progressive elaboration workflow described above. The alternative -- requiring full decomposition for any grouping -- is far more heavyweight.

### 4. The renumber mapping may need iteration (ACCEPTABLE)

The plan acknowledges the mapping is "to be finalized." Category boundaries (where does Quality end and Architecture begin?) are subjective. However, any reasonable grouping is better than chronological ordering, and the categories align with the existing FEATURES.md category field. The mapping can be adjusted during review without changing the mechanism.

### 5. Two PRs for what could be one (ACCEPTABLE AND CORRECT)

Separating schema changes (Phase 1) from renumbering (Phase 2) means two review cycles. This is the right tradeoff because:
- Phase 1 is logic changes (needs careful code review)
- Phase 2 is mechanical renames (needs careful grep-and-replace verification)
- Mixing them would make the diff unreadable

---

## COMPARISON TO INDUSTRY SYSTEMS

| Aspect | This Plan | Jira | Azure DevOps | SAFe |
|--------|-----------|------|--------------|------|
| Hierarchy | Dotted IDs (F-003.1) | Epic > Story > Subtask | Epic > Feature > User Story > Task | Portfolio > Program > Team |
| Depth | 4 levels | 3 levels (Epic/Story/Subtask) | 4 levels | 3-4 levels |
| Component | Metadata field | Component field on issue | Area Path | Capability / Feature |
| Status rollup | Automatic (`derive_epic_status`) | Manual or plugin | Automatic (rollup fields) | Automatic (PI objectives) |
| ID format | Semantic dotted | Sequential (PROJ-123) | Sequential (12345) | Sequential |

The plan's approach is closest to Azure DevOps in terms of depth and component handling, but with the advantage of semantic IDs that encode the hierarchy. The automatic status rollup (already implemented) matches what Azure DevOps provides with rollup fields, but the framework's version is simpler and requires no configuration.

The key differentiator from all industry tools: **the hierarchy lives in the same plain-text files as the code**. No external database, no SaaS dependency, no synchronization lag. This is a fundamental advantage for an agent-native framework.

---

## SUMMARY VERDICT

This plan is exceptionally well-aligned with the existing codebase. It extends proven mechanisms (parent/children, derive_epic_status, decompose), introduces minimal new concepts (subfeature annotation, component metadata, dotted IDs), and sequences the work to minimize risk. The renumbering is correctly timed at the post-consolidation inflection point.

The most important quality of this plan: **it makes the implicit explicit.** Parent-child relationships already exist in the code. Component scoping already happens informally. AC groupings within large features already emerge naturally. This plan gives all of these a formal representation, which is precisely what the framework is built to do -- turn informal development practices into structured, machine-verifiable contracts.

Recommendation: **Proceed as designed.**
