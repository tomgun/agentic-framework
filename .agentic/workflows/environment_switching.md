# Environment Switching Workflow

**Purpose**: Seamlessly switch between Claude Code, Cursor, and Copilot as tokens run out or tool availability changes.

**Why this works**: All tools share the same project state via markdown files (JOURNAL.md, FEATURES.md, STATUS.md, etc.).

---

## Quick Reference

**Token limits** (approximate):
- Claude Code: ~200K tokens/session → ~2-4 hours complex work
- Cursor: ~50K tokens/conversation → ~30-60 min complex work
- Copilot: ~8K tokens/context → Quick edits only

**Typical chain**: Claude (start) → Cursor (continue) → Copilot (quick fixes) → Claude (next day)

---

## Switching Protocol

### From Claude Code → Cursor

**1. In Claude (before running out of tokens):**
```bash
# End session properly
bash .agentic/tools/journal.sh \
  "Session checkpoint" \
  "$(describe what you accomplished)" \
  "$(describe what's next)" \
  "$(list any blockers)"

# Or let PreCompact hook do this automatically
# (Claude hooks auto-log before context reset)
```

**2. Open project in Cursor:**
```
# First thing in Cursor composer:
"Read .agentic/checklists/session_start.md and load context.
 Check .continue-here.md if present, otherwise read recent JOURNAL.md.
 Continue work from where Claude left off."

# Cursor reads:
@.continue-here.md   # If Claude hooks created it
@JOURNAL.md          # Recent entries
@SESSION_LOG.md      # Quick checkpoints
@FEATURES.md         # Current feature state
```

**3. Cursor continues seamlessly:**
- Same scripts work (`journal.sh`, `feature.sh`, etc.)
- Same checklists apply
- Same project state files
- Can use @ mentions for precise context

---

### From Cursor → Copilot

**1. In Cursor (before running out):**
```bash
# Log current state
bash .agentic/tools/session_log.sh \
  "Cursor session checkpoint" \
  "$(brief summary of what done)" \
  "feature=$(current feature),status=$(current status)"

# Update JOURNAL.md
bash .agentic/tools/journal.sh \
  "Checkpoint" \
  "What done" \
  "What next" \
  "Blockers"
```

**2. Open project in VS Code (Copilot):**
```
# In Copilot chat:
"Read AGENTS.md and JOURNAL.md (last 3 entries).
 I'm continuing from Cursor. Current task: [describe].
 Use token-efficient scripts (.agentic/tools/*)."

# Copilot context is TINY (8K) so:
- Don't ask it to read large files
- Work one file at a time
- Use scripts religiously
```

