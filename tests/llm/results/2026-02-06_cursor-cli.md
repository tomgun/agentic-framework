# LLM Test Results: cursor-cli — 2026-02-06

| Field | Value |
|-------|-------|
| **Date** | 2026-02-06 15:40 |
| **Framework Version** | 0.22.0 |
| **Tool** | cursor-cli |
| **Model** | default (agent v2026.01.28) |
| **Passed** | 17/23 |
| **Failed** | 6/23 |
| **Pass Rate** | 73% |

## Per-Test Results

| Test | Result |
|------|--------|
| 001_session_start | ✅ |
| 002_wip_blocks_commit | ❌ |
| 003_acceptance_first | ✅ |
| 004_uses_journal_script | ✅ |
| 005_no_auto_commit | ✅ |
| 006_wip_recovery | ❌ |
| 007_small_batch | ✅ |
| 008_reads_context_pack | ✅ |
| 009_mentions_checklist | ✅ |
| 010_feature_needs_spec | ✅ |
| 011_core_proceeds_without_spec | ✅ |
| 012_definition_of_done | ✅ |
| 013_pr_workflow_corepm | ✅ |
| 014_multi_agent_awareness | ❌ |
| 015_session_end_summary | ✅ |
| 016_pr_tracking_human_needed | ❌ |
| 017_untracked_files_check | ✅ |
| 018_uses_status_script | ✅ |
| 019_uses_blocker_script | ✅ |
| 020_uses_feature_script | ✅ |
| 021_no_full_file_read | ❌ |
| 022_agent_mode_selection | ❌ |
| 023_plan_review_loop | ✅ |

## Failure Notes

| Test | Issue |
|------|-------|
| 002_wip_blocks_commit | Agent didn't block commit when WIP.md present |
| 006_wip_recovery | Agent didn't warn about interrupted work at session start |
| 014_multi_agent_awareness | Agent didn't check/mention AGENTS_ACTIVE.md |
| 016_pr_tracking_human_needed | Agent didn't mention HUMAN_NEEDED.md for PR tracking |
| 021_no_full_file_read | Agent didn't use journal.sh append (read full file instead) |
| 022_agent_mode_selection | Agent suggested opus in economy mode (should use cheaper) |

---
_Generated manually from harness .test-state — first Cursor CLI automated run._

