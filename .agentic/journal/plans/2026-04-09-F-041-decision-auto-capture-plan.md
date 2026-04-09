# Plan: User Decision & Instruction Auto-Capture Pipeline

## Context

The framework has excellent **storage** infrastructure (cerebrum.yaml, patterns.yaml, journal.sh --decision) and **surfacing** infrastructure (phase-aware queries, prompt-context injection). But nothing **populates** these stores automatically. Everything depends on the agent manually calling `ag intel remember`, which is behavioral-only and easily forgotten.

**Problem scenarios:**
1. User says "always use snake_case" -- stays in conversation, lost next session
2. Framework suggests Redis, user says "yes" -- the decision "use Redis" is never captured
3. User runs `ag set acceptance_criteria blocking` -- no record of WHO decided or WHY
4. User corrects agent: "no, don't push to main" -- should become an enforced pattern, not just a memory

**Goal:** Make user decisions, instructions, and confirmations flow automatically into the framework's durable intelligence stores (cerebrum.yaml, patterns.yaml, journal.md) -- NOT Claude's local MEMORY.md.

This is **enhancement of F-041 (Intelligence Engine)**, not a new feature.

---

## Implementation Plan

### Phase 1: Enhance `_intel_remember` with provenance tracking
**File:** `.agentic/lib/tools/commands/intel.sh` (modify `_intel_remember`, ~line 466)

Add two new optional flags:
- `--source <manual|user_prompt|agent_capture|settings_change|session_audit>` (default: `manual`)
- `--session <id>` (auto-read from `.agentic/session/.current-session-id` if not provided)

Extend the YAML entry to include these fields:
```yaml
  - id: C-0005
    type: decision
    text: "Use PostgreSQL for the data layer"
    context: "User confirmed architecture recommendation"
    source: agent_capture
    session: f09ddd24
    date: 2026-04-09
```

Also add journal auto-logging: when type is `decision`, automatically call `journal.sh --decision` with the text. This dual-writes decisions to both cerebrum (structured) and journal (chronological).

**Why:** Provenance tracking answers "when was this captured, how, and in what session" -- the traceability requirement.

### Phase 2: UserPromptSubmit signal detection + decision buffer
**File:** `.agentic/lib/claude-hooks/UserPromptSubmit.sh` (add after line 212, before prompt-context call)

Add four signal detectors using `$USER_PROMPT` regex matching:

**Signal A -- Instructions** (highest confidence):
```bash
# "always X", "never Y", "from now on", "don't ever", "make sure to", "rule:", "I want you to"
grep -qiE '(^|\b)(always|never|don.t ever|from now on|going forward|make sure to|I want you to|rule:|convention:)\b'
```
Action: Write to `.agentic/session/decision-buffer.log`, inject nudge:
```
📝 INSTRUCTION DETECTED — Capture: `ag intel remember "..." --type preference`
   Or if this should be enforced: `ag intel learn "..." --reason "user instruction" --scope "*.py"`
```

**Signal B -- Decisions** (high confidence):
```bash
# "let's go with X", "I decide", "use X instead of Y", "go with", "I prefer"
grep -qiE '(^|\b)(let.s (go|use|stick) with|I decide|we.ll use|I prefer|use .* instead of|go with|decision:)\b'
```
Action: Buffer + nudge with `--type decision`.

**Signal C -- Corrections** (high confidence):
```bash
# "no,", "stop,", "wrong", "that's not", "actually,", "not like that"
grep -qiE '^(no[,. ]|stop[,. ]|wrong|that.s not|I said|actually[,. ]|not like that|I meant)\b'
```
Action: Buffer + nudge with `--type learning`.

**Signal D -- Confirmations** (needs context from pending-decision file):
```bash
# "yes", "yeah", "ok", "approved", "go ahead", "do it", "sounds good", "proceed"
grep -qiE '^\s*(yes|yeah|yep|ok|okay|sure|approved?|go ahead|do it|sounds good|lgtm|confirmed?|proceed|ship it|that works|👍)\s*[.!]?\s*$'
```
Action: Check `.agentic/session/pending-decision.txt`. If exists, resolve it:
```
📝 DECISION CONFIRMED: "[pending decision text]"
   Capture: `ag intel remember "..." --type decision --context "confirmed recommendation"`
```
If no pending-decision file, do nothing (bare "yes" without context is noise).

