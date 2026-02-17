# Plan: Settings-Over-Profiles Architecture

## Context

The framework currently uses two profile names (`discovery`, `formal`) as the primary branching mechanism for all behavioral logic. Scripts check `if profile == "formal"` rather than checking individual settings. This has two problems:

1. **All-or-nothing**: Users can't customize one behavior (e.g., "I want feature tracking but not blocking WIP") without switching their entire profile.
2. **Brittle logic**: Adding a third profile or tweaking one behavior requires touching every profile check across ~18 files.

**Goal**: Make profiles into presets that set a bundle of settings, while all framework logic checks individual settings. Users can override individual settings without changing profile.

## Design

### Settings stay in STACK.md

Consolidate under a `## Settings` section using existing `- key: value` format. Section-scoped parsing: `get_setting()` reads only from `## Settings` section, not the entire file. This avoids false matches from keys in other sections (e.g., `profile:` appearing under `## Quality validation`).

### Profile presets defined in `.agentic/presets/profiles.conf`

Flat `profile.setting=value` format (`# format: profiles-v1.0`), trivially parseable with `grep` in bash. This is a **framework-level file** — users don't edit it, they override via STACK.md.

### Resolution chain: Explicit > Profile Default > Global Default

```
get_setting("feature_tracking")
  1. Check ## Settings section of STACK.md for explicit `- feature_tracking: yes`
  2. If not found, look up `formal.feature_tracking=yes` in profiles.conf
  3. If not found, return fallback default
```

### Deduplication: single `get_setting()` source

Currently 5 duplicate `read_profile()`/`get_profile()` implementations exist across the codebase:
- `ag.sh:get_profile()`, `sync.sh:get_profile()` (bash copies)
- `phase_detect.py:read_profile()`, `doctor.py:read_profile()`, `verify.py:read_profile()` (python copies)

All will be replaced by importing from the new shared libraries:
- Bash: `source .agentic/lib/settings.sh` (provides `get_setting`)
- Python: `from agentic_lib.settings import get_setting` (or `sys.path` import from `.agentic/lib/settings.py`)

### Simple constraint rules in `.agentic/presets/constraints.conf`

Format: `if A=X -> B=Y|Z`. Warns on `ag start`, blocks on `ag commit` when `pre_commit_checks=full`.

### Upgrade path for existing projects

When `get_setting()` finds no `## Settings` section in STACK.md, it falls back to whole-file search for backward compat (matching current behavior). The `ag set` command creates the `## Settings` section on first use if it doesn't exist. Additionally, `upgrade.sh` will add the section during framework upgrades.

## Settings Inventory

New settings extracted from profile behavioral differences:

| Setting | Type | Discovery Default | Formal Default |
|---------|------|-------------------|----------------|
| `feature_tracking` | yes/no | no | yes |
| `acceptance_criteria` | blocking/recommended/off | recommended | blocking |
| `wip_before_commit` | blocking/warning | warning | blocking |
| `pre_commit_checks` | full/fast/off | fast | full |
| `git_workflow` | pull_request/direct | direct | pull_request |
| `plan_review_enabled` | yes/no | no | yes |
| `spec_directory` | yes/no | no | yes |

### Complexity settings (move into Settings section)

These already exist in STACK.md but scattered outside any section. Move into `## Settings` and make profile-aware:

| Setting | Type | Discovery Default | Formal Default | Description |
|---------|------|-------------------|----------------|-------------|
| `max_files_per_commit` | integer | 15 | 10 | Blocking limit in pre-commit Check 7 |
| `max_added_lines` | integer | 1000 | 500 | Blocking limit for added lines |
| `max_code_file_length` | integer | 1000 | 500 | Blocking limit for single file length |

**Key fix**: pre-commit-check.sh Check 5 (batch size warning) currently has hardcoded thresholds of 10 and 15. These will be derived from `max_files_per_commit`: warn at `floor(max * 0.7)`, strong warn at `max`. Check 7 (blocking) already reads from STACK.md — just ensure it uses `get_setting` instead of raw grep.

**Design rationale**: Discovery defaults are more relaxed (15 files) because exploratory work often touches more files. Formal defaults are stricter (10 files) to enforce review discipline. Users can override either way: a formal project doing a big refactor can temporarily `ag set max_files_per_commit 25`.

Existing settings that already work independently (no change needed): `development_mode`, `agent_mode`, `plan_review_max_iterations`, `pipeline_enabled`, `pre_commit_hook`.

