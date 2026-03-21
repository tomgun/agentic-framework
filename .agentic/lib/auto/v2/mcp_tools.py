"""
mcp_tools.py — MCP tool definitions and handlers for the agentic framework.

Each tool wraps an existing v2 workflow command, providing structured
input/output for MCP clients. All handlers take (project_root, params)
and return a dict result.
"""
from __future__ import annotations

import io
import json
import sys
from pathlib import Path
from typing import Any


def _capture_stdout(fn, *args, **kwargs) -> tuple[int, str]:
    """Run a function that prints to stdout and capture the output."""
    old_stdout = sys.stdout
    sys.stdout = buf = io.StringIO()
    old_stderr = sys.stderr
    sys.stderr = err_buf = io.StringIO()
    try:
        rc = fn(*args, **kwargs)
    except SystemExit as e:
        rc = e.code if isinstance(e.code, int) else 1
    finally:
        sys.stdout = old_stdout
        sys.stderr = old_stderr
    return rc, buf.getvalue() + err_buf.getvalue()


# ---------------------------------------------------------------------------
# Tool handlers
# ---------------------------------------------------------------------------


def handle_ag_status(project_root: Path, params: dict) -> dict:
    """List active work items and states."""
    from .workflow import cmd_status
    rc, output = _capture_stdout(cmd_status, project_root, params.get("args", []))
    return {"success": rc == 0, "output": output.strip()}


def handle_ag_transition(project_root: Path, params: dict) -> dict:
    """Advance feature to next state."""
    feature_id = params.get("feature_id")
    target_state = params.get("target_state")
    if not feature_id or not target_state:
        return {"success": False, "error": "feature_id and target_state are required"}

    args = [feature_id, target_state]
    reason = params.get("reason")
    if reason:
        args.extend(["--reason", reason])

    from .workflow import cmd_transition
    rc, output = _capture_stdout(cmd_transition, project_root, args)
    return {"success": rc == 0, "output": output.strip()}


def handle_ag_check(project_root: Path, params: dict) -> dict:
    """Validate artifacts for a feature."""
    feature_id = params.get("feature_id")
    args = []
    if feature_id:
        args.append(feature_id)
    else:
        args.append("--active")

    if params.get("quick"):
        args.append("--quick")

    from .workflow import cmd_check
    rc, output = _capture_stdout(cmd_check, project_root, args)
    return {"success": rc == 0, "output": output.strip()}


def handle_ag_verify(project_root: Path, params: dict) -> dict:
    """Run verification commands."""
    feature_id = params.get("feature_id")
    if not feature_id:
        return {"success": False, "error": "feature_id is required"}

    from .workflow import cmd_verify
    rc, output = _capture_stdout(cmd_verify, project_root, [feature_id])
    return {"success": rc == 0, "output": output.strip()}


def handle_ag_read_artifact(project_root: Path, params: dict) -> dict:
    """Read a specific artifact file from .agentic/work/F-XXXX/."""
    feature_id = params.get("feature_id")
    artifact_name = params.get("artifact_name")
    if not feature_id or not artifact_name:
        return {"success": False, "error": "feature_id and artifact_name are required"}

    from . import work_items

    # Security: validate feature_id format and artifact_name
    import re
    if not re.match(r"^F-\d{4,}$", feature_id):
        return {"success": False, "error": "Invalid feature_id format"}
    # Prevent path traversal
    if "/" in artifact_name or "\\" in artifact_name or ".." in artifact_name:
        return {"success": False, "error": "Invalid artifact_name"}

    artifact_path = work_items.item_dir(project_root, feature_id) / artifact_name
    if not artifact_path.exists():
        return {"success": False, "error": f"Artifact not found: {artifact_name}"}

    try:
        content = artifact_path.read_text()
        return {"success": True, "content": content, "path": str(artifact_path)}
    except Exception as e:
        return {"success": False, "error": str(e)}


# ---------------------------------------------------------------------------
# Tool definitions (MCP format)
# ---------------------------------------------------------------------------

MCP_TOOLS: dict[str, dict[str, Any]] = {
    "ag_status": {
        "description": "List active work items and their current states",
        "inputSchema": {
            "type": "object",
            "properties": {
                "args": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Optional args (e.g., ['--all'])",
                },
            },
        },
        "handler": handle_ag_status,
    },
    "ag_transition": {
        "description": "Advance a feature to the next workflow state",
        "inputSchema": {
            "type": "object",
            "properties": {
                "feature_id": {"type": "string", "description": "Feature ID (e.g., F-0042)"},
                "target_state": {"type": "string", "description": "Target state name"},
                "reason": {"type": "string", "description": "Reason for transition"},
            },
            "required": ["feature_id", "target_state"],
        },
        "handler": handle_ag_transition,
    },
    "ag_check": {
        "description": "Validate artifacts for a feature's current or next state",
        "inputSchema": {
            "type": "object",
            "properties": {
                "feature_id": {"type": "string", "description": "Feature ID (omit for auto-detect)"},
                "quick": {"type": "boolean", "description": "Quick mode: file-existence only"},
            },
        },
        "handler": handle_ag_check,
    },
    "ag_verify": {
        "description": "Run verification commands and record results",
        "inputSchema": {
            "type": "object",
            "properties": {
                "feature_id": {"type": "string", "description": "Feature ID"},
            },
            "required": ["feature_id"],
        },
        "handler": handle_ag_verify,
    },
    "ag_read_artifact": {
        "description": "Read a specific artifact file from a feature's work directory",
        "inputSchema": {
            "type": "object",
            "properties": {
                "feature_id": {"type": "string", "description": "Feature ID (e.g., F-0042)"},
                "artifact_name": {"type": "string", "description": "Artifact filename (e.g., plan.md, spec.md)"},
            },
            "required": ["feature_id", "artifact_name"],
        },
        "handler": handle_ag_read_artifact,
    },
}


def get_tool_definitions() -> list[dict]:
    """Return MCP-formatted tool definitions (without handlers)."""
    tools = []
    for name, tool in MCP_TOOLS.items():
        tools.append({
            "name": name,
            "description": tool["description"],
            "inputSchema": tool["inputSchema"],
        })
    return tools
