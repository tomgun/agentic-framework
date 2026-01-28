# Agent Tool Installation Guide

**Critical**: `AGENTS.md` is a **reference file** that is NOT auto-loaded by any AI coding tool!

Each tool has its own auto-loaded file:

| Tool | Auto-Loaded File | How to Create |
|------|------------------|---------------|
| Claude Code | `CLAUDE.md` | `bash .agentic/tools/setup-agent.sh claude` |
| Cursor | `.cursorrules` | `bash .agentic/tools/setup-agent.sh cursor` |
| GitHub Copilot | `.github/copilot-instructions.md` | `bash .agentic/tools/setup-agent.sh copilot` |
| **All tools** | All of the above | `bash .agentic/tools/setup-agent.sh all` |

---

## Quick Setup

```bash
# Set up for your specific tool:
bash .agentic/tools/setup-agent.sh claude   # Claude Code
bash .agentic/tools/setup-agent.sh cursor   # Cursor
bash .agentic/tools/setup-agent.sh copilot  # GitHub Copilot

# Or set up all tools at once:
bash .agentic/tools/setup-agent.sh all
```

---

## What Each File Does

### CLAUDE.md (Claude Code)

- Auto-loaded by Claude Code at session start
- Contains mandatory session protocol
- Points to `.agentic/agents/shared/agent_operating_guidelines.md`
- Includes Claude-specific optimizations

### .cursorrules (Cursor)

- Auto-loaded by Cursor when opening project
- Minimal file pointing to framework guidelines
- Also creates `.cursor/rules/agentic-framework.mdc` if `.cursor/` exists

### .github/copilot-instructions.md (GitHub Copilot)

- Auto-loaded by GitHub Copilot
- Contains mandatory protocols
- Points to full guidelines

---

## What About AGENTS.md?

`AGENTS.md` is:
- ✅ A human-readable reference of non-negotiables
- ✅ Included by the auto-loaded files
- ❌ NOT auto-loaded by any tool

Keep `AGENTS.md` as the source of truth for non-negotiables, but ensure agents actually see them by setting up the tool-specific files.

---

## Supported Tools

### Codex (OpenAI CLI)

Codex CLI auto-loads `.codex/instructions.md`.

**Automatic setup:**
```bash
bash .agentic/tools/setup-agent.sh codex
```

**Manual setup:**
```bash
mkdir -p .codex
cp .agentic/agents/codex/codex-instructions.md .codex/instructions.md
```

### Gemini CLI

As of 2025, Gemini CLI uses:
- `.gemini/instructions.md` (if exists)
- Or specify via `--system-prompt` flag

To support Gemini, create `.gemini/instructions.md`:
```bash
mkdir -p .gemini
cp .agentic/agents/shared/agent_operating_guidelines.md .gemini/instructions.md
```

### Amazon Q Developer

Uses `.amazonq/instructions.md`.

### Other Tools

If your tool isn't listed:
1. Check your tool's documentation for auto-loaded file locations
2. Copy the content from `.agentic/agents/shared/agent_operating_guidelines.md`
3. Consider contributing the setup to this framework!

---

## Verifying Setup

After running setup, verify the files were created:

```bash
# Check what files exist
ls -la CLAUDE.md .cursorrules .github/copilot-instructions.md 2>/dev/null

# Verify content
head -20 CLAUDE.md
```

---

## Updating Tool Files

If you update `.agentic/agents/*/` content, re-run setup:

```bash
bash .agentic/tools/setup-agent.sh all
```

The script will backup existing files before overwriting.