## Constraint Rules (~5-10)

```
acceptance_criteria=blocking -> feature_tracking=yes
acceptance_criteria=blocking -> spec_directory=yes
plan_review_enabled=yes -> feature_tracking=yes
pre_commit_checks=full -> pre_commit_hook=fast|full
feature_tracking=yes -> spec_directory=yes
```

## Complete File Audit (18 files with profile logic)

Verified by codebase grep. All must be converted.

**Bash scripts with `get_profile()` copies or profile checks:**
1. `.agentic/tools/ag.sh` — `get_profile()` + 9 `$PROFILE` checks
2. `.agentic/tools/sync.sh` — duplicate `get_profile()` + 1 profile branch
3. `.agentic/hooks/pre-commit-check.sh` — file-existence proxy for profile
4. `.agentic/hooks/session-start.sh` — 2 `$PROFILE` checks
5. `.agentic/tools/upgrade.sh` — profile detection for STATUS.md migration
6. `.agentic/tools/discover.sh` — `--profile` flag passthrough
7. `.agentic/tools/enable-formal.sh` — profile upgrade script

**Python scripts with `read_profile()` copies or profile checks:**
8. `.agentic/tools/phase_detect.py` — `read_profile()` + phase logic
9. `.agentic/tools/doctor.py` — duplicate `read_profile()` + 6 profile branches
10. `.agentic/tools/verify.py` — duplicate `read_profile()` + profile checks
11. `.agentic/tools/render_proposals.py` — `--profile` CLI arg
12. `.agentic/tools/continue_here.py` — profile string check
13. `.agentic/tools/discover.py` — `profile == "formal"` conditionals

**Documentation (profile references in prose):**
14. `.agentic/agents/shared/agent_operating_guidelines.md` — gates table
15. `.agentic/agents/shared/auto_orchestration.md` — workflow references
16. `.agentic/CLAUDE.md` template — trigger table

**Templates/init:**
17. `.agentic/init/STACK.template.md` — profile default
18. `.agentic/init/scaffold.sh` — `--profile` flag, file creation branching

**Test infrastructure (keep profile for fixture setup, migrate reading logic):**
- `tests/llm/harness.sh`, `tests/llm/interactive_runner.py`, `tests/llm/helpers.sh`

## Implementation Phases

### Phase 1: Infrastructure (non-breaking, ~5 new files, ~2 modified)

Create the settings resolution layer alongside the existing profile system. Both work simultaneously.

**New files:**
- `.agentic/presets/profiles.conf` — profile preset definitions (`# format: profiles-v1.0`)
- `.agentic/presets/constraints.conf` — constraint rules
- `.agentic/lib/settings.sh` — bash `get_setting()` + `validate_constraints()` + section-aware STACK.md parsing
- `.agentic/lib/settings.py` — python `get_setting()`

**Modify:**
- `.agentic/tools/ag.sh` — `source` settings.sh (with defensive guard), add `ag set` command, add `ag set --migrate` for existing projects
- `.agentic/init/STACK.template.md` — add `## Settings` section with all settings documented

**Key design detail for `get_setting()` parsing:**
- Extract text between `## Settings` and the next H2 heading (`^## [^#]` — this allows `###` subsections like `### Workflow` within the Settings section)
- Within that section, match `- key: value` (strip `<!-- -->` comments, `# comments`, whitespace)
- Case-sensitive keys
- If no `## Settings` section exists, fall back to whole-file search (backward compat)

### Phase 2a: Core gateway conversion (~5 files)

Convert the primary entry point and its direct dependencies.

- `.agentic/tools/ag.sh` — replace all 9 `$PROFILE` checks with `get_setting` calls; remove duplicate `get_profile()`, use `get_setting profile discovery` instead
  - `show_help()` → `get_setting feature_tracking`
  - `cmd_work()` → `get_setting feature_tracking`
  - `cmd_plan()` → `get_setting feature_tracking`
  - `cmd_implement()` → `get_setting feature_tracking` + `get_setting acceptance_criteria`
  - `cmd_commit()` → `get_setting wip_before_commit` + `get_setting pre_commit_checks`
  - `cmd_done()` → `get_setting feature_tracking`
  - `cmd_specs()` → `get_setting feature_tracking` + `get_setting spec_directory`
  - `cmd_start()` → `get_setting feature_tracking`
