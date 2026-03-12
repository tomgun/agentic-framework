# F-0201: Vision-to-Backlog Pipeline (`ag kickoff`) — Implementation Plan

**Status**: APPROVED (revision 3 — post-dialectical review, 2 rounds)
**Feature**: F-0201
**Parent**: F-0188 (End-to-End Autonomous Flow)
**Dependency**: F-0186 (Autonomous Scheduler) — SHIPPED
**ADR**: ADR-002 §3

## Context

`ag kickoff` is the linchpin for Modes 2 (Product Visionary) and 3 (Fully Autonomous). It converts a product vision into structured spec artifacts — OVERVIEW.md, FEATURES.md entries, acceptance criteria stubs, and BACKLOG.json — all in a staging area for review before promotion to real spec files.

This version ships **script mode only** (`ag kickoff "prompt"`). Playbook/interview mode (multi-turn dialogue) is deferred to a child feature — both reviewers flagged it as too ambitious for v1 and it adds 5 files without affecting the core pipeline.

### Core Workflow Principle: Generate → Review → Iterate → Approve

```
[Input: prompt]  →  [Generation]  →  [Review Loop]  →  [Approval]  →  [Promote]
                                       ↓    ↑
                                 User feedback
                                 (edit/reshape/add/remove)
```

**The review loop is mandatory** — it's a first-class phase, not an afterthought. The user sees the generated features, acceptance criteria, and backlog ordering, then can:
- Edit individual features (rename, merge, split, remove)
- Reshape acceptance criteria
- Reorder the backlog
- Ask for another generation pass with refined direction
- Approve and promote to real spec files

Only after explicit approval (`ag kickoff --approve`) do artifacts leave the staging area.

### Mode Behavior (v1: script only)

| Aspect | Script (default) | Script (extreme auto) |
|--------|-------------------|-------------------------------|
| **Input** | Single prompt + refs | Single prompt + refs |
| **Confirmations** | Pause for direction at key points | All confirmations auto-skipped |
| **Review** | Agent presents, user responds | Agent auto-approves via critical_agent |
| **Config** | `kickoff_confirm: ask` | `kickoff_confirm: skip` |

**Confirmations in script mode** are lightweight direction checks:
1. "I parsed your vision as: [summary]. Correct direction?" — skippable
2. "I'll generate N features. Here's the rough breakdown: [list]. Proceed?" — skippable
3. Review loop (always present unless `kickoff_confirm: skip` AND `review_decomposition: critical_agent`)

**Future**: `ag kickoff --interview` (playbook mode) will add a 5-phase dialogue (vision, taste, architecture, generate, review). Deferred to child feature.

## Architecture

```
                          ┌──────────────────────────────────┐
                          │        INPUT GATHERING           │
                          │  Script: prompt + confirmations  │
                          └──────────┬───────────────────────┘
                                     │
                                     ▼
                          ┌──────────────────────────────────┐
                          │        GENERATION                │
                          │  kickoff.py → staging area       │
                          │  (.agentic/session/kickoff-draft)│
                          └──────────┬───────────────────────┘
                                     │
                                     ▼
                          ┌──────────────────────────────────┐
                          │     REVIEW / ITERATE LOOP        │◄──┐
                          │                                  │   │
                          │  User: edit, merge, split,       │   │
                          │        reorder, add, remove      │   │
                          │  Agent: re-validate after edits  │   │
                          │                                  │   │
                          │  → "looks good" = approve        │───┘
                          │  → "change X" = iterate          │  (iterate)
                          │  → "start over" = discard        │
                          └──────────┬───────────────────────┘
                                     │ (approve)
                                     ▼
                          ┌──────────────────────────────────┐
                          │        PROMOTE                   │
                          │  ag kickoff --approve            │
                          │  → review_decomposition gate     │
                          │  → staging → real spec files     │
                          │  → suggest ag auto epic          │
                          └──────────────────────────────────┘
```