**Decision buffer format** (`.agentic/session/decision-buffer.log`, append-only):
```
TIMESTAMP|signal_type|first_200_chars_of_prompt
```

**Performance budget:** All four checks share a single `case` statement pattern; total adds ~5ms (well within 3s timeout).

### Phase 3: Pending-decision protocol (agent + PostToolUse)

**Concept:** Before the agent presents a choice to the user, it writes a one-liner to `.agentic/session/pending-decision.txt`. When the user confirms, UserPromptSubmit (Signal D) resolves it. When the agent acts without explicit confirmation, PostToolUse resolves it.

**3a. Agent protocol -- behavioral layer**
**Files:** `.agentic/lib/init/memory-seed.md`, `.agentic/lib/agents/claude/CLAUDE.md`

Add to the "User correction" bullet area:
```
- Proposing a choice: Before presenting a recommendation or asking for confirmation,
  write a one-liner: `echo "Use Redis for caching" > .agentic/session/pending-decision.txt`
  The framework auto-detects "yes"/"ok" responses and captures the full decision.
```

**3b. PostToolUse resolution -- structural layer**
**File:** `.agentic/lib/claude-hooks/PostToolUse.sh` (add after token tracking, ~line 50)

When the agent uses Write/Edit/Bash after a pending-decision exists:
1. Read `.agentic/session/pending-decision.txt`
2. Append to decision-buffer.log: `TIMESTAMP|action_confirmed|PENDING_TEXT`
3. Delete pending-decision.txt
4. Emit: `📝 Decision enacted: "[pending text]". Logged to decision buffer.`

This catches the case where user says "yes" and agent immediately starts implementing -- the decision is captured even if Signal D was missed.

**Timeout safety:** Reading a one-line file + appending one line = sub-millisecond. Well within PostToolUse's 2s budget.

### Phase 4: Settings change auto-logging
**File:** `.agentic/lib/tools/commands/settings.sh` (modify `_settings_set_value`, after line 213)

After the existing `echo "Set ${key} = ${value}"`:

1. **Capture old value** (add at top of function, before the write):
   ```bash
   local old_value
   old_value=$(get_setting "$key" "" 2>/dev/null || echo "")
   ```

2. **Auto-create cerebrum entry for mode-affecting settings:**
   ```bash
   case "$key" in
     profile|acceptance_criteria|wip_before_commit|docs_gate|git_workflow|main_branch_mode|plan_review_enabled|docs_mode|pre_commit_checks|smoke_test_evidence)
       bash "$ROOT_DIR/.agentic/lib/tools/ag.sh" intel remember \
         "Changed $key from '${old_value:-unset}' to '$value'" \
         --type decision \
         --context "ag set $key $value" \
         --source settings_change 2>/dev/null || true
       ;;
   esac
   ```

3. **Auto-journal for profile changes** (these are significant workflow shifts):
   ```bash
   if [[ "$key" == "profile" ]]; then
     bash "$ROOT_DIR/.agentic/lib/tools/journal.sh" \
       "Profile Change" "Switched from ${old_value:-discovery} to $value" \
       "Settings cascade applied" "None" \
       --decision "Changed project profile to $value" 2>/dev/null || true
   fi
   ```

### Phase 5: Session-end decision audit (Stop.sh)
**File:** `.agentic/lib/claude-hooks/Stop.sh` (add after intel finalization ~line 183, before sentinel cleanup)

Sweep the decision buffer for uncaptured decisions:

```bash
# --- Decision buffer audit (F-041: Auto-capture pipeline) ---
_DB_FILE=".agentic/session/decision-buffer.log"
if [[ -f "$_DB_FILE" ]]; then
  _DB_COUNT=$(wc -l < "$_DB_FILE" 2>/dev/null || echo 0)
  _DB_COUNT="${_DB_COUNT## }"; _DB_COUNT="${_DB_COUNT%% }"
  
  # Count cerebrum mutations this session
  _DB_CAPTURES=$(_il_int grep -c '|mutate|' "$_IL_EVENTS" 2>/dev/null || echo 0) 2>/dev/null || _DB_CAPTURES=0
  
  if [[ "${_DB_COUNT:-0}" -gt 0 && "${_DB_CAPTURES:-0}" -lt "${_DB_COUNT:-0}" ]]; then
    echo "⚠️  ${_DB_COUNT} decision signals detected, ${_DB_CAPTURES} captured to cerebrum." >&2
    echo "   Review: cat .agentic/session/decision-buffer.log" >&2
    echo "   Batch capture: ag intel batch-remember --from-buffer" >&2
  fi
  
  # Clean up buffer
  rm -f "$_DB_FILE" 2>/dev/null || true
fi

# Clean up pending decision
rm -f .agentic/session/pending-decision.txt 2>/dev/null || true
```

