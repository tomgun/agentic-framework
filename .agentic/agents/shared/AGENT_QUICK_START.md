# Agent Quick Start

**Read this first. It's ~60 lines. Gates enforce quality - you don't need to memorize checklists.**

---

## The One Rule

Run `doctor.sh` at phase transitions. It tells you what's wrong and blocks bad actions.

## Development Phases

```
START → PLANNING → IMPLEMENT → COMPLETE → COMMIT
```

## Phase Commands

| Phase | When | Command |
|-------|------|---------|
| START | Session begins | `bash .agentic/tools/doctor.sh` |
| PLANNING | User says "implement F-####" | Check `spec/acceptance/F-####.md` exists |
| BUG FIX | User reports or says "fix", "bug", "issue" | Log to `spec/ISSUES.md` first, then fix |
| IMPLEMENT | Acceptance exists | Write code + tests |
| COMPLETE | User says "done" | `bash .agentic/tools/doctor.sh --full` |
| COMMIT | Ready to commit | `bash .agentic/tools/doctor.sh --pre-commit` |

## What Gets Checked

- **START**: Context files exist? WIP from previous session?
- **PLANNING**: Acceptance criteria exist for the feature?
- **IMPLEMENT**: Tests exist? Code matches acceptance?
- **COMPLETE**: Tests pass? FEATURES.md updated? Docs synced?
- **COMMIT**: No .agentic/WIP.md? No untracked files? All gates pass?

## Session Start Protocol

1. Check `.agentic/AGENTS_ACTIVE.md` - other agents working? Register yourself, avoid their files
2. Check `.agentic/WIP.md` - interrupted work?
3. Read: `CONTEXT_PACK.md` → `STATUS.md` → `JOURNAL.md` (last 3 entries)
4. Greet user with context summary and options

## If Gate Fails

Fix what `doctor.sh` reports. Don't proceed until it passes.

## If Stuck

Add to `HUMAN_NEEDED.md`. Ask the human.

## When User Says "/verify"

The user is helping enforce quality. Run `doctor.sh --full` immediately and report results.

## Key Tools

| Tool | Use For |
|------|---------|
| `doctor.sh` | THE verification command |
| `doctor.sh --full` | Comprehensive check |
| `doctor.sh --pre-commit` | Before committing |
| `journal.sh` | Append to JOURNAL.md |
| `feature.sh` | Update FEATURES.md |
| `quick_issue.sh` | Log bugs to ISSUES.md |
| `wip.sh` | Track work-in-progress |

## Feature Work

For implementing features, consider using the orchestrator:
`.agentic/agents/roles/orchestrator-agent.md`

It coordinates specialized agents and enforces gates automatically.

---

## Detailed Reference

Only read these when you need specifics:
- Full guidelines: `.agentic/agents/shared/agent_operating_guidelines.md`
- Principles: `.agentic/PRINCIPLES.md`
- Checklists: `.agentic/checklists/`