**Key design decisions**:
- `kickoff.py` does NOT call the LLM. It provides structured templates, validation, and promotion. LLM interaction happens at the ag.sh/skill layer. Python layer is fully unit-testable.
- The **review loop is a first-class phase**, not just `--approve`. The agent presents staging output, the user iterates, and only explicit approval moves forward.
- Reuses: `epic.py` (get_next_feature_id — promoted to public), `backlog_helpers.py` (cmd_add with correct 3-arg signature), `query_features.py` (ID conflict check)

### Design Decisions from Dialectical Review

| Decision | Resolution | Rationale |
|----------|-----------|-----------|
| `_get_next_feature_id` is private | Promote to public `get_next_feature_id()`, add to `__all__` | Shared by epic.py and kickoff.py; underscore was premature |
| `update_staging_feature()` god function | Split into 5 separate functions (merge, split, rename, reorder, remove) | Each operation has distinct logic; separate functions are independently testable |
| `backlog_helpers.cmd_add(args)` wrong signature | Use correct `cmd_add(project_root, backlog_file, args)` 3-arg signature | Verified in actual code; plan had stale interface |
| Playbook mode in v1 | Deferred to child feature | 5 extra files, optimistic token budget, independent from core pipeline |
| Concurrent kickoff protection | Block if staging exists; require `--discard` first | Simple model, prevents accidental clobbering |
| `review_decomposition` wiring | Direct `get_setting()` call (like epic.py line 383), not `check_review()` state machine | Kickoff approval is not a feature state transition — it's a one-off gate |
| Staging dir in .gitignore | Add `.agentic/session/kickoff-draft/` to `.gitignore` | Drafts must never be committed |
| `paths.sh` KICKOFF_STAGING_DIR | Only add if kickoff.sh actually needs it (YAGNI) | Shell wrapper delegates to Python; Python uses paths.py |
| IDs at promotion time | Re-allocate fresh IDs during `promote_staging()` | Staging IDs are placeholders; prevents conflicts from time gap between generate and approve |
| OVERVIEW.md collision | Fail if exists; user must `--force` to overwrite | Safe default for v1 |
| Failed promotion recovery | Staging area remains intact for retry | Atomic: either everything promotes or nothing does |

---

## Phase 1: Foundation — Python Backend + Acceptance Criteria (8 files)

**Goal**: Core engine: staging generation, validation, promotion. Plus formal ACs.

### Files

| Action | File | Purpose |
|--------|------|---------|
| CREATE | `.agentic/spec/acceptance/F-0201.md` | Formal acceptance criteria |
| CREATE | `.agentic/lib/auto/kickoff.py` | Core module: generate, validate, promote, review, edit, discard |
| CREATE | `tests/test_kickoff.py` | Unit tests for all kickoff.py functions |
| MODIFY | `.agentic/lib/paths.py` | Add `kickoff_staging_dir` to AgenticPaths |
| MODIFY | `.agentic/lib/auto/epic.py` | Promote `_get_next_feature_id` → `get_next_feature_id`, add to `__all__` |
| MODIFY | `.gitignore` (root) | Add `.agentic/session/kickoff-draft/` |
| MODIFY | `.agentic/spec/FEATURES.md` | Update F-0201 status: planned → criteria_set |
| MODIFY | `tests/test_epic.py` | Update tests for renamed public function |

### kickoff.py Design

