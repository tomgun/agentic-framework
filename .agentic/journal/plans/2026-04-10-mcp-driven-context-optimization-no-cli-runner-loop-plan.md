# MCP-Driven Context Optimization — No CLI Runner Loop

## Context

**Problem**: Long-running Claude Code sessions exhaust context windows. The current workaround is external "CLI loops" — bash scripts or Python orchestrators (`ag auto task/epic`) that repeatedly invoke `claude --print` as subprocesses to get fresh context per unit of work. This works but:
- Requires an external process (Python scheduler, bash loop)
- Only works in CLI mode, not desktop/web/IDE
- Adds process management overhead (PID tracking, timeout enforcement, stdout capture)
- Users without `ag auto` resort to third-party CLI loop tools

**Insight**: Claude Code's native **Agent tool** already spawns subagents with fresh context windows. The existing **MCP coordination server** (F-018, just shipped) can provide persistent state across subagent boundaries. Together, they eliminate external CLI loops entirely.

**Scope**: Interactive sessions (primary) + autonomous pipeline (secondary). Parent-only MCP access — subagents focus on implementation, the orchestrator handles coordination.

---

## Architecture

```
Orchestrator (main Claude Code session — stays lean)
    │
    ├── MCP Server (agentic-coord, stdio)
    │   ├── 8 existing coordination tools (claim, release, transition, etc.)
    │   └── 5 NEW task-delegation tools (get_task_brief, list_acs, etc.)
    │
    └── Agent tool (native Claude Code)
        ├── Subagent 1: implement AC-001 (fresh context)
        ├── Subagent 2: implement AC-002 (fresh context)
        └── Subagent N: verify / create PR (fresh context)
```

**Key design decisions**:
1. **Always delegate implementation** to subagents (structural, not reactive to context pressure)
2. **Parent-only MCP** — orchestrator calls MCP tools, subagents get focused prompts and just code
3. **MCP server is the state bridge** — progress survives across subagent boundaries and compactions
4. **Backward compatible** — `ag auto` external pipeline continues to work; MCP tools are additive

---

## Phase 1: New MCP Tools for Task Delegation (5 tools)

Add to `coord_tools.py` + `mcp_tool_defs.py`. These are the bridge that makes delegation practical.

### 1.1 `list_acs` — List acceptance criteria with status
- **File**: `.agentic/lib/auto/coord_tools.py` (new function ~40 lines)
- **Input**: `{ feature_id: string }`
- **Output**: `{ criteria: [{ ac_id, text, status, attempts }], total, completed, pending }`
- **Implementation**: Parse contract YAML at `spec/contracts/F-XXXX.yaml`, cross-reference with progress file at `.agentic/session/progress/F-XXXX.json`
- **Why needed**: Orchestrator needs to know what to delegate without reading the full contract into context

### 1.2 `get_task_brief` — Assemble focused context for a subagent
- **File**: `.agentic/lib/auto/coord_tools.py` (new function ~60 lines)
- **Input**: `{ feature_id, ac_id?, role? (default "implementation-agent"), component? }`
- **Output**: `{ brief: string, ac_text, plan_summary, files_hint: string[], prior_notes: string[], token_estimate: int }`
- **Implementation**: Calls `context-for-role.sh` via subprocess, reads contract for AC text, reads progress notes. Returns assembled context (~5-10K tokens)
- **Why needed**: The orchestrator gets a ready-to-use prompt without loading all source files into its own context

### 1.3 `save_progress` — Persist subagent results
- **File**: `.agentic/lib/auto/coord_tools.py` (new function ~35 lines)
- **Input**: `{ feature_id, ac_id?, status: "passed"|"failed"|"partial"|"note", note, files_changed?: string[] }`
- **Output**: `{ recorded: bool, acs_completed, acs_remaining }`
- **Storage**: Appends to `.agentic/session/progress/F-XXXX.json` (JSON array of timestamped entries)
- **Why needed**: Results from subagents must survive after their context is gone. The orchestrator reads progress via MCP instead of keeping it all in context.

