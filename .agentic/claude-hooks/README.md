# Claude Desktop Hooks for Agentic AF

**Purpose**: Automated lifecycle hooks that enhance Claude Desktop with real-time validation, automatic context injection, and state preservation.

**Requirements**: Claude Desktop with hooks enabled (available in Claude Desktop settings)

---

## What Are Hooks?

Hooks are scripts that run automatically at specific points in the Claude Desktop lifecycle:

| Hook | When It Runs | Purpose |
|------|--------------|---------|
| `SessionStart.sh` | When you start a new Claude chat | Validate environment, show project status |
| `UserPromptSubmit.sh` | Before Claude processes your first prompt | Auto-inject `.continue-here.md` for instant context recovery |
| `PostToolUse.sh` | After Claude uses any tool (file edit, terminal, etc.) | Run quick linter checks |
| `PreCompact.sh` | Before context window gets compacted | Save state to `.continue-here.md` and `JOURNAL.md` |
| `Stop.sh` | When session ends | Remind about uncommitted changes and documentation |

---

## Setup

### 1. Enable Hooks in Claude Desktop

1. Open Claude Desktop settings
2. Go to **Advanced** or **Developer** section
3. Enable **Custom Hooks** or **Project Hooks**
4. Specify hooks configuration file: `.agentic/claude-hooks/hooks.json`

**Note**: Hook support varies by Claude Desktop version. Check official Claude documentation for your version.

### 2. Copy Hooks to Your Project

After installing Agentic AF with `install.sh`, the hooks are already in `.agentic/claude-hooks/`.

If you installed manually, ensure `hooks.json` and all `.sh` files are executable:

```bash
chmod +x .agentic/claude-hooks/*.sh
```

### 3. Configure Claude Project

In Claude Desktop, when creating or configuring a project:

1. Set **Project Directory**: `/path/to/your-project`
2. Enable **Custom Hooks**: Yes
3. **Hooks Config**: `.agentic/claude-hooks/hooks.json`

---

## What Each Hook Does

### `SessionStart.sh`

**Runs**: At the beginning of each Claude session

**Actions**:
- ✓ Check if this is an Agentic AF project
- ✓ Show framework version
- ✓ Detect if `.continue-here.md` exists (for context recovery)
- ✓ Check for blockers in `HUMAN_NEEDED.md`
- ✓ Run quick health check (`doctor.sh --quick`)
- ✓ Show git status (uncommitted changes, last commit)

**Output Example**:
```
🚀 Agentic AF Session Start

📦 Framework version: 0.3.5
✓ Session context available (.continue-here.md from 2025-01-04 22:30)
  💡 I'll auto-inject this file when you send your first prompt
⚠ 2 blocker(s) in HUMAN_NEEDED.md
  Review these before continuing development
📝 3 uncommitted change(s)
🔗 Last commit: a1b2c3d feat: add user login

✓ Session ready
```

---

### `UserPromptSubmit.sh`

**Runs**: Before Claude processes your first prompt in a session

