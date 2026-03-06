# Plan: Doc Lifecycle System (F-0139)

## Context

F-0138 added detection (drift.sh --docs) and a gate (docs_gate). But it didn't add *writing*.
The framework has no systematic way to draft and update project content docs — CHANGELOG, README,
ADRs, lessons learned, architecture docs, runbooks — as part of the development lifecycle.

Today these docs are manually maintained, rot quickly, and have no trigger that ensures they're
updated at feature completion or PR time.

The critical constraint: user extensions must survive `.agentic/` upgrades. Everything in `.agentic/`
gets wiped by `upgrade.sh`. So the project's doc registry must live in `STACK.md` (project root),
not in any framework file.

---

## Design

### Two-layer separation

| Layer | Where | Who owns it | Wiped on upgrade? |
|-------|-------|-------------|-------------------|
| **Registry** — what docs this project maintains | `STACK.md ## Docs` | Developer | No |
| **Machinery** — how to draft, trigger, invoke agent | `.agentic/tools/docs.sh` | Framework | Yes (fine) |

`docs.sh` reads the registry dynamically at runtime. When `.agentic/` is upgraded, the new
`docs.sh` reads the same `STACK.md ## Docs` entries — project extensions are preserved automatically.
No hard-coded paths in `docs.sh`.

---

### Doc Registry Format (in `STACK.md ## Docs`)

Simple one-line-per-doc format, parseable with `awk -F'|'`:

```markdown
## Docs
<!-- Doc registry — declare what docs this project maintains.
     This section lives in STACK.md (project root) and survives .agentic/ upgrades.
     To add a doc: add a line here. No .agentic/ files need editing.
     Triggers: feature_done | pr | session | manual
     Note: pr-trigger docs only fire in formal profile (formal uses PRs).
     To fire on multiple triggers, add two entries with the same path.
     Types (built-in): changelog | readme | adr | lessons | architecture | runbook | tech-spec | custom -->

- doc: CHANGELOG.md          | changelog    | pr
- doc: README.md             | readme       | pr
- doc: docs/lessons.md       | lessons      | feature_done
- doc: docs/architecture.md  | architecture | feature_done
- doc: docs/adr/             | adr          | manual
```

Format: `- doc: <path> | <type> | <trigger>`

---

### Built-in Doc Types

The framework ships with knowledge of these 8 types in `.agentic/agents/shared/doc_types.md`.
Projects don't edit this file — they just reference type names in their registry.

| Type | Typical path | Default trigger | What gets drafted |
|------|-------------|-----------------|------------------|
| `changelog` | `CHANGELOG.md` | `pr` | New entry prepended under `[Unreleased]` section (Keep a Changelog format) |
| `readme` | `README.md` | `pr` | User-facing changes section (only when user-facing code changed) |
| `lessons` | `docs/lessons.md` | `feature_done` | One entry: what was learned, what to do differently |
| `architecture` | any `.md` | `feature_done` | Section update for changed subsystems |
| `adr` | `docs/adr/` | `manual` | Full ADR stub: title, status, context, decision, consequences |
| `runbook` | any `.md` | `manual` | Operations section for new behaviour |
| `tech-spec` | `spec/TECH_SPEC.md` | `feature_done` | Technical details for changed components |
| `custom` | any path | configurable | Agent reads existing doc structure and drafts an update |

`custom` type handles any doc the framework doesn't know about — the agent reads the existing
doc's structure and drafts a section that fits it.

---

### `docs.sh` Tool (new)

