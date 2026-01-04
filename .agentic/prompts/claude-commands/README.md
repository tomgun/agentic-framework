# Claude Custom Commands (Optional)

**For Claude Desktop users only** - Set up slash commands for common workflows.

**Requirements**: Claude Desktop with custom commands enabled (check Claude settings)

---

## What Are Custom Commands?

Custom commands let you type `/command` in Claude to quickly invoke predefined workflows. They're like shortcuts for our ready-to-use prompts.

**Example**: Type `/continue` to resume work from `.continue-here.md`

---

## Setup

### Method 1: Claude Desktop Settings (if supported)

1. Open Claude Desktop settings
2. Go to "Custom Commands" or "Slash Commands"
3. Add commands from this directory
4. Save and restart Claude

### Method 2: Manual (copy-paste prompts)

If your Claude version doesn't support custom commands:
- Just use the regular prompts from `.agentic/prompts/claude/`
- Copy and paste them when needed
- Same functionality, just manual

---

## Available Commands

| Command | Description | Prompt File |
|---------|-------------|-------------|
| `/start` | Start session with context loading | `start.md` |
| `/continue` | Resume from .continue-here.md | `continue.md` |
| `/implement` | Implement a feature (TDD mode) | `implement.md` |
| `/test` | Write tests for a feature | `test.md` |
| `/fix` | Fix linter/test errors | `fix.md` |
| `/quality` | Run quality checks | `quality.md` |
| `/retro` | Run project retrospective | `retro.md` |
| `/research` | Deep research on topic | `research.md` |
| `/end` | End session with documentation | `end.md` |

---

## Command Files

Each `.md` file in this directory is a command prompt. The format is:

```markdown
---
command: /commandname
description: What this command does
---

[Prompt text that Claude will process]
```

---

## Usage Examples

**Start a session**:
```
/start
```
Claude will load context and present session options.

**Resume work**:
```
/continue
```
Claude will read `.continue-here.md` and resume.

**Implement feature**:
```
/implement F-0010
```
Claude will start TDD workflow for F-0010.

**Run retrospective**:
```
/retro
```
Claude will conduct project health check.

---

## Customization

You can modify these commands or add your own:

1. Copy a command file
2. Modify the prompt text
3. Change the command name
4. Add to Claude Desktop settings

**Example custom command**:
```markdown
---
command: /deploy
description: Deploy to production
---

I want to deploy to production. Please:

1. Check that all tests pass
2. Verify quality checks pass
3. Check that FEATURES.md is up-to-date
4. Review CHANGELOG.md
5. Confirm deployment checklist
6. Guide me through deployment process

Then await my confirmation before proceeding.
```

---

## Why Optional?

- **Not all Claude versions support custom commands**
- **Copy-paste prompts work just as well**
- **Cursor/Copilot users**: Use prompts from `.agentic/prompts/cursor/` instead
- **Flexibility**: Some users prefer explicit prompts over slash commands

---

## See Also

- Regular Claude prompts: `.agentic/prompts/claude/`
- Cursor prompts: `.agentic/prompts/cursor/`
- Claude hooks: `.agentic/claude-hooks/`