### 1.4 `get_next_action` — State-machine-driven routing
- **File**: `.agentic/lib/auto/coord_tools.py` (new function ~50 lines)
- **Input**: `{ feature_id }`
- **Output**: `{ action: "implement_ac"|"verify"|"create_pr"|"update_docs"|"done"|"blocked", details: { ac_id?, test_command?, reason? }, feature_state, acs_remaining }`
- **Implementation**: Reads state machine + progress file, determines what's next. Reuses `state_machine.py` logic.
- **Why needed**: The orchestrator doesn't need to hold the full workflow in context — just ask "what next?"

### 1.5 `get_delegation_prompt` — Complete prompt for Agent tool
- **File**: `.agentic/lib/auto/coord_tools.py` (new function ~70 lines)
- **Input**: `{ feature_id, ac_id, role? }`
- **Output**: `{ prompt: string, model_hint: "sonnet"|"opus"|"haiku", use_worktree: bool }`
- **Implementation**: Combines `get_task_brief` output with implementation instructions, test commands from STACK.md, and the specific AC. Returns a self-contained prompt ready to pass to `Agent()`.
- **Why needed**: Single MCP call → complete delegation. The orchestrator's code is just `Agent(prompt=result.prompt, model=result.model_hint)`.

### MCP Schema Definitions
- **File**: `.agentic/lib/auto/mcp_tool_defs.py` — Add 5 new entries to `MCP_TOOL_DEFS` dict
- **File**: `.agentic/lib/auto/coord_tools.py` — Add 5 new entries to `TOOLS` dispatch map
- The structural test in `test_mcp_server.py` already validates keys stay in sync

---

## Phase 2: Register MCP Server in Claude Code

### 2.1 Settings Template
- **File**: `.agentic/lib/auto/settings-template.json` — Add `mcpServers` section:
  ```json
  "mcpServers": {
    "agentic-coord": {
      "command": "bash",
      "args": [".agentic/lib/auto/mcp_start.sh"]
    }
  }
  ```

### 2.2 Init Script
- **File**: `.agentic/lib/auto/init.py` — `generate_settings()` includes `mcpServers` in output for all tiers
- Existing `ag auto init` already calls this, so MCP registration happens automatically

### 2.3 Progress Directory
- **File**: `.agentic/lib/auto/mcp_start.sh` — Ensure `.agentic/session/progress/` directory exists before starting server
- Add `progress/` to `.agentic/session/.gitignore` (session-scoped, not committed)

---

## Phase 3: Skill Enhancement — Auto-Delegation

### 3.1 Implementing-Features Skill
- **File**: `.claude/skills/implementing-features/SKILL.md` — Add delegation workflow section:

  When MCP `agentic-coord` tools are available and the feature has 2+ ACs:
  1. Call `list_acs(feature_id)` to get the AC list
  2. For each pending AC:
     a. Call `get_delegation_prompt(feature_id, ac_id)` → get prompt + model hint
     b. Call `Agent(prompt=..., model=...)` → subagent implements the AC
     c. After subagent returns, call `save_progress(feature_id, ac_id, status, note)`
     d. Call `get_next_action(feature_id)` → determine next step
  3. After all ACs: delegate verification to another subagent
  4. Create PR from the orchestrator (not delegated — needs user interaction)

  **Fallback**: If MCP tools unavailable, implement directly (current behavior). No breakage.

### 3.2 Session Continuity
- **File**: `.claude/skills/session-start/SKILL.md` — After dashboard, check for incomplete progress:
  - If `.agentic/session/progress/F-XXXX.json` exists with pending ACs, suggest continuing
  - Call `get_next_action(feature_id)` to pick up where left off

---

## Phase 4: Autonomous Pipeline Integration

