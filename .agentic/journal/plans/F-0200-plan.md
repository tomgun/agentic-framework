# F-0200: Intent Journal + Reconciliation — Plan

**Status**: APPROVED
**Parent Plan**: reliability-fix-plan.md (Priority 5)

## Scope

PRs 4-7 of the Reliability Fix Plan:
- PR 4: state_machine.py idempotency fix + intents.py module + unit tests
- PR 5: cmd_implement intent-driven + intent-helpers.sh
- PR 6: cmd_done intent-driven (reliability + gated behavioral change)
- PR 7: Reconciler + ag intent commands + integration tests + instruction file updates + migration

See parent plan for full architecture (WAL + reconciliation, session identity, adopt-orphan recovery, three enforcement modes).

## Files Changed

- `.agentic/lib/auto/state_machine.py` (idempotency fix)
- `.agentic/lib/auto/intents.py` (new)
- `.agentic/lib/tools/intent-helpers.sh` (new)
- `.agentic/lib/tools/ag.sh` (cmd_implement, cmd_done, cmd_intent)
- `.agentic/lib/tools/sync.sh` (phase_intents)
- `tests/test_intents.py` (new)
- All instruction file templates (P5e)
- `upgrade.sh`, `.agentic/.gitignore`
