# Scaffold-First Tool Install + Eliminate Hook Wrappers + AskUserQuestion Interview

## Context

Four improvements to the init/scaffold flow:
1. **Eliminate Claude hook wrappers**: `.agentic/hooks/claude/` has 9 wrapper scripts (5 lines each) that only call bootstrap then exec to `lib/claude-hooks/`. Since scaffold already extracts lib/ before the first Claude session, fold bootstrap into the implementations and point `hooks.json` directly to `lib/`. Fewer files, auto-updates with framework upgrades.
2. **False restart advisory**: `setup-agent.sh`, `ag hooks install`, and `ag auto init` unconditionally print "restart Claude" even when hooks already exist from scaffold. Fix: only warn on actual new installs.
3. **Redundant reinstall**: init_playbook Step 1a re-runs `setup-agent.sh` (scaffold already did it). Change to verify/prune.
4. **Sequential interview**: Use Claude Code's `AskUserQuestion` tool for batched questions instead of 7 text round-trips.

## Changes

### 1. Eliminate Claude hook wrappers — point hooks.json directly to lib/

**Delete**: All files in `.agentic/hooks/claude/` (9 wrapper scripts)

**Modify**: `.agentic/lib/claude-hooks/hooks.json` — change paths from `.agentic/hooks/claude/X.sh` to `.agentic/lib/claude-hooks/X.sh`:
```json
"command": "${CLAUDE_PROJECT_DIR}/.agentic/lib/claude-hooks/PreToolUse.sh"
```

**Modify**: Each `.agentic/lib/claude-hooks/*.sh` implementation — add bootstrap guard at top (after shebang, before any lib imports):
```bash
# Bootstrap: ensure lib/ is extracted (no-op if already present)
bash "${CLAUDE_PROJECT_DIR:-.}/.agentic/bootstrap.sh" 2>/dev/null || true
```

Files to add bootstrap guard to (8 implementations):
- `PreToolUse.sh`, `PostToolUse.sh`, `UserPromptSubmit.sh`, `Stop.sh`
- `SessionStart.sh`, `PreCompact.sh`

**Modify**: `.agentic/lib/hooks/shared/on-plan-mode-exit.sh`, `on-bash-merge-detect.sh`, `on-code-edit.sh` — same bootstrap guard (these are referenced by PostToolUse entries in hooks.json)

**Modify**: `.agentic/lib/tools/setup-agent.sh` — the hooks.json source path stays the same (`lib/claude-hooks/hooks.json`), no change needed here.

**Keep**: `.agentic/hooks/pre-commit` — git requires this at `core.hooksPath`. This wrapper stays.

### 2. `setup-agent.sh` — Idempotent hook install, no restart warning
**File**: `.agentic/lib/tools/setup-agent.sh` (lines 90-97)

Replace unconditional copy+warning with diff check:
```bash
if [[ -f "$HOOKS_TARGET" ]] && diff -q "$HOOKS_SOURCE" "$HOOKS_TARGET" >/dev/null 2>&1; then
  echo "✓ Hooks verified (.claude/hooks.json — already up to date)"
else
  cp "$HOOKS_SOURCE" "$HOOKS_TARGET"
  echo "✓ Installed hooks (.claude/hooks.json)"
fi
```
Remove restart advisory — callers handle their own messaging.

### 3. `operations.sh` — Conditional restart in `ag hooks install`
**File**: `.agentic/lib/tools/commands/operations.sh` (Claude hooks in `cmd_hooks install`)

Same diff-check pattern. Only print restart warning when hooks were actually created/changed.

### 4. `init.py` — `ensure_hooks()` returns status string
**File**: `.agentic/lib/auto/init.py`

Change return to `"already_present"` | `"installed"` | `"updated"` | `"source_missing"`. Remove `ensure_hooks()` from `write_settings()`. Call both from `main()`:
- `already_present` → "✓ Hooks active since session start"
- `installed`/`updated` → "⚠ Restart Claude Code to activate hooks"

### 5. `init_playbook.md` — Step 1a verify/prune + Step 2 AskUserQuestion
**File**: `.agentic/lib/init/init_playbook.md`

**Step 1a** (lines 252-305): Rewrite from "install tools" to "verify/prune":
- Show what's already installed
- Use `AskUserQuestion` (multi-select) to ask which tools user actually uses
- Verify selected tools present; only run `setup-agent.sh` if missing
- Offer to remove unselected tool configs (optional)

**Step 2** ("The Interview"): Replace 7 sequential text questions with `AskUserQuestion`:
```
Call 1 (4 questions max):
- "What are we building?" — free text (Other)
- "Primary platform?" — options: web, mobile, desktop, CLI, game, audio plugin
- "Tech stack?" — free text (Other)
- "Project license?" — options: MIT, Apache 2.0, GPL, Proprietary

Call 2:
- "Key constraints?" — multiSelect: performance, security, compliance, offline-first, real-time
- "Testing approach?" — options: pytest, jest, vitest, cargo test, go test
- "E2E testing?" — options: playwright, cypress, none, other (only if platform=web/mobile)
```

### 6. `scaffold.sh` — Update messaging
**File**: `.agentic/lib/init/scaffold.sh` (lines 346-351, 452-457)

Change "The agent will ask which AI tool(s) you use" → "✓ All AI tool configs pre-installed. The agent will verify and offer to prune unused configs."

## Files to modify
1. `.agentic/hooks/claude/*.sh` — DELETE all 9 wrapper files
2. `.agentic/lib/claude-hooks/hooks.json` — update paths to point to lib/
3. `.agentic/lib/claude-hooks/*.sh` — add bootstrap guard (8 files)
4. `.agentic/lib/hooks/shared/*.sh` — add bootstrap guard (3 files)
5. `.agentic/lib/tools/setup-agent.sh` — idempotent hooks, remove restart warning
6. `.agentic/lib/tools/commands/operations.sh` — conditional restart
7. `.agentic/lib/auto/init.py` — `ensure_hooks()` returns status
8. `.agentic/lib/init/init_playbook.md` — verify/prune + AskUserQuestion
9. `.agentic/lib/init/scaffold.sh` — update messaging

## Verification
- `bash .agentic/lib/tools/setup-agent.sh claude` twice — second says "verified", no restart
- `ag hooks install` when present → "already up to date"
- `ag hooks install` after delete → "installed" with restart warning
- `ag hooks status` lists all hooks pointing to lib/ paths
- `bash tests/validate_framework.sh` passes
- Verify `.agentic/hooks/claude/` is empty (only git pre-commit wrapper remains in `.agentic/hooks/`)
