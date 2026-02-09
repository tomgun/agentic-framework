# Plan: F-0123 Intelligent Onboarding for Existing Projects

**Status**: APPROVED
**Iteration**: 2
**Created**: 2026-02-08
**Last Updated**: 2026-02-08

---

## Context

When users install the Agentic Framework into an **existing project** (brownfield), the current `ag init` flow asks them the same interview questions it would ask for an empty project. This wastes time and produces lower-quality artifacts because the codebase already contains most of the answers. F-0123 adds intelligence: detect that a codebase exists, analyze it, and propose pre-populated state files (STACK.md, CONTEXT_PACK.md, OVERVIEW.md, and optionally FEATURES.md + acceptance criteria for Core+PM).

**Key constraints**:
- Pure bash/Python (no npm/pip dependencies)
- Must not break existing init flow for new/empty projects
- All generated specs are PROPOSALS requiring human approval
- Core+PM gets feature discovery; Core gets stack/context discovery only
- No test generation in v1
- Primary language only (no multi-language in v1)

**Dependencies**: F-0001 (Project Initialization), F-0002 (Profile Selection)

## Approach

**High-level strategy**: Build a layered discovery system integrated into the existing scaffold → playbook architecture:

1. **Detection layer** (bash, in `scaffold.sh`) -- Determines if the project has existing code. Runs inside `scaffold.sh` after profile detection but before file copying.
2. **Stack analysis layer** (Python) -- Detects languages, frameworks, package managers, test frameworks, entry points by inspecting well-known files and directory structure.
3. **Content analysis layer** (Python) -- Reads README.md for project description; maps directory structure for architecture; inspects test directories for patterns.
4. **Feature discovery layer** (Python, Core+PM only) -- Identifies modules/components/routes/endpoints and proposes them as shipped features.
5. **Output generation layer** (Python) -- Renders proposals from templates with discovered data to a staging area (`.agentic-state/proposals/`), tagged with `<!-- PROPOSAL -->` markers.
6. **Agent-guided review** (init_playbook.md) -- The agent reads `discovery_report.json`, presents findings to the user, asks for confirmation/edits. This IS the "interactive mode" — the normal agent-driven init flow enhanced with discovery data.
7. **Approval layer** (bash) -- `ag approve-onboarding` command strips proposal markers, supports per-file and batch approval.

**Key architectural decisions**:

- **scaffold.sh is the integration point** (not `cmd_init()`). `cmd_init()` in ag.sh is purely informational — it prints text and returns. `scaffold.sh` IS executed by the user/agent and is the right place to trigger discovery. Discovery runs inside scaffold.sh after profile detection.
- **Interactive mode = agent-guided discovery review**. There is no separate "interactive" code path. When `discovery_report.json` exists, the init_playbook tells the agent to read it, present findings to the user, and ask for confirmation. The agent's natural conversation ability handles the "guided questions" and "I don't know" cases. This aligns with the existing architecture where agents drive initialization.
- **Proposals go to a staging area first**. `render_proposals.py` writes to `.agentic-state/proposals/`, not directly to root. The agent (via init_playbook Step 0.5) copies confirmed proposals to root, or `scaffold.sh` can auto-copy in fully-auto mode.
- **Python scripts in `.agentic/tools/`** (existing convention). All 18 existing Python scripts are in `.agentic/tools/`. Discovery scripts follow the same pattern.
- **`copy_or_propose()` replaces `copy_if_missing()` when discovery data exists**. If existing files still look like templates (using `looks_like_template()` heuristic from doctor.py), they get overwritten with proposal-enhanced versions. If the user has customized them, they are preserved.
- **JSON intermediate format**. Discovery outputs a JSON report that both auto-discover and the agent-guided flow consume when rendering proposals. This ensures convergence.
- **Confidence levels via heuristics**: High = found in config file, Medium = inferred from file presence, Low = guessed from directory structure.

**Trade-offs considered**:
- Python for analysis vs. pure bash: Python gives JSON handling, regex, globs cleanly. Framework already uses Python tools. Right call.
- Single script vs. modular: Modular — `discover.sh` orchestrates, `discover.py` analyzes, `render_proposals.py` renders. Better for testing.
- LLM-assisted vs. heuristic-only: Heuristic-only for v1. LLM-assisted would complicate the flow. Agent can enhance proposals after generation.