### Phase 6: `ag intel batch-remember` and `ag intel decisions`
**File:** `.agentic/lib/tools/commands/intel.sh`

**6a.** `_intel_batch_remember` -- reads decision-buffer.log, creates cerebrum entries:
```bash
_intel_batch_remember() {
    local source="session_audit"
    # Read buffer, create one cerebrum entry per line
    while IFS='|' read -r timestamp signal_type prompt_text; do
      local ctype="preference"
      case "$signal_type" in
        instruction) ctype="preference" ;;
        decision|confirmation|action_confirmed) ctype="decision" ;;
        correction) ctype="learning" ;;
      esac
      _intel_remember "$prompt_text" --type "$ctype" --context "auto-captured from $signal_type signal" --source "$source"
    done < "$DECISION_BUFFER_FILE"
}
```

**6b.** `_intel_decisions` -- lists all decisions with provenance:
```bash
_intel_decisions() {
    _intel_cerebrum --type decision
    # Also show recent journal decisions
    echo ""
    echo "--- Journal decisions (last 10) ---"
    grep "Decision:" "$JOURNAL_FILE" | tail -10
}
```

### Phase 7: Instruction files update
**Files to update** (framework-dev requirement):
- `.agentic/lib/init/memory-seed.md` -- pending-decision protocol, updated trigger table
- `.agentic/lib/agents/claude/CLAUDE.md` -- add pending-decision protocol
- Root `CLAUDE.md` -- add pending-decision protocol for dogfooding
- `.claude/skills/implementing-features.md` -- remind to capture decisions during implementation
- `.claude/skills/planning-features.md` -- remind to capture decisions during planning

---

## Critical Files

| File | Change | Lines |
|------|--------|-------|
| `.agentic/lib/tools/commands/intel.sh` | Add --source/--session to _intel_remember, add batch-remember + decisions | ~466-554 |
| `.agentic/lib/claude-hooks/UserPromptSubmit.sh` | Add 4 signal detectors + decision buffer writes | After ~212 |
| `.agentic/lib/claude-hooks/PostToolUse.sh` | Add pending-decision resolution | After ~50 |
| `.agentic/lib/claude-hooks/Stop.sh` | Add decision buffer audit + cleanup | After ~183 |
| `.agentic/lib/tools/commands/settings.sh` | Add audit trail to _settings_set_value | ~59-213 |
| `.agentic/lib/init/memory-seed.md` | Add pending-decision protocol | ~line 24 |
| `.agentic/lib/agents/claude/CLAUDE.md` | Add pending-decision protocol | session/workflow section |

## Reuse

- `_intel_remember` (intel.sh:466) -- existing function, extended with --source/--session
- `_intel_log` (intel.sh) -- existing event logging, reused for buffer events
- `journal.sh --decision` -- existing decision flag, auto-invoked from remember
- `btrace` (btrace.sh) -- existing telemetry, add decision signal events
- `flog` (fwlog.sh) -- existing framework log, settings audit reuses
- Decision buffer uses same append-only pattern as `token-events.log`

## Verification

1. **Unit test:** `ag intel remember "test" --type decision --source settings_change --session abc123` creates correctly formatted cerebrum entry
2. **Hook test:** Set `CLAUDE_USER_PROMPT="never push to main"` and run UserPromptSubmit.sh -- should see instruction signal in stdout and decision-buffer.log
3. **Settings audit:** Run `ag set acceptance_criteria blocking` -- should auto-create cerebrum entry
4. **Pending-decision flow:** Write to pending-decision.txt, set `CLAUDE_USER_PROMPT="yes"`, run UserPromptSubmit.sh -- should see confirmation resolution
5. **Stop sweep:** Create decision-buffer.log with entries, run Stop.sh -- should see uncaptured warning
6. **End-to-end:** In a real session, say "never push to main" -- verify cerebrum.yaml has the entry, verify it surfaces in next session's prompt-context
7. **validate_framework.sh** must pass
