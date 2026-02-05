# Change Manifest: feature/F-0117-F-0118-migration-and-doc-drift

Generated: 2026-02-04T21:09:53Z
Mode: branch

## Commits

| Hash | Date | Message | Files | +/- |
|------|------|---------|-------|-----|
| dccf7af | 2026-02-04 | feat: Add manifest.sh and migrate state to .agenti | 55 | +668/-202 |
| cc42c11 | 2026-02-04 | feat: Add migration system and doc drift detection | 7 | +714/-110 |

## Summary

- **Total commits**: 2
- **Lines added**: 1382
- **Lines removed**: 312

## Files Changed

### Code
- `.agentic/claude-hooks/PreCompact.sh`
- `.agentic/claude-hooks/Stop.sh`
- `.agentic/hooks/pre-commit-check.sh`
- `.agentic/tools/ag.sh`
- `.agentic/tools/doctor.py`
- `.agentic/tools/drift.sh`
- `.agentic/tools/journal.sh`
- `.agentic/tools/manifest.sh`
- `.agentic/tools/migration.sh`
- `.agentic/tools/phase_detect.py`
- `.agentic/tools/scope_check.sh`
- `.agentic/tools/wip.sh`
- `.agentic/tools/worktree.sh`

### Tests
- `spec/FEATURES.md`
- `spec/acceptance/F-0117.md`
- `spec/acceptance/F-0118.md`
- `spec/acceptance/F-0119.md`
- `tests/llm/tests/001_session_start.sh`
- `tests/llm/tests/002_wip_blocks_commit.sh`
- `tests/llm/tests/006_wip_recovery.sh`
- `tests/llm/tests/014_multi_agent_awareness.sh`
- `tests/test_ag_gateway.sh`
- `tests/test_phase_detect.py`
- `tests/validate_framework.sh`

### Documentation
- `.agentic/DEVELOPER_GUIDE.md`
- `.agentic/EMERGENCY.md`
- `.agentic/FRAMEWORK_QUICK_START.md`
- `.agentic/PRINCIPLES.md`
- `.agentic/ROI.md`
- `.agentic/agents/claude/CLAUDE.md`
- `.agentic/agents/codex/codex-instructions.md`
- `.agentic/agents/shared/AGENT_QUICK_START.md`
- `.agentic/agents/shared/agent_operating_guidelines.md`
- `.agentic/agents/shared/auto_orchestration.md`
- `.agentic/agents/shared/guidelines/multi-agent.md`
- `.agentic/agents/shared/guidelines/small-batch.md`
- `.agentic/agents/shared/guidelines/wip-tracking.md`
- `.agentic/checklists/agent_behavior_verification.md`
- `.agentic/checklists/before_commit.md`
- `.agentic/checklists/feature_complete.md`
- `.agentic/checklists/session_start.md`
- `.agentic/init/STACK.template.md`
- `.agentic/prompts/claude-commands/continue.md`
- `.agentic/prompts/cursor/session_start.md`
- `.agentic/workflows/environment_switching.md`
- `.agentic/workflows/git_workflow.md`
- `.agentic/workflows/multi_agent_coordination.md`
- `.agentic/workflows/recovery.md`
- `.agentic/workflows/work_in_progress.md`
- `CHANGELOG.md`
- `CLAUDE.md`
- `CONTEXT_PACK.md`
- `JOURNAL.md`
- `spec/FEATURES.md`
- `spec/acceptance/F-0117.md`
- `spec/acceptance/F-0118.md`
- `spec/acceptance/F-0119.md`

### Configuration
- `.agentic/agents/context-manifests/git-agent.yaml`
- `.agentic/agents/context-manifests/orchestrator-agent.yaml`
- `.agentic/state/status.json`
