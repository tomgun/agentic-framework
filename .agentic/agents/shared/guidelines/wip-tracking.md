# Work-In-Progress (WIP) Tracking

**Purpose**: Never lose work when tokens run out, tools crash, or context gets compacted.

---

## When to Use WIP Tracking

### Start WIP when beginning significant work

```bash
# Starting a feature (Core+PM)
bash .agentic/tools/wip.sh start F-0005 "User authentication" "src/auth/*.ts,tests/auth/*.test.ts"

# Starting work (Core profile)
bash .agentic/tools/wip.sh start "auth-implementation" "User login and JWT tokens" "src/auth/*.ts"
```

### Update WIP frequently (~every 15 minutes)

```bash
bash .agentic/tools/wip.sh checkpoint "Login endpoint complete, starting JWT validation"
bash .agentic/tools/wip.sh checkpoint "Unit tests passing, working on integration tests"
```

### Complete WIP when work is done

```bash
bash .agentic/tools/wip.sh complete
# Then commit your changes
git add -A && git commit -m "feat: user authentication"
```

---

## Session Start WIP Check (CRITICAL)

**ALWAYS check for interrupted work at session start:**

```bash
bash .agentic/tools/wip.sh check
```

### If interrupted work detected:

Tell the user immediately:

```
⚠️ Previous work on F-0005: User Authentication was interrupted 45 minutes ago.

I can see 3 uncommitted changes:
- src/auth/login.ts
- src/auth/types.ts
- tests/auth/login.test.ts

Last checkpoint: "Login endpoint done, starting JWT validation"

Would you like to:
1. Continue from where we left off
2. Review changes first (git diff)
3. Roll back to last commit (git reset --hard)
```

---

## WIP and Context Compaction (Claude)

**Claude PreCompact hook automatically updates WIP:**
- Before context compaction, `PreCompact.sh` runs
- Updates WIP checkpoint automatically
- Logs to SESSION_LOG.md
- After compaction, WIP preserves state

**You don't need to do anything** - hooks handle it!

---

## WIP and Environment Switching

**When switching between tools (Claude → Cursor → Copilot):**

### Before switching:
```bash
bash .agentic/tools/wip.sh checkpoint "Switching from Claude to Cursor"
```

### In new environment (session start):
```bash
bash .agentic/tools/wip.sh check
# Output: "✓ Recent checkpoint (3 minutes ago) - This may be an active handoff"
# Continue seamlessly!
```

---

## WIP and Multi-Agent Coordination

When multiple agents work in parallel:

1. Each agent maintains their own WIP in their worktree
2. WIP files are NOT shared between worktrees
3. Use `.agentic/AGENTS_ACTIVE.md` to coordinate
4. Check for conflicting file modifications

---

## WIP File Location

- Location: `.agentic/WIP.md`
- Contains:
  - Feature/task being worked on
  - Files being modified
  - Checkpoint history
  - Recovery instructions

---

## Summary

| When | Action |
|------|--------|
| Start significant work | `wip.sh start` |
| Every ~15 minutes | `wip.sh checkpoint` |
| Work complete | `wip.sh complete` |
| Session start | `wip.sh check` |
| Before tool switch | `wip.sh checkpoint` |

**WIP prevents work loss** - use it consistently!
