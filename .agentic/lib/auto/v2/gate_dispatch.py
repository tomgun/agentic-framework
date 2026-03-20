"""
gate_dispatch.py — Routes gate checks to human/ai/skip based on profile config.

When TransitionOrchestrator encounters a gate on a transition, it calls
dispatch_gate() which routes to the appropriate handler:
  - human: logs to HUMAN_NEEDED.md, returns pending
  - ai: invokes CriticalAgent (or ConvergenceLoop for plan_approved)
  - skip: audit-logs and passes

Gate handlers are NOT limited to synchronous checks — the plan_approved
handler runs a full dialectical convergence loop (multi-step, multi-agent).
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Optional


def _find_plan_path(project_root: Path, feature_id: str) -> Optional[Path]:
    """Find the plan file for a feature.

    Checks work item dir first, then journal/plans/ with glob.
    """
    # Check work item dir
    work_plan = project_root / ".agentic" / "work" / feature_id / "plan.md"
    if work_plan.exists():
        return work_plan

    # Check journal plans (date-prefixed)
    plans_dir = project_root / ".agentic" / "journal" / "plans"
    if plans_dir.exists():
        matches = list(plans_dir.glob(f"*{feature_id}*plan*.md"))
        if matches:
            return matches[0]

    return None


@dataclass
class GateResult:
    """Result of a gate check."""
    passed: bool
    reviewer: str  # human | ai | skip
    verdict: Optional[str] = None  # For ai gates: approve/reject/escalate
    reason: Optional[str] = None
    pending: bool = False  # True if waiting for human review

    @staticmethod
    def approved(reviewer: str, reason: Optional[str] = None) -> GateResult:
        return GateResult(passed=True, reviewer=reviewer, verdict="approve", reason=reason)

    @staticmethod
    def rejected(reviewer: str, reason: str) -> GateResult:
        return GateResult(passed=False, reviewer=reviewer, verdict="reject", reason=reason)

    @staticmethod
    def pending_human(gate_name: str) -> GateResult:
        return GateResult(
            passed=True, reviewer="human", pending=True,
            reason=f"Gate '{gate_name}' awaiting human review",
        )

    @staticmethod
    def skipped(gate_name: str) -> GateResult:
        return GateResult(
            passed=True, reviewer="skip",
            reason=f"Gate '{gate_name}' skipped per profile",
        )


# ---------------------------------------------------------------------------
# Gate handlers
# ---------------------------------------------------------------------------


def _handle_human_gate(
    project_root: Path,
    feature_id: str,
    gate_name: str,
) -> GateResult:
    """Human gate: log to HUMAN_NEEDED.md and return pending."""
    blocker_sh = project_root / ".agentic" / "lib" / "tools" / "blocker.sh"
    if blocker_sh.exists():
        import subprocess
        try:
            subprocess.run(
                [
                    "bash", str(blocker_sh), "add",
                    f"Gate: {gate_name} ({feature_id})",
                    "review",
                    f"Feature {feature_id} needs human review at gate '{gate_name}'",
                ],
                cwd=str(project_root),
                capture_output=True,
                timeout=10,
            )
        except Exception:
            pass  # Best-effort — don't block transition on logging failure

    return GateResult.pending_human(gate_name)


def _handle_skip_gate(gate_name: str) -> GateResult:
    """Skip gate: pass through with audit note."""
    return GateResult.skipped(gate_name)


def _handle_ai_gate(
    project_root: Path,
    feature_id: str,
    gate_name: str,
    context: Optional[dict] = None,
) -> GateResult:
    """AI gate: dispatch to appropriate AI reviewer.

    - plan_approved: runs ConvergenceLoop from plan_convergence.py
    - code_review, verification_review, spec_review: runs CriticalAgent
    """
    if gate_name == "plan_approved":
        return _handle_plan_review_gate(project_root, feature_id, context)
    else:
        return _handle_critical_agent_gate(project_root, feature_id, gate_name, context)


def _handle_plan_review_gate(
    project_root: Path,
    feature_id: str,
    context: Optional[dict] = None,
) -> GateResult:
    """Plan review gate: delegates to plan_convergence.ConvergenceLoop.

    This is a multi-step process (spawn Critic + Advocate, check convergence,
    possibly iterate). The gate handler manages the full lifecycle.

    Lazy-imports plan_convergence to avoid circular deps.
    """
    try:
        from auto.plan_convergence import ConvergenceLoop  # type: ignore[import]

        # Find plan path from work item dir or journal
        plan_path = _find_plan_path(project_root, feature_id)
        if not plan_path:
            return GateResult.rejected("ai", reason=f"No plan.md found for {feature_id}")

        loop = ConvergenceLoop(project_root)
        result = loop.run(
            feature_id=feature_id,
            plan_path=str(plan_path),
            autonomous=True,
        )
        if result.converged or result.plan_status == "APPROVED":
            return GateResult.approved("ai", reason="Plan review converged")
        elif result.plan_status == "ESCALATED":
            return GateResult.rejected(
                "ai",
                reason=f"Plan review escalated: {result.escalation_reason}",
            )
        else:
            return GateResult.rejected(
                "ai",
                reason=result.escalation_reason or "Plan review did not converge",
            )
    except ImportError:
        # plan_convergence not available — fall back to human
        return GateResult.pending_human("plan_approved")
    except Exception:
        # AI review failed — fall back to human
        return GateResult.pending_human("plan_approved")


def _handle_critical_agent_gate(
    project_root: Path,
    feature_id: str,
    gate_name: str,
    context: Optional[dict] = None,
) -> GateResult:
    """Code/spec/verification review gate: delegates to CriticalAgent.

    Lazy-imports critical_agent to avoid circular deps.
    """
    try:
        from auto.critical_agent import CriticalAgent  # type: ignore[import]
        agent = CriticalAgent(project_root)

        # Map gate names to review settings (matches STACK.md keys)
        review_setting = {
            "code_review": "review_code",
            "spec_review": "review_spec",
            "verification_review": "review_regression",
        }.get(gate_name, "review_code")

        # Resolve from/to states from context if available
        from_state = (context or {}).get("from_state", "unknown")
        to_state = (context or {}).get("to_state", "unknown")

        verdict = agent.review(
            feature_id=feature_id,
            from_state=from_state,
            to_state=to_state,
            review_setting=review_setting,
        )
        if verdict.verdict == "approved":
            return GateResult.approved("ai", reason=verdict.summary)
        elif verdict.verdict == "request_changes":
            return GateResult.rejected("ai", reason=verdict.summary or "Changes requested")
        elif verdict.verdict == "escalate":
            # Escalate to human
            return GateResult.pending_human(gate_name)
        else:
            return GateResult.rejected("ai", reason=verdict.summary or "Review rejected")
    except ImportError:
        return GateResult.pending_human(gate_name)
    except Exception:
        # AI review failed — fall back to human
        return GateResult.pending_human(gate_name)


# ---------------------------------------------------------------------------
# Main dispatcher
# ---------------------------------------------------------------------------


def dispatch_gate(
    project_root: Path,
    feature_id: str,
    gate_name: str,
    reviewer: str,
    context: Optional[dict] = None,
) -> GateResult:
    """Dispatch a gate check to the appropriate handler.

    Args:
        project_root: Project root path.
        feature_id: Feature being transitioned.
        gate_name: Name of the gate (from state_machine_af.yaml).
        reviewer: Who reviews — "human", "ai", or "skip" (from profile config).
        context: Optional context dict for AI reviewers.

    Returns:
        GateResult with pass/fail/pending status.
    """
    if reviewer == "skip":
        return _handle_skip_gate(gate_name)
    elif reviewer == "human":
        return _handle_human_gate(project_root, feature_id, gate_name)
    elif reviewer == "ai":
        return _handle_ai_gate(project_root, feature_id, gate_name, context)
    else:
        # Unknown reviewer type — safe default to human
        return _handle_human_gate(project_root, feature_id, gate_name)