## Implementation Steps

### Step 1: Add brownfield detection + discovery trigger in scaffold.sh
**Files**: `.agentic/init/scaffold.sh`

- Add `detect_existing_codebase()` function: counts source files (`.py`, `.ts`, `.js`, `.go`, `.rs`, `.java`, `.rb`, `.gd`, `.cs`, `.cpp`, `.c`, `.swift`), excludes `.agentic/`, `node_modules/`, `.git/`, `__pycache__/`, `build/`, `dist/`. Also checks for project markers (`package.json`, `requirements.txt`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `Gemfile`).
- Add `copy_or_propose()` function: when `discovery_report.json` exists, checks if existing state files still look like templates (bare placeholders). If so, overwrites with proposal-enhanced versions from `.agentic-state/proposals/`. If user has customized, preserves their file and prints a note.
- After profile detection, call `detect_existing_codebase()`. If true, call `bash .agentic/tools/discover.sh --profile $PROFILE`. Then use `copy_or_propose()` instead of `copy_if_missing()` for state files.

### Step 2: Create the discovery orchestrator
**Files**: `.agentic/tools/discover.sh` (new, ~100 lines)

Bash wrapper:
- Checks Python 3 availability with clear error message
- Takes `--profile core|core+product` flag
- Calls `python3 .agentic/tools/discover.py --root $PROJECT_ROOT --output .agentic-state/discovery_report.json`
- Calls `python3 .agentic/tools/render_proposals.py --report .agentic-state/discovery_report.json --templates .agentic/init/ --output .agentic-state/proposals/ --profile $PROFILE`
- On success, prints summary of what was discovered
- On failure, prints warning and exits 0 (graceful fallback to standard init)

### Step 3: Create the Python analysis engine
**Files**: `.agentic/tools/discover.py` (new, ~400 lines)

Core analysis logic:
- `detect_stack(root)` -> dict with language, framework, runtime, package_manager, test_framework, build_tool
- `detect_entry_points(root)` -> list of main entry points (main.py, index.ts, cmd/, etc.)
- `detect_architecture(root)` -> dict with directory structure map, component list
- `read_readme(root)` -> project description extracted from README.md/README
- `detect_test_patterns(root)` -> test directory, test command, test framework
- `discover_features(root, stack)` -> (Core+PM only) list of discovered features with confidence levels
- `generate_report(root)` -> orchestrates all above, writes JSON report

**Feature discovery heuristics** (Core+PM only):
- For web apps: scan route files, API handlers, page components
- For Python: scan top-level modules, class definitions
- For Go: scan `cmd/` directories, package-level comments
- **Monorepo detection**: look for `packages/`, `apps/`, `services/`, `libs/` directories; if found, enumerate sub-projects and detect per-module features
- Generic: top-level directories that are not config/tooling are likely features/modules
- Exclusion list: `utils`, `lib`, `helpers`, `common`, `shared`, `config`, `scripts`, `tools`, `build`, `dist`, `node_modules`, `__pycache__`, `.git`, `.agentic`
- Each discovered feature gets: name, description, confidence (high/medium/low), evidence (file/pattern used)
- JSON output: `discovery_report.json` written to `--output` path

### Step 4: Create the proposal renderer
**Files**: `.agentic/tools/render_proposals.py` (new, ~250 lines)

Takes `discovery_report.json` + template paths, renders proposal-enhanced state files to staging area:
- `render_stack_md(report, template)` -> STACK.md with detected values
- `render_context_pack_md(report, template)` -> CONTEXT_PACK.md with architecture snapshot
- `render_overview_md(report, template)` -> OVERVIEW.md with README-derived description
- `render_features_md(report, template)` -> FEATURES.md with discovered features (Core+PM only)
- `render_acceptance_criteria(report, output_dir)` -> individual F-####.md files (Core+PM only)

