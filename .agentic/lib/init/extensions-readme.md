# Project Extensions

This directory contains project-specific extensions to the Agentic Framework.
Files here survive framework upgrades — `.agentic/` gets replaced, but `.agentic/local/` does not.

## Extension Points

### Custom Skills (`.agentic/local/extensions/skills/`)

Add custom Claude Code skills in the same format as framework skills:

```
skills/
  my-custom-skill/
    SKILL.md       # Skill definition (same frontmatter format as framework skills)
    scripts/       # Optional scripts
    references/    # Optional reference docs
```

Skills placed here are picked up by `generate-skills.sh` and copied to `.claude/skills/`
alongside framework skills.

### Custom Quality Gates (`.agentic/local/extensions/gates/`)

Add bash scripts that run during pre-commit (Check 17). Each script must:
- Exit 0 to pass (allow commit)
- Exit 1 to fail (block commit)

Example: `gates/check-api-keys.sh`
```bash
#!/usr/bin/env bash
# Block commits containing API keys
if git diff --cached | grep -qE 'AKIA[0-9A-Z]{16}'; then
  echo "❌ AWS access key found in staged changes"
  exit 1
fi
```

### Custom Rules (`.agentic/local/extensions/rules/`)

Rule files injected into skill instructions (replaces `subagents-project/` pattern).
Use `## Project-Specific Rules` heading — content is appended to matching skill.

### Custom Lifecycle Hooks (`.agentic/local/extensions/hooks/`)

Bash scripts executed at specific `ag` command lifecycle points. Hooks are non-blocking —
if a hook fails, a warning is printed but the command continues.

| Hook file | Runs | Arguments |
|-----------|------|-----------|
| `before-plan.sh` | Before `ag plan` emits instructions | `$1` = feature_id |
| `after-implement.sh` | After `ag implement` completes | `$1` = feature_id |
| `after-commit.sh` | After `ag commit` succeeds | (none) |
| `after-done.sh` | After `ag done` completes | `$1` = feature_id |

Hooks have a 10-second timeout. Example: `hooks/after-implement.sh`
```bash
#!/usr/bin/env bash
# Notify team on Slack when implementation starts
curl -s -X POST "$SLACK_WEBHOOK" -d "{\"text\": \"Implementation started: $1\"}" >/dev/null
```

### Custom Done-Checks (`.agentic/local/extensions/done-checks/`)

Bash scripts that run during feature completion validation (`ag done` / `feature-complete.sh`).
Unlike lifecycle hooks, done-checks are **blocking** — a failed check increments the failure count
and can prevent shipping.

Each script must:
- Accept `$1` = feature_id
- Exit 0 to pass
- Exit non-zero to fail

Naming convention: `NNN-description.sh` (number prefix controls execution order).
Scripts have a 3-second timeout.

Example: `done-checks/010-changelog-updated.sh`
```bash
#!/usr/bin/env bash
# Ensure changelog has an entry for this feature
if ! grep -q "$1" CHANGELOG.md 2>/dev/null; then
  echo "❌ No CHANGELOG.md entry found for $1"
  exit 1
fi
```

### Custom Enforcement Policies (`.agentic/local/extensions/policies/`)

Declarative YAML files evaluated during pre-commit (Check 18). For simple rules that
don't need a full bash script — use `gates/` for complex logic instead.

Each YAML file defines:
```yaml
name: Require tests for core changes
check: "! git diff --cached --name-only | grep '^src/core/' || git diff --cached --name-only | grep '^tests/'"
severity: blocking    # blocking = fails commit, warning = prints warning
message: "Changes to src/core/ must include corresponding test files"
```

Fields:
- `name` — display name (falls back to filename)
- `check` — bash command to evaluate (exit 0 = pass, non-zero = fail)
- `severity` — `blocking` (increments failure count) or `warning` (advisory only)
- `message` — human-readable explanation shown on failure

Policies have a 3-second timeout. Malformed YAML is skipped with a warning.

## Project-Level Customization Files

Beyond the `extensions/` directory, these files in `.agentic/local/` customize framework behavior:

### Conventions (`.agentic/local/conventions.md`)

Project-specific coding conventions that supplement `.agentic/conventions.md`.
Rules here take precedence when they conflict with framework defaults.
Referenced by agents during implementation via `conventions.md` pointer.

### Workflow Directions (`.agentic/local/workflow-directions.md`)

Custom instructions injected at workflow phases (Planning, Implementation, Verification, Review).
Printed by `ag implement` and referenced in role prompts. Use markdown sections (`## Planning`, etc.).

## Upgrade Behavior

During `upgrade.sh`, local customization files are automatically synced:

- **Unmodified templates** are replaced with the updated version from the new framework
- **Customized files** are preserved — a `.new` file is written alongside for manual review
- **New extension subdirectories** are created automatically if added in newer framework versions

This applies to template-derived files: `conventions.md`, `workflow-directions.md`, and `extensions/README.md`.
User-authored scripts in `extensions/` subdirectories are never touched.

## Format

All extensions use existing framework formats — no new concepts to learn.
See `.agentic/lib/agents/claude/skills/` for skill format examples.
