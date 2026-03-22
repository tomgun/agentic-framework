"""
paths.py — Central path resolver for the Agentic Framework (Python).

Usage:
    from pathlib import Path
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from paths import get_paths

    p = get_paths()  # auto-detects from cwd
    # or: p = get_paths(Path("/some/project"))

    features = p.features_file
    spec_dir = p.spec_dir
"""
from __future__ import annotations

from pathlib import Path
from typing import Optional


class AgenticPaths:
    """Resolved path set for a project using the Agentic Framework."""

    def __init__(self, project_root: Path):
        self.project_root = project_root.resolve()
        self.agentic_root = self.project_root / ".agentic"
        self.agentic_lib = self.agentic_root / "lib"

        # Main project root (not a worktree) for shared state like AGENTS.json
        self.main_project_root = self._resolve_main_root(self.project_root)
        self.agents_json = self.main_project_root / ".agentic" / "session" / "AGENTS.json"

        # Project config (stays at project root)
        self.claude_md = self.project_root / "CLAUDE.md"
        self.stack_file = self.project_root / "STACK.md"
        self.context_pack_file = self.project_root / "CONTEXT_PACK.md"
        self.agents_file = self.project_root / "AGENTS.md"

        # Tracking files (flat at .agentic/ root)
        self.status_file = self._resolve(
            self.agentic_root / "STATUS.md", self.project_root / "STATUS.md")
        self.todo_file = self._resolve(
            self.agentic_root / "TODO.md", self.project_root / "TODO.md")
        self.human_needed_file = self._resolve(
            self.agentic_root / "HUMAN_NEEDED.md", self.project_root / "HUMAN_NEEDED.md")
        self.contributions_file = self._resolve(
            self.agentic_root / "CONTRIBUTIONS.md", self.project_root / "CONTRIBUTIONS.md")
        self.overview_file = self._resolve(
            self.agentic_root / "OVERVIEW.md", self.project_root / "OVERVIEW.md")
        self.backlog_file = self.agentic_root / "BACKLOG.json"

        # Journal (.agentic/journal/)
        self.journal_dir = self._resolve(
            self.agentic_root / "journal", self.project_root / ".agentic-journal")
        self.journal_file = self._resolve(
            self.agentic_root / "journal" / "JOURNAL.md",
            self.project_root / ".agentic-journal" / "JOURNAL.md",
        )
        self.plans_dir = self._resolve(
            self.agentic_root / "journal" / "plans",
            self.project_root / ".agentic-journal" / "plans")
        self.lessons_dir = self._resolve(
            self.agentic_root / "journal" / "lessons",
            self.project_root / ".agentic-journal" / "lessons")
        self.manifests_dir = self._resolve(
            self.agentic_root / "journal" / "manifests",
            self.project_root / ".agentic-journal" / "manifests")
        self.evidence_dir = self._resolve(
            self.agentic_root / "journal" / "evidence",
            self.project_root / ".agentic-journal" / "evidence")

        # Specs (.agentic/spec/)
        self.spec_dir = self._resolve(
            self.agentic_root / "spec", self.project_root / "spec")
        self.features_file = self._resolve(
            self.agentic_root / "spec" / "FEATURES.md",
            self.project_root / "spec" / "FEATURES.md")
        self.issues_file = self._resolve(
            self.agentic_root / "spec" / "ISSUES.md",
            self.project_root / "spec" / "ISSUES.md")
        self.nfr_file = self._resolve(
            self.agentic_root / "spec" / "NFR.md",
            self.project_root / "spec" / "NFR.md")
        self.references_file = self._resolve(
            self.agentic_root / "spec" / "REFERENCES.md",
            self.project_root / "spec" / "REFERENCES.md")
        self.lessons_file = self._resolve(
            self.agentic_root / "spec" / "LESSONS.md",
            self.project_root / "spec" / "LESSONS.md")
        self.acceptance_dir = self._resolve(
            self.agentic_root / "spec" / "acceptance",
            self.project_root / "spec" / "acceptance")
        self.contracts_dir = self._resolve(
            self.agentic_root / "spec" / "contracts",
            self.project_root / "spec" / "contracts")
        self.adr_dir = self._resolve(
            self.agentic_root / "spec" / "adr",
            self.project_root / "spec" / "adr")
        self.migrations_dir = self._resolve(
            self.agentic_root / "spec" / "migrations",
            self.project_root / "spec" / "migrations")
        self.reviews_dir = self._resolve(
            self.agentic_root / "spec" / "reviews",
            self.project_root / "spec" / "reviews")

        # Session / ephemeral (.agentic/session/)
        self.session_dir = self._resolve(
            self.agentic_root / "session", self.project_root / ".agentic-state")
        self.wip_file = self._resolve(
            self.agentic_root / "session" / "WIP.md",
            self.project_root / ".agentic-state" / "WIP.md")
        self.agents_active_file = self._resolve(
            self.agentic_root / "session" / "AGENTS_ACTIVE.md",
            self.project_root / ".agentic-state" / "AGENTS_ACTIVE.md",
        )
        self.proposals_dir = self._resolve(
            self.agentic_root / "session" / "proposals",
            self.project_root / ".agentic-state" / "proposals")
        self.pending_reviews_dir = self._resolve(
            self.agentic_root / "session" / "reviews",
            self.project_root / ".agentic-state" / "reviews")
        self.kickoff_staging_dir = self.session_dir / "kickoff-draft"
        self.verification_state = self._resolve(
            self.agentic_root / "session" / ".verification-state",
            self.project_root / ".agentic-state" / ".verification-state")
        self.framework_log = self.session_dir / "framework.log"

        # Framework lib directories (inside .agentic/lib/)
        self.tools_dir = self._resolve(
            self.agentic_lib / "tools", self.agentic_root / "tools")
        self.agents_lib_dir = self._resolve(
            self.agentic_lib / "agents", self.agentic_root / "agents")
        self.workflows_dir = self._resolve(
            self.agentic_lib / "workflows", self.agentic_root / "workflows")
        self.quality_dir = self._resolve(
            self.agentic_lib / "quality", self.agentic_root / "quality")
        self.checklists_dir = self._resolve(
            self.agentic_lib / "checklists", self.agentic_root / "checklists")
        self.init_dir = self._resolve(
            self.agentic_lib / "init", self.agentic_root / "init")
        self.hooks_dir = self._resolve(
            self.agentic_lib / "hooks", self.agentic_root / "hooks")
        self.claude_hooks_dir = self._resolve(
            self.agentic_lib / "claude-hooks", self.agentic_root / "claude-hooks")
        self.prompts_dir = self._resolve(
            self.agentic_lib / "prompts", self.agentic_root / "prompts")
        self.schemas_dir = self._resolve(
            self.agentic_lib / "schemas", self.agentic_root / "schemas")
        self.presets_dir = self._resolve(
            self.agentic_lib / "presets", self.agentic_root / "presets")
        self.support_dir = self._resolve(
            self.agentic_lib / "support", self.agentic_root / "support")
        self.templates_dir = self._resolve(
            self.agentic_lib / "templates", self.agentic_root / "spec")

        # Framework docs
        self.principles_file = self._resolve(
            self.agentic_lib / "PRINCIPLES.md", self.agentic_root / "PRINCIPLES.md")
        self.developer_guide_file = self._resolve(
            self.agentic_lib / "DEVELOPER_GUIDE.md", self.agentic_root / "DEVELOPER_GUIDE.md")
        self.version_file = self._resolve(
            self.agentic_lib / "VERSION", self.agentic_root / "VERSION")

        # User extensions (.agentic/local/)
        self.local_dir = self._resolve(
            self.agentic_root / "local", self.project_root / ".agentic-local")

    @staticmethod
    def _resolve(new_path: Path, legacy_path: Optional[Path] = None) -> Path:
        """Return new_path if it exists, else legacy_path if it exists, else new_path."""
        if legacy_path is None:
            return new_path
        if new_path.exists():
            return new_path
        if legacy_path.exists():
            return legacy_path
        return new_path

    @staticmethod
    def _resolve_main_root(project_root: Path) -> Path:
        """Resolve the main repo root (not a worktree).

        In a git worktree, git-common-dir points to the main repo's .git,
        so the main repo is its parent directory.
        """
        import subprocess
        try:
            git_common = subprocess.run(
                ["git", "rev-parse", "--git-common-dir"],
                capture_output=True, text=True, cwd=str(project_root),
            ).stdout.strip()
            git_dir = subprocess.run(
                ["git", "rev-parse", "--git-dir"],
                capture_output=True, text=True, cwd=str(project_root),
            ).stdout.strip()
            if git_common and git_dir and git_common != git_dir:
                return Path(git_common).resolve().parent
        except (FileNotFoundError, OSError):
            pass
        return project_root


# Module-level cache
_paths_cache: dict[str, AgenticPaths] = {}


def get_paths(root: Optional[Path] = None) -> AgenticPaths:
    """Get resolved paths for a project.

    Args:
        root: Project root directory. Defaults to cwd.

    Returns:
        AgenticPaths instance with all resolved paths.
    """
    if root is None:
        root = Path.cwd()
    key = str(root.resolve())
    if key not in _paths_cache:
        _paths_cache[key] = AgenticPaths(root)
    return _paths_cache[key]
