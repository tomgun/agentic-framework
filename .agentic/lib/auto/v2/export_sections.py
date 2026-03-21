"""
export_sections.py — Shared content sections for generated instruction files.

Each section is a function returning a string, parameterized by project settings.
No template engine dependency — just Python f-strings.

Sections are composed by ExportGenerator based on per-tool adapter configs.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Optional


@dataclass
class ProjectSettings:
    """Project-specific settings extracted from config and STACK.md."""
    profile: str = "guided"
    mode: str = "formal"
    verification_commands: list[str] | None = None
    plan_review_enabled: bool = True
    conventions_path: str = ".agentic/conventions.md"


# ---------------------------------------------------------------------------
# Section functions — each returns a string block
# ---------------------------------------------------------------------------


def preamble() -> str:
    """Opening line establishing framework context."""
    return (
        "You are working in a repo that uses the agentic development "
        "framework (folder: .agentic/).\n\n"
        "Always consult: AGENTS.md (if present), CONTEXT_PACK.md, "
        ".agentic/STATUS.md, .agentic/spec/* as the source of truth."
    )


def session_start() -> str:
    """Dashboard protocol — Claude-only."""
    return (
        "## Session Start (do this FIRST on every new conversation)\n\n"
        "Run `bash .agentic/lib/tools/dashboard.sh 2>/dev/null` — "
        "ONE tool call, no others. Output the result verbatim as your "
        "first text response. No preamble, no narration, no reformatting.\n\n"
        "Always consult: AGENTS.md (if present), CONTEXT_PACK.md, "
        ".agentic/STATUS.md, .agentic/spec/* and .agentic/spec/adr/* "
        "as the source of truth."
    )


def workflow_commands() -> str:
    """Core ag commands list."""
    return (
        "## Workflow\n\n"
        "All work is managed by `ag` commands. The CLI enforces the "
        "workflow — never skip steps.\n\n"
        "- `ag start F-XXXX \"Title\"` — begin a new feature\n"
        "- `ag transition F-XXXX <state>` — advance the workflow "
        "(checks artifacts before proceeding)\n"
        "- `ag check F-XXXX` — validate artifacts\n"
        "- `ag verify F-XXXX` — run tests and record results\n"
        "- `ag ship F-XXXX` — prepare for shipping\n"
        "- `ag status` — see current work items\n"
        "- `ag info F-XXXX` — detailed info with next steps\n"
        "- `ag commit` | `ag done` | `ag merge <pr#> [F-XXXX]` | "
        "`ag flush` | `ag backlog` | `ag todo`\n"
        "- `ag auto task F-XXXX` | `ag auto epic F-XXXX` | "
        "`ag auto verify` | `ag auto crunch`\n"
        "- `ag export <tool>` — regenerate instruction files for AI tools"
    )


def artifacts() -> str:
    """Work directory convention."""
    return (
        "Write artifacts to `.agentic/work/F-XXXX/`: `plan.md`, "
        "`spec.md`, `review.md`, `journal.md`, `verification.json`. "
        "The CLI tells you what's missing."
    )


def trigger_words() -> str:
    """STOP table for cursor/copilot/codex (NOT Claude, which uses skills)."""
    return (
        "STOP! Trigger Words (match on intent, not just exact words):\n"
        "| User intent | Action |\n"
        "|-------------|--------|\n"
        "| Build / implement / add / create | STOP -> "
        '`ag start F-XXXX "Title"`, write plan, then '
        "`ag transition F-XXXX implementation` |\n"
        "| Build something large (>10 files) | STOP -> TOO BIG. "
        "Break into 3-5 smaller tasks. |\n"
        "| Fix / debug / repair / troubleshoot | STOP -> "
        "Write failing test FIRST |\n"
        "| Commit / push / ship / finalize | STOP -> "
        "Run `ag commit` |\n"
        "| Done / complete / finished / merge | STOP -> "
        "Run `ag done F-XXXX`. Flush ideas via `ag todo`. |\n"
        "| Idea / remember / todo / note | STOP -> "
        '`ag todo "description"` |\n'
        "| Backlog / what's next / prioritize | STOP -> "
        "`ag backlog` to see queue |\n"
        "| Write spec / acceptance criteria | STOP -> "
        "Run `ag spec F-XXXX` |\n"
        "| Decompose / break down epic | STOP -> "
        "Run `ag decompose F-XXXX` |\n"
        "| Plan created / exited plan mode | STOP -> "
        "Save plan, run dialectical review if "
        "`plan_review_enabled: yes`, then implement |"
    )


def plan_mode_exit() -> str:
    """Dialectical review protocol — Claude-only."""
    return (
        "## After Plan Mode Exits (when `plan_review_enabled: yes`)\n\n"
        "Exiting plan mode creates a DRAFT. Auto-continue immediately "
        "— do NOT stop and wait for user input.\n"
        "1. Save plan to `.agentic/work/F-XXXX/plan.md` with "
        "`**Status**: DRAFT`\n"
        "2. Spawn Critic + Advocate agents in parallel (fresh context)\n"
        "3. Synthesize with Revision Guidance\n"
        "4. Check `plan_review_convergence` in STACK.md: `auto` → "
        "approve on convergence; `manual` → present to user\n"
        "5. After APPROVED → run `ag transition F-XXXX implementation`\n\n"
        '**Wrong rationalizations:** "User created the plan so it\'s '
        'reviewed" — NO. "Plan mode exit = approval" — NO. '
        '"Simple plan, review unnecessary" — NO. '
        "Review is structural, not discretionary."
    )


def core_rules() -> str:
    """Universal rules all tools share."""
    return (
        "## Rules\n\n"
        "- Never auto-commit in interactive sessions. Show changes "
        "to human first.\n"
        "- PR by default: create feature branches and PRs "
        "(check `git_workflow` in STACK.md).\n"
        "- Add/update tests for new/changed logic. Write tests "
        "alongside code.\n"
        "- Spec + code + tests + docs = done "
        "(update all artifacts together).\n"
        "- Keep changes small and scoped "
        "(max 5-10 files per commit).\n"
        "- Multi-session safety: never run destructive git ops "
        "when other sessions may be active."
    )


def token_scripts() -> str:
    """Token-efficient script references."""
    return (
        "Token-efficient scripts (ALWAYS use these, NEVER edit "
        "state files directly):\n"
        '- STATUS.md: `bash .agentic/lib/tools/status.sh focus "Task"`\n'
        "- JOURNAL.md: `bash .agentic/lib/tools/journal.sh "
        '"Topic" "Outcomes" "Next" "Blockers" --why "Problem"`\n'
        "- HUMAN_NEEDED.md: `bash .agentic/lib/tools/blocker.sh "
        'add "Title" "type" "Details"`\n'
        "- TODO.md: `bash .agentic/lib/tools/todo.sh "
        'add "Idea"` or `ag todo "Idea"`'
    )


def sandbox_note() -> str:
    """Codex sandbox workaround."""
    return (
        "Note: Codex runs commands in a sandbox. Append `|| true` "
        "to commands that may fail to prevent non-zero exit codes "
        "from halting execution."
    )


def conventions_ref() -> str:
    """Reference to conventions.md."""
    return (
        "See `.agentic/conventions.md` for code quality standards "
        "(security, testing, naming, structure)."
    )


def project_settings(settings: ProjectSettings) -> str:
    """Dynamic section with project-specific configuration."""
    lines = [
        "## Project Settings\n",
        f"- Profile: `{settings.profile}`",
        f"- Mode: `{settings.mode}`",
        f"- Plan review: {'enabled' if settings.plan_review_enabled else 'disabled'}",
    ]
    if settings.verification_commands:
        lines.append("- Verification commands:")
        for cmd in settings.verification_commands:
            lines.append(f"  - `{cmd}`")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Section registry — maps section IDs to callables
# ---------------------------------------------------------------------------

SECTIONS = {
    "preamble": preamble,
    "session_start": session_start,
    "workflow_commands": workflow_commands,
    "artifacts": artifacts,
    "trigger_words": trigger_words,
    "plan_mode_exit": plan_mode_exit,
    "core_rules": core_rules,
    "token_scripts": token_scripts,
    "sandbox_note": sandbox_note,
    "conventions_ref": conventions_ref,
    "project_settings": project_settings,
}
