"""
publish.py -- App Store Publishing Orchestrator for the Agentic Framework.

Manages phased publishing execution: preflight → build → screenshots →
metadata → submit → monitor. State persisted to publish-state.json for
resume capability. Delegates platform-specific work to providers (bash).

Usage:
    python3 publish.py --platform ios --provider fastlane [--dry-run] [--skip-screenshots]
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------
_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
PUBLISH_STATE_FILENAME = "publish-state.json"
PHASES = ["preflight", "build", "screenshots", "metadata", "submit", "monitor"]
PHASE_STATUS = ("pending", "running", "passed", "failed", "skipped")

# Credential patterns to redact from provider output
REDACT_PATTERNS = [
    "-----BEGIN",
    "-----END",
    "PRIVATE KEY",
    "api_key",
    "password",
    "secret",
    "token",
]


def _redact_line(line: str) -> str:
    """Redact lines that match credential patterns."""
    lower = line.lower()
    for pattern in REDACT_PATTERNS:
        if pattern.lower() in lower:
            return "[REDACTED]"
    return line


class PublishState:
    """Manages publish-state.json with atomic writes."""

    def __init__(self, session_dir: Path) -> None:
        self._path = session_dir / PUBLISH_STATE_FILENAME
        self._data: dict = {}

    def load(self) -> dict:
        if self._path.exists():
            with open(self._path) as f:
                self._data = json.load(f)
        return self._data

    def save(self) -> None:
        tmp = self._path.with_suffix(".tmp")
        with open(tmp, "w") as f:
            json.dump(self._data, f, indent=2)
        tmp.rename(self._path)

    def init(
        self,
        platform: str,
        provider: str,
        dry_run: bool = False,
        skip_screenshots: bool = False,
    ) -> None:
        self._data = {
            "platform": platform,
            "provider": provider,
            "started_at": datetime.now(timezone.utc).isoformat(),
            "dry_run": dry_run,
            "phases": {},
            "retry_policy": {"max_retries": 3, "backoff": "exponential"},
        }
        for phase in PHASES:
            status = "pending"
            if phase == "screenshots" and skip_screenshots:
                status = "skipped"
            self._data["phases"][phase] = {"status": status}
        self.save()

    @property
    def data(self) -> dict:
        return self._data

    def set_phase(self, phase: str, status: str, **kwargs: str) -> None:
        if phase not in self._data.get("phases", {}):
            return
        self._data["phases"][phase]["status"] = status
        for k, v in kwargs.items():
            self._data["phases"][phase][k] = v
        self.save()

    def get_phase_status(self, phase: str) -> str:
        return self._data.get("phases", {}).get(phase, {}).get("status", "pending")

    def next_phase(self) -> Optional[str]:
        """Return the next pending phase, or None if all done."""
        for phase in PHASES:
            status = self.get_phase_status(phase)
            if status == "pending":
                return phase
        return None

    def is_resumable(self) -> bool:
        """Check if there's an existing state that can be resumed."""
        return self._path.exists() and bool(self._data.get("phases"))