Every rendered file gets:
- `<!-- PROPOSAL: Auto-discovered by ag init on YYYY-MM-DD. Review and approve with: ag approve-onboarding -->` at top
- Confidence annotations per section: `<!-- confidence: high|medium|low -->`
- All output written to `.agentic-state/proposals/` (staging area)

### Step 5: Update init_playbook.md for brownfield flow
**Files**: `.agentic/init/init_playbook.md`

Add "Step 0.5: Review Discovery Results" between Step 0 (scaffold) and Step 1 (profile):

> **If `.agentic-state/discovery_report.json` exists**, this is a brownfield project with auto-discovered data:
> 1. Read `.agentic-state/discovery_report.json`
> 2. Present a human-readable summary to the user: detected stack, architecture, entry points, features (if Core+PM)
> 3. For each section, ask: "Does this look right? Want to edit anything?"
> 4. For confirmed sections: copy the proposal file from `.agentic-state/proposals/` to the project root
> 5. For rejected sections: skip (user will fill in manually during Step 2 interview)
> 6. For "I don't know" answers: use the discovery data as-is (it's still a proposal)
> 7. Skip interview questions in Step 2 for sections the user already confirmed

This IS the interactive mode — the agent naturally guides the conversation. No separate code path needed.

### Step 6: Add `ag approve-onboarding` command
**Files**: `.agentic/tools/ag.sh`

New `cmd_approve_onboarding()` function:
- `ag approve-onboarding` (no args): list all files with `<!-- PROPOSAL -->` markers, show per-file status
- `ag approve-onboarding STACK.md`: approve single file (strip `<!-- PROPOSAL -->` and `<!-- confidence: ... -->` markers from that file only)
- `ag approve-onboarding --all`: approve all proposal files at once
- After all approvals: clean up `.agentic-state/discovery_report.json` and `.agentic-state/proposals/`
- Add to command dispatch case statement, add to `show_help()` for both profiles
- Update `cmd_init()` output text to mention auto-discovery when relevant

### Step 7: Add doctor.py proposal awareness
**Files**: `.agentic/tools/doctor.py`

- Add check in validation pipeline: scan state files for `<!-- PROPOSAL -->` markers
- If found, emit a suggestion (not error): "N file(s) have unapproved onboarding proposals. Run: ag approve-onboarding"
- Ensure `looks_like_template()` does NOT trigger false positives on proposal-enhanced files (proposals have real content, not template placeholders)

### Step 8: Add Python unit tests for discover.py
**Files**: `tests/test_discover.py` (new, ~200 lines)

Pytest tests with mock project structures (using `tmp_path` fixtures):
- Test `detect_stack()` with mock Node.js project (package.json), Python project (pyproject.toml), Go project (go.mod)
- Test `discover_features()` for sample layouts with routes, modules
- Test monorepo detection (`packages/` directory pattern)
- Test exclusion lists (`node_modules`, `.git` are ignored)
- Test confidence level assignment (high for config files, medium for file patterns, low for directory inference)
- Test empty/minimal project handling (graceful fallback, no crash)
- Test `read_readme()` with various README formats

### Step 9: Add framework validation checks
**Files**: `tests/validate_framework.sh`

New section "F-0123: Intelligent Onboarding":
- `discover.sh` exists and is executable
- `discover.py` exists
- `render_proposals.py` exists
- `ag approve-onboarding` command recognized (check ag help output)
- init_playbook.md mentions "discovery" or "brownfield" or "existing codebase"
- `discover.py` imports without error (`python3 -c "import sys; sys.path.insert(0,'.agentic/tools'); import discover"`)
- Template files still exist (regression check)

### Step 10: Update .gitignore and feature status
**Files**: `.gitignore`, `spec/FEATURES.md`

- Add `.agentic-state/discovery_report.json` and `.agentic-state/proposals/` to `.gitignore`
- Update F-0123 status to `in_progress` during implementation

## Files to Modify

| File | Action | Est. Lines | Description |
|------|--------|-----------|-------------|
| `.agentic/init/scaffold.sh` | Modify | ~60 modified | Add `detect_existing_codebase()`, `copy_or_propose()`, discovery trigger |
| `.agentic/tools/discover.sh` | **Create** | ~100 new | Bash orchestrator for discovery pipeline |
| `.agentic/tools/discover.py` | **Create** | ~400 new | Python analysis engine with stack/feature detection |
| `.agentic/tools/render_proposals.py` | **Create** | ~250 new | Python proposal renderer with staging area |
| `.agentic/tools/ag.sh` | Modify | ~80 modified | Add `cmd_approve_onboarding()`, update help, update `cmd_init()` text |
| `.agentic/init/init_playbook.md` | Modify | ~40 modified | Add Step 0.5 (discovery review), agent handoff |
| `.agentic/tools/doctor.py` | Modify | ~20 modified | Add proposal marker detection as suggestion |
| `tests/test_discover.py` | **Create** | ~200 new | Python unit tests for discover.py |
| `tests/validate_framework.sh` | Modify | ~20 modified | Add F-0123 validation checks |
| `.gitignore` | Modify | ~2 modified | Add discovery_report.json and proposals/ |
| `spec/FEATURES.md` | Modify | ~2 modified | Update F-0123 status |

**Total new files**: 4 (discover.sh, discover.py, render_proposals.py, test_discover.py)
**Total modified files**: 7
**Estimated lines**: ~950 new, ~224 modified

## Testing Strategy

**Python unit tests** (`tests/test_discover.py`):
- Stack detection for Node.js, Python, Go, Rust mock project structures
- Feature discovery for sample module layouts
- Monorepo detection (packages/, apps/ patterns)
- Exclusion list validation (node_modules, .git ignored)
- Confidence level assignment accuracy
- Empty/minimal project graceful handling
- README parsing for various formats

**Framework validation** (`tests/validate_framework.sh`):
- File existence and executable permission checks
- `ag approve-onboarding` command recognized in help
- init_playbook.md documents brownfield flow
- `discover.py` imports without error
- Template regression checks

**Integration tests** (manual, in scratch project):
1. **Empty project**: Standard flow, no auto-discover offered
2. **Node.js project**: Detect Node.js/TypeScript, propose populated STACK.md
3. **Python project**: Detect Python stack
4. **Monorepo**: Multiple packages/ subdirectories detected as features
5. **Approval test**: `<!-- PROPOSAL -->` markers present, `ag approve-onboarding STACK.md` approves single file
6. **Batch approval**: `ag approve-onboarding --all` strips all markers
7. **Partial approval**: Approve STACK.md but not FEATURES.md, verify doctor.py reports remaining proposals
8. **Re-init test**: Run scaffold.sh twice — `copy_or_propose()` overwrites template-like files but preserves customized ones
9. **Feature discovery test (Core+PM)**: Multiple modules produce FEATURES.md entries
10. **No-break regression**: Full `tests/validate_framework.sh` passes

**Manual verification**:
- [ ] Auto-discover produces reasonable output for a real-world project
- [ ] Agent-guided review (init_playbook Step 0.5) presents findings clearly
- [ ] User can confirm, edit, or reject each section through the agent
- [ ] Confidence levels are accurate
- [ ] Proposal markers are clearly visible and non-intrusive
- [ ] Approval strips markers cleanly without corrupting markdown
- [ ] doctor.py reports unapproved proposals as suggestion, not error

## Risks & Mitigations

- **Risk**: Feature discovery hallucinates features from generic directory names (e.g., `utils/`, `lib/`)
  **Mitigation**: Comprehensive exclusion list. Only suggest features with evidence. Mark all as medium/low confidence unless strong evidence exists. Python unit tests validate exclusion list.

- **Risk**: Python 3 not available on all systems
  **Mitigation**: The framework already requires Python 3. discover.sh checks Python version upfront with clear error.

- **Risk**: Discovery takes too long on large codebases
  **Mitigation**: Set depth limits (max 3 levels), file count limits (10,000 files), timeout (30 seconds). Report partial results if limits hit.

- **Risk**: Proposal markers interfere with other framework tools (doctor.sh, drift.sh)
  **Mitigation**: HTML comment syntax invisible to markdown renderers. Explicit doctor.py step adds proposal awareness (suggestion, not error).

- **Risk**: Breaking the empty-project flow
  **Mitigation**: `detect_existing_codebase()` is a pure check with no side effects. If no source files detected, entire brownfield path is skipped. Integration test #1 validates.

- **Risk**: Discovery report JSON grows large for monorepos
  **Mitigation**: Cap at 50 features. Store in `.agentic-state/` (gitignored).

- **Risk**: `copy_or_propose()` overwrites user customizations
  **Mitigation**: Only overwrites files that still look like templates (bare placeholders). If user has customized, file is preserved and a note is printed.

---

## Review History

### Review 1 (2026-02-08) - iteration 1
**Reviewer**: plan-reviewer-agent

**Issues Found**:

- [ ] CRITICAL: **AC-4 Interactive Mode is underspecified**. The acceptance criteria require: (1) guided questions about project purpose, stack, architecture; (2) ability to combine auto-discover with interactive (auto-discover proposes, human confirms/edits); (3) graceful "I don't know" handling. The plan mentions interactive mode in Step 6 (line: "If interactive: run the standard init_playbook, but pre-seed answers from discovery report") but provides no implementation detail. There is no new script, no new code path, no question flow, no mechanism for "propose and confirm". The interactive mode is essentially hand-waved as "use the existing init_playbook." This is a gap -- the current init_playbook (reviewed at `.agentic/init/init_playbook.md`) has no concept of pre-seeded answers or proposal confirmation. Either a concrete interactive flow needs to be designed (new script or modifications to init_playbook to accept pre-seeded JSON), or AC-4 should be explicitly deferred with justification.

- [ ] CRITICAL: **`cmd_init()` in ag.sh currently does not execute scripts -- it only prints instructions for the human/agent**. The plan's Step 6 says "Modify `cmd_init()` to: After `check_initialization`, run `detect_existing_codebase` ... If auto-discover: run `discover.sh --auto`". But reviewing the actual `cmd_init()` implementation (lines 783-827 of ag.sh), it is purely informational -- it prints text and returns. It never runs scaffold.sh, never executes init_playbook. The actual initialization is done by the AI agent reading the init_playbook. The plan needs to reconcile this: either (a) `cmd_init()` actually needs to be refactored to execute discovery scripts directly (significant refactor), or (b) the brownfield detection should be wired into `scaffold.sh` which IS executed, and the init_playbook updated so the agent knows to use discovery results. Option (b) is more aligned with the existing architecture.

- [ ] IMPORTANT: **`copy_if_missing` in scaffold.sh will skip files that already exist**. In a brownfield project, STACK.md, CONTEXT_PACK.md etc. may have already been created by a previous `ag init` attempt (with placeholder content). The plan puts `detect_existing_codebase()` in scaffold.sh (Step 1) and assumes it runs before file generation, but `scaffold.sh` is designed to be idempotent -- it creates files only if missing. If files already exist with placeholders, the brownfield path needs to handle overwriting them with proposals. The plan does not address this "re-init" or "upgrade" scenario.

- [ ] IMPORTANT: **No mechanism for the agent to consume the discovery_report.json**. The plan generates a JSON report in `.agentic-state/discovery_report.json` and the init_playbook is updated (Step 8), but the plan does not describe how the AI agent (Claude, Cursor, Copilot) actually reads and acts on this JSON. The current init flow is agent-guided (the agent reads the playbook and interviews the user). The plan needs to specify: does the agent read the JSON? Does `render_proposals.py` run automatically and the agent just reviews the output? The handoff between script-generated artifacts and agent-guided flow is unclear.

- [ ] IMPORTANT: **Testing strategy is insufficient for a feature of this scope**. The "unit tests" in `validate_framework.sh` are only file-existence and permission checks. There are no functional tests for the Python scripts: `discover.py` and `render_proposals.py` are ~650 lines of new Python code with complex heuristics (stack detection, feature discovery, template rendering) but the plan relies entirely on manual integration tests. At minimum, `discover.py` should have Python unit tests (pytest or unittest) that verify: (a) stack detection for known project structures (mock directories), (b) feature discovery produces expected output for sample layouts, (c) confidence levels are assigned correctly, (d) exclusion lists work. This is framework code affecting ALL users -- heuristic bugs will cause bad onboarding experiences.

- [ ] IMPORTANT: **AC-5 `ag approve-onboarding` is underspecified for partial approval**. The acceptance criteria say "Human must explicitly approve proposals before they become official" and "Unapproved proposals do not block normal framework operation." But the plan's Step 7 describes a batch-only approval that strips ALL `<!-- PROPOSAL -->` markers at once. There is no mechanism for partial approval (approve STACK.md but reject FEATURES.md). Given that feature discovery is best-effort and likely to need editing, users will want to approve files individually. Consider: `ag approve-onboarding [file]` or `ag approve-onboarding --all`.

- [ ] IMPORTANT: **doctor.sh interaction not addressed**. The plan's risk section mentions "Add a specific check in doctor.sh that warns about unapproved proposals rather than failing" but this is not reflected in any implementation step. No step modifies doctor.sh or doctor.py. If proposals contain placeholder-like content (which they will, since templates have `<!-- fill -->` markers that discovery replaces), the existing doctor.sh checks may report false positives or confusing warnings. This needs an explicit implementation step.

- [ ] SUGGESTION: **Consider placing Python scripts in `.agentic/tools/` instead of `.agentic/init/`**. The existing convention is: `.agentic/init/` contains templates and the bash scaffold, while `.agentic/tools/` contains Python scripts (18 .py files already there). Putting `discover.py` and `render_proposals.py` in `.agentic/init/` breaks this convention. At minimum, explain the rationale, or move them to `.agentic/tools/`.

- [ ] SUGGESTION: **Step 5 is not an implementation step**. "Create the discovery report output" just describes a generated file. This should be folded into Steps 3-4 as an output artifact, not listed as a separate step. It inflates the plan without adding clarity.

- [ ] SUGGESTION: **Monorepo test scenario (test #4 from acceptance criteria) is not addressed in the plan**. The acceptance criteria test scenario says "Monorepo: Handles multiple modules, creates features per module." The plan's feature discovery heuristics mention "top-level directories" but do not describe monorepo-specific logic (e.g., detecting `packages/`, `apps/`, `services/` patterns common in monorepos). Consider at least documenting the heuristic for monorepo detection.

- [ ] SUGGESTION: **The plan estimates ~400 lines for discover.py and ~250 for render_proposals.py, but does not estimate discover.sh**. The estimate section says "~900 new, ~100 modified" which seems about right, but the per-file breakdown should include discover.sh (~80 lines mentioned in Step 2).

**Verdict**: REVISION_NEEDED

**Notes**: The plan demonstrates solid architectural thinking -- the layered discovery approach, JSON intermediate format, and confidence-level heuristics are well-designed. However, there are two critical gaps: (1) the interactive mode (AC-4) is effectively unimplemented in the plan, and (2) the plan assumes `cmd_init()` directly executes scripts, which contradicts the actual architecture where `cmd_init()` is purely informational and the AI agent drives initialization via the playbook. These architectural mismatches need resolution before implementation begins. The testing strategy also needs strengthening for a feature that affects every new user's first experience with the framework. Address the critical and important issues, then request re-review.

**Planner Response (iteration 2)**:

All critical and important issues addressed:

1. **CRITICAL (AC-4 Interactive Mode)**: Redesigned. Interactive mode is now the agent-guided flow enhanced with discovery data. init_playbook.md Step 0.5 tells the agent to read `discovery_report.json`, present findings, ask for confirmation/edits per section. No separate code path needed — the agent's natural conversation handles "guided questions" and "I don't know". See revised Step 5.

2. **CRITICAL (cmd_init architecture)**: Fixed. Discovery is now wired into `scaffold.sh` (which IS executed), not `cmd_init()`. `cmd_init()` stays informational but gets updated text. See revised Step 1.

3. **IMPORTANT (copy_if_missing skip)**: Added `copy_or_propose()` function that overwrites files still matching template patterns but preserves user-customized files. See revised Step 1.

4. **IMPORTANT (agent consuming JSON)**: Explicitly specified in init_playbook.md Step 0.5 — agent reads JSON, presents summary, asks user to confirm/edit each section, copies confirmed proposals from staging area to root. See revised Step 5.

5. **IMPORTANT (testing)**: Added `tests/test_discover.py` with ~200 lines of pytest tests covering stack detection, feature discovery, monorepo, exclusion lists, confidence levels, edge cases. See new Step 8.

6. **IMPORTANT (partial approval)**: `ag approve-onboarding [file]` for single-file, `--all` for batch, no args for status listing. See revised Step 6.

7. **IMPORTANT (doctor.py)**: Added explicit Step 7 — doctor.py gets proposal marker detection as a suggestion (not error), and `looks_like_template()` won't false-positive on proposals.

8. **SUGGESTION (Python scripts location)**: Moved to `.agentic/tools/` per convention.

9. **SUGGESTION (Step 5 folded)**: Discovery report JSON is now documented as output of Steps 3-4, not a separate step. Old Step 5 removed.

10. **SUGGESTION (monorepo heuristics)**: Added `packages/`, `apps/`, `services/`, `libs/` detection to Step 3.

11. **SUGGESTION (discover.sh estimate)**: Included in Files to Modify table (~100 lines).

### Review 2 (2026-02-08) - iteration 2
**Reviewer**: plan-reviewer-agent

**Verification of Review 1 Issues**:

1. CRITICAL (AC-4 Interactive Mode): **RESOLVED**. The plan now correctly identifies that interactive mode = agent-guided discovery review. Step 5 (init_playbook.md) adds "Step 0.5: Review Discovery Results" with a concrete 7-point flow: agent reads JSON, presents summary, asks per-section confirmation, handles "I don't know" by keeping proposals as-is. This is architecturally sound -- it leverages the agent's natural conversation ability rather than building a separate interactive code path. The flow addresses all three AC-4 sub-requirements: guided questions (point 2-3), auto-discover + human confirmation (points 4-5), and "I don't know" handling (point 6).

2. CRITICAL (cmd_init architecture): **RESOLVED**. The plan now correctly wires discovery into `scaffold.sh` (Step 1), which IS executed directly. `cmd_init()` stays purely informational and just gets updated text (Step 6). This aligns with the actual architecture where `scaffold.sh` is the execution point and `cmd_init()` just prints guidance.

3. IMPORTANT (copy_if_missing skip): **RESOLVED**. Step 1 adds `copy_or_propose()` function that checks if existing files still look like templates (using `looks_like_template()` heuristic). Template-like files get overwritten with proposal-enhanced versions; user-customized files are preserved with a note. This handles the re-init scenario correctly.

4. IMPORTANT (agent consuming JSON): **RESOLVED**. The handoff is now explicit in Step 5: agent reads `discovery_report.json`, presents a human-readable summary, asks per-section, copies confirmed proposals from `.agentic-state/proposals/` to project root. The JSON -> agent -> user -> approval pipeline is clear.

5. IMPORTANT (testing): **RESOLVED**. New Step 8 adds `tests/test_discover.py` (~200 lines) with pytest tests covering stack detection (Node.js, Python, Go), feature discovery, monorepo detection, exclusion lists, confidence levels, empty project handling, and README parsing. This is adequate coverage for the heuristic-heavy code.

6. IMPORTANT (partial approval): **RESOLVED**. Step 6 now specifies three modes: `ag approve-onboarding` (no args = list status), `ag approve-onboarding STACK.md` (single-file approval), `ag approve-onboarding --all` (batch). This covers the partial approval use case.

7. IMPORTANT (doctor.py): **RESOLVED**. New Step 7 adds explicit doctor.py modifications: scan for `<!-- PROPOSAL -->` markers, emit as suggestion (not error), and ensure `looks_like_template()` does not false-positive on proposal-enhanced files.

8. SUGGESTION (Python scripts location): **RESOLVED**. Scripts moved to `.agentic/tools/` per existing convention. The Files to Modify table and Step 2/3/4 all reference `.agentic/tools/`.

9. SUGGESTION (Step 5 folded): **RESOLVED**. The old "discovery report output" step was removed. JSON output is now documented as part of Steps 3-4. The step numbering is clean: 1 (scaffold.sh), 2 (discover.sh), 3 (discover.py), 4 (render_proposals.py), 5 (init_playbook), 6 (ag.sh), 7 (doctor.py), 8 (tests), 9 (validation), 10 (gitignore/features).

10. SUGGESTION (monorepo heuristics): **RESOLVED**. Step 3 now includes explicit monorepo detection: "look for `packages/`, `apps/`, `services/`, `libs/` directories; if found, enumerate sub-projects and detect per-module features." Integration test #4 validates monorepo handling.

11. SUGGESTION (discover.sh estimate): **RESOLVED**. The Files to Modify table now includes `discover.sh` at ~100 lines. Total estimates updated to ~950 new, ~224 modified across 4 new + 7 modified files.

**New Issues Check**:

- [ ] SUGGESTION: **`.gitignore` needs wildcard or additional entries for `.agentic-state/`**. The current `.gitignore` uses specific file paths (`.agentic-state/WIP.md`, `.agentic-state/AGENTS_ACTIVE.md`, `.agentic-state/.verification-state`) rather than a directory-wide wildcard. The plan's Step 10 says "Add `.agentic-state/discovery_report.json` and `.agentic-state/proposals/` to `.gitignore`" which is correct, but the implementer should be aware this means adding two new entries, not that these are already covered. Minor -- the plan correctly identifies what to add. No action needed.

- [ ] SUGGESTION: **AC-1 says "Offers choice: auto-discover mode vs full interactive interview" but the plan's architecture merges these into a single flow**. In the revised plan, discovery runs automatically in scaffold.sh when a brownfield project is detected, and the agent-guided review always follows. There is no explicit "Do you want auto-discover or manual interview?" choice offered to the user. However, this is arguably a better UX: always auto-discover (it is fast and non-destructive), then let the user confirm/reject per-section during the agent-guided review. The AC could be interpreted as satisfied because the user can reject all proposals and fall through to the standard interview. This is a minor gap in AC coverage but the implementation approach is sound. Consider documenting this design decision in an ADR or comment.

- [ ] SUGGESTION: **`copy_or_propose()` depends on `looks_like_template()` from doctor.py, but scaffold.sh is bash**. Step 1 says `copy_or_propose()` "checks if existing state files still look like templates (bare placeholders)." The `looks_like_template()` function currently lives in doctor.py (Python). The plan should clarify that scaffold.sh will implement its own bash version of this heuristic (checking for `(Template)` in the first line or placeholder markers), not call the Python function. The existing scaffold.sh already has pattern matching for `(Template)` in the title line (line 74), so this is straightforward, but the plan should be explicit about the bash implementation.

**Assessment of Overall Plan Quality**:

The revised plan is well-structured and addresses all critical and important issues from Review 1. Key strengths:

- **Architectural alignment**: Discovery correctly wired into `scaffold.sh` (the execution point), not `cmd_init()` (informational only). This matches the actual codebase architecture.
- **Agent-driven interactive mode**: Leveraging the agent's natural conversation ability via init_playbook Step 0.5 is the right design. No unnecessary code for what agents already do well.
- **Staging area pattern**: Proposals in `.agentic-state/proposals/` with `<!-- PROPOSAL -->` markers is clean. Approval strips markers. Doctor.py aware.
- **Testing**: Adequate Python unit tests for heuristic code, plus framework validation and manual integration tests.
- **Scope**: 4 new files, 7 modified files, ~1174 lines total. This is within the framework's "small batch" guidelines.
- **Risk mitigations**: Comprehensive -- Python availability, large codebases, false positives, empty projects, marker interference.

The three new suggestions above are all minor (SUGGESTION level). None require plan revision before implementation.

**Verdict**: APPROVED

**Notes**: The plan is ready for implementation. The planner thoroughly addressed all 11 issues from Review 1. The architectural decisions are sound: scaffold.sh as the integration point, agent-guided review as the interactive mode, staging area for proposals, and modular Python scripts in `.agentic/tools/`. The three new suggestions are minor and can be addressed during implementation without plan revision. Proceed with `ag implement F-0123`.
