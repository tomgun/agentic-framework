# Plan: MCP Transport for Coordination Server (F-018)

**Status**: APPROVED

**Review**: Dialectical review completed 2026-04-09. Critic + Advocate converged. Two critical issues incorporated (stdout capture, MCP isError pattern). See revision guidance below.

## Context

The coordination server (F-018) already has 8 well-defined tool handlers in `coord_tools.py`, served over HTTP JSON-RPC via `coord_server.py`. F-018 AC-002 says: "MCP protocol server wraps existing coord tools for tool-native agent integration." The MCP server is a **second transport** — stdio-based MCP — for the same coordination tools. No new tool logic needed.

A previous v2-era MCP server (`agentic-tests/*/lib/auto/v2/mcp_server.py`) has clean, reusable JSON-RPC 2.0 protocol handling we can adapt.

**Architecture:**
```
coord_tools.py (8 tool handlers — shared layer)
    ├── coord_server.py (HTTP JSON-RPC transport, port 4185, bearer auth)  ← exists
    └── mcp_server.py  (MCP stdio transport, per MCP spec)                 ← new
```

**Why MCP transport matters for coordination:**
- Agents in MCP-capable IDEs (Cursor, Windsurf, VS Code) get native tool access to claim features, report status, poll changes, submit reviews — without HTTP client boilerplate
- Multi-agent orchestration becomes tool-native: agent calls `claim_feature` as a tool, not via curl/HTTP
- IDE shows coordination tools in the agent's tool list with structured input schemas

---

## Phase 1: MCP Coordination Server (F-018 AC-002) — 3 new files

### 1. `.agentic/lib/auto/mcp_server.py` (~200 lines)

Adapt protocol handling from `agentic-tests/algebra-rush/.agentic/lib/auto/v2/mcp_server.py`:

- Same `MCPServer` class: `handle_message()`, `_handle_initialize()`, `_handle_tools_list()`, `_handle_tools_call()`, `run_stdio()`
- Same JSON-RPC 2.0 helpers: `_jsonrpc_success()`, `_jsonrpc_error()`
- Same constants: `PROTOCOL_VERSION = "2024-11-05"`, error codes
- **Key change**: Import tools from `coord_tools.py` (sibling module) instead of deleted v2 modules
- `_handle_tools_call()` dispatches to `coord_tools.TOOLS[name](project_root, params)` with **stdout/stderr capture** (see Revision Guidance below)
- `_handle_tools_list()` returns MCP-formatted tool definitions from `mcp_tool_defs.py`
- `_resolve_project_root()` — reuse from `coord_server.py` (git-based + env var + walk-up)
- Entry point: `if __name__ == "__main__": main()`
- **Signal handlers**: SIGTERM/SIGINT for clean exit; catch BrokenPipeError on stdout writes
- **Logging to stderr**: startup (project_root), each tool call (method name), exceptions (traceback)
- **Intentionally single-threaded**: document that coord_tools handlers are NOT thread-safe; MCP stdio processes one message at a time

### 2. `.agentic/lib/auto/mcp_tool_defs.py` (~120 lines)

MCP `inputSchema` definitions for the 8 coord tools. Separate file keeps `coord_tools.py` unchanged.

Tools exposed: `claim_feature`, `release_feature`, `transition_state`, `get_unblocked`, `poll_changes`, `report_status`, `request_review`, `submit_review`.

### 3. `.agentic/lib/auto/mcp_start.sh` (~25 lines)

Shell entry point for MCP clients (Cursor, Windsurf, etc.):
- Resolve `PROJECT_ROOT` (walk up for `.agentic/`, fall back to cwd)
- Find `python3` or `python`, exit with clear error if missing
- Set `PYTHONPATH` to include `.agentic/lib`
- `exec "$PYTHON" "$PROJECT_ROOT/.agentic/lib/auto/mcp_server.py"`

---

## Phase 2: Lifecycle Commands (F-018 AC-003) — 2 files modified

### 1. `.agentic/lib/tools/commands/operations.sh` — add `cmd_mcp()` (~40 lines)

Follow `cmd_coord()` pattern (lines 497-527):
- `ag mcp start` → runs MCP server in foreground (stdio, for testing/headless)
- `ag mcp status` → capability check: verifies mcp_server.py exists and Python available (NOT a process check — stdio has no daemon)
- `ag mcp --help` → usage text with IDE setup instructions
- No `stop` needed — stdio servers terminate when client closes stdin

### 2. `.agentic/lib/tools/ag.sh` — add `mcp)` dispatch case after `coord)`

---

## Phase 3: Cursor Wiring (F-018 scope, not F-025) — 2 files modified

### 1. `.agentic/lib/agents/cursor/mcp.json` — populate with `agentic-coord` server entry
### 2. `.agentic/lib/tools/setup-agent.sh` — enhance `cursor-mcp` subcommand (opt-in)

