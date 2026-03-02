# Project Extensions

This directory contains project-specific extensions to the Agentic Framework.
Files here survive framework upgrades — `.agentic/` gets replaced, but `.agentic-local/` does not.

## Extension Points

### Custom Skills (`.agentic-local/extensions/skills/`)

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

### Custom Quality Gates (`.agentic-local/extensions/gates/`)

Add bash scripts that run during pre-commit. Each script must:
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

### Custom Rules (`.agentic-local/extensions/rules/`)

Rule files injected into skill instructions (replaces `subagents-project/` pattern).
Use `## Project-Specific Rules` heading — content is appended to matching skill.

### Custom Hooks (`.agentic-local/extensions/hooks/`)

Lifecycle hooks (future): `after-implement.sh`, `after-commit.sh`, etc.

## Format

All extensions use existing framework formats — no new concepts to learn.
See `.agentic/agents/claude/skills/` for skill format examples.