```python
# .agentic/lib/auto/kickoff.py

def generate_to_staging(project_root, features_data, overview_text=None):
    """Write kickoff artifacts to staging area.

    Args:
        project_root: Project root path
        features_data: List of dicts: [{name, description, criteria: [str], dependencies: [F-XXXX]}]
        overview_text: Optional OVERVIEW.md content

    Raises if staging dir already exists (must --discard first).

    Creates in .agentic/session/kickoff-draft/:
        - OVERVIEW.md (with <!-- PROPOSAL --> markers)
        - FEATURES.md (feature entries, placeholder IDs like F-NEW-001)
        - spec/acceptance/F-NEW-XXX.md (per feature)
        - BACKLOG.json (ordered by dependency)

    Note: IDs are placeholders. Real IDs allocated at promotion time
    via get_next_feature_id() to prevent conflicts from time gap.
    """

def validate_staging(project_root):
    """Validate staging area. Returns (valid: bool, errors: list[str]).

    Checks:
        - Dependency acyclicity (topological sort)
        - Non-empty acceptance criteria per feature
        - OVERVIEW.md exists and has content
    Note: ID uniqueness checked at promotion time, not here
    (staging uses placeholder IDs).
    """

def promote_staging(project_root, force_overview=False):
    """Move staging artifacts to real spec files.

    1. Allocates fresh feature IDs via get_next_feature_id()
    2. Re-validates with real IDs
    3. Appends features to FEATURES.md
    4. Creates spec/acceptance/F-XXXX.md files
    5. Merges entries into BACKLOG.json via backlog_helpers.cmd_add()
    6. Copies OVERVIEW.md to .agentic/OVERVIEW.md (fails if exists unless force_overview)
    7. Strips <!-- PROPOSAL --> markers
    8. Removes staging directory on success

    On failure: staging remains intact for retry.
    """

def review_staging(project_root):
    """Pretty-print staging artifacts for human review.

    Returns structured summary dict:
        - overview: title + first paragraph
        - features: [{id, name, ac_count, dependencies}]
        - backlog_order: [ids in order]
        - validation: {valid, errors, warnings}
    Designed for the agent to present to the user in the review loop.
    """

# --- Staging edit operations (one function per operation) ---

def merge_staging_features(project_root, source_id, target_id):
    """Merge source feature into target. Combines ACs, removes source, updates deps."""

def split_staging_feature(project_root, feature_id, split_spec):
    """Split feature into N new features. split_spec: [{name, criteria: [ac_indices]}]"""

def rename_staging_feature(project_root, feature_id, new_name):
    """Rename a feature in staging."""

def reorder_staging_backlog(project_root, ordered_ids):
    """Set backlog order. ordered_ids: list of feature IDs in desired order."""

def remove_staging_feature(project_root, feature_id):
    """Remove feature from staging. Cascade-deletes AC file and BACKLOG entry."""

def discard_staging(project_root):
    """Delete staging directory (rollback)."""
```

**Reuse from epic.py**:
- `get_next_feature_id(features_file)` — public import from `auto.epic` (promoted from private)
- `_build_feature_section()` — pattern reference only (kickoff builds similar but not identical sections)
- `_build_child_ac()` — pattern reference only (kickoff AC files lack parent/component fields)

**Reuse from backlog_helpers.py** (lives in `lib/tools/`, needs `sys.path.insert` like epic.py line 33):
- `cmd_add(project_root, backlog_file, args)` — correct 3-arg signature for BACKLOG.json population
- `args` format: `[feature_id, "--desc", description]` to match cmd_add's arg-parsing expectations

**Thread safety note**: `get_next_feature_id` is not atomic (documented in epic.py). This is acceptable because kickoff uses placeholder IDs during staging and allocates real IDs only at promotion time, which is human-gated.

### Acceptance Criteria (F-0201.md)

**Input gathering:**
- **AC-001**: `ag kickoff "prompt"` (script mode) generates OVERVIEW.md, FEATURES.md entries, AC stubs, and BACKLOG.json in staging directory
- **AC-002**: Script mode has optional confirmation checkpoints (direction check, feature breakdown preview) controlled by `kickoff_confirm` setting (`ask` | `skip`; default per profile: formal=`ask`, discovery=`skip`)

**Review and iteration:**
- **AC-003**: After generation, `ag kickoff --review` presents staging artifacts for user review with options: edit, merge, split, reorder, add, remove features
- **AC-004**: User can iterate on staging artifacts (edit → re-validate → review again) as many times as needed before approving
- **AC-005**: `ag kickoff --approve` validates staging, allocates fresh IDs, then promotes artifacts to real spec files
- **AC-006**: `ag kickoff --discard` removes staging directory cleanly (start over)

**Validation and infrastructure:**
- **AC-007**: Validation catches: circular dependencies, empty acceptance criteria. ID uniqueness checked at promotion time.
- **AC-008**: Routes through `review_decomposition` checkpoint (via `get_setting()`) before promotion
- **AC-009**: Staging area lives at `.agentic/session/kickoff-draft/`, is gitignored, uses `<!-- PROPOSAL -->` markers
- **AC-010**: Reuses `backlog_helpers.cmd_add()` for BACKLOG.json and `epic.get_next_feature_id()` for ID allocation
- **AC-011**: Running `ag kickoff` while staging exists is blocked; requires `--discard` first

