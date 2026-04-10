# Framework Development Guidelines

**🎯 Scope**: Additional guidelines for agents working **ON the Agentic AI Framework itself** (not projects using it).

**For projects using the framework**: See [`.agentic/conventions.md`](.agentic/conventions.md) and role prompts in [`.agentic/prompts/`](.agentic/prompts/).

---

## Core Responsibilities

When working on the framework repository (`agentic-framework`), you have additional responsibilities beyond normal project development:

### 1. **Maintain Internal Consistency**

Every change must maintain consistency across:
- ✅ Templates in `.agentic/lib/init/` and `.agentic/lib/templates/`
- ✅ Example projects in `examples/`
- ✅ Documentation in `README.md`, `START_HERE.md`, `DEVELOPER_GUIDE.md`
- ✅ Agent guidelines in `.agentic/lib/agents/`
- ✅ Tool scripts in `.agentic/lib/tools/`

**Rule**: If you change a template, workflow, or guideline → update examples and docs to match.

---

### 2. **Example Projects Are First-Class Citizens**

Example projects demonstrate best practices and verify workflows actually work.

**When to update examples**:
- ✅ Adding new framework features
- ✅ Changing templates or guidelines
- ✅ Modifying workflow documents
- ✅ Updating quality standards

**How to update examples**:
1. List all example projects: `ls examples/`
2. For each example in relevant profile (Discovery or Formal):
   - Apply changes manually or regenerate
   - Verify scripts work: `doctor.py`, `verify.py`, etc.
   - Test quality checks if applicable
   - Update example READMEs if workflow changed
3. Commit examples with framework changes

**Example projects to maintain**:
- `examples/core_todo_cli/` - Discovery profile example
- `examples/core_pm_taskboard/` - Formal profile example
- Keep `examples/old/` as reference but don't update

---

### 3. **Documentation Single Source of Truth**

**The DRY Rule**: Information lives in ONE place, others reference it.

**Master documents** (single source of truth):
- **`DEVELOPER_GUIDE.md`**: All script explanations, comprehensive command table, automation guide
- **`PRINCIPLES.md`**: All framework principles and values
- **`STACK.template.md`**: Canonical structure for STACK.md
- **`FEATURES.template.md`**: Canonical structure for FEATURES.md

**Reference documents** (cross-reference masters):
- **`MANUAL_OPERATIONS.md`**: Quick patterns, references DEVELOPER_GUIDE for details
- **`START_HERE.md`**: Navigation, references comprehensive docs
- **`README.md`**: Overview, links to detailed guides

**When updating information**:
1. Find where it lives authoritatively (usually DEVELOPER_GUIDE or PRINCIPLES)
2. Update ONCE in that location
3. Verify cross-references are still accurate
4. Don't duplicate - add cross-reference if needed

**Anti-pattern**: ❌ Copying script explanation to 3 files instead of putting in DEVELOPER_GUIDE and referencing it.

#### Agent Instruction Files (CLAUDE.md, Cursor Rules, etc.)

**Canonical source**: `.agentic/lib/agents/<tool>/` contains what users receive.

```
.agentic/lib/agents/claude/CLAUDE.md     ← CANONICAL (develop features here)
         ↓
/CLAUDE.md (root)                    ← Framework-specific wrapper only
```

**The dogfooding rule**:
1. **Develop features in `.agentic/`** - the template users receive
2. **Root files extend, not replace** - add only project-specific notes
3. **Never let root diverge** - if root has features template doesn't, backport immediately

**v2 instruction file set** (reduced from ~11 to ~5):
- `.agentic/prompts/*.md` — 7 role prompts (planner, reviewer, implementer, verifier, debugger, session, explorer)
- `.agentic/conventions.md` — consolidated coding conventions
- `.agentic/state_machine_af.yaml` — workflow states, transitions, modes, profiles
- Agent instruction files — CLAUDE.md, .cursorrules, copilot-instructions.md, codex-instructions.md (behavioral rules only)
- `.claude/skills/` — 13 trigger-word stubs (route to `ag` commands)

**Removed in v2** (content absorbed into role prompts + conventions.md + CLI enforcement):
- Checklists (`.agentic/lib/checklists/`) — gate logic moved to `preconditions.py`
- Workflow docs (`.agentic/lib/workflows/`) — sequencing moved to state machine
- Quality standards (`.agentic/quality/`) — merged into `conventions.md`
- Subagent definitions (`.agentic/lib/agents/roles/`, `subagents/`) — replaced by role prompts
- Full skill bundles (instructions + scripts + references) — replaced by trigger-word stubs

**When adding new features to CLAUDE.md**:
1. Add to `.agentic/lib/agents/claude/CLAUDE.md` FIRST
2. Test that users would benefit from it
3. Only then update root `/CLAUDE.md` if framework-dev needs something extra
4. CLAUDE.md is loaded for the orchestrating agent only. Subagents do NOT inherit it — confirmed for Claude Code (Task tool) and Cursor; Copilot behavior unverified; Codex subagents experimental. Keep templates under 100 lines for orchestrator attention quality (L-0002). Run LLM behavioral tests (`bash tests/llm/harness.sh --critical`) after changes.

**Design basis**: `docs/INSTRUCTION_ARCHITECTURE.md` — the definitive instruction architecture design. Source research: `docs/research/context_and_subagents_research_2026_02_06.md` (ChatGPT 5.2), `docs/research/2026-02-07-subagent-context-inheritance.md` (Claude Opus 4.6).

**Template vs Root — what differs and why**:

| Content | Template (`.agentic/lib/agents/`) | Root (`CLAUDE.md`, etc.) |
|---------|-------------------------------|--------------------------|
| Context opener | "You are working in a repo that uses..." | "THIS IS FRAMEWORK DEVELOPMENT. You are working ON the framework..." |
| "Read first" directive | NO | YES — `FRAMEWORK_QUICK_START.md`, `FRAMEWORK_DEVELOPMENT.md`, `PRINCIPLES.md` |
| Architecture pointer | NO | YES — `docs/INSTRUCTION_ARCHITECTURE.md` |
| Trigger table | YES | YES (identical) |
| Token-efficient scripts | YES | YES (identical) |
| Small batch rules | YES | YES (identical) |
| Playbook pointer | YES | YES (identical) |
| Framework validation | NO | YES — `bash tests/validate_framework.sh` |
| Framework-dev footer | NO | YES — dogfooding, worktree, spec-first |

**Sync rules**:
- If root has content template doesn't, and it's NOT framework-specific → backport immediately
- Templates must never exceed root for shared concerns

