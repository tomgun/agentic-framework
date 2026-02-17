# Settings System

The framework uses individual settings instead of all-or-nothing profiles. Profiles (`discovery`, `formal`) are presets that set bundles of defaults. You can override any setting independently.

## Quick Reference

```bash
ag set --show              # View all settings with sources
ag set --validate          # Check constraint rules
ag set feature_tracking yes  # Override a single setting
ag set profile formal      # Switch profile preset
```

## How Settings Are Resolved

Three-level resolution, highest priority wins:

1. **Explicit** — `## Settings` section in STACK.md (you set it directly)
2. **Profile preset** — from `.agentic/presets/profiles.conf` (set by your profile)
3. **Fallback default** — hardcoded in the calling script

Example: if your profile is `discovery` (which defaults `feature_tracking=no`) but you explicitly set `- feature_tracking: yes` in STACK.md, you get `yes`.

## When Settings Take Effect

This is important to understand:

### Script-enforced settings (immediate)

These are read **fresh on every invocation** by shell/python scripts:

| Setting | Enforced by | When |
|---------|-------------|------|
| `wip_before_commit` | `pre-commit-check.sh` | Every commit |
| `pre_commit_checks` | `pre-commit-check.sh` | Every commit |
| `max_files_per_commit` | `pre-commit-check.sh` | Every commit |
| `max_added_lines` | `pre-commit-check.sh` | Every commit |
| `max_code_file_length` | `pre-commit-check.sh` | Every commit |
| `git_workflow` | `pre-commit-check.sh` | Every commit |
| `feature_tracking` | `ag` commands, `session-start.sh` | Every ag command / session start |
| `spec_directory` | `ag` commands | Every ag command |

**Changing these takes effect immediately** — the next `ag commit` or `ag plan` will use the new value.

### Agent-interpreted settings (session start only)

These are read by the AI agent when it reads STACK.md at session startup:

| Setting | How agent learns it | When |
|---------|-------------------|------|
| `acceptance_criteria` | Reads STACK.md `## Settings` section | Session start |
| `plan_review_enabled` | Reads STACK.md `## Settings` section | Session start |
| `agent_mode` | Reads STACK.md | Session start |
| `development_mode` | Reads STACK.md | Session start |

**Changing these mid-session requires telling the agent.** The agent reads STACK.md once at session start and relies on that for the entire session. If you run `ag set acceptance_criteria off` mid-session, the agent won't know unless you tell it: "I changed acceptance_criteria to off, please adjust."

### How to force a mid-session reload

If you change a setting and need the agent to pick it up:
- Tell the agent directly: "I changed X to Y"
- Or ask it to re-read: "Please re-read STACK.md ## Settings"
- Or run `ag set --show` and share the output

## Settings Inventory

### Workflow settings

| Setting | Values | Description |
|---------|--------|-------------|
| `profile` | `discovery` / `formal` | Profile preset (sets defaults for all other settings) |
| `feature_tracking` | `yes` / `no` | Require F-#### IDs and feature specs |
| `acceptance_criteria` | `blocking` / `recommended` / `off` | Spec enforcement level (agent-interpreted) |
| `wip_before_commit` | `blocking` / `warning` | WIP gate: block commit or just warn |
| `pre_commit_checks` | `full` / `fast` / `off` | Pre-commit gate level |
| `git_workflow` | `pull_request` / `direct` | Branch policy: feature branches or commit to main |
| `plan_review_enabled` | `yes` / `no` | Iterative plan-review loop before implementation |
| `spec_directory` | `yes` / `no` | Require spec/ directory with formal specs |

### Complexity limits

| Setting | Type | Description |
|---------|------|-------------|
| `max_files_per_commit` | integer | Max files per commit (Check 7 blocks, Check 5 warns at 70%) |
| `max_added_lines` | integer | Max added lines per commit |
| `max_code_file_length` | integer | Max lines per code file |

### Profile defaults

| Setting | Discovery | Formal |
|---------|-----------|--------|
| `feature_tracking` | no | **yes** |
| `acceptance_criteria` | recommended | **blocking** |
| `wip_before_commit` | warning | **blocking** |
| `pre_commit_checks` | fast | **full** |
| `git_workflow` | direct | **pull_request** |
| `plan_review_enabled` | no | **yes** |
| `spec_directory` | no | **yes** |
| `max_files_per_commit` | 15 | 10 |
| `max_added_lines` | 1000 | 500 |
| `max_code_file_length` | 1000 | 500 |

## Constraints

Some setting combinations are invalid. Constraints are defined in `.agentic/presets/constraints.conf` and checked by `ag set --validate`:

```
acceptance_criteria=blocking → feature_tracking=yes
acceptance_criteria=blocking → spec_directory=yes
plan_review_enabled=yes → feature_tracking=yes
pre_commit_checks=full → pre_commit_hook=fast|full
feature_tracking=yes → spec_directory=yes
```

## STACK.md Format

Settings live in the `## Settings` section of STACK.md:

```markdown
## Settings
<!-- Profile sets defaults. Override individual settings below. -->
- profile: formal
- feature_tracking: yes
- acceptance_criteria: recommended    # override: suggest, don't block
- max_files_per_commit: 20            # temporarily raised for refactor
```

Only settings you want to override need to be listed — unset settings use profile defaults.

## Backward Compatibility

Projects without a `## Settings` section still work. The settings library falls back to searching the entire STACK.md for `- key: value` patterns. Run `ag set --migrate` to add the `## Settings` section to an existing project.

---

## Known Limitations & Future Work

> Development notes — not user-facing guidance.

### Agent-interpreted settings lack programmatic enforcement
Settings like `acceptance_criteria` rely on the agent reading and respecting the value. There's no script that blocks a commit if acceptance criteria are missing. This is by design for flexibility, but means agent compliance varies.

**Possible improvements:**
- Add optional enforcement to `pre-commit-check.sh` for `acceptance_criteria=blocking` (check that staged features have acceptance files)
- Add `ag implement` gate that checks acceptance file exists when `acceptance_criteria=blocking`

### Settings are read once at session start
Agents read STACK.md at session start and don't re-read mid-session. This means `ag set` changes to agent-interpreted settings are invisible until the next session or explicit re-read.

**Possible improvements:**
- `ag set` could output a message like: "Note: this is an agent-interpreted setting. Tell your agent: 'I changed X to Y'"
- Session-start hook could output resolved settings as structured data (not just prose in STACK.md)
- `ag set --show` output could be injected into agent context automatically

### No per-command setting overrides
Currently you can only change settings permanently in STACK.md. There's no `ag commit --max-files=25` for one-off overrides.

**Possible improvements:**
- Environment variable overrides: `MAX_FILES_PER_COMMIT=25 ag commit`
- Command-line flags: `ag commit --override max_files_per_commit=25`

### Settings list is hardcoded in show_all_settings
The `show_all_settings()` function in `settings.sh` has a hardcoded list of known settings. New settings must be added manually.

**Possible improvement:**
- Read setting names from `profiles.conf` automatically
- Or maintain a `settings.registry` file listing all valid settings with types and descriptions
