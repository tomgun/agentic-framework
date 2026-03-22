"""
pr_review.py -- Auto-review PRs after creation (F-0235).

Spawns a review agent to assess PR diff against ACs, auto-fixes findings
(up to pr_fix_max_attempts cycles), then applies verdict to GitHub.

Usage:
    from auto.pr_review import PRReviewer
    reviewer = PRReviewer(project_root=Path("."), claude_command="claude")
    result = reviewer.review_and_fix(pr_number=42, feature_id="F-0042")
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
from paths import get_paths  # noqa: E402
from settings import get_setting  # noqa: E402

from auto import spawn_claude  # noqa: E402


@dataclass
class PRReviewResult:
    """Result of a PR review + fix cycle."""
    verdict: str = ""       # approved | request_changes | needs_discussion | skipped
    summary: str = ""
    must_fix: list[str] = field(default_factory=list)
    should_fix: list[str] = field(default_factory=list)
    raw_output: str = ""
    fix_attempts: int = 0


class PRReviewer:
    """Reviews PRs and optionally auto-fixes findings.

    Initialized with project_root from TaskRunner (= worktree path in
    parallel mode) and claude_command from TaskRunner.
    """

    def __init__(self, project_root: Path, claude_command: str = "claude") -> None:
        self.project_root = project_root.resolve()
        self.paths = get_paths(project_root)
        self.claude_command = claude_command

    def review_and_fix(
        self,
        pr_number: int,
        feature_id: str,
    ) -> PRReviewResult:
        """Review a PR and auto-fix findings if possible.

        Returns PRReviewResult with final verdict after fix loop.
        """
        review_pr = get_setting(self.project_root, "review_pr", "skip")
        if review_pr == "skip":
            return PRReviewResult(verdict="skipped")

        if review_pr == "human":
            return self._create_human_review(pr_number, feature_id)

        # critical_agent mode — run review + fix loop
        max_fixes = int(get_setting(
            self.project_root, "pr_fix_max_attempts", "2",
        ))

        result = PRReviewResult()
        total_rounds = 1 + max_fixes  # initial review + fix attempts

        for round_num in range(total_rounds):
            # Get fresh PR diff
            pr_diff = self._get_pr_diff(pr_number)
            if not pr_diff:
                print(
                    f"  Warning: empty PR diff for #{pr_number} — skipping review",
                    file=sys.stderr,
                )
                result.verdict = "skipped"
                result.summary = "Could not fetch PR diff"
                return result

            # Run review agent
            review_output = self._run_review_agent(
                pr_number, feature_id, pr_diff,
            )
            result.raw_output = review_output
            self._parse_review_output(review_output, result)

            if result.verdict == "approved":
                break

            if round_num < max_fixes and result.verdict == "request_changes":
                # Post review findings on GitHub
                self._post_review_comment(pr_number, result)
                # Spawn fix agent
                self._run_fix_agent(pr_number, feature_id, result, pr_diff)
                result.fix_attempts += 1
                # Continue loop — re-review with fresh agent
            else:
                break  # max attempts or needs_discussion

        # Apply final verdict to GitHub
        self._apply_verdict(pr_number, result)

        # If not approved after all attempts, create blocker
        if result.verdict != "approved":
            self._create_blocker(pr_number, feature_id, result)

        return result

    def _create_human_review(
        self, pr_number: int, feature_id: str,
    ) -> PRReviewResult:
        """Create a pending review block for human review (no automated review)."""
        self._create_pr_review_block(feature_id, pr_number)
        return PRReviewResult(
            verdict="needs_discussion",
            summary=f"Awaiting human review for PR #{pr_number}",
        )

    # -- Review agent -------------------------------------------------------

    def _run_review_agent(
        self,
        pr_number: int,
        feature_id: str,
        pr_diff: str,
    ) -> str:
        """Spawn review agent to assess PR diff."""
        prompt_template = self._load_prompt("pr_review.md")
        ac_content = self._load_ac(feature_id)
        plan_content = self._load_plan(feature_id)

        prompt = prompt_template.format(
            pr_number=pr_number,
            feature_id=feature_id,
            pr_diff=pr_diff[:50000],  # cap diff size for context
            ac_content=ac_content or "(No acceptance criteria file found)",
            plan_content=plan_content or "(No plan file found)",
        )

        return spawn_claude(
            self.claude_command,
            self.project_root,
            prompt,
            print_mode=True,
            timeout=300,
        )

    def _parse_review_output(self, output: str, result: PRReviewResult) -> None:
        """Parse structured review output into PRReviewResult."""
        # Parse VERDICT
        verdict_match = re.search(
            r"VERDICT:\s*(APPROVED|REQUEST_CHANGES|NEEDS_DISCUSSION)",
            output, re.IGNORECASE,
        )
        if verdict_match:
            result.verdict = verdict_match.group(1).lower()
        else:
            result.verdict = "needs_discussion"  # safe default

        # Parse SUMMARY
        summary_match = re.search(
            r"SUMMARY:\s*(.+?)(?:\n\n|\nMUST_FIX:|\nSHOULD_FIX:|\Z)",
            output, re.DOTALL,
        )
        if summary_match:
            result.summary = summary_match.group(1).strip()

        # Parse MUST_FIX
        result.must_fix = self._parse_list_section(output, "MUST_FIX:")

        # Parse SHOULD_FIX
        result.should_fix = self._parse_list_section(output, "SHOULD_FIX:")

    def _parse_list_section(self, output: str, header: str) -> list[str]:
        """Parse a dash-prefixed list section from review output."""
        match = re.search(
            rf"{re.escape(header)}\s*\n((?:\s*-\s+.+\n?)*)",
            output,
        )
        if not match:
            return []
        items = []
        for line in match.group(1).strip().split("\n"):
            line = line.strip()
            if line.startswith("- "):
                items.append(line[2:].strip())
        return items

    # -- Fix agent ----------------------------------------------------------

    def _run_fix_agent(
        self,
        pr_number: int,
        feature_id: str,
        review_result: PRReviewResult,
        pr_diff: str,
    ) -> str:
        """Spawn fix agent to address review findings."""
        prompt_template = self._load_prompt("pr_fix.md")
        ac_content = self._load_ac(feature_id)

        must_fix_text = "\n".join(
            f"- {item}" for item in review_result.must_fix
        ) or "(none)"
        should_fix_text = "\n".join(
            f"- {item}" for item in review_result.should_fix
        ) or "(none)"

        prompt = prompt_template.format(
            pr_number=pr_number,
            feature_id=feature_id,
            must_fix=must_fix_text,
            should_fix=should_fix_text,
            pr_diff=pr_diff[:50000],
            ac_content=ac_content or "(No acceptance criteria file found)",
        )

        # Fix agent needs file write + git access — NOT print_mode
        return spawn_claude(
            self.claude_command,
            self.project_root,
            prompt,
            print_mode=False,
            timeout=300,
        )

    # -- GitHub operations --------------------------------------------------

    def _get_pr_diff(self, pr_number: int) -> str:
        """Get PR diff from GitHub."""
        try:
            proc = subprocess.run(
                ["gh", "pr", "diff", str(pr_number)],
                cwd=str(self.project_root),
                capture_output=True,
                text=True,
                timeout=30,
            )
            return proc.stdout
        except Exception:
            return ""

    def _apply_verdict(self, pr_number: int, result: PRReviewResult) -> None:
        """Apply review verdict to GitHub PR."""
        try:
            if result.verdict == "approved":
                subprocess.run(
                    ["gh", "pr", "review", str(pr_number),
                     "--approve", "-b", result.summary or "Auto-review: approved"],
                    cwd=str(self.project_root),
                    capture_output=True, text=True, timeout=30,
                )
            elif result.verdict == "request_changes":
                body = result.summary or "Auto-review: changes requested"
                if result.must_fix:
                    body += "\n\nMust fix:\n" + "\n".join(
                        f"- {item}" for item in result.must_fix
                    )
                subprocess.run(
                    ["gh", "pr", "review", str(pr_number),
                     "--request-changes", "-b", body],
                    cwd=str(self.project_root),
                    capture_output=True, text=True, timeout=30,
                )
            elif result.verdict == "needs_discussion":
                body = result.summary or "Auto-review: discussion needed"
                subprocess.run(
                    ["gh", "pr", "comment", str(pr_number), "-b", body],
                    cwd=str(self.project_root),
                    capture_output=True, text=True, timeout=30,
                )
        except Exception:
            pass  # GitHub failures are non-fatal

    def _post_review_comment(
        self, pr_number: int, result: PRReviewResult,
    ) -> None:
        """Post review findings as PR comment before fix attempt."""
        body = f"**Auto-review findings (fix attempt {result.fix_attempts + 1}):**\n\n"
        if result.must_fix:
            body += "Must fix:\n" + "\n".join(
                f"- {item}" for item in result.must_fix
            ) + "\n\n"
        if result.should_fix:
            body += "Should fix:\n" + "\n".join(
                f"- {item}" for item in result.should_fix
            )
        try:
            subprocess.run(
                ["gh", "pr", "comment", str(pr_number), "-b", body],
                cwd=str(self.project_root),
                capture_output=True, text=True, timeout=30,
            )
        except Exception:
            pass

    # -- PR review block (for human mode + scheduler polling) ---------------

    def _create_pr_review_block(
        self, feature_id: str, pr_number: int,
    ) -> None:
        """Write PR review block JSON and HUMAN_NEEDED entry."""
        reviews_dir = self.paths.pending_reviews_dir
        reviews_dir.mkdir(parents=True, exist_ok=True)

        from datetime import datetime, timezone
        review_data = {
            "feature_id": feature_id,
            "pr_number": pr_number,
            "review_setting": "review_pr",
            "from_state": "pr_created",
            "to_state": "pr_reviewed",
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
        review_file = reviews_dir / f"{feature_id}_pr_review.json"
        review_file.write_text(json.dumps(review_data, indent=2) + "\n")

        # Create HUMAN_NEEDED entry
        blocker_sh = self.paths.tools_dir / "blocker.sh"
        if blocker_sh.exists():
            try:
                subprocess.run(
                    [
                        "bash", str(blocker_sh), "add",
                        f"PR Review: {feature_id} (#{pr_number})",
                        "decision",
                        f"PR #{pr_number} needs human review. "
                        f"Review on GitHub and approve to unblock.",
                    ],
                    capture_output=True, text=True,
                    cwd=str(self.project_root),
                )
            except (OSError, subprocess.SubprocessError):
                pass

    def _create_blocker(
        self, pr_number: int, feature_id: str, result: PRReviewResult,
    ) -> None:
        """Create HUMAN_NEEDED entry for unresolved PR review."""
        # Also write the block JSON so scheduler can poll
        self._create_pr_review_block(feature_id, pr_number)

    @staticmethod
    def check_pr_review_resolved(
        project_root: Path, feature_id: str,
    ) -> bool:
        """Check if a PR review has been resolved on GitHub.

        Called by scheduler polling loop for PR-review-blocked features.
        """
        paths = get_paths(project_root)
        review_file = paths.pending_reviews_dir / f"{feature_id}_pr_review.json"
        if not review_file.exists():
            return True  # no block = resolved

        try:
            data = json.loads(review_file.read_text())
            pr_number = data.get("pr_number")
            if not pr_number:
                return False
        except (json.JSONDecodeError, OSError):
            return False

        # Check GitHub review state
        try:
            proc = subprocess.run(
                ["gh", "pr", "view", str(pr_number),
                 "--json", "reviewDecision"],
                cwd=str(project_root),
                capture_output=True, text=True, timeout=30,
            )
            if proc.returncode == 0:
                gh_data = json.loads(proc.stdout)
                decision = gh_data.get("reviewDecision", "")
                if decision == "APPROVED":
                    # Clean up block
                    review_file.unlink(missing_ok=True)
                    # Resolve HUMAN_NEEDED entry
                    blocker_sh = paths.tools_dir / "blocker.sh"
                    if blocker_sh.exists():
                        try:
                            subprocess.run(
                                ["bash", str(blocker_sh), "resolve",
                                 f"PR Review: {feature_id}"],
                                capture_output=True, text=True,
                                cwd=str(project_root),
                            )
                        except (OSError, subprocess.SubprocessError):
                            pass
                    return True
        except Exception:
            pass

        return False

    # -- Context loading ----------------------------------------------------

    def _load_prompt(self, filename: str) -> str:
        """Load a prompt template from the prompts directory."""
        prompt_file = Path(__file__).parent / "prompts" / filename
        if prompt_file.exists():
            return prompt_file.read_text()
        return ""

    def _load_ac(self, feature_id: str) -> str:
        """Load acceptance criteria — contract YAML first, then legacy markdown."""
        contract_file = self.paths.contracts_dir / f"{feature_id}.yaml"
        if contract_file.exists():
            return contract_file.read_text()
        ac_file = self.paths.acceptance_dir / f"{feature_id}.md"
        if ac_file.exists():
            return ac_file.read_text()
        return ""

    def _load_plan(self, feature_id: str) -> str:
        """Load plan file for a feature (glob for date prefix)."""
        plans_dir = self.paths.plans_dir
        if not plans_dir.exists():
            return ""
        matches = list(plans_dir.glob(f"*{feature_id}*plan*.md"))
        if matches:
            return matches[0].read_text()
        return ""