**Cursor note**: Root `.cursorrules` (29 lines) is a lean framework-dev file. Template `cursorrules.txt` (39 lines) is the user-project version (slimmed to align with three-layer architecture). The `.mdc` file (37 lines) is the slimmed Cursor format.

**Anti-pattern**: ❌ Adding `ag` CLI commands to root CLAUDE.md but not the template users get.

#### Agent-Agnostic by Default

The framework supports Claude, Cursor, Copilot, Codex equally. **Practical consequence for framework developers:**

- Scripts and tools go in `.agentic/lib/tools/`, NOT in `.claude/skills/*/scripts/`
- `.claude/skills/` are a "works even better in Claude Code" enhancement layer — they reference `.agentic/` tools, they don't contain the tools
- Each agent tool has its own delivery mechanism (`.claude/skills/`, `.cursor/rules/`, `copilot-instructions.md`), but the shared infrastructure lives in `.agentic/`
- If a capability only exists in one tool's directory, other agents can't use it

**Anti-pattern**: ❌ Putting a scanner script in `.claude/skills/session-start/scripts/` instead of `.agentic/lib/tools/`.
**Correct**: Script in `.agentic/lib/tools/dashboard.sh`, Claude skill calls it via `bash .agentic/lib/tools/dashboard.sh`.

Design basis: PRINCIPLES.md D7 (Multi-Environment Portability).

#### Memory Seed Maintenance

`.agentic/lib/init/memory-seed.md` seeds behavioral patterns into tool persistent memory during init. It is a **subset** of instruction files/playbooks — redundant for resilience, not a place for new rules.

**When to update memory-seed.md**:
- Workflow changes (new pre-commit steps, new `ag` commands)
- New behavioral rules added to instruction files that benefit from memory reinforcement
- Version bumps (always bump `<!-- memory-seed vX.Y.Z -->` when content changes)

**Update process**:
1. Edit `.agentic/lib/init/memory-seed.md`
2. Bump the version marker: `<!-- memory-seed vX.Y.Z -->`
3. Verify sentinel strings still present: `pre-commit sequence`, `token-efficient scripts`, `ag commit`, `ag done`, `ag flush`
4. Run `bash .agentic/tools/memory-check.sh` to verify alignment
5. If sentinels change, update the `SENTINELS` array in `memory-check.sh` and the `<!-- sentinels: ... -->` comment in memory-seed.md

**Key rule**: Memory-seed must never contain rules that aren't already in instruction files or playbooks. It reinforces; it doesn't originate.

---

### 4. **Test Framework Changes**

**Before committing changes to framework core**:

1. **Test in a scratch project**:
   ```bash
   mkdir /tmp/test-framework
   cd /tmp/test-framework
   git init
   bash /path/to/agentic-framework/install.sh .
   ```

2. **Verify initialization**:
   - Run through init_playbook.md
   - Test both Discovery and Formal profiles
   - Verify scaffold.sh creates correct files

3. **Test tools work**:
   ```bash
   python .agentic/tools/doctor.py
   python .agentic/tools/verify.py
   bash .agentic/tools/brief.sh
   ```

4. **Test workflows**:
   - Add a feature (Formal)
   - Implement with TDD
   - Run quality checks
   - Verify documentation updates

5. **Test upgrade path** (if changing templates/structure):
   ```bash
   cd /tmp/old-project  # Project on vX.Y.Z
   bash /path/to/new-framework/upgrade.sh
   # Verify upgrade worked
   ```

**Anti-pattern**: ❌ Changing templates without testing in real project. ❌ "It should work" without verification.

---

### 5. **Version Management**

**When bumping framework version**:

1. **Update `VERSION` file**:
   ```bash
   echo "X.Y.Z" > VERSION
   ```

2. **Update `CHANGELOG.md`**:
   - Add new version section at top
   - List all changes (Added, Changed, Fixed, Removed)
   - Reference issue/PR numbers if applicable
   - Date the release

3. **Update version references**:
   - `README.md` (current version)
   - `CONTRIBUTIONS.md` (current version at bottom)
   - Any docs referencing specific versions

4. **Update example projects**:
   - Update `STACK.md` in each example: `Version: X.Y.Z`
   - Test examples still work

5. **Git tag**:
   ```bash
   git tag -a vX.Y.Z -m "Release vX.Y.Z: [brief description]"
   git push origin vX.Y.Z
   ```

6. **Create GitHub release** (manual in GitHub UI) - **REQUIRED**:
   - Copy CHANGELOG entry
   - Attach release notes
   - GitHub auto-creates release packages

   ⚠️ **IMPORTANT**: Tag alone is NOT enough! `remote-upgrade.sh` downloads from
   `/archive/refs/tags/vX.Y.Z.tar.gz` which only works after a GitHub Release is
   created. Without the release, the tarball URL returns stale content.

**Semantic Versioning**:
- **Major (1.0.0)**: Breaking changes, incompatible with old projects
- **Minor (0.2.0)**: New features, backward compatible
- **Patch (0.2.1)**: Bug fixes, no new features

---

### 6. **Template Changes Require Careful Thought**

**Templates are copied to user projects**. Changes affect all future projects and upgrades.

**Before changing templates**:
1. **Consider backward compatibility**: Can old projects upgrade?
2. **Update upgrade.sh if needed**: Handle migration from old → new structure
3. **Update validation**: `validate_specs.py`, `doctor.py` must handle new structure
4. **Document breaking changes**: In CHANGELOG.md and UPGRADING.md

**Template files**:
- `.agentic/lib/init/*.template.md` - Initial project files
- `.agentic/lib/templates/*.template.md` - Spec document structures

**When changing template structure**:
1. Update the template
2. Update spec schema (if JSON/YAML structure changed)
3. Update validation scripts
4. Test in scratch project
5. Update examples to use new structure
6. Update UPGRADING.md if breaking
7. Consider backward compat in upgrade.sh

---

### 7. **Principles Are Sacred**

**`PRINCIPLES.md` is the framework's constitution**. Changes require strong justification.

**When proposing changes to principles**:
1. Explain what principle to change and why
2. Show what problem current principle causes
3. Demonstrate new principle aligns with core philosophy
4. Get user approval before implementing
5. Update all docs referencing the principle

**Adding new principles**:
- Should emerge from real experience, not theory
- Should have clear "What, Why, How, Example, Anti-pattern"
- Should fit existing structure

**Anti-pattern**: ❌ Changing principles based on single use case. ❌ Adding principles that contradict core philosophy.

---

### 8. **Framework Documentation Audience**

Different docs serve different readers:

**For framework users** (developers using framework in their projects):
- `README.md` - Overview and installation
- `START_HERE.md` - Quick orientation
- `DEVELOPER_GUIDE.md` - Daily usage
- `PRINCIPLES.md` - Understanding "why"
- `MANUAL_OPERATIONS.md` - Token-free operations