class PublishOrchestrator:
    """Orchestrates multi-phase app store publishing."""

    def __init__(
        self,
        project_root: Path,
        platform: str,
        provider: str,
        dry_run: bool = False,
        skip_screenshots: bool = False,
    ) -> None:
        self.project_root = project_root
        self.platform = platform
        self.provider = provider
        self.dry_run = dry_run
        self.skip_screenshots = skip_screenshots

        self.publish_dir = project_root / ".agentic" / "lib" / "tools" / "publish"
        self.provider_script = self.publish_dir / "providers" / f"{provider}.sh"
        session_dir = project_root / ".agentic" / "session"
        session_dir.mkdir(parents=True, exist_ok=True)
        self.state = PublishState(session_dir)

    def _provider_capabilities(self) -> list[str]:
        """Query provider for supported capabilities."""
        if not self.provider_script.exists():
            return []
        result = subprocess.run(
            ["bash", "-c", f"source {self.provider_script} && provider_capabilities"],
            capture_output=True,
            text=True,
            cwd=str(self.project_root),
            env={**os.environ, "PROJECT_ROOT": str(self.project_root)},
        )
        if result.returncode == 0:
            return result.stdout.strip().split()
        return []

    def _run_provider_phase(self, phase: str) -> bool:
        """Run a provider phase function, return True on success."""
        func_name = f"provider_{phase}"
        cmd = f"source {self.provider_script} && {func_name} {self.platform} {str(self.dry_run).lower()}"

        print(f"\n--- Phase: {phase} ---")
        self.state.set_phase(phase, "running")

        try:
            proc = subprocess.Popen(
                ["bash", "-c", cmd],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                cwd=str(self.project_root),
                env={**os.environ, "PROJECT_ROOT": str(self.project_root)},
            )
            assert proc.stdout is not None
            for line in proc.stdout:
                print(_redact_line(line.rstrip()))
            proc.wait()

            if proc.returncode == 0:
                self.state.set_phase(phase, "passed")
                print(f"  ✓ {phase} passed")
                return True
            else:
                self.state.set_phase(phase, "failed", error=f"exit code {proc.returncode}")
                print(f"  ✗ {phase} failed (exit {proc.returncode})")
                return False
        except Exception as e:
            self.state.set_phase(phase, "failed", error=str(e))
            print(f"  ✗ {phase} error: {e}")
            return False

    def run(self) -> bool:
        """Execute the full publishing pipeline. Returns True on success."""
        # Check for resumable state
        existing = self.state.load()
        if self.state.is_resumable():
            resume_platform = existing.get("platform")
            if resume_platform == self.platform:
                next_phase = self.state.next_phase()
                if next_phase:
                    print(f"Resuming from phase: {next_phase}")
                else:
                    print("All phases already completed.")
                    return True
            else:
                print(f"Previous state was for {resume_platform}, starting fresh for {self.platform}")
                self.state.init(self.platform, self.provider, self.dry_run, self.skip_screenshots)
        else:
            self.state.init(self.platform, self.provider, self.dry_run, self.skip_screenshots)

        # Get provider capabilities
        capabilities = self._provider_capabilities()
        if not capabilities:
            print(f"WARNING: Could not query provider capabilities, attempting all phases")
            capabilities = PHASES

        # Execute phases
        for phase in PHASES:
            status = self.state.get_phase_status(phase)
            if status in ("passed", "skipped"):
                print(f"  ↳ {phase}: {status} (skipping)")
                continue

            if phase not in capabilities and phase != "preflight":
                self.state.set_phase(phase, "skipped", reason="provider lacks capability")
                print(f"  ↳ {phase}: skipped (provider lacks capability)")
                continue

            # Preflight is handled by preflight.sh, not the provider
            if phase == "preflight":
                self.state.set_phase(phase, "passed")
                print(f"  ↳ preflight: passed (already validated)")
                continue

            success = self._run_provider_phase(phase)
            if not success:
                print(f"\nPipeline stopped at {phase}. Fix the issue and re-run to resume.")
                return False

        print("\n✓ All phases completed successfully.")
        if self.dry_run:
            print("  (dry-run mode — no actual submission was made)")
        return True


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(description="App Store Publishing Orchestrator")
    parser.add_argument("--platform", required=True, choices=["ios", "android", "react_native", "flutter"])
    parser.add_argument("--provider", required=True, choices=["fastlane", "custom"])
    parser.add_argument("--dry-run", action="store_true", default=False)
    parser.add_argument("--skip-screenshots", action="store_true", default=False)
    parser.add_argument("--project-root", default=".", help="Project root directory")

    args = parser.parse_args()

    project_root = Path(args.project_root).resolve()
    orchestrator = PublishOrchestrator(
        project_root=project_root,
        platform=args.platform,
        provider=args.provider,
        dry_run=args.dry_run,
        skip_screenshots=args.skip_screenshots,
    )

    success = orchestrator.run()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
