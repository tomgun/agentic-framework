# STACK.md - Agentic Framework

<!-- format: stack-v0.1.0 -->

Purpose: Configuration for developing the Agentic Framework itself.

## Agentic framework
- Version: 0.50.1
- Profile: autonomous_formal
- This IS the framework (dogfooding)
- Source: https://github.com/tomgun/agentic-framework

## Settings
<!-- Use `ag set <key> <value>` to change, `ag set --show` to view all. -->
- profile: autonomous_formal
<!-- discovery | formal | autonomous_formal -->

### Workflow
- feature_tracking: yes
# F-XXXX tracking, acceptance criteria gates. Profile defaults — Discovery: no | Formal: yes
- acceptance_criteria: blocking
# Require criteria before coding. Profile defaults — Discovery: recommended | Formal: blocking
- wip_before_commit: blocking
# WIP.md required before commit. Profile defaults — Discovery: warning | Formal: blocking
- pre_commit_checks: full
# Pre-commit gate depth. Profile defaults — Discovery: fast | Formal: full
- pre_commit_hook: fast
# Git hook dispatch mode. Profile defaults — Discovery: fast | Formal: fast
- git_workflow: pull_request
# Commit policy for main branch. Profile defaults — Discovery: direct | Formal: pull_request
- plan_review_enabled: yes
# Review plan before implementation (uses dialectical critic+advocate). Profile defaults — Discovery: no | Formal: yes
- spec_directory: yes
# Create spec/ directory for features. Profile defaults — Discovery: no | Formal: yes
- docs_gate: blocking
# Doc staleness check at ag done. Profile defaults — Discovery: off | Formal: blocking
- spec_analysis: on
# Advisory spec analysis before implementation. Profile defaults — Discovery: off | Formal: on
- worktree_mode: always
# Auto-create worktrees for feature branches. Options: off | always. Profile defaults — Discovery: off | Formal: off
- docs_stale_days: 30
# Days before a doc is flagged stale by docs.sh. Default: 30

### Periodic checks
- periodic_orphaned_plans: every_session
# Scan for unsaved plans. Options: every_session | off
- periodic_retro_check: every_5_sessions
# Retrospective due check. Options: every_N_sessions | off. Discovery default: off
- periodic_agent_refresh: every_20_sessions
# Suggest agent regeneration. Options: every_N_sessions | off. Discovery default: off

### Complexity limits
- max_files_per_commit: 10
# Blocking limit in pre-commit (advisory on feature branches in PR workflow). Profile defaults — Discovery: 15 | Formal: 10
- max_added_lines: 500
# Blocking limit for added lines (advisory on feature branches in PR workflow). Profile defaults — Discovery: 1000 | Formal: 500
- max_code_file_length: 2500
# Blocking limit for single file length. Profile defaults — Discovery: 1000 | Formal: 500

### Review checkpoints
<!-- Who reviews each transition. Options: human | critical_agent | skip -->
<!-- critical_agent spawns adversarial Claude reviewer (F-0182) -->
- review_spec: critical_agent
# planned → specced. Discovery: skip | Formal: critical_agent
- review_criteria: critical_agent
# specced → criteria_set. Discovery: skip | Formal: critical_agent
- review_plan: critical_agent
# plan review before implementing. Discovery: skip | Formal: critical_agent
- review_code: critical_agent
# documented → committed. Discovery: critical_agent | Formal: human | Autonomous Formal: critical_agent
- review_merge: human
# committed → shipped. Discovery: human | Formal: human
- review_decomposition: critical_agent
# Epic decomposition (future). Discovery: skip | Formal: critical_agent
- review_regression: critical_agent
# Any regression transition. Discovery: critical_agent | Formal: human | Autonomous Formal: critical_agent
- review_taste: critical_agent
# Subjective decisions (future). Discovery: skip | Formal: critical_agent
- review_commit: critical_agent
# Auto-commit in automated execution. human: stage only (default) | critical_agent: adversarial review then commit. Discovery: human | Formal: human | Autonomous Formal: critical_agent

