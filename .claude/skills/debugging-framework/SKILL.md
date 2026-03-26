---
name: debugging-framework
description: >
  Investigate why the framework didn't behave as expected. Traces actual events
  across sessions, hooks, settings, and state files. Use when user says "why
  did this happen", "trace what happened", "investigate", "debug the workflow",
  "hooks didn't fire", "check the logs", "what went wrong", or describes
  unexpected framework behavior (skipped gates, missing artifacts, wrong
  workflow path). Do NOT use for: code bugs (use fixing-bugs), codebase
  exploration (use exploring-codebase), feature implementation (use
  implementing-features).
compatibility: "Requires Claude Code with shell access."
allowed-tools: [Read, Bash, Glob, Grep, Agent]
metadata:
  author: agentic-framework
  version: "0.73.1"
---
# Debugging Framework Behavior

Systematic investigation when the framework doesn't behave as expected.
Do NOT guess or assume — trace actual evidence, then report findings.

## Step 1: Identify what should have happened

Before investigating, establish the expected behavior:
- What workflow rule was violated? (Check CLAUDE.md, memory-seed, relevant skill)
- What gate/hook/script should have fired?
- What setting controls this behavior? (Check STACK.md `## Settings`, profiles.conf)

## Step 2: Trace actual events

Work from evidence, not assumptions. Check in this order:

### 2a. Session logs (what the agent actually did)
```bash
# List recent sessions
ls -lt /home/node/.claude/projects/-workspace/*.jsonl | head -10

# Search a session for specific events
grep -a "ExitPlanMode\|EnterPlanMode\|tool_use\|tool_result" <session>.jsonl

# Extract conversation turns (skip progress events)
python3 -c "
import json
with open('<session>.jsonl') as f:
    for line in f:
        data = json.loads(line)
        if data.get('type') == 'progress': continue
        msg = data.get('message', {})
        role = msg.get('role', '')
        content = msg.get('content', [])
        if isinstance(content, list):
            for c in content:
                if c.get('type') == 'tool_use':
                    print(f'[{role}] TOOL: {c[\"name\"]}')
                elif c.get('type') == 'text':
                    print(f'[{role}] TEXT: {c[\"text\"][:200]}')
"
```

### 2b. Hook configuration (are hooks actually wired?)
```bash
# Check BOTH settings files for hooks section
python3 -c "import json; d=json.load(open('.claude/settings.local.json')); print('hooks' in d, list(d.keys()))"
python3 -c "import json; d=json.load(open('/home/node/.claude/settings.json')); print('hooks' in d, list(d.keys()))"
```

Hook scripts live in `.agentic/lib/hooks/shared/` but must be registered in
settings.json under a `hooks` key to actually fire. Scripts existing != hooks wired.

### 2c. State files (what artifacts exist on disk?)
```bash
# Plans: ephemeral vs durable
ls -la /home/node/.claude/plans/*.md                    # ephemeral (Claude Code)
ls -la .agentic/journal/plans/*-plan.md                 # durable (framework)

# Check plan status
grep '^\*\*Status\*\*:' .agentic/journal/plans/*-plan.md

# WIP / agent tracking
cat .agentic/session/AGENTS.json 2>/dev/null

# Settings that control behavior
bash .agentic/lib/tools/settings.sh list 2>/dev/null || grep -A20 '## Settings' STACK.md
```

### 2d. Hook scripts (what would they do IF wired?)
Read the relevant hook script to understand its logic:
- `on-plan-mode-exit.sh` — saves plan as DRAFT, outputs review instructions
- `on-code-edit.sh` — warns if editing code with unapproved DRAFT plan
- `pre-commit-check.sh` — blocks commits with DRAFT plans (check 21)

For each hook, determine:
1. Is the script registered in settings.json?
2. Does it have the right trigger event?
3. Would its conditions have been met? (e.g., does a DRAFT plan file exist?)

## Step 3: Build the event timeline

Construct a factual timeline with evidence for each entry:

```
[timestamp/order] EVENT — evidence source
---
1. Prior session: Agent entered plan mode — session log shows EnterPlanMode
2. Agent called ExitPlanMode — session log, last entry
3. Hook did NOT fire — no hooks section in settings.json
4. Plan saved to ~/.claude/plans/ only — file exists, journal/plans/ empty
5. This session: received continuation prompt — "Implement the following plan..."
6. Agent started editing — Edit tool calls in current session
```

Rules:
- Every claim needs a source (file path, log entry, setting value)
- "Did not happen" claims need evidence too (absence of log entry, missing file)
- Don't confuse "script exists" with "hook is registered and fired"
- Don't confuse "setting has a default" with "setting was explicitly read"

## Step 4: Identify root causes

Categorize each failure in the chain:

| Category | Example |
|----------|---------|
| **Not wired** | Hook script exists but not in settings.json |
| **Not triggered** | Hook is wired but conditions weren't met (e.g., no DRAFT file) |
| **Advisory only** | Hook fired but exit 0 (warn, don't block) |
| **Agent ignored** | Rule is in CLAUDE.md/memory but agent didn't follow it |
| **Missing enforcement** | No gate/hook/script exists for this scenario |

## Step 5: Report findings

Present:
1. **Expected behavior** — what should have happened, citing the rule source
2. **Actual timeline** — factual event chain with evidence
3. **Root causes** — categorized failures with specific gaps
4. **Fixes needed** — structural (hooks/gates/scripts) vs behavioral (instructions/memory)

Always distinguish structural fixes (can't be ignored) from behavioral fixes (agent
must choose to follow). Structural fixes are more reliable.