**For agents working in user projects**:
- `.agentic/conventions.md` - Consolidated coding conventions
- `.agentic/prompts/*.md` - Role-specific guidance (planner, implementer, reviewer, etc.)
- `.agentic/state_machine_af.yaml` - Workflow states, transitions, gates

**For framework developers** (working ON framework):
- **This file** (`FRAMEWORK_DEVELOPMENT.md`)
- `PRINCIPLES.md` - Core values
- `CHANGELOG.md` - Version history
- `UPGRADING.md` - Upgrade process

**For framework contributors**:
- `PRINCIPLES.md` - Understanding philosophy
- This file - Development process
- Example projects - See it in action

**Rule**: Know your audience. User-facing docs shouldn't discuss framework internals. Framework dev docs shouldn't be in release package.

---

### 9. **Quality Standards Apply to Framework**

The framework must follow its own quality standards:

**Code quality**:
- ✅ Python scripts follow programming_standards.md
- ✅ Shell scripts are POSIX-compatible where possible
- ✅ Clear error messages (actionable, not cryptic)
- ✅ Fail fast with clear diagnostics

**Documentation quality**:
- ✅ Accurate (reflects reality, tested)
- ✅ Clear (no ambiguity)
- ✅ Comprehensive (covers all use cases)
- ✅ Consistent (terminology, style)
- ✅ Single source of truth (no duplication)

**Testing**:
- ✅ Test scripts in scratch projects
- ✅ Verify examples work
- ✅ Test upgrade paths
- ✅ Manual verification (no unit tests for framework yet)

**Anti-pattern**: ❌ "Do as I say, not as I do" - framework violating its own principles.

---

### 10. **Git Workflow for Framework**

**Branch strategy** (PR-based, dogfooding our own recommendation):
- `main` - Stable, released versions (protected)
- Feature branches for ALL changes: `feature/F-####-description`
- Create PR for review before merging to main
- Tag releases: `vX.Y.Z`

**Workflow**:
```bash
# Create feature branch
git checkout -b feature/F-0098-new-feature

# Work, commit to branch
git add . && git commit -m "feat: description"

# Push and create PR
git push -u origin feature/F-0098-new-feature
gh pr create --title "feat: New feature (F-0098)" --body "..."

# After review, merge PR
```

**Commit messages**:
Follow conventional commits:
```
type(scope): description

Body explaining what and why (optional)
```

**Types**:
- `feat`: New feature (minor version bump)
- `fix`: Bug fix (patch version bump)
- `docs`: Documentation only
- `refactor`: Code restructuring, no behavior change
- `test`: Adding/updating tests
- `chore`: Build process, dependencies

**Examples**:
```
feat(quality): add mutation testing support
fix(upgrade): handle missing VERSION file gracefully
docs(principles): clarify "shipped ≠ accepted" concept
refactor(docs): eliminate documentation duplication
```

**Before pushing**:
1. ✅ Test changes in scratch project
2. ✅ Update examples if needed
3. ✅ Update documentation
4. ✅ Update CHANGELOG (for releases)
5. ✅ Run through user workflows manually

---

### 11. **Release Checklist**

**When releasing a new version**:

- [ ] All changes tested in scratch project
- [ ] Example projects updated and working
- [ ] **`bash .agentic/tools/drift.sh --docs` passes** (no stale docs)
- [ ] Documentation accurate and up-to-date
- [ ] **`.agentic/spec/FEATURES.md` updated with new features (F-####)**
- [ ] **`.agentic/spec/acceptance/F-####.md` created for new features**
- [ ] **`tests/validate_framework.sh` updated if new acceptance criteria**
- [ ] **`FEATURE_REGISTRY` in upgrade.sh updated if user-visible feature**
- [ ] **Manifests generated**: `bash .agentic/tools/manifest.sh F-####` for each feature
- [ ] `VERSION` file updated
- [ ] `CHANGELOG.md` updated with all changes
- [ ] `CONTRIBUTIONS.md` updated with version section
- [ ] Installation instructions reference correct version (README, DEVELOPER_GUIDE, UPGRADING, START_HERE, MANUAL_OPERATIONS)
- [ ] All commits pushed to main
- [ ] Git tag created: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
- [ ] Tag pushed: `git push origin vX.Y.Z`
- [ ] GitHub release created with CHANGELOG excerpt
- [ ] Release packages auto-generated by GitHub
- [ ] Installation tested from GitHub release
- [ ] Upgrade tested from previous version

**Dogfooding**: The framework uses its own spec-driven methodology. New framework features MUST be specced just like product features!

**Post-release**:
- [ ] Start next version in CHANGELOG (## [Unreleased])
- [ ] Update README version if showing "latest"

**Ongoing documentation (don't wait for release)**:
- **CONTRIBUTIONS.md**: Update periodically as features are implemented (not just at release time)
- **CHANGELOG.md**: Add entries as changes are made (## [Unreleased] section)

---

### 12. **Common Framework Development Patterns**

**Adding a new workflow document** (v2):
1. Determine which role prompt(s) need updating in `.agentic/prompts/`
2. If adding a new workflow state, update `state_machine_af.yaml` (transitions, preconditions)
3. If adding cross-cutting conventions, update `.agentic/conventions.md`
4. Link from `DEVELOPER_GUIDE.md` if users should know about it
5. Add example to relevant example project

**Adding a new tool script**:
1. Create `.agentic/lib/tools/new_tool.sh` or `.agentic/lib/tools/new_tool.py`
2. Add shebang and error handling
3. Add help text (`-h` flag)
4. Test in scratch project
5. Document in `DEVELOPER_GUIDE.md` (comprehensive)
6. Add quick example to `MANUAL_OPERATIONS.md` (if token-free info retrieval)
7. Update `START_HERE.md` tools list

**Adding a new agent role**:
1. Create `.agentic/lib/agents/[role]/README.md`
2. Define what agent loads/doesn't load (context budget)
3. Define handoff protocol (input/output)
4. Update `sequential_agent_specialization.md`
5. Update `automatic_sequential_pipeline.md`
6. Test with real feature in example project
7. Document in `DEVELOPER_GUIDE.md`

**Changing existing template**:
1. Update `.agentic/lib/init/*.template.md` or `.agentic/lib/templates/*.template.md`
2. Update validation (`validate_specs.py`, `doctor.py`)
3. Update upgrade.sh for migration (if breaking)
4. Update examples to new structure
5. Test scaffold.sh creates correct files
6. Test upgrade from old → new
7. Document in CHANGELOG (if breaking: major/minor version bump)

**Adding a new framework feature**:
1. Add feature spec to `.agentic/spec/FEATURES.md` (F-#### format)
2. Create acceptance criteria in `.agentic/spec/acceptance/F-####.md`
3. Add structural tests to `tests/validate_framework.sh` (verifies files exist, settings present, script behaviour)
4. If the feature changes how agents behave: add LLM behavioral tests to `tests/llm/test_definitions.json` and list them in `.agentic/spec/acceptance/F-####.md` under `## LLM Behavioral Tests`
5. If user-visible during upgrade, add to FEATURE_REGISTRY (see below)
6. If the feature affects code quality, security, testing, or library recommendations: update relevant files in `.agentic/lib/quality_knowledge/` (universal knowledge) or add stack-specific entries to YAML knowledge files
7. Run `bash .agentic/tools/drift.sh --docs` to check for stale docs
8. Update CHANGELOG.md
9. Update CONTRIBUTIONS.md
10. Generate manifest: `bash .agentic/tools/manifest.sh F-####`

**Running QA audits on framework changes**:
1. `ag audit` — verify spec→AC→test chain for recently changed features
2. `ag audit --full` — full audit report to `docs/retrospectives/`
3. `ag audit --propagate NFR-XXXX` — after changing an NFR, trace downstream impact
4. `ag nfr coverage` — check which features reference each NFR
5. QA tracker (`qa-tracker.sh`) auto-creates propagation items when migrations or NFR changes occur
6. Propagation items escalate over time: info → warn (3d) → escalate (7d)

**For spec changes (adding/modifying features in FEATURES.md)**:
- Use `bash .agentic/tools/migration.sh create "description"` to create a migration
- Migrations provide auditable history of spec evolution
- Run `bash .agentic/tools/migration.sh list` to see all migrations

**Adding to FEATURE_REGISTRY (upgrade notifications)**:
When adding a user-visible feature that should be offered during upgrades:

1. Edit `.agentic/lib/tools/upgrade.sh`
2. Find the `FEATURE_REGISTRY` array (~line 360)
3. Add entry: `"X.Y.Z:Feature Name:setup command:Description"`
   - X.Y.Z = version where feature is introduced
   - Feature Name = short name shown to user
   - setup command = command to enable/setup the feature
   - Description = brief explanation

Example:
```bash
declare -a FEATURE_REGISTRY=(
  "0.5.0:Sub-agent setup:bash .agentic/tools/setup-agent.sh cursor-agents:Specialized agents"
  "0.12.0:New Feature:bash .agentic/tools/setup-new.sh:Description here"
)
```

Users upgrading FROM a version BEFORE X.Y.Z will see the feature offer.
Users already past X.Y.Z will NOT see it (prevents repeated prompts).

---

## Framework Development Anti-Patterns

### ❌ Don't Change Templates Without Testing

**Why wrong**: Breaks all future projects and upgrades.

**Correct**: Test in scratch project, test upgrade path, update examples.

---

### ❌ Don't Update Docs Without Verifying Accuracy

**Why wrong**: Inaccurate docs are worse than no docs.

**Correct**: Test every code example, verify every workflow, check every link.

---

### ❌ Don't Duplicate Documentation

**Why wrong**: Update in 3 places = errors, maintenance burden.

**Correct**: Single source of truth with cross-references.

---

### ❌ Don't Break Backward Compatibility Casually

**Why wrong**: Existing projects can't upgrade, users lose trust.

**Correct**: Consider compatibility, provide upgrade path, document breaking changes.

---

### ❌ Don't Add Features Without Use Case

**Why wrong**: Framework bloat, confusing users, maintenance burden.

**Correct**: Real problem → solution → test in examples → release.

---

### ❌ Don't Create New Features for Improvements to Existing Ones

**Why wrong**: Feature IDs (F-XXXX) represent user-facing capabilities. When enforcement, propagation, wiring, or hardening is missing from an existing feature, creating a new F-XXXX fragments ownership, inflates the backlog, and obscures what "done" means for the original feature. Example: "plan changes don't propagate to ACs" is not a new capability — it's incomplete spec system (F-031).

**Correct**: Ask "which existing feature owns this?" Add it as a deliverable (D-level) on that feature. Only create a new F-XXXX when the gap is a genuinely new capability that no existing feature covers.

---

### ❌ Don't Commit Without Testing

**Why wrong**: Broken framework blocks all users.

**Correct**: Test in scratch project, update examples, verify workflows.

---

### ❌ Don't Release Without Updating CHANGELOG

**Why wrong**: Users don't know what changed, can't track regressions.

**Correct**: Every release has complete, dated CHANGELOG entry.

---

### ❌ Don't Violate Framework's Own Principles

**Why wrong**: "Do as I say, not as I do" kills credibility.

**Correct**: Framework follows its own quality, testing, documentation standards.

---

## Lessons Learned

Hard-won insights from framework development. These live here (in the repo) so they're available to any agent on any machine — NOT in auto-memory, which is machine-local.

### Plans given as user messages don't auto-save

Only plans created through plan mode (`/plan` / `EnterPlanMode`) get saved to `~/.claude/plans/`. When a user pastes a plan as a regular message ("Implement the following plan:"), there's nothing in `~/.claude/plans/` to copy. The "save plan after approval" rule silently doesn't apply. **Always save the plan to `.agentic/journal/plans/`** — whether it came from plan mode or a user message. If the plan is in the conversation but not in a file, write it to a file yourself.

### Plan mode bypasses spec-first workflow (I-0002)

Plan mode + session continuation are **blind spots** for the "create F-XXXX FIRST" trigger. The plan file feels like "we already planned it" but it's NOT a feature spec — it's session-scoped. **Always check**: does this work have an F-XXXX in FEATURES.md and `spec/acceptance/F-XXXX.md`? If not, create them before writing code — even if a plan exists. Tracked as I-0002 in `spec/ISSUES.md`.

### Finalize artifacts before announcing "done"

JOURNAL.md and STATUS.md must be updated BEFORE saying "ready to commit." Sequence: implement → tests pass → update journal/status → THEN announce readiness. Don't wait for the user to remind you.

### Don't remove features when slimming instruction files

Build Artifact Stamping was accidentally removed during guidelines slimming — it was a real feature. When slimming files, CHECK each section: is it dead weight or active functionality? If in doubt, keep it and ask.

### Never destroy another agent's work on main

`git clean -fd` on main destroys untracked files that may belong to another agent's in-progress work. Untracked files (plans, specs, new scripts) are NOT in git stash unless `--include-untracked` was used. Safe approach: move to /tmp first, or don't touch main at all. For tagging after merge: `git tag v0.X.0 origin/main && git push origin v0.X.0` — no checkout needed.

### Path reference updates after file moves

When moving a file (`git mv docs/X docs/Y`), grep ALL files for old path — including gitignored files (`.agentic/session/`).

### ag.sh / validate_framework.sh length

Both exceed `max_code_file_length=1200` (ag.sh ~2100, validate_framework.sh ~1890). Commits touching these require temporarily raising the limit. Needs eventual splitting/refactoring.

### D4 "Small Batch" is about agent context, not commit size

The 5-10 file limit per commit is a proxy for the real constraint: each agent task must fit within context with full comprehension. A PR can legitimately touch many files across multiple commits. Enforcement should move from commit-time to planning-time. Source: user clarification (2026-03-01).

### Settings env var overrides for testing

`settings.sh` supports `_SETTINGS_ROOT_DIR`, `_SETTINGS_STACK_FILE`, `_SETTINGS_PROFILES_CONF` env overrides. Combined with `ROOT_DIR` override in ag.sh and `_AGENTIC_SETTINGS_LOADED=""` to force re-init. Essential for isolated gate tests in `validate_framework.sh`.

### Never `git reset --hard` to reconcile diverged branches

When local main and remote main diverge (e.g., local has direct commits, remote has PR merge commits), **do not** use `git reset --hard origin/main` to "fix" the divergence. This silently drops local-only commits with no recovery path. In the v0.52.2 session, this destroyed a TZ config fix that had no corresponding PR. Safe approach: `git log origin/main..main --stat` to inspect what's local-only, verify each commit has a remote counterpart, then `git pull --rebase` to reconcile. The rule already exists in memory-seed ("Never destroy unstaged work") — this is the same principle applied to committed-but-unpushed work.

### Keep local main in sync with origin

Two rules to prevent local/remote divergence in the first place:
1. **Push main after committing to it.** Every direct-to-main commit (chores, hotfixes) should be pushed immediately — don't let local main drift ahead of origin. Unpushed commits on main are invisible to PRs and other agents.
2. **Sync before branching.** Before creating a feature branch from main, always `git pull --rebase origin main` first. A branch created from stale main will have conflicts with content that's already on remote, leading to messy rebases and accidental content loss (as happened in the v0.52.2 dashboard PR).

### LLM agents lose continuity at turn boundaries (plan-review case study)

When a workflow spans turn boundaries (user message, skill re-matching, context compression), Phase N+1's instructions may not be active when Phase N+1 runs. The plan-review gate was the hardest behavioral fix in the framework — it took multiple attempts across sessions before the agent reliably ran dialectical review after exiting plan mode instead of jumping straight to implementation.

**The problem:** When `plan_review_enabled: yes`, exiting plan mode should trigger: save plan as DRAFT → dialectical review (Critic + Advocate agents) → user approval → APPROVED → implement. Instead, the agent would exit plan mode and immediately start coding — reading implementation files, exploring the codebase, writing code — completely skipping the review loop.

**What failed (and why):**

1. **Adding instructions to skills (implementing-features SKILL.md).** Added Step 0.5 with plan gate logic, anti-pattern warnings. *Failed because:* plan mode exit ends the turn; the user's next message triggers fresh skill matching; the implementing-features skill activates but the agent has already decided what to do. Skill instructions are guidance, not gates.

2. **Adding instructions to more files (memory-seed, feature_start.md checklist, CLAUDE.md).** Spread the same "you MUST review before implementing" rule across 5+ instruction files. *Failed because:* textual instructions have diminishing returns. The 7th file saying "you MUST" has near-zero marginal effect on behavior. The agent can "agree" with the instruction and still rationalize skipping it.

3. **Adding anti-pattern warnings** ("Do NOT read implementation files before plan review"). *Failed because:* the agent rationalizes around prohibitions. It would acknowledge the warning and then explore files anyway "to prepare" or "to understand context." Telling the agent what not to do doesn't create a hard stop.

4. **Relying on `ag implement` script gate alone.** The gate existed (`exit 1` when plan not approved) but the auto-save step (copying plans from `~/.claude/plans/` to `.agentic/journal/plans/`) ran AFTER the gate check. So the gate would say "no plan found" → exit 1 → agent would interpret this as "I need to create a plan" rather than "the plan I just made needs review." A sequencing bug in ag.sh made the correct gate ineffective.

**What finally worked (three changes together):**

1. **Fix the sequencing bug in ag.sh.** Moved auto-save (step 0c) BEFORE the gate check (step 0d). Now `ag implement` finds the plan saved from `~/.claude/plans/`, checks its status, and blocks with `exit 1` if not APPROVED. The agent hits a real wall, not a suggestion. This was the critical fix — without it, the gate was checking for a file that hadn't been copied yet.

2. **Embed continuation instructions in the plan artifact itself.** Added a `POST-PLAN-MODE ACTIONS (MANDATORY)` block directly into the plan output that plan mode generates. This block says "Status: DRAFT. This plan is NOT approved for implementation." followed by the 4 steps to follow. *Why this works:* the artifact survives turn boundaries because it's the work product, not guidance about the work product. When the next turn starts, the agent sees these instructions in its own output, not in a skill file it may or may not have loaded.

3. **Name the rationalizations the agent uses to skip review.** Added a "These rationalizations are WRONG" block to CLAUDE.md (both template and root) listing the 6 specific excuses the agent invents: "the user created the plan so it's reviewed", "plan mode exit = approval", "the user said implement", "simple plan, review unnecessary", "I have it in context", "ag implement told me to review, I'll assess it myself." *Why this works:* it's harder for the agent to use an excuse when the excuse is pre-labeled as wrong. Generic "don't skip" is easy to rationalize around; named rationalizations force the agent to confront the specific pattern it's about to follow.

**Design principles extracted:**

1. **Embed enforcement in the artifact, not just instruction files.** The artifact survives turn boundaries because it's the work product, not guidance about the work product.
2. **Route to script gates, don't replicate their logic textually.** Script gates (`exit 1`) create hard stops. Textual instructions create soft suggestions. Direct the agent to the script; don't ask it to perform the gate's logic itself.
3. **Fix the plumbing before adding more signs.** The ag.sh sequencing bug meant the gate was structurally broken. No amount of instruction text would fix a gate that checks for a file before that file exists.
4. **Name rationalizations, don't just forbid behavior.** "Don't use excuses A, B, C" is harder to bypass than "don't skip step X."
5. **Textual instructions have diminishing returns.** The 7th file saying "you MUST" has near-zero marginal effect. When the same instruction fails 3+ times, the fix is architectural (change routing), not editorial (add more text).
6. **Multi-layer defense is required for cross-turn workflows.** No single mechanism was sufficient. The fix required: (a) a working script gate, (b) artifact-embedded instructions, and (c) named rationalization rebuttals — all three together.

**Remaining gaps:**

1. **Explore-before-review.** Even with all fixes, the agent may still read implementation files before running the review (as observed in v0.59.0). The gate blocks implementation, and the review does happen, but the "don't explore before review" anti-pattern has no hard enforcement.

2. **ExitPlanMode hook may be inert.** If PostToolUse hooks don't fire for built-in tools (see 2026-03-26 finding below), then the `on-plan-mode-exit.sh` hook — designed as the primary push mechanism — has never injected instructions. All correct behavior came from textual instructions (CLAUDE.md, memory), which this very case study identifies as unreliable for cross-turn workflows. The `ag implement` gate (pull mechanism) and SessionStart orphan detection are the only working structural enforcement.

3. **No review-evidence check.** `ag implement` gate 0d checks `**Status**: APPROVED` but not whether a dialectical review actually ran. Approved plans contain review evidence (e.g., `## Dialectical Review Findings`, `## Revision N Changes (from dialectical review)`). The gate could verify presence of review sections to block agents from flipping DRAFT→APPROVED without running Critic/Advocate.

4. **Agent can bypass `ag implement` entirely.** The agent can write code without ever calling `ag implement`. The PreToolUse gate (F-0251, gate.py:697-712) blocks code edits when no feature is in "implementing" state, but: (a) it checks `state_enforcement` which may be "off", (b) it doesn't check plan approval at all, and (c) safe_patterns allow `.md`, `.json`, `.yaml`, `.sh`, `tests/`, `docs/` edits unconditionally. The PostToolUse `on-code-edit.sh` warns about DRAFT plans but is advisory (exit 0). Pre-commit Check 21 blocks commits with DRAFT plans but is too late (code already written). **The missing enforcement**: PreToolUse should block code edits unless an APPROVED plan exists (when `plan_review_enabled=yes` and `state_enforcement=blocking`). The check is "block unless APPROVED exists" — not "block if DRAFT exists" — because no plan at all is equally invalid. This would make plan approval a hard gate at the Write/Edit level, closing the `ag implement` bypass entirely.

### Push mechanisms need pull safety nets

The ExitPlanMode hook is a "push" mechanism — it tries to inject instructions at the moment of exit. If it fails (session ends, plan-scan bug, hook doesn't fire), there's no recovery. Push-only enforcement is fragile because it depends on a single moment succeeding. The fix is to pair every push mechanism with a "pull" safety net that runs at a well-known checkpoint (e.g., session start). The SessionStart hook now checks for orphan plans that the ExitPlanMode hook failed to save. Even if the push failed, the next session catches the gap. This pattern applies beyond plan review: any workflow that injects state at event time should have a periodic sweep that detects missed injections.

**Update (2026-03-26): The ExitPlanMode hook may have never fired.** JSONL analysis of session `f85780c3` showed zero `PostToolUse:ExitPlanMode` progress entries, while other PostToolUse hooks (Write, Grep, Read, Bash) fired normally. ExitPlanMode is a built-in Claude Code tool — PostToolUse hooks may only trigger for user-defined/external tools. If confirmed, the `on-plan-mode-exit.sh` hook has been inert since creation: all correct plan-save + review behavior came from CLAUDE.md + memory textual instructions alone. This makes the pull safety nets (SessionStart orphan detection, `ag implement` gate 0d) even more critical — they may be the ONLY working enforcement layer. See assumption A11 in INSTRUCTION_ARCHITECTURE.md.

**Existing review evidence in approved plans:** Approved plans do contain structural evidence of review — `**Status**: APPROVED`, `## Dialectical Review Findings`, `## Revision N Changes (from dialectical review)` sections. The `ag implement` gate currently checks only the Status line. It could additionally verify the presence of review evidence sections to prevent agents from flipping DRAFT→APPROVED without running the actual review.

### Instruction file edits alone cannot fix cross-turn behavioral failures

When a behavioral rule keeps failing despite being in multiple instruction files, adding it to yet another file is the wrong response. The instinct is editorial ("add more emphasis", "add an anti-pattern warning", "capitalize MUST") but the failure mode is architectural: the instruction isn't active when the agent makes the decision. Symptoms of this pattern:
- The rule exists in 5+ files but is still violated
- Each session you add more text and it still fails
- The agent acknowledges the rule and then ignores it

The fix is to change the enforcement mechanism, not the enforcement text. Move from textual rules to: (a) script gates that `exit 1`, (b) artifact-embedded instructions that survive turn boundaries, (c) named rationalization rebuttals that make self-deception harder. See the plan-review case study above for the full example.

### Init format determines everything downstream

Init is the highest-leverage moment in a project's lifecycle. If the project starts wrong — wrong FEATURES.md format, missing hook registrations, incorrect settings — every downstream workflow fails silently. The Algebra Rush test project created FEATURES.md in table format; `ag backlog add`, the state machine, and crunch all expect heading format (`## F-XXXX:`). The agent had to rewrite it manually. The Street Fury project never got `.claude/settings.json` with hook entries, so the entire tool-level enforcement layer was inert from minute one.

**Lesson**: Over-specify init. Provide exact format templates (not "create a FEATURES.md"). Validate init output immediately. One wrong format choice at minute 0 cascades into hours of silent failures. See F-0300 R4 for the FEATURES.md fix and R0 for hook registration.

### Test configuration combinations, not individual settings

Each configuration axis (profile, git_mode, workflow) may work individually but fail in combination. The Street Fury project combined `autonomous_formal + git_mode=deferred + batch work`. Each setting was individually valid. The combination produced: `ag auto` hard-gated on active git (couldn't use the correct workflow), hooks unregistered (no tool-level enforcement), deferred git (no pre-commit enforcement). Three individually reasonable settings created a configuration where zero enforcement layers were active.

**Lesson**: Test the *product* of your configuration matrix, not just each axis. Especially test edge combinations that deviate from the "default happy path" (active git, interactive, single feature). These edge combinations are where frameworks fail because they're the paths least exercised during development.

### Phase 3 instruction consolidation (v2)

Phase 3 removed ~130 files (~25K lines) of workflow docs, checklists, quality standards, subagent definitions, and full skill bundles. Their content was absorbed into 7 role prompts + `conventions.md` + CLI enforcement via `state_machine_af.yaml`. The instruction file checklist dropped from ~11 targets to ~5. When shipping framework features in v2, update: role prompts (`.agentic/prompts/`), conventions.md, state_machine_af.yaml (if new states/transitions), agent instruction files (CLAUDE.md etc.), and skill trigger stubs (`.claude/skills/`). The old checklist targets (checklists/, workflows/, quality/, subagents/, auto_orchestration.md, agent_operating_guidelines.md) no longer exist.

### Framework skills vs Task tool agents

Framework roles (review, test, implementation) → invoked via `/review`, `/test` (Skill tool). Built-in agent types (Bash, general-purpose, Explore, Plan) → invoked via Agent tool. Completely separate systems.

### Retroactive planning defeats forward-looking gates

When an agent implements first and plans after (often after being caught), all forward-looking gates become dead code. The POST-PLAN-MODE block says "Do NOT code" — but code already exists, so the agent skips it. `ag implement`'s plan gate is never reached because implementation already happened. Dialectical review feels optional because flaws are already in the code.

**Observed in F-0222**: Agent implemented without a plan → user caught it → agent planned retroactively → exited plan mode → skipped saving plan, skipped POST-PLAN-MODE block, skipped dialectical review. All three are forward-looking gates that assumed implementation hadn't happened yet.

**Fix direction**: Gates must check *actual state* (does an approved plan exist?) not *assumed ordering* (you're about to implement). `ag plan` should detect retroactive planning via feature state in FEATURES.md. `ag done` could verify an approved plan exists before shipping. State-based checks are order-independent; workflow-position checks are fragile.

**Full analysis**: `docs/KEY_INSIGHTS.md` §16 — "Retroactive Planning Defeats Forward-Looking Gates"

### Fail-open error handling is incompatible with blocking enforcement (NHL Hockey incident)

The NHL Hockey Game test project (v0.70.0, `autonomous_formal`, `state_enforcement: blocking`) exposed a critical architectural flaw: the entire enforcement stack was bypassed because the PreToolUse hook **failed-open** on gate errors. An agent built a complete 10-feature game (16 source files, 17 tests, working build) in under 6 minutes without calling a single `ag` command, creating zero artifacts, or transitioning a single feature.

**The enforcement chain that failed silently:**

```
Claude Code → hooks.json → PreToolUse.sh → python3 -m gate → GateResult
                                ↓                    ↓
                          exit 0 = allow       exit 0 = allow
                          exit 2 = deny  ←     exit 2 = deny
                                               exit 1 = ERROR
                                                  ↓
                                          PreToolUse.sh: || GATE_RC=$?
                                          only checks -eq 2
                                          exit 1 → falls through → exit 0
                                          → ALLOW (should be DENY)
```

**Three independent failure modes, all fail-open:**

1. **Python crash** (import error, syntax error, missing dependency): exit 1 → treated as allow
2. **Timeout** (2000ms hook timeout, cold Python startup): process killed → no output → no deny JSON → allow
3. **Regex miss** (UserPromptSubmit batch-work detection): "work autonomously" ≠ "build everything" → no warning

**The cascade**: Once the first Write call succeeded without being blocked, the agent interpreted silence as permission. Sunk-cost psychology accelerated: 16 more files followed with zero friction in 5 minutes 41 seconds. All downstream gates (ag implement Gate 0, pre-commit checks, ag verify) are positioned AFTER workflow entry — an agent that bypasses the entry point bypasses everything.

**Fixes applied (#190 + #191):**
- PreToolUse.sh now **fails-closed** when `state_enforcement: blocking` — any non-zero gate exit → deny (with diagnostic message). Uses fast `grep` on STACK.md instead of Python to avoid the same failure mode.
- Batch-work regex expanded with 8 semantic patterns ("work autonomously", "come back with working", "finish everything", "do it all", etc.).
- on-code-edit.sh now warns when zero features are in implementing state (not just DRAFT plan detection).
- Anti-rationalization callouts added to CLAUDE.md, template CLAUDE.md, and memory-seed.
- PreToolUse timeout increased from 2000ms → 3000ms for cold Python startup.

**Architectural lesson**: In enforcement chains, **every link must fail-closed when the enforcement level is "blocking."** A single `|| exit 0` or unhandled exit code converts a blocking gate into a permission. Fail-open is the right default for `state_enforcement: off` (don't break non-formal projects), but it's **incompatible** with `state_enforcement: blocking`. The fix was 5 lines in PreToolUse.sh — trivial code, catastrophic impact when missing.

**Design principles extracted:**

1. **Enforcement chains must fail-closed under blocking mode.** Every link — gate logic, shell wrapper, timeout handling, exit code interpretation — must deny when in doubt.
2. **Silence is permission to an LLM agent.** No output, no error, no warning = proceed. If you intend to block, produce visible output.
3. **Test the error path, not just the happy path.** The gate worked when invoked directly. Nobody tested what happens when `python3 -m gate` fails to start at all.
4. **Defense-in-depth must be truly independent.** Three layers (PreToolUse, UserPromptSubmit, PostToolUse) all depended on Python. One Python failure disabled all three. Use different mechanisms per layer.
5. **Regex-based semantic detection has a ceiling.** "Build everything" is lexical; "work autonomously" is semantic. Regex is a first filter; structural state checks are the backstop.

**Evidence package**: `agentic-tests/nhl-hockey-game/to_agentic_af/` — full JSONL session log, tool timeline, hook evidence, framework.log, reference files, project state snapshot.

### Agents misattribute actions to the user when context comes from other sources

Agents can't distinguish user-typed content from context inherited from prior agents. In the F-0222 session, a plan was created in plan mode and accepted by the user, but the agent skipped saving it durably and skipped dialectical review. When a new session started, the new agent saw the plan in context and fabricated a false narrative: "the user explicitly pasted the plan." The user had been AFK the entire time. Don't invent provenance stories — say what you observe without asserting who put it there.

**Full analysis**: `docs/KEY_INSIGHTS.md` §15 — "Agents Cannot Distinguish Context Provenance"

---

## Quick Reference: "I'm changing..."

**"...a template"**:
→ Test scaffold, update examples, test upgrade, check validation

**"...agent guidelines"**:
→ Test with example project, verify agent follows new rules, update principles if needed

**"...a workflow doc"**:
→ Walk through workflow manually, update examples, verify agent can follow it

**"...documentation"**:
→ Verify accuracy, check for duplication, test all examples/commands

**"...a tool script"**:
→ Test in scratch project, update DEVELOPER_GUIDE, verify error handling

**"...core principles"**:
→ Strong justification, user approval, update all references

**"...version number"**:
→ Full release checklist (see above)

---

## Enforcement Architecture

When adding new gates, enforcement, or behavioral nudges to the framework, use this hierarchy (prefer higher layers):

| Layer | When it runs | Examples | Use for |
|-------|-------------|----------|---------|
| **Agent hooks** | Real-time, during session | Claude: PreToolUse.sh, PostToolUse.sh, Stop.sh, UserPromptSubmit.sh; Cursor: hooks.json | Primary enforcement. Pattern warnings, catalog tracking, session summaries, mid-session nudges. |
| **Skills** | On workflow trigger | `.claude/skills/implementing-features/` | Just-in-time guidance. Step-by-step workflow instructions loaded when agent recognizes trigger words. |
| **`ag` commands** | When agent calls them | `ag done`, `ag implement`, `ag commit` | Workflow gates. Validate preconditions before proceeding. |
| **Pre-commit hooks** | At git commit time | `pre-commit-check.sh` | Safety net for tools without hook support (manual git, CI). Defense-in-depth. |
| **Instruction files** | Always loaded | CLAUDE.md, cursorrules, memory-seed | Behavioral guidance. No structural enforcement — agent can choose to ignore. |

**Key principle**: Agent hooks are the primary enforcement layer because they run automatically — the agent doesn't choose to run them. Skills and instruction files are behavioral — they guide the agent but can be ignored. Pre-commit hooks fire too late (at commit time, when the agent has moved on).

**When to use agent hooks** (not pre-commit):
- Tracking what was written/read (PostToolUse → token-events.log, intel-events.log, .cap_updated)
- Nudging the agent mid-session (UserPromptSubmit → catalog reminder, stale artifact reminder)
- Session-end validation (Stop.sh → token summary, intel summary, catalog check)
- Blocking dangerous actions (PreToolUse → pattern warnings, destructive git op prevention)

**When pre-commit is still appropriate**:
- Checks that apply to ALL tools (not just those with hook support) — e.g., journal freshness, batch size limits
- Checks that need to see the full staged changeset (git diff --cached)
- Defense-in-depth for rules already enforced by agent hooks

---

## Discovery → Formal Transition (Profile Graduation)

Profiles (discovery, formal, autonomous_formal) are **presets for settings**, not separate products. A project can run in discovery settings indefinitely and still get real value from the framework — intelligence engine, quality patterns, journal, OVERVIEW.md design doc, Claude hook enforcement.

**The key design principle**: discovery settings still log enough information to make a transition to formal specs as fluent as possible. Every artifact discovery produces is raw material for formal specs:

| Discovery artifact | Formal equivalent | How it helps |
|---|---|---|
| OVERVIEW.md Core Capabilities (checkboxes) | FEATURES.md with F-XXXX entries | Each checked capability → a feature entry. Agent uses these as starting points. |
| OVERVIEW.md "Who Uses This" (personas) | `personas.yaml` with structured persona data | Persona goals/capabilities → queryable fields, scoped assertions, coverage analysis via `ag persona`. |
| OVERVIEW.md Guiding Principles | NFR.md non-functional requirements | Each principle → an NFR with measurable criteria. |
| JOURNAL.md entries (with `--why` and `--decision`) | ADRs in `spec/adr/` | Key decisions from journal → formal Architecture Decision Records. `--decision` entries are grep-able (`grep "Decision:" JOURNAL.md`). |
| Cerebrum entries (`ag intel remember`) | Enforced patterns in `patterns.yaml` | Preferences/learnings → `ag intel learn` patterns with scope globs. |
| Code + tests (as they exist) | YAML contracts with acceptance criteria | Code behavior → extracted ACs. Tests → verification commands in contracts. `ag specs` analyzes codebase to suggest ACs. |
| ISSUES.md + LESSONS.md | Patterns + quality checklist items | `ag intel retro` already does this — converts lessons to enforceable patterns. |

**When a user decides to graduate**: They change `feature_tracking: yes` and `spec_directory: yes` in STACK.md (or switch to `profile: formal`). The agent then helps create FEATURES.md entries and draft contracts by reading OVERVIEW.md capabilities, journal decisions, project memory entries, and the existing codebase. This is agent-assisted, not automated — the user reviews and refines the specs. The discovery artifacts give the agent rich context to work from rather than starting from scratch.

**What this means for framework development**:
1. **Discovery artifacts must be understandable months later** — OVERVIEW.md checkboxes, structured journal entries with `--why`, typed project memory entries. If someone comes back in 6 months, they should be able to understand what was built and why from these artifacts alone.
2. **Don't gate discovery features behind formal settings** — if a feature helps track what was built or why, it should work when `feature_tracking=no`. The data it produces is valuable on its own AND makes graduation easier.
3. **Structure enables transition** — machine-readable formats (checkboxes, YAML project memory entries, journal with fields) give an agent rich context when the user asks to create formal specs. No script auto-generates specs — the agent helps the user write them, using discovery artifacts as context. This is a side benefit of good structure, not the primary goal.
4. **Journal `--why` and `--decision` are critical** — the motivation behind decisions is what gives artifacts lasting value. A checkbox says "we built search." A journal entry with `--why` and `--decision` says "we built search because users couldn't find products by category, and we chose Elasticsearch over Postgres FTS because we expect 10M+ products." Use `--decision` to mark the entry as a decision (grep-able). Include reasoning, alternatives considered, and assumptions in the outcome text. That context is useful whether or not you ever go formal.
5. **Decision routing** — current state goes in OVERVIEW.md sections. Decision history goes in JOURNAL.md with `--decision`. Full tradeoff analysis goes in ADRs (formal only). Ways of working go in STACK.md + CONTEXT_PACK.md. User preferences go in project-memory.yaml via `ag intel remember`.

---

## Getting Help

**Unsure about a change?**
1. Read `PRINCIPLES.md` - does change align with core philosophy?
2. Check example projects - would this improve or complicate them?
3. Ask user for guidance - provide options with pros/cons

**Found a problem?**
1. Document it clearly (what's wrong, why it's wrong)
2. Propose solution aligned with principles
3. Test solution in scratch project
4. Implement with examples and docs

**Making significant change?**
1. Explain what and why to user
2. Show before/after impact
3. Get approval before implementing
4. Test thoroughly
5. Update all affected areas

---

## Summary: Framework Development vs. Project Development

| Aspect | Project Development | Framework Development |
|--------|-------------------|---------------------|
| Scope | Single project | Framework + examples |
| Testing | Project tests | Scratch projects, examples |
| Docs | Project docs | User docs + framework dev docs |
| Changes | Affect one project | Affect all future projects |
| Quality | Follow standards | SET the standards |
| Releases | Project milestones | Semantic versions, CHANGELOG |
| Backward compat | Not critical | Very important |
| Examples | Optional | Mandatory |

**The Golden Rule**: Framework changes affect everyone using it. Test thoroughly, document accurately, maintain consistency, respect principles.

---

**Last Updated**: 2026-03-19
**Framework Version**: 0.64.0

**Note**: These guidelines evolve with the framework. When they change, notify framework contributors and update this document.