- docs_mode: inline
# inline: update docs with code (default). deferred: log what's needed, generate later via `ag docs generate`.

## Summary
- What are we building: AI-assisted development framework with spec-driven methodology
- Primary platform: CLI tools / documentation

## Languages & runtimes
- Language(s): Bash, Python
- Runtime(s): Bash 5+, Python 3.9+

## Tooling
- Package manager: N/A (shell scripts)
- Formatting/linting: shellcheck (bash), ruff (python)

## License
- **Project License**: GPL-3.0 (framework code), dual-license for products
- **License File**: `LICENSE`
- **Copyright**: 2025-2026 Tomas Günther / TSG
- **Compatible Dependencies**: MIT, Apache 2.0, BSD
- **Incompatible Dependencies**: Proprietary (for framework code)

---

## Testing (required)
- Unit test framework: bash validate_framework.sh
- test: bash tests/validate_framework.sh
- test_fast: bash tests/validate_framework.sh
- Test commands:
  - Unit: `bash tests/validate_framework.sh`
  - Integration: `python3 -m pytest tests/ -x --ignore=tests/llm`
  - LLM: `python3 tests/llm/interactive_runner.py --critical`

## Development approach
- development_mode: standard  # Acceptance-Driven

## Agent mode (quality vs cost tradeoff)
<!-- Framework development = quality-critical, use best models -->
- agent_mode: premium
  <!-- premium: Best quality. opus for planning/implementation/review, sonnet for search -->
  <!-- balanced: Good balance. opus for planning, sonnet for implementation/review -->
  <!-- economy: Cost saving. sonnet for planning, haiku for everything else -->

## Model customization (optional)
<!-- Override default models for any task type -->
<!-- - models: -->
<!--     planning: opus -->
<!--     implementation: opus -->
<!--     review: opus -->
<!--     search: sonnet -->

## Plan-Review Loop
<!-- Iterative planning with critical review before implementation -->
<!-- Note: plan_review_enabled is in ## Settings (profile-aware) -->
- plan_review_max_iterations: 3
- plan_review_auto_for: [planning]
  <!-- planning: Runs for ag plan commands -->
  <!-- implement: Also runs before ag implement if no approved plan exists -->
- plan_review_convergence: auto
  <!-- auto: Loop runs to convergence without human per iteration (F-0236) -->
  <!-- manual: User decides each iteration (current behavior) -->
- plan_review_reviewers: [critic, advocate]
  <!-- Reviewer roles from catalog. Required: critic, advocate. -->
  <!-- Optional: security_expert, architect, qa_expert, ux_designer, ops_expert, db_expert -->

## PR Review
<!-- Auto-review PRs after creation in autonomous workflows (F-0235) -->
<!-- Note: review_pr is in ## Settings (profile-aware) -->
- pr_fix_max_attempts: 2
  <!-- Max auto-fix cycles before escalating to human. 0 = no auto-fix -->

## Sequential agent pipeline
<!-- Specialized agents working sequentially for optimal context efficiency -->
- pipeline_enabled: no  <!-- Enable when needed for complex features -->
- pipeline_mode: manual
- pipeline_agents: standard
- pipeline_handoff_approval: yes
- pipeline_coordination_file: .agentic/pipeline

## Git workflow
<!-- Framework uses PR workflow (dogfooding) -->
<!-- Note: git_workflow is in ## Settings (profile-aware) -->
- pr_draft_by_default: false
- pr_auto_request_review: false

## Multi-agent coordination
<!-- Multiple AI agents working simultaneously via worktrees -->
- multi_agent_enabled: no  <!-- Enable when using parallel agents -->
<!-- - multi_agent_orchestrator: cursor-main -->
<!-- - multi_agent_workers: -->
<!--     - id: cursor-agent-1 -->
<!--       worktree: /path/to/worktree-1 -->

