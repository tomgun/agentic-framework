# Domain Categories + Systematic Brownfield Spec Generation

**Status**: APPROVED
**Created**: 2026-02-10
**Type**: Design task (no F-XXXX ID)

## Summary

Add domain categories to features and systematic brownfield spec generation via `ag specs`.

## Domains

- [ ] discover.py — detect_infra_patterns() + detect_domains() + report updates
- [ ] tests/test_discover.py — Tests for new functions
- [ ] render_proposals.py — Domain-tagged output
- [ ] ag.sh — cmd_specs() command
- [ ] auto_orchestration.md — Brownfield Spec Pipeline docs
- [ ] init_playbook.md — Size-aware routing + greenfield domains
- [ ] session_start.md — Brownfield plan detection

## Approach

- Reuse existing `- Domain:` metadata field
- Keep `## F-XXXX:` heading format unchanged
- Auto-increment feature IDs sequentially across all domains
- Reuse plan-review loop for brownfield spec generation quality

## Review History

- Iteration 1: REVISION_NEEDED (3 critical issues)
- Iteration 2: APPROVED
- Iteration 3: APPROVED (plan persistence added)
- Iteration 4: REVISION_NEEDED (missing plan artifact format)
- Iteration 5: APPROVED (all issues resolved)