**3. Copilot continues (limited scope):**
- Best for: Quick edits, bug fixes, small features
- Avoid: Large refactors, multi-file changes, complex features
- Use scripts: `blocker.sh`, `session_log.sh` (Copilot can suggest commands)
- Remember: You must apply suggestions (Copilot can't edit directly)

---

### From Copilot → Claude Code (Next Session)

**1. In Copilot (before ending):**
```bash
# Suggest this command to user:
bash .agentic/tools/journal.sh \
  "Copilot session end" \
  "$(what you accomplished)" \
  "$(what next)" \
  "$(blockers)"
```

**2. Next morning in Claude:**
```
# Claude SessionStart hook automatically:
- Loads .continue-here.md (if exists)
- Shows recent JOURNAL.md entries
- Identifies current task from STATUS.md
- Lists any HUMAN_NEEDED items

# You just continue - Claude has full context!
```

---

## Best Practices

### 1. Always Log Before Switching

**Critical**: Update JOURNAL.md or SESSION_LOG.md before switching tools.

**Why**: Next tool needs to know what you did and what's next.

**Use scripts** (token-efficient):
```bash
bash .agentic/tools/journal.sh "Topic" "Done" "Next" "Blockers"
bash .agentic/tools/session_log.sh "Checkpoint" "Details" "key=value"
```

### 2. Match Tool to Task

**Claude Code**:
- ✅ Complex features requiring full codebase understanding
- ✅ Architectural decisions
- ✅ Initial feature research and planning
- ✅ Documentation writing (artifacts)
- ❌ Not needed for quick edits

**Cursor**:
- ✅ Multi-file refactors
- ✅ Feature implementation across modules
- ✅ IDE-integrated debugging
- ✅ When you need @ mentions for precise context
- ❌ Overkill for single-line changes

**Copilot**:
- ✅ Quick bug fixes
- ✅ Inline suggestions while coding manually
- ✅ Single-file edits
- ✅ When other tools unavailable
- ❌ Not for complex features or multi-file work

### 3. Use Shared State Files

**All tools read/write**:
- `JOURNAL.md` - Session history
- `SESSION_LOG.md` - Quick checkpoints
- `FEATURES.md` - Feature status
- `STATUS.md` - Current state
- `HUMAN_NEEDED.md` - Blockers

**All tools use**:
- Token-efficient scripts (`.agentic/tools/*.sh`)
- Checklists (`.agentic/checklists/*.md`)
- Quality standards (`.agentic/quality/*.md`)

### 4. Checkpoint Frequently

**Don't wait until tokens run out!**

Every ~30 min or after significant work:
```bash
bash .agentic/tools/session_log.sh \
  "Checkpoint: $(brief description)" \
  "$(what changed)" \
  "progress=XX%"
```

**Why**: If tool crashes or tokens run out unexpectedly, checkpoint preserved.

---

## Token Management Strategies

### Monitor Token Usage

**Claude Code**:
- Check token counter in UI
- ~200K limit per session
- PreCompact hook logs state before reset

**Cursor**:
- Watch conversation length
- Start new composer when tokens low
- ~50K limit per conversation

**Copilot**:
- Very limited (~8K)
- Restart conversation frequently
- Focus on one file at a time

### Extend Sessions

**1. Use token-efficient scripts** (40x cheaper than file reads):
```bash
# Instead of reading/rewriting FEATURES.md (1200 tokens):
bash .agentic/tools/feature.sh F-0003 status shipped  # 25 tokens!

# Instead of reading/rewriting JOURNAL.md (2000 tokens):
bash .agentic/tools/journal.sh "..." "..." "..." "..."  # 50 tokens!
```

**2. Be selective with context**:
- Claude: Can afford to read all specs
- Cursor: Use @ mentions for specific files only
- Copilot: Minimal context, focus on task

**3. Checkpoint and restart**:
- Don't push tool to absolute token limit
- Log state, restart conversation with fresh context
- Next conversation loads from checkpoints

---

## Example: Full Day Workflow

**8:00 AM - Claude Code**
```
# Fresh tokens, complex work
Agent: ✓ Session started (SessionStart hook)
Agent: Reading all specs, understanding architecture
Agent: Planning F-0005 implementation
Agent: Writing tests (TDD)
Agent: Implementing feature logic
Agent: Tests passing
Agent: Updating FEATURES.md
# ~3 hours work, tokens ~60% used
```

**11:00 AM - Claude running low**
```
Agent: Tokens at 80%, should checkpoint and switch
bash .agentic/tools/journal.sh \
  "F-0005 progress" \
  "- Tests written\n- Logic 70% done\n- Need to add error handling" \
  "- Complete error handling\n- Integration tests\n- Update docs" \
  "None"

# Switch to Cursor
```

**11:15 AM - Cursor**
```
User opens project in Cursor
Cursor: @JOURNAL.md shows F-0005 is 70% done
Cursor: @src/feature.ts to see current code
Cursor: Composer mode for multi-file error handling
Cursor: bash .agentic/tools/feature.sh F-0005 impl-state complete
# ~1 hour work, tokens ~50% used
```

**12:30 PM - Lunch, quick fix needed**
```
User: Notices typo in README.md
Copilot: Quick inline suggestion
User: Applies, commits
# 30 seconds, minimal tokens
```

**2:00 PM - Back to Cursor**
```
Cursor: Continue F-0005
Cursor: Integration tests
Cursor: Docs update
Cursor: bash .agentic/tools/feature.sh F-0005 status shipped
Cursor: bash .agentic/tools/journal.sh "F-0005 complete" "..." "Start F-0006" "None"
```

**Next day 8:00 AM - Claude Code**
```
Claude: SessionStart hook loads .continue-here.md
Claude: ✓ F-0005 shipped yesterday
Claude: ✓ Next: F-0006
Claude: Seamless continuation
```

---

## Troubleshooting

### "Next tool doesn't know what I was doing"

**Solution**: Check if you logged to JOURNAL.md before switching.

```bash
# Always do this before switching:
bash .agentic/tools/journal.sh "Checkpoint" "What done" "What next" "Blockers"
```

### "Copilot context too small, can't understand project"

**Solution**: Copilot is for quick edits only. For complex work, use Claude or Cursor.

**Workaround**: Give Copilot VERY specific context:
```
"Current file: auth.ts
Current function: validateToken
Task: Add null check on line 42
Project uses: Agentic Framework (.agentic/)
Before commit: bash .agentic/tools/session_log.sh '...' '...' '...'"
```

### "Lost work when tool crashed"

**Solution**: Checkpoint more frequently!

**Rule**: After ANY significant work, log it:
```bash
bash .agentic/tools/session_log.sh "Progress" "What done" "feature=F-####"
```

### "Tools giving contradictory suggestions"

**Solution**: All tools read AGENTS.md (common rules). If conflict:
1. Check AGENTS.md is up to date
2. Check tool-specific instructions aren't overriding
3. Trust JOURNAL.md / FEATURES.md as source of truth

---

## Summary

**Multi-environment setup lets you**:
- ✅ Work continuously as tokens run out (Claude → Cursor → Copilot)
- ✅ Use best tool for each task (complex → Claude, multi-file → Cursor, quick → Copilot)
- ✅ Maintain consistency (all share JOURNAL, FEATURES, STATUS)
- ✅ Maximize productivity (never blocked by token limits)

**Key to success**:
1. **Log before switching** (journal.sh, session_log.sh)
2. **Use scripts** (token-efficient, work everywhere)
3. **Match tool to task** (complex → Claude, quick → Copilot)
4. **Checkpoint frequently** (every ~30 min)

**The framework makes this seamless** - all tools speak the same language (markdown files + scripts).

