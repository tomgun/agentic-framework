---
name: debugging-framework
description: >
  Debug framework enforcement failures: hooks not firing, gates skipped,
  workflows broken. Use when a hook/gate/enforcement didn't work as expected,
  when "why didn't X fire?", "hooks aren't working", "gate was skipped",
  "enforcement failed", or when investigating why the framework allowed
  something it shouldn't have.
  Do NOT use for: implementing features, fixing application bugs, writing tests.
compatibility: "Requires Claude Code with shell access."
allowed-tools: [Read, Bash, Glob, Grep, Agent]
metadata:
  author: agentic-framework
  version: "0.81.0"
---
# Debugging Framework Enforcement

When a hook, gate, or workflow didn't behave as expected, follow this diagnostic sequence.
**Never assume** — verify with evidence from logs before making claims.

## Step 1: Check Log Sources (do this FIRST)

Four log sources exist. Check ALL of them before forming a hypothesis:

### a) Claude JSONL (tool calls + hook output)
```bash
# Find current session JSONL
LATEST=$(ls -t ~/.claude/projects/-workspace/*.jsonl | head -1)
# Search for specific tool/hook events
python3 -c "
import json
with open('$LATEST') as f:
    for line in f:
        d = json.loads(line)
        msg = json.dumps(d)
        if 'SEARCH_TERM' in msg:
            t = d.get('type', '?')
            print(f'{t}: {msg[:300]}')
"
```
Hook output appears in tool_result entries. If a PostToolUse hook fires on ExitPlanMode, its stdout appears in the ExitPlanMode tool result. **No output = hook didn't fire.**

### b) Framework log (.agentic/session/framework.log)
```bash
tail -30 .agentic/session/framework.log
```
Records `ag` command invocations with timestamps and exit codes. Does NOT record hook invocations.

### c) Btrace debug log (.agentic/debug/btrace-*.jsonl)
```bash
# Check if btrace is enabled
grep btrace STACK.md
# Read latest trace
cat .agentic/debug/btrace-latest.jsonl | python3 -m json.tool
```
Only populated when `btrace: on` in STACK.md. Records hook phases, gate checks, plan saves.

### d) Token/intel event logs (.agentic/session/)
```bash
grep "PATTERN" .agentic/session/token-events.log
grep "PATTERN" .agentic/session/intel-events.log
```
Records PostToolUse file tracking events.

## Step 2: Verify Hook Wiring

```bash
# Check hooks.json has the expected matcher
python3 -c "
import json
with open('.claude/hooks.json') as f:
    d = json.load(f)
for event, matchers in d.get('hooks', {}).items():
    for m in matchers:
        print(f'{event} [{m[\"matcher\"]}] → {m[\"hooks\"][0][\"command\"].split(\"/\")[-1]}')
"
```

Common failure: hook exists as a file but isn't wired in hooks.json.

## Step 3: Verify Hook Script Runs

```bash
# Test the hook directly with mock environment
CLAUDE_PROJECT_DIR=/workspace bash .agentic/lib/hooks/shared/on-plan-mode-exit.sh
```

Common failures:
- `source paths.sh` fails → hook exits silently at line 26
- Setting not found → `get_setting` returns default, hook takes wrong branch
- Feature ID not parsed from filename → sentinel not created

## Step 4: Check Sentinel Files

```bash
ls -la .agentic/session/review-pending-* .agentic/session/.plan-approved .agentic/session/.plan-review-skipped 2>/dev/null
```

Sentinels control enforcement:
- `review-pending-*` → created by on-plan-mode-exit.sh, blocks code edits
- `.plan-approved` → created by PostToolUse.sh when review.md evidence found
- `.plan-review-skipped` → created by `ag plan skip`

**No sentinel = no enforcement.** If the hook didn't create a sentinel, PreToolUse has nothing to check.

## Step 5: Check Gate Logic

```bash
# Test gate.py directly
PYTHONPATH=.agentic/lib python3 -c "
from pathlib import Path
from gate import check_plan_review_evidence
result = check_plan_review_evidence(Path('.'))
print(f'Decision: {result.decision}, Messages: {result.messages}')
"
```

## Common Failure Patterns

| Symptom | Root Cause | How to Verify |
|---------|-----------|---------------|
| Hook output missing from tool result | Hook didn't fire (not wired, or failed at source) | Check JSONL for tool_result content |
| Sentinel not created | Feature ID not parsed from plan filename | Check hook script with `bash -x` |
| Code edits not blocked | No sentinel exists OR `.plan-approved`/`.plan-review-skipped` present | Check `.agentic/session/` |
| Gate returns allow when it should deny | Invalid feature ID skipped by gate logic | Test gate.py directly |
| Hook fires but agent ignores output | Advisory only (exit 0), not blocking (exit 2) | Check hook exit code |

## Key Principle

**Evidence over assumptions.** Never say "the hook fired" or "the gate blocked" without showing the log entry that proves it. The JSONL is the ground truth for what happened in a session.
