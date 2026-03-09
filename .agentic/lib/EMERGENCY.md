---
summary: "Emergency quick reference for when tokens run out or agent unavailable"
tokens: ~600
---

# 🚨 Emergency Quick Reference

**Print this or keep it visible. For when tokens run out or you need to work without the agent.**

---

## Tokens Running Out NOW?

**Do these before closing:**

```bash
# 1. Save your current work state
echo "## Emergency Save - $(date)" >> JOURNAL.md
echo "Was working on: [DESCRIBE]" >> JOURNAL.md
echo "Progress: [WHAT GOT DONE]" >> JOURNAL.md
echo "Next steps: [WHAT'S LEFT]" >> JOURNAL.md

# 2. If there's uncommitted code you want to keep
git add -A
git commit -m "WIP: partial progress"  # NEVER use git stash (silent data loss in multi-agent)

# 3. Note anything for next session
echo "- [ ] TODO: [THING TO DO]" >> STATUS.md
```

---

## Add a New Feature (Without Agent)

**Quick version:**
```bash
# Creates feature with next available ID
bash .agentic/lib/tools/quick_feature.sh "My feature name"
```

**Manual version:**
1. Edit `.agentic/spec/FEATURES.md`
2. Add at bottom:
```markdown
## F-XXXX: My Feature Name

**Status**: planned
**Priority**: medium
**Complexity**: medium

**Description**: What it does.

**Acceptance**: TBD
```
3. Agent will see it next session

---

## Check What Agent Was Doing

```bash
# What's current focus?
head -30 STATUS.md

# What happened recently?
tail -30 JOURNAL.md

# Any unfinished work?
bash .agentic/lib/tools/wip.sh check 2>/dev/null || echo "WIP detected"

# Uncommitted changes?
git status
git diff --stat
```

---

## Quick Health Check

```bash
bash .agentic/lib/tools/doctor.sh
```

---

## Log a Bug/Issue

```bash
# Quick log an issue
bash .agentic/lib/tools/quick_issue.sh "Button not working"

# With priority and severity
bash .agentic/lib/tools/quick_issue.sh "Memory leak" high major
```

---

## Record a Decision/Blocker

```bash
# Add to HUMAN_NEEDED.md
echo "## H-$(date +%Y%m%d): [TITLE]" >> HUMAN_NEEDED.md
echo "" >> HUMAN_NEEDED.md
echo "**Context**: [SITUATION]" >> HUMAN_NEEDED.md
echo "" >> HUMAN_NEEDED.md
echo "**Options**: " >> HUMAN_NEEDED.md
echo "1. [OPTION A]" >> HUMAN_NEEDED.md
echo "2. [OPTION B]" >> HUMAN_NEEDED.md
```

---

## Resume Next Session

Tell the agent:
> "Read session_start checklist and help me continue where we left off"

Or shorter:
> "Check WIP and STATUS, then let's continue"

---

## Key Files Cheat Sheet

| File | Purpose | When to Read |
|------|---------|--------------|
| `.agentic/STATUS.md` | Current focus, priorities | Always |
| `JOURNAL.md` | Session history | To remember context |
| `AGENTS.json` | Agent/WIP tracking | `wip.sh check` detects interrupted work |
| `.agentic/HUMAN_NEEDED.md` | Decisions needed | Before starting |
| `.agentic/spec/FEATURES.md` | All features | To add/check features |
| `.agentic/spec/ISSUES.md` | Bugs & issues | To log/check bugs |
| `STACK.md` | How to run/test | When building |

---

## Emergency Contacts

**Framework docs**: `.agentic/START_HERE.md`  
**Full manual ops**: `.agentic/MANUAL_OPERATIONS.md`  
**Recovery workflow**: `.agentic/lib/workflows/work_in_progress.md`

---

*Keep this visible. You don't need the agent to save your work or add specs.*