## Retrospectives
<!-- Periodic project health checks -->
- retrospective_enabled: yes
- retrospective_trigger: features
- retrospective_interval_features: 5  # Every 5 features
- retrospective_depth: quick

## Research mode
<!-- Deep investigation for framework improvements -->
- research_enabled: yes
- research_cadence: 30  # days between field updates
- research_depth: standard
- research_budget: 60  # minutes per session

## Quality validation
<!-- Framework-specific quality gates -->
- quality_checks: enabled
- profile: framework_development
<!-- Note: pre_commit_hook is in ## Settings (profile-aware) -->
- run_command: bash tests/validate_framework.sh

## LLM behavioral tests
<!-- Agent behavior verification -->
- llm_tests_enabled: yes
- llm_test_command: ag test llm
- llm_test_critical_only: ag test llm --critical
- llm_test_results: tests/VERIFICATION_REPORT.md

## Docs
<!-- Doc registry — declare what docs this project maintains.
     This section lives in STACK.md (project root) and survives .agentic/ upgrades.
     To add a doc: add a line here. No .agentic/ files need editing.
     Format: - doc: <path> | <type> | <trigger> [| <tracks>]
     Triggers: feature_done | pr | session | manual
     Tracks (optional 4th field): comma-separated path prefixes this doc covers.
       When a feature is completed, only docs whose tracked paths overlap the
       feature's manifest are flagged for freshness. Docs without tracks are always checked.
     Note: pr-trigger docs only fire in formal profile (formal uses PRs).
     To fire on multiple triggers, add two entries with the same path.
     Types (built-in): changelog | readme | adr | lessons | architecture | runbook | tech-spec | custom -->
- doc: CHANGELOG.md                | changelog    | pr
- doc: README.md                   | readme       | pr
- doc: .agentic/spec/LESSONS.md     | lessons      | feature_done
- doc: docs/INSTRUCTION_ARCHITECTURE.md | architecture | feature_done | .agentic/lib/agents/,.claude/
- doc: docs/HOW_IT_WORKS.md         | architecture | feature_done | .agentic/lib/
- doc: docs/KEY_INSIGHTS.md         | lessons      | manual
- doc: docs/FRAMEWORK_VALUE_PROPOSITION.md | tech-spec | manual
- doc: .agentic/lib/README.md       | readme       | pr
- doc: .agentic/lib/DEVELOPER_GUIDE.md | architecture | feature_done | .agentic/lib/
- doc: .agentic/spec/NFR.md         | tech-spec    | feature_done | .agentic/spec/
- doc: .agentic/spec/ISSUES.md      | custom       | feature_done
- doc: .agentic/spec/REFERENCES.md  | custom       | manual
- doc: .agentic/OVERVIEW.md          | architecture | feature_done | .agentic/
- doc: .agentic/lib/START_HERE.md    | readme       | feature_done | .agentic/lib/
- doc: .agentic/lib/PRINCIPLES.md   | architecture | feature_done | .agentic/lib/
- doc: .agentic/lib/FRAMEWORK_MAP.md | architecture | feature_done | .agentic/lib/
- doc: .agentic/lib/DIRECT_EDITING.md | runbook     | manual
- doc: .agentic/lib/EMERGENCY.md     | runbook      | manual
- doc: .agentic/lib/MANUAL_OPERATIONS.md | runbook   | manual
- doc: docs/FRAMEWORK_WORKFLOW.md    | architecture | feature_done | .agentic/lib/tools/
- doc: .agentic/CONTRIBUTIONS.md    | changelog    | pr
- doc: spec/adr/                   | adr          | manual

## Constraints & non-negotiables
- Backward compatibility: Must support existing projects upgrading
- Cross-platform: Scripts must work on macOS and Linux
- Dogfooding: Framework uses its own spec-driven methodology
- Token efficiency: All tools must be token-efficient