- `.agentic/tools/sync.sh` — remove duplicate `get_profile()`, source `settings.sh`
- `.agentic/hooks/pre-commit-check.sh` — source `settings.sh`, replace file-existence proxy, derive Check 5 warning thresholds from `get_setting max_files_per_commit`, replace Check 7's raw grep with `get_setting`
- `.agentic/hooks/session-start.sh` — source `settings.sh`, replace profile checks
- `.agentic/tools/enable-formal.sh` — rewrite to call `ag set profile formal` + create `spec/` directory + copy templates (keep the directory/template creation logic, only change the config part)

### Phase 2b: Python tools conversion (~5 files)

- `.agentic/tools/phase_detect.py` — import `settings.py`, delete `read_profile()`, use `get_setting(root, "feature_tracking")`. Rename phase `"discovery-mode"` → `"no-feature-tracking"`.
- `.agentic/tools/doctor.py` — import `settings.py`, delete duplicate `read_profile()`, replace 6 profile branches with `get_setting` calls
- `.agentic/tools/verify.py` — import `settings.py`, delete duplicate `read_profile()`, replace profile checks
- `.agentic/tools/render_proposals.py` — replace `--profile` arg with `get_setting` checks
- `.agentic/tools/continue_here.py` — replace profile string check with `get_setting`
- `.agentic/tools/discover.py` — replace `profile == "formal"` with `get_setting`

### Phase 2c: Remaining bash + scaffolding (~3 files)

- `.agentic/tools/upgrade.sh` — use `settings.sh`, add `## Settings` section migration to upgrade flow
- `.agentic/tools/discover.sh` — replace `--profile` flag with settings-aware logic
- `.agentic/init/scaffold.sh` — still takes `--profile` flag but writes the `## Settings` section to STACK.md with preset values

### Phase 3: Documentation + tests (~5 files)

- `.agentic/agents/shared/agent_operating_guidelines.md` — gates table: profile columns → setting-based descriptions
- `.agentic/agents/shared/auto_orchestration.md` — replace profile references with setting references
- `.agentic/CLAUDE.md` template — update trigger table and profile mentions
- `tests/validate_framework.sh` — add tests for:
  - Settings resolution (explicit > preset > default)
  - Section-scoped parsing (doesn't match keys outside `## Settings`)
  - Constraint violations detected
  - Backward compat: STACK.md without `## Settings` section still works
  - `ag set --show` output
- Test infrastructure: keep profile strings in test fixtures, just ensure they use `settings.sh`/`settings.py` for reading

## `ag set` Command

```bash
ag set --show              # Show all resolved settings with source (explicit/preset/default)
ag set feature_tracking yes  # Override a single setting in STACK.md ## Settings section
ag set profile formal      # Switch preset (updates profile line)
ag set --validate          # Run constraint validation
ag set --migrate           # Add ## Settings section to existing STACK.md (upgrade path)
```

## STACK.md After Migration (Example)

```markdown
## Settings
<!-- Profile sets defaults. Override individual settings below. -->
- profile: formal

### Workflow
- feature_tracking: yes
- acceptance_criteria: blocking
- wip_before_commit: blocking
- pre_commit_checks: full
- git_workflow: pull_request
- plan_review_enabled: yes
- spec_directory: yes

### Quality
- development_mode: standard
- agent_mode: balanced
- pre_commit_hook: fast

### Complexity limits
- max_files_per_commit: 10
- max_added_lines: 500
- max_code_file_length: 500
```

Users can override any single setting:
```markdown
- profile: formal
- acceptance_criteria: recommended    # override: suggest, don't block
```

## Verification

1. `bash tests/validate_framework.sh` — framework tests pass
2. `ag set --show` — correct resolution (explicit > preset > default)
3. `ag set --validate` — constraint violations detected when rules broken
4. Test: `ag commit` in a formal project with overridden settings respects overrides
5. Test: switching profile via `ag set profile discovery` changes all unoverridden settings
6. Test: scaffold.sh still creates correct file sets per profile
7. Existing LLM behavioral tests still pass (they test agent behavior, which should be unchanged)

## Scope

- ~5 new files, ~18 modified files
- Phase 1 can ship independently (non-breaking, additive)
- Phase 2 split into 3 sub-batches (2a: core gateway ~5 files, 2b: python ~6 files, 2c: remaining ~3 files)
- Phase 3: docs + tests ~5 files
- Total: 5 committable batches, each ≤10 files
