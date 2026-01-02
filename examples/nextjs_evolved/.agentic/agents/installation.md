# Agent adapter installation

Goal: make **all agents** (Cursor / Copilot / Claude) follow the same operating rules.

## Canonical truth (works for all agents)
These files should exist at repo root (created by `bash .agentic/init/scaffold.sh`):
- `STACK.md`
- `CONTEXT_PACK.md`
- `STATUS.md`
- `/spec/`
- `spec/adr/`

## Shared agent rules
Recommended: ensure `AGENTS.md` exists at repo root (created by scaffold). If you need to recreate it:

```bash
bash .agentic/init/scaffold.sh
```

## Cursor (2.2+)
Preferred (modern) rule location:

```bash
mkdir -p .cursor/rules
cp .agentic/agents/cursor/agentic-framework.mdc .cursor/rules/agentic-framework.mdc
```

Compatibility (older):

```bash
cp .agentic/agents/cursor/cursorrules.txt .cursorrules
```

## GitHub Copilot

```bash
mkdir -p .github
cp .agentic/agents/copilot/copilot-instructions.md .github/copilot-instructions.md
```

## Claude

```bash
cp .agentic/agents/claude/CLAUDE.md CLAUDE.md
```

## Avoiding conflicts (multi-agent repos)
- Treat `AGENTS.md` (if present) as the **single behavioral contract**.
- Keep tool-specific instruction files thin and pointing back to `AGENTS.md`, `CONTEXT_PACK.md`, `STATUS.md`.