**Actions**:
- Check if `.continue-here.md` exists
- If yes, and if not injected yet this session:
  - Auto-inject file contents into context
  - Mark as injected (won't inject again until next session)
- If file is >7 days old, warn about staleness

**Benefits**:
- **Zero manual work**: You don't have to say "read .continue-here.md"
- **Instant context**: Claude knows where you left off immediately
- **One-time injection**: Won't spam context with repeated injections

**Output Example**:
```
📄 Auto-injecting session context from .continue-here.md:

[... contents of .continue-here.md ...]

---
```

---

### `PostToolUse.sh`

**Runs**: After Claude uses any tool (writes a file, runs a command, etc.)

**Actions**:
- Detect recent file modifications (last 1 minute)
- If code files changed, run fast linter:
  - JavaScript/TypeScript: `eslint --quiet`
  - Rust: `cargo check --quiet`
  - Python: `ruff check --quiet`
- Report issues (advisory only, doesn't block Claude)

**Benefits**:
- **Immediate feedback**: Catch syntax errors right after writing code
- **Non-blocking**: Claude continues working, but you see warnings
- **Fast**: Only runs quick checks (no tests, those are slow)

**Output Example**:
```
⚠️  Quick lint check found issues. Run your linter to see details.
```

---

### `PreCompact.sh`

**Runs**: Before Claude compacts the context window (when it gets full)

**Actions**:
- Generate fresh `.continue-here.md` (preserves current state)
- Add `JOURNAL.md` entry with compaction timestamp
- Note uncommitted changes
- Remind about in-progress features and blockers

**Benefits**:
- **Never lose progress**: State is saved before compaction
- **Seamless resume**: After compaction, Claude can continue with full context
- **Audit trail**: `JOURNAL.md` tracks compaction events

**Output Example**:
```
💾 Context compaction detected - preserving state...

Generating .continue-here.md...
✓ Session context preserved in .continue-here.md
✓ Added JOURNAL.md entry
Note: 1 feature(s) in progress (check FEATURES.md after resuming)
⚠ Reminder: 2 blocker(s) in HUMAN_NEEDED.md

✓ State preservation complete

After compaction, I'll resume with full context from .continue-here.md
```

---

### `Stop.sh`

**Runs**: When Claude session is ending (you close the chat, quit app, etc.)

**Actions**:
- Check for uncommitted git changes
- Check if `JOURNAL.md` was updated this session
- Check if `.continue-here.md` is fresh
- Note in-progress features
- Show session end checklist

**Benefits**:
- **Don't forget to commit**: Reminds you to save work
- **Documentation hygiene**: Encourages updating `JOURNAL.md`
- **Smooth handoff**: Ensures next session has fresh context

**Output Example**:
```
👋 Session ending - final checks...

⚠️  3 uncommitted change(s)
   Run: git status
⚠️  JOURNAL.md not updated in this session
   Consider adding session summary

⚠️  2 reminder(s) above

Session end checklist:
- [ ] Commit changes (git add + git commit)
- [ ] Update JOURNAL.md with session summary
- [ ] Update STATUS.md or PRODUCT.md if needed
- [ ] Generate .continue-here.md for next session
```

---

## Customization

All hooks are bash scripts that you can customize for your project:

### Example: Add Custom Linter

Edit `.agentic/claude-hooks/PostToolUse.sh`:

```bash
# Add your custom linter
if [[ -f ".mylinter.config" ]]; then
  mylinter check --fast
fi
```

### Example: Custom Session Start Message

Edit `.agentic/claude-hooks/SessionStart.sh`:

```bash
# Add project-specific checks
if [[ -f "API_KEYS_NEEDED.md" ]]; then
  echo "⚠️  Check API_KEYS_NEEDED.md for required credentials"
fi
```

### Example: Skip Hooks Temporarily

To temporarily disable a hook, rename it:

```bash
mv .agentic/claude-hooks/PostToolUse.sh .agentic/claude-hooks/PostToolUse.sh.disabled
```

Or modify `hooks.json` to remove the hook entry.

---

## Troubleshooting

### Hooks Not Running

**Check**:
1. Hooks enabled in Claude Desktop settings?
2. `.agentic/claude-hooks/hooks.json` exists and is valid JSON?
3. Hook scripts are executable? (`ls -la .agentic/claude-hooks/*.sh`)
4. Claude has permission to run scripts? (macOS: check Security & Privacy)

**Debug**:
- Run hooks manually to see output: `bash .agentic/claude-hooks/SessionStart.sh`
- Check Claude Desktop logs (location varies by OS)

### Hook Timeout Errors

If hooks time out (take too long), increase timeout in `hooks.json`:

```json
{
  "timeout": 10000  // 10 seconds instead of 5
}
```

Or optimize the hook script to run faster (skip slow checks).

### Hooks Breaking Claude

All hooks are designed to **never block Claude** (they exit with code 0 even on errors). If Claude seems stuck:

1. Check hook script syntax: `bash -n .agentic/claude-hooks/SessionStart.sh`
2. Run hook manually and look for infinite loops or hangs
3. Temporarily disable hooks, restart Claude, re-enable one by one to isolate issue

---

## Compatibility

| Feature | Required Version | Notes |
|---------|-----------------|-------|
| Hooks API | Claude Desktop 1.x+ | Check official docs for your version |
| `SessionStart` | All versions | Basic hook support |
| `UserPromptSubmit` | Newer versions | May not be available in older Claude Desktop |
| `PreCompact` | Newer versions | Context compaction is a recent feature |

**If hooks don't work in your Claude Desktop version**:
- You can still use the scripts manually
- Example: Run `bash .agentic/tools/continue_here.py` before starting a session
- Example: Run `.agentic/claude-hooks/Stop.sh` manually before ending a session

---

## See Also

- [`.agentic/prompts/claude/README.md`](../prompts/claude/README.md) - Ready-to-use Claude prompts
- [`.agentic/DEVELOPER_GUIDE.md`](../DEVELOPER_GUIDE.md) - Complete framework guide
- [`.agentic/tools/continue_here.py`](../tools/continue_here.py) - Generate `.continue-here.md` manually

---

**Note**: Hooks are a Claude Desktop feature. For Cursor or GitHub Copilot, use manual workflows or ready-to-use prompts instead.