**Integration:**
- **AC-012**: After approval, suggests `ag auto epic F-XXXX` for autonomous execution
- **AC-013**: In extreme auto mode (`kickoff_confirm: skip` + `review_decomposition: critical_agent`), review loop is delegated to critical_agent instead of human
- **AC-014**: If OVERVIEW.md already exists, promotion fails unless `--force` is passed
- **AC-015**: `ag kickoff --status` reports staging state (exists, feature count, validation status)

**Deferred (child feature):**
- ~~AC-003 (old)~~: Playbook/interview mode deferred to child feature

---

## Phase 2: CLI + Review Loop — `ag kickoff` in ag.sh (5 files)

**Goal**: Wire Python backend into `ag` command. Includes `--review` for the staging review/iteration loop and `kickoff_confirm` setting.

### Files

| Action | File | Purpose |
|--------|------|---------|
| CREATE | `.agentic/lib/tools/kickoff.sh` | Thin shell wrapper (like backlog.sh) |
| MODIFY | `.agentic/lib/tools/ag.sh` | Add `cmd_kickoff()` + case entry + help text |
| MODIFY | `.agentic/lib/auto/kickoff.py` | Add CLI argparse entry point |
| MODIFY | `.agentic/lib/presets/profiles.conf` | Add `kickoff_confirm` defaults per profile |
| MODIFY | `tests/test_kickoff.py` | Add CLI integration tests + review flow tests |

### cmd_kickoff() Design

```bash
cmd_kickoff() {
    local subcmd="${1:-}"

    # Subcommands:
    # ag kickoff "prompt"          → script mode (generates to staging)
    #   --style FILE               → optional style/taste reference
    #   --research FILE            → optional research/context reference
    #   --no-confirm               → skip confirmation checkpoints (one-shot override)
    # ag kickoff --review          → presents staging for review/iteration
    # ag kickoff --approve         → validates + promotes staging
    #   --force                    → overwrite existing OVERVIEW.md
    # ag kickoff --discard         → removes staging (start over)
    # ag kickoff --status          → shows staging state (minimal: exists + feature count)

    # Gates:
    # - feature_tracking: yes required
    # - No active WIP (prevent collision)
    # - Staging must not exist for new generation (block + require --discard)
    # - review_decomposition checkpoint on --approve (via get_setting(), not check_review())

    # Settings:
    # - kickoff_confirm: ask|skip — controls confirmation checkpoints
    #   Profile defaults: discovery=skip, formal=ask, autonomous_formal=skip
    # - review_decomposition: human|critical_agent|skip — promotion gate

    # Intent tracking:
    # intent_write "kickoff" "kickoff" "generate,review,validate,promote" ...
}
```

**Key interactions**:
- Script mode prints structured agent instructions (like `cmd_plan()`) — tells the agent what to do
- **Script confirmations**: When `kickoff_confirm: ask`, the agent pauses at two natural points: (1) "I interpret your vision as [summary] — correct direction?" and (2) "I'll generate N features: [breakdown] — proceed?" User can say "yes", "no, adjust X", or "skip confirmations"
- **Review subcommand** (`--review`): The agent presents staging contents in a readable format. User can request edits inline ("merge features 3 and 4", "add a feature for auth", "reorder: auth first"). Agent edits staging files and re-validates. Loop until user says "approve" or "discard".
- **Status subcommand** (`--status`): Returns JSON with staging state (exists, feature count, validation status). Useful for `ag sync` and programmatic consumers.

---

## Phase 3: Instruction File Updates (10 files, 2 commits)

**Goal**: Ensure `ag kickoff` reaches agents in ALL user projects. Framework dev requirement.

### Commit 3a — Agent Instructions (5 files)