---

## Phase 4: Tests + Contract Updates — 3 files

### 1. `tests/test_mcp_server.py` — unit tests for MCP protocol + tool dispatch
- MCP handshake (initialize → serverInfo)
- `tools/list` returns 8 tool definitions
- `tools/call` dispatches correctly (mock coord_tools.TOOLS)
- Tool errors use `isError: true` in content, NOT JSON-RPC errors
- Protocol errors (unknown method, invalid JSON) use JSON-RPC errors
- `notifications/initialized` returns None
- **Structural**: `mcp_tool_defs` keys match `coord_tools.TOOLS` keys

### 2. `tests/validate_framework.sh` — structural assertions
### 3. `.agentic/spec/contracts/F-018.yaml` — update AC-002/003/004 status
- AC-003: note that "stop" is N/A for stdio transport; `start` + `status` fulfill the lifecycle intent

---

## Key Decisions

1. **Same tool layer, different transport**: `coord_tools.py` shared, MCP server imports same handlers
2. **Location**: `.agentic/lib/auto/mcp_server.py` alongside `coord_server.py`
3. **No daemon**: stdio-only, IDE launches/terminates
4. **Opt-in**: `setup-agent.sh cursor-mcp`, not default
5. **8 tools**: Exactly the existing coordination tools, no CLI wrappers

---

## Revision Guidance (from dialectical review)

### CRITICAL — incorporated into plan above

**RG-1: Stdout capture around tool handler calls.**
coord_tools handlers import CLI modules (agents_helpers, state_machine, review) that may print() to stdout. Any stdout output corrupts the MCP JSON-RPC stream. Solution: wrap every `coord_tools.TOOLS[name]()` call with stdout/stderr capture (redirect to StringIO, route captured output to stderr for diagnostics). Reuse the `_capture_stdout()` pattern from deleted `v2/mcp_tools.py` lines 17-34.

**RG-2: MCP `isError` content pattern for tool failures.**
Per MCP spec, tool execution failures return a successful JSON-RPC response with `isError: true` in the content array — NOT a JSON-RPC error. JSON-RPC errors are reserved for protocol-level problems (unknown method, parse error). Implementation:
- Tool exception → `_jsonrpc_success(req_id, {"content": [{"type": "text", "text": str(e)}], "isError": True})`
- Unknown tool → `_jsonrpc_error(req_id, METHOD_NOT_FOUND, ...)`

### IMPORTANT — also incorporated

**RG-3**: Log to stderr (startup with project_root, each tool call, exceptions with traceback).
**RG-4**: Signal handlers (SIGTERM/SIGINT → clean exit) + BrokenPipeError on stdout writes.
**RG-5**: Phase 3 is F-018 scope (Cursor wiring of coordination MCP), not F-025.
**RG-6**: `ag mcp status` is a capability check (files exist + Python available), not a process check.
**RG-7**: Structural test that `mcp_tool_defs` keys == `coord_tools.TOOLS` keys (catches drift).

---

## Verification

1. `bash tests/validate_framework.sh` — structural assertions pass
2. `python3 tests/test_mcp_server.py` — unit tests pass
3. Smoke test:
   ```bash
   echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | \
     python3 .agentic/lib/auto/mcp_server.py
   # → serverInfo with "agentic-coord"

   echo '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' | \
     python3 .agentic/lib/auto/mcp_server.py
   # → 8 tool definitions
   ```
4. `ag mcp status` — reports availability
5. `ag contract check F-018` — AC-002/003/004 pass

---

## Critical Reference Files

| File | Purpose |
|---|---|
| `.agentic/lib/auto/coord_server.py` | Existing HTTP transport — parallel to new MCP transport |
| `.agentic/lib/auto/coord_tools.py` | 8 tool handlers to expose via MCP (shared, not modified) |
| `agentic-tests/algebra-rush/.agentic/lib/auto/v2/mcp_server.py` | Reuse JSON-RPC 2.0 protocol handling |
| `agentic-tests/algebra-rush/.agentic/lib/auto/v2/mcp_tools.py:17-34` | Reuse `_capture_stdout()` pattern |
| `.agentic/lib/tools/commands/operations.sh:497-527` | `cmd_coord()` pattern for `cmd_mcp()` |
| `.agentic/lib/tools/ag.sh:326-329` | Dispatch insertion point (after `coord)`) |
| `.agentic/lib/agents/cursor/mcp.json` | Cursor MCP template to populate |
| `.agentic/lib/tools/setup-agent.sh` | `cursor-mcp` subcommand to enhance |
| `.agentic/spec/contracts/F-018.yaml` | ACs to fulfill (AC-002, AC-003, AC-004) |