### 4.1 TaskRunner Alternative Path
- **File**: `.agentic/lib/auto/task.py` — Add `_implement_ac_via_mcp()` as alternative to `_spawn_claude_implement()`
- When MCP server is running (detected via `coord_status`), use the same `get_delegation_prompt` tool to assemble context, then pass to `spawn_claude()` as before
- **Benefit**: Context assembly is centralized in MCP tools, not duplicated between interactive and autonomous paths
- The `spawn_claude()` call itself stays — the autonomous pipeline still needs external processes for parallel execution and timeout enforcement

### 4.2 Shared Progress Tracking
- Both interactive (via Agent tool) and autonomous (via spawn_claude) write to the same progress file format via `save_progress` MCP tool
- Enables seamless handoff: start autonomous, interrupt, continue interactively (or vice versa)

---

## Phase 5: Tests

### 5.1 Unit Tests for New Tools
- **File**: `tests/test_coord_server.py` — Add test cases for 5 new tools:
  - `test_list_acs_*` — with/without contract, with progress
  - `test_get_task_brief_*` — context assembly, component scoping
  - `test_save_progress_*` — recording, increment tracking
  - `test_get_next_action_*` — state routing logic
  - `test_get_delegation_prompt_*` — prompt assembly, model hints

### 5.2 MCP Structural Test
- **File**: `tests/test_mcp_server.py` — Existing test validates `MCP_TOOL_DEFS.keys() == TOOLS.keys()`. No change needed — it auto-covers new tools.

### 5.3 Integration Test
- **File**: `tests/test_auto_crunch.py` (or new `tests/test_delegation.py`) — End-to-end: create feature with ACs → list_acs → get_delegation_prompt → save_progress → get_next_action cycle

---

## Files Changed Summary

| File | Change |
|------|--------|
| `.agentic/lib/auto/coord_tools.py` | Add 5 handler functions + update TOOLS map (~250 lines) |
| `.agentic/lib/auto/mcp_tool_defs.py` | Add 5 inputSchema entries (~100 lines) |
| `.agentic/lib/auto/settings-template.json` | Add `mcpServers` block |
| `.agentic/lib/auto/init.py` | Include `mcpServers` in `generate_settings()` |
| `.agentic/lib/auto/mcp_start.sh` | Ensure progress directory exists |
| `.claude/skills/implementing-features/SKILL.md` | Add delegation workflow section |
| `.claude/skills/session-start/SKILL.md` | Add progress continuity check |
| `.agentic/lib/auto/task.py` | Add `_implement_ac_via_mcp()` alternative |
| `tests/test_coord_server.py` | Tests for 5 new tools |
| `tests/test_auto_crunch.py` or new test file | Integration test |

---

## Verification

1. **Unit tests**: `python -m pytest tests/test_coord_server.py tests/test_mcp_server.py -v`
2. **Framework validation**: `bash tests/validate_framework.sh`
3. **Manual MCP test**: Start MCP server (`ag mcp start`), send JSON-RPC calls for each new tool via stdin, verify responses
4. **Interactive test**: In a Claude Code session with MCP registered, say "implement F-XXXX" and verify the skill delegates to subagents via Agent tool
5. **Autonomous test**: Run `ag auto task F-XXXX` and verify it uses MCP for context assembly when server is running

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Agent tool subagents may not inherit MCP server access | Parent-only design: orchestrator calls MCP, passes results to subagent via prompt. No MCP dependency in subagents. |
| `context-for-role.sh` subprocess adds ~500ms latency in MCP handler | Acceptable for tool calls. Can optimize to Python later if needed. |
| Progress file corruption from concurrent writes | Existing `fcntl.flock` pattern from agents_helpers.py. Apply same pattern. |
| Skill instructions may be compressed out in long sessions | Core delegation loop is short (~5 MCP calls per AC). Constitution layer reminds to delegate. |
| Breaking change to settings-template.json | Additive only — `mcpServers` key is ignored by older Claude Code versions that don't support it. |