| Action | File | Change |
|--------|------|--------|
| MODIFY | `CLAUDE.md` (root) | Add `ag kickoff` to Quick Commands |
| MODIFY | `.agentic/lib/agents/claude/CLAUDE.md` | Add to template Quick Commands |
| MODIFY | `.agentic/lib/agents/shared/agent_operating_guidelines.md` | Add to Quick Commands table |
| MODIFY | `.agentic/lib/agents/shared/auto_orchestration.md` | Add Vision-to-Backlog trigger section |
| MODIFY | `.agentic/lib/init/memory-seed.md` | Add trigger word entry, bump version |

### Commit 3b — Other Agents + Docs (5 files)

| Action | File | Change |
|--------|------|--------|
| MODIFY | `.agentic/lib/agents/cursor/cursorrules.txt` | Add kickoff trigger |
| MODIFY | `.agentic/lib/agents/copilot/copilot-instructions.md` | Add kickoff command |
| MODIFY | `.agentic/lib/agents/codex/codex-instructions.md` | Add kickoff command |
| MODIFY | `docs/DEVELOPER_GUIDE.md` | Add to Command Reference |
| MODIFY | `docs/HOW_IT_WORKS.md` | Add kickoff paragraph |

---

## Execution Order

```
Phase 1: Foundation (blocks everything) — 8 files
├── AC-001, AC-005, AC-006, AC-007, AC-009, AC-010, AC-011, AC-014
├── kickoff.py (generate, validate, promote, review, edit ops, discard)
├── + tests + paths + epic.py public promotion + .gitignore + AC file
└── ✅ CHECKPOINT: unit tests pass, validate_framework.sh passes

Phase 2: CLI + Review Loop (depends on Phase 1) — 5 files
├── AC-001 (script CLI), AC-002 (confirmations), AC-003 (review), AC-004 (iterate),
│   AC-005, AC-006, AC-008, AC-012, AC-013
├── ag.sh cmd_kickoff + kickoff.sh + profiles.conf + CLI tests
└── ✅ CHECKPOINT: full flow works: generate → review → iterate → approve → promote

Phase 3: Instruction Files (depends on Phases 1+2) — 10 files, 2 commits
├── All instruction files updated
└── ✅ CHECKPOINT: validate_framework.sh passes, memory-seed sentinels pass
```

**Total**: ~23 files across 3 phases (4 commits).

---

## Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| LLM output parsing in script mode | HIGH | kickoff.py accepts structured data (list of dicts), not raw LLM text. The ag.sh/skill layer handles prompt→structure conversion |
| ID conflict between staging generation and approval | MEDIUM | Staging uses placeholder IDs; real IDs allocated at promotion time via `get_next_feature_id()` |
| Concurrent kickoff collision | LOW | Blocked if staging exists; must `--discard` first |
| Stale staging directories from aborted kickoffs | LOW | `ag sync` can warn about stale staging (defer to post-MVP) |
| Missing an instruction file update | LOW | validate_framework.sh checks for kickoff in expected files |
| OVERVIEW.md already exists at promotion | LOW | Fails by default; `--force` flag to overwrite |

## Verification

1. **Unit tests**: `python -m pytest tests/test_kickoff.py -v`
2. **Integration**: `ag kickoff "Build a todo app"` → verify staging artifacts → `ag kickoff --review` → iterate → `ag kickoff --approve` → verify real spec files
3. **Framework validation**: `bash tests/validate_framework.sh`
4. **Rollback test**: `ag kickoff --discard` → verify staging directory removed
5. **ID conflict test**: Create a feature, then try kickoff that would use the same ID — verify fresh allocation at promotion
6. **Concurrent kickoff test**: Run `ag kickoff` with existing staging → verify it blocks
7. **OVERVIEW.md collision test**: Create OVERVIEW.md, then promote → verify failure, then `--force` → verify overwrite

## Deferred Work (child features)

- **Playbook/interview mode**: `ag kickoff --interview` with 5-phase dialogue (vision, taste, architecture, generate, review). Separate child feature.
- **Stale staging cleanup**: `ag sync` integration to warn about abandoned staging directories.
- **`ag kickoff --status` full JSON**: Rich structured output for programmatic consumers (coordination server, `ag auto epic`). v1 has minimal status.
