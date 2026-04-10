"""
mcp_tool_defs.py — MCP inputSchema definitions for coordination tools.

Maps the 13 tool handlers in coord_tools.TOOLS to MCP-formatted tool
definitions with JSON Schema input specifications. Kept separate from
coord_tools.py so the shared handler layer stays transport-agnostic.

Maintenance: If a tool is added/removed/renamed in coord_tools.TOOLS,
update MCP_TOOL_DEFS to match. The structural test in test_mcp_server.py
validates that the keys stay in sync.
"""
from __future__ import annotations

from typing import Any


MCP_TOOL_DEFS: dict[str, dict[str, Any]] = {
    "claim_feature": {
        "description": "Atomically claim a feature for an agent. Rejects if already claimed.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "feature_id": {
                    "type": "string",
                    "description": "Feature ID (e.g., F-0042)",
                },
                "agent": {
                    "type": "string",
                    "description": "Agent identifier",
                },
                "description": {
                    "type": "string",
                    "description": "What the agent plans to do",
                },
                "pid": {
                    "type": "integer",
                    "description": "Agent process ID",
                },
            },
            "required": ["feature_id"],
        },
    },
    "release_feature": {
        "description": "Release a feature claim so another agent can work on it.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "feature_id": {
                    "type": "string",
                    "description": "Feature ID (e.g., F-0042)",
                },
                "pid": {
                    "type": "integer",
                    "description": "Agent process ID",
                },
            },
            "required": ["feature_id"],
        },
    },
    "transition_state": {
        "description": (
            "Transition a feature to a new workflow state. "
            "Review is always skipped via RPC to avoid blocking."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "feature_id": {
                    "type": "string",
                    "description": "Feature ID (e.g., F-0042)",
                },
                "target": {
                    "type": "string",
                    "description": "Target state name (e.g., implementing, shipped)",
                },
                "dry_run": {
                    "type": "boolean",
                    "description": "Check transition without applying",
                },
            },
            "required": ["feature_id", "target"],
        },
    },
    "get_unblocked": {
        "description": "Find all features with at least one available forward transition.",
        "inputSchema": {
            "type": "object",
            "properties": {},
        },
    },
    "poll_changes": {
        "description": "Check for changes to features or agents since a given timestamp.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "since": {
                    "type": "string",
                    "description": "ISO timestamp (e.g., 2026-04-09T12:00:00Z)",
                },
            },
        },
    },
    "report_status": {
        "description": "Agent reports progress on a claimed feature.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "feature_id": {
                    "type": "string",
                    "description": "Feature ID (e.g., F-0042)",
                },
                "note": {
                    "type": "string",
                    "description": "Progress note",
                },
            },
            "required": ["feature_id", "note"],
        },
    },
    "request_review": {
        "description": "Submit a feature for review (creates pending review entry).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "feature_id": {
                    "type": "string",
                    "description": "Feature ID",
                },
                "from_state": {
                    "type": "string",
                    "description": "Current state",
                },
                "to_state": {
                    "type": "string",
                    "description": "Target state",
                },
                "review_mode": {
                    "type": "string",
                    "enum": ["human", "critical_agent", "skip"],
                    "description": "Review mode (default: human)",
                },
            },
            "required": ["feature_id", "from_state", "to_state"],
        },
    },
    "submit_review": {
        "description": "Submit a review verdict (approve or reject) for a pending review.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "feature_id": {
                    "type": "string",
                    "description": "Feature ID",
                },
                "target_state": {
                    "type": "string",
                    "description": "State being reviewed",
                },
                "verdict": {
                    "type": "string",
                    "enum": ["approved", "rejected"],
                    "description": "Review verdict",
                },
                "reasoning": {
                    "type": "string",
                    "description": "Reason for verdict",
                },
            },
            "required": ["feature_id", "target_state", "verdict"],
        },
    },
    # -----------------------------------------------------------------
    # Task delegation tools (context-optimized subagent spawning)
    # -----------------------------------------------------------------
    "list_acs": {
        "description": "List acceptance criteria for a feature with completion status from progress tracking.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "feature_id": {
                    "type": "string",
                    "description": "Feature ID (e.g., F-0042)",
                },
            },
            "required": ["feature_id"],
        },
    },
    "get_task_brief": {
        "description": (
            "Assemble focused context for a subagent about to work on a feature or AC. "
            "Returns role-specific context, AC text, plan summary, and prior progress notes."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "feature_id": {
                    "type": "string",
                    "description": "Feature ID (e.g., F-0042)",
                },
                "ac_id": {
                    "type": "string",
                    "description": "Specific acceptance criterion ID (e.g., AC-001)",
                },
                "role": {
                    "type": "string",
                    "description": "Agent role for context assembly (default: implementation-agent)",
                },
                "component": {
                    "type": "string",
                    "description": "Scope context to a specific component",
                },
            },
            "required": ["feature_id"],
        },
    },
    "save_progress": {
        "description": "Persist subagent results for a feature/AC. Survives across subagent boundaries and context compactions.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "feature_id": {
                    "type": "string",
                    "description": "Feature ID (e.g., F-0042)",
                },
                "ac_id": {
                    "type": "string",
                    "description": "Acceptance criterion ID (e.g., AC-001)",
                },
                "status": {
                    "type": "string",
                    "enum": ["passed", "failed", "partial", "note"],
                    "description": "Result status",
                },
                "note": {
                    "type": "string",
                    "description": "Progress note describing what was done",
                },
                "files_changed": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "List of files modified",
                },
            },
            "required": ["feature_id"],
        },
    },
    "get_next_action": {
        "description": (
            "Determine the next action for a feature based on state machine and progress. "
            "Returns: implement_ac, verify, create_pr, done, or blocked."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "feature_id": {
                    "type": "string",
                    "description": "Feature ID (e.g., F-0042)",
                },
            },
            "required": ["feature_id"],
        },
    },
    "get_delegation_prompt": {
        "description": (
            "Build a complete, self-contained prompt for delegating an AC to a subagent via the Agent tool. "
            "Returns the prompt text, recommended model, and worktree preference."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "feature_id": {
                    "type": "string",
                    "description": "Feature ID (e.g., F-0042)",
                },
                "ac_id": {
                    "type": "string",
                    "description": "Acceptance criterion ID to implement (e.g., AC-001)",
                },
                "role": {
                    "type": "string",
                    "description": "Agent role for context assembly (default: implementation-agent)",
                },
            },
            "required": ["feature_id", "ac_id"],
        },
    },
}


def get_tool_definitions() -> list[dict]:
    """Return MCP-formatted tool definitions for tools/list response."""
    tools = []
    for name, defn in MCP_TOOL_DEFS.items():
        tools.append({
            "name": name,
            "description": defn["description"],
            "inputSchema": defn["inputSchema"],
        })
    return tools