Location: `.agentic/tools/docs.sh` (framework-owned, wiped on upgrade — that's correct)

```bash
docs.sh --trigger feature_done --manifest F-####   # Feature completion docs
docs.sh --trigger pr --manifest F-####             # PR-time docs (changelog, readme)
docs.sh --trigger session                          # Staleness check only, no drafting
docs.sh --list                                     # Print parsed registry from STACK.md
docs.sh --check --manifest F-####                  # Dry run: what would be drafted
docs.sh --draft <path> --type <type> [--manifest F-####]  # Single doc
```

**Execution model** (critical clarification): `docs.sh` is a **context assembler**, not an LLM
caller. It cannot invoke Claude directly. The flow is:

1. Parse `## Docs` section from `STACK.md` → list of `(path, type, trigger)` tuples
2. Filter by `--trigger` value
3. For each matching doc: assemble a structured context block to stdout:
   - Feature manifest JSON (from `.agentic-journal/manifests/`)
   - Acceptance criteria (from `spec/acceptance/`)
   - Doc type guidance (from `doc_types.md`)
   - Current doc content (first 50 lines, if file exists)
   - Write strategy (prepend/append/section)
4. Print the assembled context block as structured output
5. The **Claude agent** (which called `ag done` or `ag docs`) reads this output and performs
   the actual drafting — writing to files, adding draft markers, etc.

This is the same pattern as `context-for-role.sh`: bash assembles context, Claude acts on it.
`docs.sh` never writes doc content itself — it only writes to stdout.

**Draft marker**: `<!-- draft: F-#### YYYY-MM-DD -->` — added by the Claude agent when writing.
If a draft marker already exists in the file (previous draft not reviewed), `docs.sh` prints a
warning: `"⚠ <path>: existing draft marker found (previous draft not reviewed) — skipping"`.
The agent skips that doc. Human must review/remove the old marker first.

**File creation**: If target file does not exist, `docs.sh` notes `"[new file]"` in its output.
The Claude agent creates the file with a minimal header appropriate to the doc type (from
`doc_types.md` file-creation templates) before appending the draft.

**Output model**: Drafts written directly to actual doc files using an **append/prepend-only
strategy** — the Claude agent never rewrites or restructures existing content:
- `CHANGELOG.md` → prepend new entry under `[Unreleased]` block (or add `[Unreleased]` if missing)
- Append-only docs (`lessons.md`) → append new entry at end of file
- Complex docs (`README.md`, architecture) → append a clearly marked section at end

Safe because existing content is never touched. Human reviews additions with `git diff`,
keeps what's useful, removes draft markers, commits normally. Nothing is auto-committed.
No harvest step — drafts are where they'll end up, which reduces friction.

---

### `ag docs` Command (new)

```bash
ag docs [F-####]    # Run feature_done + pr triggers for feature
ag docs --pr        # Run only pr-trigger docs (changelog, readme)
ag docs --list      # Show registry from STACK.md
ag docs --check     # Dry run
```

**Feature ID resolution**: If no F-#### given, `docs.sh` reads `.agentic-state/WIP.md` for the
current feature ID. If no WIP exists, prints error: `"No feature ID given and no WIP active.
Usage: ag docs F-####"`.

---

### Trigger Wiring in `ag done`

```
ag done F-####
  → generate manifest
  → docs_gate drift check (F-0138 behaviour — unchanged)
  → docs.sh --trigger feature_done --manifest F-####    (both profiles, if registry non-empty)
  → docs.sh --trigger pr --manifest F-####              (formal profile only — formal uses PRs)
  → mark shipped
```

In discovery: only `feature_done` docs fire (lessons, architecture, tech-spec).
In formal: both fire — CHANGELOG and README get drafted before PR is created.

`ag sync` adds: `docs.sh --trigger session` — staleness check against registry (detects docs in
registry that haven't been touched in 30 days by default), no drafting. Threshold configurable
via `docs_stale_days` in STACK.md (default: 30).

Note: PR-trigger docs only fire in formal profile (formal uses PRs). This is trigger-level
filtering in `ag done`, not per-entry filtering. The registry itself has no profile column —
that's explicitly out of scope for v1. To multiple-trigger a doc (e.g. changelog on both
`feature_done` and `pr`), add two entries with the same path.

---

### How a Developer Extends It

**Adding a new doc to track:**
```markdown
# STACK.md ## Docs — add one line:
- doc: docs/ops/runbook.md | runbook | manual
```
No `.agentic/` files touched. Survives upgrades.

**Using a doc type the framework doesn't know:**
```markdown
- doc: docs/data-dictionary.md | custom | feature_done
```
Agent reads the existing doc's structure and drafts a fitting update section.

**Changing when a doc gets updated:**
```markdown
- doc: CHANGELOG.md | changelog | feature_done   # instead of pr
```

---

### New Project Scaffolding

`scaffold.sh` adds a `## Docs` section to `STACK.md` with common types pre-listed but
commented out — developer uncomments what applies:

```markdown
## Docs
<!-- Uncomment the docs this project maintains. Add custom entries as needed.
     This section survives .agentic/ upgrades — your additions are preserved. -->
<!-- - doc: CHANGELOG.md          | changelog    | pr           -->
<!-- - doc: README.md             | readme       | pr           -->
<!-- - doc: docs/lessons.md       | lessons      | feature_done -->
<!-- - doc: docs/architecture.md  | architecture | feature_done -->
<!-- - doc: docs/adr/             | adr          | manual       -->
```

---

## Files to Create / Modify

| File | Change |
|------|--------|
| `.agentic/tools/docs.sh` | **New** — registry reader + trigger dispatcher + agent orchestrator |
| `.agentic/agents/shared/doc_types.md` | **New** — built-in type definitions (what each type means, what to draft) |
| `.agentic/tools/ag.sh` | Add `ag docs` command; wire `docs.sh` into `ag done` (after docs_gate) and `ag sync` |
| `.agentic/init/STACK.template.md` | Add commented-out `## Docs` section |
| `.agentic/init/scaffold.sh` | Copy `## Docs` section to new projects |
| `.agentic/agents/shared/auto_orchestration.md` | Add doc lifecycle step |
| `.agentic/agents/claude/subagents/documentation-agent.md` | Add "structured registry mode": when `docs.sh` output is provided, follow its context block instead of autonomous discovery. Existing autonomous mode (read CONTEXT_PACK → drift.sh) remains for standalone invocation. |
| `STACK.md` | Add populated `## Docs` section (framework dogfooding) |
| `spec/FEATURES.md` | Add F-0139 entry |
| `spec/acceptance/F-0139.md` | Acceptance criteria + `## Tests` section |
| `tests/validate_framework.sh` | F-0139 structural tests |
| `tests/llm/test_definitions.json` | LLM behavioral tests |
| `CHANGELOG.md` | New 0.30.0 entry |
| `CONTRIBUTIONS.md` | F-0139 design insights |

---

## Out of Scope (follow-on)

- Auto-creating one ADR per feature (ADRs need human judgment; `manual` trigger is correct for now)
- Per-doc profile filtering (all profiles see all registry docs in v1; simpler)
- CI/CD git hook at PR-open event (requires GitHub Actions integration)
- Auto-committing drafted docs (always human-reviewed in v1)

---

## Verification

1. **Empty registry** → `ag docs` prints "no docs registered in STACK.md ## Docs" and exits cleanly
2. **Registry with `changelog | pr` and `lessons | feature_done`** → `ag done F-####` on formal:
   drafts both; on discovery: drafts lessons only
3. **`ag docs --list`** → formatted table of registry entries
4. **`ag docs --check`** → dry run output without writing files
5. **Developer adds one line to STACK.md ## Docs** → fires at next `ag done`, no other changes needed
6. **Framework upgrade (`.agentic/` wiped)** → `STACK.md ## Docs` intact → new `docs.sh` reads it correctly
7. **`bash tests/validate_framework.sh`** passes with F-0139 tests
